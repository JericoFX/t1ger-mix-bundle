fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

author 'T1GER#9080'
description 'T1GER Deliveries - QBCore/ox_lib migration'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'language.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/utils.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

escrow_ignore {
    'config.lua',
    'language.lua',
    'shared/*.lua',
    'client/*.lua',
    'server/*.lua'
}

dependency 'ox_lib'
