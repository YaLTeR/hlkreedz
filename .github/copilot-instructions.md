# HL KreedZ AI Coding Instructions

## Project Overview

### Purpose
HL KreedZ is an AMX Mod X plugin suite that implements a **time-trial game mode** for Half-Life's Adrenaline Gamer (AG) mod. The core purpose is to track and rank how quickly players complete jump maps, leveraging Half-Life's movement mechanics for speedrunning-style gameplay.

**Core Features:**
- **Timer System**: Measures time from start button/zone to end button/zone (precise to microseconds)
- **Records Tracking**: World Records (WR) and Personal Bests (PB) per map, per player
- **Leaderboards**: Rankings for different types of runs (pure, pro, noob, no-reset)
- **Run Stats**: Tracks different metrics for the run (max/avg/end speed, jump/ducktap/slowdown count, 2D/3D distance, sync, speedgain, etc.)
- **1v1 Tournaments**: Competitive match system with map pool management, ABBA ban + BA pick format
- **Discord Integration**: Announces new WRs to Discord webhooks

### Movement Mechanics
Players gain speed advantage through advanced Half-Life physics techniques:
- **Bunny-hopping (BH)**: Jumping while air-strafing to maintain momentum
- **Wall-strafing (WS)**: Angling movement against walls to gain speed
- **Ground-strafing (GS)**: Fast ground movement using strafe mechanics
- **Slope Boosts**: Using gravity on inclines for acceleration
- **Ducktaps/Duckrolling**: Quick duck+unduck sequences to maintain speed during obstacles
- **Double-ducking (DD)**: Advanced momentum preservation technique

### Technology Stack
**Key Versions:**
- Main branch: AMX Mod X 1.8.3 (strict - not backwards compatible)
- Unstable branch: AMX Mod X 1.10.0 build 5390
- Language: PAWN (AMX Mod X scripting language)
- Storage: MySQL database for persistent records, INI files for configuration

## Architecture

### Plugin Ecosystem
The codebase is split into modular plugins, each compiled separately to `.amxx` files:

- **hl_kreedz.sma** (11,659 lines): Core timer, checkpoints, start/stop buttons, leaderboards, spectating
- **hl_kreedz_competitions.sma**: Tournament system with ABBA bans + BA picks format
- **hl_kreedz_discord.sma**: Discord webhook integration for world records
- **q_jumpstats.sma**: Jump statistics tracking (LJ stats, sync, distance, height)
- **q_menu.sma**: Menu system framework (extensible menu API used by multiple plugins)
- **q_cookies.sma**: Per-player data persistence
- **q_message.sma**: Message rendering framework
- **q.sma**: Base library with logging, cvars, utilities
- **searchmaps.sma**: Map search and listing
- **mpbhop.sma**: Movement block handling (mp_* trigger blocks)
- **cbm.sma**: Custom button maker
- **amx_settings_api.sma**: INI file-based settings (key-value, cross-plugin)

### Data Flow
1. **Input**: Player actions trigger game engine events → hooked by plugins
2. **Processing**: State tracking via per-player arrays, entity data, tries, timers
3. **Storage**: INI configs (`configs/hl_kreedz/`) + MySQL database (`hlkz.schema.sql`)
4. **Output**: HUD messages, chat, Discord webhooks, in-game menus

### Cross-Plugin Communication
- **Natives** (plugin exports): Declared in `plugin_natives()`, core examples: `HLKZ_GetRunMode()`, `HLKZ_IsMatchRunning()`, `HLKZ_SaveRecordedRun()`
- **Forwards** (event callbacks): Declared in `register_forward()`, used for cooperative logic
- **Includes**: Custom headers in `scripting/include/` (e.g., `hlkz.inc`, `q_menu.inc`, `q_jumpstats.inc`)
- **Settings API**: `amx_settings_api` reads/writes per-player or global INI files for cross-plugin state

### Plugin Communication Flow
```
Game Engine Events (player join, movement, button press)
    ↓
hl_kreedz.sma (core plugin)
    ├─ HLKZ_GetRunMode() → q_jumpstats.sma
    ├─ HLKZ_SaveRecordedRun() ↔ Database (MySQL)
    ├─ HLKZ_ShowMessage() → hl_kreedz_discord.sma (webhook)
    └─ q_menu_display() → q_menu.sma (menu rendering)
    
q_jumpstats.sma (jump stats tracking)
    ├─ Reads: player velocity, ground state
    ├─ Saves via: q_cookies.sma (player preferences)
    └─ Displays via: q_menu.sma + q_message.sma (HUD/chat)

hl_kreedz_competitions.sma (tournament system)
    ├─ Queries: HLKZ_IsMatchRunning() from hl_kreedz
    ├─ Manages: map pool via INI (amx_settings_api)
    └─ Signals: match events to hl_kreedz via forwards

Cross-cutting Data Layer:
    ├─ amx_settings_api.sma (INI file persistence)
    ├─ q_cookies.sma (per-player data via native)
    └─ hlkz.schema.sql (MySQL tables for records, stats, tournaments)
```

