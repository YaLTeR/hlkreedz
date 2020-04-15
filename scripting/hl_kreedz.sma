/* AMX Mod X
*	HL KreedZ
*
* http://aghl.ru/forum/ - Russian Half-Life and Adrenaline Gamer Community
*
* This file is provided as is (no warranties)
*
* Credit to Quaker for the snippet of setting light style (nightvision) https://github.com/skyrim/qmxx/blob/master/scripting/q_nightvision.sma
*/

#pragma semicolon 1
#pragma ctrlchar '\'

#include <amxmodx>
#include <amxmisc>
#include <celltrie>
#include <engine>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <hl>
#include <hl_kreedz_util>
#include <mysqlt>

// Compilation options
//#define _DEBUG		// Enable debug output at server console.

#define MAX_PLAYERS 32
#define MAX_FPS_MULTIPLIER 4 // for replaying demos at a max. fps of 250*MAX_FPS_MULTIPLIER

#define OBS_NONE			0
#define OBS_CHASE_LOCKED	1
#define OBS_CHASE_FREE		2
#define OBS_ROAMING			3
#define OBS_IN_EYE			4
#define OBS_MAP_FREE		5
#define OBS_MAP_CHASE		6

#define get_bit(%1,%2) (%1 & (1 << (%2 - 1)))
#define set_bit(%1,%2) (%1 |= (1 << (%2 - 1)))
#define clr_bit(%1,%2) (%1 &= ~(1 << (%2 - 1)))

#define IsPlayer(%1) (1 <= %1 <= g_MaxPlayers)
#define IsConnected(%1) (get_bit(g_bit_is_connected,%1))
#define IsAlive(%1) (get_bit(g_bit_is_alive,%1))
#define IsHltv(%1) (get_bit(g_bit_is_hltv,%1))
#define IsBot(%1) (get_bit(g_bit_is_bot,%1))

#define FL_ONGROUND_ALL (FL_ONGROUND | FL_PARTIALGROUND | FL_INWATER | FL_CONVEYOR | FL_FLOAT)

#define MAP_IDLE 0
#define MAP_BANNED 1
#define MAP_PICKED 2
#define MAP_PLAYED 3
#define MAP_DECIDER 4

#define MIN_DISTANCE_RESPAWN_ADVANTAGE 1300.0

#define TASKID_ICON						5633445
#define TASKID_WELCOME					43321
#define TASKID_KICK_REPLAYBOT			9572626
#define TASKID_CAM_UNFREEZE				1622952
#define TASKID_CONFIGURE_DB				2037262

#define TASKID_CUP_TENSION_FIRST_BAN	9357015
#define TASKID_CUP_FINALLY_FIRST_BAN	8357015
#define TASKID_CUP_FORCE_SPECTATORS		7357015
#define TASKID_CUP_START_MATCH			6357015
#define TASKID_CUP_CHANGE_MAP			5357015

// HL1 campaign
// TODO: Refactor this if possible to make it generic
#define REQ_AM_BTN_SUIT				(1<<0)
#define REQ_AM_TAKE_SUIT			(1<<1)

//#define REQ_UC1_PASS_CHECK1		(1<<0)
#define REQ_UC1_TAKE_CROWBAR		(1<<0)
#define REQ_UC1_TAKE_GLOCK			(1<<1)

#define REQ_UC2_BTN_WATER			(1<<0)
#define REQ_UC2_BTN_LIFT			(1<<1)

#define REQ_OCWGH_BTN_ELECTRICITY	(1<<0)
#define REQ_OCWGH_TAKE_NADES		(1<<1)
#define REQ_OCWGH_BTN_SILO_DOOR		(1<<2)

#define REQ_BP1_LIFT_DOOR			(1<<0)
#define REQ_BP1_TAKE_HEALTH			(1<<1)
#define REQ_BP1_TAKE_BATTERIES		(1<<2)
#define REQ_BP1_LIFT				(1<<3)

//#define REQ_BP2_BTN_BUCKET		(1<<0)
#define REQ_BP2_BTN_ELECTRO2		(1<<0)
#define REQ_BP2_BTN_ELECTRO1		(1<<1)

#define TE_EXPLOSION 				3

enum _:REPLAY
{
  //RP_VERSION,
	Float:RP_TIME,
	Float:RP_ORIGIN[3],
	Float:RP_ANGLES[3],
	RP_BUTTONS
}

enum _:CP_TYPES
{
	CP_TYPE_SPEC,
	CP_TYPE_CURRENT,
	CP_TYPE_OLD,
	CP_TYPE_PRACTICE, // Practice checkpoints (with speed / midair)
	CP_TYPE_PRACTICE_OLD,
	CP_TYPE_CUSTOM_START, // kz_set_custom_start position.
	CP_TYPE_START,        // Start button.
	CP_TYPE_DEFAULT_START // Standard spawn
}

enum _:CP_DATA
{
	bool:CP_VALID,			// is checkpoint valid
	CP_FLAGS,				// pev flags
	Float:CP_ORIGIN[3],		// position
	Float:CP_ANGLES[3],		// view angles
	Float:CP_VIEWOFS[3],	// view offset
	Float:CP_VELOCITY[3],	// velocity
	Float:CP_HEALTH,		// health
	Float:CP_ARMOR,			// armor
	bool:CP_LONGJUMP,		// longjump
}

enum _:COUNTERS
{
	COUNTER_CP,
	COUNTER_TP,
	COUNTER_SP,
	COUNTER_PRACTICE_CP,
	COUNTER_PRACTICE_TP
}

enum BUTTON_TYPE
{
	BUTTON_START,
	BUTTON_FINISH,
	BUTTON_NOT,
}

enum _:WEAPON
{
	WEAPON_CLASSNAME[32],
	Float:WEAPON_ORIGIN[3]
}

new const PLUGIN[] = "HL KreedZ Beta";
new const PLUGIN_TAG[] = "HLKZ";
new const VERSION[] = "0.38";
new const DEMO_VERSION = 36; // Should not be decreased. This is for replays, to know which version they're in, in case the stored binary data (or format) changes
new const AUTHOR[] = "KORD_12.7 & Lev & YaLTeR & naz";

new const MAIN_MENU_ID[] = "HL KreedZ Menu";
new const TELE_MENU_ID[] = "HL KreedZ Teleport Menu";
new const MAP_BAN_MENU_ID[] = "Ban a map";
new const MAP_PICK_MENU_ID[] = "Pick a map";

new const CONFIGS_SUB_DIR[] = "/hl_kreedz";
new const PLUGIN_CFG_FILENAME[] = "hl_kreedz.cfg";
new const PLUGIN_CFG_SHORTENED[] = "hlkz";
new const MYSQL_LOG_FILENAME[] = "kz_mysql.log";
new const MAP_POOL_FILE[] = "map_pool.ini";
new const CUP_FILE[] = "cup.ini";

new const FIREWORK_SOUND[] = "firework.wav";

//new const staleStatTime = 30 * 24 * 60 * 60;	// Keep old stat for this amount of time
//new const keepStatPlayers = 100;				// Keep this amount of players in stat even if stale

new const g_MapStateString[][] =
{
	"",
	"banned",
	"picked",
	"played",
	"decider"
};

new const g_szStarts[][] =
{
	"hlkz_start", "counter_start", "clockstartbutton", "firsttimerelay", "but_start", "counter_start_button",
	"multi_start", "timer_startbutton", "start_timer_emi", "gogogo",

	// For the HL1 campaign maps
	// TODO: Refactor this not to be hardcoded here
	"am_start", "uc1_start", "uc2_start", "ocwgh_start", "bp1_start", "bp2_start"
};

new const g_szStops[][] =
{
	"hlkz_finish", "counter_off", "clockstopbutton", "clockstop", "but_stop", "counter_stop_button",
	"multi_stop", "stop_counter", "m_counter_end_emi",

	// For the HL1 campaign maps
	// TODO: Refactor this not to be hardcoded here
	"am_end", "uc1_end", "uc2_end", "ocwgh_end", "bp1_end", "bp2_end"
};

new const g_ItemNames[][] =
{
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_buckshot",
	"ammo_crossbow",
	"ammo_gaussclip",
	"ammo_rpgclip",
	"item_battery",
	"item_healthkit",
	"item_longjump"
};

new const g_WeaponNames[][] =
{
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_crowbar",
	"weapon_egon",
	"weapon_gauss",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine"
};

new const g_BoostWeapons[][] = {
	"weapon_9mmAR",
	"weapon_crossbow",
	"weapon_egon",
	"weapon_gauss",
	"weapon_handgrenade",
	"weapon_hornetgun", // no boost, but it could be used to block a moving entity (door, lift, etc.) 
	"weapon_rpg",
	"weapon_satchel",
	"weapon_snark",
	"weapon_tripmine"
};

// Entities thay may be still alive without the owner being online
// and affect another player in a way they can take advantage for a run
new const g_DamageBoostEntities[][] = {
	"bolt",					// DMG_BLAST
	"grenade",				// DMG_BLAST
	"hornet",				// DMG_BULLET
	"monster_satchel",		// DMG_BLAST
	"monster_snark",		// DMG_SLASH
	"monster_tripmine",		// DMG_BLAST
	"rpg_rocket"			// DMG_BLAST
};

new g_bit_is_connected, g_bit_is_alive, g_bit_invis, g_bit_waterinvis;
new g_bit_is_hltv, g_bit_is_bot;
new g_baIsClimbing, g_baIsPaused, g_baIsFirstSpawn, g_baIsPureRunning;

new Float:g_PlayerTime[MAX_PLAYERS + 1];
new Float:g_PlayerTimePause[MAX_PLAYERS + 1];
new g_ShowTimer[MAX_PLAYERS + 1];
new g_ShowKeys[MAX_PLAYERS + 1];
new g_SolidState[MAX_PLAYERS + 1];
new g_LastButtons[MAX_PLAYERS + 1];
new g_LastSentButtons[MAX_PLAYERS + 1];
new Float:g_LastPressedJump[MAX_PLAYERS + 1];
new Float:g_LastPressedDuck[MAX_PLAYERS + 1];
new g_LastMode[MAX_PLAYERS + 1];
new g_LastTarget[MAX_PLAYERS + 1];
new g_TeleMenuPosition[MAX_PLAYERS + 1];
new g_TeleMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS];
new g_TeleMenuPlayersNum[MAX_PLAYERS + 1];
new g_TeleMenuOption[MAX_PLAYERS + 1];
new g_KzMenuOption[MAX_PLAYERS + 1];
new g_CheatCommandsGuard[MAX_PLAYERS + 1];
new g_ShowStartMsg[MAX_PLAYERS + 1];
new g_TimeDecimals[MAX_PLAYERS + 1];
new g_Nightvision[MAX_PLAYERS + 1];
new g_Slopefix[MAX_PLAYERS + 1];
new Float:g_Speedcap[MAX_PLAYERS + 1];
new g_ShowSpeed[MAX_PLAYERS + 1];
new g_ShowSpecList[MAX_PLAYERS + 1];
new Float:g_PlayerTASed[MAX_PLAYERS + 1];

new g_BotOwner[MAX_PLAYERS + 1];
new g_BotEntity[MAX_PLAYERS + 1];
new g_RecordRun[MAX_PLAYERS + 1];
// Each player has all the frames of their run stored here, the frames are arrays containing the info formatted like the REPLAY enum
new Array:g_RunFrames[MAX_PLAYERS + 1]; // frames of the current run, being stored here while the run is going on
new Array:g_ReplayFrames[MAX_PLAYERS + 1]; // frames to be replayed
new g_ReplayFramesIdx[MAX_PLAYERS + 1]; // How many frames have been replayed
new bool:g_Unfreeze[MAX_PLAYERS + 1];
new g_ReplayNum; // How many replays are running
new Float:g_ReplayStartGameTime[MAX_PLAYERS + 1]; // gametime() of the first frame of the demo
//new bool:g_isCustomFpsReplay[MAX_PLAYERS + 1]; // to know if the current run is a replay with modified FPS, so if there's a replay running when changing the FPS multiplier, that replay's FPS is not changed
new g_ConsolePrintNextFrames[MAX_PLAYERS + 1];
new g_ReplayFpsMultiplier[MAX_PLAYERS + 1]; // atm not gonna implement custom fps replays, just ability to multiply demo fps by an integer up to 4
//new Float:g_ArtificialFrames[MAX_PLAYERS + 1][MAX_FPS_MULTIPLIER]; // when will the calculated extra frames happen
new Float:g_LastFrameTime[MAX_PLAYERS + 1];

new g_FrameTime[MAX_PLAYERS + 1][2];
new Float:g_FrameTimeInMsec[MAX_PLAYERS + 1];

new g_ControlPoints[MAX_PLAYERS + 1][CP_TYPES][CP_DATA];
new g_CpCounters[MAX_PLAYERS + 1][COUNTERS];
new g_RunType[MAX_PLAYERS + 1][9];
new Float:g_Velocity[MAX_PLAYERS + 1][3];
new Float:g_Origin[MAX_PLAYERS + 1][3];
new Float:g_Angles[MAX_PLAYERS + 1][3];
new Float:g_ViewOfs[MAX_PLAYERS + 1][3];
new g_Impulses[MAX_PLAYERS + 1];
new g_Buttons[MAX_PLAYERS + 1];
new bool:g_bIsSurfing[MAX_PLAYERS + 1];
new bool:g_bWasSurfing[MAX_PLAYERS + 1];
new bool:g_bIsSurfingWithFeet[MAX_PLAYERS + 1];
new bool:g_hasSurfbugged[MAX_PLAYERS + 1];
new bool:g_hasSlopebugged[MAX_PLAYERS + 1];
new bool:g_StoppedSlidingRamp[MAX_PLAYERS + 1];
new g_RampFrameCounter[MAX_PLAYERS + 1];
new g_HBFrameCounter[MAX_PLAYERS + 1]; // frame counter for healthbooster trigger_multiple

new g_MapWeapons[256][WEAPON]; // weapons that are in the map, with their origin and angles

new g_HudRGB[3];
new g_SyncHudTimer;
new g_SyncHudMessage;
new g_SyncHudKeys;
new g_SyncHudHealth;
new g_SyncHudShowStartMsg;
new g_SyncHudSpeedometer;
new g_SyncHudSpecList;
new g_SyncHudCupMaps;

new g_MaxPlayers;
new g_PauseSprite;
new g_TaskEnt;

new g_Firework;
new Float:g_PrevButtonOrigin[3];

new g_MapId;
new g_Map[64];
new g_EscapedMap[128];
new g_ConfigsDir[256];
new g_ReplaysDir[256];
new g_StatsFile[RUN_TYPE][256];
new g_TopType[RUN_TYPE][32];
new Array:g_ArrayStats[RUN_TYPE];

new g_MapIniFile[256];
new g_MapDefaultStart[CP_DATA];
new g_MapPoolFile[256];
new g_CupFile[256];
new g_MapDefaultLightStyle[32];

new g_SpectatePreSpecMode;
new bool:g_InForcedRespawn;
new Float:g_LastHealth;
new bool:g_RestoreSolidStates;
new bool:g_bMatchRunning;
new bool:g_bCanTakeAdvantageOfRespawn;

new g_CupMatches; // how many maps will runners play to decide who qualifies
new g_CupPlayer1; // player index of opponent 1
new g_CupPlayer2; // player index of opponent 2
new g_CupSteam1[32]; // Steam id of opponent 1
new g_CupSteam2[32]; // Steam id of opponent 2
new g_CupScore1; // score of opponent 1, score meaning maps won
new g_CupScore2; // score of opponent 2
new bool:g_CupReady1; // whether opponent 1 is ready or not
new bool:g_CupReady2; // whether opponent 2 is ready or not
new Trie:g_CupMapPool; // mapName->mapState (MAP_BANNED, MAP_PICKED, etc.)
new g_PrevChooser; // index of the last player who banned/picked a map
new g_FirstBanner; // index of the first player who banned a map

new bool:g_isAnyBoostWeaponInMap;

// HL1 campaign stuff
new bool:g_isHL1Campaign;
new g_PlayerEndReqs[MAX_PLAYERS + 1]; // conditions that have to be met to be allowed to end the timer, like pressing a button in the way, etc.
new Trie:g_MapEndReqs;
new Trie:g_UnorderedReqsMaps;
new g_MapEndTotalReq;

new pcvar_allow_spectators;
new pcvar_kz_uniqueid;
new pcvar_kz_messages;
new pcvar_kz_hud_rgb;
new pcvar_kz_checkpoints;
new pcvar_kz_stuck;
new pcvar_kz_semiclip;
new pcvar_kz_pause;
new pcvar_kz_nodamage;
new pcvar_kz_show_timer;
new pcvar_kz_show_keys;
new pcvar_kz_show_start_msg;
new pcvar_kz_time_decimals;
new pcvar_kz_nokill;
new pcvar_kz_autoheal;
new pcvar_kz_autoheal_hp;
new pcvar_kz_spawn_mainmenu;
new pcvar_kz_nostat;
new pcvar_kz_top_records;
new pcvar_kz_top_records_max;
new pcvar_kz_pure_max_start_speed;
new pcvar_kz_pure_allow_healthboost;
new pcvar_kz_remove_func_friction;
new pcvar_kz_nightvision;
new pcvar_kz_slopefix;
new pcvar_kz_speedcap;
new pcvar_kz_speclist;
new pcvar_kz_speclist_admin_invis;
new pcvar_kz_autorecord;
new pcvar_kz_max_concurrent_replays;
new pcvar_kz_max_replay_duration;
new pcvar_kz_replay_setup_time;
new pcvar_kz_spec_unfreeze;
new pcvar_kz_denied_sound;
new pcvar_sv_items_respawn_time;
new pcvar_kz_mysql;
new pcvar_kz_mysql_threads;
new pcvar_kz_mysql_thread_fps;
new pcvar_kz_mysql_collect_time_ms;
new pcvar_kz_mysql_host;
new pcvar_kz_mysql_user;
new pcvar_kz_mysql_pass;
new pcvar_kz_mysql_db;
new pcvar_kz_cup_max_maps;
new pcvar_kz_cup_map_change_delay;
new pcvar_kz_stop_moving_platforms;

new Handle:g_DbHost;
new Handle:g_DbConnection;

new g_FwLightStyle;

new pcvar_sv_ag_match_running;

new mfwd_hlkz_cheating;
new mfwd_hlkz_worldrecord;

