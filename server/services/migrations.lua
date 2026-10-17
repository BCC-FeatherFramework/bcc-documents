-- bcc-documents' own tables. Applied in order on start; each step is idempotent.
--
-- bcc_documents: one row per character and document type, with the details
-- printed on the document (names, job, photo). For a license document the
-- license itself lives in feather-licenses (license_id); expiry and status are
-- read from there, never stored here.
-- bcc_documents_orders: every paid action (purchase, extension, reissue, photo,
-- officer issue) as a durable workflow, so a payment is never lost when a later
-- step fails; see DocumentsOrdersReport / DocumentsOrdersRetry.

DocsMigrations = {}

local statements = {
    [[CREATE TABLE IF NOT EXISTS `bcc_documents` (
        `character_id` CHAR(36) NOT NULL,
        `doc_type` VARCHAR(50) NOT NULL,
        `license_id` CHAR(36) NULL,
        `first_name` VARCHAR(64) NULL,
        `last_name` VARCHAR(64) NULL,
        `date_of_birth` VARCHAR(16) NULL,
        `gender` VARCHAR(16) NULL,
        `job_label` VARCHAR(100) NULL,
        `picture` VARCHAR(512) NULL,
        `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`character_id`,`doc_type`),
        KEY `idx_bcc_documents_license` (`license_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `bcc_documents_orders` (
        `order_id` CHAR(36) NOT NULL,
        `character_id` CHAR(36) NOT NULL,
        `doc_type` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `currency` VARCHAR(32) NOT NULL,
        `amount` BIGINT UNSIGNED NOT NULL DEFAULT 0,
        `payload_json` LONGTEXT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
        `economy_transaction_id` CHAR(36) NULL,
        `last_error` VARCHAR(255) NULL,
        `note` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`order_id`),
        KEY `idx_bcc_documents_orders_status` (`status`,`created_at`),
        KEY `idx_bcc_documents_orders_character` (`character_id`,`created_at`),
        CONSTRAINT `chk_bcc_documents_orders_status`
            CHECK (`status` IN ('pending','paid','fulfilled','rejected','review'))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
}

function DocsMigrations.Run()
    -- An upstream (VORP) bcc_documents table keyed by VORP character numbers
    -- cannot be mapped to Feather character UUIDs; keep it aside untouched.
    local legacy = DB.value([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bcc_documents' AND COLUMN_NAME = 'charidentifier']])
    if tonumber(legacy) and tonumber(legacy) > 0 then
        DB.exec('RENAME TABLE `bcc_documents` TO `bcc_documents_vorp_legacy`')
        Docs.Log('migration.legacy_table_renamed', { table = 'bcc_documents_vorp_legacy' })
    end
    for _, statement in ipairs(statements) do
        DB.exec(statement)
    end
    return Docs.Ok(true)
end
