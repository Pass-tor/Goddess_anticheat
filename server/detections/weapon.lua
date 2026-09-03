-- ═══════════════════════════════════════════════════════════
--  GODDESS — WEAPON DETECTIONS (server-side validation)
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Weapon = {}

-- fireState[src][weaponHash] = { lastShotTs, shotsInWindow, windowStart }
local fireState = {}

local function isBlacklisted(weaponHash)
    return Goddess.Utils.TableContains(Config.Blacklist.Weapons, weaponHash)
end

local function isWhitelistedOnly()
    return #Config.Whitelist.Weapons > 0
end

-- ─────────────────────────────────────────────
--  WEAPON GRANT VALIDATION
--  Call this from your inventory/weapon-give resource via
--  the exported Goddess.RegisterSecureEvent pattern, or hook
--  here directly if you control weapon granting centrally.
-- ─────────────────────────────────────────────
function Goddess.Detect.Weapon.ValidateGrant(src, weaponHash, authorized)
    if not Config.Detections.WeaponBlacklist and not Config.Detections.WeaponGrant then return true end

    if Config.Detections.WeaponBlacklist and isBlacklisted(weaponHash) then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_BLACKLIST, ('weapon hash %s'):format(tostring(weaponHash)))
        return false
    end

    if isWhitelistedOnly() and not Goddess.Utils.TableContains(Config.Whitelist.Weapons, weaponHash) then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_BLACKLIST, ('weapon %s not in whitelist'):format(tostring(weaponHash)))
        return false
    end

    if Config.Detections.WeaponGrant and not authorized then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_GRANT, ('unauthorized grant of %s'):format(tostring(weaponHash)))
        return false
    end

    return true
end

-- ─────────────────────────────────────────────
--  FIRE RATE
--  Client reports each shot fired (lightweight signal); server
--  computes real inter-shot interval and compares to the
--  weapon's known cyclic rate.
-- ─────────────────────────────────────────────
local baseCyclicMs = {
    -- conservative baseline ms-per-shot for common automatic weapons;
    -- extend this table with accurate values for your server's weapon set.
    [`WEAPON_MICROSMG`] = 100,
    [`WEAPON_SMG`] = 110,
    [`WEAPON_ASSAULTRIFLE`] = 100,
    [`WEAPON_CARBINERIFLE`] = 100,
    [`WEAPON_MINIGUN`] = 50,
}

function Goddess.Detect.Weapon.OnShotFired(src, weaponHash)
    if not Config.Detections.WeaponFireRate then return end
    if Goddess.Security.InGracePeriod(src) then return end

    local base = baseCyclicMs[weaponHash]
    if not base then return end -- no baseline configured, skip rather than false-flag

    fireState[src] = fireState[src] or {}
    local st = fireState[src][weaponHash]
    local now = GetGameTimer()

    if st and st.lastShotTs then
        local interval = now - st.lastShotTs
        local minAllowed = base / Config.Thresholds.MaxFireRateMultiplier
        if interval < minAllowed and interval > 0 then
            Goddess.Security.Report(src, Goddess.Detections.WEAPON_FIRERATE,
                ('interval %dms < min %dms for %s'):format(interval, math.floor(minAllowed), tostring(weaponHash)))
        end
    end

    fireState[src][weaponHash] = fireState[src][weaponHash] or {}
    fireState[src][weaponHash].lastShotTs = now
end

-- ─────────────────────────────────────────────
--  DAMAGE VALIDATION
--  Hooked from server/detections/event.lua's damage event
--  listener, which has authoritative source/target/weapon.
-- ─────────────────────────────────────────────
function Goddess.Detect.Weapon.ValidateDamage(src, weaponHash, damage, baseDamage)
    if not Config.Detections.WeaponDamage then return end
    if not baseDamage or baseDamage <= 0 then return end
    if Goddess.Security.InGracePeriod(src) then return end

    if damage > baseDamage * Config.Thresholds.MaxDamageMultiplier then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_DAMAGE,
            ('%.0f dmg vs base %.0f with %s'):format(damage, baseDamage, tostring(weaponHash)))
    end
end

-- ─────────────────────────────────────────────
--  AMMO MANIPULATION
--  Server periodically compares reported ammo deltas against
--  what could plausibly have been consumed/gained legitimately.
-- ─────────────────────────────────────────────
function Goddess.Detect.Weapon.ValidateAmmoDelta(src, weaponHash, previousAmmo, currentAmmo, shotsFiredSinceLast)
    if not Config.Detections.WeaponAmmo then return end
    if Goddess.Security.InGracePeriod(src) then return end

    -- Ammo increased without a known pickup/refill event, and beyond
    -- what a reload could explain -> suspicious.
    if currentAmmo > previousAmmo + 1000 then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_AMMO,
            ('ammo jumped %d -> %d for %s'):format(previousAmmo, currentAmmo, tostring(weaponHash)))
        return
    end

    -- Ammo did not decrease despite shots fired -> infinite ammo signal.
    if shotsFiredSinceLast and shotsFiredSinceLast > 3 and currentAmmo >= previousAmmo then
        Goddess.Security.Report(src, Goddess.Detections.WEAPON_AMMO,
            ('ammo did not decrease after %d shots (%s)'):format(shotsFiredSinceLast, tostring(weaponHash)))
    end
end

-- ─────────────────────────────────────────────
--  WEAPON SPAWN / EXPLOSIVE ABUSE
-- ─────────────────────────────────────────────
function Goddess.Detect.Weapon.OnWeaponObjectSpawn(src, weaponHash, authorized)
    if not Config.Detections.WeaponSpawn then return end
    if authorized then return end
    Goddess.Security.Report(src, Goddess.Detections.WEAPON_SPAWN, ('unauthorized weapon object spawn: %s'):format(tostring(weaponHash)))
end

local explosiveWeapons = {
    [`WEAPON_RPG`] = true, [`WEAPON_GRENADELAUNCHER`] = true, [`WEAPON_GRENADE`] = true,
    [`WEAPON_STICKYBOMB`] = true, [`WEAPON_PROXMINE`] = true, [`WEAPON_MOLOTOV`] = true,
}

function Goddess.Detect.Weapon.ValidateExplosiveUse(src, weaponHash, authorized)
    if not Config.Detections.WeaponExplosive then return true end
    if not explosiveWeapons[weaponHash] then return true end
    if authorized then return true end

    -- Not inherently a violation (players may legitimately own these),
    -- but flagged if the player was never granted it (authorized=false
    -- means caller confirmed they don't have it in inventory/loadout).
    Goddess.Security.Report(src, Goddess.Detections.WEAPON_EXPLOSIVE, ('explosive weapon use without grant: %s'):format(tostring(weaponHash)))
    return false
end

AddEventHandler('playerDropped', function()
    fireState[source] = nil
end)
