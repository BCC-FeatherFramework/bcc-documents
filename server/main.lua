-- bcc-documents server: licensing office, document use and officer commands.
-- Identity always comes from the caller's Core session; client payloads carry
-- only the document type and the player's choices.

DocsReady = false

local function DocConfig(docType)
    return type(docType) == 'string' and Config.DocumentTypes[docType] or nil
end

local function Reply(src, ok, message)
    if message then
        NotifyClient(src, message, 5000)
    end
    return { ok = ok == true }
end

local function Available(src)
    if not DocsReady then
        NotifyClient(src, _U('ServiceUnavailable'), 4000)
        return false
    end
    return true
end

local function Holds(characterId, docType)
    local count = DocsInventory.CountDocuments(characterId, docType)
    return count.ok and count.value > 0
end

-- Does the character currently have this document? For a license document that
-- means a current (active or suspended) license; for others, a record.
local function HasDocument(characterId, docType)
    if DocConfig(docType).licenseKey then
        local license = DocsRecords.License(characterId, docType)
        if not license.ok then
            return nil, license
        end
        return license.value ~= nil, license
    end
    return DocsRecords.Get(characterId, docType) ~= nil
end

local function RunOrder(character, docType, kind, price, payload, successMessage)
    local created = DocsOrders.Create(character.characterId, docType, kind, price, payload)
    if not created.ok then
        return Reply(character.source, false, _U('ServiceUnavailable'))
    end
    local result = DocsOrders.Run(created.value, character.source)
    if not result.ok then
        if created.value.status == 'rejected' or created.value.status == 'pending' then
            return Reply(character.source, false, DocsEconomy.Message(result))
        end
        -- Paid but a later step failed: staff can finish it with DocumentsOrdersRetry.
        return Reply(character.source, false, _U('OrderReview'))
    end
    return Reply(character.source, true, successMessage(result.value))
end

-- Licensing office -------------------------------------------------------------

DocsRPC.Register('bcc-documents:Buy', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    if not character or not docConfig or not docConfig.sellNpc or not Available(src) then
        return { ok = false }
    end
    local has, problem = HasDocument(character.characterId, params.docType)
    if has == nil then
        return Reply(src, false, _U('ServiceUnavailable'))
    elseif has then
        return Reply(src, false, _U('AlreadyGotDocument'))
    end
    if Holds(character.characterId, params.docType) then
        return Reply(src, false, _U('PocketFull'))
    end
    return RunOrder(character, params.docType, 'purchase', docConfig.price, {}, function()
        return _U('BoughtDocument') .. DocsEconomy.Format(docConfig.price)
    end)
end)

DocsRPC.Register('bcc-documents:Extend', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    local days = tonumber(params.days)
    if not character or not docConfig or not Available(src) then
        return { ok = false }
    end
    if not docConfig.licenseKey or (tonumber(docConfig.expiryDays) or 0) <= 0 then
        return Reply(src, false, _U('NoExtendPermanent'))
    end
    if not days or days % 1 ~= 0 or days < 1 or days > Config.feather.maxExtendDays then
        return Reply(src, false, _U('InvalidDays') .. Config.feather.maxExtendDays)
    end
    local license = DocsRecords.License(character.characterId, params.docType)
    if not license.ok then
        return Reply(src, false, _U('ServiceUnavailable'))
    elseif not license.value then
        return Reply(src, false, _U('GotNoDocument'))
    elseif license.value.status == 'suspended' then
        return Reply(src, false, _U('LicenseSuspended'))
    end
    local price = (tonumber(docConfig.extendPrice) or 0) * days
    return RunOrder(character, params.docType, 'extend', price, {
        licenseId = license.value.licenseId,
        revision = license.value.revision,
        days = days
    }, function(order)
        local expiresAt = order.payload.expiresAt
        return _U('ExpiryDateExtended') .. (expiresAt and os.date(Config.PlayYear .. '-%m-%d %H:%M',
            math.floor(expiresAt / 1000)) or '')
    end)
end)

