-- ═══════════════════════════════════════════════════════════
--  GODDESS — UNINSTALLER
--  FiveM resources cannot delete their own files or unload
--  arbitrary other resources' data — Lua sandboxing in FXServer
--  has no filesystem-write API for this. The safest practical
--  uninstall flow is:
--
--    1. Run `goddess_uninstall` in the server console. This
--       stops the resource cleanly and prints the exact manual
--       steps left (removing the folder + server.cfg line),
--       plus an optional scoped database purge.
--    2. Remove `ensure Goddess` (or `start Goddess`) from
--       server.cfg.
--    3. Delete the resources/Goddess folder.
--
--  The optional database purge ONLY ever touches tables using
--  Config.Database.TablePrefix (default `goddess_`) — it will
--  never drop or modify unrelated tables.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}

RegisterCommand('goddess_uninstall', function(src, args)
    if src ~= 0 then
        print('[Goddess] goddess_uninstall must be run from the server console.')
        return
    end

    local purge = args[1] == '--purge-database'

    print('════════════════════════════════════════════')
    print(' GODDESS — UNINSTALL')
    print('════════════════════════════════════════════')

    if purge and Goddess.DB and Goddess.DB.IsReady and Goddess.DB.IsReady() then
        print('[Goddess] Purging Goddess-owned tables only (prefix: ' .. Config.Database.TablePrefix .. ')…')
        Goddess.Utils.Safe(function()
            exports.oxmysql:execute('DROP TABLE IF EXISTS ' .. Goddess.DB.TableName('bans'), {})
            exports.oxmysql:execute('DROP TABLE IF EXISTS ' .. Goddess.DB.TableName('detections'), {})
            exports.oxmysql:execute('DROP TABLE IF EXISTS ' .. Goddess.DB.TableName('detection_history'), {})
        end)
        print('[Goddess] Goddess-prefixed tables dropped. No other tables were touched.')
    elseif purge then
        print('[Goddess] --purge-database requested but the database is not currently reachable. No tables were dropped.')
    else
        print('[Goddess] Database left untouched. Re-run with `goddess_uninstall --purge-database` to drop only Goddess-owned tables.')
    end

    print('[Goddess] Stopping resource…')
    print('════════════════════════════════════════════')
    print('MANUAL STEPS REMAINING:')
    print('  1. Remove `ensure Goddess` / `start Goddess` from server.cfg')
    print('  2. Delete the resources/Goddess folder')
    print('  3. Remove any Config.Admin.Identifiers / ace grants you added for goddess.admin')
    print('════════════════════════════════════════════')

    StopResource(GetCurrentResourceName())
end, true)
