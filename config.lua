Config = {}

-- ═══════════════════════════════════════════════════════════
--  GODDESS — CORE CONFIGURATION
-- ═══════════════════════════════════════════════════════════

Config.Debug = false               -- verbose console output
Config.DebugStats = true           -- track & expose performance stats to admins
Config.Framework = 'esx'           -- 'esx' | 'standalone'
Config.Locale = 'en'

-- ─────────────────────────────────────────────
--  DEPENDENCIES
--  Toggle which optional integrations are active.
--  Goddess must not error if an optional dependency
--  is disabled or fails to start.
-- ─────────────────────────────────────────────
Config.Dependencies = {
    ox_lib       = true,
    oxmysql      = true,   -- required if Config.Database.Enabled = true
    ox_inventory = true,
    ox_target    = false,
}

-- ─────────────────────────────────────────────
--  DATABASE
--  Goddess can run in a fully in-memory mode
--  (no persistence) if Enabled = false.
-- ─────────────────────────────────────────────
Config.Database = {
    Enabled           = true,
    TablePrefix        = 'goddess_',
    PurgeHistoryDays   = 30,       -- 0 = never purge
}

-- ─────────────────────────────────────────────
--  ADMIN SYSTEM
--  Identifiers are NOT hardcoded here — configure
--  per-server. Supports ace permissions as an
--  alternative/complement to the identifier list.
-- ─────────────────────────────────────────────
Config.Admin = {
    -- Add trusted identifiers, e.g. 'license:xxxxxxxx'
    Identifiers = {
        -- 'license:0000000000000000000000000000000000000000',
    },

    -- Alternative: grant via ace permission
    -- add_ace group.admin goddess.admin allow
    UseAcePermission = true,
    AcePermission    = 'goddess.admin',

    -- Players who can never be flagged/punished at all
    -- (use sparingly — dev/testing only)
    FullBypass = {
        -- 'license:0000000000000000000000000000000000000000',
    },
}

-- ─────────────────────────────────────────────
--  PUNISHMENT SYSTEM
-- ─────────────────────────────────────────────
Config.Punishment = {
    Enabled = true,

    -- 'warn' -> 'kick' -> 'tempban' -> 'permban'
    -- Escalation is driven by suspicion score thresholds below,
    -- not by a single detection event.
    Escalation = {
        { score = 30,  action = 'warn'    },
        { score = 60,  action = 'kick'    },
        { score = 100, action = 'tempban', duration = 1440 }, -- minutes (24h)
        { score = 160, action = 'permban' },
    },

    -- Some detections are severe enough to skip escalation
    -- entirely (still requires 2+ confirmations, see detection
    -- modules — Goddess never punishes on a single raw signal).
    InstantActions = {
        -- ['weapon_blacklisted'] = 'kick',
    },

    DefaultBanReason = 'Security violation detected by Goddess',
}

-- ─────────────────────────────────────────────
--  SUSPICION SYSTEM
-- ─────────────────────────────────────────────
Config.Suspicion = {
    DecayEnabled   = true,
    DecayAmount    = 1,        -- points removed
    DecayInterval  = 30000,    -- ms between decay ticks
    MaxScore       = 200,
    -- minimum number of independent detection modules that must
    -- agree within Window (ms) before a score is escalated to punishment
    RequiredConfirmations = 2,
    ConfirmationWindow     = 15000,
}

-- ─────────────────────────────────────────────
--  FALSE-POSITIVE PROTECTION
-- ─────────────────────────────────────────────
Config.Protection = {
    SpawnGraceMs        = 8000,   -- ignore checks right after spawn/connect
    ReviveGraceMs        = 6000,   -- ignore checks right after revive/respawn
    VehicleTransitionMs  = 2000,   -- ignore movement checks on enter/exit vehicle
    TeleportGraceMs      = 3000,   -- ignore movement checks after legit TP (e.g. /tp, job warp)
    MinSignalsToConfirm  = 2,      -- multiple-signal confirmation before flag
    JobExceptions = {
        -- jobs that are allowed elevated behavior (e.g. police, ambulance)
        -- ['police'] = { 'Godmode', 'Weapon' },
    },
}

-- ─────────────────────────────────────────────
--  RATE LIMITING / COOLDOWNS
-- ─────────────────────────────────────────────
Config.RateLimit = {
    DefaultEventCooldownMs = 300,
    DefaultEventMaxPerWindow = 20,
    DefaultEventWindowMs = 10000,
}

