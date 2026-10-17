-- bcc-documents' boundary to feather-inventory.
--
-- A document item is a display copy: a stack item limited to one per character
-- (sql/install_items.sql). Using it shows the holder's own record from
-- bcc_documents, as upstream did. GrantCharacterItem delivers it to online and
-- offline characters alike.
--
-- Inventory errors are { ok = false, error = { code, message } }; this file
-- returns flat { ok = false, code, message } like the other domains.

DocsInventory = {}

local RESOURCE = 'feather-inventory'
local api

local function Flat(result)
    if type(result) ~= 'table' then
        return Docs.Err('dependency_unavailable', 'Inventory returned no result.')
    end
    if result.ok then
        return result
    end
    local problem = type(result.error) == 'table' and result.error or {}
    return Docs.Err(problem.code or result.code or 'inventory_failed', problem.message or result.message)
end

local function Api()
    if api then
        return api
    end
    if GetResourceState(RESOURCE) ~= 'started' then
        return nil
    end
    local called, value = pcall(function()
        return exports[RESOURCE]:initiate()
    end)
    api = called and type(value) == 'table' and value or nil
    return api
end

local function CharacterInventory(characterId)
    local inventory = Api()
    if not inventory then
        return Docs.Err('dependency_unavailable', 'Inventory API is unavailable.')
    end
    local found = Flat(inventory.Inventory.GetCharacterInventory(characterId))
    if not found.ok or type(found.value) ~= 'table' or not found.value.id then
        return Docs.Err(found.code or 'inventory_not_found', 'Character inventory not found.')
    end
    return Docs.Ok(found.value.id)
end

function DocsInventory.ItemExists(itemName)
    local inventory = Api()
    if not inventory then
        return false
    end
    local exists = inventory.Items.ItemExists(itemName)
    return type(exists) == 'table' and exists.ok == true and exists.value == true
end

-- Gives one document copy to a character, online or offline.
function DocsInventory.GiveDocument(characterId, docType)
    return Flat(Docs.Call(RESOURCE, 'GrantCharacterItem', characterId, docType, 1, 'bcc-documents.document'))
end

-- Number of copies of a document type a character carries (online or offline).
function DocsInventory.CountDocuments(characterId, docType)
    local inventory = Api()
    if not inventory then
        return Docs.Err('dependency_unavailable', 'Inventory API is unavailable.')
    end
    local target = CharacterInventory(characterId)
    if not target.ok then
        return target
    end
    local items = Flat(inventory.Inventory.GetInventoryItems(target.value))
    if not items.ok then
        return items
    end
    local count = 0
    for _, item in ipairs(items.value or {}) do
        if item.name == docType then
            count = count + (tonumber(item.quantity) or 1)
        end
    end
    return Docs.Ok(count)
end

-- True when a connected player's inventory can take one more of the item.
function DocsInventory.CanHold(src, itemName)
    local inventory = Api()
    if not inventory or not src then
        return true
    end
    local result = inventory.Inventory.InventoryCanHold({ { item = itemName, quantity = 1 } }, src)
    return type(result) == 'table' and result.ok == true and type(result.value) == 'table'
        and result.value.accepted == true
end

-- Removes every copy of a document type from a character's inventory.
function DocsInventory.RemoveDocuments(characterId, docType)
    local inventory = Api()
    if not inventory then
        return Docs.Err('dependency_unavailable', 'Inventory API is unavailable.')
    end
    local target = CharacterInventory(characterId)
    if not target.ok then
        return target
    end
    local items = Flat(inventory.Inventory.GetInventoryItems(target.value))
    if not items.ok then
        return items
    end
    local removed = 0
    for _, item in ipairs(items.value or {}) do
        if item.name == docType then
            if Flat(inventory.Items.RemoveItemById(item.id)).ok then
                removed = removed + 1
            end
        end
    end
    return Docs.Ok(removed)
end

function DocsInventory.Count(src, itemName)
    local inventory = Api()
    if not inventory then
        return 0
    end
    local result = inventory.Items.GetItemCount(itemName, src)
    return type(result) == 'table' and result.ok and (tonumber(result.value) or 0) or 0
end

function DocsInventory.RemoveByName(src, itemName, quantity)
    local inventory = Api()
    if not inventory then
        return Docs.Err('dependency_unavailable', 'Inventory API is unavailable.')
    end
    return Flat(inventory.Items.RemoveItemByName(itemName, quantity, src))
end

function DocsInventory.Close(src)
    local inventory = Api()
    if inventory then
        inventory.Inventory.CloseInventory(src)
    end
end

-- Registers a usable item; handler(src, item).
function DocsInventory.RegisterUsable(itemName, handler)
    local inventory = Api()
    if not inventory then
        return Docs.Err('dependency_unavailable', 'Inventory API is unavailable.')
    end
    return Flat(inventory.Items.RegisterUsableItem(itemName, function(item, src)
        handler(src, item)
    end))
end

AddEventHandler('onResourceStart', function(resource)
    if resource == RESOURCE then
        api = nil
    end
end)
