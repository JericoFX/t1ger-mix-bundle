-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

fx_version 'cerulean'
games {'gta5'}
lua54 'yes'

author 'T1GER#9080'
discord 'https://discord.gg/FdHkq5q'
description 'T1GER Yacht Heist'
version '1.0.0'

shared_scripts {
        '@ox_lib/init.lua'
}

client_scripts {
        'language.lua',
        'config.lua',
        'client/utils.lua',
        'client/main.lua'
}

server_scripts {
        '@mysql-async/lib/MySQL.lua',
        'language.lua',
        'config.lua',
        'server/main.lua'
}

dependency 'ox_lib'

escrow_ignore {
    "config.lua",
    "language.lua",
    "client/*.lua",
    "server/*.lua",
}