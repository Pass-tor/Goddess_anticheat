-- ═══════════════════════════════════════════════════════════
--  GODDESS — CLIENT ENTITY DETECTIONS
--  The authoritative entity-spam / blacklist checks live
--  server-side (server/detections/entity.lua) via the native
--  `entityCreated` event, which cannot be bypassed by a
--  modified client. This module exists as an extension point
--  for future local heuristics (e.g. flagging suspicious prop
--  attachment patterns) and intentionally stays minimal to
--  avoid wasted per-tick cost.
-- ═══════════════════════════════════════════════════════════

Goddess = Goddess or {}
Goddess.Detect = Goddess.Detect or {}
Goddess.Detect.Entity = {}

function Goddess.Detect.Entity.Tick(ped)
    -- Intentionally minimal — see header comment.
end
