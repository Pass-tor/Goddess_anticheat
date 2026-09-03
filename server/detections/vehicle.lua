-- ═══════════════════════════════════════════════════════════
--  GODDESS — VEHICLE DETECTIONS (server-side validation)
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Vehicle = {}

-- lastVehPos[netId] = { x, y, z, t }
local lastVehPos = {}
-- spawnState[src] = { count, windowStart }
local spawnState = {}

local function isBlacklisted(model)
    return Goddess.Utils.TableContains(Config.Blacklist.Vehicles, model)
end

local function isWhitelistedOnly()
    return #Config.Whitelist.Vehicles > 0
end

-- ─────────────────────────────────────────────
--  SPAWN VALIDATION
--  Call from your vehicle-spawning resource, or hook the
--  `esx:spawnVehicle` style event via RegisterSecureEvent.
-- ─────────────────────────────────────────────
function Goddess.Detect.Vehicle.ValidateSpawn(src, model, authorized)
    if not Config.Detections.VehicleSpawn and not Config.Detections.VehicleBlacklist then return true end

    if Config.Detections.VehicleBlacklist and isBlacklisted(model) then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_BLACKLIST, ('model %s'):format(tostring(model)))
        return false
    end

    if isWhitelistedOnly() and not Goddess.Utils.TableContains(Config.Whitelist.Vehicles, model) then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_BLACKLIST, ('model %s not in whitelist'):format(tostring(model)))
        return false
    end

    if Config.Detections.VehicleSpawn and not authorized then
        spawnState[src] = spawnState[src] or { count = 0, windowStart = GetGameTimer() }
        local ok = Goddess.Utils.RateCheck(spawnState[src], 60000, Config.Thresholds.MaxEntitiesPerMinute)
        if not ok then
            Goddess.Security.Report(src, Goddess.Detections.VEHICLE_SPAWN, 'excessive unauthorized vehicle spawns')
            return false
        end
    end

    return true
end

-- ─────────────────────────────────────────────
--  SPEED / TELEPORT
-- ─────────────────────────────────────────────
function Goddess.Detect.Vehicle.OnPositionSignal(src, netId, data)
    if not Config.Detections.VehicleSpeed and not Config.Detections.VehicleTeleport then return end
    if Goddess.Security.InGracePeriod(src) then
        lastVehPos[netId] = { x = data.x, y = data.y, z = data.z, t = GetGameTimer() }
        return
    end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return end -- only trust the driver's report

    local prev = lastVehPos[netId]
    local now = GetGameTimer()
    lastVehPos[netId] = { x = data.x, y = data.y, z = data.z, t = now }
    if not prev then return end

    local dt = (now - prev.t) / 1000.0
    if dt <= 0 then return end

    local dist = Goddess.Utils.Distance3D(prev, data)
    local speed = dist / dt

    if Config.Detections.VehicleTeleport and dist >= Config.Thresholds.VehicleTeleportDistance and dt < 1.5 then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_TELEPORT, ('vehicle moved %.1fm in %.2fs'):format(dist, dt))
        return
    end

    if Config.Detections.VehicleSpeed and speed > Config.Thresholds.MaxVehicleSpeed then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_SPEED, ('%.1f units/s (max %.1f)'):format(speed, Config.Thresholds.MaxVehicleSpeed))
    end
end

-- ─────────────────────────────────────────────
--  GODMODE (server reads vehicle health/damage state directly)
-- ─────────────────────────────────────────────
function Goddess.Detect.Vehicle.CheckGodmode(src, netId)
    if not Config.Detections.VehicleGodmode then return end
    if Goddess.Security.InGracePeriod(src) then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    if GetEntityInvincible(veh) then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_GODMODE, 'vehicle flagged invincible server-side')
    end
end

-- ─────────────────────────────────────────────
--  MODIFICATION ABUSE
--  Call from your vehicle-mod shop resource before applying
--  mods, passing whether the player actually paid/owns the shop use.
-- ─────────────────────────────────────────────
function Goddess.Detect.Vehicle.ValidateModification(src, netId, authorized)
    if not Config.Detections.VehicleMod then return true end
    if authorized then return true end
    Goddess.Security.Report(src, Goddess.Detections.VEHICLE_MOD, ('unauthorized modification on vehicle net %d'):format(netId))
    return false
end

-- ─────────────────────────────────────────────
--  PLATE MANIPULATION
--  Detects a plate changing without going through the
--  authorized plate-change flow (server tracks last known plate).
-- ─────────────────────────────────────────────
local knownPlates = {} -- [netId] = plate

function Goddess.Detect.Vehicle.CheckPlate(src, netId)
    if not Config.Detections.VehiclePlate then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local plate = GetVehicleNumberPlateText(veh)
    local prev = knownPlates[netId]
    knownPlates[netId] = plate

    if prev and prev ~= plate and not Goddess.Security.InGracePeriod(src) then
        Goddess.Security.Report(src, Goddess.Detections.VEHICLE_PLATE, ('plate changed %s -> %s'):format(prev, plate))
    end
end

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) == 2 then -- vehicle
        local netId = NetworkGetNetworkIdFromEntity(entity)
        lastVehPos[netId] = nil
        knownPlates[netId] = nil
    end
end)

AddEventHandler('playerDropped', function()
    spawnState[source] = nil
end)
