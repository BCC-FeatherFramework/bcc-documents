-- Document records (bcc_documents) and the view shown when a document is used
-- or shown. License status and expiry always come from feather-licenses.

DocsRecords = {}

local selectColumns = [[
    SELECT `character_id`,`doc_type`,`license_id`,`first_name`,`last_name`,`date_of_birth`,`gender`,
        `job_label`,`picture`,FLOOR(UNIX_TIMESTAMP(`issued_at`)) AS issued_at_s
    FROM `bcc_documents`]]

function DocsRecords.Get(characterId, docType)
    return DB.one(selectColumns .. ' WHERE `character_id`=? AND `doc_type`=?', characterId, docType)
end

-- Details printed on the document, read now from Character and Jobs.
function DocsRecords.Snapshot(characterId)
    local profile = DocsCharacters.Profile(characterId) or {}
    return {
        firstName = profile.firstName,
        lastName = profile.lastName,
        dateOfBirth = profile.dateOfBirth,
        gender = profile.gender,
        jobLabel = DocsJobs.ActiveLabel(characterId)
    }
end

-- Creates or refreshes the record for a (character, document type). A new
-- license replaces the previous license ID; the photo is kept.
function DocsRecords.Upsert(characterId, docType, licenseId)
    local snapshot = DocsRecords.Snapshot(characterId)
    local picture = Config.DocumentTypes[docType].defaultPicture
    DB.exec([[
        INSERT INTO `bcc_documents`
            (`character_id`,`doc_type`,`license_id`,`first_name`,`last_name`,`date_of_birth`,`gender`,`job_label`,`picture`)
        VALUES (?,?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE `license_id`=VALUES(`license_id`),`first_name`=VALUES(`first_name`),
            `last_name`=VALUES(`last_name`),`date_of_birth`=VALUES(`date_of_birth`),`gender`=VALUES(`gender`),
            `job_label`=VALUES(`job_label`),`issued_at`=CURRENT_TIMESTAMP]],
        characterId, docType, licenseId, snapshot.firstName, snapshot.lastName, snapshot.dateOfBirth,
        snapshot.gender, snapshot.jobLabel, picture ~= '' and picture or nil)
end

-- A reissued copy prints the current names and job, like upstream.
function DocsRecords.Refresh(characterId, docType)
    local snapshot = DocsRecords.Snapshot(characterId)
    DB.exec([[
        UPDATE `bcc_documents` SET `first_name`=?,`last_name`=?,`date_of_birth`=?,`gender`=?,`job_label`=?
        WHERE `character_id`=? AND `doc_type`=?]],
        snapshot.firstName, snapshot.lastName, snapshot.dateOfBirth, snapshot.gender, snapshot.jobLabel,
        characterId, docType)
end

function DocsRecords.SetPicture(characterId, docType, picture)
    DB.exec('UPDATE `bcc_documents` SET `picture`=? WHERE `character_id`=? AND `doc_type`=?',
        picture, characterId, docType)
end

function DocsRecords.Delete(characterId, docType)
    DB.exec('DELETE FROM `bcc_documents` WHERE `character_id`=? AND `doc_type`=?', characterId, docType)
end

-- Dates are printed with the configured play year instead of the real one.
local function Date(seconds)
    if not seconds then
        return nil
    end
    return os.date(Config.PlayYear .. '-%m-%d %H:%M', math.floor(seconds))
end

-- The current license of a license document type, or nil (no license, or the
-- document is not a license).
function DocsRecords.License(characterId, docType)
    local key = Config.DocumentTypes[docType] and Config.DocumentTypes[docType].licenseKey
    if not key then
        return Docs.Ok(nil)
    end
    local check = DocsLicenses.Check(characterId, key)
    if not check.ok then
        return check
    end
    return Docs.Ok(check.value.licenseId and check.value or nil)
end

-- Everything the client needs to draw a document; nil when the character has none.
function DocsRecords.View(characterId, docType)
    local row = DocsRecords.Get(characterId, docType)
    if not row then
        return Docs.Ok(nil)
    end
    local view = {
        docType = docType,
        firstName = row.first_name,
        lastName = row.last_name,
        dateOfBirth = row.date_of_birth,
        gender = row.gender,
        jobLabel = row.job_label,
        picture = row.picture,
        issuedAt = Date(tonumber(row.issued_at_s))
    }
    if Config.DocumentTypes[docType].licenseKey then
        local license = DocsRecords.License(characterId, docType)
        if not license.ok then
            return license
        end
        if not license.value then
            view.status = 'revoked'
        else
            view.status = license.value.status == 'suspended' and 'suspended'
                or (license.value.expired and 'expired' or 'valid')
            view.expiresAt = license.value.expiresAt and Date(license.value.expiresAt / 1000) or nil
        end
    end
    return Docs.Ok(view)
end
