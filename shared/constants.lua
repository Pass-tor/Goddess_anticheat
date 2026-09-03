-- ═══════════════════════════════════════════════════════════
--  GODDESS — SHARED CONSTANTS
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Version = Config.Version.Number

Goddess.Events = {
    -- client -> server signals (never trusted as final verdict)
    SIGNAL          = 'goddess:signal',
    -- server -> client
    SYNC_CONFIG     = 'goddess:syncConfig',
    ADMIN_PUSH      = 'goddess:adminPush',
    NUI_OPEN        = 'goddess:nuiOpen',
    NUI_DATA        = 'goddess:nuiData',
}

Goddess.Detections = {
    GODMODE          = 'godmode',
    INVISIBLE        = 'invisible',
    SUPERJUMP        = 'superjump',
    STAMINA          = 'stamina',
    SPEED            = 'speed',
    TELEPORT         = 'teleport',
    NOCLIP           = 'noclip',
    FREECAM          = 'freecam',
    RAGDOLL          = 'ragdoll',
    HEALTH_ARMOR     = 'health_armor',
    MODEL_CHANGE     = 'model_change',

    WEAPON_BLACKLIST = 'weapon_blacklisted',
    WEAPON_GRANT     = 'weapon_unauthorized_grant',
    WEAPON_DAMAGE    = 'weapon_damage',
    WEAPON_FIRERATE  = 'weapon_firerate',
    WEAPON_AMMO      = 'weapon_ammo',
    WEAPON_SPAWN     = 'weapon_spawn',
    WEAPON_EXPLOSIVE = 'weapon_explosive',

    VEHICLE_SPAWN     = 'vehicle_spawn',
    VEHICLE_BLACKLIST = 'vehicle_blacklisted',
    VEHICLE_GODMODE   = 'vehicle_godmode',
    VEHICLE_SPEED     = 'vehicle_speed',
    VEHICLE_TELEPORT  = 'vehicle_teleport',
    VEHICLE_MOD       = 'vehicle_mod',
    VEHICLE_PLATE     = 'vehicle_plate',

    ENTITY_BLACKLIST  = 'entity_blacklisted',
    ENTITY_SPAM       = 'entity_spam',
    ENTITY_OWNERSHIP  = 'entity_ownership',

    EXPLOSION         = 'explosion_abuse',
    EVENT_ABUSE       = 'event_abuse',
}

-- Severity weight added to suspicion score per detection type.
-- Kept here (shared) so client display + server logic agree.
Goddess.Severity = {
    godmode = 25, invisible = 20, superjump = 15, stamina = 10, speed = 12,
    teleport = 20, noclip = 25, freecam = 20, ragdoll = 10, health_armor = 15,
    model_change = 8,

    weapon_blacklisted = 30, weapon_unauthorized_grant = 25, weapon_damage = 18,
    weapon_firerate = 15, weapon_ammo = 15, weapon_spawn = 20, weapon_explosive = 30,

    vehicle_spawn = 12, vehicle_blacklisted = 20, vehicle_godmode = 20,
    vehicle_speed = 15, vehicle_teleport = 20, vehicle_mod = 8, vehicle_plate = 10,

    entity_blacklisted = 20, entity_spam = 15, entity_ownership = 10,

    explosion_abuse = 25, event_abuse = 15,
}

Goddess.PunishmentActions = {
    WARN     = 'warn',
    KICK     = 'kick',
    TEMPBAN  = 'tempban',
    PERMBAN  = 'permban',
}
