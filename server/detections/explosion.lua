-- ═══════════════════════════════════════════════════════════
--  GODDESS — EXPLOSION DETECTIONS (server-side validation)
--  Hooks the native `explosionEvent` (server-side event fired
--  by the game for every networked explosion) — this is
--  authoritative and cannot be spoofed by a client claiming a
--  different source.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Explosion = {}

-- freqState[src] = { count, windowStart }
local freqState = {}

function Goddess.Detect.Explosion.Handle(src, data)
    if not Config.Detections.Explosion then return end
    if not src or src == -1 then return end -- world/scripted explosion, not player-caused

    if Goddess.Admin.IsFullBypass(src) or Goddess.Admin.IsStaffMode(src) then return end

    -- Type filtering (blacklist)
    if data.explosionType and Goddess.Utils.TableContains(Config.Blacklist.ExplosionTypes, data.explosionType) then
        Goddess.Security.Report(src, Goddess.Detections.EXPLOSION, ('blacklisted explosion type %s'):format(tostring(data.explosionType)))
        return
    end

    -- Frequency limiting
    freqState[src] = freqState[src] or { count = 0, windowStart = GetGameTimer() }
    local ok = Goddess.Utils.RateCheck(freqState[src], 60000, Config.Thresholds.MaxExplosionsPerMinute)
    if not ok then
        Goddess.Security.Report(src, Goddess.Detections.EXPLOSION, 'exceeded explosion frequency limit')
        return
    end

    -- Radius sanity (only meaningful for explosion types that report one)
    if data.radius and data.radius > Config.Thresholds.MaxExplosionRadius then
        Goddess.Security.Report(src, Goddess.Detections.EXPLOSION, ('radius %.1f exceeds max %.1f'):format(data.radius, Config.Thresholds.MaxExplosionRadius))
    end
end

AddEventHandler('playerDropped', function()
    freqState[source] = nil
end)