### Data Flow Example: Player Finishes Run
```
1. Player touches end button (trigger_multiple)
2. hl_kreedz.sma hooks: trigger_touch() event
3. Validates run via HLKZ_SaveRecordedRun()
4. If new WR:
   - HLKZ_ShowMessage() broadcasts to chat
   - hl_kreedz_discord.sma receives, sends Discord webhook
   - Database updated via MySQL insert
   - q_jumpstats.sma records jump stats via q_cookies
5. Update leaderboard display to all players via HUD
```

### Game Engine Hooks & Event Handling
The plugin hooks into Half-Life's game engine through multiple mechanisms:

**RegisterHam (Ham Sandwich)** - Hooks entity-specific game events:
```pawn
// Hook button press events
RegisterHam(Ham_Use, "func_button", "Fw_HamUseButtonPre", 0);

// Handler checks if it's a start/stop button and sets player state
public Fw_HamUseButtonPre(button, id) {
    // Determine button type (start/end)
    // Update player variables: g_baIsClimbing, g_PlayerTime, etc.
    // Start/stop timer, validate run conditions
}
```

**register_forward** - Hooks global game events:
```pawn
// Subscribe to player spawn, touch, think, etc.
register_forward(FM_PlayerPreThink, "Fw_PlayerPreThink");
register_forward(FM_Touch, "Fw_Touch");
```

**register_clcmd** - Hooks console commands:
```pawn
// Listen for specific console commands
register_clcmd("spectate", "CmdSpectateHandler");
register_clcmd("jointeam", "CmdJoinTeam");
```

**CmdSayHandler** - Central handler for chat commands:
```pawn
// Handles all player chat starting with "/"
register_clcmd("say", "CmdSayHandler");

public CmdSayHandler(id) {
    static args[64];
    read_args(args, charsmax(args));
    remove_quotes(args);
	  trim(args);
    
    if (args[0] != '/' && args[0] != '.' && args[0] != '!')
        return PLUGIN_CONTINUE;

    if (equali(args[1], "cp")) { /* Make a checkpoint */ }
    else if (equali(args[1], "tp")) { /* Teleport to checkpoint */
    ...
}
```

**Primary Code Flow Entry Points:**
1. **Button Press** → `RegisterHam(Ham_Use)` → `Fw_HamUseButtonPre()` → Start/finish timer logic
2. **Player Movement** → `register_forward(FM_PlayerPreThink)` → Track velocity, detect cheats, update HUD
3. **Chat Commands** → `register_clcmd("say")` → `CmdSayHandler()` → Route to feature handlers
4. **Console Commands** → `register_clcmd()` → Direct handler functions

## Code Patterns & Conventions

### Plugin Initialization
```pawn
// Required order
#pragma semicolon 1           // Enforce semicolons
#pragma ctrlchar '\'          // Backslash for escape (NOT standard ^)
#include <amxmodx>
// Other includes (amxmisc, fakemeta, etc.)
public plugin_natives() {
    register_library("libname");
    register_native("NativeName", "native_impl_function");
}
public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_cvar(...); // CVars with callback hooks
    // Init module-specific state
}
public plugin_end() {
    // Cleanup: ArrayDestroy(), TrieDestroy(), remove timers
}
```

### Player State Tracking
Per-player data uses bit arrays or indexed arrays [33] (hardcoded max players):
```pawn
new g_bit_is_connected;  // Bitfield
#define IsConnected(%1) (get_bit(g_bit_is_connected,%1))
new g_PlayerData[33][PlayerDataStruct];  // Indexed
```

### Timers & Tasks
- **Tasks** (repeating): `set_task(delay, "function", taskid)` with unique task IDs (e.g., `TASKID_CUP_CHANGE_MAP`)
- **One-time timers**: `set_task(delay, "function", _, _, _, "a")` (abort flag)
- **Cleanup**: Remove in `plugin_end()` or when no longer needed

### HUD Rendering
- **Sync handles** created per-channel: `g_SyncHud = CreateHudSyncObj()`
- **AG clients** (Adrenaline Gamer mod) use special AG messages; fallback to HUD for vanilla
- **HUD positions**: Stored as floats (0.5 = center, negative = pixel offset from bottom-right)

### CVars & Configuration
- Define with `register_cvar(name, default_value, flags)`
- Hook changes: `hook_cvar_change(pcvar, "CallbackFunction")`
- Read: `get_cvar_float()`, `get_cvar_string()`, etc.
- Config INI files use `configs/hl_kreedz/` subdirectory

### Control Characters & Strings
**Critical**: `#pragma ctrlchar '\'` replaces `^` as escape character:
- Use `\n` for newlines, `\t` for tabs
- String include `string_stocks` BEFORE setting ctrlchar (due to `remove_filepath()` bug)

### Bitfield Operations (Player State)
```pawn
#define get_bit(%1,%2) (%1 & (1 << (%2 - 1)))
#define set_bit(%1,%2) (%1 |= (1 << (%2 - 1)))
#define clr_bit(%1,%2) (%1 &= ~(1 << (%2 - 1)))

// Usage
new g_PlayerRunning;  // Bitfield tracking running players
set_bit(g_PlayerRunning, id);          // Player started run
if (get_bit(g_PlayerRunning, id)) { }  // Check if running
clr_bit(g_PlayerRunning, id);          // Player stopped
```

