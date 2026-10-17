-- bcc-documents' boundary to feather-licenses.
--
-- Each license document type (Config.DocumentTypes[*].licenseKey) is a license
-- definition owned by bcc-documents. Licenses holds the truth: who holds which
-- license, its status and expiry. The document item is only a display copy.

DocsLicenses = {}

local RESOURCE = 'feather-licenses'
local DAY = 86400

local function Licenses(operation, request)
    return Docs.Call(RESOURCE, operation, request)
end

-- Duration rules for a document type: expiryDays = 0 means a permanent license
-- (no default, no maximum, not renewable).
local function Durations(docConfig)
    local days = tonumber(docConfig.expiryDays) or 0
    if days <= 0 then
        return nil, nil, false
    end
    local maxDays = math.max(days, tonumber(Config.feather.maxLicenseDays) or days)
    return days * DAY, maxDays * DAY, true
end

-- Registers or updates the definition of every license document type. Safe on
-- every start: an unchanged definition is left alone.
function DocsLicenses.EnsureDefinitions()
    local ready = Licenses('AwaitReady', 30000)
    if not ready.ok then
        return ready
    end
    for docType, docConfig in pairs(Config.DocumentTypes) do
        local key = docConfig.licenseKey
        if key then
            local default, maximum, renewable = Durations(docConfig)
            local current = Licenses('GetLicenseDefinition', { licenseKey = key })
            if not current.ok and current.code == 'definition_not_found' then
                local registered = Licenses('RegisterLicenseDefinition', {
                    requestId = ('definition:%s:%s'):format(key, Docs.NewId()),
                    licenseKey = key,
                    label = docConfig.displayName,
                    holderTypes = { 'character' },
                    defaultDurationSeconds = default,
                    maxDurationSeconds = maximum,
                    renewable = renewable,
                    reasonCode = 'documents.setup'
                })
                if not registered.ok then
                    return Docs.Err(registered.code, 'License definition could not be registered.', { docType = docType })
                end
            elseif not current.ok then
                return Docs.Err(current.code, 'License definition lookup failed.', { docType = docType })
            elseif current.value.ownerResource ~= GetCurrentResourceName() then
                return Docs.Err('license_key_conflict', 'License key belongs to another resource.', {
                    docType = docType, owner = current.value.ownerResource })
            else
                local definition = current.value
                local changed = definition.label ~= docConfig.displayName
                    or definition.defaultDurationSeconds ~= default
                    or definition.maxDurationSeconds ~= maximum
                    or definition.renewable ~= renewable
                    or definition.status ~= 'active'
                if changed then
                    local updated = Licenses('UpdateLicenseDefinition', {
                        requestId = ('definition-update:%s:%s'):format(key, Docs.NewId()),
                        licenseKey = key,
                        expectedRevision = definition.revision,
                        label = docConfig.displayName,
                        defaultDurationSeconds = default or false,
                        maxDurationSeconds = maximum or false,
                        renewable = renewable,
                        status = 'active',
                        reasonCode = 'documents.setup'
                    })
                    if not updated.ok then
                        return Docs.Err(updated.code, 'License definition could not be updated.', { docType = docType })
                    end
                end
            end
        end
    end
    return Docs.Ok(true)
end

-- The character's current license for a document type, or nil.
function DocsLicenses.Check(characterId, licenseKey)
    local check = Licenses('CheckLicense', {
        holderType = 'character',
        holderId = characterId,
        licenseKey = licenseKey
    })
    if not check.ok then
        return check
    end
    return Docs.Ok(check.value)
end

function DocsLicenses.Issue(order, issuer)
    local request = {
        requestId = 'order:' .. order.order_id,
        licenseKey = order.license_key,
        holderType = 'character',
        holderId = order.character_id,
        reasonCode = 'documents.' .. order.kind,
        referenceType = 'documents_order',
        referenceId = order.order_id
    }
    if issuer == 'character' then
        request.issuerType = 'character'
        request.actorSource = order.actor_source
    elseif order.actor_source then
        request.actorSource = order.actor_source
    end
    return Licenses('IssueLicense', request)
end

function DocsLicenses.Renew(order, licenseId, revision, days)
    return Licenses('RenewLicense', {
        requestId = 'order:' .. order.order_id,
        licenseId = licenseId,
        expectedRevision = revision,
        durationSeconds = days * DAY,
        reasonCode = 'documents.' .. order.kind,
        referenceType = 'documents_order',
        referenceId = order.order_id,
        actorSource = order.actor_source
    })
end

function DocsLicenses.Revoke(requestId, licenseId, revision, reasonCode, actorSource)
    return Licenses('RevokeLicense', {
        requestId = requestId,
        licenseId = licenseId,
        expectedRevision = revision,
        reasonCode = reasonCode,
        actorSource = actorSource
    })
end
