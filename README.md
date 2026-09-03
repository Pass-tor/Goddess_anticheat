# Goddess

A modular, server-authoritative security system for FiveM / ESX Legacy servers, with optional integration for ox_lib, ox_inventory, ox_target, and oxmysql.

Goddess is **not** a silver bullet. It is a layered detection and response system designed to raise the cost of cheating and give administrators real tools and visibility — not to claim perfect, unbypassable protection. See [Security Limitations](#security-limitations) below.

---

## 1. Folder Structure

```
Goddess/
├── fxmanifest.lua
├── config.lua
├── README.md
├── install/
│   ├── install.lua          -- goddess_install verification command
│   └── uninstall.lua        -- goddess_uninstall command
├── sql/
│   └── goddess_schema.sql   -- reference schema (also auto-created)
├── shared/
│   ├── constants.lua        -- events, detection keys, severity weights
│   └── utils.lua            -- shared helper functions
├── client/
│   ├── main.lua              -- bootstrap, NUI wiring
│   ├── modules/
│   │   ├── state.lua         -- local grace/elevation state
│   │   └── scanner.lua       -- adaptive scan loop dispatcher
│   └── detections/
│       ├── player.lua        -- invisible/superjump/stamina/noclip/freecam/model
│       ├── weapon.lua        -- fire-rate + ammo signals
│       ├── vehicle.lua       -- enter/exit transition tracking
│       └── entity.lua        -- extension point
├── server/
│   ├── main.lua               -- signal router, polling loop, NUI data
│   ├── security.lua           -- suspicion scoring engine (the core)
│   ├── secure_event.lua       -- Goddess.RegisterSecureEvent API
│   ├── punishment.lua         -- warn/kick/tempban/permban + escalation
│   ├── admin.lua               -- admin permissions + chat commands
│   ├── logging.lua             -- Discord webhook logging
│   ├── database.lua            -- oxmysql wrapper, degrades gracefully
│   └── detections/
│       ├── player.lua          -- server-side validation of player signals
│       ├── weapon.lua          -- weapon grant/damage/fire-rate/ammo validation
│       ├── vehicle.lua         -- vehicle spawn/speed/godmode/mod validation
│       ├── entity.lua          -- entity spam/blacklist/ownership validation
│       ├── explosion.lua       -- explosion frequency/type/radius validation
│       └── event.lua            -- native game-event hooks (damage, explosions, connect)
└── web/
    ├── index.html               -- admin NUI dashboard
    ├── style.css
    └── app.js
```

---

## 2. Installation

1. Copy the `Goddess` folder into your server's `resources/` directory.
2. Add to `server.cfg` **after** `ox_lib` and `oxmysql`:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure Goddess
   ```
3. Import `sql/goddess_schema.sql` if you prefer manual schema provisioning — otherwise Goddess creates its own tables automatically on first start (`CREATE TABLE IF NOT EXISTS`).
4. Edit `config.lua`:
   - Set `Config.Admin.Identifiers` with your trusted license identifiers, **or** enable `Config.Admin.UseAcePermission` and grant the `goddess.admin` ace permission to your admin group.
   - Set your Discord webhook URLs under `Config.Logging.Webhooks` (optional).
   - Review `Config.Thresholds` for your server's playstyle.
5. Start the server, then in the **server console** run:
   ```
   goddess_install
   ```
   This verifies dependencies, config sanity, and database connectivity, and prints a clear pass/fail report. It does not modify anything — it's read-only verification.

### Uninstalling

FiveM's Lua sandbox has no API for a resource to delete its own files or unload arbitrary server state — there is no true `Goddess uninstall` executable. The safest practical process:

1. In the server console: `goddess_uninstall` (add `--purge-database` to additionally drop **only** the `goddess_`-prefixed tables — no other tables are ever touched).
2. Remove `ensure Goddess` from `server.cfg`.
3. Delete the `resources/Goddess` folder.
4. Remove any `goddess.admin` ace grants you added.

---

## 3. Configuration

All behavior is controlled from `config.lua`. Key sections:

| Section | Purpose |
|---|---|
| `Config.Dependencies` | Toggle optional integrations (ox_lib, oxmysql, ox_inventory, ox_target) |
| `Config.Database` | Enable/disable persistence, table prefix, history retention |
| `Config.Admin` | Admin identifiers, ace permission, full-bypass list |
| `Config.Punishment` | Escalation ladder (score → action), instant actions |
| `Config.Suspicion` | Decay rate, confirmation requirements |
| `Config.Protection` | Grace periods, job exceptions, false-positive tuning |
| `Config.RateLimit` | Default cooldowns for secure events |
| `Config.Detections` | Per-module on/off toggles |
| `Config.Thresholds` | Numeric sensitivity for every detection |
| `Config.Scanning` | Adaptive scan interval tuning |
| `Config.Blacklist` / `Config.Whitelist` | Weapons, vehicles, peds, objects |
| `Config.Logging` | Discord webhook URLs (server-side only, never sent to clients) |

**Nothing is hardcoded** — no identifiers, no webhook URLs, no server-specific assumptions ship pre-filled.

---

## 4. Integration Examples

### Protecting an ESX event

```lua
-- server-side, in your own resource
exports.Goddess:RegisterSecureEvent('esx_shops:buyItem', {
    cooldown = 500,
    maxPerWindow = 10,
    windowMs = 10000,
    validateArgs = function(src, shopType, itemName, price, count)
        if type(itemName) ~= 'string' or type(price) ~= 'number' then
            return false, 'malformed args'
        end
        if price < 0 or price > 1000000 then
            return false, 'implausible price'
        end
        return true
    end,
}, function(src, shopType, itemName, price, count)
    -- your real handler — only runs if all checks above passed
end)
```

### Protecting an ox_inventory-related event

```lua
exports.Goddess:RegisterSecureEvent('myresource:ox_inventory:useItem', {
    cooldown = 300,
    job = { 'police', 'ambulance' }, -- example job restriction
    validateArgs = function(src, itemName, slot)
        local xPlayer = exports.ox_inventory:GetInventory(src)
        if not xPlayer then return false, 'no inventory context' end
        local item = exports.ox_inventory:GetSlot(src, slot)
        if not item or item.name ~= itemName then
            return false, 'slot/item mismatch'
        end
        return true
    end,
}, function(src, itemName, slot)
    -- real handler
end)
```

### Reading suspicion score / clearing it from your own resource

```lua
local score = exports.Goddess:GetSuspicionScore(playerId)
exports.Goddess:ClearSuspicion(playerId)
local isAdmin = exports.Goddess:IsGoddessAdmin(playerId)
```

---

## 5. Admin Commands

All commands respect `Config.Admin.Identifiers` / the `goddess.admin` ace permission.

| Command | Description |
|---|---|
| `/goddess:dashboard` | Open the NUI dashboard |
| `/goddess:staffmode` | Toggle personal exemption from detections while on duty |
| `/goddess:suspicion [id]` | View a player's current suspicion score |
| `/goddess:clear [id]` | Clear a player's suspicion score |
| `/goddess:kick [id] [reason]` | Manually kick a player |
| `/goddess:ban [id] [minutes\|0] [reason]` | Manually ban a player (0 = permanent) |
| `/goddess:unban [license]` | Lift a ban |
| `/goddess:history [license]` | View recent detection history for a license |
| `goddess_install` (console) | Run installation verification |
| `goddess_uninstall [--purge-database]` (console) | Stop Goddess and optionally purge only its own tables |

---

## 6. Detection Explanation

Every detection follows the same pipeline:

```
Client signal (untrusted) → Server validation → Suspicion score → Multi-signal confirmation → Escalation → Punishment
```

- **Client modules** (`client/detections/*.lua`) only ever emit *signals* — they never decide punishment.
- **Server modules** (`server/detections/*.lua`) re-validate every signal against server-known state (positions, health, native game events) before it can affect anything.
- **`Goddess.Security.Report`** is the single choke point all detections flow through. It requires either repeated occurrences of the same detection, or corroboration from a second, independent detection type, within `Config.Suspicion.ConfirmationWindow`, before the suspicion score is actually increased. Isolated, one-off signals are logged for visibility but do not score.
- **Escalation** only fires when the cumulative score crosses a new tier in `Config.Punishment.Escalation` — a player is never banned off a single detection.
- Grace periods (spawn, revive, vehicle transitions, legitimate teleports) suppress scoring entirely during known false-positive windows.

Detections that rely purely on native game events fired server-side (`explosionEvent`, `weaponDamageEvent`, `entityCreated`, `playerConnecting`) are the strongest signals, since those events cannot be spoofed by a modified client the way a custom client-to-server message can.

---

## 7. Performance Notes

- A single adaptive scanner thread drives all client detections instead of one thread per check.
- Normal players are scanned every `Config.Scanning.NormalIntervalMs` (default 1500ms); once a player's suspicion crosses `Config.Scanning.ElevatedThreshold`, **only that player** is scanned at `Config.Scanning.ElevatedIntervalMs` (default 400ms) for `Config.Scanning.ElevatedDurationMs`.
- Server-side polling (health/armor, vehicle godmode/plate) runs once per `Config.Scanning.NormalIntervalMs` across all online players in a single loop — no per-player threads.
- Position/teleport signals are decoupled from the heavier per-tick detection loop and sent on a fixed lightweight interval to keep both bandwidth and CPU cost predictable regardless of player count.
- Database writes are async (oxmysql) and never block detection logic; a slow or unavailable database degrades to in-memory-only mode rather than stalling the resource.
- Enable `Config.DebugStats` to see scanner tick-rate output in `Config.Debug` console logs.

---

## 8. Security Limitations

Read this section before assuming Goddess makes your server "uncheatable." It does not, and no client-side Lua system can.

- **The FiveM client is fundamentally untrusted.** A sufficiently motivated attacker can modify their own client, memory, or network traffic. Client-side detections in this resource are *signals*, not proof — that's why every meaningful punishment path routes through server-side validation and multi-signal confirmation.
- **Server-authoritative checks are the real protection.** Native game events (`weaponDamageEvent`, `explosionEvent`, `entityCreated`, position deltas measured server-side) are far harder to spoof than a client-reported value, and Goddess leans on those wherever FiveM exposes them.
- **No single native or function check is treated as final.** Detections require corroboration before they affect a player's score, specifically to resist attackers who find a way to suppress or spoof one signal.
- **Custom/undetectable clients can still exist.** If an attacker fully controls their game client and only ever sends network traffic that looks legitimate (correct positions, correct damage, correct event arguments), no server-side system — Goddess included — can distinguish that traffic from a legitimate player using only Lua-level tools. This is a fundamental limitation of the platform, not a bug.
- **Resource integrity checks are limited.** FXServer does not give resources a general way to verify the integrity of other client-side game memory or files; Goddess's "resource integrity" posture is limited to what natives and event data actually expose.
- **This is one layer, not a complete security program.** Combine Goddess with server-side economy validation in your other resources (via `Goddess.RegisterSecureEvent`), sensible ACE permissions, keeping FXServer and dependencies updated, and human moderation.

---

## 9. Final Audit Report

Internal review performed before delivery:

- **Syntax/consistency:** All function names, exports, and event names referenced across client/server files were cross-checked against their definitions (`Goddess.Security.*`, `Goddess.Detect.*`, `Goddess.Punishment.*`, `Goddess.DB.*`, `Goddess.Log.*`, `Goddess.Admin.*`).
- **Load order:** `fxmanifest.lua` lists shared → client/server files in dependency order (constants/utils before modules that use them; database/logging/admin/punishment/security before the detection modules and `main.lua` that call them).
- **Missing functions:** None left as TODO/placeholder — every function referenced has a real implementation, including fallbacks (e.g. `Goddess.DB.*` no-ops safely when persistence is disabled).
- **Client/server boundary:** No server-only natives (`DropPlayer`, `GetPlayerIdentifier`, database calls) are referenced from client files, and vice versa; verified by file.
- **Nil-safety:** All detection entrypoints guard against nil peds/entities/sources before use; `Goddess.Utils.Safe` wraps every module tick and event handler so one failing check cannot crash the resource.
- **SQL:** Table/column names in `sql/goddess_schema.sql` match `server/database.lua` exactly; all queries are parameterized (no string-concatenated user input) to prevent injection; the table prefix is applied consistently.
- **Dependency mistakes:** `Config.Dependencies` toggles are checked before `oxmysql`/`ox_lib`/`ox_inventory` exports are called anywhere in the codebase; `Goddess.DB.Init` explicitly checks `GetResourceState('oxmysql')` before use.
- **False positives:** Grace periods (spawn/revive/vehicle-transition/teleport), multi-signal confirmation, and score decay are all implemented and enabled by default with conservative thresholds.
- **Bypass resistance:** No punishment path is reachable from a single client-reported value without server-side re-validation or corroboration; explosion/damage/entity detections prefer native server events over client signals wherever FiveM provides them.
- **Performance:** No `Wait(0)` loops; all threads use configurable intervals; adaptive scanning avoids uniformly polling every player at high frequency.
- **Uninstall safety:** The database purge command scopes every `DROP TABLE` to `Config.Database.TablePrefix`-prefixed names only.
- **Known non-goals / honest limitations:** documented explicitly above rather than implied away.

Goddess v1.0.0
