fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Muhaddil'
description 'Un script de ambulancias automaticas para FiveM'

version 'v1.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_script {
    -- '@async/async.lua',
    -- '@mysql-async/lib/MySQL.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

client_script {
    'client/*.lua',
}

files {
    'locales/*.json',
}
