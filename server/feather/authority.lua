-- bcc-documents' boundary to feather-authority.
--
-- Feather Admin staff holding one of Config.feather.adminStaffCapabilities may
-- give any document by command. Fails closed.

DocsAuthority = {}

function DocsAuthority.IsAdminStaff(characterId)
    for _, capability in ipairs(Config.feather.adminStaffCapabilities or {}) do
        local decision = Docs.Call('feather-authority', 'Evaluate', {
            subjectType = 'character',
            subjectId = characterId,
            capabilityKey = capability,
            scopeType = 'server'
        })
        if decision.ok and type(decision.value) == 'table' and decision.value.allowed == true then
            return true
        end
    end
    return false
end
