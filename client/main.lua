-- bcc-documents client: licensing office (prompt, NPC, blip) and document views.
-- Every action is a server RPC; the server decides prices, identity and results.

local createdBlips = {}
local createdPeds = {}
local promptGroup = GetRandomIntInRange(1, 0xffffff)
local promptId
local mainPage

local function DebugPrint(...)
    if Config.devMode then
        print(...)
    end
end

local function Toolkit(operation, ...)
    local called, result = pcall(function(...)
        return exports['feather-toolkit'][operation](exports['feather-toolkit'], ...)
    end, ...)
    if not called or type(result) ~= 'table' or result.ok ~= true then
        DebugPrint(('[bcc-documents] toolkit %s failed: %s'):format(operation,
            called and type(result) == 'table' and tostring(result.code) or tostring(result)))
        return nil
    end
    return result.value
end

local function Price(value)
    return '$' .. tostring(value or 0)
end

-- Office ------------------------------------------------------------------------

local function SetupOffice()
    local prompt = Toolkit('CreatePrompt', {
        label = _U('PromptName'),
        control = Config.feather.promptControl,
        groupId = promptGroup,
        mode = 'hold',
        holdMode = 'MEDIUM_TIMED_EVENT',
        pulsing = false
    })
    promptId = prompt and prompt.id
    for _, location in pairs(Config.DocumentLocations) do
        if Config.DocumentBlips then
            local blip = Toolkit('CreateBlip', {
                x = location.coords.x, y = location.coords.y, z = location.coords.z,
                sprite = GetHashKey(Config.feather.blipSprite),
                name = _U('BlipName')
            })
            if blip then
                createdBlips[#createdBlips + 1] = blip.id
            end
        end
        if Config.DocumentNPC then
            local ped = Toolkit('CreatePed', {
                model = Config.feather.npcModel,
                x = location.coords.x, y = location.coords.y, z = location.coords.z - 1.0,
                heading = location.NpcHeading,
                networked = false,
                scriptHost = true
            })
            if ped then
                createdPeds[#createdPeds + 1] = ped.id
                FreezeEntityPosition(ped.entity, true)
                SetEntityInvincible(ped.entity, true)
                SetBlockingOfNonTemporaryEvents(ped.entity, true)
                SetEntityCanBeDamaged(ped.entity, false)
            end
        end
    end
end

CreateThread(function()
    SetupOffice()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, location in pairs(Config.DocumentLocations) do
            if #(playerCoords - location.coords) < Config.feather.promptDistance and promptId then
                sleep = 0
                exports['feather-toolkit']:ShowPromptGroup(promptGroup, _U('Licenses'))
                local state = exports['feather-toolkit']:IsPromptCompleted(promptId)
                if type(state) == 'table' and state.ok and state.value.completed then
                    OpenMenu()
                end
            end
        end
        Wait(sleep)
    end
end)

-- Office menus --------------------------------------------------------------------

local function Footer(page, back)
    page:RegisterElement('line', { slot = 'footer', style = {} })
    if back then
        page:RegisterElement('button', { label = _U('BackButton'), slot = 'footer', style = {} }, back)
    end
    page:RegisterElement('bottomline', { slot = 'footer', style = {} })
end

function OpenMenu()
    local menu = DocumentsMenu()
    if not menu then
        return
    end
    mainPage = menu:RegisterPage('Main:Page')
    mainPage:RegisterElement('header', { value = _U('Licenses'), slot = 'header', style = {} })
    mainPage:RegisterElement('line', { slot = 'header', style = {} })
    for docType, settings in pairs(Config.DocumentTypes) do
        if settings.sellNpc then
            mainPage:RegisterElement('button', { label = settings.displayName, style = {} }, function()
                OpenDocumentSubMenu(docType)
            end)
        end
    end
    mainPage:RegisterElement('bottomline', { style = {} })
    menu:Open({ startupPage = mainPage })
end

function OpenDocumentSubMenu(docType)
    local menu = DocumentsMenu()
    local docConfig = Config.DocumentTypes[docType]
    local page = menu:RegisterPage('submenu:' .. docType)
    page:RegisterElement('header', { value = docConfig.displayName, slot = 'header', style = {} })
    page:RegisterElement('button', { label = _U('RegisterDoc') .. ' - ' .. Price(docConfig.price), style = {} },
        function()
            DocsRPC.Send('bcc-documents:Buy', { docType = docType })
        end)
    if docType == 'idcard' then
        page:RegisterElement('button', {
            label = _U('ChangePicture') .. ' - ' .. Price(docConfig.changePhotoPrice), style = {}
        }, function()
            ChangeDocumentPhoto(docType)
        end)
    end
    page:RegisterElement('button', { label = _U('DocumentLost') .. ' - ' .. Price(docConfig.reissuePrice), style = {} },
        function()
            DocsRPC.Send('bcc-documents:Reissue', { docType = docType })
        end)
    if docConfig.licenseKey and (tonumber(docConfig.expiryDays) or 0) > 0 then
        page:RegisterElement('button', {
            label = _U('ExtendExpiry') .. ' - ' .. Price(docConfig.extendPrice), style = {}
        }, function()
            AddExpiryDate(docType)
        end)
    end
    Footer(page, function()
        OpenMenu()
    end)
    menu:Open({ startupPage = page })
end

function ChangeDocumentPhoto(docType)
    local menu = DocumentsMenu()
    local page = menu:RegisterPage('change:photo')
    local photoLink
    page:RegisterElement('header', { value = Config.DocumentTypes[docType].displayName, slot = 'header', style = {} })
    page:RegisterElement('input', {
        label = _U('InputPhotolink'),
        placeholder = _U('PastePhotoLink'),
        persist = false,
        style = {}
    }, function(data)
        photoLink = data.value ~= '' and data.value or nil
    end)
    page:RegisterElement('line', { slot = 'footer', style = {} })
    page:RegisterElement('button', { label = _U('Submit'), slot = 'footer', style = {} }, function()
        if photoLink then
            DocsRPC.Send('bcc-documents:ChangePhoto', { docType = docType, url = photoLink })
            OpenDocumentSubMenu(docType)
        else
            Notify(_U('InvalidPhoto'), 4000)
        end
    end)
    page:RegisterElement('button', { label = _U('BackButton'), slot = 'footer', style = {} }, function()
        OpenDocumentSubMenu(docType)
    end)
    page:RegisterElement('bottomline', { slot = 'footer', style = {} })
    menu:Open({ startupPage = page })
end

function AddExpiryDate(docType)
    local menu = DocumentsMenu()
    local page = menu:RegisterPage('input:expiry')
    local days
    page:RegisterElement('header', { value = Config.DocumentTypes[docType].displayName, slot = 'header', style = {} })
    page:RegisterElement('number', {
        label = _U('EnterExpiryDays'),
        placeholder = _U('NumberOfDays'),
        min = 1,
        max = Config.feather.maxExtendDays,
        step = 1,
        style = {}
    }, function(data)
        days = tonumber(data.value)
    end)
    page:RegisterElement('line', { slot = 'footer', style = {} })
    page:RegisterElement('button', { label = _U('Confirm'), slot = 'footer', style = {} }, function()
        if days and days >= 1 and days <= Config.feather.maxExtendDays and days % 1 == 0 then
            DocsRPC.Send('bcc-documents:Extend', { docType = docType, days = days })
            OpenDocumentSubMenu(docType)
        else
            Notify(_U('InvalidDays') .. Config.feather.maxExtendDays, 4000)
        end
    end)
    page:RegisterElement('button', { label = _U('BackButton'), slot = 'footer', style = {} }, function()
        OpenDocumentSubMenu(docType)
    end)
    page:RegisterElement('bottomline', { slot = 'footer', style = {} })
    menu:Open({ startupPage = page })
end

-- Document views ------------------------------------------------------------------

local function Lines(view)
    local unknown = _U('Unknown')
    local gender = view.gender == 'male' and _U('Male') or (view.gender == 'female' and _U('Female') or unknown)
    local lines = {
        _U('Firstname') .. (view.firstName or unknown),
        _U('Lastname') .. (view.lastName or unknown),
        _U('DateOfBirth') .. (view.dateOfBirth or unknown),
        _U('Gender') .. gender,
        _U('Job') .. (view.jobLabel or unknown),
        _U('CreationDate') .. (view.issuedAt or unknown)
    }
    if view.status then
        local statuses = {
            valid = _U('StatusValid'), expired = _U('StatusExpired'),
            suspended = _U('StatusSuspended'), revoked = _U('StatusRevoked')
        }
        lines[#lines + 1] = _U('ExpiryDate') .. (view.expiresAt or 'N/A')
        lines[#lines + 1] = _U('Status') .. (statuses[view.status] or view.status)
    end
    return table.concat(lines, '\n')
end

local function Header(page, view)
    page:RegisterElement('header', { value = Config.DocumentTypes[view.docType].displayName, slot = 'header' })
    page:RegisterElement('line', { slot = 'header' })
    if type(view.picture) == 'string' and view.picture ~= '' then
        page:RegisterElement('imagebox', { image = view.picture, alt = _U('ChangePicture'), slot = 'header' })
    end
    page:RegisterElement('textdisplay', { value = Lines(view) })
end

-- A document someone shows you.
function ShowDocument(view)
    local menu = DocumentsMenu()
    local page = menu:RegisterPage('show:document')
    Header(page, view)
    page:RegisterElement('line', { slot = 'footer', style = {} })
    page:RegisterElement('button', { label = _U('CloseMenu'), slot = 'footer', style = {} }, function()
        menu:Close()
    end)
    page:RegisterElement('bottomline', { slot = 'footer', style = {} })
    menu:Open({ startupPage = page })
end

-- Your own document, opened from the inventory.
function OpenDocument(view)
    local menu = DocumentsMenu()
    local page = menu:RegisterPage('open:document')
    Header(page, view)
    page:RegisterElement('line', { slot = 'footer', style = {} })
    page:RegisterElement('button', { label = _U('ShowDocument'), slot = 'footer', style = {} }, function()
        OpenShowToPlayerMenu(view)
    end)
    page:RegisterElement('button', { label = _U('RevokeDocument'), slot = 'footer', style = {} }, function()
        DocsRPC.Send('bcc-documents:Revoke', { docType = view.docType })
        menu:Close()
    end)
    page:RegisterElement('button', { label = _U('PutBack'), slot = 'footer', style = {} }, function()
        menu:Close()
    end)
    page:RegisterElement('bottomline', { slot = 'footer', style = {} })
    menu:Open({ startupPage = page })
end

local function NearbyPlayers()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearby = {}
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= playerPed and #(playerCoords - GetEntityCoords(targetPed)) < Config.feather.showDistance then
            nearby[#nearby + 1] = { id = GetPlayerServerId(player), name = GetPlayerName(player) }
        end
    end
    return nearby
end

function OpenShowToPlayerMenu(view)
    local menu = DocumentsMenu()
    local page = menu:RegisterPage('playerMenu')
    page:RegisterElement('header', { value = _U('ChoosePlayer'), slot = 'header' })
    local players = NearbyPlayers()
    if #players == 0 then
        page:RegisterElement('textdisplay', { value = _U('NoNearbyPlayer'), style = {} })
    end
    for _, player in ipairs(players) do
        page:RegisterElement('button', { label = player.name, style = {} }, function()
            DocsRPC.Send('bcc-documents:Show', { docType = view.docType, target = player.id })
        end)
    end
    Footer(page, function()
        OpenDocument(view)
    end)
    menu:Open({ startupPage = page })
end

DocsRPC.Register('bcc-documents:client:Open', function(params)
    if type(params.view) == 'table' and Config.DocumentTypes[params.view.docType] then
        OpenDocument(params.view)
    end
end)

DocsRPC.Register('bcc-documents:client:Show', function(params)
    if type(params.view) == 'table' and Config.DocumentTypes[params.view.docType] then
        ShowDocument(params.view)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    for _, id in ipairs(createdPeds) do
        exports['feather-toolkit']:RemoveEntity(id)
    end
    for _, id in ipairs(createdBlips) do
        exports['feather-toolkit']:RemoveBlip(id)
    end
    if promptId then
        exports['feather-toolkit']:RemovePrompt(promptId)
    end
end)
