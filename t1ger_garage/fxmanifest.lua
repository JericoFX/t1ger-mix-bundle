-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

fx_version 'cerulean'
games {'gta5'}
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Garage'
version '1.1.0'

locale 'en'

files {
    'locales/*.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'language.lua',
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

exports {
    'SetVehicleImpounded'
}

escrow_ignore {
    'config.lua',
    'language.lua',
    'client/*.lua',
    'server/*.lua'
}