public plugin_precache()
{
	g_FwLightStyle = register_forward(FM_LightStyle, "Fw_FmLightStyle");
	g_PauseSprite = precache_model("sprites/pause_icon.spr");
	precache_model("models/player/robo/robo.mdl");
	precache_model("models/player/gordon/gordon.mdl");
	precache_model("models/p_shotgun.mdl");
	g_Firework = precache_model("sprites/firework.spr");
	precache_sound(FIREWORK_SOUND);
	//precache_model("models/boxy.mdl");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar("hlkreedz_version", VERSION, FCVAR_SPONLY | FCVAR_SERVER | FCVAR_UNLOGGED);

	new ag_gamemode[32];
	get_cvar_string("sv_ag_gamemode", ag_gamemode, charsmax(ag_gamemode));
	if (ag_gamemode[0] && !equal(ag_gamemode, "kreedz"))
	{
		server_print("The hl_kreedz.amxx plugin can only be run in \"kreedz\" mode.");
		pause("ad");
		return;
	}

	pcvar_kz_uniqueid = register_cvar("kz_uniqueid", "3");	// 1 - name, 2 - ip, 3 - steamid
	pcvar_kz_spawn_mainmenu = register_cvar("kz_spawn_mainmenu", "1");
	pcvar_kz_messages = register_cvar("kz_messages", "2");	// 0 - none, 1 - chat, 2 - hud
	pcvar_kz_hud_rgb = register_cvar("kz_hud_rgb", "255 160 0");
	pcvar_kz_checkpoints = register_cvar("kz_checkpoints", "1");
	pcvar_kz_stuck = register_cvar("kz_stuck", "1");
	pcvar_kz_semiclip = register_cvar("kz_semiclip", "1");
	pcvar_kz_pause = register_cvar("kz_pause", "1");
	pcvar_kz_nodamage = register_cvar("kz_nodamage", "1");
	pcvar_kz_show_timer = register_cvar("kz_show_timer", "2");
	pcvar_kz_show_keys = register_cvar("kz_show_keys", "1");
	pcvar_kz_show_start_msg = register_cvar("kz_show_start_message", "1");
	pcvar_kz_time_decimals = register_cvar("kz_def_time_decimals", "3");
	pcvar_kz_nokill = register_cvar("kz_nokill", "0");
	pcvar_kz_autoheal = register_cvar("kz_autoheal", "0");
	pcvar_kz_autoheal_hp = register_cvar("kz_autoheal_hp", "50");
	pcvar_kz_nostat = register_cvar("kz_nostat", "0");		// Disable stats storing (use for tests or fun)
	pcvar_kz_top_records = register_cvar("kz_top_records", "15"); // show 15 records of a top
	pcvar_kz_top_records_max = register_cvar("kz_top_records_max", "25"); // show max. 25 records even if player requests 100

	// Maximum speed when starting the timer to be considered a pure run
	pcvar_kz_pure_max_start_speed = register_cvar("kz_pure_max_start_speed", "50");

	pcvar_kz_pure_allow_healthboost = register_cvar("kz_pure_allow_healthboost", "0");
	pcvar_kz_remove_func_friction = register_cvar("kz_remove_func_friction", "0");

	// 0 = disabled, 1 = all nightvision types allowed, 2 = only flashlight-like nightvision allowed, 3 = only map-global nightvision allowed
	pcvar_kz_nightvision = register_cvar("kz_def_nightvision", "0");

	// 0 - slopebug/surfbug fix disabled, 1 - fix enabled, may want to disable it when you consistently get stuck in little slopes while sliding+wallstrafing
	pcvar_kz_slopefix = register_cvar("kz_slopefix", "1");
	pcvar_kz_speedcap = register_cvar("kz_speedcap", "0"); // 0 means the player can set the speedcap at the horizontal speed they want
	pcvar_kz_speclist = register_cvar("kz_speclist", "1");
	pcvar_kz_speclist_admin_invis = register_cvar("kz_speclist_admin_invis", "0");

	pcvar_kz_autorecord = register_cvar("kz_autorecord", "1");
	pcvar_kz_max_concurrent_replays = register_cvar("kz_max_concurrent_replays", "5");
	pcvar_kz_max_replay_duration = register_cvar("kz_max_replay_duration", "1200"); // in seconds (default: 20 minutes)
	pcvar_kz_replay_setup_time = register_cvar("kz_replay_setup_time", "2"); // in seconds
	pcvar_kz_spec_unfreeze = register_cvar("kz_spec_unfreeze", "1"); // unfreeze spectator cam when watching a replaybot teleport

	pcvar_allow_spectators = get_cvar_pointer("allow_spectators");

	pcvar_sv_ag_match_running = get_cvar_pointer("sv_ag_match_running");

	pcvar_kz_denied_sound = register_cvar("kz_denied_sound", "1");

	pcvar_sv_items_respawn_time = register_cvar("sv_items_respawn_time", "0"); // 0 = unchanged, n > 0 = n seconds

	// 0 = store data in files and only store leaderboards, 1 = store data in MySQL and store much more data (not only leaderboards), 2 store data in both (files and mysql) and retrieve from file only if it fails to retrieve from DB
	pcvar_kz_mysql = register_cvar("kz_mysql", "0");
	// How many threads to use with MySQL, so it can use that many threads per frame to query stuff (1 query per thread?). This depends on the CPU you have in the server I guess
	pcvar_kz_mysql_threads = register_cvar("kz_mysql_threads", "1");
	pcvar_kz_mysql_thread_fps = register_cvar("kz_mysql_thread_fps", "25"); // MySQLT module only admits values between 4 and 33 fps
	pcvar_kz_mysql_collect_time_ms = register_cvar("kz_mysql_collect_time_ms", "75"); // MySQLT module only admits values between 30 and 300 ms
	pcvar_kz_mysql_host = register_cvar("kz_mysql_host", ""); // IP:port, FQDN:port, etc.
	pcvar_kz_mysql_user = register_cvar("kz_mysql_user", ""); // Name of the MySQL user that will be used to read/write data in the DB
	pcvar_kz_mysql_pass = register_cvar("kz_mysql_pass", ""); // Password of the MySQL user
	pcvar_kz_mysql_db = register_cvar("kz_mysql_db", ""); // MySQL database name

	pcvar_kz_cup_max_maps = register_cvar("kz_cup_max_maps", "7");
	pcvar_kz_cup_map_change_delay = register_cvar("kz_cup_map_change_delay", "8.0");

	pcvar_kz_stop_moving_platforms = register_cvar("kz_stop_moving_platforms", "0");

	register_dictionary("telemenu.txt");
	register_dictionary("common.txt");

	register_clcmd("kz_teleportmenu",	"CmdTPMenuHandler",		ADMIN_CFG, "- displays kz teleport menu");
	register_clcmd("kz_setstart",		"CmdSetStartHandler",	ADMIN_CFG, "- set start position");
	register_clcmd("kz_clearstart",		"CmdClearStartHandler",	ADMIN_CFG, "- clear start position");

	// Cup and map pool stuff
	register_clcmd("kz_cup",			"CmdCupHandler", 		ADMIN_CFG, "- start a cup match between 2 players");
	register_clcmd("kz_cup_reset_maps",	"CmdResetCupMapStates",	ADMIN_CFG, "- resets the state of all the maps in the pool");
	register_clcmd("kz_cup_clear",		"CmdClearCup",			ADMIN_CFG, "- clears all the cached cup data");
	register_clcmd("kz_map_add",		"CmdMapInsertHandler",	ADMIN_CFG, "- adds a map to the map pool");
	register_clcmd("kz_map_insert",		"CmdMapInsertHandler",	ADMIN_CFG, "- adds a map to the map pool");
	register_clcmd("kz_map_del",		"CmdMapDeleteHandler",	ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_delete",		"CmdMapDeleteHandler",	ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_remove",		"CmdMapDeleteHandler",	ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_state",		"CmdMapStateHandler",	ADMIN_CFG, "- modifies the state of a map in the pool");
	register_clcmd("kz_map_pool_show",	"CmdMapsShowHandler",	ADMIN_CFG, "- shows the maps and their states on the screen");
	register_clcmd("kz_map_pool_clear",	"CmdMapsClearHandler",	ADMIN_CFG, "- clears the map pool (leaves it empty)");

	register_clcmd("kz_set_custom_start",	"CmdSetCustomStartHandler",		-1, "- sets the custom start position");
	register_clcmd("kz_clear_custom_start",	"CmdClearCustomStartHandler",	-1, "- clears the custom start position");

	// TODO remove these below or make them admin-only to set the availability of these commands for client usage, clients will use say commands instead of console ones to set these variables
	register_clcmd("kz_start_message",	"CmdShowStartMsg",	-1, "<0|1> - toggles the message that appears when starting the timer");
	register_clcmd("kz_time_decimals",	"CmdTimeDecimals",	-1, "<1-6> - sets a number of decimals to be displayed for times (seconds)");
	register_clcmd("kz_nightvision",	"CmdNightvision",	-1, "<0-2> - sets nightvision mode. 0=off, 1=flashlight-like, 2=map-global");

	register_clcmd("say",		"CmdSayHandler");
	register_clcmd("say_team",	"CmdSayHandler");
	register_clcmd("spectate",	"CmdSpectateHandler");

	register_clcmd("+hook",					"CheatCmdHandler");
	register_clcmd("-hook",					"CheatCmdHandler");
	register_clcmd("+rope",					"CheatCmdHandler");
	register_clcmd("-rope",					"CheatCmdHandler");
	register_clcmd("+tas_perfectstrafe",	"TASCmdHandler");
	register_clcmd("-tas_perfectstrafe",	"TASCmdHandler");
	register_clcmd("+tas_autostrafe",		"TASCmdHandler");
	register_clcmd("-tas_autostrafe",		"TASCmdHandler");

	register_menucmd(register_menuid(MAIN_MENU_ID),		1023, "ActionKzMenu");
	register_menucmd(register_menuid(TELE_MENU_ID),		1023, "ActionTeleportMenu");
	register_menucmd(register_menuid(MAP_BAN_MENU_ID),	1023, "ActionMapBanMenu");
	register_menucmd(register_menuid(MAP_PICK_MENU_ID),	1023, "ActionMapPickMenu");

	register_think("replay_bot", "npc_think");

	RegisterHam(Ham_Use, "func_button", "Fw_HamUseButtonPre");
	RegisterHam(Ham_Touch, "trigger_multiple", "Fw_HamUseButtonPre"); // ag_bhop_master.bsp starts timer when jumping on a platform
	RegisterHam(Ham_Spawn, "player", "Fw_HamSpawnPlayerPost", 1);
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPre");
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPost", 1);
	RegisterHam(Ham_BloodColor, "player", "Fw_HamBloodColorPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPost", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_crossbow",		"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_egon",			"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_handgrenade",	"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_hornetgun",		"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_rpg",			"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_satchel",		"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_snark",			"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_tripmine",		"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack,	"weapon_9mmAR",			"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack,	"weapon_gauss",			"Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack,	"weapon_satchel",		"Fw_HamBoostAttack");

	if (get_pcvar_float(pcvar_sv_items_respawn_time) > 0)
	{
		for (new i = 0; i < sizeof(g_ItemNames); i++)
			RegisterHam(Ham_Respawn, g_ItemNames[i], "Fw_HamItemRespawn", 1);

		for (new j = 0; j < sizeof(g_WeaponNames); j++)
			register_touch(g_WeaponNames[j], "worldspawn",	"Fw_FmWeaponRespawn");
	}

	register_forward(FM_ClientKill,"Fw_FmClientKillPre");
	register_forward(FM_ClientCommand, "Fw_FmClientCommandPost", 1);
	register_forward(FM_Think, "Fw_FmThinkPre");
	register_forward(FM_PlayerPreThink, "Fw_FmPlayerPreThinkPost", 1);
	register_forward(FM_PlayerPostThink, "Fw_FmPlayerPostThinkPre");
	register_forward(FM_AddToFullPack, "Fw_FmAddToFullPackPost", 1);
	register_forward(FM_GetGameDescription,"Fw_FmGetGameDescriptionPre");
	unregister_forward(FM_LightStyle, g_FwLightStyle);
	register_forward(FM_Touch, "Fw_FmTouchPre");
	register_forward(FM_CmdStart, "Fw_FmCmdStartPre");
	register_touch("hornet", 			"player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_satchel", 	"player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_snark", 	"player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_tripmine", 	"player", "Fw_FmPlayerTouchMonster");
	register_touch("trigger_teleport", 	"player", "Fw_FmPlayerTouchTeleport");
	register_touch("trigger_push", 		"player", "Fw_FmPlayerTouchPush");
	register_touch("trigger_multiple", 	"player", "Fw_FmPlayerTouchHealthBooster");

	mfwd_hlkz_cheating = CreateMultiForward("hlkz_cheating", ET_IGNORE, FP_CELL);
	mfwd_hlkz_worldrecord = CreateMultiForward("hlkz_worldrecord", ET_IGNORE, FP_CELL, FP_CELL);

	register_message(get_user_msgid("Health"), "Fw_MsgHealth");
	register_message(SVC_TEMPENTITY, "Fw_MsgTempEntity");
	new msgCountdown = get_user_msgid("Countdown");
	if (msgCountdown > 0)
		register_message(msgCountdown, "Fw_MsgCountdown");
	new msgSettings = get_user_msgid("Settings");
	if (msgSettings > 0)
		register_message(msgSettings, "Fw_MsgSettings");

	g_TaskEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	set_pev(g_TaskEnt, pev_classname, engfunc(EngFunc_AllocString, "timer_entity"));
	set_pev(g_TaskEnt, pev_nextthink, get_gametime() + 1.01);

	CheckSpawns();

	g_MaxPlayers = get_maxplayers();

	g_SyncHudTimer = CreateHudSyncObj();
	g_SyncHudMessage = CreateHudSyncObj();
	g_SyncHudKeys = CreateHudSyncObj();
	g_SyncHudHealth = CreateHudSyncObj();
	g_SyncHudShowStartMsg = CreateHudSyncObj();
	g_SyncHudSpeedometer = CreateHudSyncObj();
	g_SyncHudSpecList = CreateHudSyncObj();
	g_SyncHudCupMaps = CreateHudSyncObj();

	g_ArrayStats[NOOB] = ArrayCreate(STATS);
	g_ArrayStats[PRO]  = ArrayCreate(STATS);
	g_ArrayStats[PURE] = ArrayCreate(STATS);

	g_ReplayNum = 0;
}

public plugin_cfg()
{
	server_print("[%s] Executing plugin_cfg", PLUGIN_TAG);
	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	// Execute custom config file
	new cfg[256];
	formatex(cfg, charsmax(cfg), "%s/%s", g_ConfigsDir, PLUGIN_CFG_FILENAME);
	if (file_exists(cfg))
	{
		server_cmd("exec %s", cfg);
		server_exec();
	}

	// Execute custom map config file
	new mapCfg[288];
	formatex(mapCfg, charsmax(mapCfg), "%s/maps/%s_%s.cfg", g_ConfigsDir, PLUGIN_CFG_SHORTENED, g_Map);
	if (file_exists(mapCfg))
	{
		server_cmd("exec %s", mapCfg);
		server_exec();
	}

	// Dive into our custom directory
	add(g_ConfigsDir, charsmax(g_ConfigsDir), CONFIGS_SUB_DIR);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	formatex(g_ReplaysDir, charsmax(g_ReplaysDir), "%s/%s", g_ConfigsDir, "replays");
	if (!dir_exists(g_ReplaysDir))
		mkdir(g_ReplaysDir);

	GetTopTypeString(NOOB, g_TopType[NOOB]);
	GetTopTypeString(PRO,  g_TopType[PRO]);
	GetTopTypeString(PURE, g_TopType[PURE]);

	// Load stats
	formatex(g_StatsFile[NOOB], charsmax(g_StatsFile[]), "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[NOOB]);
	formatex(g_StatsFile[PRO],  charsmax(g_StatsFile[]),  "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[PRO]);
	formatex(g_StatsFile[PURE], charsmax(g_StatsFile[]), "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[PURE]);

	// Load map settings
	formatex(g_MapIniFile, charsmax(g_MapIniFile), "%s/%s.ini", g_ConfigsDir, g_Map);
	LoadMapSettings();

	g_isAnyBoostWeaponInMap = false;
	CheckMapWeapons();

	g_MapEndReqs = TrieCreate();
	g_UnorderedReqsMaps = TrieCreate();
	SetMapEndReqs();
	if (TrieGetSize(g_MapEndReqs))
		g_isHL1Campaign = true;

	if (get_pcvar_num(pcvar_kz_stop_moving_platforms))
	{
		// This has to be done here, if the map entities have already started moving,
		// then they simply won't stop, LOL, so stop them before that happens
		StopMovingPlatforms();
	}

	// Load map pool for kz_cup
	formatex(g_MapPoolFile, charsmax(g_MapPoolFile), "%s/%s", g_ConfigsDir, MAP_POOL_FILE);
	formatex(g_CupFile, charsmax(g_CupFile), "%s/%s", g_ConfigsDir, CUP_FILE);
	LoadMapPool();
	LoadCup();

	// Set up hud color
	new rgb[12], r[4], g[4], b[4];
	get_pcvar_string(pcvar_kz_hud_rgb, rgb, charsmax(rgb));
	parse(rgb, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	g_HudRGB[0] = str_to_num(r);
	g_HudRGB[1] = str_to_num(g);
	g_HudRGB[2] = str_to_num(b);

	set_task(2.00, "InitTopsAndDB", TASKID_CONFIGURE_DB);
}

public plugin_end()
{
	ArrayDestroy(g_ArrayStats[NOOB]);
	ArrayDestroy(g_ArrayStats[PRO]);
	ArrayDestroy(g_ArrayStats[PURE]);
	TrieDestroy(g_CupMapPool);
}

// To be executed after cvars in amxx.cfg and other configs have been set,
// important for the DB connection to be up before loading any top
// FIXME: this should be put back in the init without delay, and the commands should go in kl_kreedz.cfg
public InitTopsAndDB()
{
	if (get_pcvar_num(pcvar_kz_remove_func_friction))
		RemoveFuncFriction();

	// Create healer
	if (get_pcvar_num(pcvar_kz_autoheal))
		CreateGlobalHealer();

	//console_print(0, "[%s] kz_mysql: %d", PLUGIN_TAG, get_pcvar_num(pcvar_kz_mysql));
	if (get_pcvar_num(pcvar_kz_mysql))
	{
		new dbHost[261], dbUser[32], dbPass[32], dbName[256];
		get_pcvar_string(pcvar_kz_mysql_host, dbHost, charsmax(dbHost));
		get_pcvar_string(pcvar_kz_mysql_user, dbUser, charsmax(dbUser));
		get_pcvar_string(pcvar_kz_mysql_pass, dbPass, charsmax(dbPass));
		get_pcvar_string(pcvar_kz_mysql_db, dbName, charsmax(dbName));

		g_DbHost = mysql_makehost(dbHost, dbUser, dbPass, dbName);

		new error[32], errNo;
		server_print("Connecting to MySQL @ %s with user %s, DB: %s", dbHost, dbUser, dbName);
		g_DbConnection = mysql_connect(g_DbHost, errNo, error, 31);
		if (errNo)
		{
			log_to_file(MYSQL_LOG_FILENAME, "ERROR: [%d] - [%s]", errNo, error);
			server_print("The hl_kreedz.amxx plugin has MySQL storage activated, but failed to connect to MySQL. You can see the error in the %s file", MYSQL_LOG_FILENAME);
			pause("ad");
			return;
		}

		mysql_escape_string(g_EscapedMap, charsmax(g_EscapedMap), g_Map);

		new threadFPS = get_pcvar_num(pcvar_kz_mysql_thread_fps);
		new threadThinkTime = 1000 / threadFPS;
		mysql_performance(get_pcvar_num(pcvar_kz_mysql_collect_time_ms), threadThinkTime, get_pcvar_num(pcvar_kz_mysql_threads));

		// Insert the current map if doesn't exist
		new what[4], insertMapQuery[704], selectMapQuery[176];
		formatex(what, charsmax(what), "map");
		formatex(insertMapQuery, charsmax(insertMapQuery), "INSERT INTO map (name) \
		                                  SELECT '%s' \
		                                  FROM (select 1) as a \
		                                  WHERE NOT EXISTS( \
		                                      SELECT name \
		                                      FROM map \
		                                      WHERE name = '%s' \
		                                  ) \
		                                  LIMIT 1", g_EscapedMap, g_EscapedMap);

		mysql_query(g_DbConnection, "DefaultInsertHandler", insertMapQuery, what, sizeof(what));

		formatex(selectMapQuery, charsmax(selectMapQuery), "SELECT id FROM map WHERE name = '%s'", g_EscapedMap); // FIXME check if the escaped name may differ from the one in DB
		mysql_query(g_DbConnection, "SelectMapIdHandler", selectMapQuery);

		// TODO: Insert server location data
		// TODO: Insert the `server` if doesn't exist
		// TODO: Insert the `server_map` if doesn't exist
	}

	LoadRecords(PURE);
	LoadRecords(PRO);
	LoadRecords(NOOB);
}


//*******************************************************
//*                                                     *
//* Menus                                               *
//*                                                     *
//*******************************************************

public CmdTPMenuHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		DisplayTeleportMenu(id, g_TeleMenuPosition[id] = 0);

	return PLUGIN_HANDLED;
}

DisplayTeleportMenu(id, pos)
{
	if (pos < 0)
		return;

	get_players(g_TeleMenuPlayers[id], g_TeleMenuPlayersNum[id]);

	new menuBody[512];
	new b = 0;
	new i;
	new name[32];
	new start = pos * 7;

	if (start >= g_TeleMenuPlayersNum[id])
		start = pos = g_TeleMenuPosition[id] = 0;

	new len = formatex(menuBody, charsmax(menuBody), "%s Teleport Menu %d/%d\n\n", PLUGIN, pos + 1, (g_TeleMenuPlayersNum[id] / 6 + ((g_TeleMenuPlayersNum[id] % 6) ? 1 : 0)));
	new end = start + 7;
	new keys = MENU_KEY_0;

	if (end > g_TeleMenuPlayersNum[id])
		end = g_TeleMenuPlayersNum[id];

	for (new a = start; a < end; ++a)
	{
		i = g_TeleMenuPlayers[id][a];
		get_user_name(i, name, charsmax(name));

		if (!is_user_alive(i) || id == i)
		{
			++b; len += formatex(menuBody[len], charsmax(menuBody) - len, "#. %s\n", name);
		}
		else
		{
			keys |= (1<<b);

			if (is_user_admin(i))
				len += formatex(menuBody[len], charsmax(menuBody) - len, "%d. %s *\n", ++b, name);
			else
				len += formatex(menuBody[len], charsmax(menuBody) - len, "%d. %s\n", ++b, name);
		}
	}

	keys |= MENU_KEY_8;
	len += formatex(menuBody[len], charsmax(menuBody) - len, "\n8. TP to %s\n", g_TeleMenuOption[id] ? "player" : "admin");

	if (end != g_TeleMenuPlayersNum[id])
	{
		formatex(menuBody[len], charsmax(menuBody) - len, "\n9. %L...\n0. %L", id, "MORE", id, pos ? "BACK" : "EXIT");
		keys |= MENU_KEY_9;
	}
	else
		formatex(menuBody[len], charsmax(menuBody) - len, "\n0. %L", id, pos ? "BACK" : "EXIT");

	show_menu(id, keys, menuBody, -1, TELE_MENU_ID);
}

public ActionTeleportMenu(id, key)
{
	switch (key)
	{
	case 7:
		{
			g_TeleMenuOption[id] = !g_TeleMenuOption[id];
			DisplayTeleportMenu(id, g_TeleMenuPosition[id]);
		}

	case 8: DisplayTeleportMenu(id, ++g_TeleMenuPosition[id]);
	case 9: DisplayTeleportMenu(id, --g_TeleMenuPosition[id]);

	default:
		{
			new player = g_TeleMenuPlayers[id][g_TeleMenuPosition[id] * 7 + key];

			// Get names for displaying/logging activity
			static adminName[33], playerName[33];
			get_user_name(id, adminName, charsmax(adminName));
			get_user_name(player, playerName, charsmax(playerName));

			if (!is_user_alive(player))
			{
				client_print(id, print_chat, "[%s] %L", PLUGIN_TAG, id, "CANT_PERF_DEAD", playerName);
				DisplayTeleportMenu(id, g_TeleMenuPosition[id]);
				return PLUGIN_HANDLED;
			}

			new origin[3];
			if (g_TeleMenuOption[id])
			{
				get_user_origin(player, origin);
				set_user_origin(id, origin);
			}
			else
			{
				get_user_origin(id, origin);
				set_user_origin(player, origin);
			}

			// Log activity
			static authid[33], ip[16];
			get_user_authid(id, authid, charsmax(authid));
			get_user_ip(id, ip, charsmax(ip), 1);

			log_amx("[%s] ADMIN %s <%s><%s> teleport%s player %s", PLUGIN_TAG, adminName, authid, ip, g_TeleMenuOption[id] ? "ed to" : "", playerName);
			client_print(0, print_chat, "[%s] ADMIN %s teleport%s player %s", PLUGIN_TAG, adminName, g_TeleMenuOption[id] ? "ed to" : "", playerName);

			DisplayTeleportMenu(id, g_TeleMenuPosition[id]);
		}
	}

	return PLUGIN_HANDLED;
}

DisplayKzMenu(id, mode)
{
	g_KzMenuOption[id] = mode;

	new menuBody[512], len;
	new keys = MENU_KEY_0;

	switch (mode)
	{
	case 0:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7; // | MENU_KEY_8;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "%s\n\n", PLUGIN);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. START CLIMB\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Checkpoints\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Practice checkpoints\n\n");	
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. HUD settings\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Top climbers\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Spectate players\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "7. Help\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "8. About\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "9. Admin area\n\n");
		}
	case 1:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Climb Menu\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Start position\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Respawn\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Pause timer\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Reset\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Set custom start position\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Clear custom start position\n");
		}
	case 2:
		{
			keys |= MENU_KEY_1;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "CPs: %d | TPs: %d\n\n", g_CpCounters[id][COUNTER_CP], g_CpCounters[id][COUNTER_TP]);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Checkpoint\n");

			if (g_CpCounters[id][COUNTER_CP])
			{
				keys |= MENU_KEY_2;
				len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Teleport\n\n");
			}
			else
				len += formatex(menuBody[len], charsmax(menuBody) - len, "#. Teleport (0/1 CPs)\n\n");

			if (g_CpCounters[id][COUNTER_CP] > 1)
			{
				keys |= MENU_KEY_3;
				len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Unstuck\n");
			}
			else
				len += formatex(menuBody[len], charsmax(menuBody) - len, "#. Unstuck (%d/2 CPs)\n", g_CpCounters[id][COUNTER_CP]);
		}
	case 3:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Practice CPs: %d | TPs: %d\n\n", g_CpCounters[id][COUNTER_PRACTICE_CP],g_CpCounters[id][COUNTER_PRACTICE_TP]);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Checkpoint\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Teleport\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Previous\n");
		}		
	case 4:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4;

			new timerStatus[7], keysStatus[5];
			switch(g_ShowTimer[id])
			{
			case 0: timerStatus = "OFF";
			case 1: timerStatus = "CENTER";
			case 2: timerStatus = "HUD";
			}
			switch(g_ShowKeys[id])
			{
			case 0: keysStatus = "OFF";
			case 1: keysStatus = "AUTO";
			case 2: keysStatus = "ON";
			}

			len = formatex(menuBody[len], charsmax(menuBody) - len, "HUD Settings\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Timer display: %s\n", timerStatus);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Keys display: %s\n", keysStatus);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Start message display: %s\n", g_ShowStartMsg[id] ? "ON" : "OFF");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Time decimals display: %d\n", g_TimeDecimals[id]);
		}
	case 5:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Show Top Climbers\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Pure 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Pro 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Noob 15\n");
		}
	}

	if (mode)
	{
		keys |= MENU_KEY_9;
		len += formatex(menuBody[len], charsmax(menuBody) - len, "\n9. Back\n");
	}

	len += formatex(menuBody[len], charsmax(menuBody) - len, "0. Exit");

	show_menu(id, keys, menuBody, -1, MAIN_MENU_ID);
	return PLUGIN_HANDLED;
}

createMapMenu(id, const menu_id[], bool:wasBadChoice=false)
{
	new playerName[32];
	GetColorlessName(id, playerName, charsmax(playerName));

	if (!wasBadChoice)
	{
		if (containi(menu_id, "pick") != -1)
			client_print(0, print_chat, "[%s] Now it's %s's turn to pick a map.", PLUGIN_TAG, playerName);
		else
			client_print(0, print_chat, "[%s] Now it's %s's turn to ban a map.", PLUGIN_TAG, playerName);
	}

	new menuText[512];
	formatex(menuText, charsmax(menuText), "\\w%s:\n", menu_id);

	new i, map[32], mapState;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetCell(ti, mapState);
		TrieIterGetKey(ti, map, charsmax(map));

		new mapStateText[10];
		if (g_MapStateString[mapState][0])
		{
			formatex(mapStateText, charsmax(mapStateText), "[%s]", g_MapStateString[mapState]);
			strtoupper(mapStateText);
		}

		if (mapState == MAP_IDLE)
		{
			formatex(menuText, charsmax(menuText), "%s\\y%d\\w. %s %s\n",
				menuText,
				i+1,
				map,
				mapStateText);
		}
		else
		{
			formatex(menuText, charsmax(menuText), "%s\\r%d\\d. %s %s\n",
				menuText,
				i+1,
				map,
				mapStateText);
		}

		i++;
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	new keys = MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5
				| MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9 | MENU_KEY_0;

	show_menu(id, keys, menuText, _, menu_id);
	return PLUGIN_HANDLED;
}

public ActionMapBanMenu(id, key)
{
	new i, map[32], mapState;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		if (key == i)
		{
			TrieIterGetCell(ti, mapState);

			if (mapState == MAP_IDLE)
			{
				TrieIterGetKey(ti, map, charsmax(map));
				break;
			}
		}

		i++;
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (map[0])
	{
		// Update map state
		TrieSetCell(g_CupMapPool, map, MAP_BANNED);

		new availableMaps = CountCupMaps(MAP_IDLE);

		new playerName[32];
		GetColorlessName(id, playerName, charsmax(playerName));
		if (!playerName[0])
			formatex(playerName, charsmax(playerName), "The unnamed player");

		client_print(0, print_chat, "[%s] %s has banned %s.", PLUGIN_TAG, playerName, map);

		new remainingMapsToBan = availableMaps - g_CupMatches;
		if (remainingMapsToBan > 0)
		{
			client_print(0, print_chat, "[%s] Remaining %d map%s to be banned.",
				PLUGIN_TAG, remainingMapsToBan, remainingMapsToBan == 1 ? "" : "s");
		}
		else
		{
			client_print(0, print_chat, "[%s] We're done banning maps. Time to pick! You'll pick %d maps and then the remaining one is the decider.",
				PLUGIN_TAG, g_CupMatches - 1);
		}
		CmdMapsShowHandler(0);

		// ABBA format banning
		// (A) 1 --> prev = 0, id = 1, next = 2
		// (B) 2 --> prev = 1, id = 2, next = 2
		// (B) 2 --> prev = 2, id = 2, next = 1
		// (A) 1 --> prev = 2, id = 1, next = 1
		new nextId;
		if (g_PrevChooser)
		{
			if (id == g_PrevChooser)
			{
				// Have done 2 bans in a row, so the turn is now for the opponent
				nextId = (id == g_CupPlayer1) ? g_CupPlayer2 : g_CupPlayer1;
			}
			else
			{
				// Have done 1 ban, the turn continues being for the same player
				nextId = id;
			}
		}
		else
		{
			// This was the first ban, so now the turn is for the opponent
			nextId = (id == g_CupPlayer1) ? g_CupPlayer2 : g_CupPlayer1;
		}

		// Update now the previous chooser, after it's been used
		g_PrevChooser = id;

		server_print("ActionMapBanMenu :: availableMaps=%d, g_CupMatches=%d", availableMaps, g_CupMatches);
		if (availableMaps == g_CupMatches)
		{
			// Time to start picking maps
			// Player1 started banning, now Player2 has to start picking
			nextId = (g_FirstBanner == g_CupPlayer1) ? g_CupPlayer2 : g_CupPlayer1;
			g_PrevChooser = 0;
			createMapMenu(nextId, MAP_PICK_MENU_ID);
		}
		else
		{
			// Continue banning
			createMapMenu(nextId, MAP_BAN_MENU_ID);
		}
	}
	else
	{
		client_print(id, print_chat, "[%s] Please, ban a map that's not already banned.", PLUGIN_TAG);
		createMapMenu(id, MAP_BAN_MENU_ID, true);
	}

	return PLUGIN_HANDLED;
}

public ActionMapPickMenu(id, key)
{
	new i, map[32], mapState;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		if (key == i)
		{
			TrieIterGetCell(ti, mapState);

			if (mapState == MAP_IDLE)
			{
				TrieIterGetKey(ti, map, charsmax(map));
				break;
			}
		}

		i++;
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (map[0])
	{
		// Update map state
		TrieSetCell(g_CupMapPool, map, MAP_PICKED);

		new availableMaps = CountCupMaps(MAP_IDLE);

		new playerName[32];
		GetColorlessName(id, playerName, charsmax(playerName));
		if (!playerName[0])
			formatex(playerName, charsmax(playerName), "The unnamed player");
		
		client_print(0, print_chat, "[%s] %s has picked %s.", PLUGIN_TAG, playerName, map);

		new mapsToPick = availableMaps - 1; // minus the decider, that is autopicked
		if (mapsToPick > 0)
		{
			client_print(0, print_chat, "[%s] Remaining %d map%s to be picked, and then the decider is autopicked.",
				PLUGIN_TAG, mapsToPick, mapsToPick == 1 ? "" : "s");
		}

		// TODO: DRY, same code as in the map banning function
		// ABBA format banning
		// (A) 1 --> prev = 0, id = 1, next = 2
		// (B) 2 --> prev = 1, id = 2, next = 2
		// (B) 2 --> prev = 2, id = 2, next = 1
		// (A) 1 --> prev = 2, id = 1, next = 1
		new nextId;
		if (g_PrevChooser)
		{
			if (id == g_PrevChooser)
			{
				// Have done 2 bans in a row, so the turn is now for the opponent
				nextId = (id == g_CupPlayer1) ? g_CupPlayer2 : g_CupPlayer1;
			}
			else
			{
				// Have done 1 ban, the turn continues being for the same player
				nextId = id;
			}
		}
		else
		{
			// This was the first ban, so now the turn is for the opponent
			nextId = (id == g_CupPlayer1) ? g_CupPlayer2 : g_CupPlayer1;
		}

		// Update now the previous chooser, after it's been used
		g_PrevChooser = id;

		server_print("ActionMapPickMenu :: availableMaps=%d, g_CupMatches=%d", availableMaps, g_CupMatches);
		if (availableMaps == 1)
		{
			GetLastCupMapAvailable(map, charsmax(map));
			
			// The decider is the last map that's left, no more menus, this is chosen automatically
			TrieSetCell(g_CupMapPool, map, MAP_DECIDER);
			client_print(0, print_chat, "[%s] %s will be the decider.", PLUGIN_TAG, map);

			// Map states during bans/picks only get saved here
			// If the server crashes or there's a map change in the middle of the
			// bans/picks, then all that info will be lost and kz_cup should be issued again
			WriteCupMapPoolFile(0);

			// Now we're gonna change (or not) the map to start playing
			GetNextCupMapToPlay(map, charsmax(map));

			if (equal(map, g_Map))
			{
				// We're gonna play in this very map, so no changelevel needed
				client_print(0, print_chat, "[%s] The next map to be played is %s.", PLUGIN_TAG, map);
				client_print(0, print_chat, "[%s] We're already in that map, so just waiting for participants to get /ready to start ;)", PLUGIN_TAG);
			}
			else
			{
				new Float:timeToChange = get_pcvar_float(pcvar_kz_cup_map_change_delay);
				client_print(0, print_chat, "[%s] The next map to be played is %s. Changing the map in %.0f seconds...", PLUGIN_TAG, map, timeToChange);

				set_task(timeToChange, "CupChangeMap", TASKID_CUP_CHANGE_MAP, map, charsmax(map));
			}
		}
		else
		{
			// Continue picking
			createMapMenu(nextId, MAP_PICK_MENU_ID);
		}
		CmdMapsShowHandler(0);
	}
	else
	{
		client_print(id, print_chat, "[%s] Please, pick a map that's not already banned/picked.", PLUGIN_TAG);
		createMapMenu(id, MAP_PICK_MENU_ID, true);
	}

	return PLUGIN_HANDLED;
}

public ActionKzMenu(id, key)
{
	key++;

	if (key == 9) DisplayKzMenu(id, 0);
	if (key == 10) return PLUGIN_HANDLED;

	switch (g_KzMenuOption[id])
	{
	case 0:
		switch (key)
		{
		case 1: return DisplayKzMenu(id, 1);
		case 2: return DisplayKzMenu(id, 2);
		case 3: return DisplayKzMenu(id, 3);
		case 4: return DisplayKzMenu(id, 4);
		case 5: return DisplayKzMenu(id, 5);
		case 6: CmdSpec(id);
		case 7: CmdHelp(id);
		}
	case 1:
		switch (key)
		{
		case 1: CmdStart(id);
		case 2: CmdRespawn(id);
		case 3: CmdPause(id);
		case 4: CmdReset(id);
		case 5: CmdSetCustomStartHandler(id);
		case 6: CmdClearCustomStartHandler(id);
		}
	case 2:
		switch (key)
		{
		case 1: CmdCp(id);
		case 2: CmdTp(id);
		case 3: CmdStuck(id);
		}
	case 3:
		switch (key)
		{
			case 1: CmdPracticeCp(id);
			case 2: CmdPracticeTp(id);
			case 3: CmdPracticePrev(id);
		}
	case 4:
		switch (key)
		{
		case 1: CmdTimer(id);
		case 2: CmdShowkeys(id);
		case 3: CmdMenuShowStartMsg(id);
		case 4: CmdMenuTimeDecimals(id);
		}
	case 5:
		switch (key)
		{
		case 1: ShowTopClimbers(id, PURE);
		case 2: ShowTopClimbers(id, PRO);
		case 3: ShowTopClimbers(id, NOOB);
		}
	}

	DisplayKzMenu(id, g_KzMenuOption[id]);
	return PLUGIN_HANDLED;
}




//*******************************************************
//*                                                     *
//* Player handling                                     *
//*                                                     *
//*******************************************************

