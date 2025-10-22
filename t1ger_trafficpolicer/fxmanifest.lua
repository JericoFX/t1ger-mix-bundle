-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

fx_version 'cerulean'
games {'gta5'}
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Traffic Policer (Breathalyzer, ANPR, Traffic Offenses, Drug Swab & More)'
version '1.0.2'

shared_script '@ox_lib/init.lua'

client_scripts {
    'language.lua',
    'config.lua',
    'client/utils.lua',
    'client/main.lua',
    'client/effects.lua',
    'client/anpr.lua',
    'client/citations.lua',
    'client/speed.lua'
}


server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'language.lua',
    'config.lua',
    'server/main.lua'
}

exports {}

escrow_ignore {
    "config.lua",
    "language.lua",
    "client/*.lua",
    "server/*.lua",
}
