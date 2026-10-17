Config = {
    -- Default Settings
    devMode = false,            -- Never true on a live server (enables DocumentsFlowTest)
    PlayYear = "1900",          -- Year shown on documents instead of the real one
    -- Language settings
    defaultlang = "en_lang",    -- Set Your Language (Current Languages: "en_lang" English, "ro_lang" Romanian)
    -- Command Settings
    NeedItem = true,            -- Set true or false, if you want to need an item to execute the commands
    NeedItemName = "paper",     -- Item consumed for each document given by command
    -- NPC and Blip settings
    DocumentBlips = true,
    DocumentNPC = true,
    DocumentLocations = {
        {
            coords = vector3(-175.29, 631.92, 114.09),
            NpcHeading = 326.82,
        },
        {
            coords = vector3(-798.53, -1194.58, 43.95),
            NpcHeading = 190.82,
        },
        {
            coords = vector3(1230.19, -1298.7, 76.9),
            NpcHeading = 230.74,
        },
        {
            coords = vector3(2747.9, -1396.45, 46.18),
            NpcHeading = 31.65,
        },
        {
            coords = vector3(2933.1, 1282.69, 44.65),
            NpcHeading = 74.53,
        },
    },
    -- Document types with associated details.
    -- Prices are whole dollars. expiryDays = 0 means the document never expires.
    -- licenseKey: the feather-licenses key this document stands for. A document
    -- without one (the ID card) is an identity paper, not a license.
    -- allowJob: feather-jobs job key allowed to give the document by command.
    DocumentTypes = {
        idcard = {
            displayName = "Identity Card",
            price = 15,
            reissuePrice = 20,
            changePhotoPrice = 10,
            extendPrice = 10,
            expiryDays = 0,  -- Set expiry duration by default
            defaultPicture = '',
            sellNpc = true,
            givenCommand = false,
            allowJob = "",
        },
        huntinglicence = {
            displayName = "Hunting Licence",
            licenseKey = "hunting",
            price = 10,
            reissuePrice = 30,
            changePhotoPrice = 10,
            extendPrice = 10,
            expiryDays = 1,  -- Set expiry duration by default
            defaultPicture ='',
            sellNpc = true,
            givenCommand = false,
            allowJob = "",
        },
        mininglicence = {
            displayName = "Mining Licence",
            licenseKey = "mining",
            price = 20,
            reissuePrice = 25,
            changePhotoPrice = 10,
            extendPrice = 10,
            expiryDays = 1,  -- Set expiry duration by default
            defaultPicture = '',
            sellNpc = true,
            givenCommand = false,
            allowJob = "",
        },
        lumberlicence = {
            displayName = "Lumber Licence",
            licenseKey = "lumber",
            price = 15,
            reissuePrice = 20,
            changePhotoPrice = 10,
            extendPrice = 10,
            expiryDays = 1,  -- Set expiry duration by default
            defaultPicture = '',
            sellNpc = true,
            givenCommand = false,
            allowJob = "",
        },
        goldpanninglicence = {
            displayName = "Gold Panning Licence",
            licenseKey = "goldpanning",
            price = 10,
            reissuePrice = 15,
            changePhotoPrice = 10,
            extendPrice = 10,
            expiryDays = 1,  -- Set expiry duration by default
            defaultPicture = '',
            sellNpc = true,
            givenCommand = false,
            allowJob = "",
        },
        weaponlicense = {
            displayName = "Weaponlicense",
            licenseKey = "weapons",
            price = 0,
            reissuePrice = 0,
            changePhotoPrice = 0,
            extendPrice = 0,
            expiryDays = 0,  -- Set expiry duration by default
            defaultPicture = '',
            sellNpc = false,
            givenCommand = "giveweaponlicense",
            allowJob = "doj",
        }
    },

    Textures = {
        ['cross'] = { "scoretimer_textures", "scoretimer_generic_cross" },
        ['locked'] = { "menu_textures", "stamp_locked_rank" },
        ['tick'] = { "scoretimer_textures", "scoretimer_generic_tick" },
        ['money'] = { "inventory_items", "money_moneystack" },
        ['alert'] = { "menu_textures", "menu_icon_alert" },
    }
}

-- Feather Framework integration.
Config.feather = {
    -- feather-economy currency for every price.
    currency = 'dollars',
    notifyStyle = 'right',
    -- Feather Admin staff holding one of these feather-authority capabilities may
    -- give any document by command (replaces VORP's AdminJob). By default only
    -- Admin administrators and owners hold staff.admin.audit.search.
    adminStaffCapabilities = { 'staff.admin.audit.search' },
    -- Longest extension a player can buy at once, and the longest a license may run.
    maxExtendDays = 30,
    maxLicenseDays = 365,
    -- A document can be shown to players within this distance (server-checked).
    showDistance = 3.0,
    -- Interaction distance at the licensing office.
    promptDistance = 2.0,
    -- Photo links: https only, at most this many characters.
    maxPhotoUrlLength = 512,
    -- feather-toolkit control for the office prompt (G).
    promptControl = 0x760A9C6F,
    npcModel = 'MP_POST_RELAY_MALES_01',
    blipSprite = 'blip_job_board'
}
