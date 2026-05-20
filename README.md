<div align="center">

<img src="https://img.shields.io/badge/RedM-Resource-darkred?style=for-the-badge&logo=github" />
<img src="https://img.shields.io/badge/RSG--Core-Required-8B0000?style=for-the-badge" />
<img src="https://img.shields.io/badge/ox__lib-Required-orange?style=for-the-badge" />
<img src="https://img.shields.io/badge/oxmysql-Required-yellow?style=for-the-badge" />
<img src="https://img.shields.io/badge/Version-1.0.0-brightgreen?style=for-the-badge" />
<img src="https://img.shields.io/badge/Lua-5.4-blue?style=for-the-badge&logo=lua" />

<br/><br/>

# 🗂️ WS — Object Spawner

**A persistent, admin-only world object spawner for RedM (rdr3) built on RSG Core.**  
Place, edit, freeze, reposition, and delete objects — all saved to MySQL and restored on every restart.

<br/>

> 💡 Developed by **[wsscripts](https://github.com/wsscripts)**

</div>

---

## 📸 Preview

<table>
  <tr>
    <td align="center"><b>Main Menu</b></td>
    <td align="center"><b>New Object Dialog</b></td>
  </tr>
  <tr>
    <td><img src="https://i.ibb.co/rfFbfwvF/Capture.png" width="400"/></td>
    <td><img src="https://i.ibb.co/rfsNgbBt/Capture2.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center"><b>Saved Objects Panel</b></td>
    <td align="center"><b>Placement Preview</b></td>
  </tr>
  <tr>
    <td><img src="https://i.ibb.co/1tHVqDhD/Capture3.png" width="400"/></td>
    <td><img src="https://i.ibb.co/BFZtzCP/Capture4.png" width="400"/></td>
  </tr>
</table>

---

## ✨ Features

- 🎯 `/object` command opens a polished `ox_lib` context menu — **admin only**
- 🔦 **Live laser raycast preview** — semi-transparent ghost object follows your camera in real time
- ⌨️ **Keyboard fine-tuning** — move, rotate, reset offset, switch laser ↔ manual mode mid-placement
- 💾 **Persistent storage** — all objects saved to MySQL, auto-respawned on every resource start
- 📦 **Saved objects panel** — browse every placed object with ID, model name and coordinates
- 🛠️ **Per-object actions** — teleport, change model, toggle freeze, reposition via laser, edit coords manually, delete (with confirmation)
- 📡 **Live broadcast** — every change instantly syncs to all connected clients
- 🔒 **Dual permission check** — rsg-core group **and** ace permission `command.object`

---

## 📦 Dependencies

| Resource | Purpose |
|---|---|
| [`rsg-core`](https://github.com/Rexshack-RedM/rsg-core) | Framework — player data, callbacks, permissions |
| [`ox_lib`](https://github.com/overextended/ox_lib) | UI — context menus, input dialogs, notifications |
| [`oxmysql`](https://github.com/overextended/oxmysql) | Async MySQL wrapper for persistent storage |

---

## 🚀 Installation

**1.** Drop the `ws-objectspawner` folder into your `resources/` directory.

**2.** Import the database schema:
```sql
SOURCE install.sql;
```

**3.** Add to your `server.cfg` **after** all three dependencies:
```
ensure rsg-core
ensure ox_lib
ensure oxmysql
ensure ws-objectspawner
```

> ⚠️ Load order matters — this resource must start **after** `rsg-core`, `ox_lib`, and `oxmysql`.

---

## ⚙️ Configuration (`config.lua`)

```lua
Config = {}

Config.Command       = 'object'   -- Chat command to open the menu
Config.AdminGroup    = 'admin'    -- rsg-core permission group required
Config.LaserDistance = 50.0       -- Max raycast distance in metres
Config.RenderDistance= 150.0      -- Render distance for saved objects
Config.MoveStep      = 0.05       -- X/Y/Z fine-adjust step (metres)
Config.RotateStep    = 2.5        -- Heading fine-adjust step (degrees)
```

| Key | Default | Description |
|---|---|---|
| `Config.Command` | `'object'` | Command that opens the spawner menu |
| `Config.AdminGroup` | `'admin'` | rsg-core group required to use the tool |
| `Config.LaserDistance` | `50.0` | Max raycast range in metres |
| `Config.RenderDistance` | `150.0` | Intended render distance *(currently rendered globally)* |
| `Config.MoveStep` | `0.05` | Keyboard fine-adjust step size (metres) |
| `Config.RotateStep` | `2.5` | Q/E rotation step size (degrees) |

---

## 🔐 Permissions

Access is granted when **either** condition is met:

- ✅ Player's rsg-core group matches `Config.AdminGroup` (default: `admin`)
- ✅ Player has ace permission `command.object`

To grant ace permission in `server.cfg`:
```
add_ace identifier.license:XXXXXXXX command.object allow
```

---

## 🕹️ Placement Controls

| Key | Action |
|---|---|
| `LMB` / `Enter` | ✅ Confirm placement |
| `RMB` / `Backspace` | ❌ Cancel placement |
| `Space` | 🔀 Toggle laser raycast ↔ manual mode |
| `↑ / ↓` Arrow | Move on **Y** axis |
| `← / →` Arrow | Move on **X** axis |
| `Page Up / Page Down` | Move on **Z** axis (height) |
| `Q` | 🔄 Rotate heading clockwise |
| `E` | 🔄 Rotate heading counter-clockwise |
| `R` | ↩️ Reset manual offset to zero |

---

## 🗄️ Database Schema

```sql
CREATE TABLE IF NOT EXISTS `objectspawner_objects` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `model`      VARCHAR(100) NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `heading`    FLOAT        NOT NULL DEFAULT 0,
    `frozen`     TINYINT(1)   NOT NULL DEFAULT 1,
    `created_by` VARCHAR(60)  DEFAULT NULL,   -- citizenid of the placing admin
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 📡 Events & Callbacks Reference

| Name | Side | Type | Description |
|---|---|---|---|
| `rsg-objectspawner:server:getObjects` | Server | Callback | Returns all saved objects from the DB |
| `rsg-objectspawner:server:saveObject` | Server | Callback | Inserts a new object, returns its ID |
| `rsg-objectspawner:server:updateObject` | Server | Net Event | Updates model, coords, heading, frozen |
| `rsg-objectspawner:server:deleteObject` | Server | Net Event | Deletes an object by ID |
| `rsg-objectspawner:client:refresh` | Client | Net Event | Re-fetches and re-spawns all saved objects |

---

## 📁 File Structure

```
ws-objectspawner/
├── 📁 client/
│   └── main.lua          # UI menus, placement loop, object rendering
├── 📁 server/
│   └── main.lua          # Callbacks, DB operations, permission checks
├── 📁 screenshots/
│   ├── menu-main.png
│   ├── menu-new-object.png
│   └── menu-saved.png
├── config.lua            # All configurable values
├── fxmanifest.lua        # Resource manifest
├── install.sql           # Database table definition
└── README.md
```

---

## 📝 Notes

- Models must be valid **RDR3 object hashes**. The script validates via `IsModelInCdimage` before spawning — admins are notified if a model is invalid.
- `created_by` stores the player's `citizenid` for audit tracking.
- Objects are currently rendered **globally** on all clients regardless of `Config.RenderDistance`.

---

<div align="center">

Made with ❤️ by **wsscripts**

</div>
