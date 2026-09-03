-- ═══════════════════════════════════════════════════════════
--  GODDESS — ADMIN SYSTEM
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Admin = {}

local staffMode = {} -- [src] = true/false

--- Is `src` a Goddess administrator (identifier list OR ace permission)?
function Goddess.Admin.IsAdmin(src)
    if src == 0 then return true end -- console always admin

    if Config.Admin.UseAcePermission and IsPlayerAceAllowed(src, Config.Admin.AcePermission) then
        return true
    end

    if #Config.Admin.Identifiers > 0 then
        local ids = Goddess.Utils.GetIdentifiers(src)
        for _, configured in ipairs(Config.Admin.Identifiers) do
            for _, myId in pairs(ids) do
                if myId == configured then return true end
            end
        end
    end

    return false
end
exports('IsGoddessAdmin', Goddess.Admin.IsAdmin)

--- Is `src` fully exempt from all detections? (dev/testing only)
function Goddess.Admin.IsFullBypass(src)
    if #Config.Admin.FullBypass == 0 then return false end
    local ids = Goddess.Utils.GetIdentifiers(src)
    for _, configured in ipairs(Config.Admin.FullBypass) do
        for _, myId in pairs(ids) do
            if myId == configured then return true end
        end
    end
    return false
end

function Goddess.Admin.IsStaffMode(src)
    return staffMode[src] == true
end

local function requireAdmin(src)
    if src ~= 0 and not Goddess.Admin.IsAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'You do not have permission to use this command.' } })
        return false
    end
    return true
end

local function getSrcByArg(arg)
    local id = tonumber(arg)
    if not id then return nil end
    if GetPlayerName(id) then return id end
    return nil
end

-- ─────────────────────────────────────────────
--  COMMANDS
-- ─────────────────────────────────────────────

RegisterCommand('goddess:staffmode', function(src)
    if not requireAdmin(src) then return end
    staffMode[src] = not staffMode[src]
    TriggerClientEvent('chat:addMessage', src, { args = { '^5Goddess', 'Staff mode: ' .. (staffMode[src] and 'ENABLED' or 'DISABLED') } })
end, false)

RegisterCommand('goddess:suspicion', function(src, args)
    if not requireAdmin(src) then return end
    local target = getSrcByArg(args[1])
    if not target then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:suspicion [id]' } })
        return
    end
    local score = Goddess.Security.GetScore(target)
    TriggerClientEvent('chat:addMessage', src, { args = { '^5Goddess', ('%s (id %s) suspicion score: %d'):format(GetPlayerName(target) or '?', target, score) } })
end, false)

RegisterCommand('goddess:clear', function(src, args)
    if not requireAdmin(src) then return end
    local target = getSrcByArg(args[1])
    if not target then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:clear [id]' } })
        return
    end
    Goddess.Security.ClearScore(target)
    local adminName = src == 0 and 'console' or GetPlayerName(src)
    Goddess.Log.AdminAction({ admin = adminName, action = 'clear_suspicion', target = GetPlayerName(target) or tostring(target) })
    TriggerClientEvent('chat:addMessage', src, { args = { '^2Goddess', ('Cleared suspicion for %s'):format(GetPlayerName(target) or target) } })
end, false)
exports('ClearSuspicion', function(target) Goddess.Security.ClearScore(target) end)

RegisterCommand('goddess:kick', function(src, args)
    if not requireAdmin(src) then return end
    local target = getSrcByArg(args[1])
    if not target then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:kick [id] [reason]' } })
        return
    end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Kicked by administrator' end
    local adminName = src == 0 and 'console' or GetPlayerName(src)
    Goddess.Punishment.Kick(target, reason, 'manual', adminName)
end, false)

RegisterCommand('goddess:ban', function(src, args)
    if not requireAdmin(src) then return end
    local target = getSrcByArg(args[1])
    if not target then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:ban [id] [minutes|0 for permanent] [reason]' } })
        return
    end
    local minutes = tonumber(args[2]) or 0
    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = Config.Punishment.DefaultBanReason end
    local adminName = src == 0 and 'console' or GetPlayerName(src)
    Goddess.Punishment.Ban(target, reason, 'manual', adminName, minutes)
end, false)

RegisterCommand('goddess:unban', function(src, args)
    if not requireAdmin(src) then return end
    local license = args[1]
    if not license then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:unban [license:xxxx]' } })
        return
    end
    local adminName = src == 0 and 'console' or GetPlayerName(src)
    Goddess.DB.Unban(license, function(success)
        if success then
            Goddess.Log.AdminAction({ admin = adminName, action = 'unban', target = license })
            TriggerClientEvent('chat:addMessage', src, { args = { '^2Goddess', 'Player unbanned.' } })
        else
            TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'No active ban found, or database unavailable.' } })
        end
    end)
end, false)

RegisterCommand('goddess:history', function(src, args)
    if not requireAdmin(src) then return end
    local license = args[1]
    if not license then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Goddess', 'Usage: /goddess:history [license:xxxx]' } })
        return
    end
    Goddess.DB.GetDetectionHistoryForLicense(license, function(rows)
        if #rows == 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '^5Goddess', 'No detection history found.' } })
            return
        end
        for i = 1, math.min(10, #rows) do
            local r = rows[i]
            TriggerClientEvent('chat:addMessage', src, { args = { '^5Goddess', ('[%s] %s (severity %s)'):format(os.date('%Y-%m-%d %H:%M', (r.created_at or 0) / 1000), r.detection, r.severity) } })
        end
    end)
end, false)

RegisterCommand('goddess:reload', function(src)
    if not requireAdmin(src) then return end
    -- Safe partial reload: config is re-read on next resource restart.
    -- We do not hot-swap Config here to avoid inconsistent module state;
    -- instead we confirm current values and advise a restart if needed.
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^5Goddess', 'Config is loaded at resource start. Use `restart Goddess` to fully reload — this preserves in-memory suspicion state only if the server persists it externally.' }
    })
end, false)

RegisterCommand('goddess:dashboard', function(src)
    if not requireAdmin(src) then return end
    TriggerClientEvent('goddess:nuiOpen', src)
end, false)

for _, cmd in ipairs({ 'goddess:staffmode', 'goddess:suspicion', 'goddess:clear', 'goddess:kick', 'goddess:ban', 'goddess:unban', 'goddess:history', 'goddess:reload', 'goddess:dashboard' }) do
    if Config.Admin.UseAcePermission then
        ExecuteCommand(('add_ace resource.%s command.%s allow'):format(GetCurrentResourceName(), cmd))
    end
end

AddEventHandler('playerDropped', function()
    staffMode[source] = nil
end)
