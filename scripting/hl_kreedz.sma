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
#include <engine>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <hl>
#include <hl_kreedz_util>


#define PLUGIN "HL KreedZ Beta"
#define PLUGIN_TAG "HLKZ"
#define VERSION "0.34" // take into account replays' version byte when updating version
#define AUTHOR "KORD_12.7 & Lev & YaLTeR & naz"

// Compilation options
//#define _DEBUG		// Enable debug output at server console.

#define MAX_PLAYERS 32

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

#define TASKID_ICON 5633445
#define TASKID_WELCOME 43321
#define TASKID_KICK_REPLAYBOT 9572626
#define TASKID_CAM_UNFREEZE 15622952

#define MAIN_MENU_ID	"HL KreedZ Menu"
#define TELE_MENU_ID	"HL KreedZ Teleport Menu"

new const configsSubDir[] = "/hl_kreedz";
new const pluginCfgFileName[] = "hl_kreedz.cfg";

//new const staleStatTime = 30 * 24 * 60 * 60;	// Keep old stat for this amount of time
//new const keepStatPlayers = 100;				// Keep this amount of players in stat even if stale

new const g_szStarts[][] =
{
	"hlkz_start", "counter_start", "clockstartbutton", "firsttimerelay", "but_start", "counter_start_button",
	"multi_start", "timer_startbutton", "start_timer_emi", "gogogo"
};

new const g_szStops[][] =
{
	"hlkz_finish", "counter_off", "clockstopbutton", "clockstop", "but_stop", "counter_stop_button",
	"multi_stop", "stop_counter", "m_counter_end_emi"
};

new const g_szTops[][] =
{
	"Pure", "Pro", "Noob"
};

enum _:REPLAY
{
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
	CP_TYPE_CUSTOM_START, // kz_set_custom_start position.
	CP_TYPE_START,        // Standard spawn or the start button.
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
}

enum BUTTON_TYPE
{
	BUTTON_START,
	BUTTON_FINISH,
	BUTTON_NOT,
}

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
new Array:g_RunFrames[MAX_PLAYERS + 1]; // current run frames, being stored here while the run is going on
new Array:g_ReplayFrames[MAX_PLAYERS + 1]; // frames to be replayed
new g_ReplayFramesIdx[MAX_PLAYERS + 1]; // How many frames have been replayed
new bool:g_Unfreeze[MAX_PLAYERS + 1];
new g_ReplayNum; // How many replays are running
new g_FrozenSpectators[MAX_PLAYERS + 1]; // spectators that saw a player teleporting and got their cam frozen

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

new g_HudRGB[3];
new g_SyncHudTimer;
new g_SyncHudMessage;
new g_SyncHudKeys;
new g_SyncHudHealth;
new g_SyncHudShowStartMsg;
new g_SyncHudSpeedometer;
new g_SyncHudSpecList;
new g_MaxPlayers;
new g_PauseSprite;
new g_TaskEnt;

new g_Map[64];
new g_ConfigsDir[256];
new g_ReplaysDir[256];
new g_StatsFileNub[256];
new g_StatsFilePro[256];
new g_StatsFilePure[256];

new g_MapIniFile[256];
new g_MapDefaultStart[CP_DATA];
new g_MapDefaultLightStyle[32];

new g_SpectatePreSpecMode;
new bool:g_InForcedRespawn;
new Float:g_LastHealth;
new bool:g_RestoreSolidStates;
new bool:g_bMatchRunning;

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

new g_FwLightStyle;

new pcvar_sv_ag_match_running;

new mfwd_hlkz_cheating;
new mfwd_hlkz_worldrecord;

new Array:g_ArrayStatsNub;
new Array:g_ArrayStatsPro;
new Array:g_ArrayStatsPure;