-- ─────────────────────────────────────────────
--  DETECTION TOGGLES
-- ─────────────────────────────────────────────
Config.Detections = {
    Godmode        = true,
    Invisible      = true,
    SuperJump      = true,
    Stamina        = true,
    Speed          = true,
    Teleport       = true,
    Noclip         = true,
    Freecam        = true,
    Ragdoll        = true,
    HealthArmor    = true,
    ModelChange    = true,

    WeaponBlacklist   = true,
    WeaponGrant       = true,
    WeaponDamage      = true,
    WeaponFireRate    = true,
    WeaponAmmo        = true,
    WeaponSpawn       = true,
    WeaponExplosive   = true,

    VehicleSpawn      = true,
    VehicleBlacklist  = true,
    VehicleGodmode    = true,
    VehicleSpeed      = true,
    VehicleTeleport   = true,
    VehicleMod        = true,
    VehiclePlate      = true,

    EntityBlacklist   = true,
    EntitySpam        = true,
    EntityOwnership   = true,

    Explosion         = true,
    Event             = true,
}

-- ─────────────────────────────────────────────
--  DETECTION THRESHOLDS
--  Tune per-server. Values chosen conservatively
--  to minimize false positives.
-- ─────────────────────────────────────────────
Config.Thresholds = {
    -- Movement (world units/second, GTA units)
    MaxGroundSpeed        = 12.0,   -- sprint w/ stamina cheat ceiling
    MaxSpeedGraceHits     = 3,      -- consecutive violations required
    MaxVerticalSpeed      = 25.0,   -- superjump / flight
    TeleportDistance      = 60.0,   -- meters moved in one tick without vehicle
    NoclipMinAirTicks     = 5,      -- consecutive ticks colliding-off + moving

    -- Health / armor
    MaxHealthValue = 200,
    MaxArmorValue  = 100,
    HealthRegenPerSecondMax = 25,

    -- Weapons
    MaxFireRateMultiplier = 1.35,   -- vs base weapon cyclic rate
    MaxDamageMultiplier   = 1.5,    -- vs base weapon damage

    -- Vehicles
    MaxVehicleSpeed       = 120.0,  -- m/s ceiling before flag (~430 km/h)
    VehicleTeleportDistance = 80.0,

    -- Entities
    MaxEntitiesPerMinute  = 25,
    MaxEntitiesTotal      = 40,

    -- Explosions
    MaxExplosionsPerMinute = 6,
    MaxExplosionRadius     = 15.0,
}

-- ─────────────────────────────────────────────
--  ADAPTIVE SCANNING
--  Normal players are scanned at a low frequency.
--  Once suspicion rises, scan frequency increases
--  temporarily for that player only.
-- ─────────────────────────────────────────────
Config.Scanning = {
    NormalIntervalMs     = 1500,
    ElevatedIntervalMs   = 400,
    ElevatedThreshold     = 20,    -- suspicion score that triggers elevated scanning
    ElevatedDurationMs    = 60000, -- how long elevated scanning persists after score drops
}

-- ─────────────────────────────────────────────
--  BLACKLISTS / WHITELISTS
-- ─────────────────────────────────────────────
Config.Blacklist = {
    Weapons = {
        `WEAPON_RAILGUNXM3`,
    },
    Vehicles = {
        -- `SCRAMJET`,
    },
    Peds = {
        -- `a_c_cat_01`,
    },
    Objects = {
        -- `prop_atm_01`,
    },
    ExplosionTypes = {
        -- 22, -- EXP_TAG_ROGUE (example: disallow rogue drone explosions client-triggered)
    },
}

Config.Whitelist = {
    Weapons = {}, -- if non-empty, ONLY these weapons are permitted server-wide
    Vehicles = {}, -- if non-empty, ONLY these models are spawnable via natives Goddess monitors
}

-- ─────────────────────────────────────────────
--  PROTECTED EVENTS
--  Events registered here are wrapped with
--  Goddess.RegisterSecureEvent automatically.
--  Extend this list (or use the export directly
--  from your own resources) to protect more events.
-- ─────────────────────────────────────────────
Config.ProtectedEvents = {
    -- name = { cooldown, maxPerWindow, windowMs }
}

-- ─────────────────────────────────────────────
--  LOGGING (Discord Webhooks)
--  NEVER reference these from client-side code.
--  Leave blank to disable a category.
-- ─────────────────────────────────────────────
Config.Logging = {
    Enabled = true,
    BotName = 'Goddess',
    BotAvatar = '',

    Webhooks = {
        Detection    = '',
        Kick         = '',
        Ban          = '',
        AdminAction  = '',
        Security     = '',
        ResourceError = '',
    },

    Colors = {
        Detection = 15105570,  -- orange
        Kick      = 15158332,  -- red
        Ban       = 10038562,  -- dark red
        Admin     = 3447003,   -- blue
        Security  = 15844367,  -- gold
        Error     = 9807270,   -- grey
    },
}

-- ─────────────────────────────────────────────
--  VERSION / UPDATE CHECK
-- ─────────────────────────────────────────────
Config.Version = {
    Number = '1.0.0',
    CheckForUpdates = false, -- disabled by default; no endpoint hardcoded
    UpdateCheckUrl = '',     -- set your own trusted endpoint if desired
}
