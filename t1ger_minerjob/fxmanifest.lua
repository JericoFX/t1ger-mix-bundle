-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Miner Job'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
    'language.lua',
    'config.lua',
    'client/utils.lua',
    'client/main.lua'
}

server_scripts {
    'language.lua',
    'config.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'qb-core'
}

escrow_ignore {
    "config.lua",
    "language.lua",
    "client/*.lua",
    "server/*.lua"
}