public client_putinserver(id)
{
	set_bit(g_bit_is_connected, id);
	if (is_user_hltv(id))
		set_bit(g_bit_is_hltv, id);
	if (is_user_bot(id))
		set_bit(g_bit_is_bot, id);

	g_ShowTimer[id] = get_pcvar_num(pcvar_kz_show_timer);
	g_ShowKeys[id] = get_pcvar_num(pcvar_kz_show_keys);
	g_ShowStartMsg[id] = get_pcvar_num(pcvar_kz_show_start_msg);
	// FIXME: get default value from client, and then fall back to server if client doesn't have the command set
	g_TimeDecimals[id] = get_pcvar_num(pcvar_kz_time_decimals);
	g_Nightvision[id] = get_pcvar_num(pcvar_kz_nightvision);
	g_Slopefix[id] = get_pcvar_num(pcvar_kz_slopefix);
	// Nightvision value 1 in server cvar is "all modes allowed", if that's the case we default it to mode 2 in client,
	// every other mode in cvar is +1 than client command, so we do -1 to get the correct mode
	if (g_Nightvision[id] > 1)
		g_Nightvision[id]--;
	else if (g_Nightvision[id] == 1)
		g_Nightvision[id] = 2;

	g_Speedcap[id] = get_pcvar_float(pcvar_kz_speedcap);

	g_ShowSpeed[id] = false;
	g_ShowSpecList[id] = true;
	g_ConsolePrintNextFrames[id] = 0;
	g_ReplayFpsMultiplier[id] = 1;

	//query_client_cvar(id, "kz_nightvision", "ClCmdNightvision"); // TODO save user variables in a file and retrieve them when they connect to server

	new Float:time = get_gametime();
	//console_print(0, "[%.3f] Setting map default start for %d", time, id);
	g_ControlPoints[id][CP_TYPE_DEFAULT_START] = g_MapDefaultStart;

	g_ReplayFrames[id] = ArrayCreate(REPLAY);

	// Link this player to the cup player
	new uniqueId[32];
	GetUserUniqueId(id, uniqueId, charsmax(uniqueId));

	if (equal(g_CupSteam1, uniqueId))
		g_CupPlayer1 = id;

	if (equal(g_CupSteam2, uniqueId))
		g_CupPlayer2 = id;

	set_task(1.20, "DisplayWelcomeMessage", id + TASKID_WELCOME);
}

public client_disconnect(id)
{
	clr_bit(g_bit_is_connected, id);
	clr_bit(g_bit_is_hltv, id);
	clr_bit(g_bit_is_bot, id);
	clr_bit(g_bit_invis, id);
	clr_bit(g_bit_waterinvis, id);
	clr_bit(g_baIsFirstSpawn, id);
	clr_bit(g_baIsPureRunning, id);
	g_SolidState[id] = -1;
	g_PlayerEndReqs[id] = 0;

	if (g_RecordRun[id])
	{
		//fclose(g_RecordRun[id]);
		g_RecordRun[id] = 0;
		ArrayClear(g_RunFrames[id]);
		//console_print(id, "stopped recording");
	}
	ArrayClear(g_ReplayFrames[id]);
	g_ReplayFramesIdx[id] = 0;


	// Clear and reset other things
	ResetPlayer(id, true, false);

	g_ControlPoints[id][CP_TYPE_START][CP_VALID] = false;
}

ResetPlayer(id, bool:onDisconnect, bool:onlyTimer)
{
	// Unpause
	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
	remove_task(id + TASKID_ICON);

	InitPlayer(id, onDisconnect, onlyTimer);

	if (!onDisconnect)
	{
		if (onlyTimer)
			ShowMessage(id, "Timer reset");
		else
			ShowMessage(id, "Timer and checkpoints reset");
	}
}

InitPlayer(id, bool:onDisconnect = false, bool:onlyTimer = false)
{
	new i;

	// Reset timer
	clr_bit(g_baIsClimbing, id);
	clr_bit(g_baIsPaused, id);
	clr_bit(g_baIsPureRunning, id);

	g_PlayerTime[id] = 0.0;
	g_PlayerTimePause[id] = 0.0;
	g_PlayerEndReqs[id] = 0;

	if (!onDisconnect)
	{
		// Clear the timer hud
		client_print(id, print_center, "");
		ClearSyncHud(id, g_SyncHudTimer);

		// Clear the timer hud for spectating spectators
		for (i = 1; i <= g_MaxPlayers; i++)
		{
			if (pev(i, pev_iuser1) == OBS_IN_EYE && pev(i, pev_iuser2) == id)
			{
				client_print(i, print_center, "");
				ClearSyncHud(i, g_SyncHudTimer);
			}
		}

		if (onlyTimer)
			return;

		// Reset score
		ExecuteHamB(Ham_AddPoints, id, -(pev(id, pev_frags)), true);

		// Reset health
		new Float:health;
		pev(id, pev_health, health);
		if (health < 100.0 && IsAlive(id) && !pev(id, pev_iuser1))
			set_pev(id, pev_health, 100.0);
	}

	// Reset checkpoints
	for (i = 0; i < CP_TYPE_CUSTOM_START; i++)
		g_ControlPoints[id][i][CP_VALID] = false;

	// Reset counters
	for (i = 0; i < COUNTERS; i++)
		g_CpCounters[id][i] = 0;
}

public DisplayWelcomeMessage(id)
{
	id -= TASKID_WELCOME;
	client_print(id, print_chat, "[%s] Welcome to %s", PLUGIN_TAG, PLUGIN);
	client_print(id, print_chat, "[%s] Visit sourceruns.org & www.aghl.ru", PLUGIN_TAG);
	client_print(id, print_chat, "[%s] You can say /kzhelp to see available commands", PLUGIN_TAG);

	if (!get_pcvar_num(pcvar_kz_checkpoints))
		client_print(id, print_chat, "[%s] Checkpoints are off", PLUGIN_TAG);

	if (get_pcvar_num(pcvar_kz_spawn_mainmenu))
		DisplayKzMenu(id, 0);
}




//*******************************************************
//*                                                     *
//* Client commands                                     *
//*                                                     *
//*******************************************************

CmdCp(id)
{
	if (CanCreateCp(id))
		CreateCp(id, CP_TYPE_CURRENT);
}

CmdTp(id)
{
	if (CanTeleport(id, CP_TYPE_CURRENT))
		Teleport(id, CP_TYPE_CURRENT);
}

CmdPracticeCp(id)
{
	if (CanCreateCp(id, true, true))
		CreateCp(id, CP_TYPE_PRACTICE)
}

CmdPracticeTp(id)
{
	ResetPlayer(id, false, true);
	if (CanTeleport(id, CP_TYPE_PRACTICE))
		Teleport(id, CP_TYPE_PRACTICE);
}

CmdStuck(id)
{
	if (CanTeleport(id, CP_TYPE_OLD))
		Teleport(id, CP_TYPE_OLD);
}

CmdPracticePrev(id)
{
	ResetPlayer(id, false, true)
	if(CanTeleport(id, CP_TYPE_PRACTICE_OLD))
		Teleport(id, CP_TYPE_PRACTICE_OLD);
}

CmdStart(id)
{
	if (!g_bMatchRunning && CanTeleport(id, CP_TYPE_CUSTOM_START, false))
	{
		ResetPlayer(id, false, true);
		Teleport(id, CP_TYPE_CUSTOM_START);
		return;
	}

	if (CanTeleport(id, CP_TYPE_START))
		Teleport(id, CP_TYPE_START);
	else if (CanTeleport(id, CP_TYPE_DEFAULT_START))
		Teleport(id, CP_TYPE_DEFAULT_START);
}

CmdPause(id)
{
	if (CanPause(id))
		get_bit(g_baIsPaused, id) ? ResumeTimer(id) : PauseTimer(id, false);
}

CmdReset(id)
{
	if (CanReset(id))
		ResetPlayer(id, false, false);
}

CmdSpecList(id)
{
	//console_print(id, "pev_iuser1 is %s", pev(id, pev_iuser1) ? "set" : "NOT set"); // happens when you're in spectator mode
	//console_print(id, "pev_iuser2 is %s", pev(id, pev_iuser2) ? "set" : "NOT set"); // happens when you're spectating a player (not in Free mode)
	if (!get_pcvar_num(pcvar_kz_speclist))
	{
		ShowMessage(id, "Toggling the spectator list is disabled by server");
		return;
	}
	g_ShowSpecList[id] = !g_ShowSpecList[id];
	client_print(id, print_chat, "[%s] Spectator list is now %s", PLUGIN_TAG, g_ShowSpecList[id] ? "visible" : "hidden");
}

CmdSpec(id)
{
	client_cmd(id, "spectate");	// CanSpectate is called inside of command hook handler
}

CmdInvis(id)
{
	if(get_bit(g_bit_invis, id) || !IsAlive(id) || pev(id, pev_iuser1))
	{
		clr_bit(g_bit_invis, id);
		client_print(id, print_chat, "[%s] All players visible", PLUGIN_TAG);
	}
	else
	{
		set_bit(g_bit_invis, id);
		client_print(id, print_chat, "[%s] All players hidden", PLUGIN_TAG);
	}
}

CmdWaterInvis(id)
{
	if (get_bit(g_bit_waterinvis, id) || pev(id, pev_iuser1))
	{
		clr_bit(g_bit_waterinvis, id);
		client_print(id, print_chat, "[%s] Liquids are now visible", PLUGIN_TAG);
	}
	else
	{
		set_bit(g_bit_waterinvis, id);
		client_print(id, print_chat, "[%s] Liquids are now hidden", PLUGIN_TAG);
	}
}

CmdTimer(id)
{
	if (!get_pcvar_num(pcvar_kz_show_timer))
	{
		ShowMessage(id, "Timer display modification is disabled by server");
		return;
	}

	client_print(id, print_center, "");
	ClearSyncHud(id, g_SyncHudTimer);
	ClearSyncHud(id, g_SyncHudKeys);
	ClearSyncHud(id, g_SyncHudShowStartMsg);

	if (g_ShowTimer[id] < 2)
		ShowMessage(id, "Timer display position: %s", g_ShowTimer[id]++ < 1 ? "center" : "HUD");
	else
	{
		g_ShowTimer[id] = 0;
		ShowMessage(id, "Timer display: off");
	}
}
/*
CmdReplaySmoothen(id)
{
	new fpsMultiplier = max(floatround(xs_fabs(GetFloatArg()), floatround_floor), MAX_FPS_MULTIPLIER);
	g_ReplayFpsMultiplier[id] = fpsMultiplier;
}
*/
CmdReplayPure(id)
	CmdReplay(id, PURE);

CmdReplayPro(id)
	CmdReplay(id, PRO);

CmdReplayNoob(id)
	CmdReplay(id, NOOB);

CmdReplay(id, RUN_TYPE:runType)
{
	static authid[32], replayFile[256], idNumbers[24], stats[STATS], time[32];
	new minutes, Float:seconds, replayRank = GetNumberArg();
	new maxReplays = get_pcvar_num(pcvar_kz_max_concurrent_replays);
	new Float:setupTime = get_pcvar_float(pcvar_kz_replay_setup_time);

	LoadRecords(runType);
	new Array:arr = g_ArrayStats[runType];

	for (new i = 0; i < ArraySize(arr); i++)
	{
		ArrayGetArray(arr, i, stats);
		if (i == replayRank - 1)
		{
			stats[STATS_NAME][17] = EOS;
			formatex(authid, charsmax(authid), "%s", stats[STATS_ID]);
			break; // the desired record info is now stored in stats, so exit loop
		}
	}

	new replayingMsg[96], replayFailedMsg[96], szTopType[32];
	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(szTopType, charsmax(szTopType), g_TopType[runType]);
	strtolower(szTopType);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
	//formatex(g_ReplayFile[id], charsmax(replayFile), "%s", replayFile);
	//console_print(id, "rank %d's idNumbers: '%s', replay file: '%s'", replayRank, idNumbers, replayFile);

	minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
	seconds = stats[STATS_TIME] - (60 * minutes);

	formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%"), minutes, seconds);
	ucfirst(szTopType);
	formatex(replayingMsg, charsmax(replayingMsg), "[%s] Replaying %s's %s run (%ss)", PLUGIN_TAG, stats[STATS_NAME], szTopType, time);
	formatex(replayFailedMsg, charsmax(replayFailedMsg), "[%s] Sorry, no replay available for %s's %s run", PLUGIN_TAG, stats[STATS_NAME], szTopType);

	new file = fopen(replayFile, "rb");
	if (!file && runType == PRO && ComparePro2PureTime(stats[STATS_ID], stats[STATS_TIME]) == 0)
	{
		formatex(replayFile, charsmax(replayFile), "%s/%s_%s_pure.dat", g_ReplaysDir, g_Map, idNumbers);
		file = fopen(replayFile, "rb");
	}
	if (!file)
	{
		client_print(id, print_chat, "%s", replayFailedMsg);
		return PLUGIN_HANDLED;
	}
	else
	{
		new bool:canceled = false;
		if (g_ReplayFramesIdx[id])
		{
			new bot = GetOwnersBot(id);
			//console_print(1, "CmdReplay :: removing bot %d", bot);
			FinishReplay(id);
			KickReplayBot(bot + TASKID_KICK_REPLAYBOT);
			canceled = true;
		}

		if (g_ReplayNum >= maxReplays)
		{
			client_print(id, print_chat, "[%s] Sorry, there are too many replays running! Please, wait until one of the %d replays finish", PLUGIN_TAG, g_ReplayNum);
			fclose(file);
			return PLUGIN_HANDLED;
		}
		else if (GetOwnersBot(id))
		{
			client_print(id, print_chat, "[%s] Your previous bot is still setting up. Please, wait %.1f seconds to start a new replay", PLUGIN_TAG, setupTime);
			fclose(file);
			return PLUGIN_HANDLED;
		}

		if (canceled)
			client_print(id, print_chat, "[%s] Your previous replay has been canceled. Initializing the replay you've just requested...", PLUGIN_TAG);

		client_print(id, print_chat, "%s", replayingMsg);
	}

	if (!g_ReplayFramesIdx[id])
	{
		new replay[REPLAY], replay0[REPLAY];

		ArrayClear(g_ReplayFrames[id]);
		//console_print(id, "gonna read the replay file");

		//fread(file, version, BLOCK_SHORT);
		//console_print(1, "replaying demo of version %d", version);

		new i = 0;
		while (!feof(file))
		{
			fread_blocks(file, replay, sizeof(replay) - 1, BLOCK_INT);
			fread(file, replay[RP_BUTTONS], BLOCK_SHORT);
			ArrayPushArray(g_ReplayFrames[id], replay);
			i++;
		}
		fclose(file);
		ArrayGetArray(g_ReplayFrames[id], 0, replay0);
		// ((1483.79 - 1452.84) / 7630) * 1
		new Float:demoFramerate = 1.0 / ((replay[RP_TIME] - replay0[RP_TIME]) / float(i)) * float(g_ReplayFpsMultiplier[id]);
		//console_print(id, "%.3f = 1.0 / ((%.3f - %.3f) / %.3f) * %.3f", demoFramerate, replay[RP_TIME], replay0[RP_TIME], float(i), float(g_ReplayFpsMultiplier[id]));

		g_ReplayNum++;
		SpawnBot(id);
		client_print(id, print_chat, "[%s] Your bot will start running at %.2f fps (on average) in %.1f seconds", PLUGIN_TAG, demoFramerate, setupTime);
		//console_print(1, "replayft=%.3f, replay0t=%.2f, i=%d, mult=%d", replay[RP_TIME], replay0[RP_TIME], i, g_ReplayFpsMultiplier[id]);
	}
}

SpawnBot(id)
{
	if (get_playersnum(1) < g_MaxPlayers - 4) // leave at least 4 slots available
	{
		new botName[33];
		formatex(botName, charsmax(botName), "%s Bot ", PLUGIN_TAG);
		for (new i = 0; i < 4; i++)
		{ // Generate a random number 4 times, so the final name is like Bot 0123
			new str[2];
			num_to_str(random_num(0, 9), str, charsmax(str));
			add(botName, charsmax(botName), str);
		}
		new bot;
		bot = engfunc(EngFunc_CreateFakeClient, botName);
		if (bot)
		{
			// Creating an entity that will make the thinking process for this bot
			new ent = create_entity("info_target");
			g_BotEntity[bot] = ent;
			entity_set_string(ent, EV_SZ_classname, "replay_bot");

			engfunc(EngFunc_FreeEntPrivateData, bot);
			ConfigureBot(bot);

			new ptr[128], ip[64];
			get_cvar_string("ip", ip, charsmax(ip));
			dllfunc(DLLFunc_ClientConnect, bot, botName, ip, ptr);
			dllfunc(DLLFunc_ClientPutInServer, bot);
			set_pev(bot, pev_flags, pev(bot, pev_flags) | FL_FAKECLIENT);
			set_bit(g_bit_is_bot, bot);

			entity_set_float(bot, EV_FL_takedamage, 1.0);
			entity_set_float(bot, EV_FL_health, 100.0);

			entity_set_byte(bot, EV_BYTE_controller1, 125);
			entity_set_byte(bot, EV_BYTE_controller2, 125);
			entity_set_byte(bot, EV_BYTE_controller3, 125);
			entity_set_byte(bot, EV_BYTE_controller4, 125);

			new Float:maxs[3] = {16.0, 16.0, 36.0};
			new Float:mins[3] = {-16.0, -16.0, -36.0};
			entity_set_size(bot, mins, maxs);

			// Copy the state of the player who spawned the bot
			static replay[REPLAY];
			ArrayGetArray(g_ReplayFrames[id], 0, replay);

			set_pev(bot, pev_origin, replay[RP_ORIGIN]);
			set_pev(bot, pev_angles, replay[RP_ANGLES]);
			set_pev(bot, pev_v_angle, replay[RP_ANGLES]);
			set_pev(bot, pev_button, replay[RP_BUTTONS]);
			g_ReplayStartGameTime[id] = replay[RP_TIME];
			//g_isCustomFpsReplay[id] = g_ReplayFpsMultiplier[id] > 1;

			g_BotOwner[bot] = id;
			g_Unfreeze[bot] = false;
			//console_print(1, "player %d spawned the bot %d", id, bot);

			entity_set_float(ent, EV_FL_nextthink, get_gametime() + get_pcvar_float(pcvar_kz_replay_setup_time)); // TODO: countdown hud; 2 seconds to start the replay, so there's time to switch to spectator
			engfunc(EngFunc_RunPlayerMove, bot, replay[RP_ANGLES], 0.0, 0.0, 0.0, replay[RP_BUTTONS], 0, 4);
		}
		else
			client_print(id, print_chat, "[%s] Sorry, couldn't create the bot", PLUGIN_TAG);
	}
	else
		client_print(id, print_chat, "[%s] Sorry, won't spawn the bot since there are only 4 slots left for players", PLUGIN_TAG);

    return PLUGIN_HANDLED;
}

SpawnDummyBot(id)
{
	if (get_playersnum(1) < g_MaxPlayers - 4) // leave at least 4 slots available
	{
		new botName[33];
		formatex(botName, charsmax(botName), "%s Dummy ", PLUGIN_TAG);
		for (new i = 0; i < 4; i++)
		{ // Generate a random number 4 times, so the final name is like Bot 0123
			new str[2];
			num_to_str(random_num(0, 9), str, charsmax(str));
			add(botName, charsmax(botName), str);
		}
		new bot, ptr[128], ip[64];
		bot = engfunc(EngFunc_CreateFakeClient, botName);
		if (bot)
		{
			// Creating an entity that will make the thinking process for this bot
			//new ent = create_entity("info_target");
			//g_BotEntity[bot] = ent;
			//entity_set_string(ent, EV_SZ_classname, "dummy_bot");

			engfunc(EngFunc_FreeEntPrivateData, bot);
			ConfigureBot(bot);
			get_cvar_string("ip", ip, charsmax(ip));
			dllfunc(DLLFunc_ClientConnect, bot, botName, ip, ptr);
			dllfunc(DLLFunc_ClientPutInServer, bot);
			set_pev(bot, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT);
			set_bit(g_bit_is_bot, bot);

			entity_set_float(bot, EV_FL_takedamage, 1.0);
			entity_set_float(bot, EV_FL_health, 100.0);

			entity_set_byte(bot, EV_BYTE_controller1, 125);
			entity_set_byte(bot, EV_BYTE_controller2, 125);
			entity_set_byte(bot, EV_BYTE_controller3, 125);
			entity_set_byte(bot, EV_BYTE_controller4, 125);

			new Float:maxs[3] = {16.0, 16.0, 36.0};
			new Float:mins[3] = {-16.0, -16.0, -36.0};
			entity_set_size(bot, mins, maxs);

			// Copy the state of the player who spawned the bot
			new Float:botOrigin[3], Float:botAngles[3];
			pev(id, pev_origin, botOrigin);
			pev(id, pev_angles, botAngles);
			set_pev(bot, pev_origin, botOrigin);
			set_pev(bot, pev_angles, botAngles);
			set_pev(bot, pev_v_angle, botAngles);

			new ownerModel[32];
			hl_get_user_model(id, ownerModel, sizeof(ownerModel));
			set_user_info(bot, "model", ownerModel);

			engfunc(EngFunc_RunPlayerMove, bot, botAngles, 0.0, 0.0, 0.0, pev(id, pev_button), 0, 4);
		}
		else
			client_print(id, print_chat, "[%s] Sorry, couldn't create the bot", PLUGIN_TAG);
	}
	else
		client_print(id, print_chat, "[%s] Sorry, won't spawn the bot since there are only 4 slots left for players", PLUGIN_TAG);

    //return PLUGIN_HANDLED;
}

ConfigureBot(id) {
	set_user_info(id, "model",				"robo");
	set_user_info(id, "rate",				"3500.000000");
	set_user_info(id, "cl_updaterate",		"30");
	set_user_info(id, "cl_lw",				"0");
	set_user_info(id, "cl_lc",				"0");
	set_user_info(id, "tracker",			"0");
	set_user_info(id, "cl_dlmax",			"128");
	set_user_info(id, "lefthand",			"1");
	set_user_info(id, "friends",			"0");
	set_user_info(id, "dm",					"0");
	set_user_info(id, "ah",					"1");

	//set_user_info(id, "*bot",				"1");
	set_user_info(id, "_cl_autowepswitch",	"1");
	set_user_info(id, "_vgui_menu",			"0");		//disable vgui so we dont have to
	set_user_info(id, "_vgui_menus",		"0");		//register both 2 types of menus :)
}

// Using this for bots instead of the player prethink because here I can tell the engine
// when I want the next frame to be displayed, because prethink for bots runs 1000 times per second
// (nextthink doesn't work for player prethink), and this one is adaptable to the FPS the run was recorded on
public npc_think(id)
{
	// Get the bot attached to this entity
	new bot = GetEntitysBot(id);
	new owner = g_BotOwner[bot];
	/*
	new bool:isCustomFrame = false;
	for (new i = 0; i < g_ReplayFpsMultiplier[owner] - 1; i++)
	{
		// FIXME this is throwing index out of bounds error when the fps multiplier is modified
		if (!isCustomFrame && g_isCustomFpsReplay[id] && g_ArtificialFrames[owner][id] > g_LastFrameTime[owner])
			isCustomFrame = true;
	}
	*/

	if (g_ReplayFrames[owner] && g_ReplayFramesIdx[owner] < ArraySize(g_ReplayFrames[owner]))
	{
		static replayPrev[REPLAY], replay[REPLAY], replayNext[REPLAY], replay2Next[REPLAY];

		if (g_Unfreeze[bot] > 3)
		{
			if (get_pcvar_num(pcvar_kz_spec_unfreeze))
				UnfreezeSpecCam(bot);
			g_Unfreeze[bot] = 0;
		}

		// Get previous frame
		if (g_ReplayFramesIdx[owner] - 1 >= 0)
			ArrayGetArray(g_ReplayFrames[owner], g_ReplayFramesIdx[owner] - 1, replayPrev);

		// Get current frame
		ArrayGetArray(g_ReplayFrames[owner], g_ReplayFramesIdx[owner], replay); // get current frame

		// Get next frame
		if (g_ReplayFramesIdx[owner] + 1 < ArraySize(g_ReplayFrames[owner]))
			ArrayGetArray(g_ReplayFrames[owner], g_ReplayFramesIdx[owner] + 1, replayNext);
		else
			replayNext[RP_TIME] = replay[RP_TIME] + 0.004;

		// Get next next frame
		if (g_ReplayFramesIdx[owner] + 2 < ArraySize(g_ReplayFrames[owner]))
			ArrayGetArray(g_ReplayFrames[owner], g_ReplayFramesIdx[owner] + 2, replay2Next);
		else
			replay2Next[RP_TIME] = replay[RP_TIME] + 0.004;

		new Float:botVelocity[3], Float:frameDuration = replayNext[RP_TIME] - replay[RP_TIME];
		pev(bot, pev_velocity, botVelocity);
		if (frameDuration <= 0)
		{
			if (replay2Next[RP_TIME])
				frameDuration = (replay2Next[RP_TIME] - replay[RP_TIME]) / 2;
			else
				frameDuration = 0.002; // duration of a frame at 125 fps, 'cos the most usual thing is to use 250 fps, so at 0.004 there will already be another frame to replay
		}

		new Float:botPrevHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));
		new Float:botPrevPos[3];
		xs_vec_copy(replayPrev[RP_ORIGIN], botPrevPos);

		// The correct thing would be to take into account the previous frame, but it doesn't matter most of the time
		if (frameDuration)
		{
			botVelocity[0] = (replayNext[RP_ORIGIN][0] - replay[RP_ORIGIN][0]) / frameDuration;
			botVelocity[1] = (replayNext[RP_ORIGIN][1] - replay[RP_ORIGIN][1]) / frameDuration;
			// z velocity is already calculated by the engine because of gravity,
			// but it would have to be calculated if surfing, but may not be easy
			// as a too high z velocity when not surfing will deal fall damage
		}

		set_pev(id, pev_origin, replay[RP_ORIGIN]);
		set_pev(id, pev_angles, replay[RP_ANGLES]);
		set_pev(id, pev_v_angle, replay[RP_ANGLES]);
		set_pev(id, pev_button, replay[RP_BUTTONS]);
		set_pev(id, pev_velocity, botVelocity);
		set_pev(bot, pev_origin, replay[RP_ORIGIN]);
		set_pev(bot, pev_angles, replay[RP_ANGLES]);
		set_pev(bot, pev_v_angle, replay[RP_ANGLES]);
		set_pev(bot, pev_button, replay[RP_BUTTONS]);
		set_pev(bot, pev_velocity, botVelocity);

		entity_set_float(id, EV_FL_nextthink, get_gametime() + replayNext[RP_TIME] - replay[RP_TIME]);

		new Float:botCurrHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));
		new Float:botCurrPos[3];
		xs_vec_copy(replay[RP_ORIGIN], botCurrPos);

		new Float:demoTime = replay[RP_TIME] - g_ReplayStartGameTime[owner];

		if ((botPrevHSpeed > 0.0 && botCurrHSpeed == 0.0 && get_distance_f(botCurrPos, botPrevPos) > 50.0)
			|| get_distance_f(botCurrPos, botPrevPos) > 100.0) // Has teleported?
		{
			g_Unfreeze[bot]++;
		}
		else if (g_Unfreeze[bot])
			g_Unfreeze[bot]++;

		botCurrHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));

		if (g_ConsolePrintNextFrames[owner] > 0)
		{
			console_print(owner, "[t=%d %.5f] dp: %.2f, px: %.2f, py: %.2f, pz: %.2f, s: %.2f, btns: %d", g_ReplayFramesIdx[owner], demoTime, get_distance_f(botCurrPos, botPrevPos), replay[RP_ORIGIN][0], replay[RP_ORIGIN][1], replay[RP_ORIGIN][2], botCurrHSpeed, replay[RP_BUTTONS]);
			g_ConsolePrintNextFrames[owner]--;
		}

		g_LastFrameTime[owner] = replay[RP_TIME] + frameDuration;
		engfunc(EngFunc_RunPlayerMove, bot, replay[RP_ANGLES], botVelocity[0], botVelocity[1], botVelocity[2], replay[RP_BUTTONS], 0, 4);
		g_ReplayFramesIdx[owner]++;
	}
	else
	{
		set_task(0.5, "KickReplayBot", bot + TASKID_KICK_REPLAYBOT);
		FinishReplay(owner);
	}
}

