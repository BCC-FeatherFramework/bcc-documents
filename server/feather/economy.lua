-- bcc-documents' boundary to feather-economy.
--
-- bcc-documents keeps no balances. Every fee moves money from the character's
-- wallet into the currency's system sink, idempotent by order ID. Config prices
-- are whole units; Economy amounts are minor units.

DocsEconomy = {}

local RESOURCE = 'feather-economy'
local precisions = {}

local function Economy(operation, request, context)
    return Docs.Call(RESOURCE, operation, request, context)
end

function DocsEconomy.Currency()
    return Config.feather.currency
end

local function Precision(currency)
    if precisions[currency] then
        return Docs.Ok(precisions[currency])
    end
    local definition = Economy('GetCurrency', currency)
    if not definition.ok then
        return definition
    end
    if type(definition.value) ~= 'table' or definition.value.enabled ~= true then
        return Docs.Err('invalid_currency', 'Currency is unavailable.')
    end
    precisions[currency] = tonumber(definition.value.precision) or 0
    return Docs.Ok(precisions[currency])
end

-- Whole config price -> integer minor units, or an error.
function DocsEconomy.ToMinor(price)
    price = tonumber(price)
    if not price or price ~= price or price < 0 then
        return Docs.Err('invalid_price', 'Price is invalid.')
    end
    local precision = Precision(DocsEconomy.Currency())
    if not precision.ok then
        return precision
    end
    return Docs.Ok(math.floor(price * 10 ^ precision.value + 0.5))
end

local function Wallet(characterId, currency)
    local result = Economy('EnsureCharacterWallets', { characterId = characterId })
    if not result.ok then
        return result
    end
    for _, account in ipairs(result.value) do
        if account.accountType == 'wallet' and account.currency == currency and account.status == 'open' then
            return Docs.Ok(account)
        end
    end
    return Docs.Err('wallet_not_found', 'Economy returned no wallet for this currency.')
end

local function Sink(currency)
    local result = Economy('GetSystemAccount', { currency = currency, accountType = 'system_sink' })
    if not result.ok then
        return result
    end
    return Docs.Ok(result.value.accountId)
end

-- Charges an order (wallet -> system sink). Idempotent by order ID, so a retry
-- after a timeout never charges twice. A zero amount moves nothing.
function DocsEconomy.Charge(order)
    if tonumber(order.amount) == 0 then
        return Docs.Ok({ transactionId = nil, free = true })
    end
    local currency = order.currency
    local wallet = Wallet(order.character_id, currency)
    if not wallet.ok then
        return wallet
    end
    local sink = Sink(currency)
    if not sink.ok then
        return sink
    end
    return Economy('Transfer', {
        fromAccountId = wallet.value.accountId,
        toAccountId = sink.value,
        currency = currency,
        amount = tonumber(order.amount),
        reasonCode = 'documents.' .. order.kind,
        referenceType = 'documents_order',
        referenceId = order.order_id,
        idempotencyKey = 'bcc-documents:order:' .. order.order_id
    }, {
        actorSource = order.actor_source,
        correlationId = order.order_id
    })
end

-- Player-facing message for an Economy refusal.
function DocsEconomy.Message(result)
    local code = type(result) == 'table' and result.code or nil
    if code == 'insufficient_funds' then
        return _U('NotEnoughMoney')
    end
    return _U('ServiceUnavailable')
end

function DocsEconomy.Format(price)
    return ('$%s'):format(tostring(price))
end

AddEventHandler('onResourceStart', function(resource)
    if resource == RESOURCE then
        precisions = {}
    end
end)
