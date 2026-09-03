-- ═══════════════════════════════════════════════════════════
--  GODDESS — NATIVE GAME EVENT HOOKS
--  Wires FiveM's built-in server-side events (which are
--  authoritative and not directly spoofable by a client) into
--  the relevant detection modules.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}

-- ─────────────────────────────────────────────
--  EXPLOSIONS
-- ─────────────────────────────────────────────
AddEventHandler('explosionEvent', function(src, data)
    Goddess.Utils.Safe(Goddess.Detect.Explosion.Handle, src, {
        explosionType = data.explosionType,
        radius = data.meta and data.meta.damageScale and (data.meta.damageScale * 10.0) or nil,
        posX = data.posX, posY = data.posY, posZ = data.posZ,
    })
end)

-- ─────────────────────────────────────────────
--  WEAPON DAMAGE
--  weaponDamageEvent gives us server-truth about who damaged
--  whom, with what weapon, and how much — the client cannot
--  lie about this from Goddess's perspective since we read it
--  from the server event itself, not a client signal.
-- ─────────────────────────────────────────────
local baseDamageTable = {
    -- conservative baseline damage values for common weapons;
    -- extend with your server's actual weapon balancing.
    [`WEAPON_PISTOL`] = 25, [`WEAPON_COMBATPISTOL`] = 26, [`WEAPON_MICROSMG`] = 22,
    [`WEAPON_SMG`] = 24, [`WEAPON_ASSAULTRIFLE`] = 30, [`WEAPON_CARBINERIFLE`] = 32,
    [`WEAPON_PUMPSHOTGUN`] = 40, [`WEAPON_SNIPERRIFLE`] = 90,
}

AddEventHandler('weaponDamageEvent', function(src, data)
    if not data or not data.weaponType then return end
    local base = baseDamageTable[data.weaponType]
    if not base then return end

    local damage = data.weaponDamage or 0
    Goddess.Utils.Safe(Goddess.Detect.Weapon.ValidateDamage, src, data.weaponType, damage, base)

    -- Hitting a target whose health never drops despite repeated
    -- confirmed damage events is a strong godmode signal on the
    -- *target's* side, tracked separately (see main.lua health poll).
end)

-- ─────────────────────────────────────────────
--  ENTITY LIFECYCLE
-- ─────────────────────────────────────────────
AddEventHandler('entityCreated', function(entity)
    if not DoesEntityExist(entity) then return end
    Goddess.Utils.Safe(Goddess.Detect.Entity.OnEntityCreated, entity)
end)

AddEventHandler('entityRemoved', function(entity)
    Goddess.Utils.Safe(Goddess.Detect.Entity.OnEntityRemoved, entity)
end)

-- ─────────────────────────────────────────────
--  PLAYER CONNECT — BAN GATE
-- ─────────────────────────────────────────────
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    Citizen.Wait(0)
    deferrals.update('Goddess: verifying account…')

    local ids = Goddess.Utils.GetIdentifiers(src)
    if not ids.license then
        deferrals.done('Goddess: could not verify your license identifier.')
        return
    end

    Goddess.Punishment.CheckBanOnConnect(ids.license, function(banned, ban)
        if banned then
            local reason = ban and ban.reason or Config.Punishment.DefaultBanReason
            local expiry = ban and ban.expires_at
            local expiryText = (expiry and expiry > 0) and ('Expires: ' .. os.date('%Y-%m-%d %H:%M UTC', expiry / 1000)) or 'Permanent ban'
            deferrals.done(('You are banned from this server.\nReason: %s\n%s'):format(reason, expiryText))
        else
            deferrals.done()
        end
    end)
end)

AddEventHandler('playerJoining', function()
    Goddess.Security.OnPlayerConnected(source)
end)
