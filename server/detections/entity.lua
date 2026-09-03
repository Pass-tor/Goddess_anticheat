-- ═══════════════════════════════════════════════════════════
--  GODDESS — ENTITY DETECTIONS (server-side validation)
--  Covers objects, peds, and mass-spawn abuse. Vehicle-specific
--  spawn logic lives in vehicle.lua; this module handles the
--  generic entity-creation firehose.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Entity = {}

-- spawnCounters[src] = { count, windowStart }
local spawnCounters = {}
-- ownedByPlayer[src] = number of currently-tracked live entities
local ownedByPlayer = {}

local function isBlacklistedModel(entityType, model)
    if entityType == 1 then return Goddess.Utils.TableContains(Config.Blacklist.Peds, model) end
    if entityType == 3 then return Goddess.Utils.TableContains(Config.Blacklist.Objects, model) end
    if entityType == 2 then return Goddess.Utils.TableContains(Config.Blacklist.Vehicles, model) end
    return false
end

--- Called from the entityCreating/entityCreated handlers in event.lua
function Goddess.Detect.Entity.OnEntityCreated(entity)
    if not Config.Detections.EntityBlacklist and not Config.Detections.EntitySpam then return end
    if not DoesEntityExist(entity) then return end

    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 then return end -- server-created / world entity, skip

    local entityType = GetEntityType(entity) -- 1 ped, 2 vehicle, 3 object
    local model = GetEntityModel(entity)

    if Config.Detections.EntityBlacklist and isBlacklistedModel(entityType, model) then
        Goddess.Security.Report(owner, Goddess.Detections.ENTITY_BLACKLIST, ('type=%d model=%s'):format(entityType, tostring(model)))
    end

    if Config.Detections.EntitySpam then
        spawnCounters[owner] = spawnCounters[owner] or { count = 0, windowStart = GetGameTimer() }
        local ok = Goddess.Utils.RateCheck(spawnCounters[owner], 60000, Config.Thresholds.MaxEntitiesPerMinute)

        ownedByPlayer[owner] = (ownedByPlayer[owner] or 0) + 1

        if not ok then
            Goddess.Security.Report(owner, Goddess.Detections.ENTITY_SPAM, 'exceeded entity spawn rate limit')
        elseif ownedByPlayer[owner] > Config.Thresholds.MaxEntitiesTotal then
            Goddess.Security.Report(owner, Goddess.Detections.ENTITY_SPAM, ('%d live entities owned'):format(ownedByPlayer[owner]))
        end
    end
end

function Goddess.Detect.Entity.OnEntityRemoved(entity)
    local owner = NetworkGetEntityOwner(entity)
    if owner and ownedByPlayer[owner] then
        ownedByPlayer[owner] = math.max(0, ownedByPlayer[owner] - 1)
    end
end

-- ─────────────────────────────────────────────
--  OWNERSHIP ANOMALIES
--  Flags when network ownership of a sensitive entity changes
--  in a way that doesn't correspond to normal proximity-based
--  migration (e.g. claimed from far away).
-- ─────────────────────────────────────────────
function Goddess.Detect.Entity.CheckOwnershipAnomaly(entity, newOwnerSrc)
    if not Config.Detections.EntityOwnership then return end
    if not DoesEntityExist(entity) then return end

    local ped = GetPlayerPed(newOwnerSrc)
    if not ped or ped == 0 then return end

    local entityCoords = GetEntityCoords(entity)
    local playerCoords = GetEntityCoords(ped)
    local dist = Goddess.Utils.Distance3D(
        { x = entityCoords.x, y = entityCoords.y, z = entityCoords.z },
        { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
    )

    if dist > 150.0 then
        Goddess.Security.Report(newOwnerSrc, Goddess.Detections.ENTITY_OWNERSHIP, ('claimed entity %.0fm away'):format(dist))
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    spawnCounters[src] = nil
    ownedByPlayer[src] = nil
end)
