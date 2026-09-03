fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Goddess'
author 'Goddess Development'
description 'Modular server-authoritative security system for ESX Legacy servers'
version '1.0.0'

-- ─────────────────────────────────────────────
--  SHARED
-- ─────────────────────────────────────────────
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
}

-- ─────────────────────────────────────────────
--  CLIENT
-- ─────────────────────────────────────────────
client_scripts {
    'client/modules/state.lua',
    'client/modules/scanner.lua',
    'client/detections/player.lua',
    'client/detections/weapon.lua',
    'client/detections/vehicle.lua',
    'client/detections/entity.lua',
    'client/main.lua',
}

-- ─────────────────────────────────────────────
--  SERVER
-- ─────────────────────────────────────────────
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/logging.lua',
    'server/admin.lua',
    'server/punishment.lua',
    'server/security.lua',
    'server/secure_event.lua',
    'server/detections/player.lua',
    'server/detections/weapon.lua',
    'server/detections/vehicle.lua',
    'server/detections/entity.lua',
    'server/detections/explosion.lua',
    'server/detections/event.lua',
    'server/main.lua',
    'install/install.lua',
    'install/uninstall.lua',
}

-- ─────────────────────────────────────────────
--  NUI DASHBOARD
-- ─────────────────────────────────────────────
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

-- ─────────────────────────────────────────────
--  EXPORTS
-- ─────────────────────────────────────────────
exports {
    'RegisterSecureEvent',
    'GetSuspicionScore',
    'ClearSuspicion',
    'IsGoddessAdmin',
}

server_exports {
    'RegisterSecureEvent',
    'GetSuspicionScore',
    'ClearSuspicion',
    'IsGoddessAdmin',
    'BanPlayer',
    'KickPlayer',
}

dependencies {
    'ox_lib',
}
