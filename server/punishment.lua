-- ═══════════════════════════════════════════════════════════
--  GODDESS — PUNISHMENT SYSTEM
--  Warn -> Kick -> Temp Ban -> Perm Ban, driven by suspicion
--  score escalation. Never bans off a single raw signal.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Punishment = {}

local function buildEvidence(src)
    local log = Goddess.Security.GetRecentLog(src)
    if not log or #log == 0 then return 'n/a' end
    local parts = {}
    for _, entry in ipairs(log) do
        parts[#parts + 1] = ('%s(+%d)'):format(entry.detection, entry.severity)
    end
    return table.concat(parts, ', ')
end

function Goddess.Punishment.Warn(src, reason, detection)
    if not Config.Punishment.Enabled then return end
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^3Goddess Warning', reason or 'Suspicious activity detected. Further violations may result in removal.' }
    })
    Goddess.Utils.Debug(('WARN issued to %s: %s'):format(src, reason))
end

function Goddess.Punishment.Kick(src, reason, detection, admin)
    if not Config.Punishment.Enabled then return end
    local playerName = GetPlayerName(src) or 'Unknown'
    local ids = Goddess.Utils.GetIdentifiers(src)

    Goddess.Log.Kick({ src = src, playerName = playerName, reason = reason, detection = detection })
    if admin then
        Goddess.DB.InsertHistory(ids.license, 'kick', reason, admin)
    end

    DropPlayer(src, ('[Goddess] %s'):format(reason or 'You have been kicked by the security system.'))
end
exports('KickPlayer', Goddess.Punishment.Kick)

function Goddess.Punishment.Ban(src, reason, detection, admin, durationMinutes)
    if not Config.Punishment.Enabled then return end
    local playerName = GetPlayerName(src) or 'Unknown'
    local ids = Goddess.Utils.GetIdentifiers(src)
    local evidence = buildEvidence(src)
    durationMinutes = durationMinutes or 0

    local expiresAt = nil
    if durationMinutes and durationMinutes > 0 then
        expiresAt = (os.time() + durationMinutes * 60) * 1000
    end

    Goddess.DB.InsertBan({
        playerName = playerName,
        license = ids.license,
        discord = ids.discord,
        rockstar = ids.fivem,
        ip = ids.ip,
        reason = reason,
        detection = detection,
        evidence = evidence,
        admin = admin or 'Goddess',
        bannedAt = os.time() * 1000,
        expiresAt = expiresAt,
    })

    if admin then
        Goddess.DB.InsertHistory(ids.license, 'ban', reason, admin)
    end

    Goddess.Log.Ban({
        playerName = playerName, license = ids.license, reason = reason,
        detection = detection, evidence = evidence, durationMinutes = durationMinutes,
    })

    local durationText = durationMinutes > 0 and Goddess.Utils.FormatDuration(durationMinutes) or 'permanent'
    DropPlayer(src, ('[Goddess] Banned (%s): %s'):format(durationText, reason or Config.Punishment.DefaultBanReason))
end
exports('BanPlayer', Goddess.Punishment.Ban)

--- Called by security.lua whenever a player's score crosses a
--- new escalation tier. `tier` is one row of Config.Punishment.Escalation.
function Goddess.Punishment.Escalate(src, tier, detection)
    local action = tier.action
    local playerName = GetPlayerName(src) or 'Unknown'
    local reason = ('Automated action — suspicion score reached %d (%s)'):format(tier.score, detection or 'multiple signals')

    if action == Goddess.PunishmentActions.WARN then
        Goddess.Punishment.Warn(src, 'Suspicious activity detected on your session.', detection)
    elseif action == Goddess.PunishmentActions.KICK then
        Goddess.Punishment.Kick(src, reason, detection, nil)
    elseif action == Goddess.PunishmentActions.TEMPBAN then
        Goddess.Punishment.Ban(src, reason, detection, nil, tier.duration or 60)
    elseif action == Goddess.PunishmentActions.PERMBAN then
        Goddess.Punishment.Ban(src, reason, detection, nil, 0)
    end

    Goddess.Utils.Debug(('Escalation for %s (%s): %s'):format(playerName, src, action))
end

--- Check bans on connect. Returns true (and a reason) if the
--- connecting player is currently banned.
function Goddess.Punishment.CheckBanOnConnect(license, cb)
    if not Goddess.DB.IsReady() then
        cb(false)
        return
    end
    Goddess.DB.GetActiveBan(license, function(ban)
        if not ban then
            cb(false)
            return
        end
        if ban.expires_at and ban.expires_at > 0 and ban.expires_at < (os.time() * 1000) then
            Goddess.DB.Unban(license)
            cb(false)
            return
        end
        cb(true, ban)
    end)
end
