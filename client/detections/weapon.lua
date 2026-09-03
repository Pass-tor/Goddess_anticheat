-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT WEAPON DETECTIONS
--  Fire-rate and ammo signals only; damage validation happens
--  entirely server-side (via the native weaponDamageEvent),
--  since client-reported damage cannot be trusted at all.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}

-- lastAmmo[weaponHash] = { ammo, shotsSinceReport }
local lastAmmo = {}

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkWeaponFireBullet' and name ~= 'CEventNetworkFiredWeapon' then return end
    if not Config.Detections.WeaponFireRate and not Config.Detections.WeaponAmmo then return end

    local ped = PlayerPedId()
    local shooter = args[1]
    if shooter ~= ped then return end -- not us

    local weaponHash = args[3] or GetSelectedPedWeapon(ped)
    TriggerServerEvent(Goddess.Events.SIGNAL, 'shot_fired', { weaponHash = weaponHash })

    if lastAmmo[weaponHash] then
        lastAmmo[weaponHash].shotsSinceReport = (lastAmmo[weaponHash].shotsSinceReport or 0) + 1
    end
end)

-- Periodic ammo snapshot -> server compares deltas.
CreateThread(function()
    while true do
        Wait(4000)
        if Config.Detections.WeaponAmmo then
            local ped = PlayerPedId()
            local weaponHash = GetSelectedPedWeapon(ped)
            if weaponHash and weaponHash ~= `WEAPON_UNARMED` then
                local ammo = GetAmmoInPedWeapon(ped, weaponHash)
                local prev = lastAmmo[weaponHash]
                TriggerServerEvent(Goddess.Events.SIGNAL, 'ammo_check', {
                    weaponHash = weaponHash,
                    previousAmmo = prev and prev.ammo or ammo,
                    currentAmmo = ammo,
                    shotsSinceLast = prev and prev.shotsSinceReport or 0,
                })
                lastAmmo[weaponHash] = { ammo = ammo, shotsSinceReport = 0 }
            end
        end
    end
end)
