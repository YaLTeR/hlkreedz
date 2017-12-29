/* AMX Mod X
*	HL KreedZ
*
* http://aghl.ru/forum/ - Russian Half-Life and Adrenaline Gamer Community
*
* This file is provided as is (no warranties)
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

#define PLUGIN "HL KreedZ Beta"
#define PLUGIN_TAG "HLKZ"
#define VERSION "0.24"
#define AUTHOR "KORD_12.7 & Lev & YaLTeR"

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

#define MAIN_MENU_ID	"HL KreedZ Menu"
#define TELE_MENU_ID	"HL KreedZ Teleport Menu"

new const configsSubDir[] = "/hl_kreedz";
new const pluginCfgFileName[] = "hl_kreedz.cfg";

new const staleStatTime = 30 * 24 * 60 * 60;	// Keep old stat for this amount of time
new const keepStatPlayers = 100;				// Keep this amount of players in stat even if stale

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

enum _:CP_TYPES
{
	CP_TYPE_SPEC,
	CP_TYPE_CURRENT,
	CP_TYPE_OLD,
	CP_TYPE_START,
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

enum _:STATS
{
	STATS_ID[32],
	STATS_NAME[32],
	STATS_CP,
	STATS_TP,
	Float:STATS_TIME,	// Timer value
	STATS_TIMESTAMP,	// Date
}

enum BUTTON_TYPE
{
	BUTTON_START,
	BUTTON_FINISH,
	BUTTON_NOT,
}

new g_bit_is_connected, g_bit_is_alive;
new g_bit_is_hltv, g_bit_is_bot;
new g_baIsClimbing, g_baIsPaused, g_baIsFirstSpawn;

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

new g_ControlPoints[MAX_PLAYERS + 1][CP_TYPES][CP_DATA];
new g_CpCounters[MAX_PLAYERS + 1][COUNTERS];

new g_HudRGB[3];
new g_SyncHudTimer;
new g_SyncHudMessage;
new g_SyncHudKeys;
new g_SyncHudHealth;
new g_MaxPlayers;
new g_PauseSprite;
new g_TaskEnt;

new g_Map[64];
new g_ConfigsDir[256];
new g_StatsFileNub[256];
new g_StatsFilePro[256];
new g_MapIniFile[256];
new g_MapDefaultStart[CP_DATA];

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
new pcvar_kz_nokill;
new pcvar_kz_autoheal;
new pcvar_kz_autoheal_hp;
new pcvar_kz_spawn_mainmenu;
new pcvar_kz_nostat;

new Array:g_ArrayStatsNub;
new Array:g_ArrayStatsPro;




public plugin_precache()
{
	g_PauseSprite = precache_model("sprites/pause_icon.spr");
	//precache_model("models/w_jumppack.mdl");
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
	pcvar_kz_nokill = register_cvar("kz_nokill", "0");
	pcvar_kz_autoheal = register_cvar("kz_autoheal", "0");
	pcvar_kz_autoheal_hp = register_cvar("kz_autoheal_hp", "50");
	pcvar_kz_nostat = register_cvar("kz_nostat", "0");		// Disable stats storing (use for tests or fun)

	pcvar_allow_spectators = get_cvar_pointer("allow_spectators");

	register_dictionary("telemenu.txt");
	register_dictionary("common.txt");

	register_clcmd("kz_teleportmenu", "CmdTeleportMenuHandler", ADMIN_CFG, "- displays kz teleport menu");
	register_clcmd("kz_setstart", "CmdSetStartHandler", ADMIN_CFG, "- set start position");
	register_clcmd("kz_clearstart", "CmdClearStartHandler", ADMIN_CFG, "- clear start position");

	register_clcmd("say", "CmdSayHandler");
	register_clcmd("say_team", "CmdSayHandler");
	register_clcmd("spectate", "CmdSpectateHandler");

	register_clcmd("+hook", "CheatCmdHandler");
	register_clcmd("-hook", "CheatCmdHandler");
	register_clcmd("+rope", "CheatCmdHandler");
	register_clcmd("-rope", "CheatCmdHandler");

	register_menucmd(register_menuid(MAIN_MENU_ID), 1023, "ActionKzMenu");
	register_menucmd(register_menuid(TELE_MENU_ID), 1023, "ActionTeleportMenu");

	RegisterHam(Ham_Use, "func_button", "Fw_HamUseButtonPre");
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

	g_ArrayStatsNub = ArrayCreate(STATS);
	g_ArrayStatsPro = ArrayCreate(STATS);
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

	// Load stats
	formatex(g_StatsFileNub, charsmax(g_StatsFileNub), "%s/%s_%s.dat", g_ConfigsDir, g_Map, "nub");
	formatex(g_StatsFilePro, charsmax(g_StatsFilePro), "%s/%s_%s.dat", g_ConfigsDir, g_Map, "pro");
	LoadRecords(true);
	LoadRecords(false);

	// Load map settings
	formatex(g_MapIniFile, charsmax(g_MapIniFile), "%s/%s.ini", g_ConfigsDir, g_Map);
	LoadMapSettings();

	// Create healer
	if (get_pcvar_num(pcvar_kz_autoheal))
		CreateGlobalHealer();

	// Setup hud color
	new rgb[12], r[4], g[4], b[4];
	get_pcvar_string(pcvar_kz_hud_rgb, rgb, charsmax(rgb));
	parse(rgb, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	g_HudRGB[0] = str_to_num(r);
	g_HudRGB[1] = str_to_num(g);
	g_HudRGB[2] = str_to_num(b);
}

public plugin_end()
{
	ArrayDestroy(g_ArrayStatsNub);
	ArrayDestroy(g_ArrayStatsPro);
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
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Spectate playes\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Top climbers\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Help\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "7. About\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Admin area\n\n");
		}
	case 1:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Climb Menu\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Start position\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Respawn\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Pause timer\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Reset\n");
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
			keys |= MENU_KEY_1 | MENU_KEY_2;

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
		}
	case 5:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Show Top Climbers\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Pro 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Noob 15\n");
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
	key ++;

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
		}
	case 5:
		switch (key)
		{
		case 1: ShowTopClimbers(id, true);
		case 2: ShowTopClimbers(id, false);
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

	g_ControlPoints[id][CP_TYPE_START] = g_MapDefaultStart;

	set_task(1.20, "DisplayWelcomeMessage", id + TASKID_WELCOME);
}

public client_disconnect(id)
{
	clr_bit(g_bit_is_connected, id);
	clr_bit(g_bit_is_hltv, id);
	clr_bit(g_bit_is_bot, id);
	clr_bit(g_baIsFirstSpawn, id);
	g_SolidState[id] = -1;

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
	for (i = 0; i < CP_TYPE_START; i++)
		g_ControlPoints[id][i][CP_VALID] = false;

	// Reset counters
	for (i = 0; i < COUNTERS; i++)
		g_CpCounters[id][i] = 0;
}

public DisplayWelcomeMessage(id)
{
	id -= TASKID_WELCOME;
	client_print(id, print_chat, "[%s] Welcome to %s", PLUGIN_TAG, PLUGIN);
	client_print(id, print_chat, "[%s] Visit www.aghl.ru", PLUGIN_TAG);

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

CmdSpec(id)
{
	client_cmd(id, "spectate");	// CanSpectate is called inside of command hook handler
}

CmdTimer(id)
{
	if (!get_pcvar_num(pcvar_kz_show_timer))
	{
		ShowMessage(id, "Timer display is disabled by server");
		return;
	}

	client_print(id, print_center, "");
	ClearSyncHud(id, g_SyncHudTimer);
	ClearSyncHud(id, g_SyncHudKeys);

	if (g_ShowTimer[id] < 2)
		ShowMessage(id, "Timer display destination: %s", g_ShowTimer[id]++ < 1 ? "center" : "hud");
	else
	{
		g_ShowTimer[id] = 0;
		ShowMessage(id, "Timer display off");
	}
}

CmdShowkeys(id)
{
	if (!get_pcvar_num(pcvar_kz_show_keys))
	{
		ShowMessage(id, "Keys display is disabled by server");
		return;
	}

	ClearSyncHud(id, g_SyncHudKeys);

	if (g_ShowKeys[id] < 2)
		ShowMessage(id, "Keys display %s", g_ShowKeys[id]++ < 1 ? "on in spectator mode" : "on");
	else
	{
		g_ShowKeys[id] = 0;
		ShowMessage(id, "Keys display off");
	}
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
	new motd[2047], title[32], len;

	len = formatex(motd[len], charsmax(motd) - len,
		"Say commands:\n\
		/kz - show main menu\n\
		/cp - create control point\n\
		/tp - teleport to last control point\n\
		/top - show Top climbers\n\
		/unstuck - teleport to previous control point\n\
		/pause - pause timer and freeze player\n\
		/reset - reset timer and clear checkpoints\n");
	len += formatex(motd[len], charsmax(motd) - len,
		"/start - go to start button\n\
		/respawn - go to spawn point\n\
		/spec - go to spectate mode or exit from it\n\
		/timer - switch between different timer display modes\n\
		/showkeys - display pressed movement keys in HUD\n\
		/kzhelp - this motd\n");

	formatex(motd[len], charsmax(motd) - len,
		"\n%s %s by KORD_12.7 & Lev\n\
		Visit aghl.ru for news\n\n", PLUGIN, VERSION);

	formatex(title, charsmax(title), "%s Help", PLUGIN);
	show_motd(id, motd, title);
	return PLUGIN_HANDLED;
}

public CmdSayHandler(id)
{
	static args[64];
	read_args(args, charsmax(args));
	remove_quotes(args); trim(args);

	if (args[0] != '/' && args[0] != '.')
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

	else if (equali(args[1], "spec"))
		CmdSpec(id);

	else if (equali(args[1], "showkeys") || equali(args[1], "keys"))
		CmdShowkeys(id);

	else if (equali(args[1], "spawn") || equali(args[1], "respawn"))
		CmdRespawn(id);

	else if (equali(args[1], "kzmenu") || equali(args[1], "menu") || equali(args[1], "kz"))
		DisplayKzMenu(id, 0);

	else if (equali(args[1], "kzhelp") || equali(args[1], "help") || equali(args[1], "h"))
		CmdHelp(id);

	else if (contain(args[1], "top") != -1 || contain(args[1], "pro") != -1 || contain(args[1], "nub") != -1 || contain(args[1], "noob") != -1)
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

	if (cp != CP_TYPE_START && !get_pcvar_num(pcvar_kz_checkpoints))
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
	if (IsHltv(id) || IsBot(id))
		return PLUGIN_CONTINUE;

	return ClientCommandSpectatePre(id);
}

public Fw_FmClientCommandPost(id)
{
	if (IsHltv(id) || IsBot(id))
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

	FinishTimer(id);

	InitPlayer(id);
}

StartTimer(id)
{
	set_bit(g_baIsClimbing, id);
	g_PlayerTime[id] = get_gametime();
	ShowMessage(id, "Timer started");
}

FinishTimer(id)
{
	new name[32], minutes, Float:seconds;
	new Float:kztime = get_gametime() - g_PlayerTime[id];

	minutes = floatround(kztime, floatround_floor) / 60;
	seconds = kztime - (60 * minutes);

	client_cmd(0, "spk fvox/bell");

	get_user_name(id, name, charsmax(name));
	client_print(0, print_chat,"[%s] %s finished in %02d:%06.3f (CPs: %d | TPs: %d)", PLUGIN_TAG, name, minutes, seconds, g_CpCounters[id][COUNTER_CP], g_CpCounters[id][COUNTER_TP]);

	if (!get_pcvar_num(pcvar_kz_nostat))
		UpdateRecords(id, kztime, !g_CpCounters[id][COUNTER_CP] && !g_CpCounters[id][COUNTER_TP]);

	clr_bit(g_baIsClimbing, id);

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
	static players[MAX_PLAYERS], num, id, i;

	get_players(players, num);
	for (i = 0; i < num; i++)
	{
		id = players[i];
		//if (IsBot(id) || IsHltv(id)) continue;

		// Select traget from whom to take timer and pressed keys
		mode = pev(id, pev_iuser1);
		targetId = mode == OBS_CHASE_LOCKED || mode == OBS_CHASE_FREE || mode == OBS_IN_EYE || mode == OBS_MAP_CHASE ? pev(id, pev_iuser2) : id;
		if (!is_user_connected(targetId)) continue;

		if (g_LastMode[id] != mode)
		{
			// Clear hud if we are switching spec mode
			g_LastMode[id] = mode;
			ClearSyncHud(id, g_SyncHudTimer);
			ClearSyncHud(id, g_SyncHudKeys);
		}
		if (g_LastTarget[id] != targetId)
		{
			// Clear hud if we are switching between different targets
			g_LastTarget[id] = targetId;
			ClearSyncHud(id, g_SyncHudTimer);
			ClearSyncHud(id, g_SyncHudKeys);
		}

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

			switch (g_ShowTimer[id])
			{
			case 1: client_print(id, print_center, "Time: %02d:%02d | CPs: %d | TPs: %d %s",
						min, sec, g_CpCounters[targetId][COUNTER_CP], g_CpCounters[targetId][COUNTER_TP], get_bit(g_baIsPaused, targetId) ? "| *Paused*" : "");
			case 2:
				{
					set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.10, 0, 0.0, 999999.0, 0.0, 0.0, -1);
					ShowSyncHudMsg(id, g_SyncHudTimer, "Time: %02d:%02d | CPs: %d | TPs: %d %s",
						min, sec, g_CpCounters[targetId][COUNTER_CP], g_CpCounters[targetId][COUNTER_TP], get_bit(g_baIsPaused, targetId) ? "| *Paused*" : "");
				}
			}
		}
	}
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
	// Even frags to mantain frags equals to teleports
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
			InitPlayer(i);
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

public Fw_FmPlayerPostThinkPre(id)
{
	if (!g_RestoreSolidStates)
		return;

	g_RestoreSolidStates = false;

	static i;
	for (i = 1; i <= g_MaxPlayers; i++)
	{
		if (IsConnected(i) && g_SolidState[i] >= 0)
			set_pev(i, pev_solid, g_SolidState[i]);
	}
}

public Fw_FmAddToFullPackPost(es, e, ent, host, hostflags, player, pSet)
{
	if (!player || ent == host || IsHltv(host) || !IsConnected(ent) || !IsConnected(host) || !get_pcvar_num(pcvar_kz_semiclip) || pev(host, pev_iuser1) || !get_orig_retval())
		return FMRES_IGNORED;

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

GetNextNumber(buffer[], &pos)
{
	while ((buffer[pos] < '0' || buffer[pos] > '9') && buffer[pos] != '-' && buffer[pos] != 0)
		pos++;
	if (buffer[pos] == 0)
		return 0;

	new i = pos;
	while (buffer[pos] >= '0' && buffer[pos] <= '9' || buffer[pos] == '-')
		pos++;
	buffer[pos] = 0;
	pos++;

	return str_to_num(buffer[i]);
}

Float:GetNextFloat(buffer[], &pos)
{
	while ((buffer[pos] < '0' || buffer[pos] > '9') && buffer[pos] != '-' && buffer[pos] != '.' && buffer[pos] != 0)
		pos++;
	if (buffer[pos] == 0)
		return 0.0;

	new i = pos;
	while (buffer[pos] >= '0' && buffer[pos] <= '9' || buffer[pos] == '-' || buffer[pos] == '.')
		pos++;
	buffer[pos] = 0;
	pos++;

	return str_to_float(buffer[i]);
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

GetColorlessName(id, name[], len)
{
	get_user_name(id, name, len);

	// Clear out color codes
	new i, j;
	while (name[i])
	{
		if (name[i] == '^' && name[i + 1] >= '0' && name[i + 1] <= '9')
		{
			i++;
		}
		else
		{
			if (j != i)
				name[j] = name[i];
			j++;
		}
		i++;
	}
	name[j] = 0;
}

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

LoadRecords(bool:pro)
{
	new file = fopen(pro ? g_StatsFilePro : g_StatsFileNub, "r");
	if (!file) return;

	new data[1024], stats[STATS], uniqueid[32], name[32], cp[24], tp[24], i;
	new kztime[24], timestamp[24];
	new current_time = get_systime();
	new Array:arr = pro ? g_ArrayStatsPro : g_ArrayStatsNub;
	ArrayClear(arr);

	while (!feof(file))
	{
		fgets(file, data, charsmax(data));
		if (!strlen(data))
			continue;

		parse(data, uniqueid, charsmax(uniqueid), name, charsmax(name),
			cp, charsmax(cp), tp, charsmax(tp), kztime, charsmax(kztime), timestamp, charsmax(timestamp));

		stats[STATS_TIMESTAMP] = str_to_num(timestamp);

		// Stale old records that are below specified amount, otherwise we use them to inform player about better/worse time and position
		if (current_time - stats[STATS_TIMESTAMP] > staleStatTime &&
			i > keepStatPlayers)
			continue;

		copy(stats[STATS_ID], charsmax(stats[STATS_ID]), uniqueid);
		copy(stats[STATS_NAME], charsmax(stats[STATS_NAME]), name);
		stats[STATS_CP] = str_to_num(cp);
		stats[STATS_TP] = str_to_num(tp);
		stats[STATS_TIME] = _:str_to_float(kztime);

		ArrayPushArray(arr, stats);
		i++;
	}

	fclose(file);
}

SaveRecords(bool:pro)
{
	new file = fopen(pro ? g_StatsFilePro : g_StatsFileNub, "w+");
	if (!file) return;

	new stats[STATS];
	new Array:arr = pro ? g_ArrayStatsPro : g_ArrayStatsNub;

	for (new i; i < ArraySize(arr); i++)
	{
		ArrayGetArray(arr, i, stats);

		fprintf(file, "\"%s\" \"%s\" %d %d %.5f %i\n",
			stats[STATS_ID],
			stats[STATS_NAME],
			stats[STATS_CP],
			stats[STATS_TP],
			stats[STATS_TIME],
			stats[STATS_TIMESTAMP]);
	}

	fclose(file);
}

UpdateRecords(id, Float:kztime, bool:pro)
{
	new uniqueid[32], name[32], rank;
	new stats[STATS], insertItemId = -1, deleteItemId = -1;
	new minutes, Float:seconds, Float:slower, Float:faster;
	LoadRecords(pro);
	new Array:arr = pro ? g_ArrayStatsPro : g_ArrayStatsNub;

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
			client_print(id, print_chat, "[%s] You failed your time by %02d:%06.3f", PLUGIN_TAG, minutes, seconds);

			return;
		}

		faster = stats[STATS_TIME] - kztime;
		minutes = floatround(faster, floatround_floor) / 60;
		seconds = faster - (60 * minutes);
		client_print(id, print_chat, "[%s] You improved your time by %02d:%06.3f", PLUGIN_TAG, minutes, seconds);

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
	if (rank <= 15)
	{
		client_cmd(0, "spk woop");
		client_print(0, print_chat, "[%s] %s is now on place %d in %s 15", PLUGIN_TAG, name, rank, pro ? "Pro" : "Noob");
	}
	else
		client_print(0, print_chat, "[%s] %s's rank is %d of %d among %s players", PLUGIN_TAG, name, rank, ArraySize(arr), pro ? "Pro" : "Noob");

	SaveRecords(pro);
}

ShowTopClimbers(id, bool:pro)
{
	new buffer[2048], len;
	new stats[STATS], date[32], time[32], minutes, Float:seconds;
	LoadRecords(pro);
	new Array:arr = pro ? g_ArrayStatsPro : g_ArrayStatsNub;
	new size = min(ArraySize(arr), 15);

	if (pro)
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time              Date\n\n");
	else
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time       CP  TP         Date\n\n");

	for (new i = 0; i < size && charsmax(buffer) - len > 0; i++)
	{
		ArrayGetArray(arr, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[STATS_NAME][17] = EOS;

		minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
		seconds = stats[STATS_TIME] - (60 * minutes);

		formatex(time, charsmax(time), "%02d:%06.3f", minutes, seconds);
		format_time(date, charsmax(date), "%d/%m/%Y", stats[STATS_TIMESTAMP]);

		if (pro)
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s         %s\n", i + 1, stats[STATS_NAME], time, date);
		else
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s  %3d %3d        %s\n", i + 1, stats[STATS_NAME], time, stats[STATS_CP], stats[STATS_TP], date);
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "\n%s %s", PLUGIN, VERSION);

	show_motd(id, buffer, pro ? "Pro15 Climbers" : "Noob15 Climbers");

	return PLUGIN_HANDLED;
}
