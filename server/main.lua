-- ═══════════════════════════════════════════════════════════
--  GODDESS — SERVER MAIN
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}

-- ─────────────────────────────────────────────
--  RESOURCE START
-- ─────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Goddess.Utils.Print(('Goddess v%s starting…'):format(Goddess.Version))

    Goddess.DB.Init(function(ok)
        if ok then
            Goddess.Utils.Print('Database ready.')
        else
            Goddess.Utils.Print('Running without database persistence (bans/detections are session-only).')
        end
    end)

    if #Config.Admin.Identifiers == 0 and not Config.Admin.UseAcePermission then
        Goddess.Utils.Error('No admin identifiers configured and ace permissions disabled — nobody can access admin commands. See config.lua Config.Admin.')
    end

    Goddess.Log.Security('Goddess Started', ('Version %s initialized on this server.'):format(Goddess.Version))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Goddess.Log.Security('Goddess Stopped', 'The security resource has been stopped. The server is currently unprotected by Goddess.')
end)

-- ─────────────────────────────────────────────
--  CLIENT SIGNAL ROUTER
--  All client-side detection modules funnel their raw signals
--  through this single event. Nothing here is trusted at face
--  value — each handler re-validates before scoring.
-- ─────────────────────────────────────────────
RegisterNetEvent(Goddess.Events.SIGNAL, function(signalType, payload)
    local src = source
    if not src or src == 0 then return end
    if GetPlayerName(src) == nil then return end -- invalid source

    Goddess.Utils.Safe(function()
        if signalType == 'position' then
            Goddess.Detect.Player.OnPositionSignal(src, payload)
        elseif signalType == 'vehicle_position' then
            Goddess.Detect.Vehicle.OnPositionSignal(src, payload.netId, payload)
        elseif signalType == 'shot_fired' then
            Goddess.Detect.Weapon.OnShotFired(src, payload.weaponHash)
        elseif signalType == 'ammo_check' then
            Goddess.Detect.Weapon.ValidateAmmoDelta(src, payload.weaponHash, payload.previousAmmo, payload.currentAmmo, payload.shotsSinceLast)
        elseif signalType == 'revive' then
            Goddess.Security.MarkRevive(src)
        elseif signalType == 'vehicle_transition' then
            Goddess.Security.MarkVehicleTransition(src)
        elseif signalType == 'legit_teleport' then
            Goddess.Security.MarkLegitTeleport(src)
        else
            -- generic pass-through detections: invisible, superjump,
            -- stamina, noclip, freecam, ragdoll, model_change
            Goddess.Detect.Player.OnClientSignal(src, signalType, payload and payload.details)
        end
    end)
end)

-- ─────────────────────────────────────────────
--  PERIODIC SERVER-SIDE POLLING
--  Adaptive: elevated (suspicious) players get polled more
--  frequently via a per-player thread; everyone else is swept
--  on the normal interval.
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.Scanning.NormalIntervalMs)
        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            Goddess.Utils.Safe(Goddess.Detect.Player.CheckHealthArmor, src)

            local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
            if veh and veh ~= 0 then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                Goddess.Utils.Safe(Goddess.Detect.Vehicle.CheckGodmode, src, netId)
                Goddess.Utils.Safe(Goddess.Detect.Vehicle.CheckPlate, src, netId)
            end
        end
    end
end)

-- ─────────────────────────────────────────────
--  MAINTENANCE (history purge)
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(6 * 60 * 60 * 1000) -- every 6 hours
        Goddess.Utils.Safe(Goddess.DB.PurgeOldHistory)
    end
end)

-- ─────────────────────────────────────────────
--  NUI DASHBOARD DATA
-- ─────────────────────────────────────────────
RegisterNetEvent('goddess:requestDashboardData', function()
    local src = source
    if not Goddess.Admin.IsAdmin(src) then return end

    local players = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        table.insert(players, {
            id = id,
            name = GetPlayerName(id),
            score = Goddess.Security.GetScore(id),
            elevated = Goddess.Security.IsElevated(id),
        })
    end

    Goddess.DB.GetRecentDetections(50, function(detections)
        Goddess.DB.GetAllBans(function(bans)
            TriggerClientEvent('goddess:nuiData', src, {
                version = Goddess.Version,
                dbReady = Goddess.DB.IsReady(),
                players = players,
                detections = detections,
                bans = bans,
            })
        end)
    end)
end)

RegisterNetEvent('goddess:nuiAction', function(action, data)
    local src = source
    if not Goddess.Admin.IsAdmin(src) then return end
    local adminName = GetPlayerName(src)

    if action == 'kick' and data.id then
        Goddess.Punishment.Kick(tonumber(data.id), data.reason or 'Kicked via Goddess dashboard', 'manual', adminName)
    elseif action == 'ban' and data.id then
        Goddess.Punishment.Ban(tonumber(data.id), data.reason or Config.Punishment.DefaultBanReason, 'manual', adminName, tonumber(data.minutes) or 0)
    elseif action == 'unban' and data.license then
        Goddess.DB.Unban(data.license)
        Goddess.Log.AdminAction({ admin = adminName, action = 'unban', target = data.license })
    elseif action == 'clear' and data.id then
        Goddess.Security.ClearScore(tonumber(data.id))
        Goddess.Log.AdminAction({ admin = adminName, action = 'clear_suspicion', target = data.id })
    end
end)
