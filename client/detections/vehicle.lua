-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT VEHICLE DETECTIONS
--  Vehicle position is already reported at high frequency in
--  scanner.lua. This module handles enter/exit transitions
--  (for grace periods) and lightweight local mod-tamper signals.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Vehicle = {}

local wasInVehicle = false

function Goddess.Detect.Vehicle.Tick(ped)
    local inVeh = IsPedInAnyVehicle(ped, false)

    if inVeh ~= wasInVehicle then
        wasInVehicle = inVeh
        Goddess.State.lastVehicleTransition = GetGameTimer()
        TriggerServerEvent(Goddess.Events.SIGNAL, 'vehicle_transition', {})
    end
end