public UnfreezeSpecCam(bot)
{
	for (new spec = 1; spec <= g_MaxPlayers; spec++)
	{
		if (is_user_connected(spec))
		{
			// Iterate from 1 to g_MaxPlayers, if it doesn't exist or is not playing don't do anything
			if (is_user_alive(spec))
				continue;
			
			if (pev(spec, pev_iuser2) == bot)
			{
				// This spectator is watching the frozen bot (not really, what is frozen is the cam, the bot is moving)
				new botName[33], specName[33];
				GetColorlessName(bot, botName, charsmax(botName));
				GetColorlessName(spec, specName, charsmax(specName));

				new Float:origin[3], Float:botOrigin[3];
				new Float:angles[3], Float:botAngles[3];
				pev(spec, pev_origin, origin);
				pev(bot, pev_origin, botOrigin);
				pev(spec, pev_v_angle, angles);
				pev(bot, pev_v_angle, botAngles);
				//console_print(spec, "Spec %s angles: (%.2f, %.2f, %.2f)", specName, angles[0], angles[1], angles[2]);
				//console_print(spec, "Bot %s angles: (%.2f, %.2f, %.2f)", botName, botAngles[0], botAngles[1], botAngles[2]);

				//console_print(spec, "Changing spec %s's origin and angles to the ones of bot %s", specName, botName);
				set_pev(spec, pev_origin, botOrigin);
				set_pev(spec, pev_angles, botAngles);
				set_pev(spec, pev_v_angle, botAngles);

				//console_print(spec, "Executing +attack;wait;-attack on spectator %s watching bot %s)", specName, botName);
				//client_cmd(spec, "+attack; wait; -attack;");
				//client_cmd(spec, "+attack2; wait; -attack2;");

				new payLoad[2];
				payLoad[0] = spec;
				payLoad[1] = bot;
				new taskId = spec * 32;
				set_task(0.03, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId    , payLoad, sizeof(payLoad));
				set_task(0.12, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 1, payLoad, sizeof(payLoad));
				//set_task(0.20, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 2, payLoad, sizeof(payLoad));
				//set_task(0.24 ,"RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 3, payLoad, sizeof(payLoad));
				//set_task(0.32, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 4, payLoad, sizeof(payLoad));
			}
		}
	}
}

public RestoreSpecCam(payLoad[], taskId)
{
	new spec = payLoad[0];
	new bot = payLoad[1];
	// Checking if the spectator continues spectating, otherwise if unspecs during
	// the time this task is executed it will be teleported to the runner position
	if (pev(spec, pev_iuser1))
	{
		// This spectator is watching the frozen bot (not really, what is frozen is the cam, the bot is moving)
		new botName[33], specName[33];
		GetColorlessName(bot, botName, charsmax(botName));
		GetColorlessName(spec, specName, charsmax(specName));
		//console_print(spec, "Executing +attack2;wait;-attack2 on spectator %s watching bot %s)", specName, botName);
		//client_cmd(spec, "+attack2; wait; -attack2");
		//set_pev(spec, pev_iuser2, bot);

		new Float:origin[3], Float:botOrigin[3];
		new Float:angles[3], Float:botAngles[3];
		pev(spec, pev_origin, origin);
		pev(bot, pev_origin, botOrigin);
		pev(spec, pev_v_angle, angles);
		pev(bot, pev_v_angle, botAngles);
		//console_print(spec, "Spec %s o(%.2f, %.2f, %.2f), a(%.2f, %.2f, %.2f)", specName, origin[0], origin[1], origin[2], angles[0], angles[1], angles[2]);
		//console_print(spec, "Bot %s  o(%.2f, %.2f, %.2f), a(%.2f, %.2f, %.2f)", botName, botOrigin[0], botOrigin[1], botOrigin[2], botAngles[0], botAngles[1], botAngles[2]);

		//client_cmd(spec, "+attack; wait; -attack;");
		//client_cmd(spec, "+attack2; wait; -attack2;");
		set_pev(spec, pev_iuser2, bot);

		//console_print(spec, "Changing spec %s's origin and angles to the ones of bot %s", specName, botName);
		set_pev(spec, pev_origin, botOrigin);
		set_pev(spec, pev_angles, botAngles);
		set_pev(spec, pev_v_angle, botAngles);
		pev(spec, pev_origin, origin);
		pev(spec, pev_v_angle, angles);
		//console_print(spec, "Spec %s o(%.2f, %.2f, %.2f), a(%.2f, %.2f, %.2f)", specName, origin[0], origin[1], origin[2], angles[0], angles[1], angles[2]);
	}
}

public CmdPrintNextFrames(id)
{
	new num = GetNumberArg();
	console_print(1, "CmdPrintNextFrames :: num = %d", num);
	g_ConsolePrintNextFrames[id] = num;
}

public CmdSpectatingName(id)
{
	new runner = pev(id, pev_iuser2);
	if (runner)
	{
		new runnerName[33];
		GetColorlessName(runner, runnerName, charsmax(runnerName));
		client_print(id, print_chat, "You're spectating %s", runnerName);
	}
}

// Pass the player id that spawned the replay bot
FinishReplay(id)
{
	g_ReplayFramesIdx[id] = 0;
	ArrayClear(g_ReplayFrames[id]);

	new bot = GetOwnersBot(id);
	new ent = g_BotEntity[bot];
	//console_print(1, "removing entity %d", ent);
	remove_entity(ent);
	g_BotOwner[bot] = 0;
	//console_print(1, "FinishReplay :: setting g_BotOwner[bot] = 0");
	g_BotEntity[bot] = 0;

	set_pev(bot, pev_flags, pev(bot, pev_flags) & ~FL_FROZEN);
	remove_task(bot + TASKID_ICON);
}

public KickReplayBot(id)
{
	new bot = id - TASKID_KICK_REPLAYBOT;
	server_cmd("kick #%d \"Replay finished.\"", get_user_userid(bot));
	g_ReplayNum--;
}

CmdShowkeys(id)
{
	if (!get_pcvar_num(pcvar_kz_show_keys))
	{
		ShowMessage(id, "Keys display modification is disabled by server");
		return;
	}

	ClearSyncHud(id, g_SyncHudKeys);

	if (g_ShowKeys[id] < 2)
		ShowMessage(id, "Keys display: %s", g_ShowKeys[id]++ < 1 ? "on in spectator mode" : "on");
	else
	{
		g_ShowKeys[id] = 0;
		ShowMessage(id, "Keys display: off");
	}
}

CmdMenuShowStartMsg(id)
{
	if (!get_pcvar_num(pcvar_kz_show_start_msg))
	{
		ShowMessage(id, "Start message display toggling is disabled by server");
		return;
	}

	client_print(id, print_center, "");
	ClearSyncHud(id, g_SyncHudTimer);
	ClearSyncHud(id, g_SyncHudKeys);
	ClearSyncHud(id, g_SyncHudShowStartMsg);

	g_ShowStartMsg[id] = !g_ShowStartMsg[id];
	ShowMessage(id, "Start message display: %s", g_ShowStartMsg[id] ? "on" : "off");
	client_cmd(id, "kz_start_message %d", g_ShowStartMsg[id]);
}

CmdMenuTimeDecimals(id)
{
	if (!get_pcvar_num(pcvar_kz_time_decimals))
	{
		ShowMessage(id, "Modifying the number of decimals to display is disabled by server");
		return;
	}

	client_print(id, print_center, "");

	if (g_TimeDecimals[id] < 6)
		g_TimeDecimals[id]++;
	else
		g_TimeDecimals[id] = 1;
	ShowMessage(id, "Decimals to show in times: %d", g_TimeDecimals[id]);
	client_cmd(id, "kz_time_decimals %d", g_TimeDecimals[id]);
}

CmdRespawn(id)
{
	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		ShowMessage(id, "You must be alive to use this command");
		return;
	}

	if (g_bCanTakeAdvantageOfRespawn)
		ResetPlayer(id, false, true);
	else
	{
		for (new i = 0; i < sizeof(g_DeathmatchMaps); i++)
			if (equal(g_Map, g_DeathmatchMaps[i]) && get_bit(g_baIsClimbing, id))
				ResetPlayer(id, false, true);
	}

	g_InForcedRespawn = true;	// this blocks teleporting to CP after respawn

	strip_user_weapons(id);
	ExecuteHamB(Ham_Spawn, id);

	ResumeTimer(id);
}

CmdHelp(id)
{
	new motd[1536], title[32], len;

	len = formatex(motd[len], charsmax(motd) - len,
		"Say commands:\n\
		/kz - show main menu\n\
		/cp - create control point\n\
		/tp - teleport to last control point\n\
		/practicecp - create practice control point\n\
		/practicetp - teleport to last practice control point\n\
		/top - show Top climbers\n\
		/pure /pro /nub <#>-<#> - show specific tops and records, e.g. /pro 20-50\n\
		/unstuck - teleport to previous control point\n\
		/pause - pause timer and freeze player\n\
		/reset - reset timer and clear checkpoints\n\
		/speed - toggle showing your horizontal speed\n");

	if (is_plugin_loaded("Q::Jumpstats"))
	{
		len += formatex(motd[len], charsmax(motd) - len,
			"/lj - show LJ top\n\
			/ljstats - toggle showing different jump distances\n\
			/prestrafe - toggle showing prestrafe speed\n\
			/ljsounds - toggle announcer sounds\n");
	}
	if (is_plugin_loaded("Enhanced Map Searching"))
	{
		len += formatex(motd[len], charsmax(motd) - len,
			"/rtv - vote a random map (agmap command)\n");
	}

	len += formatex(motd[len], charsmax(motd) - len,
		"/start - go to start button\n\
		/respawn - go to spawn point\n\
		/spec - go to spectate mode or exit from it\n\
		/speclist - show players watching you\n\
		/ss - set custom start position\n\
		/cs - clear custom start position\n\
		/invis - make other players invisible to you\n\
		/winvis - make most liquids invisible\n\
		/timer - switch between different timer display modes\n\
		/showkeys - display pressed movement keys in HUD\n\
		/startmsg - display timer start message in HUD\n\
		/dec <1-6> - number of decimals in times\n\
		/nv <0-2> - nightvision mode, 0=off, 1=flashlight, 2=global\n\
		/slopefix - toggle slopebug/surfbug fix, if you get stuck in little slopes disable it\n\
		/speedcap <#> - set your horizontal speed limit\n\
		/kzhelp - this motd\n");

	formatex(motd[len], charsmax(motd) - len,
		"\n%s %s by %s\n\
		Visit aghl.ru or sourceruns.org for news\n\n", PLUGIN, VERSION, AUTHOR);

	formatex(title, charsmax(title), "%s Help", PLUGIN);
	show_motd(id, motd, title);
	return PLUGIN_HANDLED;
}

public CmdSayHandler(id, level, cid)
{
	static args[64];
	read_args(args, charsmax(args));
	remove_quotes(args); trim(args);

	if (args[0] != '/' && args[0] != '.' && args[0] != '!')
		return PLUGIN_CONTINUE;

	if (equali(args[1], "cp"))
		CmdCp(id);

	else if (equali(args[1], "tp"))
		CmdTp(id);

	else if (equali(args[1], "stuck") || equali(args[1], "unstuck"))
		CmdStuck(id);

	else if (equali(args[1], "practicecp"))
		CmdPracticeCp(id);

	else if (equali(args[1], "practicetp"))
		CmdPracticeTp(id);

	else if (equali(args[1], "practiceprev"))
		CmdPracticePrev(id);

	else if (equali(args[1], "pause"))
		CmdPause(id);

	else if (equali(args[1], "reset"))
		CmdReset(id);

	else if (equali(args[1], "start"))
		CmdStart(id);

	else if (equali(args[1], "timer"))
		CmdTimer(id);

	else if (equali(args[1], "speclist"))
		CmdSpecList(id);

	else if (equali(args[1], "spectate") || equali(args[1], "spec"))
		CmdSpec(id);

	else if (equali(args[1], "checkspec"))
		CmdSpectatingName(id);

	else if (equali(args[1], "setstart") || equali(args[1], "ss"))
		CmdSetCustomStartHandler(id);

	else if (equali(args[1], "clearstart") || equali(args[1], "cs"))
		CmdClearCustomStartHandler(id);

	else if (equali(args[1], "invis"))
		CmdInvis(id);

	else if (equali(args[1], "winvis") || equali(args[1], "waterinvis") || equali(args[1], "liquidinvis"))
		CmdWaterInvis(id);

	else if (equali(args[1], "showkeys") || equali(args[1], "keys"))
		CmdShowkeys(id);

	else if (equali(args[1], "startmsg"))
		CmdMenuShowStartMsg(id);

	else if (equali(args[1], "spawn") || equali(args[1], "respawn"))
		CmdRespawn(id);

	else if (equali(args[1], "kzmenu") || equali(args[1], "menu") || equali(args[1], "kz"))
		DisplayKzMenu(id, 0);

	else if (equali(args[1], "kzhelp") || equali(args[1], "help") || equali(args[1], "h"))
		CmdHelp(id);

	else if (equali(args[1], "slopefix"))
		CmdSlopefix(id);

	else if (equali(args[1], "speed"))
		CmdSpeed(id);

	else if (equali(args[1], "ready"))
		CmdReady(id);

	else if (equali(args[1], "bot"))
	{
		if (is_user_admin(id))
			SpawnDummyBot(id);
	}

	// The ones below use containi() because they can be passed parameters
	else if (containi(args[1], "printframes") == 0)
		CmdPrintNextFrames(id);

	else if (containi(args[1], "replaypure") == 0 || containi(args[1], "replaybot") == 0 || containi(args[1], "rp") == 0)
		CmdReplayPure(id);

	else if (containi(args[1], "replaypro") == 0)
		CmdReplayPro(id);

	else if (containi(args[1], "replaynub") == 0 || containi(args[1], "replaynoob") == 0)
		CmdReplayNoob(id);
/*
	else if (containi(args[1], "replaysmooth") == 0)
		CmdReplaySmoothen(id);
*/
	else if (containi(args[1], "speedcap") == 0)
		CmdSpeedcap(id);

	else if (containi(args[1], "dec") == 0)
		CmdTimeDecimals(id);

	else if (containi(args[1], "nv") == 0 || containi(args[1], "nightvision") == 0)
		CmdNightvision(id);

	else if (containi(args[1], "pure") == 0)
		ShowTopClimbers(id, PURE);

	else if (containi(args[1], "pro") == 0)
		ShowTopClimbers(id, PRO);

	else if (containi(args[1], "nub") == 0 || containi(args[1], "noob") == 0)
		ShowTopClimbers(id, NOOB);

	else if (containi(args[1], "top") == 0)
		DisplayKzMenu(id, 5);
/*
	else if (containi(args[1], "pov") == 0)
	{
		if (is_user_admin(id) && pev(id, pev_iuser1))
			SetPOV(id);
	}
*/
	else
		return PLUGIN_CONTINUE;

	return PLUGIN_HANDLED;
}

public CheatCmdHandler(id)
{
	new cmd[32];
	read_argv(0, cmd, charsmax(cmd));
	new bit;
	switch (cmd[1])
	{
	case 'h', 'H': bit = 1 << 0;		// +|-hook
	case 'r', 'R': bit = 1 << 1;		// +|-rope
	default: return PLUGIN_CONTINUE;
	}

	new const hookBits = (1 << 0) | (1 << 1);	// hook&rope

	if (cmd[0] == '+')
		g_CheatCommandsGuard[id] |= bit;
	else
	{
		// Skip timer reset if hook isn't used, the case when console opened/closed with bind to command (it sends -command)
		if (!(g_CheatCommandsGuard[id] & hookBits))
			return PLUGIN_CONTINUE;
		g_CheatCommandsGuard[id] &= ~bit;
	}

	if (get_bit(g_baIsClimbing, id))
		ResetPlayer(id, false, true);

	new ret;
	ExecuteForward(mfwd_hlkz_cheating, ret, id);

	return PLUGIN_CONTINUE;
}

// refactor to get this into the CheatCmdHandler function,
// it isn't already inside it 'cos wasn't working properly at first try
public TASCmdHandler(id)
{
	new cmd[32];
	read_argv(0, cmd, charsmax(cmd));

	if (cmd[0] == '+')
		g_CheatCommandsGuard[id] |= (1 << 2);
	else
	{
		// Skip timer reset if hook isn't used, the case when console opened/closed with bind to command (it sends -command)
		if (!(g_CheatCommandsGuard[id] & (1 << 2)))
			return PLUGIN_CONTINUE;
		g_CheatCommandsGuard[id] &= ~(1 << 2);
	}

	if (get_bit(g_baIsClimbing, id))
		ResetPlayer(id, false, true);

	if (cmd[0] == '+')
	{
		if (!g_PlayerTASed[id] || (get_gametime() - g_PlayerTASed[id]) > 10.0)
		{
			new name[32], uniqueid[32];
			GetColorlessName(id, name, charsmax(name));
			get_user_authid(id, uniqueid, charsmax(uniqueid));
			log_amx("%s <%s> has used a TAS command! Command: %s", name, uniqueid, cmd);
			g_PlayerTASed[id] = get_gametime();
		}
	}

	new ret;
	ExecuteForward(mfwd_hlkz_cheating, ret, id);

	return PLUGIN_CONTINUE;
}


//*******************************************************
//*                                                     *
//* Checkpoint functions                                *
//*                                                     *
//*******************************************************

bool:CanCreateCp(id, bool:showMessages = true, bool:practiceMode = false)
{
	if (!get_pcvar_num(pcvar_kz_checkpoints))
	{
		if (showMessages) ShowMessage(id, "Checkpoint commands are disabled");
		return false;
	}

	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		if (showMessages) ShowMessage(id, "You must be alive to use this command");
		return false;
	}
	if (get_bit(g_baIsPaused, id))
	{
		if (showMessages) ShowMessage(id, "You can't create a checkpoint while in pause");
		return false;
	}

	if (!practiceMode)
	{
		if (!IsValidPlaceForCp(id))
		{
			if (showMessages) ShowMessage(id, "You must be on the ground");
			return false;
		}
	}

	return true;
}

bool:CanTeleport(id, cp, bool:showMessages = true)
{
	if (cp >= CP_TYPES)
		return false;

	if (cp != CP_TYPE_START && cp != CP_TYPE_CUSTOM_START && cp != CP_TYPE_PRACTICE && !get_pcvar_num(pcvar_kz_checkpoints))
	{
		if (showMessages) ShowMessage(id, "Checkpoint commands are disabled");
		return false;
	}
	if (cp == CP_TYPE_OLD && !get_pcvar_num(pcvar_kz_stuck))
	{
		if (showMessages) ShowMessage(id, "Stuck/Unstuck commands are disabled");
		return false;
	}
	if (cp == CP_TYPE_PRACTICE_OLD && !get_pcvar_num(pcvar_kz_stuck))
	{
		if (showMessages) ShowMessage(id, "Teleporting to previous checkpoints is disabled")
		return false; 
	}
	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		if (showMessages) ShowMessage(id, "You must be alive to use this command");
		return false;
	}
	if (get_bit(g_baIsPaused, id))
	{
		if (showMessages) ShowMessage(id, "You can't teleport while in pause");
		return false;
	}

	if (!g_ControlPoints[id][cp][CP_VALID])
	{
		if (showMessages)
			switch (cp)
			{
			case CP_TYPE_CURRENT: ShowMessage(id, "You don't have checkpoint created");
			case CP_TYPE_OLD: ShowMessage(id, "You don't have previous checkpoint created");
			case CP_TYPE_CUSTOM_START: ShowMessage(id, "You don't have a custom start point set");
			case CP_TYPE_START: ShowMessage(id, "You don't have start checkpoint created");
			case CP_TYPE_DEFAULT_START: ShowMessage(id, "The map doesn't have a default start checkpoint set");
			case CP_TYPE_PRACTICE: ShowMessage(id, "You don't have a practice checkpoint created");
			case CP_TYPE_PRACTICE_OLD: ShowMessage(id, "You don't have a previous practice checkpoint created")
			}
		return false;
	}

	return true;
}

CreateCp(id, cp, bool:specModeStepTwo = false)
{
	if (cp >= CP_TYPES)
		return;

	switch (cp)
	{
	case CP_TYPE_SPEC:
		if (specModeStepTwo)
		{
			g_CpCounters[id][COUNTER_SP]++;
			ShowMessage(id, "Spectate Checkpoint #%d created", g_CpCounters[id][COUNTER_SP]);
			return;
		}
	case CP_TYPE_CURRENT:
		{
			g_CpCounters[id][COUNTER_CP]++;
			ShowMessage(id, "Checkpoint #%d created", g_CpCounters[id][COUNTER_CP]);

			// Backup current checkpoint
			g_ControlPoints[id][CP_TYPE_OLD] = g_ControlPoints[id][CP_TYPE_CURRENT];
		}
	case CP_TYPE_PRACTICE:
		{
			g_CpCounters[id][COUNTER_PRACTICE_CP]++;
			ShowMessage(id, "Practice checkpoint #%d created", g_CpCounters[id][COUNTER_PRACTICE_CP]);

			// Backup current checkpoint
			g_ControlPoints[id][CP_TYPE_PRACTICE_OLD] = g_ControlPoints[id][CP_TYPE_PRACTICE];
		}
	}

	// Store current player state and position
	g_ControlPoints[id][cp][CP_VALID] = true;
	g_ControlPoints[id][cp][CP_FLAGS] = pev(id, pev_flags);
	pev(id, pev_origin, g_ControlPoints[id][cp][CP_ORIGIN]);
	pev(id, pev_v_angle, g_ControlPoints[id][cp][CP_ANGLES]);
	pev(id, pev_view_ofs, g_ControlPoints[id][cp][CP_VIEWOFS]);
	pev(id, pev_velocity, g_ControlPoints[id][cp][CP_VELOCITY]);
	pev(id, pev_health, g_ControlPoints[id][cp][CP_HEALTH]);
	pev(id, pev_armorvalue, g_ControlPoints[id][cp][CP_ARMOR]);
	g_ControlPoints[id][cp][CP_LONGJUMP] = hl_get_user_longjump(id);
}

Teleport(id, cp)
{
	if (cp >= CP_TYPES)
		return;

	// Return if checkpoint doesn't have a valid data
	if (!g_ControlPoints[id][cp][CP_VALID])
		return;

	g_RampFrameCounter[id] = 0;

	// Restore player state and position
	if (g_ControlPoints[id][cp][CP_FLAGS] & FL_DUCKING)
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_DUCKING);
	else
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_DUCKING);
	
	if  (cp == CP_TYPE_PRACTICE || cp == CP_TYPE_PRACTICE_OLD)
	{
		set_pev(id, pev_origin, g_ControlPoints[id][cp][CP_ORIGIN]);
		set_pev(id, pev_angles, g_ControlPoints[id][cp][CP_ANGLES]);
		set_pev(id, pev_v_angle, g_ControlPoints[id][cp][CP_ANGLES]);
		set_pev(id, pev_view_ofs, g_ControlPoints[id][cp][CP_VIEWOFS]);
		set_pev(id, pev_velocity, g_ControlPoints[id][cp][CP_VELOCITY]);
		set_pev(id, pev_fixangle, true);
		set_pev(id, pev_health, g_ControlPoints[id][cp][CP_HEALTH]);
		set_pev(id, pev_armorvalue, g_ControlPoints[id][cp][CP_ARMOR]);
		hl_set_user_longjump(id, g_ControlPoints[id][cp][CP_LONGJUMP]);

		g_CpCounters[id][COUNTER_PRACTICE_TP]++;
		ShowMessage(id, "Go practice checkpoint #%d", g_CpCounters[id][COUNTER_PRACTICE_TP]);
	}
	else 
	{ 
		set_pev(id, pev_origin, g_ControlPoints[id][cp][CP_ORIGIN]);
		set_pev(id, pev_angles, g_ControlPoints[id][cp][CP_ANGLES]);
		set_pev(id, pev_v_angle, g_ControlPoints[id][cp][CP_ANGLES]);
		set_pev(id, pev_view_ofs, g_ControlPoints[id][cp][CP_VIEWOFS]);
		set_pev(id, pev_velocity, /*g_ControlPoints[id][cp][CP_VELOCITY]*/ Float:{ 0.0, 0.0, 0.0 });
		set_pev(id, pev_fixangle, true);
		set_pev(id, pev_health, g_ControlPoints[id][cp][CP_HEALTH]);
		set_pev(id, pev_armorvalue, g_ControlPoints[id][cp][CP_ARMOR]);
		hl_set_user_longjump(id, g_ControlPoints[id][cp][CP_LONGJUMP]);
	}
	ExecuteHamB(Ham_AddPoints, id, -1, true);

	// Inform
	if (cp == CP_TYPE_SPEC)
	{
		ShowMessage(id, "Teleported to the spectate checkpoint");
	}
	else if (cp == CP_TYPE_START)
	{
		ShowMessage(id, "Teleported to the start position");
	}
	else if (cp == CP_TYPE_CUSTOM_START)
	{
		ShowMessage(id, "Teleported to the custom start position");
	}
	else if (cp == CP_TYPE_CURRENT || cp == CP_TYPE_OLD)
	{
		// Increment teleport times counter
		g_CpCounters[id][COUNTER_TP]++;
		ShowMessage(id, "Go checkpoint #%d", g_CpCounters[id][COUNTER_TP]);
	}
	else if (cp == CP_TYPE_DEFAULT_START)
	{
		ResetPlayer(id, false, true);
		ShowMessage(id, "Teleported to the default start position");
	}
}

TeleportAfterRespawn(id)
{
	// Check if we respawn after spectate
	if (g_ControlPoints[id][CP_TYPE_SPEC][CP_VALID])
	{
		// Teleport to spectator checkpoint
		Teleport(id, CP_TYPE_SPEC);
		g_ControlPoints[id][CP_TYPE_SPEC][CP_VALID] = false;
	}
	else
	{
		// g_bMatchRunning isn't updated by this point yet.
		if (get_pcvar_num(pcvar_sv_ag_match_running) == 1)
		{
			if (CanTeleport(id, CP_TYPE_START, false))
				Teleport(id, CP_TYPE_START);
			else if (CanTeleport(id, CP_TYPE_DEFAULT_START, false))
				Teleport(id, CP_TYPE_DEFAULT_START);

			return;
		}

		// Teleport player to last checkpoint
		if (CanTeleport(id, CP_TYPE_CURRENT, false))
			Teleport(id, CP_TYPE_CURRENT);
		else if (CanTeleport(id, CP_TYPE_START, false))
			Teleport(id, CP_TYPE_START);
		else if (CanTeleport(id, CP_TYPE_DEFAULT_START, false))
			Teleport(id, CP_TYPE_DEFAULT_START);
	}
}

bool:IsValidPlaceForCp(id)
{
	// TODO: check velocity, not ON_GROUND, cos there can be no sense in teleporting to some moving object...
	// TODO: trace down to see if there is a ground under feet (it can be point sized, be warned)
	return (pev(id, pev_flags) & FL_ONGROUND_ALL) != 0;
}

bool:IsUserOnGround(id)
{
	return !!(pev(id, pev_flags) & FL_ONGROUND_ALL);
}

Float:GetPlayerSpeed(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);
	return floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0));
}


//*******************************************************
//*                                                     *
//* Spectate mode handling                              *
//*                                                     *
//*******************************************************

bool:CanSpectate(id, bool:showMessages = true)
{
	if (pcvar_allow_spectators && !get_pcvar_num(pcvar_allow_spectators))
	{
		if (showMessages) ShowMessage(id, "Spectator mode is disabled");
		return false;
	}

	if (IsAlive(id) && !IsValidPlaceForCp(id))
	{
		if (showMessages) ShowMessage(id, "You must be on the ground to enter spectator mode");
		return false;
	}
	if (g_bMatchRunning)
	{
		if (showMessages) ShowMessage(id, "Match is running, spectate is disabled");
		return false;
	}

	return true;
}

public CmdSpectateHandler(id)
{
	//if (IsHltv(id) || IsBot(id))
	if (IsHltv(id))
		return PLUGIN_CONTINUE;

	return ClientCommandSpectatePre(id);
}

public Fw_FmClientCommandPost(id)
{
	//if (IsHltv(id) || IsBot(id))
	if (IsHltv(id))
		return FMRES_IGNORED;

	new cmd[32];
	read_argv(0, cmd, charsmax(cmd));

	if (equal(cmd, "spectate"))
	{
		return ClientCommandSpectatePost(id);
	}

	return FMRES_IGNORED;
}

ClientCommandSpectatePre(id)
{
	g_SpectatePreSpecMode = pev(id, pev_iuser1);

	if (g_SpectatePreSpecMode == OBS_NONE)
	{
		// Trying to enter spectate mode
		if (!CanSpectate(id))
			return PLUGIN_HANDLED;

		// Store player position now to create CP later and to move him to this point after switching to spectate
		CreateCp(id, CP_TYPE_SPEC, false);
		// Invalidate CP if dead
		if (!IsAlive(id))
			g_ControlPoints[id][CP_TYPE_SPEC][CP_VALID] = false;
	}

	return PLUGIN_CONTINUE;
}

