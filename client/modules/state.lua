-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT STATE
--  Local-only bookkeeping used to reduce false positives and
--  drive adaptive scan intervals. None of this is trusted by
--  the server — it only controls what signals get *sent*.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.State = {
    elevated = false,
    elevatedUntil = 0,
    lastSpawnTime = GetGameTimer(),
    lastVehicleTransition = 0,
    inVehicle = false,
    currentVehicle = 0,
    lastHealth = 200,
    lastModel = 0,
}

RegisterNetEvent(Goddess.Events.SYNC_CONFIG, function(data)
    if data.elevated ~= nil then
        Goddess.State.elevated = data.elevated
        Goddess.State.elevatedUntil = data.until_ or 0
    end
end)

function Goddess.State.CurrentInterval()
    if Goddess.State.elevated and GetGameTimer() < Goddess.State.elevatedUntil then
        return Config.Scanning.ElevatedIntervalMs
    end
    Goddess.State.elevated = false
    return Config.Scanning.NormalIntervalMs
end

--- Local grace check mirrors the server's, so the client avoids
--- wasting bandwidth sending signals during known-safe windows
--- (spawn, revive, vehicle transition). Server still enforces
--- its own grace periods independently — this is an optimization,
--- not a security boundary.
function Goddess.State.InLocalGrace()
    local now = GetGameTimer()
    if now - Goddess.State.lastSpawnTime < Config.Protection.SpawnGraceMs then return true end
    if now - Goddess.State.lastVehicleTransition < Config.Protection.VehicleTransitionMs then return true end
    return false
end