public plugin_precache()
{
	g_FwLightStyle = register_forward(FM_LightStyle, "Fw_FmLightStyle");
	g_PauseSprite = precache_model("sprites/pause_icon.spr");
    precache_model("models/player/robo/robo.mdl");
    precache_model("models/player/gordon/gordon.mdl");
    precache_model("models/p_shotgun.mdl");
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

	pcvar_kz_uniqueid = register_cvar("kz_uniqueid", "1");	// 1 - name, 2 - ip, 3 - steamid
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

	pcvar_allow_spectators = get_cvar_pointer("allow_spectators");

	pcvar_sv_ag_match_running = get_cvar_pointer("sv_ag_match_running");


	register_dictionary("telemenu.txt");
	register_dictionary("common.txt");

	register_clcmd("kz_teleportmenu", "CmdTeleportMenuHandler", ADMIN_CFG, "- displays kz teleport menu");
	register_clcmd("kz_setstart", "CmdSetStartHandler", ADMIN_CFG, "- set start position");
	register_clcmd("kz_clearstart", "CmdClearStartHandler", ADMIN_CFG, "- clear start position");

	register_clcmd("kz_set_custom_start", "CmdSetCustomStartHandler", -1, "- sets the custom start position");
	register_clcmd("kz_clear_custom_start", "CmdClearCustomStartHandler", -1, "- clears the custom start position");
	register_clcmd("kz_start_message", "CmdShowStartMsg", -1, "<0|1> - toggles the message that appears when starting the timer");
	register_clcmd("kz_time_decimals", "CmdTimeDecimals", -1, "<1-6> - sets a number of decimals to be displayed for times (seconds)");
	register_clcmd("kz_nightvision", "CmdNightvision", -1, "<0-2> - sets nightvision mode. 0=off, 1=flashlight-like, 2=map-global");

	register_clcmd("say", "CmdSayHandler");
	register_clcmd("say_team", "CmdSayHandler");
	register_clcmd("spectate", "CmdSpectateHandler");

	register_clcmd("+hook", "CheatCmdHandler");
	register_clcmd("-hook", "CheatCmdHandler");
	register_clcmd("+rope", "CheatCmdHandler");
	register_clcmd("-rope", "CheatCmdHandler");
	register_clcmd("+tas_perfectstrafe", "TASCmdHandler");
	register_clcmd("-tas_perfectstrafe", "TASCmdHandler");
	register_clcmd("+tas_autostrafe", "TASCmdHandler");
	register_clcmd("-tas_autostrafe", "TASCmdHandler");

	register_menucmd(register_menuid(MAIN_MENU_ID), 1023, "ActionKzMenu");
	register_menucmd(register_menuid(TELE_MENU_ID), 1023, "ActionTeleportMenu");

	register_think("replay_bot", "npc_think");

	RegisterHam(Ham_Use, "func_button", "Fw_HamUseButtonPre");
	RegisterHam(Ham_Touch, "trigger_multiple", "Fw_HamUseButtonPre"); // ag_bhop_master.bsp starts timer when jumping on a platform
	RegisterHam(Ham_Spawn, "player", "Fw_HamSpawnPlayerPost", 1);
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPre");
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPost", 1);
	RegisterHam(Ham_BloodColor, "player", "Fw_HamBloodColorPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPost", 1);

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
	register_touch("trigger_teleport", "player", "Fw_FmPlayerTouchTeleport");
	register_touch("trigger_push", "player", "Fw_FmPlayerTouchPush");
	register_touch("trigger_multiple", "player", "Fw_FmPlayerTouchHealthBooster");

	mfwd_hlkz_cheating = CreateMultiForward("hlkz_cheating", ET_IGNORE, FP_CELL);
	mfwd_hlkz_worldrecord = CreateMultiForward("hlkz_worldrecord", ET_IGNORE, FP_CELL, FP_FLOAT, FP_CELL, FP_CELL);

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

	g_MaxPlayers = get_maxplayers();

	g_SyncHudTimer = CreateHudSyncObj();
	g_SyncHudMessage = CreateHudSyncObj();
	g_SyncHudKeys = CreateHudSyncObj();
	g_SyncHudHealth = CreateHudSyncObj();
	g_SyncHudShowStartMsg = CreateHudSyncObj();
	g_SyncHudSpeedometer = CreateHudSyncObj();
	g_SyncHudSpecList = CreateHudSyncObj();

	g_ArrayStatsNub = ArrayCreate(STATS);
	g_ArrayStatsPro = ArrayCreate(STATS);
	g_ArrayStatsPure = ArrayCreate(STATS);

	g_ReplayNum = 0;
}