ClientCommandSpectatePost(id)
{
	new bool:bNotInSpec = pev(id, pev_iuser1) == OBS_NONE;

	if (g_SpectatePreSpecMode == OBS_NONE)
	{
		if (bNotInSpec)
		{
			// Invalidate spectate checkpoint cos we aren't moved to spectate mode
			g_ControlPoints[id][CP_TYPE_SPEC][CP_VALID] = false;
		}
		else
		{
			clr_bit(g_bit_invis, id);
			// Entered spectate mode
			// Remove frozen state and pause sprite if any, but maintain timer stopped
			if (get_bit(g_baIsPaused, id))
			{
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
				remove_task(id + TASKID_ICON);
			}

			// Move to the point were player was (adjust for view offset)
			g_ControlPoints[id][CP_TYPE_SPEC][CP_ORIGIN][2] += g_ControlPoints[id][CP_TYPE_SPEC][CP_VIEWOFS][2];
			set_pev(id, pev_iuser1, OBS_ROAMING);
			set_pev(id, pev_origin, g_ControlPoints[id][CP_TYPE_SPEC][CP_ORIGIN]);
			set_pev(id, pev_angles, g_ControlPoints[id][CP_TYPE_SPEC][CP_ANGLES]);
			set_pev(id, pev_v_angle, g_ControlPoints[id][CP_TYPE_SPEC][CP_ANGLES]);
			set_pev(id, pev_fixangle, true);
			g_ControlPoints[id][CP_TYPE_SPEC][CP_ORIGIN][2] -= g_ControlPoints[id][CP_TYPE_SPEC][CP_VIEWOFS][2];

			// Delayed notify about spectate checkpoint and increment the counter, cos this is the only place where we sure we got in spectate
			if (g_ControlPoints[id][CP_TYPE_SPEC][CP_VALID])
				CreateCp(id, CP_TYPE_SPEC, true);

			// Update hud soon
			set_pev(g_TaskEnt, pev_nextthink, get_gametime() + 0.01);
			ClearSyncHud(id, g_SyncHudKeys);

			// Pause timer, but don't froze and no pause sprite
			PauseTimer(id, true);
		}
	}
	else if (bNotInSpec)
	{
		// Returned from spectator mode, resume timer
		ResumeTimer(id);
	}

	return FMRES_HANDLED;
}




//*******************************************************
//*                                                     *
//* Time management                                     *
//*                                                     *
//*******************************************************

bool:CanPause(id, bool:showMessages = true)
{
	if (pev(id, pev_iuser1))
	{
		if (showMessages) ShowMessage(id, "You can't toggle pause while in spectator");
		return false;
	}

	// Always allow to unpause
	if (get_bit(g_baIsPaused, id))
		return true;

	if (!get_pcvar_num(pcvar_kz_pause))
	{
		if (showMessages) ShowMessage(id, "Pause is disabled");
		return false;
	}

	if (!get_bit(g_baIsClimbing, id))
	{
		if (showMessages) ShowMessage(id, "Timer is not started");
		return false;
	}
	if (!IsAlive(id))
	{
		if (showMessages) ShowMessage(id, "You must be alive to use this command");
		return false;
	}
	if (!IsValidPlaceForCp(id))
	{
		if (showMessages) ShowMessage(id, "You must be on the ground to get paused");
		return false;
	}
	if (g_bMatchRunning)
	{
		if (showMessages) ShowMessage(id, "Match is running, pause is disabled");
		return false;
	}

	return true;
}

bool:CanReset(id, bool:showMessages = true)
{
	if (g_bMatchRunning)
	{
		if (showMessages) ShowMessage(id, "Match is running, reset is disabled");
		return false;
	}

	return true;
}

StartClimb(id)
{
	if (g_CheatCommandsGuard[id])
	{
		if(get_pcvar_num(pcvar_kz_denied_sound))
		{
		client_cmd(id, "spk \"vox/access denied\"");
		}
		ShowMessage(id, "Using timer while cheating is prohibited");
		return;
	}
	if (g_bMatchRunning)
	{
		ShowMessage(id, "Match is running, start is disabled");
		return;
	}

	if (g_RecordRun[id])
	{
		//fclose(g_RecordRun[id]);
		g_RecordRun[id] = 0;
		ArrayClear(g_RunFrames[id]);
		//console_print(id, "stopped recording");
	}

	if (get_pcvar_num(pcvar_kz_autorecord))
	{
		g_RecordRun[id] = 1;
		g_RunFrames[id] = ArrayCreate(REPLAY);
		//console_print(id, "started recording");
		RecordRunFrame(id);
	}

	InitPlayer(id);

	CreateCp(id, CP_TYPE_START);

	StartTimer(id);
}

FinishClimb(id)
{
	new kzDeniedSound = get_pcvar_bool(pcvar_kz_denied_sound);
	new bool:canFinish = true;
	if (g_CheatCommandsGuard[id])
	{
		ShowMessage(id, "Using timer while cheating is prohibited");
		canFinish = false;
	}
	if (!get_bit(g_baIsClimbing, id))
	{
		ShowMessage(id, "You must press the start button first");
		canFinish = false;
	}
	//console_print(id, "Your reqs: %d, map reqs: %d", g_PlayerEndReqs[id], g_MapEndTotalReq);
	if (g_isHL1Campaign && g_PlayerEndReqs[id] != g_MapEndTotalReq)
	{
		ShowMessage(id, "You don't meet the requirements to finish. Press the required buttons or pass through the required places first");
		canFinish = false;
	}
	if (!canFinish)
	{
		if (kzDeniedSound)
			client_cmd(id, "spk \"vox/access denied\"");
		
		return;
	}

	FinishTimer(id);
	InitPlayer(id);
}

StartTimer(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);
	new Float:speed = vector_length(velocity);

	set_bit(g_baIsClimbing, id);
	if (speed <= get_pcvar_float(pcvar_kz_pure_max_start_speed))
		set_bit(g_baIsPureRunning, id);

	g_PlayerTime[id] = get_gametime();

	if (g_ShowStartMsg[id])
	{
		new msg[38];
		formatex(msg, charsmax(msg), "Timer started with speed %5.2fu/s", speed);
		ShowMessage(id, msg);
	}

	//console_print(id, "gametime: %.5f", get_gametime());
}

FinishTimer(id)
{
	new name[32], minutes, Float:seconds, pureRun[11], RUN_TYPE:topType;
	new Float:kztime = get_gametime() - g_PlayerTime[id];

	minutes = floatround(kztime, floatround_floor) / 60;
	seconds = kztime - (60 * minutes);
	pureRun = get_bit(g_baIsPureRunning, id) ? "(Pure Run)" : "";

	client_cmd(0, "spk fvox/bell");

	get_user_name(id, name, charsmax(name));
	client_print(0, print_chat, GetVariableDecimalMessage(id, "[%s] %s finished in %02d:%", "(CPs: %d | TPs: %d) %s"),
		PLUGIN_TAG, name, minutes, seconds, g_CpCounters[id][COUNTER_CP], g_CpCounters[id][COUNTER_TP], pureRun);

	if (!get_pcvar_num(pcvar_kz_nostat) && !IsBot(id))
	{

		// Bots are not gonna set new records yet, unless some bhop AI is created for fun
		if (!g_CpCounters[id][COUNTER_CP] && !g_CpCounters[id][COUNTER_TP])
		{
			if (get_bit(g_baIsPureRunning, id))
			{
				// Update both: pure and pro
				topType = PURE;
				UpdateRecords(id, kztime, PURE);
				UpdateRecords(id, kztime, PRO);
			}
			else
			{
				topType = PRO;
				UpdateRecords(id, kztime, PRO);
			}
		}
		else
		{
			topType = NOOB;
			UpdateRecords(id, kztime, NOOB);
		}
	}

	clr_bit(g_baIsClimbing, id);
	clr_bit(g_baIsPureRunning, id);

	if (g_bMatchRunning)
	{
		g_bMatchRunning = false;
		server_cmd("agabort");
		server_exec();

		LaunchRecordFireworks();
		
		if (IsCupMap() && (id == g_CupPlayer1 || id == g_CupPlayer2) && g_CupReady1 && g_CupReady2)
		{
			// Do stuff for the cup

			// Update scores
			if (id == g_CupPlayer1)
				g_CupScore1++;
			else
				g_CupScore2++;

			// Update map state
			TrieSetCell(g_CupMapPool, g_Map, MAP_PLAYED);

			// Save the changes to file, because we're gonna change the map in a while
			// and this info has to be taken again from the file right after changing
			WriteCupMapPoolFile(0);
			WriteCupFile(0);
			CmdMapsShowHandler(0); // TODO: maybe this should show who won each map instead of just [PLAYED]

			if (!topType)
				topType = PURE;

			// Save replays of both participants, for the one that didn't reach the button too
			if (g_RecordRun[g_CupPlayer1])
			{
				g_RecordRun[g_CupPlayer1] = 0;
				SaveRecordedRunCup(g_CupPlayer1, topType);
			}
			if (g_RecordRun[g_CupPlayer2])
			{
				g_RecordRun[g_CupPlayer2] = 0;
				SaveRecordedRunCup(g_CupPlayer2, topType);
			}

			new playerName[32];
			GetColorlessName(id, playerName, charsmax(playerName));
			if (playerName[0])
				client_print(0, print_chat, "[%s] Player %s has won this map! Congrats!", PLUGIN_TAG, playerName);
			else
				client_print(0, print_chat, "[%s] The unnamed player has won this map! Congrats!", PLUGIN_TAG);

			new name1[32], name2[32];
			GetColorlessName(g_CupPlayer1, name1, charsmax(name1));
			GetColorlessName(g_CupPlayer2, name2, charsmax(name2));
			client_print(0, print_chat, "[%s] Score: %s %d - %d %s", PLUGIN_TAG, name1, g_CupScore1, g_CupScore2, name2);

			new diffScore = abs(g_CupScore1 - g_CupScore2);
			// At this point this very map has already been marked as PLAYED, so won't be counted as remaining
			new remainingMapsCount = CountCupMaps(MAP_PICKED) + CountCupMaps(MAP_DECIDER);
			new bool:hasWonMatch = diffScore > remainingMapsCount;

			if (hasWonMatch)
			{
				// The match winner must be the one who won this map,
				// unless you can somehow score negative if that makes sense (?)
				client_print(0, print_chat, "[%s] %s has won overall the match, no more maps to be played. Congrats!", PLUGIN_TAG, playerName);

				ClearCup(0);
				WriteCupMapPoolFile(0);
				WriteCupFile(0);
			}
			else
			{
				new map[32];
				GetNextCupMapToPlay(map, charsmax(map));

				new Float:timeToChange = get_pcvar_float(pcvar_kz_cup_map_change_delay);
				client_print(0, print_chat, "[%s] The next map to be played is %s. Changing the map in %.0f seconds...", PLUGIN_TAG, map, timeToChange);

				set_task(timeToChange, "CupChangeMap", TASKID_CUP_CHANGE_MAP, map, charsmax(map));
			}
		}
	}
}

PauseTimer(id, bool:specModeProcessing)
{
	if (!get_bit(g_baIsClimbing, id) || get_bit(g_baIsPaused, id))
		return;

	set_bit(g_baIsPaused, id);
	g_PlayerTimePause[id] = get_gametime();

	ShowMessage(id, "Timer has been paused");

	if (!specModeProcessing)
	{
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
		ShowPauseIcon(id + TASKID_ICON);
		set_task(2.0, "ShowPauseIcon", id + TASKID_ICON, _, _, "b");
	}
}

ResumeTimer(id)
{
	if (!get_bit(g_baIsClimbing, id) || !get_bit(g_baIsPaused, id))
		return;

	clr_bit(g_baIsPaused, id);
	g_PlayerTime[id] += get_gametime() - g_PlayerTimePause[id];
	g_PlayerTimePause[id] = 0.0;

	ShowMessage(id, "Timer has been resumed");

	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
	remove_task(id + TASKID_ICON);
}

public ShowPauseIcon(id)
{
	id -= TASKID_ICON;
	if (!IsPlayer(id))
		return;

	new Float:origin[3];
	pev(id, pev_origin, origin);
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SPRITE);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2]) + 45);
	write_short(g_PauseSprite);
	write_byte(10);		// size * 10
	write_byte(128);	// brightness
	message_end();
}

public Fw_HamUseButtonPre(ent, id)
{
	if (!IsPlayer(id))
		return HAM_IGNORED;

	//console_print(id, "using a button");

	new BUTTON_TYPE:type = GetEntityButtonType(ent);
	switch (type)
	{
	case BUTTON_START: StartClimb(id);
	case BUTTON_FINISH: {
		new Float:origin[3];
		fm_get_brush_entity_origin(ent, origin); // find origin of button for fireworks

		// console_print(0, "origin[0]: %f", origin[0]);
		// console_print(0, "origin[1]: %f", origin[1]);
		// console_print(0, "origin[2]: %f", origin[2]);

		g_PrevButtonOrigin[0] = origin[0];
		g_PrevButtonOrigin[1] = origin[1];
		g_PrevButtonOrigin[2] = origin[2];

		FinishClimb(id);
	}
	case BUTTON_NOT: CheckEndReqs(ent, id);
	}

	return HAM_IGNORED;
}

BUTTON_TYPE:GetEntityButtonType(ent)
{
	static name[32];

	pev(ent, pev_target, name, charsmax(name));
	if (name[0])
	{
		if (IsStartEntityName(name))
		{
			return BUTTON_START;
		}
		else if (IsStopEntityName(name))
		{
			return BUTTON_FINISH;
		}
	}

	pev(ent, pev_targetname, name, charsmax(name));
	if (name[0])
	{
		if (IsStartEntityName(name))
		{
			return BUTTON_START;
		}
		else if (IsStopEntityName(name))
		{
			return BUTTON_FINISH;
		}
	}

	return BUTTON_NOT;
}

bool:IsStartEntityName(name[])
{
	for (new i = 0; i < sizeof(g_szStarts); i++)
		if (containi(name, g_szStarts[i]) != -1)
			return true;
	return false;
}

bool:IsStopEntityName(name[])
{
	for (new i = 0; i < sizeof(g_szStops); i++)
		if (containi(name, g_szStops[i]) != -1)
			return true;
	return false;
}

CheckEndReqs(ent, id)
{
	new name[32];
	pev(ent, pev_targetname, name, charsmax(name));

	if (!name[0])
		pev(ent, pev_target, name, charsmax(name));

	//console_print(id, "checking reqs for %s", name);

	if (TrieKeyExists(g_MapEndReqs, name))
	{
		// This entity is a requirement for being able to end the timer
		new reqBits;
		TrieGetCell(g_MapEndReqs, name, reqBits);

		//console_print(id, "%s is registered in HLKZ", name);

		if (reqBits - 1 == g_PlayerEndReqs[id] || TrieKeyExists(g_UnorderedReqsMaps, g_Map))
		{
			// Add its bits to the player's bit field for end requirements,
			// but only if it they have met all the previous requirements
			//console_print(id, "updating reqs, current = %d", g_PlayerEndReqs[id]);
			g_PlayerEndReqs[id] |= reqBits;
		}

		//console_print(id, "req %s has been met; your reqs:: %d", name, g_PlayerEndReqs[id]);
	}
}


//*******************************************************
//*                                                     *
//* Hud display                                         *
//*                                                     *
//*******************************************************

public Fw_FmThinkPre(ent)
{
	// Hud update task
	if (ent == g_TaskEnt)
	{
		static Float:currentGameTime;
		currentGameTime = get_gametime();
		UpdateHud(currentGameTime);
		set_pev(ent, pev_nextthink, currentGameTime + 0.05);
	}
}

UpdateHud(Float:currentGameTime)
{
	static Float:kztime, min, sec, mode, targetId, ent, body;
	static players[MAX_PLAYERS], num, id, id2, i, j, playerName[33];
	static specHud[1280];

	get_players(players, num);
	for (i = 0; i < num; i++)
	{
		id = players[i];
		GetColorlessName(id, playerName, charsmax(playerName));
		//if (IsBot(id) || IsHltv(id)) continue;

		// Select target from whom to take timer and pressed keys
		mode = pev(id, pev_iuser1);
		targetId = mode == OBS_CHASE_LOCKED || mode == OBS_CHASE_FREE || mode == OBS_IN_EYE || mode == OBS_MAP_CHASE ? pev(id, pev_iuser2) : id;
		if (!is_user_connected(targetId)) continue;

		if (g_LastMode[id] != mode)
		{
			// Clear hud if we are switching spec mode
			g_LastMode[id] = mode;
			ClearSyncHud(id, g_SyncHudTimer);
			ClearSyncHud(id, g_SyncHudKeys);
			ClearSyncHud(id, g_SyncHudShowStartMsg);
			ClearSyncHud(id, g_SyncHudSpeedometer);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(targetId, g_SyncHudSpecList);
		}
		if (g_LastTarget[id] != targetId)
		{
			// Clear hud if we are switching between different targets
			g_LastTarget[id] = targetId;
			ClearSyncHud(id, g_SyncHudTimer);
			ClearSyncHud(id, g_SyncHudKeys);
			ClearSyncHud(id, g_SyncHudShowStartMsg);
			ClearSyncHud(id, g_SyncHudSpeedometer);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(targetId, g_SyncHudSpecList);
		}

		// Drawing spectator list
		if (is_user_alive(id) && get_pcvar_num(pcvar_kz_speclist))
		{
			new bool:sendTo[33];
			if (GetSpectatorList(id, specHud, charsmax(specHud), sendTo))
			{
				for (new i = 1; i <= g_MaxPlayers; i++)
				{
					if (sendTo[i] == true && g_ShowSpecList[i] == true)
					{
						set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], 0.75, 0.15, 0, 0.0, 999999.0, 0.0, 0.0, -1);
						ShowSyncHudMsg(id, g_SyncHudSpecList, specHud);
					} else {
						ClearSyncHud(id, g_SyncHudSpecList);
					}
				}
			}
		}


		// Drawing pressed keys
		HudShowPressedKeys(id, mode, targetId);

		// Show information about start/stop entities
		get_user_aiming(targetId, ent, body);
		if (!IsPlayer(ent))
		{
			new BUTTON_TYPE:type = GetEntityButtonType(ent);
			switch (type)
			{
			case BUTTON_START: ShowInHealthHud(id, "START");
			case BUTTON_FINISH: ShowInHealthHud(id, "STOP");
			}

#if defined _DEBUG
			static classname[32], targetname[32], target[32];
			pev(ent, pev_classname, classname, charsmax(classname));
			pev(ent, pev_targetname, targetname, charsmax(targetname));
			pev(ent, pev_target, target, charsmax(target));
			ShowInHealthHud(id, "classname: %s\ntargetname: %s\ntarget: %s", classname, targetname, target);
#endif // _DEBUG
		}

		// Show own or spectated target timer
		if (get_bit(g_baIsClimbing, targetId) && g_ShowTimer[id])
		{
			kztime = get_bit(g_baIsPaused, targetId) ? g_PlayerTimePause[targetId] - g_PlayerTime[targetId] : currentGameTime - g_PlayerTime[targetId];

			min = floatround(kztime / 60.0, floatround_floor);
			sec = floatround(kztime - min * 60.0, floatround_floor);

			if (g_CpCounters[id][COUNTER_CP] || g_CpCounters[id][COUNTER_TP])
				g_RunType[id] = "Noob run";
			else if (get_bit(g_baIsPureRunning, id))
				g_RunType[id] = "Pure run";
			else
				g_RunType[id] = "Pro run";

			switch (g_ShowTimer[id])
			{
			case 1:
				{
					client_print(id, print_center, "%s | Time: %02d:%02d | CPs: %d | TPs: %d %s",
							g_RunType[id], min, sec, g_CpCounters[targetId][COUNTER_CP], g_CpCounters[targetId][COUNTER_TP], get_bit(g_baIsPaused, targetId) ? "| *Paused*" : "");
				}
			case 2:
				{
					set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.10, 0, 0.0, 999999.0, 0.0, 0.0, -1);
					ShowSyncHudMsg(id, g_SyncHudTimer, "%s | Time: %02d:%02d | CPs: %d | TPs: %d %s",
						g_RunType[id], min, sec, g_CpCounters[targetId][COUNTER_CP], g_CpCounters[targetId][COUNTER_TP], get_bit(g_baIsPaused, targetId) ? "| *Paused*" : "");
				}
			}
		}

		if (g_ShowSpeed[id])
		{
			set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.7, 0, 0.0, 999999.0, 0.0, 0.0, -1);
			if (is_user_alive(id))
				ShowSyncHudMsg(id, g_SyncHudSpeedometer, "%.2f", floatsqroot(g_Velocity[id][0] * g_Velocity[id][0] + g_Velocity[id][1] * g_Velocity[id][1]));
			else
			{
				new specmode = pev(id, pev_iuser1);
				if (specmode == 2 || specmode == 4)
				{
					new t = pev(id, pev_iuser2);
					ShowSyncHudMsg(id, g_SyncHudSpeedometer, "%.2f", floatsqroot(g_Velocity[t][0] * g_Velocity[t][0] + g_Velocity[t][1] * g_Velocity[t][1]));
				}
			}
		}
	}
}

GetSpectatorList(id, hud[], len, sendTo[])
{
	new szName[33];
	new bool:send = false;

	sendTo[id] = true;

	GetColorlessName(id, szName, charsmax(szName));
	format(hud, 45, "Spectating %s:\n", szName);

	for (new dead = 1; dead <= g_MaxPlayers; dead++)
	{
		if (is_user_connected(dead))
		{
			if (is_user_alive(dead))
				continue;

			if (pev(dead, pev_iuser2) == id)
			{
				if(!(get_pcvar_num(pcvar_kz_speclist_admin_invis) && get_user_flags(dead, 0) & ADMIN_IMMUNITY))
				{
					get_user_name(dead, szName, charsmax(szName));
					add(szName, charsmax(szName), "\n");
					add(hud, len, szName);
					send = true;
				}
				sendTo[dead] = true;
			}
		}
	}
	return send;
}

HudStorePressedKeys(id)
{
	if (!get_pcvar_num(pcvar_kz_show_keys))
		return;

	static Float:currentGameTime;
	currentGameTime = get_gametime();

	static button;
	button = pev(id, pev_button);

	// Prolong Jump key show
	if (button & IN_JUMP)
		g_LastPressedJump[id] = currentGameTime;
	else if (currentGameTime > g_LastPressedJump[id] && currentGameTime - g_LastPressedJump[id] < 0.05)
		button |= IN_JUMP;

	// Prolong Duck key show
	if (button & IN_DUCK)
		g_LastPressedDuck[id] = currentGameTime;
	else if (currentGameTime > g_LastPressedDuck[id] && currentGameTime - g_LastPressedDuck[id] < 0.05)
		button |= IN_DUCK;

	g_LastButtons[id] = button;
}

HudShowPressedKeys(id, mode, tagret)
{
	if (!get_pcvar_num(pcvar_kz_show_keys) || !g_ShowKeys[id] ||
		(mode != OBS_NONE && mode != OBS_IN_EYE) ||
		(mode == OBS_NONE && g_ShowKeys[id] != 2))
		return;

	static button;
	button = g_LastButtons[tagret];
	if (g_LastSentButtons[id] == button)
		return;
	g_LastSentButtons[id] = button;

	set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, -1.0, 0, _, 999999.0, _, _, -1);
	ShowSyncHudMsg(id, g_SyncHudKeys, "\n%s\n%s\n%s        %s\n%s\n%s\n%s",
		(button & IN_USE) ? "USE" : "",
		(button & IN_FORWARD) && !(button & IN_BACK) ? "W" : "",
		(button & IN_MOVELEFT) && !(button & IN_MOVERIGHT) ? "A" : "",
		(button & IN_MOVERIGHT) && !(button & IN_MOVELEFT) ? "D" : "",
		(button & IN_BACK) && !(button & IN_FORWARD) ? "S" : "",
		(button & IN_JUMP) ? "JUMP" : "",
		(button & IN_DUCK) ? "DUCK" : "");
}

ShowMessage(id, const message[], {Float,Sql,Result,_}:...)
{
	static kz_messages;
	static msg[192];

	kz_messages = get_pcvar_num(pcvar_kz_messages);
	if (!kz_messages)
		return;

	vformat(msg, charsmax(msg), message, 3);

	switch (kz_messages)
	{
	case 1: client_print(id, print_chat, "[%s] %s.", PLUGIN_TAG, msg);
	case 2:
		{
			set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.89, 0, 0.0, 2.0, 0.0, 1.0, 4);
			ShowSyncHudMsg(id, g_SyncHudMessage, msg);
		}
	}
}

ShowInHealthHud(id, const message[], {Float,Sql,Result,_}:...)
{
	static kz_messages;
	static msg[192];

	kz_messages = get_pcvar_num(pcvar_kz_messages);
	if (!kz_messages)
		return;

	vformat(msg, charsmax(msg), message, 3);

	set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.92, 0, _, 2.0, _, _, -1);
	ShowSyncHudMsg(id, g_SyncHudHealth, msg);
}




//*******************************************************
//*                                                     *
//* Forwards (mostly about damage and spawn)            *
//*                                                     *
//*******************************************************

public Fw_HamSpawnPlayerPost(id)
{
	if (pev(id, pev_deadflag) == DEAD_NO && pev(id, pev_iuser1) == OBS_NONE)
		set_bit(g_bit_is_alive, id);
	else
		clr_bit(g_bit_is_alive, id);

	// First spawn
	if (!get_bit(g_baIsFirstSpawn, id))
	{
		set_bit(g_baIsFirstSpawn, id);
		return;
	}

	// Remember and clear pause state to allow teleporting
	new paused = get_bit(g_baIsPaused, id);
	clr_bit(g_baIsPaused, id);

	// Teleport if not a forced respawn
	if (!g_InForcedRespawn)
	{
		TeleportAfterRespawn(id);
	}
	g_InForcedRespawn = false;

	// Check if timer is paused and freeze a player
	if (!paused)
		return;

	set_bit(g_baIsPaused, id);

	ShowMessage(id, "Timer has been paused");

	set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
	ShowPauseIcon(id + TASKID_ICON);
	set_task(2.0, "ShowPauseIcon", id + TASKID_ICON, _, _, "b");
}

public Fw_HamKilledPlayerPre(victim, killer, shouldgib)
{
	if (!IsPlayer(victim))
		return;

	clr_bit(g_bit_is_alive, victim);

	// Clear freeze to allow correct animation of the corpse
	if (!get_bit(g_baIsPaused, victim))
		return;

	set_pev(victim, pev_flags, pev(victim, pev_flags) & ~FL_FROZEN);
	remove_task(victim + TASKID_ICON);
}

public Fw_HamKilledPlayerPost(victim, killer, shouldgib)
{
	// Even frags to mantain frags equal to teleports
	if (IsPlayer(killer))
		ExecuteHamB(Ham_AddPoints, killer, -(g_CpCounters[killer][COUNTER_TP] + pev(killer, pev_frags)), true);
	if (IsPlayer(victim))
		ExecuteHamB(Ham_AddPoints, victim, -(g_CpCounters[victim][COUNTER_TP] + pev(victim, pev_frags)), true);
}

