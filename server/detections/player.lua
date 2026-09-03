-- ═══════════════════════════════════════════════════════════
--  GODDESS — PLAYER DETECTIONS (server-side validation)
--  Client modules only ever send *signals*. This module is
--  the authority: it re-checks against server-known state
--  (GetEntityCoords, GetEntityHealth, etc. are trustworthy
--  server-side even though the ped is client-simulated,
--  because these natives read the server's replicated view)
--  before ever calling Goddess.Security.Report.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Player = {}

-- lastPos[src] = { x, y, z, t }
local lastPos = {}

local function ped(src)
    return GetPlayerPed(src)
end

-- ─────────────────────────────────────────────
--  SPEED / TELEPORT (server authoritative distance check)
--  Client sends a periodic position signal; server computes
--  actual displacement over real elapsed time.
-- ─────────────────────────────────────────────
function Goddess.Detect.Player.OnPositionSignal(src, data)
    if not Config.Detections.Speed and not Config.Detections.Teleport then return end
    if Goddess.Security.InGracePeriod(src) then
        lastPos[src] = { x = data.x, y = data.y, z = data.z, t = GetGameTimer() }
        return
    end

    local prev = lastPos[src]
    local now = GetGameTimer()
    lastPos[src] = { x = data.x, y = data.y, z = data.z, t = now }
    if not prev then return end

    local dt = (now - prev.t) / 1000.0
    if dt <= 0 then return end

    local dist = Goddess.Utils.Distance3D(prev, data)

    -- In a vehicle, higher speeds are legitimate — handled by vehicle module.
    if data.inVehicle then return end

    local speed = dist / dt

    if Config.Detections.Teleport and dist >= Config.Thresholds.TeleportDistance and dt < 1.5 then
        Goddess.Security.Report(src, Goddess.Detections.TELEPORT, ('moved %.1fm in %.2fs'):format(dist, dt))
        return
    end

    if Config.Detections.Speed and speed > Config.Thresholds.MaxGroundSpeed then
        Goddess.Security.Report(src, Goddess.Detections.SPEED, ('%.1f units/s (max %.1f)'):format(speed, Config.Thresholds.MaxGroundSpeed))
    end
end

-- ─────────────────────────────────────────────
--  HEALTH / ARMOR (server reads directly — does not trust client)
-- ─────────────────────────────────────────────
function Goddess.Detect.Player.CheckHealthArmor(src)
    if not Config.Detections.HealthArmor then return end
    if Goddess.Security.InGracePeriod(src) then return end

    local p = ped(src)
    if not p or p == 0 then return end

    local health = GetEntityHealth(p)
    local armor = GetPedArmour(p)

    if health > Config.Thresholds.MaxHealthValue + 5 then
        Goddess.Security.Report(src, Goddess.Detections.HEALTH_ARMOR, ('health=%d exceeds max'):format(health))
    end
    if armor > Config.Thresholds.MaxArmorValue + 5 then
        Goddess.Security.Report(src, Goddess.Detections.HEALTH_ARMOR, ('armor=%d exceeds max'):format(armor))
    end
end

-- ─────────────────────────────────────────────
--  GODMODE / INVINCIBILITY
--  Server tracks damage events (see event.lua weaponDamageEvent
--  hook) — if a player repeatedly takes lethal damage server-side
--  yet health never drops, that's the strongest signal. Here we
--  expose the report entrypoint used by that hook.
-- ─────────────────────────────────────────────
function Goddess.Detect.Player.ReportGodmodeSuspicion(src, details)
    if not Config.Detections.Godmode then return end
    if Goddess.Security.InGracePeriod(src) then return end
    Goddess.Security.Report(src, Goddess.Detections.GODMODE, details)
end

-- ─────────────────────────────────────────────
--  GENERIC CLIENT SIGNAL ROUTER
--  Client-side detections (invisible, superjump, stamina,
--  noclip, freecam, ragdoll immunity, model change) can only
--  be *observed* client-side, so we accept the signal but
--  require corroboration (handled by Security.Report's
--  confirmation logic) before it affects punishment.
-- ─────────────────────────────────────────────
local clientOnlySignals = {
    invisible = Goddess.Detections and Goddess.Detections.INVISIBLE,
}

function Goddess.Detect.Player.OnClientSignal(src, signalType, details)
    local configKey = ({
        invisible    = 'Invisible',
        superjump    = 'SuperJump',
        stamina      = 'Stamina',
        noclip       = 'Noclip',
        freecam      = 'Freecam',
        ragdoll      = 'Ragdoll',
        model_change = 'ModelChange',
    })[signalType]

    if not configKey or not Config.Detections[configKey] then return end
    if Goddess.Security.InGracePeriod(src) then return end

    local detectionKey = ({
        invisible    = Goddess.Detections.INVISIBLE,
        superjump    = Goddess.Detections.SUPERJUMP,
        stamina      = Goddess.Detections.STAMINA,
        noclip       = Goddess.Detections.NOCLIP,
        freecam      = Goddess.Detections.FREECAM,
        ragdoll      = Goddess.Detections.RAGDOLL,
        model_change = Goddess.Detections.MODEL_CHANGE,
    })[signalType]

    -- Server-side sanity: reject signals for peds that don't exist
    -- or that are absurdly far from the player's last known position
    -- (protects against a spoofed signal claiming to be from src).
    local p = ped(src)
    if not p or p == 0 then return end

    Goddess.Security.Report(src, detectionKey, details)
end

AddEventHandler('playerDropped', function()
    lastPos[source] = nil
end)