public plugin_cfg()
{
	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	// Execute custom config file
	new cfg[256];
	formatex(cfg, charsmax(cfg), "%s/%s", g_ConfigsDir, pluginCfgFileName);
	if (file_exists(cfg))
	{
		server_cmd("exec %s", cfg);
		server_exec();
	}

	// Dive into our custom directory
	add(g_ConfigsDir, charsmax(g_ConfigsDir), configsSubDir);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	formatex(g_ReplaysDir, charsmax(g_ReplaysDir), "%s/%s", g_ConfigsDir, "replays");
	if (!dir_exists(g_ReplaysDir))
		mkdir(g_ReplaysDir);

	// Load stats
	formatex(g_StatsFileNub, charsmax(g_StatsFileNub), "%s/%s_%s.dat", g_ConfigsDir, g_Map, "nub");
	formatex(g_StatsFilePro, charsmax(g_StatsFilePro), "%s/%s_%s.dat", g_ConfigsDir, g_Map, "pro");
	formatex(g_StatsFilePure, charsmax(g_StatsFilePure), "%s/%s_%s.dat", g_ConfigsDir, g_Map, "pure");
	LoadRecords(g_szTops[0]);
	LoadRecords(g_szTops[1]);
	LoadRecords(g_szTops[2]);

	// Load map settings
	formatex(g_MapIniFile, charsmax(g_MapIniFile), "%s/%s.ini", g_ConfigsDir, g_Map);
	LoadMapSettings();

	// Create healer
	if (get_pcvar_num(pcvar_kz_autoheal))
		CreateGlobalHealer();

	// Set up hud color
	new rgb[12], r[4], g[4], b[4];
	get_pcvar_string(pcvar_kz_hud_rgb, rgb, charsmax(rgb));
	parse(rgb, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	g_HudRGB[0] = str_to_num(r);
	g_HudRGB[1] = str_to_num(g);
	g_HudRGB[2] = str_to_num(b);

	if (get_pcvar_num(pcvar_kz_remove_func_friction))
		RemoveFuncFriction();
}

public plugin_end()
{
	ArrayDestroy(g_ArrayStatsNub);
	ArrayDestroy(g_ArrayStatsPro);
	ArrayDestroy(g_ArrayStatsPure);
}


//*******************************************************
//*                                                     *
//* Menus                                               *
//*                                                     *
//*******************************************************

public CmdTeleportMenuHandler(id, level, cid)
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
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6; // | MENU_KEY_7 | MENU_KEY_8;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "%s\n\n", PLUGIN);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. START CLIMB\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Checkpoints\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. HUD settings\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Spectate players\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Top climbers\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Help\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "7. About\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Admin area\n\n");
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
		case 4: CmdSpec(id);
		case 5: return DisplayKzMenu(id, 5);
		case 6: CmdHelp(id);
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
		case 1: CmdTimer(id);
		case 2: CmdShowkeys(id);
		case 3: CmdMenuShowStartMsg(id);
		case 4: CmdMenuTimeDecimals(id);
		}
	case 5:
		switch (key)
		{
		case 1: ShowTopClimbers(id, g_szTops[0]);
		case 2: ShowTopClimbers(id, g_szTops[1]);
		case 3: ShowTopClimbers(id, g_szTops[2]);
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

	//query_client_cvar(id, "kz_nightvision", "ClCmdNightvision"); // TODO save user variables in a file and retrieve them when they connect to server

	g_ControlPoints[id][CP_TYPE_START] = g_MapDefaultStart;

	g_ReplayFrames[id] = ArrayCreate(REPLAY);

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
			ShowMessage(id, "Timer resetted");
		else
			ShowMessage(id, "Timer and checkpoints resetted");
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

CmdStuck(id)
{
	if (CanTeleport(id, CP_TYPE_OLD))
		Teleport(id, CP_TYPE_OLD);
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

CmdReplayPure(id)
	CmdReplay(id, g_szTops[0]);

CmdReplayPro(id)
	CmdReplay(id, g_szTops[1]);

CmdReplayNoob(id)
	CmdReplay(id, g_szTops[2]);

CmdReplay(id, szTopType[])
{
	static authid[32], replayFile[256], idNumbers[24], stats[STATS], time[32];
	new minutes, Float:seconds, replayRank = GetNumberArg();
	new maxReplays = get_pcvar_num(pcvar_kz_max_concurrent_replays);
	new Float:setupTime = get_pcvar_float(pcvar_kz_replay_setup_time);

	LoadRecords(szTopType);

	new Array:arr;
	if 		(equali(szTopType, g_szTops[0]))	arr = g_ArrayStatsPure;
	else if (equali(szTopType, g_szTops[1]))	arr = g_ArrayStatsPro;
	else										arr = g_ArrayStatsNub;

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

	new replayingMsg[96], replayFailedMsg[96];
	formatex(replayingMsg, charsmax(replayingMsg), "[%s] Replaying %s's %s run (%ss)", PLUGIN_TAG, stats[STATS_NAME], szTopType, time);
	formatex(replayFailedMsg, charsmax(replayFailedMsg), "[%s] Sorry, no replay available for %s's %s run", PLUGIN_TAG, stats[STATS_NAME], szTopType);
	ConvertSteamID32ToNumbers(authid, idNumbers);
	strtolower(szTopType);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
	//formatex(g_ReplayFile[id], charsmax(replayFile), "%s", replayFile);
	//console_print(id, "rank %d's idNumbers: '%s', replay file: '%s'", replayRank, idNumbers, replayFile);
	
	minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
	seconds = stats[STATS_TIME] - (60 * minutes);

	formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%"), minutes, seconds);

	new file = fopen(replayFile, "rb");
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
			client_print(id, print_chat, "[%s] Cancelling your current replay...", PLUGIN_TAG);

		client_print(id, print_chat, "%s", replayingMsg);
	}
	
	if (!g_ReplayFramesIdx[id])
	{
		new replay[REPLAY];

		ArrayClear(g_ReplayFrames[id]);
		//console_print(id, "gonna read the replay file");

		//new version;
		//fread(file, version, BLOCK_BYTE);
		//console_print(1, "replaying demo of version %d", version);

		new i = 0;
		while (!feof(file))
		{
			i++;
			fread_blocks(file, replay, sizeof(replay) - 1, BLOCK_INT);
			fread(file, replay[RP_BUTTONS], BLOCK_SHORT);

			//if (i % 331 == 0) // only showing these frames because printing too many throws stack overflow
				//console_print(id, "gametime: %.5f, pz: %.3f, ay: %.3f, buttons: %d", replay[RP_TIME], replay[RP_ORIGIN], replay[RP_ANGLES], replay[RP_BUTTONS]);

			ArrayPushArray(g_ReplayFrames[id], replay);

		}
		//console_print(id, "%d frames loaded", ArraySize(g_ReplayFrames[id]));
		fclose(file);

		g_ReplayNum++;
		SpawnBot(id);
		client_print(id, print_chat, "[%s] Your bot will start running in %.1f seconds", PLUGIN_TAG, setupTime);
	}
}

SpawnBot(id)
{
    if (get_playersnum(1) < get_maxplayers() - 4) // leave at least 4 slots available
    {
	    new botName[33];
	    formatex(botName, charsmax(botName), "%s Bot ", PLUGIN_TAG);
		for (new i = 0; i < 4; i++)
		{ // Generate a random number 4 times, so the final name is like Bot 0123
			new str[2];
	    	num_to_str(random_num(0, 9), str, charsmax(str));
	    	add(botName, charsmax(botName), str);
		}
	    new bot, ptr[128], ip[64]/*, Float:botOrigin[3], Float:botAngles[3], Float:botViewOfs[3], Float:botVelocity[3]*/;
	    bot = engfunc(EngFunc_CreateFakeClient, botName);
	    if (bot)
	    {
	    	// Creating an entity that will make the thinking process for this bot
	    	new ent = create_entity("info_target");
	    	g_BotEntity[bot] = ent;
		    entity_set_string(ent, EV_SZ_classname, "replay_bot");

		    engfunc(EngFunc_FreeEntPrivateData, bot);
		    ConfigureBot(bot);
			get_cvar_string("ip", ip, charsmax(ip));
		    dllfunc(DLLFunc_ClientConnect, bot, botName, ip, ptr);
		    dllfunc(DLLFunc_ClientPutInServer, bot);

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
                    /*
		    console_print(1, "data row: %.5f %.3f %.3f %.3f %.3f %.3f %.3f %d",
		    	replay[RP_TIME],
		    	replay[RP_ORIGIN][0], replay[RP_ORIGIN][1], replay[RP_ORIGIN][2],
		    	replay[RP_ANGLES][0], replay[RP_ANGLES][1], replay[RP_ANGLES][2],
		    	replay[RP_BUTTONS]);
                    */
		    set_pev(bot, pev_origin, replay[RP_ORIGIN]);
		    set_pev(bot, pev_angles, replay[RP_ANGLES]);
		    set_pev(bot, pev_button, replay[RP_BUTTONS]);
		    new Float:botOrigin[3];
		    pev(bot, pev_origin, botOrigin);

		    g_BotOwner[bot] = id;
		    g_Unfreeze[bot] = false;
		    //console_print(1, "player %d spawned the bot %d", id, bot);

			entity_set_float(ent, EV_FL_nextthink, get_gametime() + get_pcvar_float(pcvar_kz_replay_setup_time)); // TODO: countdown hud; 3 seconds to start the replay, so there's time to switch to spectator
		    engfunc(EngFunc_RunPlayerMove, bot, replay[RP_ANGLES], 0.0, 0.0, 0.0, replay[RP_BUTTONS], 0, 4);
	    }
	    else
	    	client_print(id, print_chat, "[%s] Sorry, couldn't create the bot", PLUGIN_TAG);
    }
    return PLUGIN_HANDLED;
}

ConfigureBot(id) {
	set_user_info(id, "model",				"robo");
	set_user_info(id, "rate",				"3500");
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
	if (g_ReplayFrames[owner] && g_ReplayFramesIdx[owner] < ArraySize(g_ReplayFrames[owner]))
	{
		static replayPrev[REPLAY], replay[REPLAY], replayNext[REPLAY], replay2Next[REPLAY];

		// Fix spectator cam getting frozen when the watched player is teleported
		//if (g_Unfreeze[bot] == 10)
			//UnfreezeSpecCam(bot);

		if (g_Unfreeze[bot] > 25)
		{
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

		new Float:botVelocity[3], Float:botOrigin[3], Float:frameDuration = replayNext[RP_TIME] - replay[RP_TIME];
		pev(bot, pev_velocity, botVelocity);
		pev(bot, pev_origin, botOrigin);
		if (frameDuration <= 0)
		{
			if (replay2Next[RP_TIME])
				frameDuration = (replay2Next[RP_TIME] - replay[RP_TIME]) / 2;
			else
				frameDuration = 0.002; // duration of a frame at 125 fps, 'cos the most usual thing is to use 250 fps, so at 0.004 there will already be another frame to replay
		}

		new Float:botPrevHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));
		new Float:botPrevPos[3];
		xs_vec_copy(botOrigin, botPrevPos);

		// The correct thing would be to take into account the previous frame, but it doesn't matter most of the time
		if (frameDuration)
		{
			botVelocity[0] = (replayNext[RP_ORIGIN][0] - replay[RP_ORIGIN][0]) / frameDuration;
			botVelocity[1] = (replayNext[RP_ORIGIN][1] - replay[RP_ORIGIN][1]) / frameDuration;
			// z velocity is already calculated by the engine because of gravity,
			// but it would have to be calculated if surfing, but may not be easy
			// as a too high z velocity when not surfing will deal fall damage
		}
	    set_pev(bot, pev_origin, replay[RP_ORIGIN]);
	    set_pev(bot, pev_angles, replay[RP_ANGLES]);
	    set_pev(bot, pev_v_angle, replay[RP_ANGLES]);
	    set_pev(bot, pev_button, replay[RP_BUTTONS]);
		set_pev(bot, pev_velocity, botVelocity);
		pev(bot, pev_origin, botOrigin); // set again botOrigin to calculate curr position vector length


    	entity_set_float(id, EV_FL_nextthink, get_gametime() + replayNext[RP_TIME] - replay[RP_TIME]);

	    engfunc(EngFunc_RunPlayerMove, bot, replay[RP_ANGLES], botVelocity[0], botVelocity[1], botVelocity[2], replay[RP_BUTTONS], 0, 4);

		new Float:botCurrHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));
		new Float:botCurrPos[3];
		xs_vec_copy(botOrigin, botCurrPos);

	    g_ReplayFramesIdx[owner]++;

		if ((botPrevHSpeed > 0.0 && botCurrHSpeed == 0.0 && get_distance_f(botOrigin, botPrevPos) > 50.0)
			|| get_distance_f(botOrigin, botPrevPos) > 900.0) // Has teleported?
			g_Unfreeze[bot]++;
		else if (g_Unfreeze[bot])
			g_Unfreeze[bot]++;

		//if (g_Unfreeze[bot])
		    //console_print(1, "[t=%d] Distance from prev frame: %.3f, curr HSpeed: %.3f", g_ReplayFramesIdx[owner], get_distance_f(botOrigin, botPrevPos), botCurrHSpeed);
	}
	else
	{
		//console_print(1, "npc_think :: removing bot %d", bot);
		set_task(0.5, "KickReplayBot", bot + TASKID_KICK_REPLAYBOT);
		FinishReplay(owner);
	}

}

