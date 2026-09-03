-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT SCANNER
--  Single adaptive loop that dispatches to each enabled
--  detection module. Avoids one-thread-per-detection overhead
--  and keeps Wait() times centrally tunable.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Scanner = {}

local statsFrame = { ticks = 0, lastReset = GetGameTimer() }

CreateThread(function()
    while true do
        local interval = Goddess.State.CurrentInterval()
        Wait(interval)

        if Config.DebugStats then
            statsFrame.ticks = statsFrame.ticks + 1
            if GetGameTimer() - statsFrame.lastReset > 10000 then
                Goddess.Utils.Debug(('scanner: %d ticks / 10s (interval=%dms)'):format(statsFrame.ticks, interval))
                statsFrame.ticks = 0
                statsFrame.lastReset = GetGameTimer()
            end
        end

        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            Goddess.Utils.Safe(Goddess.Detect.Player.Tick, ped)
            Goddess.Utils.Safe(Goddess.Detect.Vehicle.Tick, ped)
            Goddess.Utils.Safe(Goddess.Detect.Entity.Tick, ped)
        end
    end
end)

-- Lightweight, higher-frequency position reporting (separate from the
-- heavier per-detection tick above, since teleport/speed checks need
-- tighter timing resolution but almost no per-tick CPU cost).
CreateThread(function()
    while true do
        Wait(500)
        if not Goddess.State.InLocalGrace() then
            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local inVeh = IsPedInAnyVehicle(ped, false)
                TriggerServerEvent(Goddess.Events.SIGNAL, 'position', {
                    x = coords.x, y = coords.y, z = coords.z, inVehicle = inVeh,
                })

                if inVeh then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if GetPedInVehicleSeat(veh, -1) == ped then -- driver only
                        local vc = GetEntityCoords(veh)
                        TriggerServerEvent(Goddess.Events.SIGNAL, 'vehicle_position', {
                            netId = NetworkGetNetworkIdFromEntity(veh),
                            x = vc.x, y = vc.y, z = vc.z,
                        })
                    end
                end
            end
        end
    end
end)
