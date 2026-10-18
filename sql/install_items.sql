-- bcc-documents item definitions for feather-inventory.
-- Safe to run more than once: existing items keep their IDs and settings.
-- Apply once, then restart feather-inventory and bcc-documents.
--
-- Each document is a display copy: one per character (max_quantity 1). The
-- record behind it lives in bcc_documents, and licenses in feather-licenses.

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'idcard', 'Identification Card', 'You need an ID card to be registered.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'idcard');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'huntinglicence', 'Hunting Licence', 'You need a licence when you go hunting. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'huntinglicence');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'mininglicence', 'Mining Licence', 'You cannot go into the mine without this licence. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'mininglicence');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'lumberlicence', 'Lumberjack Licence', 'You cannot cut wood without this licence. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'lumberlicence');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'goldpanninglicence', 'Gold Panning Licence', 'You cannot pan the river without this licence. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'goldpanninglicence');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weaponlicense', 'Weapon Licence', 'Permission to carry weapons. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weaponlicense');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'peaceofficer', 'Peace Officer Commission', 'Commission as a peace officer, granted by the Sheriff. The licensing office records it.', 1, 1, 0.1, 1,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'peaceofficer');

-- Paper: used up when an officer gives a document by command (Config.NeedItem).
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'paper', 'Paper', 'A blank sheet for official documents.', 50, 50, 0.01, 0,
    (SELECT `id` FROM `categories` WHERE `name` = 'documents'), 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'paper');