public UnfreezeSpecCam(bot)
{
	//new bot = id - TASKID_CAM_UNFREEZE;
	//console_print(1, "UnfreezeSpecCam :: bot id: %d", bot);
	new bool:launchTask = false;
	for (new spec = 1; spec <= g_MaxPlayers; spec++)
	{
		if (is_user_connected(spec))
		{
			if (is_user_alive(spec))
				continue;
			
			if (pev(spec, pev_iuser2) == bot)
			{
				client_cmd(spec, "+attack; wait; -attack;");
				g_FrozenSpectators[spec] = bot;
				new runnerName[33], specName[33];
				GetColorlessName(bot, runnerName, charsmax(runnerName));
				GetColorlessName(spec, specName, charsmax(specName));
				//console_print(spec, "executing +attack;wait;-attack on spectator %s", specName);
				launchTask = true;
			}
		}
	}
	if (launchTask)
		set_task(0.1, "RestoreSpecCam");
}

public RestoreSpecCam()
{
	for (new i = 1; i <= sizeof(g_FrozenSpectators) - 1; i++)
	{	
		new bot = g_FrozenSpectators[i];
		if (bot)
		{
			new runnerName[33];
			GetColorlessName(bot, runnerName, charsmax(runnerName));
			//console_print(i, "setting cam back on player %s", runnerName);
			set_pev(i, pev_iuser2, bot);
		}
	}
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
			/prestrafe - toggle showing prestrafe speed\n");
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

	/*
	else if (equali(args[1], "bot"))
	{
		if (is_user_admin(id))
			SpawnBot(id);
	}
	*/

	// The ones below use contain because they can be passed parameters
	else if (containi(args[1], "replaypure") == 0)
		CmdReplayPure(id);

	else if (containi(args[1], "replaypro") == 0)
		CmdReplayPro(id);

	else if (containi(args[1], "replaynub") == 0 || containi(args[1], "replaynoob") == 0)
		CmdReplayNoob(id);

	else if (containi(args[1], "speedcap") == 0)
		CmdSpeedcap(id);

	else if (containi(args[1], "dec") == 0)
		CmdTimeDecimals(id);

	else if (containi(args[1], "nv") == 0 || containi(args[1], "nightvision") == 0)
		CmdNightvision(id);

	else if (containi(args[1], "pure") == 0)
		ShowTopClimbers(id, g_szTops[0]);

	else if (containi(args[1], "pro") == 0)
		ShowTopClimbers(id, g_szTops[1]);

	else if (containi(args[1], "nub") == 0 || containi(args[1], "noob") == 0)
		ShowTopClimbers(id, g_szTops[2]);

	else if (containi(args[1], "top") == 0)
		DisplayKzMenu(id, 5);

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

bool:CanCreateCp(id, bool:showMessages = true)
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

	if (!IsValidPlaceForCp(id))
	{
		if (showMessages) ShowMessage(id, "You must be on the ground");
		return false;
	}

	return true;
}