DocsRPC.Register('bcc-documents:Reissue', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    if not character or not docConfig or not Available(src) then
        return { ok = false }
    end
    local has = HasDocument(character.characterId, params.docType)
    if has == nil then
        return Reply(src, false, _U('ServiceUnavailable'))
    elseif not has or not DocsRecords.Get(character.characterId, params.docType) then
        return Reply(src, false, _U('GotNoDocument'))
    end
    if Holds(character.characterId, params.docType) then
        return Reply(src, false, _U('PocketFull'))
    end
    return RunOrder(character, params.docType, 'reissue', docConfig.reissuePrice, {}, function()
        return _U('DocumentUpdated') .. ' ' .. DocsEconomy.Format(docConfig.reissuePrice)
    end)
end)

DocsRPC.Register('bcc-documents:ChangePhoto', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    local url = params.url
    if not character or not docConfig or not Available(src) then
        return { ok = false }
    end
    if type(url) ~= 'string' or #url > Config.feather.maxPhotoUrlLength or not url:match('^https://[%w%-%.]+/%S*$') then
        return Reply(src, false, _U('InvalidPhoto'))
    end
    if not DocsRecords.Get(character.characterId, params.docType) then
        return Reply(src, false, _U('GotNoDocument'))
    end
    return RunOrder(character, params.docType, 'photo', docConfig.changePhotoPrice, { picture = url }, function()
        return _U('ChangedPicture') .. DocsEconomy.Format(docConfig.changePhotoPrice)
    end)
end)

-- The player revokes their own document: the license is revoked, the record
-- removed and every copy taken back. No money moves.
function DocsRevokeOwn(characterId, docType, actorSource)
    local license = DocsRecords.License(characterId, docType)
    if not license.ok then
        return license
    end
    if license.value then
        local revoked = DocsLicenses.Revoke(('self-revoke:%s'):format(Docs.NewId()), license.value.licenseId,
            license.value.revision, 'documents.self_revoked', actorSource)
        if not revoked.ok then
            return revoked
        end
    elseif not DocsRecords.Get(characterId, docType) then
        return Docs.Err('document_not_found', 'No document to revoke.')
    end
    DocsRecords.Delete(characterId, docType)
    DocsInventory.RemoveDocuments(characterId, docType)
    return Docs.Ok(true)
end

DocsRPC.Register('bcc-documents:Revoke', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    if not character or not docConfig or not Available(src) then
        return { ok = false }
    end
    local revoked = DocsRevokeOwn(character.characterId, params.docType, src)
    if not revoked.ok then
        return Reply(src, false, revoked.code == 'document_not_found' and _U('DontHaveToRevoke')
            or _U('ServiceUnavailable'))
    end
    return Reply(src, true, _U('YouRevokedDocument'))
end)

-- Showing a document --------------------------------------------------------------
-- The server builds the view from its own records; the client only names the
-- document and the target, and the target must stand close by.

DocsRPC.Register('bcc-documents:Show', function(params, src)
    local character, docConfig = DocsCharacters.Get(src), DocConfig(params.docType)
    local target = tonumber(params.target)
    if not character or not docConfig or not target or target == src or not GetPlayerName(target) then
        return { ok = false }
    end
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target)))
    if distance > Config.feather.showDistance then
        return Reply(src, false, _U('NoNearbyPlayer'))
    end
    local view = DocsRecords.View(character.characterId, params.docType)
    if not view.ok or not view.value then
        return Reply(src, false, _U('GotNoDocument'))
    end
    DocsRPC.Notify(target, 'bcc-documents:client:Show', { view = view.value })
    return Reply(src, true, (GetPlayerName(target) or '') .. _U('checkingYourDoc'))
end)

-- Using a document item opens the holder's own document.
local function OnUse(docType)
    return function(src)
        DocsInventory.Close(src)
        local character = DocsCharacters.Get(src)
        if not character then
            return
        end
        local view = DocsRecords.View(character.characterId, docType)
        if not view.ok then
            return NotifyClient(src, _U('ServiceUnavailable'), 4000)
        end
        if not view.value then
            return NotifyClient(src, _U('GotNoDocument'), 5000)
        end
        DocsRPC.Notify(src, 'bcc-documents:client:Open', { view = view.value })
    end
end

-- Officer commands -----------------------------------------------------------------
-- givenCommand <serverId>: the target must be online and nearby is not required
-- (as upstream). The officer needs the document's allowJob in feather-jobs or
-- Feather Admin staff; a license is issued with the officer as issuer.