### HUD Message with AG Fallback
```pawn
// Display message respecting AG vs vanilla clients
public HLKZ_ShowMessage(id, const message[]) {
    if (g_IsAgServer && g_IsAgClient) {
        // Send AG-specific message (e.g., AG_PrintScreen, AG_PrintChat)
        // Implementation plugin-specific
    } else {
        // Fallback: HUD sync message
        new hud[256];
        formatex(hud, charsmax(hud), "%s", message);
        ShowSyncHudMsg(id, g_SyncHud, "%s", hud);
    }
}
```

### Settings API Usage (Cross-Plugin Persistence)
```pawn
#include <amx_settings_api>

static authid[32], idNumbers[24];
get_user_authid(id, authid, charsmax(authid));
ConvertSteamID32ToNumbers(authid, idNumbers);

// Save player setting
amx_save_setting_int("hl_kreedz/player_prefs.ini", idNumbers, "player_setting", preference_value);

// Load player setting
new loaded_value;
amx_load_setting_int("hl_kreedz/player_prefs.ini", idNumbers, "player_setting", loaded_value);
```

## Important Dependencies

### External Libraries & Modules
- **curl**: Required for Discord webhook (`hl_kreedz_discord.sma`); enable in `configs/modules.ini`
- **mysqlt**: SQL support for leaderboards and statistics
- **fakemeta**: Entity manipulation
- **hamsandwich**: Engine hook API
- **hl/hlkz**: Half-Life / KreedZ specific constants and functions

### Database
- Schema in `sql/hlkz.schema.sql` (MySQL 8.0, large multi-table structure)
- Uses views for map statistics (`DataForMedalsView`, `SeasonMapPool`)
- Table prefix: global records, player stats, match data, tournament data

## Workflow & Key Commands

### Building
**Manual compilation required** (no Makefile provided):
- Use AMX Mod X compiler targeting PAWN with includes from `scripting/include/`
- Compiled output: `.amxx` files copied to `plugins/`
- SourceRuns compiles these via server-side AMXXPC or external build tool

### Testing
- Run on HL server with `sv_ag_gamemode kreedz` (enforced in `plugin_init()`)
- Verify AG version via `sv_ag_version` cvar to enable AG-specific features
- Check `server.log` for debug output (enable with `#define _DEBUG` in plugins)

### Configuration
- All runtime settings: `configs/hl_kreedz/*.ini` or `configs/*.cfg`
- Language strings: `data/lang/q_*.txt` (key=value format)
- Map pool: Auto-loaded from config or built in-game via admin menu

## Common Tasks

### Adding a New Feature to hl_kreedz
1. Define state struct in enum section (line ~140-210)
2. Initialize in `plugin_init()` (line ~731+)
3. Register command: `register_clcmd("say /command", "cmd_handler")`
4. Implement handler with player state checks
5. Cleanup in `plugin_end()` (line ~1244)
6. Export as native if needed by other plugins
7. Update docs in README.md and TODO.md

### Extending Jump Stats
- Modify `q_jumpstats.sma` state machine (`State_*` enum)
- Save data via `q_cookies` API
- Display in menu using `q_menu` framework
- Ensure compatibility with leaderboard views in `hlkz.schema.sql`

### Creating Admin Commands
- Use `register_clcmd()` with appropriate flags (`ADMIN_RCON`, etc.)
- Verify admin level: `get_user_flags(id) & ADMIN_LEVEL`
- Send feedback via chat or HUD using `HLKZ_ShowMessage()` native
- Log actions to server console with `server_print()`

## Project-Specific Conventions

1. **Naming**: snake_case for functions/variables; UPPER_CASE for constants
2. **Comments**: Explain "why", not "what"; reference forum/GitHub issues when applicable
3. **Error Handling**: Silent failures for non-critical systems; log errors with `[PLUGIN_TAG]` prefix
4. **Memory**: Use `Trie` for O(1) lookups (map names, player IDs); `Array` for dynamic lists
5. **Backwards Compatibility**: AG servers may run vanilla HL clients; always provide HUD fallback
6. **SQL Safety**: Use parameterized queries where available; sanitize player names in `hlkz_utils.inc` if present
7. **Performance**: HUD updates at 0.05s (`HUD_UPDATE_TIME`); defer heavy tasks to timers

## Troubleshooting

- **"cannot read from file"**: Check `configs/modules.ini` has required modules enabled (curl, sqlx, etc.)
- **Plugin doesn't load**: Verify AMX Mod X version matches (1.8.3 for main branch)
- **HUD flickering**: Use `CreateHudSyncObj()` and ensure single `ShowSyncHudMsg()` call per frame
- **Menu not responding**: Check menu callback registration and forward binding in `plugin_natives()`
- **SQL errors**: Verify database credentials in `configs/` and that schema is imported

## References

- [AMX Mod X Documentation](https://www.amxmodx.org/)
- Source files with extensive comments: `hl_kreedz.sma` lines 1-100 (credits, pragma setup)