public Fw_HamBloodColorPre(id)
{
	if (get_pcvar_num(pcvar_kz_nodamage))
	{
		SetHamReturnInteger(-1);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public Fw_HamTakeDamagePlayerPre(victim, inflictor, aggressor, Float:damage, damagebits)
{
	pev(victim, pev_health, g_LastHealth);

	if (get_pcvar_num(pcvar_kz_nodamage))
	{
		if ((damagebits == DMG_GENERIC && !aggressor && damage == 300.0) || (aggressor != victim && IsPlayer(aggressor)))
		{
			// Hack for admins to shoot users with python
			if (aggressor && victim &&
				(get_user_weapon(aggressor) == HLW_PYTHON) &&
				(get_user_flags(aggressor) & ADMIN_LEVEL_A) &&
				(get_user_flags(victim) & ADMIN_USER))
			{
				SetHamParamFloat(4, 100500.0);
				return HAM_HANDLED;
			}

			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public Fw_HamTakeDamagePlayerPost(victim, inflictor, aggressor, Float:damage, damagebits)
{
	static Float:fHealth;
	pev(victim, pev_health, fHealth);

	if (damagebits & DMG_BLAST || damagebits & DMG_SLASH || damagebits & DMG_BULLET)
	{ // Check damage types in the g_DamageBoostEntities[][] declaration
		new classNameInflictor[32];
		pev(inflictor, pev_classname, classNameInflictor, charsmax(classNameInflictor));
		for (new i = 0; i < sizeof(g_DamageBoostEntities); i++)
		{
			if (equal(classNameInflictor, g_DamageBoostEntities[i]))
			{
				// No check for the aggressor, because I imagine one could throw
				// a nade far up, reconnect, start the timer, and then that nade
				// just falls into the ground, explodes and boosts player in some
				// direction with the damage inflicted
				//PunishPlayerCheatingWithWeapons(victim);

				// EDIT: so in HLKZ we cannot damage other players, so yea, we have
				// to check the aggressor
				if (victim == aggressor) {
					PunishPlayerCheatingWithWeapons(victim);
				}
			}
		}
	}

	// If someone gets boosted by the attack of another player, punish the boosted victim xD
	if (IsPlayer(aggressor) && !get_pcvar_num(pcvar_kz_nodamage))
		PunishPlayerCheatingWithWeapons(victim);

	if (fHealth > 2147483400.0)
	{
		fHealth = 2147483400.0;
		set_pev(victim, pev_health, fHealth);
	}
	if (fHealth > 255.0 && (fHealth < 100000 || g_LastHealth < 100000) && fHealth != g_LastHealth)
	{
		ShowInHealthHud(victim, "HP: %.0f", fHealth);
	}
}

public Fw_HamBoostAttack(weaponId)
{
	new ownerId = pev(weaponId, pev_owner);
	PunishPlayerCheatingWithWeapons(ownerId);
	return PLUGIN_CONTINUE;
}

public Fw_HamItemRespawn(itemId)
{
	new Float:respawnTime = get_pcvar_float(pcvar_sv_items_respawn_time);
	set_pev(itemId, pev_nextthink, get_gametime() + respawnTime);

	return PLUGIN_CONTINUE;
}

public Fw_FmWeaponRespawn(weaponId, worldspawnId)
{
	// Tried setting the nextthink of weapons like we do with items, but that didn't work,
	// so we set a task and make it call the weapon's spawn function
	new weapon[WEAPON];
	pev(weaponId, pev_classname, weapon[WEAPON_CLASSNAME], charsmax(weapon[WEAPON_CLASSNAME]));
	pev(weaponId, pev_origin, weapon[WEAPON_ORIGIN]);

	new i, bool:found = false, Float:subtract[3];
	for (i = 0; i < sizeof(g_MapWeapons); i++)
	{
		if (!g_MapWeapons[i][WEAPON_CLASSNAME])
			break;

		if (equal(g_MapWeapons[i][WEAPON_CLASSNAME], weapon[WEAPON_CLASSNAME]))
		{
			// The height at which the weapon is placed seems to be slightly changed
			// after the weapon is taken FOR FIRST TIME in the map. It's like the next time
			// the entity spawns a little lower in the Z axis, more sticked to the ground.
			// After the first take, all the entities of that weapon class that spawn there
			// will have the same Z value though
			xs_vec_sub(g_MapWeapons[i][WEAPON_ORIGIN], weapon[WEAPON_ORIGIN], subtract);
			if (!subtract[0] && !subtract[1] && xs_fabs(subtract[2]) <= 0.1)
			{
				found = true;
				break;
			}
		}
	}

	if (!found)
		g_MapWeapons[i] = weapon;
	else
	{
		new Float:respawnTime = get_pcvar_float(pcvar_sv_items_respawn_time);
		set_pev(weaponId, pev_nextthink, get_gametime() + respawnTime);
	}

	return PLUGIN_CONTINUE;
}

public Fw_FmClientKillPre(id)
{
	if (get_pcvar_num(pcvar_kz_nokill))
	{
		ShowMessage(id,"Command \"kill\" is disabled");
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

public Fw_MsgHealth(msg_id, msg_dest, msg_entity)
{
	static health;
	health = get_msg_arg_int(1);

	if (health > 255)
		set_msg_arg_int(1, get_msg_argtype(1), 255);
}

public Fw_MsgCountdown(msg_id, msg_dest, msg_entity)
{
	static arg1, arg2;
	arg1 = get_msg_arg_int(1);
	arg2 = get_msg_arg_int(2);
	if (arg1 != -1 || arg2 != 0)
		return;

	// Start the timer, disable pause/reset/start button/commands
	g_bMatchRunning = true;
	for (new i = 1; i <= g_MaxPlayers; i++)
	{
		if (is_user_alive(i) && pev(i, pev_iuser1) == OBS_NONE)
		{
			InitPlayer(i, true);
			StartTimer(i);

			g_RecordRun[i] = 1;
			g_RunFrames[i] = ArrayCreate(REPLAY);
			RecordRunFrame(i);
		}
	}
}

public Fw_MsgSettings(msg_id, msg_dest, msg_entity)
{
	static arg1;
	arg1 = get_msg_arg_int(1);
	if (arg1 == 0)
		g_bMatchRunning = false;
}

public Fw_FmGetGameDescriptionPre()
{
	forward_return(FMV_STRING, PLUGIN);
	return FMRES_SUPERCEDE;
}

public Fw_FmCmdStartPre(id, uc_handle, seed)
{
	g_FrameTime[id][1] = g_FrameTime[id][0];
	g_FrameTime[id][0] = get_uc(uc_handle, UC_Msec);
	g_FrameTimeInMsec[id] = g_FrameTime[id][0] * 0.001;
	g_Buttons[id] = get_uc(uc_handle, UC_Buttons);
	g_Impulses[id] = get_uc(uc_handle, UC_Impulse);
}

public Fw_MsgTempEntity()
{
	// Block MiniAG timer from being sent
	if (get_msg_arg_int(1) == TE_TEXTMESSAGE && get_msg_arg_int(3) == 4096 && get_msg_arg_int(4) == 81)
	{
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}




//*******************************************************
//*                                                     *
//* Semiclip                                            *
//*                                                     *
//*******************************************************

public Fw_FmPlayerPreThinkPost(id)
{
	g_bWasSurfing[id] = g_bIsSurfing[id];
	g_bIsSurfing[id] = false;
	g_bIsSurfingWithFeet[id] = false;
	g_hasSurfbugged[id] = false;
	g_hasSlopebugged[id] = false;

	if (g_RampFrameCounter[id] > 0)
		g_RampFrameCounter[id] -= 1;

	if (g_HBFrameCounter[id] > 0)
	{
		g_HBFrameCounter[id] -= 1;
		CheckHealthBoost(id);
	}
	pev(id, pev_origin, g_Origin[id]);
	pev(id, pev_angles, g_Angles[id]);
	pev(id, pev_view_ofs, g_ViewOfs[id]);
	pev(id, pev_velocity, g_Velocity[id]);
	//console_print(id, "sequence: %d, pev_gaitsequence: %d", pev(id, pev_sequence), pev(id, pev_gaitsequence));

	if (!IsBot(id) && g_RecordRun[id])
		RecordRunFrame(id);

	// Store pressed keys here, cos HUD updating is called not so frequently
	HudStorePressedKeys(id);

	if (IsHltv(id) || !get_pcvar_num(pcvar_kz_semiclip) || pev(id, pev_iuser1))
		return;

	static i;
	for (i = 1; i <= g_MaxPlayers; i++)
	{
		if (!IsConnected(i) || i == id || IsHltv(i) || pev(i, pev_iuser1))
		{
			g_SolidState[i] = -1;
		}
		else
		{
			g_SolidState[i] = pev(i, pev_solid);
			set_pev(i, pev_solid, SOLID_NOT);
		}
	}

	g_RestoreSolidStates = true;

}

public Fw_FmTouchPre(iEntity1, iEntity2)
{
	// Surf detection
	if(IsPlayer(iEntity1))
	{
		// Setting stuff
		g_StoppedSlidingRamp[iEntity1] = false;
		new className[32];
		pev(iEntity2, pev_classname, className, charsmax(className));
		pev(iEntity1, pev_velocity, g_Velocity[iEntity1]);
		new Float:player[3], Float:angles[3], Float:velocity[3];
		new Float:belowOrigin[3], Float:sideOrigin[3];
		new Float:belowNormal[3], Float:sideNormal[3];
		pev(iEntity1, pev_origin, player);
		pev(iEntity1, pev_angles, angles);
		pev(iEntity1, pev_velocity, velocity);

		// Start checking planes around player to know their context
		GetNormalPlaneRelativeToPlayer(iEntity1, player, Float:{0.0, 0.0, -9999.0}, belowOrigin, belowNormal); // direction: below player
		GetNormalPlaneAtSideOfPlayer(iEntity1, player, sideOrigin, sideNormal);

		new Float:footOrigin[3], Float:footSideOrigin[3], Float:footSideNormal[3];
		new Float:feetZ = (pev(iEntity1, pev_flags) & FL_DUCKING) ? -18.0 : -36.0;
		new Float:feet[3];
		feet[0] = 0.0;
		feet[1] = 0.0;
		feet[2] = feetZ;
		xs_vec_add(player, feet, footOrigin);
		GetNormalPlaneAtSideOfPlayer(iEntity1, footOrigin, footSideOrigin, footSideNormal);

		new bool:bOnRamp = player[1] == belowOrigin[1] && belowNormal[1] != 0 && player[2] - belowOrigin[2] <= 50.0;
		// that 50.0 should be 36.0, but in some rare case it was more than 40, and most times it's between 34.9 and 35.0, and between 16.9 and 17.5 when crouched

		if (bOnRamp)
			g_RampFrameCounter[iEntity1] = 125; // for the next 125 frames will continue checking slopebug
		else
			g_RampFrameCounter[iEntity1] = 0;

		// Avoid keeping the velocity when appearing on the other side of the teleport
		// It thinks you're surfing when jumping into it
		if (equali(className, "trigger_teleport"))
		{ // Made a register_touch for this as it seems that it never makes it to this point
			g_bIsSurfing[iEntity1] = false;
			g_RampFrameCounter[iEntity1] = 0;
			g_hasSurfbugged[iEntity1] = false;
			g_hasSlopebugged[iEntity1] = false;
		}

		if (!IsUserOnGround(iEntity1) && (sideNormal[2] != 0 || footSideNormal[2] != 0 || bOnRamp))
		{ // Surfing
			if (footSideNormal[2] != 0 && sideNormal[2] == 0)
				g_bIsSurfingWithFeet[iEntity1] = true;
			else
				g_bIsSurfingWithFeet[iEntity1] = false;

			if (!equali(className, "trigger_teleport"))
				g_bIsSurfing[iEntity1] = true;
		}
		else if (g_bWasSurfing[iEntity1] && bOnRamp)
		{
			// Player is sliding a ramp, and it was surfing in the previous frame,
			// but the player's not longer surfing but landing on the ramp to make another jump
			g_StoppedSlidingRamp[iEntity1] = true;
			g_bIsSurfing[iEntity1] = false;
		}
	}
	// Would also do in case the player is iEntity2 and not iEntity1, but turns out that
	// if a player touches something, it will enter twice in this forward, once with player
	// as iEntity1 and entity (worldspawn or whatever) as iEntity2 and the next time viceversa
}

public Fw_FmPlayerTouchMonster(monster, id)
{
    if (!is_user_alive(id) || !pev_valid(monster))
    	return;

    new Float:playerFeetZ = g_Origin[id][2] + ((pev(id, pev_flags) & FL_DUCKING) ? -18.0 : -36.0);
    new Float:monsterOrigin[3];
    pev(monster, pev_origin, monsterOrigin);

    if (playerFeetZ > monsterOrigin[2] + 6.0) // 6.0 = half the height of the tripmine/snark/satchel
    {
    	// The player is touching a snark/tripmine and it's higher, so it's stepping on it...
    	// not allowed to do that, cheater! now we downgrade the run or reset the timer
		PunishPlayerCheatingWithWeapons(id);
    }
}

public Fw_FmPlayerTouchTeleport(tp, id) {
    if (is_user_alive(id))
    {
		g_bIsSurfing[id] = false;
		g_bWasSurfing[id] = false;
		g_hasSurfbugged[id] = false;
		g_hasSlopebugged[id] = false;
		g_RampFrameCounter[id] = 0;
		g_HBFrameCounter[id] = 0;
    }

}

public Fw_FmPlayerTouchPush(push, id)
{
	if (is_user_alive(id))
		CheckHealthBoost(id);
}

CheckHealthBoost(id)
{
	if (!get_pcvar_num(pcvar_kz_pure_allow_healthboost))
	{
		new Float:startSpeed = floatsqroot(floatpower(g_Velocity[id][0], 2.0) + floatpower(g_Velocity[id][1], 2.0));
		new Float:endSpeed = GetPlayerSpeed(id);
		if (endSpeed > (startSpeed * 1.5) && endSpeed >= 2000.0)
		{
			// Very likely used healthboost, so this is not a pure run anymore
			clr_bit(g_baIsPureRunning, id);
			if (g_CpCounters[id][COUNTER_CP] || g_CpCounters[id][COUNTER_TP])
				g_RunType[id] = "Noob run";
			else
				g_RunType[id] = "Pro run";

			g_HBFrameCounter[id] = 0;

			new ret;
			ExecuteForward(mfwd_hlkz_cheating, ret, id);
		}
	}
}

public Fw_FmPlayerTouchHealthBooster(hb, id)
{
	if (is_user_alive(id))
		g_HBFrameCounter[id] = 250;
}

public Fw_FmPlayerPostThinkPre(id)
{
	if ((pev(id, pev_button) & IN_JUMP) && hl_get_user_longjump(id))
	{
		// TODO: check whether the player has really longjumped, not if it has the LJ module
		// and has performed a jump that may be just a normal jump and not a longjump-assisted one
		clr_bit(g_baIsPureRunning, id);
	}

	new Float:currVelocity[3];
	pev(id, pev_velocity, currVelocity);
	new Float:endSpeed = floatsqroot(floatpower(currVelocity[0], 2.0) + floatpower(currVelocity[1], 2.0));
	if (g_Slopefix[id])
	{
		new Float:currOrigin[3], Float:futureOrigin[3], Float:futureVelocity[3];
		pev(id, pev_origin, currOrigin);
		new Float:startSpeed = floatsqroot(floatpower(g_Velocity[id][0], 2.0) + floatpower(g_Velocity[id][1], 2.0));

		new Float:svGravity = get_cvar_float("sv_gravity");
		new Float:pGravity;
		pev(id, pev_gravity, pGravity);

		futureOrigin[0] = currOrigin[0] + g_Velocity[id][0] * g_FrameTimeInMsec[id];
		futureOrigin[1] = currOrigin[1] + g_Velocity[id][1] * g_FrameTimeInMsec[id];
		futureOrigin[2] = currOrigin[2] + 0.4 + g_FrameTimeInMsec[id] * (g_Velocity[id][2] - pGravity * svGravity * g_FrameTimeInMsec[id] / 2);

		futureVelocity = g_Velocity[id];
		futureVelocity[2] += 0.1;

		if (g_bIsSurfing[id] && startSpeed > 1.0 && endSpeed <= 0.0)
		{
			// We restore the velocity that the player had before occurring the slopebug
			set_pev(id, pev_velocity, futureVelocity);

			// We move the player to the position where they would be if they were not blocked by the bug,
			// only if they're not gonna get stuck inside a wall
			new Float:leadingBoundary[3], Float:collisionPoint[3];
			if (IsPlayerInsideWall(id, futureOrigin, leadingBoundary, collisionPoint))
			{
				// The player has some boundary component inside the wall, so make
				// that component go outside, touching the wall but not inside it
				if (xs_fabs(leadingBoundary[0]) - xs_fabs(collisionPoint[0]) < 0.0)
				{
					new Float:x = float(xs_fsign(g_Velocity[id][0])) * 16.0;
					futureOrigin[0] = collisionPoint[0] - x;

				}
				if (xs_fabs(leadingBoundary[1]) - xs_fabs(collisionPoint[1]) < 0.0)
				{
					new Float:y = float(xs_fsign(g_Velocity[id][1])) * 16.1;
					futureOrigin[1] = collisionPoint[1] - y;
				}
				if (!IsPlayerInsideWall(id, futureOrigin, leadingBoundary, collisionPoint))
					set_pev(id, pev_origin, futureOrigin); // else player is not teleported, just keeps velocity
				// Tried to do a while to continue checking if player's inside a wall, but crashed with reliable channel overflowed
			}
			else
				set_pev(id, pev_origin, futureOrigin);

			g_hasSurfbugged[id] = true;
		}
		if ((g_StoppedSlidingRamp[id] || g_RampFrameCounter[id] > 0) && startSpeed > 1.0 && endSpeed <= 0.0)
		{
			set_pev(id, pev_velocity, futureVelocity);
			new Float:leadingBoundary[3], Float:collisionPoint[3];
			if (IsPlayerInsideWall(id, futureOrigin, leadingBoundary, collisionPoint))
			{
				// The player has some boundary component inside the wall, so make
				// that component go outside, touching the wall but not inside it
				if (xs_fabs(leadingBoundary[0]) - xs_fabs(collisionPoint[0]) < 0.0)
				{
					new Float:x = float(xs_fsign(g_Velocity[id][0])) * 16.0;
					futureOrigin[0] = collisionPoint[0] - x;

				}
				if (xs_fabs(leadingBoundary[1]) - xs_fabs(collisionPoint[1]) < 0.0)
				{
					new Float:y = float(xs_fsign(g_Velocity[id][1])) * 16.1;
					futureOrigin[1] = collisionPoint[1] - y;
				}
				if (!IsPlayerInsideWall(id, futureOrigin, leadingBoundary, collisionPoint))
					set_pev(id, pev_origin, futureOrigin); // else player is not teleported, just keeps velocity
			}
			else
				set_pev(id, pev_origin, futureOrigin);

			g_hasSlopebugged[id] = true;
		}
	}

	if (g_HBFrameCounter[id] > 0)
		CheckHealthBoost(id);

	if (g_Speedcap[id] && endSpeed > g_Speedcap[id])
	{
		new Float:m = (endSpeed / g_Speedcap[id]) * 1.000001;
		new Float:cappedVelocity[3];
		cappedVelocity[0] = currVelocity[0] / m;
		cappedVelocity[1] = currVelocity[1] / m;
		cappedVelocity[2] = currVelocity[2];
		set_pev(id, pev_velocity, cappedVelocity);
	}

	if (!g_RestoreSolidStates)
		return;

	g_RestoreSolidStates = false;

	static i;
	for (i = 1; i <= g_MaxPlayers; i++)
	{
		if (IsConnected(i) && g_SolidState[i] >= 0)
			set_pev(i, pev_solid, g_SolidState[i]);
	}

	//pev(id, pev_velocity, g_Velocity[id]);
	//pev(id, pev_angles, g_Angles[id]);
}

/* TODO: Review this dead code. There's NOT a forward pointing here, so it's never called and I don't know it should be
public Fw_FmAddToFullPackPre(es, e, ent, host, hostflags, player, pSet)
{
	if (!player || ent == host)
		return FMRES_IGNORED;

	if(get_bit(g_bit_invis, host))
	{
		forward_return(FMV_CELL, 0);
		return FMRES_SUPERCEDE;
	}
	return FMRES_HANDLED;
}
*/

public Fw_FmAddToFullPackPost(es, e, ent, host, hostflags, player, pSet)
{
	if (!player)
	{
		if (get_bit(g_bit_waterinvis, host) && !IsHltv(host) && !IsConnected(ent) && IsConnected(host) && pev_valid(ent))
		{
			static className[32];
			pev(ent, pev_classname, className, charsmax(className));
			if (equali(className, "func_water") || equali(className, "func_conveyor"))
				set_es(es, ES_Effects, get_es(es, ES_Effects) | EF_NODRAW);

			else if (equali(className, "func_illusionary"))
			{
				new iContent = pev(ent, pev_skin);
				// CONTENTS_ORIGIN is Volumetric light, which is the only content option other than Empty
				// in some map editors and is used for liquids too
				if (iContent == CONTENTS_WATER || iContent == CONTENTS_ORIGIN
					|| iContent == CONTENTS_LAVA || iContent == CONTENTS_SLIME)
					set_es(es, ES_Effects, get_es(es, ES_Effects) | EF_NODRAW);
			}

		}
		return FMRES_IGNORED;
	}
	else if (player && (g_Nightvision[host] == 1) && (ent == host))
		set_es(es, ES_Effects, get_es(es, ES_Effects) | EF_BRIGHTLIGHT);

	if (ent == host || IsHltv(host) || !IsConnected(ent) || !IsConnected(host) || !get_pcvar_num(pcvar_kz_semiclip) || pev(host, pev_iuser1) || !get_orig_retval())
		return FMRES_IGNORED;

	if(get_bit(g_bit_invis, host))
	{
		set_es(es, ES_RenderMode, kRenderTransTexture);
		set_es(es, ES_RenderAmt, 0);
		set_es(es, ES_Origin, { 999999999.0, 999999999.0, 999999999.0 } );
		return FMRES_IGNORED;
	}

	// Update player (host) with setting all players as not solid ...
	set_es(es, ES_Solid, SOLID_NOT);
	// and transparent depending on the distance
	static Float:dist, amount;
	dist = entity_range(ent, host) + 50;
	if (dist > 255.0)
		return FMRES_HANDLED;
	amount = floatround(floatclamp(dist, 0.0, 255.0), floatround_tozero);
	if (amount >= 255)
		return FMRES_HANDLED;
	set_es(es, ES_RenderAmt, amount);
	set_es(es, ES_RenderMode, kRenderTransAlpha);

	return FMRES_HANDLED;
}

public Fw_FmLightStyle(style, const value[]) {
	if(!style) {
		copy(g_MapDefaultLightStyle, charsmax(g_MapDefaultLightStyle), value);
	}
}


//*******************************************************
//*                                                     *
//* Map tuning                                          *
//*                                                     *
//*******************************************************

/*
kz_create_button(id, type, Float:pOrigin[3] = {0.0, 0.0, 0.0})
{
	new ent= engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_button"));
	if (!pev_valid(ent))
		return PLUGIN_HANDLED;

	set_pev(ent, pev_classname, type == BUTTON_START ? "hlkz_start" : "hlkz_finish");
	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_movetype, MOVETYPE_NONE);
	set_pev(ent, pev_target, type == BUTTON_START ? "counter_start" : "counter_off");
	engfunc(EngFunc_SetModel, ent, "models/w_jumppack.mdl");
	entity_set_float(ent, EV_FL_framerate, 1.0);
	entity_set_int(ent, EV_INT_sequence, 0);
	engfunc(EngFunc_SetSize, ent, {-16.0, -16.0, 0.0}, {16.0, 16.0, 16.0});

	if (IsPlayer(id))
	{
		new Float:vOrigin[3];
		fm_get_aim_origin(id, vOrigin);
		vOrigin[2] += 25.0;
		engfunc(EngFunc_SetOrigin, ent, vOrigin);
	}
	else
		engfunc(EngFunc_SetOrigin, ent, pOrigin);

	switch(type)
	{
		case BUTTON_START: fm_set_rendering(ent, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 100);
		case BUTTON_FINISH: fm_set_rendering(ent, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 100);
	}

	return PLUGIN_HANDLED;
}
// */

RemoveFuncFriction()
{
	new frictionEntity = FM_NULLENT, i = 0;
	while(frictionEntity = find_ent_by_class(frictionEntity, "func_friction"))
	{
		remove_entity(frictionEntity);
		i++;
	}
	server_print("[%s] %d func_friction entities removed", PLUGIN_TAG, i);
}

// Stops from moving the blocks that move automatically without player interaction
StopMovingPlatforms()
{
	new classNames[][] = {"func_rotating", "func_train"};
	for (new i = 0; i < sizeof(classNames); i++)
	{
		new movingPlatform = FM_NULLENT, j = 0;
		while(movingPlatform = find_ent_by_class(movingPlatform, classNames[i]))
		{
			set_pev(movingPlatform, pev_speed, 0.0);
			j++;
		}
		server_print("[%s] %d %s entities have been stopped", PLUGIN_TAG, j, classNames[i]);
	}
}

CheckSpawns()
{
	new Array:spawns = ArrayCreate(1);
	new id;
	while((id = find_ent_by_class(id, "info_player_deathmatch")) != 0)
	{
		ArrayPushCell(spawns, id);
	}
	if (ArraySize(spawns) == 0 && (id = find_ent_by_class(id, "info_player_start")) != 0)
	{
		ArrayPushCell(spawns, id);
	}

	new Float:maxDistance;
	new spawnsNum = ArraySize(spawns);
	server_print("[%s] There are %d spawns in this map:", PLUGIN_TAG, spawnsNum);
	for (new i = 0; i < spawnsNum; i++)
	{
		id = ArrayGetCell(spawns, i);
		new Float:origin[3];
		pev(id, pev_origin, origin);

		for (new j = 0; j < spawnsNum; j++)
		{
			if (i == j)
				continue;

			new id2 = ArrayGetCell(spawns, j);
			new Float:origin2[3];
			pev(id2, pev_origin, origin2);

			new Float:distance = get_distance_f(origin, origin2);
			if (distance > maxDistance)
				maxDistance = distance;
		}
		//server_print("Spawn #%d {%.2f, %.2f, %.2f}", i+1, origin[0], origin[1], origin[2]);
	}
	server_print("[%s] Longest distance between 2 spawns: %.2f", PLUGIN_TAG, maxDistance);

	if (maxDistance > MIN_DISTANCE_RESPAWN_ADVANTAGE)
		g_bCanTakeAdvantageOfRespawn = true;
}

CheckMapWeapons()
{
	for (new i = 0; i < sizeof(g_BoostWeapons); i++)
	{
		if (find_ent_by_class(-1, g_BoostWeapons[i]))
		{
			g_isAnyBoostWeaponInMap = true;
			break;
		}
	}
	server_print("[%s] The current map %s weapons to boost with", PLUGIN_TAG, g_isAnyBoostWeaponInMap ? "has" : "doesn't have");
}

// Sets the bitfield for each run ending requirement depending on the map
SetMapEndReqs()
{
	if (equali(g_Map, "hl1_bhop_am", 11))
	{
		TrieSetCell(g_MapEndReqs, "am_btn_suit", REQ_AM_BTN_SUIT);
		TrieSetCell(g_MapEndReqs, "am_take_suit", REQ_AM_TAKE_SUIT);

		g_MapEndTotalReq = REQ_AM_BTN_SUIT | REQ_AM_TAKE_SUIT;
	}
	else if (equali(g_Map, "hl1_bhop_uc1", 12))
	{
		TrieSetCell(g_MapEndReqs, "uc1_take_crowbar", REQ_UC1_TAKE_CROWBAR);
		TrieSetCell(g_MapEndReqs, "uc1_take_glock", REQ_UC1_TAKE_GLOCK);
		
		g_MapEndTotalReq = REQ_UC1_TAKE_CROWBAR | REQ_UC1_TAKE_GLOCK;
	}
	else if (equali(g_Map, "hl1_bhop_uc2", 12))
	{
		TrieSetCell(g_MapEndReqs, "uc2_btn_water", REQ_UC2_BTN_WATER);
		TrieSetCell(g_MapEndReqs, "uc2_btn_lift", REQ_UC2_BTN_LIFT);
		
		g_MapEndTotalReq = REQ_UC2_BTN_WATER | REQ_UC2_BTN_LIFT;
	}
	else if (equali(g_Map, "hl1_bhop_ocwgh", 14))
	{
		TrieSetCell(g_MapEndReqs, "ocwgh_btn_electricity", REQ_OCWGH_BTN_ELECTRICITY);
		TrieSetCell(g_MapEndReqs, "ocwgh_take_nades", REQ_OCWGH_TAKE_NADES);
		TrieSetCell(g_MapEndReqs, "ocwgh_btn_silo_door", REQ_OCWGH_BTN_SILO_DOOR);

		g_MapEndTotalReq = REQ_OCWGH_BTN_ELECTRICITY | REQ_OCWGH_TAKE_NADES | REQ_OCWGH_BTN_SILO_DOOR;
	}
	else if (equali(g_Map, "hl1_bhop_bp1", 12))
	{
		TrieSetCell(g_MapEndReqs, "bp1_btn_lift_door", REQ_BP1_LIFT_DOOR);
		TrieSetCell(g_MapEndReqs, "bp1_take_health", REQ_BP1_TAKE_HEALTH);
		TrieSetCell(g_MapEndReqs, "bp1_take_batteries", REQ_BP1_TAKE_BATTERIES);
		TrieSetCell(g_MapEndReqs, "bp1_btn_lift", REQ_BP1_LIFT);

		g_MapEndTotalReq = REQ_BP1_LIFT_DOOR | REQ_BP1_TAKE_HEALTH | REQ_BP1_TAKE_BATTERIES | REQ_BP1_LIFT;
	}
	else if (equali(g_Map, "hl1_bhop_bp2", 12))
	{
		//TrieSetCell(g_MapEndReqs, "bp2_btn_bucket", REQ_BP2_BTN_BUCKET);
		TrieSetCell(g_MapEndReqs, "bp2_btn_electro2", REQ_BP2_BTN_ELECTRO2);
		TrieSetCell(g_MapEndReqs, "bp2_btn_electro1", REQ_BP2_BTN_ELECTRO1);

		g_MapEndTotalReq = /*REQ_BP2_BTN_BUCKET |*/ REQ_BP2_BTN_ELECTRO2 | REQ_BP2_BTN_ELECTRO1;

		TrieSetCell(g_UnorderedReqsMaps, g_Map, true);
	}
	server_print("[%s] Map requirements bitfield value: %d", PLUGIN_TAG, g_MapEndTotalReq);
}

public CmdSetStartHandler(id, level, cid)
{
	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		ShowMessage(id, "You must be alive to use this command");
		return PLUGIN_HANDLED;
	}
	if (!IsValidPlaceForCp(id))
	{
		ShowMessage(id, "You must be on the ground");
		return PLUGIN_HANDLED;
	}

	if (cmd_access(id, level, cid, 1))
	{
		new file = fopen(g_MapIniFile, "wt");
		if (!file)
		{
			ShowMessage(id, "Failed to write map ini file");
			return PLUGIN_HANDLED;
		}

		CreateCp(id, CP_TYPE_DEFAULT_START);
		g_MapDefaultStart = g_ControlPoints[id][CP_TYPE_DEFAULT_START];

		new uniqueid[32], name[32];
		GetUserUniqueId(id, uniqueid, charsmax(uniqueid));
		GetColorlessName(id, name, charsmax(name));
		new Float:time = get_gametime();
		console_print(0, "[%.3f] %s (%s) is setting a default start point for %s (point = {%.2f, %.2f, %.2f})",
				time, name, uniqueid, g_Map,
				g_MapDefaultStart[CP_ORIGIN][0], g_MapDefaultStart[CP_ORIGIN][1], g_MapDefaultStart[CP_ORIGIN][2]);

		fprintf(file, "Start: %d, { %f, %f, %f }, { %f, %f, %f }, { %f, %f, %f }, { %f, %f, %f }, %f, %f, %d\n",
			g_MapDefaultStart[CP_FLAGS],
			g_MapDefaultStart[CP_ORIGIN][0], g_MapDefaultStart[CP_ORIGIN][1], g_MapDefaultStart[CP_ORIGIN][2],
			g_MapDefaultStart[CP_ANGLES][0], g_MapDefaultStart[CP_ANGLES][1], g_MapDefaultStart[CP_ANGLES][2],
			g_MapDefaultStart[CP_VIEWOFS][0], g_MapDefaultStart[CP_VIEWOFS][1], g_MapDefaultStart[CP_VIEWOFS][2],
			g_MapDefaultStart[CP_VELOCITY][0], g_MapDefaultStart[CP_VELOCITY][1], g_MapDefaultStart[CP_VELOCITY][2],
			g_MapDefaultStart[CP_HEALTH], g_MapDefaultStart[CP_ARMOR], g_MapDefaultStart[CP_LONGJUMP]);

		fclose(file);

		// Propagate to clients
		for (new i = 1; i <= g_MaxPlayers; i++)
			g_ControlPoints[i][CP_TYPE_DEFAULT_START] = g_MapDefaultStart;

		ShowMessage(id, "Map start position set");
	}

	return PLUGIN_HANDLED;
}

public CmdClearStartHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new file = fopen(g_MapIniFile, "wt");
		if (!file)
		{
			ShowMessage(id, "Failed to write map ini file");
			return PLUGIN_HANDLED;
		}

		// In the future we will store health boxes here. Now just wipe out this file

		fclose(file);

		g_MapDefaultStart[CP_VALID] = false;

		ShowMessage(id, "Map start position cleared");
	}

	return PLUGIN_HANDLED;
}

public CmdReady(id)
{
	if (g_bMatchRunning)
	{
		client_print(id, print_chat, "[%s] You're not allowed to ready the match is already running.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (!(id == g_CupPlayer1 || id == g_CupPlayer2))
	{
		client_print(id, print_chat, "[%s] You're not allowed to ready because you are not a participant in the current cup match.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (CountCupMaps(MAP_IDLE))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, there are still maps to be banned/picked.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (!IsCupMap())
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet. You must be in one of the maps to be played.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	// Set the players readiness
	new bool:ready;
	if (id == g_CupPlayer1)
	{
		g_CupReady1 = !g_CupReady1;
		ready = g_CupReady1;
		server_print("player1 is %s", ready ? "ready" : "NOT ready");
	}
	
	if (id == g_CupPlayer2)
	{
		g_CupReady2 = !g_CupReady2;
		ready = g_CupReady2;
		server_print("player1 is %s", ready ? "ready" : "NOT ready");
	}

	new playerName[32];
	GetColorlessName(id, playerName, charsmax(playerName));
	if (ready)
	{
		if (playerName[0])
			client_print(0, print_chat, "[%s] Player %s is now ready!", PLUGIN_TAG, playerName);
		else // someone may have as nick just a color code, like ^8, and appear like empty string here
			client_print(0, print_chat, "[%s] The unnamed player is now ready!", PLUGIN_TAG);
	}
	else
	{
		if (playerName[0])
			client_print(0, print_chat, "[%s] Player %s is NOT ready now!", PLUGIN_TAG, playerName);
		else
			client_print(0, print_chat, "[%s] The unnamed player is NOT ready now!", PLUGIN_TAG);
	}

	if (g_CupReady1 && g_CupReady2)
	{
		client_print(0, print_chat, "[%s] Starting in 5 seconds... non-participants will now be switched to spectator mode.", PLUGIN_TAG);
		set_task(1.5, "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS);
		set_task(4.9, "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS + 1); // just in case someone's being an idiot
		set_task(5.0, "CupStartMatch", TASKID_CUP_START_MATCH);
	}

	return PLUGIN_HANDLED;
}

bool:IsCupMap()
{
	// Check if the current map is one of the maps to be played
	new map[32], mapState, bool:result;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetKey(ti, map, charsmax(map));
		TrieIterGetCell(ti, mapState);

		if ((mapState == MAP_PICKED || mapState == MAP_DECIDER) && equali(g_Map, map))
		{
			result = true;
			break;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

public CupForceSpectators(taskId)
{
	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		if (id == g_CupPlayer1 || id == g_CupPlayer2)
			continue;

		if (!pev(id, pev_iuser1)) // not spectator? force them )))
			server_cmd("agforcespectator #%d", get_user_userid(id));
	}
	server_exec();

	return PLUGIN_HANDLED;
}

public CupStartMatch(taskId)
{
	new bool:areParticipantsSpectating;
	if (pev(g_CupPlayer1, pev_iuser1))
	{
		areParticipantsSpectating = true;
		new playerName[32];
		GetColorlessName(g_CupPlayer1, playerName, charsmax(playerName));
		client_print(0, print_chat, "[%s] Cannot start the match because the participant %s is spectating!", PLUGIN_TAG, playerName);
	}
	// FIXME: DRY, but the message should appear per each participant that is spectating,
	// or maybe doesn't really matter and can be dumbed down
	if (pev(g_CupPlayer2, pev_iuser1))
	{
		areParticipantsSpectating = true;
		new playerName[32];
		GetColorlessName(g_CupPlayer2, playerName, charsmax(playerName));
		client_print(0, print_chat, "[%s] Cannot start the match because the participant %s is spectating!", PLUGIN_TAG, playerName);
	}

	if (areParticipantsSpectating)
		return PLUGIN_HANDLED;

	server_cmd("agstart");
	server_exec();

	return PLUGIN_HANDLED;
}

public CupChangeMap(map[], taskId)
{
	server_cmd("changelevel %s", map);
	//server_exec();

	return PLUGIN_HANDLED;
}

// Made to support specifically Bo3 and Bo5 with an odd number of maps in the pool,
// any other settings may result in unfair cups
public CmdCupHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new cupMatches[6], target1[32], target2[32];
		read_argv(1, cupMatches, charsmax(cupMatches));
		read_argv(2, target1, charsmax(target1));
		read_argv(3, target2, charsmax(target2));

		new player1 = cmd_target(id, target1, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS);
		new player2 = cmd_target(id, target2, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS);

		if (!player1)
		{
			ShowMessage(id, "Cannot find the first player specified in the kz_cup command");
			return PLUGIN_HANDLED;
		}

		if (!player2)
		{
			ShowMessage(id, "Cannot find the second player specified in the kz_cup command");
			return PLUGIN_HANDLED;
		}

		g_CupMatches = str_to_num(cupMatches);
		g_CupPlayer1 = player1;
		g_CupPlayer2 = player2;
		GetUserUniqueId(player1, g_CupSteam1, charsmax(g_CupSteam1));
		GetUserUniqueId(player2, g_CupSteam2, charsmax(g_CupSteam2));
		g_CupScore1 = 0;
		g_CupScore2 = 0;
		g_CupReady1 = false;
		g_CupReady2 = false;
		g_PrevChooser = 0;
		g_FirstBanner = 0;
		ResetCupMapStates(id);

		if (g_CupMatches + 2 == TrieGetSize(g_CupMapPool))
		{
			client_print(0, print_chat, "[%s] Flipping a coin to decide who bans first...", PLUGIN_TAG);
			set_task(2.0, "CupTensionFirstBan", TASKID_CUP_TENSION_FIRST_BAN);
		}
		else
		{
			g_FirstBanner = g_CupPlayer1;
			createMapMenu(g_FirstBanner, MAP_BAN_MENU_ID);
		}
		WriteCupFile(id);
	}

	return PLUGIN_HANDLED;
}

public CupTensionFirstBan(taskId)
{
	client_print(0, print_chat, "[%s] ...can you guess who bans first?", PLUGIN_TAG);
	set_task(3.0, "CupFinallyFirstBan", TASKID_CUP_FINALLY_FIRST_BAN);
}

public CupFinallyFirstBan(taskId)
{
	new id, rand = random_num(0, 1);
	if (rand)
		id = g_CupPlayer2;
	else
		id = g_CupPlayer1;

	new playerName[32];
	GetColorlessName(id, playerName, charsmax(playerName));
	client_print(0, print_chat, "[%s] Okay, %s bans first!", PLUGIN_TAG, playerName[0] ? playerName : "the unnamed player");

	g_FirstBanner = id;
	createMapMenu(g_FirstBanner, MAP_BAN_MENU_ID);
}

public CmdMapsShowHandler(id)
{
	new msg[512], map[32];
	formatex(msg, charsmax(msg), "Map pool:\n");

	// Add first the decider
	new Array:decidersMaps = GetCupMapsWithState(MAP_DECIDER);
	for (new i = 0; i < ArraySize(decidersMaps); i++)
	{
		ArrayGetString(decidersMaps, i, map, charsmax(map));
		formatex(msg, charsmax(msg), "%s > %s - [DECIDER]\n", msg, map);
		server_print("getting decider map %s", map);
	}

	// Then the picked ones
	new Array:pickedMaps = GetCupMapsWithState(MAP_PICKED);
	for (new i = 0; i < ArraySize(pickedMaps); i++)
	{
		ArrayGetString(pickedMaps, i, map, charsmax(map));
		formatex(msg, charsmax(msg), "%s > %s - [PICKED]\n", msg, map);
		server_print("getting picked map %s", map);
	}

	// Then the played ones
	new Array:playedMaps = GetCupMapsWithState(MAP_PLAYED);
	for (new i = 0; i < ArraySize(playedMaps); i++)
	{
		ArrayGetString(playedMaps, i, map, charsmax(map));
		formatex(msg, charsmax(msg), "%s > %s - [PLAYED]\n", msg, map);
		server_print("getting played map %s", map);
	}

	// Then the banned ones
	new Array:bannedMaps = GetCupMapsWithState(MAP_BANNED);
	for (new i = 0; i < ArraySize(bannedMaps); i++)
	{
		ArrayGetString(bannedMaps, i, map, charsmax(map));
		formatex(msg, charsmax(msg), "%s > %s - [BANNED]\n", msg, map);
		server_print("getting banned map %s", map);
	}

	// Then the maps that remain untouched yet
	new Array:idleMaps = GetCupMapsWithState(MAP_IDLE);
	for (new i = 0; i < ArraySize(idleMaps); i++)
	{
		ArrayGetString(idleMaps, i, map, charsmax(map));
		formatex(msg, charsmax(msg), "%s > %s\n", msg, map);
		server_print("getting idle map %s", map);
	}

	set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], _, 0.2, 0, 0.0, 6.0, 0.0, 1.0, -1);
	ShowSyncHudMsg(id, g_SyncHudCupMaps, msg);

	return PLUGIN_HANDLED;
}

Array:GetCupMapsWithState(stateNumber)
{
	new Array:result = ArrayCreate(32, 7);

	new map[32], mapState;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetCell(ti, mapState);
		if (mapState == stateNumber)
		{
			TrieIterGetKey(ti, map, charsmax(map));
			ArrayPushString(result, map);
			server_print("pushed map %s", map);
		}
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

public CmdMapInsertHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		// Insert up to 5 maps at a time
		new maps[5][32], poolLimit = get_pcvar_num(pcvar_kz_cup_max_maps);
		for (new i = 0; i < sizeof(maps); i++) {
			read_argv(i+1, maps[i], charsmax(maps[]));

			if (maps[i][0])
			{
				if (TrieGetSize(g_CupMapPool) < poolLimit) {
					TrieSetCell(g_CupMapPool, maps[i], MAP_IDLE);
				} else {
					console_print(id, "[%s] Couldn't add %s to the map pool, the limit of %d maps has been reached.", PLUGIN_TAG, maps[i], poolLimit);
				}
			}
		}

		WriteCupMapPoolFile(id);
	}

	return PLUGIN_HANDLED;
}

public CmdMapDeleteHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		// Remove up to 5 maps at a time
		new maps[5][32];
		for (new i = 0; i < sizeof(maps); i++) {
			read_argv(i+1, maps[i], charsmax(maps[]));

			if (maps[i][0] && !TrieDeleteKey(g_CupMapPool, maps[i])) {
				console_print(id, "[%s] Couldn't remove %s from the map pool. Maybe it wasn't in the pool.", PLUGIN_TAG, maps[i]);
			}
		}

		WriteCupMapPoolFile(id);
	}

	return PLUGIN_HANDLED;
}

// Set the map state you want to some map
public CmdMapStateHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new map[32], action[8];
		read_argv(1, map, charsmax(map));
		read_argv(2, action, charsmax(action));

		new mapState;
		for (new i = 0; i < sizeof(g_MapStateString); i++)
		{
			if (equali(g_MapStateString[i], action))
			{
				mapState = i;
				break;
			}
		}

		if (TrieKeyExists(g_CupMapPool, map))
		{
			TrieSetCell(g_CupMapPool, map, mapState);
			client_print(0, print_chat, "[%s] %s's new state is: %s.",
				PLUGIN_TAG, map, g_MapStateString[mapState][0] ? g_MapStateString[mapState] : "idle");
		}
		else
			client_print(id, print_chat, "[%s] Sorry, the specified map is not in the pool.", PLUGIN_TAG);

		WriteCupMapPoolFile(id);
	}

	return PLUGIN_HANDLED;
}

public CmdMapsClearHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		TrieClear(g_CupMapPool);
		client_print(id, print_chat, "[%s] The map pool has been cleared.", PLUGIN_TAG);
	}
	return PLUGIN_HANDLED;
}

public CmdResetCupMapStates(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		ResetCupMapStates(id);
	}
	return PLUGIN_HANDLED;
}

