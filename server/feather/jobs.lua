-- bcc-documents' boundary to feather-jobs.
--
-- allowJob in Config.DocumentTypes is a feather-jobs job key. Jobs returns
-- facts; bcc-documents decides what they permit.

DocsJobs = {}

local RESOURCE = 'feather-jobs'

-- With minGradeOrdinal, only a grade at or above it matches.
function DocsJobs.Holds(characterId, jobKey, minGradeOrdinal)
    if type(jobKey) ~= 'string' or jobKey == '' then
        return false
    end
    local check = Docs.Call(RESOURCE, 'CheckAssignment', { characterId = characterId, jobKey = jobKey,
        minGradeOrdinal = tonumber(minGradeOrdinal) })
    return check.ok and check.value.matched == true
end

-- Label of the character's active job, shown on documents.
function DocsJobs.ActiveLabel(characterId)
    local snapshot = Docs.Call(RESOURCE, 'GetEffectiveJobSnapshot', { characterId = characterId })
    if snapshot.ok and type(snapshot.value) == 'table' and type(snapshot.value.active) == 'table' then
        return snapshot.value.active.jobLabel
    end
    return nil
end
