-- Paid document actions as durable workflows.
--
--   pending -> (Economy charge) -> paid -> (Licenses, records, items) -> fulfilled
--   pending -> refused charge -> rejected
--   paid    -> a later step failed -> review (money moved; retry resumes)
--
-- Every external call is idempotent by order ID (Economy idempotency key,
-- Licenses request ID), so a retry never charges or issues twice. The item
-- delivery is marked in the order payload once done.

DocsOrders = {}

local KINDS = { purchase = true, extend = true, reissue = true, photo = true }

-- Charge refusals that are final: nothing moved, the order is rejected.
local definitive = {
    insufficient_funds = true,
    authorization_denied = true,
    account_not_found = true,
    account_closed = true,
    currency_mismatch = true,
    invalid_input = true,
    invalid_price = true,
    invalid_currency = true,
    wallet_not_found = true
}

local function Load(orderId)
    local row = DB.one([[
        SELECT `order_id`,`character_id`,`doc_type`,`kind`,`currency`,`amount`,`payload_json`,`status`,
            `economy_transaction_id`,`last_error`,`note`,
            FLOOR(UNIX_TIMESTAMP(`created_at`)) AS created_at_s
        FROM `bcc_documents_orders` WHERE `order_id`=?]], orderId)
    if not row then
        return nil
    end
    local decoded, payload = pcall(json.decode, row.payload_json or '{}')
    row.payload = decoded and type(payload) == 'table' and payload or {}
    return row
end
DocsOrders.Load = Load

local function Save(order, status, fields)
    fields = fields or {}
    order.status = status
    DB.exec([[
        UPDATE `bcc_documents_orders`
        SET `status`=?,`payload_json`=?,`economy_transaction_id`=COALESCE(?,`economy_transaction_id`),`last_error`=?
        WHERE `order_id`=?]],
        status, json.encode(order.payload), fields.transactionId, fields.error and tostring(fields.error):sub(1, 255),
        order.order_id)
end

-- Creates a pending order. price is whole config units.
function DocsOrders.Create(characterId, docType, kind, price, payload)
    if not KINDS[kind] then
        return Docs.Err('invalid_input', 'Unknown order kind.')
    end
    local amount = DocsEconomy.ToMinor(price)
    if not amount.ok then
        return amount
    end
    local orderId = Docs.NewId()
    DB.exec([[
        INSERT INTO `bcc_documents_orders` (`order_id`,`character_id`,`doc_type`,`kind`,`currency`,`amount`,`payload_json`)
        VALUES (?,?,?,?,?,?,?)]],
        orderId, characterId, docType, kind, DocsEconomy.Currency(), amount.value, json.encode(payload or {}))
    return Docs.Ok(Load(orderId))
end

-- The domain steps of a paid order. Each step is safe to run again.
local fulfil = {}

function fulfil.purchase(order)
    local docConfig = Config.DocumentTypes[order.doc_type]
    local licenseId
    if docConfig.licenseKey then
        local issued = DocsLicenses.Issue({
            order_id = order.order_id,
            character_id = order.character_id,
            license_key = docConfig.licenseKey,
            kind = order.kind,
            actor_source = order.actor_source
        }, 'system')
        if not issued.ok then
            return issued
        end
        licenseId = issued.value.licenseId
    end
    DocsRecords.Upsert(order.character_id, order.doc_type, licenseId)
    return fulfil.deliver(order)
end

function fulfil.extend(order)
    local renewed = DocsLicenses.Renew({
        order_id = order.order_id,
        kind = order.kind,
        actor_source = order.actor_source
    }, order.payload.licenseId, order.payload.revision, order.payload.days)
    if not renewed.ok then
        return renewed
    end
    order.payload.expiresAt = renewed.value.expiresAt
    return Docs.Ok(true)
end

function fulfil.reissue(order)
    DocsRecords.Refresh(order.character_id, order.doc_type)
    return fulfil.deliver(order)
end

function fulfil.photo(order)
    DocsRecords.SetPicture(order.character_id, order.doc_type, order.payload.picture)
    return Docs.Ok(true)
end

-- Gives the document item once; the payload remembers it was delivered.
function fulfil.deliver(order)
    if order.payload.itemDelivered then
        return Docs.Ok(true)
    end
    local given = DocsInventory.GiveDocument(order.character_id, order.doc_type)
    if not given.ok then
        return given
    end
    order.payload.itemDelivered = true
    Save(order, order.status)
    return Docs.Ok(true)
end

-- Runs an order from its current state. actorSource is the connected player
-- who triggered it (nil for console retries).
function DocsOrders.Run(order, actorSource)
    order.actor_source = actorSource
    if order.status == 'fulfilled' or order.status == 'rejected' then
        return Docs.Ok(order)
    end
    if order.status == 'pending' then
        local charged = DocsEconomy.Charge(order)
        if not charged.ok then
            if definitive[charged.code] then
                Save(order, 'rejected', { error = charged.code })
            else
                Save(order, 'pending', { error = charged.code })
            end
            return charged
        end
        Save(order, 'paid', { transactionId = charged.value and charged.value.transactionId })
    end
    local step = fulfil[order.kind]
    local done = step(order)
    if not done.ok then
        Save(order, 'review', { error = done.code })
        Docs.Log('order.review', { order = order.order_id, kind = order.kind, code = done.code })
        return done
    end
    Save(order, 'fulfilled')
    return Docs.Ok(order)
end

-- Console reconciliation ---------------------------------------------------------

RegisterCommand('DocumentsOrdersReport', function(source)
    if source ~= 0 then
        return
    end
    local rows = DB.query([[
        SELECT `order_id`,`character_id`,`doc_type`,`kind`,`amount`,`status`,`economy_transaction_id`,`last_error`,
            `created_at`
        FROM `bcc_documents_orders` WHERE `status` IN ('pending','paid','review')
        ORDER BY `created_at` LIMIT 50]]) or {}
    print(('[DocumentsOrdersReport] %d unresolved order(s)'):format(#rows))
    for _, row in ipairs(rows) do
        print(('[DocumentsOrdersReport] %s %s %s %s amount=%s character=%s tx=%s error=%s at=%s'):format(
            row.order_id, row.status, row.kind, row.doc_type, tostring(row.amount), row.character_id,
            tostring(row.economy_transaction_id), tostring(row.last_error), tostring(row.created_at)))
    end
end, true)

RegisterCommand('DocumentsOrdersRetry', function(source, args)
    if source ~= 0 then
        return
    end
    local order = args[1] and Load(args[1])
    if not order then
        return print('[DocumentsOrdersRetry] usage: DocumentsOrdersRetry <orderId>')
    end
    if order.status == 'review' then
        order.status = 'paid'
    end
    local result = DocsOrders.Run(order, nil)
    print(('[DocumentsOrdersRetry] %s -> %s%s'):format(order.order_id, order.status,
        result.ok and '' or (' (' .. tostring(result.code) .. ')')))
end, true)

RegisterCommand('DocumentsOrdersResolve', function(source, args)
    if source ~= 0 then
        return
    end
    local order = args[1] and Load(args[1])
    local status = args[2]
    if not order or (status ~= 'fulfilled' and status ~= 'rejected') then
        return print('[DocumentsOrdersResolve] usage: DocumentsOrdersResolve <orderId> <fulfilled|rejected> <note>')
    end
    local note = table.concat(args, ' ', 3):sub(1, 255)
    DB.exec('UPDATE `bcc_documents_orders` SET `status`=?,`note`=? WHERE `order_id`=?', status, note, order.order_id)
    print(('[DocumentsOrdersResolve] %s -> %s'):format(order.order_id, status))
end, true)
