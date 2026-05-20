# ws-objectspawner
-- WS SCRIPTS
> **RedM** · RSG Core · ox_lib · oxmysql  
> Version 1.0.0 — Lua 5.4

A server-side persistent object spawner for RedM servers running the **rsg-core** framework. Admins can place, edit, and delete world objects through an in-game `ox_lib` context menu. All objects are saved to a MySQL database and automatically re-spawned whenever the resource restarts.

---

## Features

- `/object` command opens a clean `ox_lib` context menu (admin-only)
- **Live laser placement** — a semi-transparent preview object follows your camera raycast in real time
- **Keyboard fine-tuning** during placement (move, rotate, reset offset, toggle laser / manual mode)
- **Saved objects panel** — list every DB object with its ID, model, and coordinates
- Per-object actions: teleport to, change model, toggle freeze, reposition via laser, edit coordinates manually, delete (with confirmation)
- All changes **instantly broadcast** to every connected client via a server-triggered refresh event
- Objects auto-respawn on `onResourceStart` and are cleaned up on `onResourceStop`
- Admin check is dual-layered: rsg-core permission group **and** ace permission `command.object`

---

## Dependencies

| Resource | Role |
|---|---|
| `rsg-core` | Framework core — player data, callbacks, permissions |
| `ox_lib` | UI (context menus, input dialogs, notifications, text UI) |
| `oxmysql` | Async MySQL wrapper for persistent storage |

---

## Installation

1. Copy the `ws-objectspawner` folder into your server's `resources/` directory.

2. Import the database table:
   ```sql
   SOURCE install.sql;
   ```

3. Add to your `server.cfg` **after** the three dependencies:
   ```
   ensure rsg-core
   ensure ox_lib
   ensure oxmysql
   ensure ws-objectspawner
   ```

---

## Configuration (`config.lua`)

| Key | Default | Description |
|---|---|---|
| `Config.Command` | `'object'` | Chat command that opens the spawner menu |
| `Config.AdminGroup` | `'admin'` | rsg-core permission group required to use the spawner |
| `Config.LaserDistance` | `50.0` | Maximum raycast distance in metres for laser placement |
| `Config.RenderDistance` | `150.0` | Intended render distance for saved objects *(currently rendered globally)* |
| `Config.MoveStep` | `0.05` | X/Y/Z step size (metres) for keyboard fine-adjustment |
| `Config.RotateStep` | `2.5` | Heading step size (degrees) for Q/E rotation |

---

## Permissions

Access is granted when **either** condition is met:

- The player's rsg-core group matches `Config.AdminGroup` (default: `admin`)
- The player has the ace permission `command.object`

To grant the ace permission manually in `server.cfg`:
```
add_ace identifier.license:XXXXXXXX command.object allow
```

---

## Placement Controls

| Key | Action |
|---|---|
| `LMB` / `Enter` | Confirm placement |
| `RMB` / `Backspace` | Cancel placement |
| `Space` | Toggle laser raycast ↔ manual mode |
| `Arrow Up / Down` | Move on Y axis |
| `Arrow Left / Right` | Move on X axis |
| `Page Up / Page Down` | Move on Z axis (height) |
| `Q` | Rotate heading clockwise |
| `E` | Rotate heading counter-clockwise |
| `R` | Reset manual offset to zero |

---

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS `objectspawner_objects` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `model`      VARCHAR(100) NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `heading`    FLOAT        NOT NULL DEFAULT 0,
    `frozen`     TINYINT(1)   NOT NULL DEFAULT 1,
    `created_by` VARCHAR(60)  DEFAULT NULL,  -- citizenid of the admin who placed it
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## File Structure

```
ws-objectspawner/
├── client/
│   └── main.lua        # UI menus, placement loop, object rendering
├── server/
│   └── main.lua        # Callbacks, DB operations, permission checks
├── config.lua          # All configurable values
├── fxmanifest.lua      # Resource manifest (FiveM/RedM)
├── install.sql         # Database table definition
└── README.md
```

---

## Events & Callbacks Reference

| Name | Side | Type | Description |
|---|---|---|---|
| `rsg-objectspawner:server:getObjects` | Server | Callback | Returns all saved objects from the DB |
| `rsg-objectspawner:server:saveObject` | Server | Callback | Inserts a new object row, returns its ID |
| `rsg-objectspawner:server:updateObject` | Server | Net Event | Updates model, coords, heading, frozen for an existing object |
| `rsg-objectspawner:server:deleteObject` | Server | Net Event | Deletes an object row by ID |
| `rsg-objectspawner:client:refresh` | Client | Net Event | Triggers a full re-fetch and re-spawn of all saved objects |

---

## Notes

- Models must be valid RDR3 object hashes. The script validates with `IsModelInCdimage` before spawning and will notify the admin if the model is invalid.
- The `created_by` column stores the player's `citizenid` for audit purposes.
- Objects are rendered **globally** on all clients regardless of `Config.RenderDistance` in the current implementation.