function DocsGive(officerSource, docType, targetSource)
    local officer, target = DocsCharacters.Get(officerSource), DocsCharacters.Get(targetSource)
    local docConfig = DocConfig(docType)
    if not officer or not docConfig then
        return Docs.Err('invalid_input', 'Officer and document required.')
    end
    if not target then
        return Docs.Err('target_unavailable', 'Target has no active character.')
    end
    if not DocsJobs.Holds(officer.characterId, docConfig.allowJob)
        and not DocsAuthority.IsAdminStaff(officer.characterId) then
        return Docs.Err('not_allowed', 'Officer may not give this document.')
    end
    if Config.NeedItem and DocsInventory.Count(officerSource, Config.NeedItemName) < 1 then
        return Docs.Err('need_item', 'Officer lacks the required item.')
    end
    local has = HasDocument(target.characterId, docType)
    if has == nil then
        return Docs.Err('dependency_unavailable', 'Document check failed.')
    elseif has then
        return Docs.Err('target_has_document', 'Target already has this document.')
    end
    local licenseId
    if docConfig.licenseKey then
        local issued = DocsLicenses.Issue({
            order_id = Docs.NewId(),
            character_id = target.characterId,
            license_key = docConfig.licenseKey,
            kind = 'officer_issue',
            actor_source = officerSource
        }, 'character')
        if not issued.ok then
            return issued
        end
        licenseId = issued.value.licenseId
    end
    DocsRecords.Upsert(target.characterId, docType, licenseId)
    if not Holds(target.characterId, docType) then
        DocsInventory.GiveDocument(target.characterId, docType)
    end
    if Config.NeedItem then
        DocsInventory.RemoveByName(officerSource, Config.NeedItemName, 1)
    end
    return Docs.Ok({ licenseId = licenseId, target = target })
end

local function RegisterGiveCommands()
    for docType, docConfig in pairs(Config.DocumentTypes) do
        if docConfig.givenCommand then
            RegisterCommand(docConfig.givenCommand, function(source, args)
                if source == 0 then
                    return print('[bcc-documents] ' .. docConfig.givenCommand .. ' is an in-game command.')
                end
                local given = DocsGive(source, docType, tonumber(args[1]))
                if given.ok then
                    NotifyClient(source, _U('GiveDocument') .. docConfig.displayName, 5000)
                    NotifyClient(given.value.target.source, _U('GetDocument') .. docConfig.displayName, 5000)
                    return
                end
                local messages = {
                    not_allowed = _U('NoJob'),
                    need_item = _U('NoNeedItem') .. tostring(Config.NeedItemName),
                    target_has_document = _U('TargetAlreadyGotDocument'),
                    target_unavailable = _U('NoNearbyPlayer')
                }
                NotifyClient(source, messages[given.code] or _U('ServiceUnavailable'), 5000)
            end, false)
        end
    end
end

-- Startup ---------------------------------------------------------------------------

CreateThread(function()
    local migrated = DocsMigrations.Run()
    if not migrated.ok then
        return Docs.Log('startup.failed', { step = 'migrations', code = migrated.code })
    end
    local definitions = DocsLicenses.EnsureDefinitions()
    if not definitions.ok then
        Docs.Log('startup.failed', { step = 'license_definitions', code = definitions.code,
            docType = definitions.details and definitions.details.docType })
        return
    end
    local inventoryReady = Docs.Call('feather-inventory', 'AwaitReady', 30000)
    if not inventoryReady.ok then
        return Docs.Log('startup.failed', { step = 'inventory', code = inventoryReady.code })
    end
    for docType in pairs(Config.DocumentTypes) do
        if not DocsInventory.ItemExists(docType) then
            Docs.Log('item.missing', { item = docType, fix = 'apply sql/install_items.sql' })
        else
            local registered = DocsInventory.RegisterUsable(docType, OnUse(docType))
            if not registered.ok then
                Docs.Log('item.register_failed', { item = docType, code = registered.code })
            end
        end
    end
    RegisterGiveCommands()
    DocsReady = true
    Docs.Log('startup.ready', {})
end)
