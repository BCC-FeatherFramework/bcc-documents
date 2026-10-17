-- Console tests.
--   DocumentsReleaseSmokeTest            read-only release check
--   DocumentsFlowTest <characterUuid>    DevMode only; MOVES MONEY and changes documents.
--     The character may be offline. Buys an ID card and a hunting licence,
--     extends the licence, reissues a lost copy, changes the photo, then revokes
--     the licence and the ID card. Costs the configured prices.

RegisterCommand('DocumentsReleaseSmokeTest', function(source)
    if source ~= 0 then
        return
    end
    local registered = {}
    for _, command in ipairs(GetRegisteredCommands() or {}) do
        registered[command.name] = true
    end
    local missingItems, missingDefinitions = {}, {}
    for docType, docConfig in pairs(Config.DocumentTypes) do
        if not DocsInventory.ItemExists(docType) then
            missingItems[#missingItems + 1] = docType
        end
        if docConfig.licenseKey then
            local definition = Docs.Call('feather-licenses', 'GetLicenseDefinition', { licenseKey = docConfig.licenseKey })
            if not definition.ok or definition.value.ownerResource ~= GetCurrentResourceName() then
                missingDefinitions[#missingDefinitions + 1] = docConfig.licenseKey
            end
        end
    end
    local probe = '00000000-0000-0000-0000-000000000000'
    local licenses = Docs.Call('feather-licenses', 'CheckLicense', { holderType = 'character', holderId = probe,
        licenseKey = 'hunting' })
    local jobs = Docs.Call('feather-jobs', 'CheckAssignment', { characterId = probe, jobKey = 'documents_probe' })
    local authority = Docs.Call('feather-authority', 'Evaluate', { subjectType = 'character', subjectId = probe,
        capabilityKey = (Config.feather.adminStaffCapabilities or {})[1] or 'staff.admin.audit.search',
        scopeType = 'server' })
    local currency = DocsEconomy.ToMinor(1)
    local tables = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('bcc_documents','bcc_documents_orders')]]))
    local tests = {
        { 'development disabled', Config.devMode == false },
        { 'flow test absent', not registered.DocumentsFlowTest },
        { 'service ready', DocsReady == true },
        { 'tables present', tables == 2 },
        { 'document items defined', #missingItems == 0 },
        { 'paper item defined', not Config.NeedItem or DocsInventory.ItemExists(Config.NeedItemName) },
        { 'license definitions owned', #missingDefinitions == 0 },
        { 'licenses trust', licenses.ok == true },
        { 'jobs trust', jobs.ok == true },
        { 'authority trust', authority.ok == true },
        { 'economy currency', currency.ok == true }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then
            passed = passed + 1
        end
        print(('[DocumentsReleaseSmokeTest] %-26s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    if #missingItems > 0 then
        print('[DocumentsReleaseSmokeTest] missing items (apply sql/install_items.sql): ' .. table.concat(missingItems, ', '))
    end
    if #missingDefinitions > 0 then
        print('[DocumentsReleaseSmokeTest] license definitions not owned: ' .. table.concat(missingDefinitions, ', '))
    end
    print(('[DocumentsReleaseSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
end, true)

if not Config.devMode then
    return
end

local function Target(argument)
    if Docs.Uuid(argument) then
        return { characterId = argument:lower() }
    end
    return DocsCharacters.Get(argument)
end

local function Count(characterId, docType)
    local count = DocsInventory.CountDocuments(characterId, docType)
    return count.ok and count.value or -1
end

local function Order(character, docType, kind, price, payload)
    local created = DocsOrders.Create(character.characterId, docType, kind, price, payload)
    if not created.ok then
        return created, nil
    end
    return DocsOrders.Run(created.value, character.source), created.value
end

RegisterCommand('DocumentsFlowTest', function(source, args)
    if source ~= 0 then
        return
    end
    CreateThread(function()
        local called, reason = xpcall(function()
            local character = Target(args[1])
            if not character then
                return print('[DocumentsFlowTest] usage: DocumentsFlowTest <characterUuid|serverId>')
            end
            local id, hunting = character.characterId, 'huntinglicence'
            local huntingConfig = Config.DocumentTypes[hunting]
            -- Start clean: a previous run may have left documents behind.
            DocsRevokeOwn(id, hunting, nil)
            DocsRevokeOwn(id, 'idcard', nil)

            local idBought = Order(character, 'idcard', 'purchase', Config.DocumentTypes.idcard.price, {})
            local idRecord = DocsRecords.Get(id, 'idcard')
            local idCopies = Count(id, 'idcard')

            local bought, boughtOrder = Order(character, hunting, 'purchase', huntingConfig.price, {})
            local license = DocsRecords.License(id, hunting)
            local record = DocsRecords.Get(id, hunting)
            local copies = Count(id, hunting)
            local view = DocsRecords.View(id, hunting)

            local before = license.ok and license.value and license.value.expiresAt or 0
            local extended = Order(character, hunting, 'extend', huntingConfig.extendPrice * 2, {
                licenseId = license.ok and license.value and license.value.licenseId,
                revision = license.ok and license.value and license.value.revision,
                days = 2
            })
            local afterExtend = DocsRecords.License(id, hunting)

            -- A lost copy: take it away, then reissue.
            DocsInventory.RemoveDocuments(id, hunting)
            local lostCopies = Count(id, hunting)
            local reissued = Order(character, hunting, 'reissue', huntingConfig.reissuePrice, {})
            local reissuedCopies = Count(id, hunting)

            local photo = 'https://example.com/photo.png'
            local changed = Order(character, 'idcard', 'photo', Config.DocumentTypes.idcard.changePhotoPrice,
                { picture = photo })
            local picture = DocsRecords.Get(id, 'idcard')

            local revoked = DocsRevokeOwn(id, hunting, nil)
            local afterRevoke = DocsRecords.License(id, hunting)
            local revokedRecord = DocsRecords.Get(id, hunting)
            local revokedCopies = Count(id, hunting)
            local idRevoked = DocsRevokeOwn(id, 'idcard', nil)

            local tests = {
                { 'id card bought', idBought.ok and idRecord ~= nil and idRecord.license_id == nil and idCopies == 1 },
                { 'licence bought', bought.ok and boughtOrder.status == 'fulfilled' },
                { 'licence issued', license.ok and license.value ~= nil and license.value.matched == true },
                { 'record links licence', record ~= nil and license.ok and license.value
                    and record.license_id == license.value.licenseId },
                { 'one copy given', copies == 1 },
                { 'document view valid', view.ok and view.value and view.value.status == 'valid'
                    and view.value.expiresAt ~= nil },
                { 'licence extended', extended.ok and afterExtend.ok and afterExtend.value
                    and afterExtend.value.expiresAt - before == 2 * 86400000 },
                { 'lost copy reissued', lostCopies == 0 and reissued.ok and reissuedCopies == 1 },
                { 'photo changed', changed.ok and picture ~= nil and picture.picture == photo },
                { 'licence revoked', revoked.ok and afterRevoke.ok and afterRevoke.value == nil },
                { 'record and copies removed', revokedRecord == nil and revokedCopies == 0 },
                { 'id card revoked', idRevoked.ok and DocsRecords.Get(id, 'idcard') == nil and Count(id, 'idcard') == 0 }
            }
            local passed = 0
            for _, test in ipairs(tests) do
                if test[2] then
                    passed = passed + 1
                end
                print(('[DocumentsFlowTest] %-26s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
            end
            print(('[DocumentsFlowTest] done %d/%d passed (MUTATING: character %s)'):format(passed, #tests, id))
            for name, result in pairs({ idcard = idBought, purchase = bought, extend = extended, reissue = reissued,
                photo = changed, revoke = revoked }) do
                if not result.ok then
                    print(('[DocumentsFlowTest] %s failed: %s %s'):format(name, tostring(result.code),
                        tostring(result.message)))
                end
            end
        end, debug.traceback)
        if not called then
            print('[DocumentsFlowTest] FAIL ' .. tostring(reason))
        end
    end)
end, true)
