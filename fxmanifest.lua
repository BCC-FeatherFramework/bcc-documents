fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

author 'BCC Team'

description 'Documents System (Feather Framework port)'

shared_scripts {
	'config.lua',
	'shared/locale.lua',
	'languages/*.lua'
}

client_scripts {
	'client/feather/init.lua',
	'client/feather/menu_v2.lua',
	'client/functions.lua',
	'client/main.lua'
}

server_scripts {
	'@feather-mysql/lib/DB.lua',
	'server/feather/init.lua',
	'server/feather/economy.lua',
	'server/feather/licenses.lua',
	'server/feather/inventory.lua',
	'server/feather/jobs.lua',
	'server/feather/authority.lua',
	'server/services/migrations.lua',
	'server/services/documents.lua',
	'server/services/orders.lua',
	'server/main.lua',
	'server/tests.lua'
}

dependencies {
	'feather-mysql',
	'feather-core',
	'feather-character',
	'feather-notify',
	'feather-menu-v2',
	'feather-toolkit',
	'feather-economy',
	'feather-inventory',
	'feather-jobs',
	'feather-authority',
	'feather-licenses'
}

version '1.0.0'
