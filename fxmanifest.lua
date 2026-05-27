fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Poud'
description 'ESX mining script with ox_target support'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'esx_progressbar',
    'Poud_notify',
    'Poud_progress'
}
