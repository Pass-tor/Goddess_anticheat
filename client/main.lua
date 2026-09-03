-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT MAIN
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}

CreateThread(function()
    Wait(1000)
    Goddess.Utils.Print(('Goddess client v%s active.'):format(Goddess.Version))
end)

-- ─────────────────────────────────────────────
--  NUI DASHBOARD (admin-only, opened via /goddess:dashboard)
-- ─────────────────────────────────────────────
local nuiOpen = false

RegisterNetEvent(Goddess.Events.NUI_OPEN, function()
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('goddess:requestDashboardData')
end)

RegisterNetEvent('goddess:nuiData', function(data)
    SendNUIMessage({ action = 'data', payload = data })
end)

RegisterNUICallback('close', function(_, cb)
    nuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('goddess:requestDashboardData')
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('goddess:nuiAction', data.action, data)
    cb('ok')
end)

RegisterCommand('goddess:closeui', function()
    if nuiOpen then
        nuiOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end, false)

RegisterKeyMapping('goddess:closeui', 'Close Goddess Dashboard', 'keyboard', 'ESCAPE')