bool:CanTeleport(id, cp, bool:showMessages = true)
{
	if (cp >= CP_TYPES)
		return false;

	if (cp != CP_TYPE_START && cp != CP_TYPE_CUSTOM_START && !get_pcvar_num(pcvar_kz_checkpoints))
	{
		if (showMessages) ShowMessage(id, "Checkpoint commands are disabled");
		return false;
	}
	if (cp == CP_TYPE_OLD && !get_pcvar_num(pcvar_kz_stuck))
	{
		if (showMessages) ShowMessage(id, "Stuck/Unstuck commands are disabled");
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
			case CP_TYPE_START: ShowMessage(id, "You don't have start checkpoint created and the map doesn't have a default one");
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

	set_pev(id, pev_origin, g_ControlPoints[id][cp][CP_ORIGIN]);
	set_pev(id, pev_angles, g_ControlPoints[id][cp][CP_ANGLES]);
	set_pev(id, pev_v_angle, g_ControlPoints[id][cp][CP_ANGLES]);
	set_pev(id, pev_view_ofs, g_ControlPoints[id][cp][CP_VIEWOFS]);
	set_pev(id, pev_velocity, /*g_ControlPoints[id][cp][CP_VELOCITY]*/ Float:{ 0.0, 0.0, 0.0 });
	set_pev(id, pev_fixangle, true);
	set_pev(id, pev_health, g_ControlPoints[id][cp][CP_HEALTH]);
	set_pev(id, pev_armorvalue, g_ControlPoints[id][cp][CP_ARMOR]);
	hl_set_user_longjump(id, g_ControlPoints[id][cp][CP_LONGJUMP]);

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

			return;
		}

		// Teleport player to last checkpoint
		if (CanTeleport(id, CP_TYPE_CURRENT, false))
			Teleport(id, CP_TYPE_CURRENT);
		else if (CanTeleport(id, CP_TYPE_START, false))
			Teleport(id, CP_TYPE_START);
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
		client_cmd(id, "spk \"vox/access denied\"");
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
	if (g_CheatCommandsGuard[id])
	{
		client_cmd(id, "spk \"vox/access denied\"");
		ShowMessage(id, "Using timer while cheating is prohibited");
		return;
	}
	if (!get_bit(g_baIsClimbing, id))
	{
		client_cmd(id, "spk \"vox/access denied\"");
		ShowMessage(id, "You must press the start button first");
		return;
	}
	if (get_bit(g_baIsPureRunning, id))
	{
		ShowMessage(id, "You have performed a pure run :)");
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
	new name[32], minutes, Float:seconds, pureRun[11];
	new Float:kztime = get_gametime() - g_PlayerTime[id];

	minutes = floatround(kztime, floatround_floor) / 60;
	seconds = kztime - (60 * minutes);
	pureRun = get_bit(g_baIsPureRunning, id) ? "(Pure Run)" : "";

	client_cmd(0, "spk fvox/bell");

	get_user_name(id, name, charsmax(name));
	client_print(0, print_chat, GetVariableDecimalMessage(id, "[%s] %s finished in %02d:%", "(CPs: %d | TPs: %d) %s"),
		PLUGIN_TAG, name, minutes, seconds, g_CpCounters[id][COUNTER_CP], g_CpCounters[id][COUNTER_TP], pureRun);

	if (!get_pcvar_num(pcvar_kz_nostat))
		if (!g_CpCounters[id][COUNTER_CP] && !g_CpCounters[id][COUNTER_TP])
		{
			if (get_bit(g_baIsPureRunning, id))
			{
				UpdateRecords(id, kztime, g_szTops[0]);
				UpdateRecords(id, kztime, g_szTops[1]);
			}
			else
				UpdateRecords(id, kztime, g_szTops[1]);
		}
		else
			UpdateRecords(id, kztime, g_szTops[2]);

	clr_bit(g_baIsClimbing, id);
	clr_bit(g_baIsPureRunning, id);

	if (g_bMatchRunning)
	{
		g_bMatchRunning = false;
		server_cmd("agabort");
		server_exec();
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

	new BUTTON_TYPE:type = GetEntityButtonType(ent);
	switch (type)
	{
	case BUTTON_START: StartClimb(id);
	case BUTTON_FINISH: FinishClimb(id);
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
		if (equali(g_szStarts[i], name))
			return true;
	return false;
}

bool:IsStopEntityName(name[])
{
	for (new i = 0; i < sizeof(g_szStops); i++)
		if (equali(g_szStops[i], name))
			return true;
	return false;
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
		new specs = 0, specsTotal = 0;
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
			if (GetSpectatorList(id, specHud, sendTo))
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

GetSpectatorList(id, hud[], sendTo[])
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
					add(hud, charsmax(hud), szName);
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

public Fw_HamTakeDamagePlayerPre(victim, inflictor, agressor, Float:damage, damagebits)
{
	pev(victim, pev_health, g_LastHealth);

	if (get_pcvar_num(pcvar_kz_nodamage))
	{
		if ((damagebits == DMG_GENERIC && !agressor && damage == 300.0) || (agressor != victim && IsPlayer(agressor)))
		{
			// Hack for admins to shoot users with python
			if (agressor && victim &&
				(get_user_weapon(agressor) == HLW_PYTHON) &&
				(get_user_flags(agressor) & ADMIN_LEVEL_A) &&
				(get_user_flags(victim) & ADMIN_USER ))
			{
				SetHamParamFloat(4, 100500.0);
				return HAM_HANDLED;
			}

			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public Fw_HamTakeDamagePlayerPost(victim, inflictor, agressor, Float:damage, damagebits)
{
	static Float:fHealth;
	pev(victim, pev_health, fHealth);

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

public RemoveFuncFriction()
{
	new iEnt = FM_NULLENT, i = 0;
	while( (iEnt = find_ent_by_class(iEnt, "func_friction")) )
	{
		remove_entity(iEnt);
		i++;
	}
	server_print("[%s] %d func_friction entities removed", PLUGIN_TAG, i);
}

public CmdSetStartHandler(id)
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

	new file = fopen(g_MapIniFile, "wt");
	if (!file)
	{
		ShowMessage(id, "Failed to write map ini file");
		return PLUGIN_HANDLED;
	}

	CreateCp(id, CP_TYPE_START);
	g_MapDefaultStart = g_ControlPoints[id][CP_TYPE_START];

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
		g_ControlPoints[i][CP_TYPE_START] = g_MapDefaultStart;

	ShowMessage(id, "Map start position set");

	return PLUGIN_HANDLED;
}

public CmdClearStartHandler(id)
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

	return PLUGIN_HANDLED;
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

CmdSpeed(id)
{
	ClearSyncHud( id, g_SyncHudSpeedometer );
	g_ShowSpeed[id] = !g_ShowSpeed[id];
	client_print( id, print_chat, "Speed: %s", g_ShowSpeed[id] ? "ON" : "OFF" );

	return PLUGIN_HANDLED;
}

CmdSpeedcap(id)
{
	new Float:allowed_speedcap = get_pcvar_float(pcvar_kz_speedcap);
	new Float:speedcap = GetFloatArg();
	//console_print(id, "allowed_speedcap = %.2f; speedcap = %.2f", allowed_speedcap, speedcap);

	if (allowed_speedcap && speedcap > allowed_speedcap)
	{
		g_Speedcap[id] = speedcap;
		ShowMessage(id, "Server doesn't allow a higher speedcap than %.2f", allowed_speedcap);
	} else {
		g_Speedcap[id] = speedcap;
	}

	ShowMessage(id, "Your horizontal speedcap is now: %.2f", g_Speedcap[id]);
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

LoadRecords(szTopType[])
{
	new file;
	if (equali(szTopType, g_szTops[0]))
		file = fopen(g_StatsFilePure, "r");
	else if (equali(szTopType, g_szTops[1]))
		file = fopen(g_StatsFilePro, "r");
	else
		file = fopen(g_StatsFileNub, "r");
	if (!file) return;

	new data[1024], stats[STATS], uniqueid[32], name[32], cp[24], tp[24];
	new kztime[24], timestamp[24];

	new Array:arr;
	if (equali(szTopType, g_szTops[0]))
		arr = g_ArrayStatsPure;
	else if (equali(szTopType, g_szTops[1]))
		arr = g_ArrayStatsPro;
	else
		arr = g_ArrayStatsNub;
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

		ArrayPushArray(arr, stats);
	}

	fclose(file);
}

SaveRecords(szTopType[])
{
	new file;
	if (equali(szTopType, g_szTops[0]))
		file = fopen(g_StatsFilePure, "w+");
	else if (equali(szTopType, g_szTops[1]))
		file = fopen(g_StatsFilePro, "w+");
	else
		file = fopen(g_StatsFileNub, "w+");
	if (!file) return;

	new stats[STATS];
	new Array:arr;
	if (equali(szTopType, g_szTops[0]))
		arr = g_ArrayStatsPure;
	else if (equali(szTopType, g_szTops[1]))
		arr = g_ArrayStatsPro;
	else
		arr = g_ArrayStatsNub;

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

// Refactor if somehow more than 2 tops have to be passed
// The second top is only in case you do a Pure that is
// better than your Pro record, so it gets updated in both
UpdateRecords(id, Float:kztime, szTopType[])
{
	new uniqueid[32], name[32], rank;
	new stats[STATS], insertItemId = -1, deleteItemId = -1;
	new minutes, Float:seconds, Float:slower, Float:faster;
	LoadRecords(szTopType);

	new Array:arr, type;
	if (equali(szTopType, g_szTops[0]))
	{
		arr = g_ArrayStatsPure;
		type = 0;
	}
	else if (equali(szTopType, g_szTops[1]))
	{
		arr = g_ArrayStatsPro;
		type = 1;
	}
	else
	{
		arr = g_ArrayStatsNub;
		type = 2;
	}

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
			if (!(get_bit(g_baIsPureRunning, id) && type == 1))
			{
				client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You failed your %s time by %02d:%"),
					PLUGIN_TAG, szTopType, minutes, seconds);
			}
		
			return;
		}

		faster = stats[STATS_TIME] - kztime;
		minutes = floatround(faster, floatround_floor) / 60;
		seconds = faster - (60 * minutes);
		client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You improved your %s time by %02d:%"),
			PLUGIN_TAG, szTopType, minutes, seconds);

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
		client_print(0, print_chat, "[%s] %s is now on place %d in %s 15", PLUGIN_TAG, name, rank, szTopType);
	}
	else
		client_print(0, print_chat, "[%s] %s's rank is %d of %d among %s players", PLUGIN_TAG, name, rank, ArraySize(arr), szTopType);

	SaveRecords(szTopType);

	if (rank == 1)
	{
		new ret;
		ExecuteForward(mfwd_hlkz_worldrecord, ret, id, kztime, type, arr);
	}

	if (g_RecordRun[id])
	{
		//fclose(g_RecordRun[id]);
		g_RecordRun[id] = 0;
		//ArrayClear(g_RunFrames[id]);
		//console_print(id, "stopped recording");
		SaveRecordedRun(id, szTopType);
	}
}

ShowTopClimbers(id, szTopType[])
{
	new buffer[1536], len;
	new stats[STATS], date[32], time[32], minutes, Float:seconds;
	LoadRecords(szTopType);
	new Array:arr;
	if (equali(szTopType, g_szTops[0]))
		arr = g_ArrayStatsPure;
	else if (equali(szTopType, g_szTops[1]))
		arr = g_ArrayStatsPro;
	else
		arr = g_ArrayStatsNub;

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



	if (equali(szTopType, g_szTops[2]))
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time       CP  TP         Date        Demo\n\n");
	else
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time              Date        Demo\n\n");

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
		strtolower(szTopType);
		formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
		new hasDemo = file_exists(replayFile);
		ucfirst(szTopType);

		if (equali(szTopType, g_szTops[2]))
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s  %3d %3d        %s   %s\n", i + 1, stats[STATS_NAME], time, stats[STATS_CP], stats[STATS_TP], date, hasDemo ? "yes" : "no");
		else
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s         %s   %s\n", i + 1, stats[STATS_NAME], time, date, hasDemo ? "yes" : "no");
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "\n%s %s", PLUGIN, VERSION);

	new header[24];
	formatex(header, charsmax(header), "%s %d-%d Climbers", szTopType, recMin ? recMin : 1, recMax);
	show_motd(id, buffer, header);

	return PLUGIN_HANDLED;
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

SaveRecordedRun(id, szTopType[])
{
	static authid[32], replayFile[256], idNumbers[24];
	get_user_authid(id, authid, charsmax(authid));

	ConvertSteamID32ToNumbers(authid, idNumbers);
	strtolower(szTopType);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
	//console_print(id, "saving run to: '%s'", replayFile);

	g_RecordRun[id] = fopen(replayFile, "wb");
	//console_print(id, "opened replay file");

	//fwrite(g_RecordRun[id], GetVersionNumber(), BLOCK_BYTE); // version

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

/**
 * Returns the numbers in the version, so 0.34 returns 34, or 1.0.2 returns 102.
 * This is to save as metadata in the replay files so we can know what version they're
 * to make proper changes to them (e.g.: convert from one version to another 'cos
 * replay data format is changed).
 */
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
