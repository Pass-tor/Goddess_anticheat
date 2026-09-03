-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT PLAYER DETECTIONS
--  These are SIGNALS only. The server independently validates
--  and requires multi-signal confirmation before acting — a
--  modified client can lie about or suppress any of this, so
--  none of it is trusted as a final verdict.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Player = {}

local lastZ = nil
local lastZTime = 0
local noclipStreak = 0
local knownModel = nil

local function send(signalType, details)
    TriggerServerEvent(Goddess.Events.SIGNAL, signalType, { details = details })
end

function Goddess.Detect.Player.Tick(ped)
    if Goddess.State.InLocalGrace() then return end

    -- ── Invisible ──────────────────────────────────────────
    if Config.Detections.Invisible then
        if not IsEntityVisible(ped) and not IsPedFatallyInjured(ped) and not IsEntityDead(ped) then
            send('invisible', 'IsEntityVisible=false while alive')
        end
    end

    -- ── Super jump / abnormal vertical speed ─────────────────
    if Config.Detections.SuperJump then
        local z = GetEntityCoords(ped).z
        local now = GetGameTimer()
        if lastZ and lastZTime > 0 then
            local dt = (now - lastZTime) / 1000.0
            if dt > 0 and not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) then
                local vertSpeed = (z - lastZ) / dt
                if vertSpeed > Config.Thresholds.MaxVerticalSpeed then
                    send('superjump', ('vertical speed %.1f'):format(vertSpeed))
                end
            end
        end
        lastZ, lastZTime = z, now
    end

    -- ── Stamina ────────────────────────────────────────────
    if Config.Detections.Stamina then
        -- A ped that is sprinting continuously with stamina that
        -- never depletes (native has no direct getter for remaining
        -- stamina in vanilla FiveM, so we infer via sprint state +
        -- lack of the natural slowdown after prolonged sprint).
        if IsPedSprinting(ped) and GetEntitySpeed(ped) > 6.5 then
            -- flagged only by duration tracking; see below
            Goddess.Detect.Player._sprintTicks = (Goddess.Detect.Player._sprintTicks or 0) + 1
            if Goddess.Detect.Player._sprintTicks > 40 then -- sustained far beyond normal stamina limits
                send('stamina', 'sustained max-speed sprint beyond normal stamina window')
                Goddess.Detect.Player._sprintTicks = 0
            end
        else
            Goddess.Detect.Player._sprintTicks = 0
        end
    end

    -- ── Noclip-like movement ───────────────────────────────
    -- Heuristic: moving at speed while airborne with no ground within
    -- a reasonable probe distance beneath the ped, and not in a
    -- jump/fall/parachute/vehicle state that would legitimately
    -- explain it. Uses a downward raycast rather than any
    -- "collision disabled" getter, since that state isn't reliably
    -- queryable — this keeps the signal accurate to what we can
    -- actually observe.
    if Config.Detections.Noclip then
        local speed = GetEntitySpeed(ped)
        local inVehicle = IsPedInAnyVehicle(ped, false)
        local legitAirborne = IsPedFalling(ped) or IsPedJumping(ped) or IsPedInParachuteFreeFall(ped)
            or (GetPedParachuteState and GetPedParachuteState(ped) > 0)

        if speed > 3.0 and not inVehicle and not legitAirborne then
            local coords = GetEntityCoords(ped)
            local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
            local heightAboveGround = coords.z - groundZ

            if heightAboveGround > 8.0 then
                noclipStreak = noclipStreak + 1
                if noclipStreak >= Config.Thresholds.NoclipMinAirTicks then
                    send('noclip', ('moving at %.1f while %.1fm above ground with no legitimate airborne state'):format(speed, heightAboveGround))
                    noclipStreak = 0
                end
            else
                noclipStreak = 0
            end
        else
            noclipStreak = 0
        end
    end

    -- ── Freecam-like behavior ──────────────────────────────
    if Config.Detections.Freecam then
        if IsGameplayCamRendering and not IsGameplayCamRendering() then
            local camCoords = GetGameplayCamCoord and GetGameplayCamCoord() or nil
            local pedCoords = GetEntityCoords(ped)
            if camCoords then
                local dist = Goddess.Utils.Distance3D(
                    { x = camCoords.x, y = camCoords.y, z = camCoords.z },
                    { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z }
                )
                if dist > 15.0 then
                    send('freecam', ('camera %.1fm from ped while gameplay cam not rendering'):format(dist))
                end
            end
        end
    end

    -- ── Ragdoll immunity ────────────────────────────────────
    if Config.Detections.Ragdoll then
        if IsPedFatallyInjured(ped) == false and IsPedRagdoll(ped) == false and IsPedBeingStunned(ped) == false then
            -- Cannot directly detect "immunity" without triggering a
            -- ragdoll ourselves (which would be intrusive); this hook
            -- is intended for correlation with server-observed forced
            -- ragdoll events (e.g. explosions) that failed to apply.
            -- Left as a lightweight no-op signal point for server
            -- correlation extension.
        end
    end

    -- ── Model change ────────────────────────────────────────
    if Config.Detections.ModelChange then
        local model = GetEntityModel(ped)
        if knownModel and knownModel ~= model then
            send('model_change', ('%s -> %s'):format(tostring(knownModel), tostring(model)))
        end
        knownModel = model
    end
end

-- ── Health tracking (local signal only; server independently
--    reads authoritative health via GetEntityHealth server-side) ──
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        -- args: [victim, attacker, ..., weaponHash, isFatal, ...]
        -- left for extension: correlate locally-observed damage
        -- with server-confirmed health to help catch godmode faster.
    end
end)

AddEventHandler('baseevents:onPlayerDied', function()
    TriggerServerEvent(Goddess.Events.SIGNAL, 'revive', {})
end)

RegisterNetEvent('esx:onPlayerSpawn', function()
    Goddess.State.lastSpawnTime = GetGameTimer()
    TriggerServerEvent(Goddess.Events.SIGNAL, 'revive', {})
end)
