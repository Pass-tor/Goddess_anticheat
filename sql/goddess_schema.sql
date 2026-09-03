-- ═══════════════════════════════════════════════════════════
--  GODDESS — DATABASE SCHEMA
--  These tables are also created automatically at resource
--  start (see server/database.lua) via CREATE TABLE IF NOT
--  EXISTS. This file is provided for manual review/import and
--  for server owners who prefer to provision schema up front.
--
--  Table prefix is configurable via Config.Database.TablePrefix
--  (default: goddess_). Update the names below to match if you
--  changed it.
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `goddess_bans` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_name` VARCHAR(100),
    `license` VARCHAR(100),
    `discord` VARCHAR(100),
    `rockstar` VARCHAR(100),
    `ip` VARCHAR(64),
    `reason` VARCHAR(255),
    `detection` VARCHAR(100),
    `evidence` TEXT,
    `admin` VARCHAR(100),
    `banned_at` BIGINT,
    `expires_at` BIGINT DEFAULT NULL,
    `active` TINYINT(1) DEFAULT 1,
    `goddess_version` VARCHAR(20),
    INDEX `idx_goddess_bans_license` (`license`),
    INDEX `idx_goddess_bans_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `goddess_detections` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_name` VARCHAR(100),
    `license` VARCHAR(100),
    `detection` VARCHAR(100),
    `severity` INT,
    `score_after` INT,
    `details` TEXT,
    `created_at` BIGINT,
    INDEX `idx_goddess_detections_license` (`license`),
    INDEX `idx_goddess_detections_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `goddess_detection_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `license` VARCHAR(100),
    `action` VARCHAR(30),
    `reason` VARCHAR(255),
    `admin` VARCHAR(100),
    `created_at` BIGINT,
    INDEX `idx_goddess_history_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