ResetCupMapStates(id)
{
	new i;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti)) {
		new map[32];
		TrieIterGetKey(ti, map, charsmax(map));

		if (TrieSetCell(g_CupMapPool, map, MAP_IDLE))
			i++;
		
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (id)
		client_print(id, print_chat, "[%s] All the %d maps have been reset to IDLE state.", PLUGIN_TAG, i);
	else
		server_print("[%s] All the %d maps have been reset to IDLE state.", PLUGIN_TAG, i);
}

// Clears the cached cup data, including the map states
public CmdClearCup(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		ClearCup(id);
	}
	return PLUGIN_HANDLED;
}

ClearCup(id)
{
	g_CupMatches = 0;
	g_CupPlayer1 = 0;
	g_CupPlayer2 = 0;
	g_CupSteam1[0] = EOS;
	g_CupSteam2[0] = EOS;
	g_CupScore1 = 0;
	g_CupScore2 = 0;
	g_CupReady1 = false;
	g_CupReady2 = false;
	g_PrevChooser = 0;
	g_FirstBanner = 0;
	ResetCupMapStates(id);
}

// Writes to a file the map pool in its current state
WriteCupMapPoolFile(id)
{
	new file = fopen(g_MapPoolFile, "wt");
	if (!file)
	{
		ShowMessage(id, "Failed to write map pool file");
		return;
	}

	console_print(id, "Current maps:");
	new map[32], mapState, TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti)) {
		TrieIterGetKey(ti, map, charsmax(map));
		TrieIterGetCell(ti, mapState);

		if (g_MapStateString[mapState][0])
			console_print(id, " - %s -> %s", map, g_MapStateString[mapState]);
		else
			console_print(id, " - %s", map);

		fprintf(file, "%s %d\n", map, mapState);
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);
	fclose(file);
}

// Writes to a file the map pool in its current state
WriteCupFile(id)
{
	new file = fopen(g_CupFile, "wt");
	if (!file)
	{
		ShowMessage(id, "Failed to write cup file");
		return;
	}

	if (g_CupMatches && g_CupSteam1[0] && g_CupSteam2[0])
	{
		fprintf(file, "%d %s %s %d %d\n", g_CupMatches, g_CupSteam1, g_CupSteam2, g_CupScore1, g_CupScore2);
	}

	fclose(file);
}

public CmdSetCustomStartHandler(id)
{
	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		ShowMessage(id, "You must be alive to use this command");
		return PLUGIN_HANDLED;
	}
	if (!IsValidPlaceForCp(id))
	{
		ShowMessage(id, "You must be on the ground");
		return PLUGIN_HANDLED;
	}

	CreateCp(id, CP_TYPE_CUSTOM_START);
	ShowMessage(id, "Custom starting position set");

	return PLUGIN_HANDLED;
}

public CmdClearCustomStartHandler(id)
{
	g_ControlPoints[id][CP_TYPE_CUSTOM_START][CP_VALID] = false;

	ShowMessage(id, "Custom starting position cleared");

	return PLUGIN_HANDLED;
}

public CmdShowStartMsg(id)
{
	if (!get_pcvar_num(pcvar_kz_show_start_msg))
	{
		ShowMessage(id, "Start message display toggling is disabled by server");
		return PLUGIN_HANDLED;
	}

	new arg1[2];
 	read_argv(1, arg1, charsmax(arg1));

	ClearSyncHud(id, g_SyncHudTimer);
	ClearSyncHud(id, g_SyncHudKeys);
	ClearSyncHud(id, g_SyncHudShowStartMsg);

 	g_ShowStartMsg[id] = str_to_num(arg1);

 	return PLUGIN_HANDLED;
}

public CmdSlopefix(id)
{
	g_Slopefix[id] = !g_Slopefix[id];
	ShowMessage(id, "Slopebug/Surfbug fix is now %s", g_Slopefix[id] ? "enabled" : "disabled");
	return PLUGIN_HANDLED;
}

public CmdTimeDecimals(id)
{
	if (!get_pcvar_num(pcvar_kz_time_decimals))
	{
		ShowMessage(id, "Modifying the number of decimals to display is disabled by server");
		return PLUGIN_HANDLED;
	}

	new decimals = GetNumberArg();
 	if (decimals < 1)
 		decimals = 1;
 	else if (decimals > 6)
 		decimals = 6;

 	g_TimeDecimals[id] = decimals;

 	return PLUGIN_HANDLED;
}

public CmdSpeed(id)
{
	ClearSyncHud( id, g_SyncHudSpeedometer );
	g_ShowSpeed[id] = !g_ShowSpeed[id];
	client_print( id, print_chat, "Speed: %s", g_ShowSpeed[id] ? "ON" : "OFF" );

	return PLUGIN_HANDLED;
}

public CmdSpeedcap(id)
{
	new Float:allowedSpeedcap = get_pcvar_float(pcvar_kz_speedcap);
	new Float:speedcap = GetFloatArg();
	//console_print(id, "allowedSpeedcap = %.2f; speedcap = %.2f", allowedSpeedcap, speedcap);

	if (allowedSpeedcap && speedcap > allowedSpeedcap)
	{
		g_Speedcap[id] = speedcap;
		ShowMessage(id, "Server doesn't allow a higher speedcap than %.2f", allowedSpeedcap);
	} else {
		g_Speedcap[id] = speedcap;
	}
	ShowMessage(id, "Your horizontal speedcap is now: %.2f", g_Speedcap[id]);
	clr_bit(g_baIsPureRunning, id);

	return PLUGIN_HANDLED;
}

public SetPOV(id)
{
	new target = GetNumberArg();
	set_pev(id, pev_iuser2, target);

	return PLUGIN_HANDLED;
}

public CmdNightvision(id)
{
	new cvar_nightvision = get_pcvar_num(pcvar_kz_nightvision);
	if (!cvar_nightvision)
	{
		ShowMessage(id, "Nightvision is disabled by server");
		return PLUGIN_HANDLED;
	}

	new mode = GetNumberArg();
	if (mode >= 2 && cvar_nightvision == 2)
	{
		ShowMessage(id, "Only nightvision mode 1 is allowed by server");
		return PLUGIN_HANDLED;
	}
	else if (mode == 1 && cvar_nightvision == 3)
	{
		ShowMessage(id, "Only nightvision mode 2 is allowed by server");
		return PLUGIN_HANDLED;
	}

	if (mode >= 2)
	{
		message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id);
		write_byte(0);
		write_string("#");
		message_end();
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id);
		write_byte(0);
		write_string(g_MapDefaultLightStyle);
		message_end();
	}
 	g_Nightvision[id] = mode;

 	return PLUGIN_HANDLED;
}

LoadMapSettings()
{
	new file = fopen(g_MapIniFile, "rt");
	if (!file)
		return;

	//new Float:time = get_gametime();
	//console_print(0, "[%.3f] Loading map default start", time);

	new buffer[1024], pos;
	while (!feof(file))
	{
		fgets(file, buffer, charsmax(buffer));
		if (!strlen(buffer))
			continue;
		if (!equal(buffer, "Start: ", 7))
			continue;

		g_MapDefaultStart[CP_FLAGS] = GetNextNumber(buffer, pos);
		g_MapDefaultStart[CP_ORIGIN][0] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ORIGIN][1] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ORIGIN][2] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ANGLES][0] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ANGLES][1] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ANGLES][2] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VIEWOFS][0] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VIEWOFS][1] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VIEWOFS][2] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VELOCITY][0] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VELOCITY][1] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_VELOCITY][2] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_HEALTH] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_ARMOR] = _:GetNextFloat(buffer, pos);
		g_MapDefaultStart[CP_LONGJUMP] = GetNextNumber(buffer, pos);
		g_MapDefaultStart[CP_VALID] = true;
	}

	fclose(file);
}

LoadMapPool()
{
	g_CupMapPool = TrieCreate();

	new file = fopen(g_MapPoolFile, "rt");
	if (!file) return;

	new buffer[48];
	while(fgets(file, buffer, charsmax(buffer)))
	{
		// One map name and state per line
		new map[32], mapState[6];
		parse(buffer,
				map,		charsmax(map),
				mapState,	charsmax(mapState));

		TrieSetCell(g_CupMapPool, map, str_to_num(mapState));
	}
	fclose(file);
	server_print("[%s] Map pool loaded (%d).", PLUGIN_TAG, TrieGetSize(g_CupMapPool));
}

LoadCup()
{
	// Load current cup's info
	new file = fopen(g_CupFile, "rt");
	if (!file) return;

	new buffer[512];
	while(fgets(file, buffer, charsmax(buffer)))
	{
		new matches[6], id1[25], id2[25], score1[6], score2[6];
		parse(buffer,
				matches,	charsmax(matches),
				id1,		charsmax(id1),
				id2,		charsmax(id2),
				score1,		charsmax(score1),
				score2,		charsmax(score2));

		g_CupMatches = str_to_num(matches);
		copy(g_CupSteam1, charsmax(g_CupSteam1), id1);
		copy(g_CupSteam2, charsmax(g_CupSteam2), id2);
		g_CupScore1 = str_to_num(score1);
		g_CupScore2 = str_to_num(score2);
	}
	fclose(file);
	server_print("[%s] Cup loaded.", PLUGIN_TAG);
}

GetLastCupMapAvailable(map[], len)
{
	new TrieIter:ti = TrieIterCreate(g_CupMapPool), bool:isMapFound;
	while (!TrieIterEnded(ti))
	{
		new mapState;
		TrieIterGetCell(ti, mapState);

		if (mapState == MAP_IDLE)
		{
			if (!isMapFound)
			{
				TrieIterGetKey(ti, map, len);
				isMapFound = true;
			}
			else
			{
				new badMap[32];
				TrieIterGetKey(ti, badMap, charsmax(badMap));
				server_print("[%s] Error: trying to get the decider map... but there's more than 1 idle map (name: %s)",
					PLUGIN_TAG, badMap);
			}
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);
}

GetNextCupMapToPlay(map[], len)
{
	new mapState;

	// Check if the current map can be played
	TrieGetCell(g_CupMapPool, g_Map, mapState);
	if (mapState == MAP_PICKED) // if it's the decider and the only one remaining then it will be chosen later below
	{
		copy(map, len, g_Map);
		return;
	}

	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetCell(ti, mapState);

		if (mapState == MAP_PICKED)
		{
			TrieIterGetKey(ti, map, len);
			TrieIterDestroy(ti);
			return;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	// Take the decider map
	ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetCell(ti, mapState);

		if (mapState == MAP_DECIDER)
		{
			TrieIterGetKey(ti, map, len);
			TrieIterDestroy(ti);
			return;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	server_print("[%s] Error: trying to get the next map to play, but there's no map remaining to be played", PLUGIN_TAG);
}

CountCupMaps(theState)
{
	new result = 0;

	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		new mapState;
		TrieIterGetCell(ti, mapState);

		if (mapState == theState)
			result++;

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

CreateGlobalHealer()
{
	new Float:health = get_pcvar_float(pcvar_kz_autoheal_hp) * 2.0;
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "trigger_hurt"));
	dllfunc(DLLFunc_Spawn, ent);
	engfunc(EngFunc_SetSize, ent, Float:{-8192.0, -8192.0, -8192.0}, Float:{8192.0, 8192.0, 8192.0});
	set_pev(ent, pev_spawnflags, SF_TRIGGER_HURT_CLIENTONLYTOUCH);
	set_pev(ent, pev_dmg, -1.0 * health);
}




//*******************************************************
//*                                                     *
//* Records handling                                    *
//*                                                     *
//*******************************************************

GetUserUniqueId(id, uniqueid[], len)
{
	new type = get_pcvar_num(pcvar_kz_uniqueid);
	if (type < 1 || type > 3)
		type = 1;
	switch (type)
	{
	case 1: GetColorlessName(id, uniqueid, len);
	case 2: get_user_ip(id, uniqueid, len, 1);
	case 3: get_user_authid(id, uniqueid, len);
	}
}

LoadRecords(RUN_TYPE:topType)
{
	if (get_pcvar_num(pcvar_kz_mysql))
	{
		new query[1336];
		formatex(query, charsmax(query), "SELECT p.unique_id, pn.name, r.checkpoints, r.teleports, r.time, UNIX_TIMESTAMP(r.date) \
		                                    FROM run r \
		                                    INNER JOIN player p ON p.id = r.player \
		                                    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date \
		                                    INNER JOIN map m ON m.id = r.map \
		                                    WHERE \
		                                          r.is_valid = true \
		                                      AND m.name = '%s' \
		                                      AND r.type = '%s' \
		                                      AND r.time = (SELECT MIN(r2.time) \
		                                                    FROM run r2 \
		                                                    WHERE \
		                                                          r2.is_valid = true \
		                                                      AND r2.player = r.player \
		                                                      AND r2.map = r.map \
		                                                      AND r2.type = r.type) \
		                                    ORDER BY r.time ASC", g_EscapedMap, g_TopType[topType]);
		// This query takes around 50ms to run (min 30ms, max 72ms, out of 50 queries)
		new data[1];
		data[0] = topType;

		//console_print(0, query);

		mysql_query(g_DbConnection, "SelectRunsHandler", query, data, sizeof(data));
	}
	else
		LoadRecordsFile(topType);

}

LoadRecordsFile(RUN_TYPE:topType)
{
	console_print(0, "LoadRecordsFile :: trying to open %s", g_StatsFile[topType]);
	new file = fopen(g_StatsFile[topType], "r");
	if (!file) return;

	//console_print(0, "LoadRecordsFile :: file opened correctly");

	new data[1024], stats[STATS], uniqueid[32], name[32], cp[24], tp[24];
	new kztime[24], timestamp[24];

	new Array:arr = g_ArrayStats[topType];
	ArrayClear(arr);

	while (!feof(file))
	{
		fgets(file, data, charsmax(data));
		if (!strlen(data))
			continue;

		parse(data, uniqueid, charsmax(uniqueid), name, charsmax(name),
		cp, charsmax(cp), tp, charsmax(tp), kztime, charsmax(kztime), timestamp, charsmax(timestamp));

		stats[STATS_TIMESTAMP] = str_to_num(timestamp);

		copy(stats[STATS_ID], charsmax(stats[STATS_ID]), uniqueid);
		copy(stats[STATS_NAME], charsmax(stats[STATS_NAME]), name);
		stats[STATS_CP] = str_to_num(cp);
		stats[STATS_TP] = str_to_num(tp);
		stats[STATS_TIME] = _:str_to_float(kztime);

		//console_print(0, "STATS_ID: %s, STATS_TIME: %.3f", stats[STATS_ID], stats[STATS_TIME]);

		ArrayPushArray(arr, stats);
	}

	fclose(file);
}

SaveRecordsFile(RUN_TYPE:topType)
{
	new file = fopen(g_StatsFile[topType], "w+");
	if (!file) return;

	new stats[STATS];
	new Array:arr = g_ArrayStats[topType];

	for (new i; i < ArraySize(arr); i++)
	{
		ArrayGetArray(arr, i, stats);

		fprintf(file, "\"%s\" \"%s\" %d %d %.6f %i\n",
			stats[STATS_ID],
			stats[STATS_NAME],
			stats[STATS_CP],
			stats[STATS_TP],
			stats[STATS_TIME],
			stats[STATS_TIMESTAMP]);
	}

	fclose(file);
}

// Here instead of writing the whole file again, we just insert a few rows in the DB, so it's much less expensive in this case
SaveRecordDB(RUN_TYPE:topType, stats[STATS])
{
	//console_print(0, "SaveRecordDB(), copying stats into data...");

	new data[sizeof(stats)+1];
	data[0] = topType;
	datacopy(data, stats, sizeof(stats), 1, 0);
	/*
	new i = 1;
	while (i < sizeof(stats)+1)
	{
		data[i] = stats[i-1];
		i++;
	}
	*/
	//add(data, sizeof(stats)+1, stats);
	//data[1] = stats;

	new escapedUniqueId[64];
	mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), stats[STATS_ID]);

	new query[592];
	formatex(query, charsmax(query), "INSERT INTO player (unique_id) \
	                                SELECT '%s' \
	                                FROM (select 1) as a \
	                                WHERE NOT EXISTS( \
	                                    SELECT unique_id \
	                                    FROM player \
	                                    WHERE unique_id = '%s' \
	                                ) \
	                                LIMIT 1", escapedUniqueId, escapedUniqueId);

	// Here one callback will call another, and that one will call another, and another...
	// because we have to wait until the previous data has been inserted, and only if it has been inserted at all
	// so we insert the player if doesn't exist, then the name they were using at that time, then the run corresponding to that player
	mysql_query(g_DbConnection, "SelectRunnerId", query, data, sizeof(data));
}

