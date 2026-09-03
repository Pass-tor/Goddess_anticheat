-- ═══════════════════════════════════════════════════════════
--  GODDESS — LOGGING (Discord Webhooks)
--  Webhook URLs live server-side only (config.lua), never
--  exposed to clients. All sends are protected calls so a
--  webhook outage can never take down the resource.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Log = {}

local function send(category, embed)
    if not Config.Logging.Enabled then return end
    local url = Config.Logging.Webhooks[category]
    if not url or url == '' then return end

    Goddess.Utils.Safe(function()
        PerformHttpRequest(url, function(statusCode, _, _)
            if Config.Debug and statusCode and statusCode >= 300 then
                Goddess.Utils.Error(('Discord webhook (%s) returned status %s'):format(category, tostring(statusCode)))
            end
        end, 'POST', json.encode({
            username = Config.Logging.BotName,
            avatar_url = (Config.Logging.BotAvatar ~= '' and Config.Logging.BotAvatar) or nil,
            embeds = { embed },
        }), { ['Content-Type'] = 'application/json' })
    end)
end

local function baseFooter()
    return {
        text = ('Goddess v%s • %s'):format(Goddess.Version, GetCurrentResourceName()),
    }
end

function Goddess.Log.Detection(data)
    send('Detection', {
        title = '🔎 Detection Signal Confirmed',
        color = Config.Logging.Colors.Detection,
        fields = {
            { name = 'Player', value = ('%s (`%s`)'):format(data.playerName or '?', tostring(data.src)), inline = true },
            { name = 'Detection', value = data.detection or 'unknown', inline = true },
            { name = 'Severity', value = tostring(data.severity or 0), inline = true },
            { name = 'Suspicion Score', value = tostring(data.scoreAfter or 0), inline = true },
            { name = 'Details', value = data.details and data.details ~= '' and data.details or 'n/a', inline = false },
        },
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

function Goddess.Log.Kick(data)
    send('Kick', {
        title = '⚠️ Player Kicked',
        color = Config.Logging.Colors.Kick,
        fields = {
            { name = 'Player', value = ('%s (`%s`)'):format(data.playerName or '?', tostring(data.src)), inline = true },
            { name = 'Reason', value = data.reason or 'n/a', inline = true },
            { name = 'Detection', value = data.detection or 'n/a', inline = true },
        },
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

function Goddess.Log.Ban(data)
    send('Ban', {
        title = '⛔ Player Banned',
        color = Config.Logging.Colors.Ban,
        fields = {
            { name = 'Player', value = data.playerName or '?', inline = true },
            { name = 'License', value = data.license and ('||' .. data.license .. '||') or 'n/a', inline = true },
            { name = 'Duration', value = Goddess.Utils.FormatDuration(data.durationMinutes or 0), inline = true },
            { name = 'Reason', value = data.reason or 'n/a', inline = false },
            { name = 'Detection', value = data.detection or 'n/a', inline = true },
            { name = 'Evidence', value = data.evidence and data.evidence ~= '' and data.evidence or 'n/a', inline = false },
        },
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

function Goddess.Log.AdminAction(data)
    send('AdminAction', {
        title = '🛡️ Admin Action',
        color = Config.Logging.Colors.Admin,
        fields = {
            { name = 'Admin', value = data.admin or 'console', inline = true },
            { name = 'Action', value = data.action or 'n/a', inline = true },
            { name = 'Target', value = data.target or 'n/a', inline = true },
            { name = 'Details', value = data.details and data.details ~= '' and data.details or 'n/a', inline = false },
        },
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

function Goddess.Log.Security(title, message)
    send('Security', {
        title = '🚨 ' .. title,
        description = message,
        color = Config.Logging.Colors.Security,
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

function Goddess.Log.ResourceError(context, err)
    send('ResourceError', {
        title = '💥 Resource Error',
        color = Config.Logging.Colors.Error,
        fields = {
            { name = 'Context', value = context or 'n/a', inline = false },
            { name = 'Error', value = tostring(err):sub(1, 900), inline = false },
        },
        footer = baseFooter(),
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end
