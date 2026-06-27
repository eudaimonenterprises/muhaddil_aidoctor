fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Muhaddil'
description 'An automated ambulance script for FiveM'
version 'v1.0.2'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

-- FIXED: Added 's' to server_scripts and removed deprecated qbx load injection
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

-- FIXED: Added 's' to client_scripts
client_scripts {
    'client/*.lua',
}

files {
    'locales/*.json',
}
