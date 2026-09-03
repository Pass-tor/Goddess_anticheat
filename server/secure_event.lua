-- ═══════════════════════════════════════════════════════════
--  GODDESS — SECURE EVENT API
--  Goddess.RegisterSecureEvent(name, options, handler)
--
--  options = {
--      cooldown        = ms between calls per-player (default from config)
--      maxPerWindow    = max calls per windowMs (default from config)
--      windowMs        = window for maxPerWindow (default from config)
--      job             = string | { string, ... }  -- ESX job restriction
--      group           = string | { string, ... }  -- ESX group / ace group
--      minDistance     = nil | number (requires options.getEntityCoords(src, ...) )
--      validateArgs    = function(src, ...) -> boolean, reason
--      onViolation     = function(src, reason) -- optional custom hook
--  }
--
--  handler(src, ...) is only invoked once ALL checks pass.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}

local ESX = nil
if Config.Framework == 'esx' then
    Goddess.Utils.Safe(function()
        ESX = exports['es_extended']:getSharedObject()
    end)
end

-- rateStates[eventName][src] = { count, windowStart, lastCall }
local rateStates = {}

local function getRateState(eventName, src)
    rateStates[eventName] = rateStates[eventName] or {}
    rateStates[eventName][src] = rateStates[eventName][src] or { count = 0, windowStart = 0, lastCall = 0 }
    return rateStates[eventName][src]
end

local function playerHasJob(src, jobs)
    if not ESX then return true end -- can't validate without framework, fail open on job-only checks
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local job = xPlayer.job and xPlayer.job.name
    if type(jobs) == 'string' then return job == jobs end
    if type(jobs) == 'table' then return Goddess.Utils.TableContains(jobs, job) end
    return true
end

local function playerHasGroup(src, groups)
    if type(groups) == 'string' then groups = { groups } end
    for _, g in ipairs(groups) do
        if IsPlayerAceAllowed(src, g) then return true end
    end
    return false
end

--- Register a server event with full validation stacked in front of it.
function Goddess.RegisterSecureEvent(eventName, options, handler)
    options = options or {}
    local cooldown = options.cooldown or Config.RateLimit.DefaultEventCooldownMs
    local maxPerWindow = options.maxPerWindow or Config.RateLimit.DefaultEventMaxPerWindow
    local windowMs = options.windowMs or Config.RateLimit.DefaultEventWindowMs

    RegisterNetEvent(eventName, function(...)
        local src = source
        if not src or src == 0 then return end

        local args = { ... }

        local function violate(reason)
            Goddess.Security.Report(src, Goddess.Detections.EVENT_ABUSE, ('%s: %s'):format(eventName, reason))
            if options.onViolation then
                Goddess.Utils.Safe(options.onViolation, src, reason)
            end
        end

        -- 1. Invalid source sanity check
        if GetPlayerName(src) == nil then
            violate('invalid source')
            return
        end

        -- 2. Cooldown
        local state = getRateState(eventName, src)
        local now = GetGameTimer()
        if now - state.lastCall < cooldown then
            violate('cooldown violation')
            return
        end
        state.lastCall = now

        -- 3. Rate window
        if not Goddess.Utils.RateCheck(state, windowMs, maxPerWindow) then
            violate('rate limit exceeded')
            return
        end

        -- 4. Job restriction
        if options.job and not playerHasJob(src, options.job) then
            violate('job not authorized')
            return
        end

        -- 5. Group / permission restriction
        if options.group and not playerHasGroup(src, options.group) then
            violate('group not authorized')
            return
        end

        -- 6. Distance validation (requires caller-supplied coord getter,
        --    since target entity semantics differ per event)
        if options.minDistance and options.getEntityCoords then
            local ok, dist = pcall(options.getEntityCoords, src, table.unpack(args))
            if ok and dist and dist > options.minDistance then
                violate('distance check failed')
                return
            end
        end

        -- 7. Custom argument validation
        if options.validateArgs then
            local ok, valid, reason = pcall(options.validateArgs, src, table.unpack(args))
            if not ok then
                Goddess.Utils.Error(('validateArgs threw for %s: %s'):format(eventName, tostring(valid)))
                violate('validation error')
                return
            end
            if not valid then
                violate(reason or 'argument validation failed')
                return
            end
        end

        -- All checks passed — invoke real handler.
        local ok, err = pcall(handler, src, table.unpack(args))
        if not ok then
            Goddess.Utils.Error(('secure event handler error for %s: %s'):format(eventName, tostring(err)))
            Goddess.Log.ResourceError('SecureEvent:' .. eventName, err)
        end
    end)

    Goddess.Utils.Debug(('Registered secure event: %s'):format(eventName))
end
exports('RegisterSecureEvent', Goddess.RegisterSecureEvent)

-- ─────────────────────────────────────────────
--  Auto-wrap events listed in Config.ProtectedEvents.
--  These are events that already exist elsewhere; Goddess
--  here only demonstrates the pattern for the ones you list
--  with metadata — actual protection of a third-party event
--  must be done by that resource using the export above,
--  since Goddess cannot safely rebind another resource's
--  RegisterNetEvent handler.
-- ─────────────────────────────────────────────
for name, opts in pairs(Config.ProtectedEvents) do
    Goddess.Utils.Debug(('Config.ProtectedEvents entry found for %s — remember to wrap it in its owning resource with exports.Goddess:RegisterSecureEvent'):format(name))
end