// Refactor if somehow more than 2 tops have to be passed
// The second top is only in case you do a Pure that is
// better than your Pro record, so it gets updated in both
UpdateRecords(id, Float:kztime, RUN_TYPE:topType)
{
	new uniqueid[32], name[32], rank;
	new stats[STATS], insertItemId = -1, deleteItemId = -1;
	new minutes, Float:seconds, Float:slower, Float:faster;
	LoadRecords(topType);

	new Array:arr = g_ArrayStats[topType];

	GetUserUniqueId(id, uniqueid, charsmax(uniqueid));
	GetColorlessName(id, name, charsmax(name));

	new result;
	for (new i = 0; i < ArraySize(arr); i++)
	{
		ArrayGetArray(arr, i, stats);
		result = floatcmp(kztime, stats[STATS_TIME]);

		if (result == -1 && insertItemId == -1)
			insertItemId = i;

		if (!equal(stats[STATS_ID], uniqueid))
			continue;

		if (result != -1)
		{
			slower = kztime - stats[STATS_TIME];
			minutes = floatround(slower, floatround_floor) / 60;
			seconds = slower - (60 * minutes);
			if (!(get_bit(g_baIsPureRunning, id) && topType == PRO))
			{
				client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You failed your %s time by %02d:%"),
					PLUGIN_TAG, g_TopType[topType], minutes, seconds);
			}

			return;
		}

		faster = stats[STATS_TIME] - kztime;
		minutes = floatround(faster, floatround_floor) / 60;
		seconds = faster - (60 * minutes);
		client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You improved your %s time by %02d:%"),
			PLUGIN_TAG, g_TopType[topType], minutes, seconds);

		deleteItemId = i;

		break;
	}

	copy(stats[STATS_ID], charsmax(stats[STATS_ID]), uniqueid);
	copy(stats[STATS_NAME], charsmax(stats[STATS_NAME]), name);
	stats[STATS_CP] = g_CpCounters[id][COUNTER_CP];
	stats[STATS_TP] = g_CpCounters[id][COUNTER_TP];
	stats[STATS_TIME] = _:kztime;
	stats[STATS_TIMESTAMP] = get_systime();

	if (insertItemId != -1)
	{
		rank = insertItemId;
		ArrayInsertArrayBefore(arr, insertItemId, stats);
	}
	else
	{
		rank = ArraySize(arr);
		ArrayPushArray(arr, stats);
	}

	if (deleteItemId != -1)
		ArrayDeleteItem(arr, insertItemId != -1 ? deleteItemId + 1 : deleteItemId);

	rank++;
	if (rank <= get_pcvar_num(pcvar_kz_top_records))
	{
		client_cmd(0, "spk woop");
		client_print(0, print_chat, "[%s] %s is now on place %d in %s 15", PLUGIN_TAG, name, rank, g_TopType[topType]);
	}
	else
		client_print(0, print_chat, "[%s] %s's rank is %d of %d among %s players", PLUGIN_TAG, name, rank, ArraySize(arr), g_TopType[topType]);

	new mySQLStore = get_pcvar_num(pcvar_kz_mysql);
	if (mySQLStore)
		SaveRecordDB(topType, stats);

	if (mySQLStore != 1)
		SaveRecordsFile(topType);

	if (rank == 1)
	{
		new ret;
		ExecuteForward(mfwd_hlkz_worldrecord, ret, topType, arr);

		LaunchRecordFireworks();
	}

	if (g_RecordRun[id])
	{
		//fclose(g_RecordRun[id]);
		g_RecordRun[id] = 0;
		//ArrayClear(g_RunFrames[id]);
		//console_print(id, "stopped recording");
		SaveRecordedRun(id, topType);
	}
}

ShowTopClimbers(id, RUN_TYPE:topType)
{
	new buffer[1536], len;
	new stats[STATS], date[32], time[32], minutes, Float:seconds;
	LoadRecords(topType);
	new Array:arr = g_ArrayStats[topType];

	new cvarDefaultRecords = get_pcvar_num(pcvar_kz_top_records);
	new cvarMaxRecords = get_pcvar_num(pcvar_kz_top_records_max);

	// Get the info... from what record until what record we have to show
	new topArgs[2];
	GetRangeArg(topArgs); // e.g.: "say /pro 20-30" --> the '20' goes to topArgs[0] and '30' to topArgs[1]
	new recMin = min(topArgs[0], topArgs[1]);
	new recMax = max(topArgs[0], topArgs[1]);
	if (recMax > ArraySize(arr)) ShowMessage(id, "There are less records than requested");
	if (!recMax)	recMax = cvarDefaultRecords;
	if (recMin < 0) recMin = 0;
	if (recMax < 0) recMax = 1;
	if (recMin) 	recMin -= 1; // so that in "say /pro 1-20" it takes from 1 to 20 both inclusive
	// yeah this one below is duplicated, because recMax may have changed in the previous checks and the first check is only to notify the player
	if (recMax > ArraySize(arr)) recMax = ArraySize(arr); // there may be less records than the player is requesting, limit it to that amount
	if (recMax - cvarMaxRecords > recMin)
	{
		// limit max. records to show
		recMax = recMin + cvarMaxRecords;
		client_print(id, print_chat, "[%s] Sorry, not showing all the requested records because the server won't allow loading more than %d records at once", PLUGIN_TAG, cvarMaxRecords);
	}



	if (topType == NOOB)
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time       CP  TP         Date        Demo\n\n");
	else
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time              Date        Demo\n\n");

	new szTopType[32], szTopTypeUCFirst[32];
	formatex(szTopType, charsmax(szTopType), g_TopType[topType]);
	formatex(szTopType, charsmax(szTopType), g_TopType[topType]);
	ucfirst(szTopTypeUCFirst);

	for (new i = recMin; i < recMax && charsmax(buffer) - len > 0; i++)
	{
		static authid[32], idNumbers[24], replayFile[256];
		ArrayGetArray(arr, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[STATS_NAME][17] = EOS;

		minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
		seconds = stats[STATS_TIME] - (60 * minutes);

		formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%"), minutes, seconds);
		format_time(date, charsmax(date), "%d/%m/%Y", stats[STATS_TIMESTAMP]);

		// Check if there's demo for this record
		formatex(authid, charsmax(authid), "%s", stats[STATS_ID]);
		ConvertSteamID32ToNumbers(authid, idNumbers);

		formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
		new hasDemo = file_exists(replayFile);
		if (!hasDemo && topType == PRO && ComparePro2PureTime(stats[STATS_ID], stats[STATS_TIME]) == 0)
		{
	    	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_pure.dat", g_ReplaysDir, g_Map, idNumbers);
	        hasDemo = file_exists(replayFile);
		}

		if (topType == NOOB)
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s  %3d %3d        %s   %s\n", i + 1, stats[STATS_NAME], time, stats[STATS_CP], stats[STATS_TP], date, hasDemo ? "yes" : "no");
		else
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s         %s   %s\n", i + 1, stats[STATS_NAME], time, date, hasDemo ? "yes" : "no");
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "\n%s %s", PLUGIN, VERSION);

	new header[24];
	formatex(header, charsmax(header), "%s %d-%d Climbers", szTopTypeUCFirst, recMin ? recMin : 1, recMax);
	show_motd(id, buffer, header);

	return PLUGIN_HANDLED;
}

ComparePro2PureTime(runnerId[], Float:runnerTime)
{
	new stats[STATS];
	for (new i = 0; i < ArraySize(g_ArrayStats[PURE]); i++)
	{
		ArrayGetArray(g_ArrayStats[PURE], i, stats);

		if (equal(stats[STATS_ID], runnerId))
			return floatcmp(runnerTime, stats[STATS_TIME]);
	}
	return 1;
}

// Checks if the bounding box of the player has its nearest boundary to the wall inside that same wall
// The nearest boundary is the one that is frontmost, known thanks to the velocity of the player
public IsPlayerInsideWall(id, Float:origin[3], Float:leadingBoundary[3], Float:collisionPoint[3])
{
	// Get the player boundary that will be colliding against a wall due to velocity going in that direction
	new Float:x = float(xs_fsign(g_Velocity[id][0])); // 1 unit
	new Float:y = float(xs_fsign(g_Velocity[id][1])); // 1 unit
	leadingBoundary[0] = x * 15.01; // we go outwards from the center of the player, towards one of their boundaries
	leadingBoundary[1] = y * 15.11; // 15.1 tested ingame, + 0.1 so the distance to wall can later be checked as less or equal to 1.0, and yea probably not the best way

	if (g_bIsSurfingWithFeet[id])
		leadingBoundary[2] = (pev(id, pev_flags) & FL_DUCKING) ? -17.95 : -35.95; // the lower Z bound or feet position + 0.05
	else
		leadingBoundary[2] = 0.0;

	// Now this will have the point (of the player) that will collide against some wall
	xs_vec_add(origin, leadingBoundary, leadingBoundary);

	new Float:direction[3];
	// a bit more to the side than straight in case it were to end in the corner between the ramp and the side wall, so it goes more towards the wall (I may have to think this better)
	direction[0] = x - 0.01;
	direction[1] = y;
	direction[2] = 0.0; // the ray will go at the same height as the one defined for the boundary

	new Float:normal[3];
	GetNormalPlaneRelativeToPlayer(id, leadingBoundary, direction, collisionPoint, normal); // collisionPoint is (0.0, 0.0, 0.0) if not colliding against a side plane

	if (vector_length(collisionPoint) == 0.0)
		return false;
	if (xs_fabs(leadingBoundary[0]) - xs_fabs(collisionPoint[0]) < 0.0 || xs_fabs(leadingBoundary[1]) - xs_fabs(collisionPoint[1]) < 0.0)
		return true;
	else
		return false;
}

// Create a string that has the correct formating for seconds, that is a float
// with a variable number of decimals per user configuration
// This may actually be a silly thing due to my unknowledge about Pawn/AMXX
GetVariableDecimalMessage(id, msg1[], msg2[] = "")
{
	new sec[3]; // e.g.: number 6 in "%06.3f"
	new dec[3]; // e.g.: number 3 in "%06.3f"
	num_to_str(g_TimeDecimals[id], dec, charsmax(dec));
	new iSec = g_TimeDecimals[id] + 3; // the left part is the sum of all digits to be printed + 3 (= 2 digits for seconds + the dot)
	num_to_str(iSec, sec, charsmax(sec));

	new msg[192];
	strcat(msg, msg1, charsmax(msg));
	strcat(msg, "0", charsmax(msg));
	strcat(msg, sec, charsmax(msg));
	strcat(msg, ".", charsmax(msg));
	strcat(msg, dec, charsmax(msg));
	strcat(msg, "f ", charsmax(msg));
	strcat(msg, msg2, charsmax(msg));
	return msg;
}

RecordRunFrame(id)
{
	new Float:maxDuration = get_pcvar_float(pcvar_kz_max_replay_duration);
	new Float:kztime = get_gametime() - g_PlayerTime[id];
	if (kztime < maxDuration)
	{
		new frameState[REPLAY];
		frameState[RP_TIME] = get_gametime();
		frameState[RP_ORIGIN] = g_Origin[id];
		frameState[RP_ANGLES] = g_Angles[id];
		frameState[RP_BUTTONS] = pev(id, pev_button);
		ArrayPushArray(g_RunFrames[id], frameState);
		//console_print(id, "[%.3f] recording run...", frameState[RP_TIME]);
	}
}

SaveRecordedRun(id, RUN_TYPE:topType)
{
	static authid[32], replayFile[256], idNumbers[24];
	get_user_authid(id, authid, charsmax(authid));

	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, g_TopType[topType]);
	//console_print(id, "saving run to: '%s'", replayFile);

	g_RecordRun[id] = fopen(replayFile, "wb");
	//console_print(id, "opened replay file");

	//fwrite(g_RecordRun[id], DEMO_VERSION, BLOCK_SHORT); // version

	new frameState[REPLAY];
	for (new i; i < ArraySize(g_RunFrames[id]); i++)
	{
		ArrayGetArray(g_RunFrames[id], i, frameState);
		fwrite_blocks(g_RecordRun[id], frameState, sizeof(frameState) - 1, BLOCK_INT); // gametime, origin and angles
		fwrite(g_RecordRun[id], frameState[RP_BUTTONS], BLOCK_SHORT); // buttons
	}
	fclose(g_RecordRun[id]);
	//console_print(id, "saved %d frames to replay file", ArraySize(g_RunFrames[id]));
	g_RecordRun[id] = 0;
	ArrayClear(g_RunFrames[id]);
	//console_print(id, "clearing replay from memory");
}

SaveRecordedRunCup(id, RUN_TYPE:topType)
{
	static authid[32], replayFile[256], idNumbers[24];
	get_user_authid(id, authid, charsmax(authid));

	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(replayFile, charsmax(replayFile), "%s/cup_%s_%s_%s_%d.dat",
		g_ReplaysDir, g_Map, idNumbers, g_TopType[topType], ArraySize(g_RunFrames[id]));

	g_RecordRun[id] = fopen(replayFile, "wb");

	new frameState[REPLAY];
	for (new i; i < ArraySize(g_RunFrames[id]); i++)
	{
		ArrayGetArray(g_RunFrames[id], i, frameState);
		fwrite_blocks(g_RecordRun[id], frameState, sizeof(frameState) - 1, BLOCK_INT); // gametime, origin and angles
		fwrite(g_RecordRun[id], frameState[RP_BUTTONS], BLOCK_SHORT); // buttons
	}
	fclose(g_RecordRun[id]);

	g_RecordRun[id] = 0;
	ArrayClear(g_RunFrames[id]);
}

// Returns the entity that is linked to a bot
GetEntitysBot(ent)
{
	for (new i = 1; i <= sizeof(g_BotEntity) - 1; i++)
	{
		if (ent == g_BotEntity[i])
			return i;
	}
	return 0;
}

// Returns the bot that a player has spawned
GetOwnersBot(id)
{
	//console_print(1, "checking bots of player %d", id);
	for (new i = 1; i <= sizeof(g_BotOwner) - 1; i++)
	{	
		//console_print(1, "%d's owner is %d", i, g_BotOwner[i]);
		if (id == g_BotOwner[i])
			return i;
	}
	return 0;
}

PunishPlayerCheatingWithWeapons(id)
{
	if ((!g_isAnyBoostWeaponInMap && get_bit(g_baIsClimbing, id)) || equali(g_Map, "agtricks"))
		ResetPlayer(id, false, false); // "agstart full" is not allowed on maps without weapons
	else
		clr_bit(g_baIsPureRunning, id); // downgrade run from pure to pro
}

LaunchRecordFireworks()
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY); // create firework entity
	write_byte(TE_EXPLOSION);
	write_coord(floatround(g_PrevButtonOrigin[0]));	// start position
	write_coord(floatround(g_PrevButtonOrigin[1]));
	write_coord(floatround(g_PrevButtonOrigin[2]) + 100);
	write_short(g_Firework);	// sprite index
	write_byte(20); // scale
	write_byte(10);	// framerate
	write_byte(6);
	message_end();
	emit_sound(0, CHAN_AUTO, FIREWORK_SOUND, VOL_NORM, ATTN_NONE, 0, PITCH_NORM);
}

/**
 * Returns the numbers in the version, so 0.34 returns 34, or 1.0.2 returns 102.
 * This is to save as metadata in the replay files so we can know what version they're
 * to make proper changes to them (e.g.: convert from one version to another 'cos
 * replay data format is changed).
 * // Now using the DEMO_VERSION number instead
 */
 /*
GetVersionNumber()
{
	new szVersion[32], numberPart[32];
	add(szVersion, charsmax(szVersion), VERSION);

	// Get number part
	new len = strlen(szVersion);
    for (new i = 0; i < len; i++) {
        if (isdigit(szVersion[i])) {
        	add(numberPart, charsmax(numberPart), szVersion[i], 1);
    }

	//console_print(1, "%s --> %s --> %d", szVersion, numberPart, str_to_num(numberPart));
	return str_to_num(numberPart);
}
*/



//*******************************************************
//*                                                     *
//* MySQL query handling                                *
//*                                                     *
//*******************************************************

public DefaultInsertHandler(failstate, error[], errNo, what[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ DefaultInsertHandler(): [%d] - [%s] - [%s]", errNo, error, what);
		return;
	}
	server_print("[%.3f] Inserted %s, QueueTime:[%.3f]", get_gametime(), what, queuetime);
}

public SelectRunsHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
	log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SelectRunsHandler(): [%d] - [%s] - [%d]", errNo, error, data[1]);

	if (get_pcvar_num(pcvar_kz_mysql) == 2)
		LoadRecordsFile(data[0]);

	return;
	}

	//console_print(0, "SelectRunsHandler()");

	new RUN_TYPE:topType = data[0];
	new stats[STATS], uniqueId[32], name[32], cp, tp, Float:kztime, timestamp;

	new Array:arr = g_ArrayStats[topType];
	ArrayClear(arr);

	while (mysql_more_results())
	{
		mysql_read_result(0, uniqueId, charsmax(uniqueId));
		mysql_read_result(1, name, charsmax(name));
		cp = mysql_read_result(2);
		tp = mysql_read_result(3);
		mysql_read_result(4, kztime);
		timestamp = mysql_read_result(5);

		// FIXME check if this language allows to dump the data directly to the stats array
		//console_print(0, "ts %%d = %d", timestamp);

		stats[STATS_TIMESTAMP] = timestamp;
		copy(stats[STATS_ID], charsmax(stats[STATS_ID]), uniqueId);
		copy(stats[STATS_NAME], charsmax(stats[STATS_NAME]), name);
		stats[STATS_CP] = cp;
		stats[STATS_TP] = tp;
		stats[STATS_TIME] = _:kztime;

		//console_print(0, "time = %.3f", stats[STATS_TIME]);

		ArrayPushArray(arr, stats);

		mysql_next_row();
	}

	server_print("[%.3f] Selected %s runs, QueueTime:[%.3f]", get_gametime(), g_TopType[topType], queuetime);
}

// Gets the player id from the `player` table so we can use it to insert stuff in the `player_name` table
public SelectRunnerId(failstate, error[], errNo, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SelectRunnerId(): [%d] - [%s] - [%s]", errNo, error, data);
        return;
    }
    //new RUN_TYPE:topType = data[0];
    new stats[STATS];
    //add(stats, sizeof(stats), data[STATS]);
    //console_print(0, "sizeof(data) = %d", size);
    //console_print(0, "sizeof(stats) = %d", sizeof(stats));
    datacopy(stats, data, sizeof(stats), 0, 1);
/*
    console_print(0, "data[1]: %s", data[1]);
    console_print(0, "data[STATS_ID+1]: %s", data[STATS_ID+1]);
    console_print(0, "data[STATS_NAME+1]: %s", data[STATS_NAME+1]);
    console_print(0, "stats[STATS_NAME]: %s", stats[STATS_NAME]);
    console_print(0, "time: %.3f", stats[STATS_TIME]);
    console_print(0, "ts %%i: %i", stats[STATS_TIMESTAMP]);
    console_print(0, "ts %%d: %d", stats[STATS_TIMESTAMP]);
*/    

    server_print("[%.3f] Inserted runner %s, QueueTime:[%.3f]", get_gametime(), stats[STATS_ID], queuetime);

    if (stats[STATS_ID])
    {
      new escapedUniqueId[64], query[108];
      mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), stats[STATS_ID]);
      formatex(query, charsmax(query), "SELECT id FROM player WHERE unique_id = '%s'", escapedUniqueId);

      // Here one callback will call another, and that one will call another, and another...
      // because we have to wait until the previous data has been inserted, and only if it has been inserted at all
      // so we insert the player if doesn't exist, then the name they were using at that time, then the run corresponding to that player
      mysql_query(g_DbConnection, "InsertRunPlayerName", query, data, size);
    }
    else
    {
      // Something new must have been inserted in SaveRecordDB because there's no unique_id...
      // so we get directly the last inserted id
      new playerId = mysql_get_insert_id();
      DoQueryInsertRunPlayerName(data, size, playerId);
    }
}

// Gets the player id from the SELECT query result
public InsertRunPlayerName(failstate, error[], errNo, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_to_file(MYSQL_LOG_FILENAME, "ERROR @ InsertRunPlayerName(): [%d] - [%s] - [%s]", errNo, error, data);
        return;
    }
    //new RUN_TYPE:topType = data[0];
    //console_print(0, "topType: %d", topType);
    new stats[STATS];
    //copy(stats, sizeof(stats), data[1]);
    datacopy(stats, data, sizeof(stats), 0, 1);

    //console_print(0, "stats[STATS_ID]: %s", stats[STATS_ID]);
    new playerId;

    if (mysql_more_results())
    {
        playerId = mysql_read_result(0);
    }

    server_print("[%.3f] Selected runner #%d, QueueTime:[%.3f]", get_gametime(), playerId, queuetime);

    DoQueryInsertRunPlayerName(data, size, playerId);
}

// Launches the query to insert the player name that was in use when the record was one
DoQueryInsertRunPlayerName(data[], size, playerId)
{
    new stats[STATS];
    //copy(stats, sizeof(stats), data[1]);
    datacopy(stats, data, sizeof(stats), 0, 1);

    new escapedName[64], query[752];
    //console_print(0, "ts %%i: %i", stats[STATS_TIMESTAMP]);
    mysql_escape_string(escapedName, charsmax(escapedName), stats[STATS_NAME]);
    formatex(query, charsmax(query), "INSERT INTO player_name (player, name, date) \
                                      SELECT %d, '%s', FROM_UNIXTIME(%i) \
                                      FROM (select 1) as a \
                                      WHERE NOT EXISTS( \
                                          SELECT player, name, date \
                                          FROM player_name \
                                          WHERE player = %d AND name = '%s' AND date = FROM_UNIXTIME(%i) \
                                      ) \
                                      LIMIT 1", playerId, escapedName, stats[STATS_TIMESTAMP], playerId, escapedName, stats[STATS_TIMESTAMP]);


    //console_print(0, query);

    new newData[sizeof(stats)+2];
    newData[0] = data[0];
    newData[1] = playerId;
    //add(newData, charsmax(newData), data[1]);
    datacopy(newData, data, sizeof(stats), 2, 1);

    mysql_query(g_DbConnection, "InsertRun", query, newData, sizeof(newData));
}

// Launches the query to insert the run
public InsertRun(failstate, error[], errNo, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_to_file(MYSQL_LOG_FILENAME, "ERROR @ InsertRun(): [%d] - [%s] - [%s]", errNo, error, data);
        return;
    }
    new RUN_TYPE:topType = data[0];
    new playerId = data[1];
    new stats[STATS];
    //copy(stats, sizeof(stats), data[2]);
    datacopy(stats, data, sizeof(stats), 0, 2);

    server_print("[%.3f] Inserted name of the runner %s, QueueTime:[%.3f]", get_gametime(), stats[STATS_ID], queuetime);

    new escapedUniqueId[64], query[624];
    mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), stats[STATS_ID]);
    formatex(query, charsmax(query), "INSERT INTO run (player, map, type, time, date, checkpoints, teleports) \
                                      SELECT %d, %d, '%s', %.6f, FROM_UNIXTIME(%i), %d, %d \
                                      FROM (select 1) as a \
                                      WHERE NOT EXISTS( \
                                          SELECT player, map, type, time, date, checkpoints, teleports \
                                          FROM run \
                                          WHERE player = %d AND date = FROM_UNIXTIME(%i) AND type = '%s' \
                                      ) \
                                      LIMIT 1",
                                      playerId, g_MapId, g_TopType[topType], stats[STATS_TIME], stats[STATS_TIMESTAMP], stats[STATS_CP], stats[STATS_TP],
                                      playerId, stats[STATS_TIMESTAMP], g_TopType[topType]);

    new newData[1];
    newData[0] = topType;

    mysql_query(g_DbConnection, "InsertRunHandler", query, newData, sizeof(newData));
}

public InsertRunHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_to_file(MYSQL_LOG_FILENAME, "ERROR @ DefaultInsertHandler(): [%d] - [%s] - [%d]", errNo, error, data[0]);
        return;
    }
    server_print("[%.3f] Inserted run, QueueTime:[%.3f]", get_gametime(), queuetime);

    new RUN_TYPE:topType = data[0];

    // Load records and hope that they're retrieved before the client requests the data (e.g.: writes /pure)
    LoadRecords(topType);
}

// Gets the map id corresponding to the map that is currently being played
public SelectMapIdHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SelectMapIdHandler(): [%d] - [%s]", errNo, error);
        return;
    }

    if (mysql_more_results())
    {
      g_MapId = mysql_read_result(0);
    }

    server_print("[%.3f] Selected map #%d, QueueTime:[%.3f]", get_gametime(), g_MapId, queuetime);
}


/*

Query to get Pure WR Top:
SELECT p.id, p.realname, (SELECT COUNT(*)
                          FROM (SELECT r1.map, r1.player, MIN(r1.time) as wr
                                FROM run r1
                                WHERE r1.player = p.id AND r1.type = 'pure'
                                GROUP BY r1.map, r1.player) t1
                          INNER JOIN (SELECT r2.map, MIN(r2.time) AS wr
                                      FROM run r2
                                      WHERE r2.type = 'pure'
                                      GROUP BY r2.map) t2
                                      ON t1.map = t2.map AND t1.wr = t2.wr) wr_count
FROM player p
HAVING wr_count > 0
ORDER BY wr_count DESC


Query to get Pure WRs of a given player:
SELECT m.name, r.player, t1.time
FROM (SELECT r1.map, MIN(r1.time) as time
      FROM run r1
      WHERE r1.type = 'pure'
      GROUP BY r1.map) t1
INNER JOIN run r ON r.map = t1.map AND r.time = t1.time AND r.type = 'pure'
INNER JOIN map m ON m.id = t1.map
WHERE r.player = 72
ORDER BY m.name ASC

*/
