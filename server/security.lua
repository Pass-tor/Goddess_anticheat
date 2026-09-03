-- ═══════════════════════════════════════════════════════════
--  GODDESS — SECURITY CORE
--  Server-authoritative suspicion scoring engine.
--  Detection -> signal -> server verification -> suspicion
--  score -> confirmation -> escalation -> punishment.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Security = {}

-- players[src] = {
--   score = number,
--   lastTierIndex = number,
--   recentLog = { {detection, severity, ts}, ... },
--   confirmations = { [detection] = { count, firstTs } },
--   connectedAt = ms, lastRevive = ms, lastVehicleTransition = ms, lastTeleport = ms,
--   elevatedUntil = ms,
-- }
local players = {}

local function ensure(src)
    if not players[src] then
        players[src] = {
            score = 0,
            lastTierIndex = 0,
            recentLog = {},
            confirmations = {},
            connectedAt = GetGameTimer(),
            lastRevive = 0,
            lastVehicleTransition = 0,
            lastTeleport = 0,
            elevatedUntil = 0,
        }
    end
    return players[src]
end

function Goddess.Security.OnPlayerConnected(src)
    ensure(src).connectedAt = GetGameTimer()
end

function Goddess.Security.OnPlayerDropped(src)
    players[src] = nil
end

function Goddess.Security.MarkRevive(src)
    ensure(src).lastRevive = GetGameTimer()
end

function Goddess.Security.MarkVehicleTransition(src)
    ensure(src).lastVehicleTransition = GetGameTimer()
end

function Goddess.Security.MarkLegitTeleport(src)
    ensure(src).lastTeleport = GetGameTimer()
end

-- ─────────────────────────────────────────────
--  GRACE PERIOD CHECKS
-- ─────────────────────────────────────────────
function Goddess.Security.InGracePeriod(src)
    local p = players[src]
    if not p then return true end
    local now = GetGameTimer()

    if now - p.connectedAt < Config.Protection.SpawnGraceMs then return true end
    if now - p.lastRevive < Config.Protection.ReviveGraceMs then return true end
    if now - p.lastVehicleTransition < Config.Protection.VehicleTransitionMs then return true end
    if now - p.lastTeleport < Config.Protection.TeleportGraceMs then return true end

    return false
end

function Goddess.Security.GetScore(src)
    local p = players[src]
    return p and p.score or 0
end

function Goddess.Security.ClearScore(src)
    local p = ensure(src)
    p.score = 0
    p.lastTierIndex = 0
    p.confirmations = {}
    p.recentLog = {}
end

function Goddess.Security.GetRecentLog(src)
    local p = players[src]
    return p and p.recentLog or {}
end

function Goddess.Security.IsElevated(src)
    local p = players[src]
    if not p then return false end
    return GetGameTimer() < p.elevatedUntil
end

-- ─────────────────────────────────────────────
--  CORE: REPORT A DETECTION
--  Every detection module (server-side, after validating a
--  client signal) calls this. Nothing is punished directly by
--  detection modules — everything routes through here so
--  confirmation + escalation rules are applied consistently.
-- ─────────────────────────────────────────────
function Goddess.Security.Report(src, detection, details)
    if src == nil or src == 0 then return end
    if Goddess.Admin.IsFullBypass(src) then return end
    if Goddess.Admin.IsStaffMode(src) then return end

    local p = ensure(src)
    local severity = Goddess.Severity[detection] or 10
    local now = GetGameTimer()

    -- Multi-signal confirmation: a single detection type reported once
    -- is logged but not scored until it repeats, OR a different
    -- detection type corroborates within the confirmation window.
    local conf = p.confirmations[detection]
    if not conf or (now - conf.firstTs) > Config.Suspicion.ConfirmationWindow then
        conf = { count = 0, firstTs = now }
        p.confirmations[detection] = conf
    end
    conf.count = conf.count + 1

    -- Count distinct detection types confirmed within the window
    local distinctRecent = 0
    for _, c in pairs(p.confirmations) do
        if (now - c.firstTs) <= Config.Suspicion.ConfirmationWindow and c.count >= 1 then
            distinctRecent = distinctRecent + 1
        end
    end

    local confirmed = conf.count >= Config.Suspicion.RequiredConfirmations
        or distinctRecent >= Config.Protection.MinSignalsToConfirm

    -- Always log for admin visibility / evidence, even if not yet confirmed.
    table.insert(p.recentLog, 1, { detection = detection, severity = severity, ts = now, details = details })
    if #p.recentLog > 20 then table.remove(p.recentLog) end

    if not confirmed then
        Goddess.Utils.Debug(('Signal (unconfirmed) from %s: %s'):format(src, detection))
        return
    end

    p.score = Goddess.Utils.Clamp(p.score + severity, 0, Config.Suspicion.MaxScore)

    local playerName = GetPlayerName(src) or 'Unknown'
    local ids = Goddess.Utils.GetIdentifiers(src)

    Goddess.DB.InsertDetection({
        playerName = playerName, license = ids.license, detection = detection,
        severity = severity, scoreAfter = p.score, details = details, createdAt = os.time() * 1000,
    })

    Goddess.Log.Detection({ src = src, playerName = playerName, detection = detection, severity = severity, scoreAfter = p.score, details = details })

    -- Elevate scanning frequency for this player
    if p.score >= Config.Scanning.ElevatedThreshold then
        p.elevatedUntil = now + Config.Scanning.ElevatedDurationMs
        TriggerClientEvent('goddess:syncConfig', src, { elevated = true, until_ = p.elevatedUntil })
    end

    Goddess.Security.CheckEscalation(src, detection)
end

-- ─────────────────────────────────────────────
--  ESCALATION
-- ─────────────────────────────────────────────
function Goddess.Security.CheckEscalation(src, detection)
    local p = players[src]
    if not p then return end

    -- Instant actions bypass the tier ladder but still required
    -- confirmation (handled above) so it's never a raw single-signal ban.
    local instant = Config.Punishment.InstantActions[detection]
    if instant then
        Goddess.Punishment.Escalate(src, { score = p.score, action = instant }, detection)
        return
    end

    local tiers = Config.Punishment.Escalation
    for i = #tiers, 1, -1 do
        local tier = tiers[i]
        if p.score >= tier.score and i > p.lastTierIndex then
            p.lastTierIndex = i
            Goddess.Punishment.Escalate(src, tier, detection)
            break
        end
    end
end

-- ─────────────────────────────────────────────
--  SUSPICION DECAY
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.Suspicion.DecayInterval)
        if Config.Suspicion.DecayEnabled then
            for src, p in pairs(players) do
                if p.score > 0 then
                    p.score = math.max(0, p.score - Config.Suspicion.DecayAmount)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    Goddess.Security.OnPlayerDropped(source)
end)
