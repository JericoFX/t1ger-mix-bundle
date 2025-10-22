-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

fx_version 'cerulean'
games {'gta5'}
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Bank Robbery'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared.lua',
    'language.lua',
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/main.lua',
    'client/drilling.lua',
    'client/safecrack.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'ox_lib'

escrow_ignore {
    'config.lua',
    'language.lua',
    'client/*.lua',
    'server/*.lua'
}
