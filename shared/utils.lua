-- ═══════════════════════════════════════════════════════════
--  GODDESS — SHARED UTILITIES
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Utils = {}

local isServer = IsDuplicityVersion()

--- Debug print, only active when Config.Debug is true.
function Goddess.Utils.Debug(...)
    if not Config.Debug then return end
    local prefix = isServer and '^5[Goddess:Server]^7' or '^5[Goddess:Client]^7'
    print(prefix, ...)
end

--- Always-on informational print (startup, errors)
function Goddess.Utils.Print(...)
    print('^2[Goddess]^7', ...)
end

function Goddess.Utils.Error(...)
    print('^1[Goddess:ERROR]^7', ...)
end

--- Safe wrapper — never lets a detection/module crash the resource.
--- Returns ok(bool), result/err
function Goddess.Utils.Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        Goddess.Utils.Error(('protected call failed: %s'):format(tostring(result)))
    end
    return ok, result
end

function Goddess.Utils.Distance3D(a, b)
    if not a or not b then return 0.0 end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Goddess.Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Goddess.Utils.TableContains(tbl, value)
    if not tbl then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function Goddess.Utils.ShallowCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do out[k] = v end
    return out
end

--- Simple leaky-bucket style rate tracker.
--- state = { count = 0, windowStart = 0 }
function Goddess.Utils.RateCheck(state, windowMs, maxPerWindow)
    local now = GetGameTimer()
    if now - state.windowStart > windowMs then
        state.windowStart = now
        state.count = 0
    end
    state.count = state.count + 1
    return state.count <= maxPerWindow
end

function Goddess.Utils.FormatDuration(minutes)
    if minutes <= 0 then return 'permanent' end
    if minutes < 60 then return minutes .. ' minute(s)' end
    local hours = minutes / 60
    if hours < 24 then return string.format('%.1f hour(s)', hours) end
    return string.format('%.1f day(s)', hours / 24)
end

--- Cross-version identifier grabber usable on both sides for a player src.
--- Server-only (client has no GetPlayerIdentifiers for other peds).
if isServer then
    function Goddess.Utils.GetIdentifiers(src)
        local ids = {
            license = nil, discord = nil, steam = nil, fivem = nil, ip = nil,
        }
        local numIds = GetNumPlayerIdentifiers(src)
        for i = 0, numIds - 1 do
            local id = GetPlayerIdentifier(src, i)
            if id then
                if id:find('license:') then ids.license = id
                elseif id:find('discord:') then ids.discord = id
                elseif id:find('steam:') then ids.steam = id
                elseif id:find('fivem:') then ids.fivem = id
                elseif id:find('ip:') then ids.ip = id
                end
            end
        end
        return ids
    end
end
