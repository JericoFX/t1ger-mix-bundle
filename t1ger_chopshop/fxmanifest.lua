-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Chop Shop'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'language.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/utils.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql'
}

escrow_ignore {
    "config.lua",
    "language.lua",
    "client/*.lua",
    "server/*.lua",
}