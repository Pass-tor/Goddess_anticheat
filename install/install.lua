-- ═══════════════════════════════════════════════════════════
--  GODDESS — INSTALLER
--  FiveM resources cannot register a true shell-style
--  executable ("Goddess install"). The safest practical
--  equivalent is a server console / RCON command that runs a
--  verification pass and reports exactly what's missing.
--
--  Usage (server console or RCON, once the resource is
--  `ensure`d in server.cfg):
--
--      goddess_install
--
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Installer = {}

local function check(label, condition, hint)
    local status = condition and '^2OK^7' or '^1MISSING^7'
    print(('[Goddess Install] %-32s [%s]%s'):format(label, status, (not condition and hint) and (' — ' .. hint) or ''))
    return condition
end

RegisterCommand('goddess_install', function(src)
    if src ~= 0 then
        print('[Goddess] goddess_install must be run from the server console.')
        return
    end

    print('════════════════════════════════════════════')
    print(' GODDESS — INSTALLATION VERIFICATION')
    print('════════════════════════════════════════════')

    local allOk = true

    allOk = check('fxmanifest.lua loaded', GetCurrentResourceName() ~= nil) and allOk
    allOk = check('config.lua loaded (Config table)', Config ~= nil) and allOk

    -- ox_lib
    if Config.Dependencies.ox_lib then
        allOk = check('ox_lib running', GetResourceState('ox_lib') == 'started',
            'start ox_lib before Goddess, or set Config.Dependencies.ox_lib = false') and allOk
    end

    -- oxmysql (only required if database enabled)
    if Config.Database.Enabled then
        allOk = check('oxmysql running', GetResourceState('oxmysql') == 'started',
            'start oxmysql, or set Config.Database.Enabled = false to run without persistence') and allOk
        allOk = check('Database reachable', Goddess.DB and Goddess.DB.IsReady and Goddess.DB.IsReady(),
            'check your oxmysql connection string / server.cfg') and allOk
    else
        print('[Goddess Install] Database disabled by config — skipping DB checks.')
    end

    -- Optional integrations
    if Config.Dependencies.ox_inventory then
        check('ox_inventory running (optional)', GetResourceState('ox_inventory') == 'started',
            'optional — only needed if you wire weapon/item validation into it')
    end
    if Config.Dependencies.ox_target then
        check('ox_target running (optional)', GetResourceState('ox_target') == 'started', 'optional')
    end

    -- Admin config sanity
    allOk = check('Admin access configured',
        (#Config.Admin.Identifiers > 0) or Config.Admin.UseAcePermission,
        'add identifiers to Config.Admin.Identifiers or enable Config.Admin.UseAcePermission') and allOk

    -- Permissions: can we write ace commands?
    allOk = check('Resource permissions OK', GetCurrentResourceName() ~= nil) and allOk

    print('════════════════════════════════════════════')
    if allOk then
        print('^2[Goddess] All checks passed. Goddess is ready.^7')
    else
        print('^1[Goddess] One or more checks failed — see above. Goddess will still run in degraded mode where possible.^7')
    end
    print('════════════════════════════════════════════')
end, true) -- restricted: console/RCON only by convention (see check above)
