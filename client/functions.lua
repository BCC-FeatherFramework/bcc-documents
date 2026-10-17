-- feather-menu-v2 through the compatibility layer in client/feather/menu_v2.lua,
-- so the upstream menu layout keeps working. The menu is created on first use.

local documentsMenu

function DocumentsMenu()
    if documentsMenu then
        return documentsMenu
    end
    documentsMenu = FeatherMenuV2Compat:RegisterMenu('bcc-documents:mainmenu', {
        top = '5%',
        left = '5%',
        ['720width'] = '500px',
        ['1080width'] = '600px',
        ['2kwidth'] = '700px',
        ['4kwidth'] = '900px',
        style = {},
        contentslot = {
            style = {
                ['height'] = '350px',
                ['min-height'] = '250px'
            }
        },
        draggable = true
    }, {
        opened = function()
            DisplayRadar(false)
        end,
        closed = function()
            DisplayRadar(true)
        end
    })
    return documentsMenu
end
