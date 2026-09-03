-- ═══════════════════════════════════════════════════════════
--  GODDESS — DATABASE LAYER
--  Wraps oxmysql. If Config.Database.Enabled is false, or
--  oxmysql is unavailable, Goddess degrades to in-memory-only
--  mode instead of crashing.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.DB = {}

local prefix = Config.Database.TablePrefix
local ready = false

local function tableName(name)
    return prefix .. name
end
Goddess.DB.TableName = tableName

--- Determine whether persistence is actually usable this session.
local function checkAvailable()
    if not Config.Database.Enabled then
        Goddess.Utils.Print('Database disabled in config — running in-memory only.')
        return false
    end
    if not Config.Dependencies.oxmysql then
        Goddess.Utils.Error('Database enabled but oxmysql dependency is disabled in config. Falling back to in-memory mode.')
        return false
    end
    if GetResourceState('oxmysql') ~= 'started' then
        Goddess.Utils.Error('oxmysql is not running. Falling back to in-memory mode.')
        return false
    end
    return true
end

function Goddess.DB.IsReady()
    return ready
end

--- Runs at resource start. Creates tables if they do not exist.
function Goddess.DB.Init(cb)
    ready = checkAvailable()
    if not ready then
        if cb then cb(false) end
        return
    end

    local ok = Goddess.Utils.Safe(function()
        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS ]] .. tableName('bans') .. [[ (
                id INT AUTO_INCREMENT PRIMARY KEY,
                player_name VARCHAR(100),
                license VARCHAR(100) INDEX,
                discord VARCHAR(100),
                rockstar VARCHAR(100),
                ip VARCHAR(64),
                reason VARCHAR(255),
                detection VARCHAR(100),
                evidence TEXT,
                admin VARCHAR(100),
                banned_at BIGINT,
                expires_at BIGINT DEFAULT NULL,
                active TINYINT(1) DEFAULT 1,
                goddess_version VARCHAR(20)
            )
        ]], {})

        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS ]] .. tableName('detections') .. [[ (
                id INT AUTO_INCREMENT PRIMARY KEY,
                player_name VARCHAR(100),
                license VARCHAR(100) INDEX,
                detection VARCHAR(100),
                severity INT,
                score_after INT,
                details TEXT,
                created_at BIGINT
            )
        ]], {})

        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS ]] .. tableName('detection_history') .. [[ (
                id INT AUTO_INCREMENT PRIMARY KEY,
                license VARCHAR(100) INDEX,
                action VARCHAR(30),
                reason VARCHAR(255),
                admin VARCHAR(100),
                created_at BIGINT
            )
        ]], {})
    end)

    if not ok then
        ready = false
        if cb then cb(false) end
        return
    end

    Goddess.Utils.Print('Database schema verified.')
    if cb then cb(true) end
end

-- ─────────────────────────────────────────────
--  BANS
-- ─────────────────────────────────────────────
function Goddess.DB.InsertBan(data, cb)
    if not ready then if cb then cb(nil) end return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:insert('INSERT INTO ' .. tableName('bans') ..
            ' (player_name, license, discord, rockstar, ip, reason, detection, evidence, admin, banned_at, expires_at, active, goddess_version) ' ..
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)',
            {
                data.playerName, data.license, data.discord, data.rockstar, data.ip,
                data.reason, data.detection, data.evidence, data.admin,
                data.bannedAt, data.expiresAt, Goddess.Version,
            }, function(id)
                if cb then cb(id) end
            end)
    end)
end

function Goddess.DB.GetActiveBan(license, cb)
    if not ready then if cb then cb(nil) end return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:single('SELECT * FROM ' .. tableName('bans') ..
            ' WHERE license = ? AND active = 1 ORDER BY id DESC LIMIT 1',
            { license }, function(row)
                if cb then cb(row) end
            end)
    end)
end

function Goddess.DB.Unban(license, cb)
    if not ready then if cb then cb(false) end return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:update('UPDATE ' .. tableName('bans') ..
            ' SET active = 0 WHERE license = ? AND active = 1',
            { license }, function(affected)
                if cb then cb(affected and affected > 0) end
            end)
    end)
end

function Goddess.DB.GetAllBans(cb)
    if not ready then if cb then cb({}) end return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:query('SELECT * FROM ' .. tableName('bans') ..
            ' WHERE active = 1 ORDER BY banned_at DESC LIMIT 200', {}, function(rows)
                if cb then cb(rows or {}) end
            end)
    end)
end

-- ─────────────────────────────────────────────
--  DETECTIONS
-- ─────────────────────────────────────────────
function Goddess.DB.InsertDetection(data)
    if not ready then return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:insert('INSERT INTO ' .. tableName('detections') ..
            ' (player_name, license, detection, severity, score_after, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            {
                data.playerName, data.license, data.detection, data.severity,
                data.scoreAfter, data.details, data.createdAt,
            })
    end)
end

function Goddess.DB.GetRecentDetections(limit, cb)
    if not ready then if cb then cb({}) end return end
    limit = limit or 50
    Goddess.Utils.Safe(function()
        exports.oxmysql:query('SELECT * FROM ' .. tableName('detections') ..
            ' ORDER BY created_at DESC LIMIT ?', { limit }, function(rows)
                if cb then cb(rows or {}) end
            end)
    end)
end

function Goddess.DB.GetDetectionHistoryForLicense(license, cb)
    if not ready then if cb then cb({}) end return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:query('SELECT * FROM ' .. tableName('detections') ..
            ' WHERE license = ? ORDER BY created_at DESC LIMIT 100', { license }, function(rows)
                if cb then cb(rows or {}) end
            end)
    end)
end

-- ─────────────────────────────────────────────
--  ADMIN ACTION HISTORY
-- ─────────────────────────────────────────────
function Goddess.DB.InsertHistory(license, action, reason, admin)
    if not ready then return end
    Goddess.Utils.Safe(function()
        exports.oxmysql:insert('INSERT INTO ' .. tableName('detection_history') ..
            ' (license, action, reason, admin, created_at) VALUES (?, ?, ?, ?, ?)',
            { license, action, reason, admin, os.time() * 1000 })
    end)
end

-- ─────────────────────────────────────────────
--  MAINTENANCE
-- ─────────────────────────────────────────────
function Goddess.DB.PurgeOldHistory()
    if not ready then return end
    local days = Config.Database.PurgeHistoryDays
    if not days or days <= 0 then return end
    local cutoff = (os.time() - (days * 86400)) * 1000
    Goddess.Utils.Safe(function()
        exports.oxmysql:execute('DELETE FROM ' .. tableName('detections') .. ' WHERE created_at < ?', { cutoff })
    end)
end
