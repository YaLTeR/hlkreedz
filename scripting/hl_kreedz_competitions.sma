
#pragma semicolon 1
#pragma ctrlchar '\'

#include <amxmodx>
#include <amxmisc>
#include <hlkz>

#define PLUGIN  "HLKZ Competitions"
#define VERSION "0.1.0"
#define AUTHOR  "naz"

#define PLUGIN_TAG "HLKZ"

// TODO: remove these from hl_kreedz.sma
#define TASKID_CAM_UNFREEZE             1622952
#define TASKID_CUP_CHANGE_MAP           5357015
#define TASKID_CUP_START_MATCH          6357015
#define TASKID_CUP_FORCE_SPECTATORS     7357015
#define TASKID_CUP_FINALLY_FIRST_BAN    8357015
#define TASKID_CUP_TENSION_FIRST_BAN    9357015

#define MAX_MAP_INSERTIONS_AT_ONCE      7

// TODO: refactor, it's repeated in the main plugin
#define IsPlayer(%1) (1 <= %1 <= g_MaxPlayers)


// ENUMS
enum MENU_CUP
{
	MENU_CUP_MANAGE_MATCHES = 0,
	MENU_CUP_CREATE_MATCH,
	MENU_CUP_MANAGE_MAP_POOL,
	MENU_CUP_FORCE_READY_UP,
	MENU_CUP_MAP_CHANGE_DELAY,
	MENU_CUP_MATCH_AGABORT_DELAY
}

enum MENU_MATCH_EDIT
{
	MENU_MATCH_EDIT_BEST_OF = 0,
	MENU_MATCH_EDIT_PLAYER1,
	MENU_MATCH_EDIT_PLAYER2,
	MENU_MATCH_EDIT_MAP_FORMAT,
	MENU_MATCH_EDIT_PLAYER_FORMAT,
	MENU_MATCH_EDIT_RANDOM_PLAYER_ORDER,
	MENU_MATCH_EDIT_RELOAD,
	MENU_MATCH_EDIT_START
}

enum MENU_MAP_POOL
{
	MENU_MAP_POOL_VIEW = 0,
	MENU_MAP_POOL_ADD,
	MENU_MAP_POOL_REMOVE,
	MENU_MAP_POOL_CLEAR,
	MENU_MAP_POOL_RELOAD
}

enum MAP_POOL_ACTION
{
	MP_ACTION_VIEW,  // TODO: replace with EDIT instead of VIEW and allow setting the map winner and state through that
	MP_ACTION_REMOVE,
	MP_ACTION_PICK,
	MP_ACTION_BAN
}


// STRUCTS
// TODO: refactor to allow for team matches
enum _:MATCH
{
	MATCH_BEST_OF,
	MATCH_PLAYER1,
	MATCH_PLAYER2,
	MATCH_STEAM1[32],
	MATCH_STEAM2[32],
	MATCH_SCORE1,
	MATCH_SCORE2,
	bool:MATCH_READY1,
	bool:MATCH_READY2,

	// This is about the order in which maps are picked or banned in a match
	// e.g.: PPBBPPD <- Pick map, pick map, ban map, ban map, pick map, pick map, and last is the autopicked decider (D)
	MATCH_MAP_FORMAT[MAX_MATCH_MAPS + 1],

	// This is about the order in which the 2 players (A and B) in a match have to make the pick/ban decisions
	// e.g.: ABBABAD <- First goes player A, then B, then B... and at last the decider (D)
	MATCH_PLAYER_FORMAT[MAX_MATCH_MAPS + 1],

	// Whether to ignore or not the order for players A and B, randomly swapping (or not) A and B
	bool:MATCH_HAS_RANDOM_SEED
}


// GLOBALS

// TODO: refactor, they are repeated in the main plugin
new const CONFIGS_SUB_DIR[] = "hl_kreedz";
new const MAP_POOL_FILE[]   = "map_pool.ini";
new const CUP_FILE[]        = "cup.ini";

new g_MaxPlayers;

new g_CurrMatch[MATCH];

new Trie:g_MatchMapPool;    // mapName->mapState (MAP_BANNED, MAP_PICKED, etc.)

new g_Map[64];
new g_ConfigsDir[256];
new g_MapPoolFile[256];
new g_CupFile[256];

new bool:g_IsCupStarting;
new bool:g_IsMatchEditionDirty;


// MENU CALLBACKS
new g_CupMenuItemCallback;
new g_MatchesMenuItemCallback;
new g_MatchEditMenuItemCallback;
new g_MatchPlayersMenuItemCallback;
new g_MapPoolMenuItemCallback;
new g_ShowMapsMenuItemCallback;


// CVARS
new pcvar_kz_cup_format;
new pcvar_kz_cup_map_change_delay;
new pcvar_kz_cup_agabort_delay;

// SYNC HUD HANDLES
new g_SyncHudCupMaps;


public plugin_natives()
{
	register_native("HLKZ_IsPlayingMatch", "native_is_playing_match");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// CVaras
	pcvar_kz_cup_format           = register_cvar("kz_cup_format", "ABABABD");
	pcvar_kz_cup_map_change_delay = register_cvar("kz_cup_map_change_delay", "12.0");
	pcvar_kz_cup_agabort_delay    = register_cvar("kz_cup_agabort_delay", "3.0");

	// Chat commands
	register_clcmd("say /cup", "CmdCup", ADMIN_CFG, "- shows the cup menu");
	register_clcmd("say /ready", "CmdReady", _, "- readies up for a match");
	register_clcmd("say /forceready", "CmdCupForceReady", ADMIN_CFG, "- forces players to ready up");

	// Non-chat commands
	// TODO: allow making cups through command again, even though it's annoying with so many arguments
	//register_clcmd("kz_cup",            "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	//register_clcmd("kz_bo",             "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	//register_clcmd("kz_bestof",         "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	//register_clcmd("kz_bestofn",        "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	register_clcmd("kz_cup_reset_maps", "CmdResetCupMapStates", ADMIN_CFG, "- resets the state of all the maps in the pool");
	register_clcmd("kz_cup_clear",      "CmdClearCup",          ADMIN_CFG, "- clears all the cached cup data");
	register_clcmd("kz_map_add",        "CmdMapInsertHandler",  ADMIN_CFG, "- adds a map to the map pool");
	register_clcmd("kz_map_insert",     "CmdMapInsertHandler",  ADMIN_CFG, "- adds a map to the map pool");
	register_clcmd("kz_map_del",        "CmdMapDeleteHandler",  ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_delete",     "CmdMapDeleteHandler",  ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_remove",     "CmdMapDeleteHandler",  ADMIN_CFG, "- removes a map from the map pool");
	register_clcmd("kz_map_state",      "CmdMapStateHandler",   ADMIN_CFG, "- modifies the state of a map in the pool");
	register_clcmd("kz_map_winner",     "CmdMapWinnerHandler",  ADMIN_CFG, "- set the winner of the current cup map.");
	register_clcmd("kz_map_pool_show",  "CmdMapsShowHandler",   ADMIN_CFG, "- shows the maps and their states on the screen");
	register_clcmd("kz_map_pool_clear", "CmdMapsClearHandler",  ADMIN_CFG, "- clears the map pool (leaves it empty)");
	register_clcmd("kz_cup_forceready", "CmdCupForceReady",     ADMIN_CFG, "- forces players to ready up");
	register_clcmd("kz_cup_maps",       "CmdCupMapsHandler",    ADMIN_CFG, "- how many maps to play, e.g.: 5 for a Bo5.");

	// Messagemode commands
	register_clcmd("EDIT_MAP_CHANGE_DELAY",    "CmdEditMapChangeDelay",     ADMIN_CFG);
	register_clcmd("EDIT_MATCH_AGABORT_DELAY", "CmdEditMatchAgabortDelay",  ADMIN_CFG);
	register_clcmd("EDIT_MATCH_BEST_OF",       "CmdEditMatchBestOf",        ADMIN_CFG);
	register_clcmd("EDIT_MATCH_MAP_FORMAT",    "CmdEditMatchMapFormat",     ADMIN_CFG);
	register_clcmd("EDIT_MATCH_PLAYER_FORMAT", "CmdEditMatchPlayerFormat",  ADMIN_CFG);
	register_clcmd("ADD_MAP_POOL_MAP",         "InsertMapIntoPool",         ADMIN_CFG);
	register_clcmd("CONFIRM_START_CUP",        "ConfirmStartCup",           ADMIN_CFG);

	// Menu callbacks
	g_CupMenuItemCallback          = menu_makecallback("CupMenuItemCallback");
	g_MatchesMenuItemCallback      = menu_makecallback("MatchesMenuItemCallback");
	g_MatchEditMenuItemCallback    = menu_makecallback("MatchEditMenuItemCallback");
	g_MatchPlayersMenuItemCallback = menu_makecallback("MatchPlayersMenuItemCallback");
	g_MapPoolMenuItemCallback      = menu_makecallback("MapPoolMenuItemCallback");
	g_ShowMapsMenuItemCallback     = menu_makecallback("ShowMapsMenuItemCallback");

	// Sync hud initializations
	g_SyncHudCupMaps = CreateHudSyncObj();

	// Others
	g_MaxPlayers = get_maxplayers();
}

public plugin_cfg()
{
	server_print("[%s] [%.3f] Executing HLKZ Competitions plugin_cfg()", PLUGIN_TAG, get_gametime());
	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	// Dive into our custom directory
	format(g_ConfigsDir, charsmax(g_ConfigsDir), "%s/%s", g_ConfigsDir, CONFIGS_SUB_DIR);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	// Load map pool for kz_cup
	formatex(g_MapPoolFile, charsmax(g_MapPoolFile), "%s/%s", g_ConfigsDir, MAP_POOL_FILE);
	formatex(g_CupFile, charsmax(g_CupFile), "%s/%s", g_ConfigsDir, CUP_FILE);
	LoadMapPool();
	LoadMatch();
}

public plugin_end()
{
	TrieDestroy(g_MatchMapPool);
}

public client_putinserver(id)
{
	// Link this player to the cup player
	new uniqueId[32];
	HLKZ_GetUserUniqueId(id, uniqueId);

	if (equal(g_CurrMatch[MATCH_STEAM1], uniqueId))
		g_CurrMatch[MATCH_PLAYER1] = id;

	if (equal(g_CurrMatch[MATCH_STEAM2], uniqueId))
		g_CurrMatch[MATCH_PLAYER2] = id;
}

public client_disconnect(id)
{
	if (id == g_CurrMatch[MATCH_PLAYER1])
	{
		g_CurrMatch[MATCH_PLAYER1] = 0;
		g_CurrMatch[MATCH_STEAM1][0] = EOS;
		g_CurrMatch[MATCH_READY1] = false;
		g_CurrMatch[MATCH_SCORE1] = 0;  // TODO: review
	}
	
	if (id == g_CurrMatch[MATCH_PLAYER2])
	{
		g_CurrMatch[MATCH_PLAYER2] = 0;
		g_CurrMatch[MATCH_STEAM2][0] = EOS;
		g_CurrMatch[MATCH_READY2] = false;
		g_CurrMatch[MATCH_SCORE2] = 0;  // TODO: review
	}

	if (HLKZ_IsMatchRunning() && HLKZ_IsPlayingMatch(id))
		SaveRecordedCupRun(id);
}

public hlkz_postwelcome(id)
{
	if (g_CurrMatch[MATCH_PLAYER1] || g_CurrMatch[MATCH_PLAYER2])
		set_pev(id, pev_iuser1, OBS_IN_EYE);
	else
		set_pev(id, pev_iuser1, OBS_ROAMING);

	if (g_CurrMatch[MATCH_PLAYER1])
		set_pev(id, pev_iuser2, g_CurrMatch[MATCH_PLAYER1]);
	else if (g_CurrMatch[MATCH_PLAYER2])
		set_pev(id, pev_iuser2, g_CurrMatch[MATCH_PLAYER2]);

	new target = pev(id, pev_iuser2);
	if (IsPlayer(target))
	{
		new payLoad[2];
		payLoad[0] = id;
		payLoad[1] = target;

		// These weird ids are so that there's no task collision
		new taskId = id * 36;
		set_task(0.03, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 2, payLoad, sizeof(payLoad));
		set_task(0.12, "RestoreSpecCam", TASKID_CAM_UNFREEZE + taskId + 3, payLoad, sizeof(payLoad));
	}
}

public hlkz_stop_match()
{
	g_CurrMatch[MATCH_READY1] = false;
	g_CurrMatch[MATCH_READY2] = false;
}

public hlkz_run_finish(id)
{
	if (!HLKZ_IsMatchRunning())
		return;

	if (IsCupMap() && IsCupPlayer(id))
	{
		HLKZ_AllowSpectate(true);

		// Save replays of both participants, for the one that didn't reach the button too
		SaveRecordedCupRun(g_CurrMatch[MATCH_PLAYER1]);
		SaveRecordedCupRun(g_CurrMatch[MATCH_PLAYER2]);

		SetCupMapWinner(id);
	}
}

public hlkz_pre_save_on_disconnect(id)
{
	if (IsCupPlayer(id) && HLKZ_IsMatchRunning())
		SaveRecordedCupRun(id);
}

public native_is_playing_match(plugin, params)
{
	if (params != 1)
		return PLUGIN_CONTINUE;

	new id = get_param(1);
	if (!id)
		return PLUGIN_CONTINUE;

	// TODO: check for HLKZ_IsMatchRunning()? may want to store that info in this plugin instead of asking the main one

	return IsCupMap() && IsCupPlayer(id);
}


///////////////////////////////////////////////////////////////
// MENU HANDLING
///////////////////////////////////////////////////////////////

ShowCupMenu(id)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new menu = menu_create("Cup menu:", "HandleCupMenu");

	menu_additem(menu, "Manage matches",       _, _, g_CupMenuItemCallback);  // 1
	menu_additem(menu, "Create match",         _, _, g_CupMenuItemCallback);  // 2
	menu_additem(menu, "Manage map pool",      _, _, g_CupMenuItemCallback);  // 3
	menu_additem(menu, "Force ready up",       _, _, g_CupMenuItemCallback);  // 4

	new itemText[64];
	formatex(itemText, charsmax(itemText), "Map change delay: %.1f", get_pcvar_float(pcvar_kz_cup_map_change_delay));
	menu_additem(menu, itemText, _, _, g_CupMenuItemCallback);  // 5

	formatex(itemText, charsmax(itemText), "Match agabort delay: %.1f", get_pcvar_float(pcvar_kz_cup_agabort_delay));
	menu_additem(menu, itemText, _, _, g_CupMenuItemCallback);  // 6

	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleCupMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch (item)
	{
		case MENU_CUP_MANAGE_MATCHES:
		{
			ShowMatchesMenu(id);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_CUP_CREATE_MATCH:
		{
			// TODO: make a menu before showing the match edit menu, where
			// you can choose a preset, e.g.: you choose HLKZ 6 Bo3 and it
			// autofills the corresponding map/player formats and seeding
			// into the edit menu
			ShowMatchEditMenu(id, true);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_CUP_MANAGE_MAP_POOL:
		{
			ShowMapPoolMenu(id);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_CUP_FORCE_READY_UP:
		{
			//menu_destroy(menu);
			DoCupForceReady(id);
			client_print(id, print_chat, "[%s] Forcing players to ready up.", PLUGIN_TAG);
		}
		case MENU_CUP_MAP_CHANGE_DELAY:
		{
			client_cmd(id, "messagemode EDIT_MAP_CHANGE_DELAY");
			client_print(id, print_chat, "[%s] Type in chat the new delay (in seconds) for autoswitching maps in the cup.", PLUGIN_TAG);
		}
		case MENU_CUP_MATCH_AGABORT_DELAY:
		{
			client_cmd(id, "messagemode EDIT_MATCH_AGABORT_DELAY");
			client_print(id, print_chat, "[%s] Type in chat the new delay (in seconds) for the agabort after someone wins the map.", PLUGIN_TAG);
		}
	}
	// TODO: try caching menus and see if it works fine
	ShowCupMenu(id);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public CupMenuItemCallback(id, menu, item)
{
	return ITEM_IGNORE;
}

ShowMatchesMenu(id)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	//LoadMatch();

	//if (get_cvar_num("kz_mysql") > 0)
	//{
	//	// TODO: get matches from database
	//	//return PLUGIN_HANDLED;
	//}
	new menu = menu_create("Matches:", "HandleMatchesMenu");

	new itemText[64], player1Text[33], player2Text[33];
	if (g_CurrMatch[MATCH_PLAYER1])
		get_user_name(g_CurrMatch[MATCH_PLAYER1], player1Text, charsmax(player1Text));
	else
		copy(player1Text, charsmax(player1Text), g_CurrMatch[MATCH_STEAM1]);

	if (g_CurrMatch[MATCH_PLAYER2])
		get_user_name(g_CurrMatch[MATCH_PLAYER2], player2Text, charsmax(player2Text));
	else
		copy(player2Text, charsmax(player2Text), g_CurrMatch[MATCH_STEAM2]);

	if (!player1Text[0])
		copy(player1Text, charsmax(player1Text), "(no player yet)");

	if (!player2Text[0])
		copy(player2Text, charsmax(player2Text), "(no player yet)");

	new dirtyIndicator[5];
	if (g_IsMatchEditionDirty)
		copy(dirtyIndicator, charsmax(dirtyIndicator), " (*)");

	formatex(itemText, charsmax(itemText), "%s vs %s %s", player1Text, player2Text, dirtyIndicator);
	menu_additem(menu, itemText, _, _, g_MatchesMenuItemCallback);

	menu_setprop(menu, MPROP_NOCOLORS, 0);
	menu_setprop(menu, MPROP_EXITNAME, "Back");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleMatchesMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowCupMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	//if (get_cvar_num("kz_mysql") > 0)
	//{
	//	// TODO: handle matches from database
	//	//ShowMatchEditMenu(id, item);
	//	//return PLUGIN_HANDLED;
	//}

	// TODO: add support for multiple matches, or like a match history
	if (0 == item)
		ShowMatchEditMenu(id);

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public MatchesMenuItemCallback(id, menu, item)
{
	return ITEM_IGNORE;
}

// TODO: refactor to edit not only the current match but others too?
ShowMatchEditMenu(id, bool:isNewMatch = false)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new menu;
	if (isNewMatch)
	{
		menu = menu_create("Create match:", "HandleMatchEditMenu");

		// Clear some stuff, but not the format and such because
		// it will probably be the same as the previous match
		g_CurrMatch[MATCH_PLAYER1] = 0;
		g_CurrMatch[MATCH_PLAYER2] = 0;
		g_CurrMatch[MATCH_STEAM1][0] = EOS;
		g_CurrMatch[MATCH_STEAM2][0] = EOS;
		g_CurrMatch[MATCH_SCORE1] = 0;
		g_CurrMatch[MATCH_SCORE2] = 0;
		g_CurrMatch[MATCH_READY1] = false;
		g_CurrMatch[MATCH_READY2] = false;

		g_IsMatchEditionDirty = false;
	}
	else
	{
		new headerText[20], dirtyIndicator[5];
		if (g_IsMatchEditionDirty)
			copy(dirtyIndicator, charsmax(dirtyIndicator), " (*)");

		formatex(headerText, charsmax(headerText), "Edit match: %s", dirtyIndicator);

		menu = menu_create(headerText, "HandleMatchEditMenu");
	}

	new itemText[64], player1Name[33], player2Name[33];
	if (g_CurrMatch[MATCH_PLAYER1])
		get_user_name(g_CurrMatch[MATCH_PLAYER1], player1Name, charsmax(player1Name));
	else
		copy(itemText, charsmax(itemText), g_CurrMatch[MATCH_STEAM1]);

	if (g_CurrMatch[MATCH_PLAYER2])
		get_user_name(g_CurrMatch[MATCH_PLAYER2], player2Name, charsmax(player2Name));
	else
		copy(itemText, charsmax(itemText), g_CurrMatch[MATCH_STEAM2]);

	formatex(itemText, charsmax(itemText), "Best of: %d", g_CurrMatch[MATCH_BEST_OF]);
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	formatex(itemText, charsmax(itemText), "Player A: %s", player1Name);
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	formatex(itemText, charsmax(itemText), "Player B: %s", player2Name);
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	formatex(itemText, charsmax(itemText), "Map format (pick/ban): %s", g_CurrMatch[MATCH_MAP_FORMAT]);
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	formatex(itemText, charsmax(itemText), "Player format (A/B): %s", g_CurrMatch[MATCH_PLAYER_FORMAT]);
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	formatex(itemText, charsmax(itemText), "Random seed? %s", g_CurrMatch[MATCH_HAS_RANDOM_SEED] ? "yes" : "no");
	menu_additem(menu, itemText, _, _, g_MatchEditMenuItemCallback);

	menu_additem(menu, "Reload from file/DB", _, _, g_MatchEditMenuItemCallback);

	menu_addblank(menu, 0);

	if (!g_IsCupStarting)
		menu_additem(menu, "Start now", _, _, g_MatchEditMenuItemCallback);
	else
		menu_additem(menu, "Starting... waiting for players to pick/ban", _, _, g_MatchEditMenuItemCallback);

	menu_addblank2(menu);

	menu_additem(menu, "Back", _, _, g_MatchEditMenuItemCallback);

	menu_setprop(menu, MPROP_NOCOLORS, 0);
	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); // fixes *sometimes* appearing a second Exit option

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleMatchEditMenu(id, menu, item)
{
	if (item == MENU_EXIT || item >= 9)
	{
		if (g_IsMatchEditionDirty)
			WriteMatchFile(id);

		// TODO: check if it could have been the cup menu instead of the matches menu
		ShowMatchesMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch (item)
	{
		case MENU_MATCH_EDIT_BEST_OF:
		{
			client_cmd(id, "messagemode EDIT_MATCH_BEST_OF");
			client_print(id, print_chat, "[%s] Type in chat the number of maps to be played in the match at maximum (e.g. 3 for a Bo3).", PLUGIN_TAG);
		}
		case MENU_MATCH_EDIT_PLAYER1:
		{
			ShowMatchPlayersMenu(id, PF_PLAYER1);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_MATCH_EDIT_PLAYER2:
		{
			ShowMatchPlayersMenu(id, PF_PLAYER2);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_MATCH_EDIT_MAP_FORMAT:
		{
			client_cmd(id, "messagemode EDIT_MATCH_MAP_FORMAT");
			client_print(id, print_chat, "[%s] Type in chat the map pick/ban order, e.g.: BBPPBB, where B is ban and P is pick.", PLUGIN_TAG);
		}
		case MENU_MATCH_EDIT_PLAYER_FORMAT:
		{
			client_cmd(id, "messagemode EDIT_MATCH_PLAYER_FORMAT");
			client_print(id, print_chat, "[%s] Type in chat the player decision order, e.g.: ABBABA, where player A starts and B follows.", PLUGIN_TAG);
		}
		case MENU_MATCH_EDIT_RANDOM_PLAYER_ORDER:
		{
			g_CurrMatch[MATCH_HAS_RANDOM_SEED] = !g_CurrMatch[MATCH_HAS_RANDOM_SEED];
			g_IsMatchEditionDirty = true;
		}
		case MENU_MATCH_EDIT_RELOAD:
		{
			LoadMatch();
			// TODO: reload from DB. Then this chat message would go on the query callback
			client_print(id, print_chat, "[%s] The match has been reloaded.", PLUGIN_TAG);
		}
		case MENU_MATCH_EDIT_START:
		{
			if (!g_IsCupStarting)
			{
				if (IsCupOngoing())
				{
					client_cmd(id, "messagemode CONFIRM_START_CUP");
					client_print(id, print_chat, "[%s] There's an ongoing match, are you sure you want to start a new one? type 'yes' in chat (no quotes) to confirm.", PLUGIN_TAG);
				}
				else
					StartCup(id);

				if (IsCupPlayer(id))
				{
					// We will have to show this admin the pick/ban menu, so destroy the menu here
					// and don't show the match edit menu again
					menu_destroy(menu);
					return PLUGIN_HANDLED;
				}
			}
			else
				client_print(id, print_chat, "[%s] Cannot start another cup, there's one already starting. Reset the map and start it again if it bugged out", PLUGIN_TAG);
		}
	}
	ShowMatchEditMenu(id);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public MatchEditMenuItemCallback(id, menu, item)
{
	if (item >= 0 && item <= 9)
	{
		if (g_IsCupStarting)
			return DisableMenuItem(menu, item);
	}

	return ITEM_IGNORE;
}

ShowMatchPlayersMenu(id, PLAYER_FORMAT:playerType)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new headerText[32];
	formatex(headerText, charsmax(headerText), "Select player %s:", playerType);

	new menu = menu_create(headerText, "HandleMatchPlayersMenu");

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum);
	for (new i = 0; i < playersNum; i++)
	{
		new pid = players[i];
		new itemText[64], playerName[33], chosenPlayerType[12];
		get_user_name(pid, playerName, charsmax(playerName));

		if (g_CurrMatch[MATCH_PLAYER1] == pid)
			copy(chosenPlayerType, charsmax(chosenPlayerType), " [Player A]");
		else if (g_CurrMatch[MATCH_PLAYER2] == pid)
			copy(chosenPlayerType, charsmax(chosenPlayerType), " [Player B]");

		formatex(itemText, charsmax(itemText), "%s (#%d)%s", playerName, get_user_userid(pid), chosenPlayerType);

		new itemInfo[2];
		itemInfo[0] = _:playerType; // TODO: check if this assignment can go before the loop without repercussions
		itemInfo[1] = pid;

		menu_additem(menu, itemText, itemInfo, _, g_MatchPlayersMenuItemCallback);
	}
	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleMatchPlayersMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowMatchEditMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	new itemInfo[2];
	menu_item_getinfo(menu, item, _, itemInfo, sizeof(itemInfo));

	new PLAYER_FORMAT:playerType = PLAYER_FORMAT:itemInfo[0];
	new chosenId = itemInfo[1];

	if (item >= 0)
	{
		if (chosenId == g_CurrMatch[MATCH_PLAYER1] || chosenId == g_CurrMatch[MATCH_PLAYER2])
		{
			client_print(id, print_chat, "[%s] That player is already chosen as Player A or B", PLUGIN_TAG);
			//ShowMatchPlayersMenu(id, playerType);
			//menu_destroy(menu);
			//return PLUGIN_HANDLED;
		}
		new uniqueId[32];
		HLKZ_GetUserUniqueId(chosenId, uniqueId);

		if (playerType == PF_PLAYER1)
		{
			if (g_CurrMatch[MATCH_PLAYER1] != chosenId)
			{
				g_CurrMatch[MATCH_PLAYER1] = chosenId;
				copy(g_CurrMatch[MATCH_STEAM1], charsmax(g_CurrMatch[MATCH_STEAM1]), uniqueId);
				g_IsMatchEditionDirty = true;
			}
		}
		else
		{
			if (g_CurrMatch[MATCH_PLAYER2] != chosenId)
			{
				g_CurrMatch[MATCH_PLAYER2] = chosenId;
				copy(g_CurrMatch[MATCH_STEAM2], charsmax(g_CurrMatch[MATCH_STEAM1]), uniqueId);
				g_IsMatchEditionDirty = true;
			}
		}
	}
	ShowMatchEditMenu(id);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public MatchPlayersMenuItemCallback(id, menu, item)
{
	if (item >= 0)
	{
		//if (pid == g_CurrMatch[MATCH_PLAYER1] || pid == g_CurrMatch[MATCH_PLAYER2])
		//	return DisableMenuItem(menu, item);
	}
	return ITEM_IGNORE;
}

ShowMapPoolMenu(id)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new menu = menu_create("Map pool menu:", "HandleMapPoolMenu");

	new itemText[64];

	formatex(itemText, charsmax(itemText), "View (%d maps)", TrieGetSize(g_MatchMapPool));
	menu_additem(menu, itemText, _, _, g_MapPoolMenuItemCallback);

	menu_additem(menu, "Add a map",           _, _, g_MapPoolMenuItemCallback);
	menu_additem(menu, "Remove a map",        _, _, g_MapPoolMenuItemCallback);
	menu_additem(menu, "Clear",               _, _, g_MapPoolMenuItemCallback);
	menu_additem(menu, "Reload from file/DB", _, _, g_MapPoolMenuItemCallback);

	menu_setprop(menu, MPROP_NOCOLORS, 0);
	menu_setprop(menu, MPROP_EXITNAME, "Back");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleMapPoolMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowCupMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch (item)
	{
		case MENU_MAP_POOL_VIEW:
		{
			//ShowMapsMenu(id, MP_ACTION_VIEW);
			CmdMapsShowHandler(id);
			//menu_destroy(menu);
			//ShowMapPoolMenu(id);
			//return PLUGIN_HANDLED;
		}
		case MENU_MAP_POOL_ADD:
		{
			client_cmd(id, "messagemode ADD_MAP_POOL_MAP");
			client_print(id, print_chat, "[%s] Type in chat the exact name of a map you want to add to the pool.", PLUGIN_TAG);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_MAP_POOL_REMOVE:
		{
			ShowMapsMenu(id, MP_ACTION_REMOVE);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		case MENU_MAP_POOL_CLEAR:
		{
			// TODO: refactor this and CmdMapsClearHandler to call a function with the common code
			TrieClear(g_MatchMapPool);
			client_print(id, print_chat, "[%s] The map pool has been cleared.", PLUGIN_TAG);
		}
		case MENU_MAP_POOL_RELOAD:
		{
			LoadMapPool();
			// TODO: reload from DB. Then this chat message would go on the query callback
			client_print(id, print_chat, "[%s] The map pool has been reloaded.", PLUGIN_TAG);
		}
	}
	ShowMapPoolMenu(id);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public MapPoolMenuItemCallback(id, menu, item)
{
	return ITEM_IGNORE;
}

ShowMapsMenu(id, MAP_POOL_ACTION:action)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	if (MP_ACTION_REMOVE == action && get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new headerText[16];
	switch (action)
	{
		case MP_ACTION_VIEW:   { copy(headerText, charsmax(headerText), "Maps:"); }
		case MP_ACTION_REMOVE: { copy(headerText, charsmax(headerText), "Remove a map:"); }
		case MP_ACTION_PICK:   { copy(headerText, charsmax(headerText), "Pick a map:"); }
		case MP_ACTION_BAN:    { copy(headerText, charsmax(headerText), "Ban a map:"); }
	}
	new menu = menu_create(headerText, "HandleShowMapsMenu");

	new matchMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti))
	{
		new itemText[64], mapStateText[10];
		TrieIterGetArray(ti, matchMap, sizeof(matchMap));

		if (g_MapStateString[_:matchMap[MAP_STATE_]][0])
		{
			formatex(mapStateText, charsmax(mapStateText), " [%s]", g_MapStateString[_:matchMap[MAP_STATE_]]);
			strtoupper(mapStateText);
		}
		formatex(itemText, charsmax(itemText), "%s %s", matchMap[MAP_NAME], mapStateText);

		new itemInfo[1];
		itemInfo[0] = _:action; // TODO: check if this assignment can go before the loop without repercussions

		menu_additem(menu, itemText, itemInfo, _, g_ShowMapsMenuItemCallback);

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	menu_setprop(menu, MPROP_NOCOLORS, 0);

	if (TrieGetSize(g_MatchMapPool) <= 9)
		menu_setprop(menu, MPROP_PERPAGE, 0);

	if (MP_ACTION_BAN == action || MP_ACTION_PICK == action)
		menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	else
	{
		menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE);
		menu_setprop(menu, MPROP_EXITNAME, "Back");
	}
	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleShowMapsMenu(id, menu, item)
{
	new itemInfo[1], mapName[MAX_MAPNAME_LENGTH], MAP_POOL_ACTION:action;
	menu_item_getinfo(menu, item, _, itemInfo, sizeof(itemInfo), mapName, charsmax(mapName));
	action = MAP_POOL_ACTION:itemInfo[0];

	if (item == MENU_EXIT)
	{
		if (MP_ACTION_VIEW == action || MP_ACTION_REMOVE == action)
			ShowMapPoolMenu(id);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item >= 0)
	{
		switch (action)
		{
			case MP_ACTION_VIEW:
			{
				// TODO: maybe show map stats in the future
				return PLUGIN_HANDLED;
			}
			case MP_ACTION_REMOVE:
			{
				RemoveMapFromPool(id, mapName);
				menu_destroy(menu);
				return PLUGIN_HANDLED;
			}
			case MP_ACTION_PICK, MP_ACTION_BAN:
			{
				ProcessMatchChoice(id, action, mapName);
				menu_destroy(menu);
				return PLUGIN_HANDLED;
			}
		}
	}
	//ShowMapsMenu(id, MP_ACTION_VIEW);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public ShowMapsMenuItemCallback(id, menu, item)
{
	if (item >= 0)
	{
		new itemInfo[1], mapName[MAX_MAPNAME_LENGTH], MAP_POOL_ACTION:action;
		menu_item_getinfo(menu, item, _, itemInfo, sizeof(itemInfo), mapName, charsmax(mapName));
		action = MAP_POOL_ACTION:itemInfo[0];

		if (MP_ACTION_BAN == action || MP_ACTION_PICK == action)
		{
			new cupMap[CUP_MAP];
			TrieGetArray(g_MatchMapPool, mapName, cupMap, sizeof(cupMap));

			if (MAP_IDLE != cupMap[MAP_STATE_])
				return DisableMenuItem(menu, item);
		}
	}
	return ITEM_IGNORE;
}


///////////////////////////////////////////////////////////////
// CHAT COMMAND HANDLING
///////////////////////////////////////////////////////////////

public CmdEditMapChangeDelay(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new Float:oldValue = get_pcvar_float(pcvar_kz_cup_map_change_delay);
	new Float:value = GetFloatArg();

	if (oldValue != value)
	{
		set_pcvar_float(pcvar_kz_cup_map_change_delay, value);
		g_IsMatchEditionDirty = true;
	}
	ShowCupMenu(id);

	return PLUGIN_HANDLED;
}

public CmdEditMatchAgabortDelay(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new Float:value = GetFloatArg();
	set_pcvar_float(pcvar_kz_cup_agabort_delay, value);

	ShowCupMenu(id);

	return PLUGIN_HANDLED;
}

public CmdEditMatchBestOf(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new oldValue = g_CurrMatch[MATCH_BEST_OF];
	new value = GetNumberArg();

	if (oldValue != value)
	{
		g_CurrMatch[MATCH_BEST_OF] = GetNumberArg();
		g_IsMatchEditionDirty = true;
	}
	ShowMatchEditMenu(id);

	return PLUGIN_HANDLED;
}

public CmdEditMatchMapFormat(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new value[MAX_MATCH_MAPS + 1];
	read_args(value, charsmax(value));
	remove_quotes(value);
	trim(value);

	if (!equal(g_CurrMatch[MATCH_MAP_FORMAT], value))
	{
		formatex(g_CurrMatch[MATCH_MAP_FORMAT], charsmax(g_CurrMatch[MATCH_MAP_FORMAT]), value);
		g_IsMatchEditionDirty = true;
	}
	ShowMatchEditMenu(id);

	return PLUGIN_HANDLED;
}

public CmdEditMatchPlayerFormat(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new value[MAX_MATCH_MAPS + 1];
	read_args(value, charsmax(value));
	remove_quotes(value);
	trim(value);

	if (!equal(g_CurrMatch[MATCH_PLAYER_FORMAT], value))
	{
		formatex(g_CurrMatch[MATCH_PLAYER_FORMAT], charsmax(g_CurrMatch[MATCH_PLAYER_FORMAT]), value);
		g_IsMatchEditionDirty = true;
	}
	ShowMatchEditMenu(id);

	return PLUGIN_HANDLED;
}

public CmdCupForceReady(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		DoCupForceReady(id);

	return PLUGIN_HANDLED;
}

public CmdCupMapsHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new mapsToPlay[8];
		read_argv(1, mapsToPlay, charsmax(mapsToPlay));

		g_CurrMatch[MATCH_BEST_OF] = str_to_num(mapsToPlay);
	}

	return PLUGIN_HANDLED;
}

public CmdCup(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		ShowCupMenu(id);

	return PLUGIN_HANDLED;
}

public CmdReady(id, level, cid)
{
	DoReady(id);

	return PLUGIN_HANDLED;
}

public CmdMapsShowHandler(id)
{
	new msg[512], map[MAX_MAPNAME_LENGTH];
	formatex(msg, charsmax(msg), "Map pool:\n");

	// Add first the decider
	new Array:deciderMaps = GetCupMapsWithState(MAP_DECIDER);
	for (new i = 0; i < ArraySize(deciderMaps); i++)
	{
		ArrayGetString(deciderMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [DECIDER]\n", msg, map);
	}

	// Then the picked ones
	new Array:pickedMaps = GetCupMapsWithState(MAP_PICKED);
	for (new i = 0; i < ArraySize(pickedMaps); i++)
	{
		ArrayGetString(pickedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [PICKED]\n", msg, map);
	}

	// Then the played ones
	new Array:playedMaps = GetCupMapsWithState(MAP_PLAYED);
	for (new i = 0; i < ArraySize(playedMaps); i++)
	{
		ArrayGetString(playedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [PLAYED]\n", msg, map);
	}

	// Then the banned ones
	new Array:bannedMaps = GetCupMapsWithState(MAP_BANNED);
	for (new i = 0; i < ArraySize(bannedMaps); i++)
	{
		ArrayGetString(bannedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [BANNED]\n", msg, map);
	}

	// Then the maps that remain untouched yet
	new Array:idleMaps = GetCupMapsWithState(MAP_IDLE);
	for (new i = 0; i < ArraySize(idleMaps); i++)
	{
		ArrayGetString(idleMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s\n", msg, map);
	}

	// TODO: it's probably better to get their RGB after the player settings are read
	// or after they change (with /hudcolor <name|rgb>), because this right here might get called more often
	new rgb[3];
	if (!id)
	{
		// Use white color when showing the list to everyone
		rgb[0] = 255;
		rgb[1] = 255;
		rgb[2] = 255;
	}
	else
	{
		HLKZ_GetHudColor(id, rgb);
		//console_print(id, "rgb: [%d, %d, %d]", rgb[0], rgb[1], rgb[2]);
	}

	set_hudmessage(rgb[0], rgb[1], rgb[2], _, 0.2, 0, 0.0, 6.0, 0.0, 1.0, -1);
	ShowSyncHudMsg(id, g_SyncHudCupMaps, msg);

	return PLUGIN_HANDLED;
}

public CmdMapInsertHandler(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	InsertMapIntoPool(id);

	return PLUGIN_HANDLED;
}

public CmdMapDeleteHandler(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	// Remove up to 5 maps at a time
	new maps[5][32];
	for (new i = 0; i < sizeof(maps); i++) {
		read_argv(i+1, maps[i], charsmax(maps[]));

		if (maps[i][0] && !TrieDeleteKey(g_MatchMapPool, maps[i])) {
			console_print(id, "[%s] Couldn't remove %s from the map pool. Maybe it wasn't in the pool.", PLUGIN_TAG, maps[i]);
		}
	}
	WriteMapPoolFile(id);

	return PLUGIN_HANDLED;
}

// Set the map state you want to some map
public CmdMapStateHandler(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new map[MAX_MAPNAME_LENGTH], action[8];
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

	if (TrieKeyExists(g_MatchMapPool, map))
	{
		new cupMap[CUP_MAP];
		TrieGetArray(g_MatchMapPool, map, cupMap, sizeof(cupMap));

		cupMap[MAP_STATE_] = _:mapState;
		TrieSetArray(g_MatchMapPool, map, cupMap, sizeof(cupMap));

		client_print(0, print_chat, "[%s] %s's new state is: %s.",
			PLUGIN_TAG, map, g_MapStateString[mapState][0] ? g_MapStateString[mapState] : "idle");
	}
	else
		client_print(id, print_chat, "[%s] Sorry, the specified map is not in the pool.", PLUGIN_TAG);

	WriteMapPoolFile(id);

	return PLUGIN_HANDLED;
}

// Let an admin set the winner in case something goes wrong
public CmdMapWinnerHandler(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	if (!IsCupMap())
	{
		client_print(id, print_chat, "[%s] Sorry, cannot set the winner of the current map as it's not in the pool for the cup.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}
	new userid[32], score[8];
	read_argv(1, userid, charsmax(userid));

	trim(userid);

	new player = cmd_target(id, userid, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS);

	if (!player || !IsCupPlayer(player))
	{
		client_print(id, print_chat, "[%s] Sorry, the specified player does not exist or is not a cup player.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	SetCupMapWinner(player);

	return PLUGIN_HANDLED;
}

public CmdMapsClearHandler(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	TrieClear(g_MatchMapPool);
	client_print(id, print_chat, "[%s] The map pool has been cleared.", PLUGIN_TAG);

	return PLUGIN_HANDLED;
}

public CmdResetCupMapStates(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		ResetCupMapStates(id);

	return PLUGIN_HANDLED;
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

public ConfirmStartCup(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new cmdArg[64];
	read_args(cmdArg, charsmax(cmdArg));
	remove_quotes(cmdArg);
	trim(cmdArg);

	if (equali("yes", cmdArg, 3))
		StartCup(id);
	else
		client_print(id, print_chat, "[%s] Didn't confirm, so the cup won't start yet.", PLUGIN_TAG);

	return PLUGIN_HANDLED;
}


///////////////////////////////////////////////////////////////
// GAME LOGIC / OTHERS
///////////////////////////////////////////////////////////////

DoCupForceReady(id)
{
	if (!g_CurrMatch[MATCH_PLAYER1] || !g_CurrMatch[MATCH_PLAYER2])
	{
		console_print(id, "The players could not be found.");
		return;
	}

	if (!g_CurrMatch[MATCH_READY1])
		DoReady(g_CurrMatch[MATCH_PLAYER1]);

	if (!g_CurrMatch[MATCH_READY2])
		DoReady(g_CurrMatch[MATCH_PLAYER2]);
}

DoReady(id)
{
	//console_print(id, "readying up");
	if (HLKZ_GetRunMode(id) != MODE_NORMAL)
	{
		client_print(id, print_chat, "[%s] Cannot /ready now, a match is already running!", PLUGIN_TAG);
		return;
	}

	new uniqueId[32];
	HLKZ_GetUserUniqueId(id, uniqueId);

	if (!IsCupPlayer(id))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you are not a participant in the current cup match.", PLUGIN_TAG);
		return;
	}

	if (CountCupMaps(MAP_IDLE))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, there are still maps to be banned/picked.", PLUGIN_TAG);
		return;
	}

	if (!IsCupMap())
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you must be in one of the maps to be played.", PLUGIN_TAG);
		return;
	}

	if (HLKZ_UsesStartingZone())
	{
		if (!HLKZ_CanTeleportNr(id, CP_TYPE_CUSTOM_START))
		{
			client_print(id, print_chat, "[%s] Cannot /ready yet, you must set a custom start position first (through KZ menu or saying /ss).", PLUGIN_TAG);
			return;
		}
	}
	else if (!HLKZ_CanTeleportNr(id, CP_TYPE_START))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you must press the start button first, to set the start point.", PLUGIN_TAG);
		return;
	}

	// Set the players readiness
	new bool:ready;
	if (id == g_CurrMatch[MATCH_PLAYER1])
	{
		g_CurrMatch[MATCH_READY1] = !g_CurrMatch[MATCH_READY1];
		ready = g_CurrMatch[MATCH_READY1];
	}

	if (id == g_CurrMatch[MATCH_PLAYER2])
	{
		g_CurrMatch[MATCH_READY2] = !g_CurrMatch[MATCH_READY2];
		ready = g_CurrMatch[MATCH_READY2];
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

	if (g_CurrMatch[MATCH_READY1] && g_CurrMatch[MATCH_READY2])
	{
		// Players that won't be playing the match will be forced into spectators and no one will be able to change spec mode
		HLKZ_AllowSpectate(false);

		// TODO: make these 5 seconds to start the match configurable from the menu, like the map change delay
		client_print(0, print_chat, "[%s] Starting in 5 seconds... non-participants will now be switched to spectator mode.", PLUGIN_TAG);
		set_task(1.5,  "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS);
		set_task(4.5,  "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS + 1);
		set_task(4.98, "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS + 2); // just in case someone's being an idiot
		set_task(5.0,  "CupStartMatch",      TASKID_CUP_START_MATCH);
	}
}

LoadMapPool()
{
	g_MatchMapPool = TrieCreate();

	new file = fopen(g_MapPoolFile, "rt");
	if (!file) return;

	new buffer[CUP_MAP + 8];  // some extra space as here integers are as chars and take more space
	while(fgets(file, buffer, charsmax(buffer)))
	{
		new cupMap[CUP_MAP];

		// One map name and state per line
		new mapOrder[4], mapName[MAX_MAPNAME_LENGTH], mapState[3], mapPicker[3];
		parse(buffer,
				mapOrder,	charsmax(mapOrder),
				mapName,	charsmax(mapName),
				mapState,	charsmax(mapState),
				mapPicker,	charsmax(mapPicker));

		cupMap[MAP_ORDER]  = str_to_num(mapOrder);
		cupMap[MAP_STATE_] = _:str_to_num(mapState);
		cupMap[MAP_PICKER] = _:str_to_num(mapPicker);

		formatex(cupMap[MAP_NAME], charsmax(cupMap[MAP_NAME]), "%s", mapName);

		TrieSetArray(g_MatchMapPool, mapName, cupMap, sizeof(cupMap));
	}
	fclose(file);
	server_print("[%s] Map pool loaded (%d maps).", PLUGIN_TAG, TrieGetSize(g_MatchMapPool));
}

LoadMatch()
{
	// Load current match's info
	new file = fopen(g_CupFile, "rt");
	if (!file) return;

	new buffer[256];
	while(fgets(file, buffer, charsmax(buffer)))
	{
		new maps[4], playerFormat[MAX_MATCH_MAPS + 1], mapFormat[MAX_MATCH_MAPS + 1], id1[MAX_AUTHID_LENGTH], id2[MAX_AUTHID_LENGTH], score1[4], score2[4];
		parse(buffer,
				maps,		  charsmax(maps),
				playerFormat, charsmax(playerFormat),
				mapFormat,    charsmax(mapFormat),
				id1,		  charsmax(id1),
				id2,		  charsmax(id2),
				score1,		  charsmax(score1),
				score2,		  charsmax(score2));

		if (!playerFormat[0])
		{
			copy(playerFormat, charsmax(playerFormat), "ABBABA");
			server_print("[%s] Defaulting player format to ABBABA due to lack of format.", PLUGIN_TAG);
		}

		if (!mapFormat[0])
		{
			copy(mapFormat, charsmax(mapFormat), "BBPPBB");
			server_print("[%s] Defaulting map format to BBPPBB due to lack of format.", PLUGIN_TAG);
		}

		g_CurrMatch[MATCH_BEST_OF] = str_to_num(maps);
		//ValidatePlayerFormat(0, playerFormat);
		//ValidateMapFormat(0, mapFormat);
		copy(g_CurrMatch[MATCH_PLAYER_FORMAT], charsmax(g_CurrMatch[MATCH_PLAYER_FORMAT]), playerFormat);
		copy(g_CurrMatch[MATCH_MAP_FORMAT], charsmax(g_CurrMatch[MATCH_MAP_FORMAT]), mapFormat);
		copy(g_CurrMatch[MATCH_STEAM1], charsmax(g_CurrMatch[MATCH_STEAM1]), id1);
		copy(g_CurrMatch[MATCH_STEAM2], charsmax(g_CurrMatch[MATCH_STEAM2]), id2);
		g_CurrMatch[MATCH_SCORE1] = str_to_num(score1);
		g_CurrMatch[MATCH_SCORE2] = str_to_num(score2);
	}
	fclose(file);
	server_print("[%s] Cup loaded.", PLUGIN_TAG);
}

GetLastCupMapAvailable(map[], len)
{
	new TrieIter:ti = TrieIterCreate(g_MatchMapPool), bool:isMapFound;
	while (!TrieIterEnded(ti))
	{
		//new mapState;
		//TrieIterGetCell(ti, mapState);
		new cupMap[CUP_MAP];
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		if (cupMap[MAP_STATE_] == MAP_IDLE)
		{
			if (!isMapFound)
			{
				formatex(map, len, "%s", cupMap[MAP_NAME]);
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
	new Array:orderedMaps = GetOrderedMapPool();

	for (new i = 0; i < ArraySize(orderedMaps); i++)
	{
		new cupMap[CUP_MAP];
		ArrayGetArray(orderedMaps, i, cupMap, sizeof(cupMap));

		if (cupMap[MAP_STATE_] == MAP_PICKED || cupMap[MAP_STATE_] == MAP_DECIDER)
		{
			formatex(map, len, "%s", cupMap[MAP_NAME]);
			return;
		}
	}
	server_print("[%s] Error: trying to get the next map to play, but there's no map remaining to be played.", PLUGIN_TAG);
}

// state is a reserved word
CountCupMaps(MAP_STATE:state_)
{
	new result = 0;

	new cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti))
	{
		//new mapState;
		//TrieIterGetCell(ti, mapState);
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		//if (mapState == state_)
		if (cupMap[MAP_STATE_] == state_)
			result++;

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

// TODO: Cache the result when starting the map or when the map pool file is read
bool:IsCupMap()
{
	// Check if the current map is one of the maps to be played
	new /*map[32], mapState,*/ cupMap[CUP_MAP], bool:result;
	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti))
	{
		//TrieIterGetKey(ti, map, charsmax(map));
		//TrieIterGetCell(ti, mapState);
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		if ((cupMap[MAP_STATE_] == MAP_PICKED || cupMap[MAP_STATE_] == MAP_DECIDER) && equali(g_Map, cupMap[MAP_NAME]))
		{
			result = true;
			break;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

bool:IsCupPlayer(id)
{
	return id == g_CurrMatch[MATCH_PLAYER1] || id == g_CurrMatch[MATCH_PLAYER2];
}

bool:IsCupOngoing()
{
	new totalMaps = TrieGetSize(g_MatchMapPool);
	if (0 == totalMaps)
		return false;

	if (CountCupMaps(MAP_IDLE) == totalMaps)
		return false;

	if (CountCupMaps(MAP_PLAYED) == totalMaps)
		return false;

	return true;
}

SetCupMapWinner(id)
{
	if (id == g_CurrMatch[MATCH_PLAYER1])
		g_CurrMatch[MATCH_SCORE1]++;
	else if (id == g_CurrMatch[MATCH_PLAYER2])
		g_CurrMatch[MATCH_SCORE2]++;

	new cupMap[CUP_MAP];
	TrieGetArray(g_MatchMapPool, g_Map, cupMap, sizeof(cupMap));

	// Update map state
	cupMap[MAP_STATE_] = MAP_PLAYED;
	TrieSetArray(g_MatchMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap));

	// Save the changes to file, because we're gonna change the map in a while
	// and this info has to be taken again from the file right after changing
	WriteMapPoolFile(0);
	WriteMatchFile(0);
	CmdMapsShowHandler(0); // TODO: maybe this should show who won each map instead of just [PLAYED]

	// Commented out because this shouldn't happen, and if it does it has to be fixed in a better way
	//if (!topType)
	//	topType = PURE;

	new playerName[32];
	GetColorlessName(id, playerName, charsmax(playerName));
	client_print(0, print_chat, "[%s] Player %s has won in this map! Congrats!", PLUGIN_TAG, playerName);

	new name1[32], name2[32];
	GetColorlessName(g_CurrMatch[MATCH_PLAYER1], name1, charsmax(name1));
	GetColorlessName(g_CurrMatch[MATCH_PLAYER2], name2, charsmax(name2));
	client_print(0, print_chat, "[%s] Score: %s %d - %d %s", PLUGIN_TAG, name1, g_CurrMatch[MATCH_SCORE1], g_CurrMatch[MATCH_SCORE2], name2);

	new diffScore = abs(g_CurrMatch[MATCH_SCORE1] - g_CurrMatch[MATCH_SCORE2]);
	// At this point this very map has already been marked as PLAYED, so won't be counted as remaining
	new remainingMapsCount = CountCupMaps(MAP_PICKED) + CountCupMaps(MAP_DECIDER);
	new bool:hasWonMatch = diffScore > remainingMapsCount;

	if (hasWonMatch)
	{
		// The match winner must be the one who won this map,
		// unless you can somehow score negative if that makes sense (?)
		client_print(0, print_chat, "[%s] %s has won overall the match, no more maps to be played. Congrats!", PLUGIN_TAG, playerName);

		ClearCup(0);
	}
	else
	{
		new map[MAX_MAPNAME_LENGTH];
		GetNextCupMapToPlay(map, charsmax(map));

		new Float:timeToChange = get_pcvar_float(pcvar_kz_cup_map_change_delay);
		client_print(0, print_chat, "[%s] The next map to be played is %s. Changing the map in %.1f seconds...", PLUGIN_TAG, map, timeToChange);

		set_task(timeToChange, "CupChangeMap", TASKID_CUP_CHANGE_MAP, map, charsmax(map));
	}
}

public InsertMapIntoPool(id)
{
	// Insert up to 5 maps at a time
	new maps[MAX_MAP_INSERTIONS_AT_ONCE][32];
	for (new i = 0; i < sizeof(maps); i++) {
		read_argv(i+1, maps[i], charsmax(maps[]));

		if (maps[i][0])
		{
			new cupMap[CUP_MAP];
			TrieGetArray(g_MatchMapPool, maps[i], cupMap, sizeof(cupMap));
			// TODO: check that the map exists

			copy(cupMap[MAP_NAME], charsmax(cupMap[MAP_NAME]), maps[i]);
			TrieSetArray(g_MatchMapPool, maps[i], cupMap, sizeof(cupMap));
		}
	}

	if (read_argc() > MAX_MAP_INSERTIONS_AT_ONCE + 1)
		console_print(id, "[%s] Added %d maps, can't add more per command.", PLUGIN_TAG, MAX_MAP_INSERTIONS_AT_ONCE);

	WriteMapPoolFile(id);

	ShowMapPoolMenu(id);
}

RemoveMapFromPool(id, mapName[])
{
	trim(mapName);

	if (mapName[0] && !TrieDeleteKey(g_MatchMapPool, mapName)) {
		client_print(id, print_chat, "[%s] Couldn't remove %s from the map pool. Was it in the pool?", PLUGIN_TAG, mapName);
	}

	ShowMapsMenu(id, MP_ACTION_REMOVE);
}

public CupForceSpectators(taskId)
{
	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		if (IsCupPlayer(id))
			continue;

		if (!pev(id, pev_iuser1)) // not spectator? force them )))
			server_cmd("agforcespectator #%d", get_user_userid(id));
	}
	server_exec();

	return PLUGIN_HANDLED;
}

public CupStartMatch(taskId)
{
	CupForceSpectators(TASKID_CUP_FORCE_SPECTATORS + 3);

	new bool:areParticipantsSpectating;
	if (pev(g_CurrMatch[MATCH_PLAYER1], pev_iuser1))
	{
		areParticipantsSpectating = true;
		new playerName[32];
		GetColorlessName(g_CurrMatch[MATCH_PLAYER1], playerName, charsmax(playerName));
		client_print(0, print_chat, "[%s] Cannot start the match because the participant %s is spectating!", PLUGIN_TAG, playerName);
	}
	// FIXME: DRY, but the message should appear per each participant that is spectating,
	// or maybe doesn't really matter and can be dumbed down
	if (pev(g_CurrMatch[MATCH_PLAYER2], pev_iuser1))
	{
		areParticipantsSpectating = true;
		new playerName[32];
		GetColorlessName(g_CurrMatch[MATCH_PLAYER2], playerName, charsmax(playerName));
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

//bool:ProcessPlayerFormat(id, cupFormat[])
//{
//	new i;
//	while (cupFormat[i])
//	{
//		// TODO: refactor to make it simpler, no conditions
//		if (equali(cupFormat[i], "A", 1))
//			g_CurrMatch[MATCH_PLAYER_FORMAT][i] = PF_PLAYER1;
//		else if (equali(cupFormat[i], "B", 1))
//			g_CurrMatch[MATCH_PLAYER_FORMAT][i] = PF_PLAYER2;
//		else if (equali(cupFormat[i], "D", 1))
//			g_CurrMatch[MATCH_PLAYER_FORMAT][i] = PF_DECIDER;
//		else
//		{
//			g_CurrMatch[MATCH_PLAYER_FORMAT][i] = PF_UNKNOWN;

//			//new format[MAX_MATCH_MAPS + 1];
//			//get_pcvar_string(pcvar_kz_cup_format, format, charsmax(format));

//			//console_print(id, "[%s] The provided format is wrong! You can set it with kz_cup_format <format>", PLUGIN_TAG);
//			//console_print(id, "[%s] Example: \"kz_cup_format ABBAABD\". The default one is %s", PLUGIN_TAG, format);
//			//console_print(id, "[%s] A is first opponent's pick/ban, B is second opponent's pick/ban, and D is the decider map", PLUGIN_TAG);

//			console_print(id, "[%s] The provided player format is wrong!", PLUGIN_TAG);

//			return false;
//		}
//		i++;
//	}

//	return true;
//}

bool:ValidatePlayerFormat(id, matchFormat[])
{
	new i;
	while (matchFormat[i]) // exit on null terminator
	{
		if (matchFormat[i] == PF_DECIDER)
		{
			if (matchFormat[i+1] != EOS)  // assume we don't go OOB because it's null terminated
			{
				client_print(id, print_chat, "[%s] Bad player format! You can only put the decider/autopick at the end of the format", PLUGIN_TAG);
				return false;
			}
		}
		else if (!(matchFormat[i] == PF_PLAYER1 || matchFormat[i] == PF_PLAYER2))
		{
			client_print(id, print_chat, "[%s] Bad player format! Unrecognized format starting from '%s'", PLUGIN_TAG, matchFormat[i]);
			return false;
		}
		i++;
	}

	new mapsCount = TrieGetSize(g_MatchMapPool);
	if (i != mapsCount)
	{
		if (mapsCount - 1 == i && i < MAX_MATCH_MAPS)
		{
			matchFormat[i+1] = PF_DECIDER;
			return true;
		}
		else
		{
			client_print(id, print_chat, "[%s] Bad player format! You provided a format for %d maps when there's %d in the pool", PLUGIN_TAG, i, mapsCount);
			return false;
		}
	}
	return true;
}

// TODO: maybe converge similar functions ValidatePlayerFormat and ValidateMapFormat
bool:ValidateMapFormat(id, matchFormat[])
{
	new i;
	while (matchFormat[i]) // exit on null terminator
	{
		if (matchFormat[i] == MF_DECIDER)
		{
			if (matchFormat[i+1] != EOS)  // assume we don't go OOB because it's null terminated
			{
				client_print(id, print_chat, "[%s] Bad map format! You can only put the decider/autopick at the end of the format", PLUGIN_TAG);
				return false;
			}
		}
		else if (!(matchFormat[i] == MF_BAN || matchFormat[i] == MF_PICK))
		{
			client_print(id, print_chat, "[%s] Bad map format! Unrecognized format starting from '%s'", PLUGIN_TAG, matchFormat[i]);
			return false;
		}
		i++;
	}

	new mapsCount = TrieGetSize(g_MatchMapPool);
	if (i != mapsCount)
	{
		if (mapsCount - 1 == i && i < MAX_MATCH_MAPS)
		{
			matchFormat[i+1] = MF_DECIDER;
			return true;
		}
		else
		{
			client_print(id, print_chat, "[%s] Bad map format! You provided a format for %d maps when there's %d in the pool", PLUGIN_TAG, i, mapsCount);
			return false;
		}
	}
	return true;
}

Array:GetCupMapsWithState(MAP_STATE:stateNumber)
{
	new Array:result = ArrayCreate(32, 7);

	new cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		if (cupMap[MAP_STATE_] == stateNumber)
			ArrayPushString(result, cupMap[MAP_NAME]);

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

ClearCup(id)
{
	g_CurrMatch[MATCH_BEST_OF] = 0;
	g_CurrMatch[MATCH_PLAYER1] = 0;
	g_CurrMatch[MATCH_PLAYER2] = 0;
	g_CurrMatch[MATCH_STEAM1][0] = EOS;
	g_CurrMatch[MATCH_STEAM2][0] = EOS;
	g_CurrMatch[MATCH_SCORE1] = 0;
	g_CurrMatch[MATCH_SCORE2] = 0;
	g_CurrMatch[MATCH_READY1] = false;
	g_CurrMatch[MATCH_READY2] = false;
	ResetCupMapStates(id);

	new msg[96];
	formatex(msg, charsmax(msg), "[%s] Players, scores and readiness states have been cleared.", PLUGIN_TAG);
	if (id)
	{
		client_print(id, print_chat, msg);
		console_print(id, msg);
	}
	else
		server_print(msg);

	WriteMapPoolFile(id);
	WriteMatchFile(id);
}

// Writes to a file the map pool in its current state
WriteMapPoolFile(id)
{
	new file = fopen(g_MapPoolFile, "wt");
	if (!file)
	{
		ShowMessageHLKZ(id, "Failed to write map pool file");
		return;
	}

	console_print(id, "Current maps:");
	new cupMap[CUP_MAP], TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti)) {
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		if (g_MapStateString[_:cupMap[MAP_STATE_]][0])
			console_print(id, " - %s -> #%d, %s, player %d", cupMap[MAP_NAME], cupMap[MAP_ORDER], g_MapStateString[_:cupMap[MAP_STATE_]], cupMap[MAP_PICKER]);
		else
			console_print(id, " - %s", cupMap[MAP_NAME]);

		fprintf(file, "%d %s %d %d\n", cupMap[MAP_ORDER], cupMap[MAP_NAME], cupMap[MAP_STATE_], cupMap[MAP_PICKER]);
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);
	fclose(file);
}

// Writes to a file the cup match in its current state
WriteMatchFile(id)
{
	new file = fopen(g_CupFile, "wt");
	if (!file)
	{
		ShowMessageHLKZ(id, "Failed to write cup file");
		return;
	}

	if (g_CurrMatch[MATCH_BEST_OF] && g_CurrMatch[MATCH_STEAM1][0] && g_CurrMatch[MATCH_STEAM2][0]
	    && g_CurrMatch[MATCH_PLAYER_FORMAT][0] && g_CurrMatch[MATCH_MAP_FORMAT][0])
	{
		new len = fprintf(file, "%d %s %s %s %s %d %d\n",
		    g_CurrMatch[MATCH_BEST_OF],
		    g_CurrMatch[MATCH_PLAYER_FORMAT],
		    g_CurrMatch[MATCH_MAP_FORMAT],
		    g_CurrMatch[MATCH_STEAM1],
		    g_CurrMatch[MATCH_STEAM2],
		    g_CurrMatch[MATCH_SCORE1],
		    g_CurrMatch[MATCH_SCORE2]);

		server_print("[%s] Wrote %d characters to match file", PLUGIN_TAG, len);
	}
	fclose(file);

	g_IsMatchEditionDirty = false;
}

ResetCupMapStates(id)
{
	new i, cupMap[CUP_MAP];

	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti)) {
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		cupMap[MAP_ORDER]  = 0;
		cupMap[MAP_STATE_] = MAP_IDLE;
		cupMap[MAP_PICKER] = PF_UNKNOWN;

		if (TrieSetArray(g_MatchMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap)))
			i++;

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	new msg[96];
	formatex(msg, charsmax(msg), "[%s] All the %d maps have been reset to IDLE state.", PLUGIN_TAG, i);
	if (id)
	{
		client_print(id, print_chat, msg);
		console_print(id, msg);
	}
	else
		server_print(msg);
}

Array:GetOrderedMapPool()
{
	new Array:result = ArrayCreate(CUP_MAP, TrieGetSize(g_MatchMapPool));

	new clean[CUP_MAP];
	// Fill the map list with empty entries
	for (new i = 0; i < TrieGetSize(g_MatchMapPool); i++)
		ArrayPushArray(result, clean, sizeof(clean));

	new TrieIter:ti = TrieIterCreate(g_MatchMapPool);
	while (!TrieIterEnded(ti))
	{
		new cupMap[CUP_MAP];
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		ArraySetArray(result, cupMap[MAP_ORDER], cupMap, sizeof(cupMap));

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return result;
}

GetNextPicker()
{
	new totalPoolMaps = TrieGetSize(g_MatchMapPool);
	new availableMaps = CountCupMaps(MAP_IDLE);

	new i = totalPoolMaps - availableMaps;
	while (g_CurrMatch[MATCH_PLAYER_FORMAT][i])
	{
		new PLAYER_FORMAT:format = g_CurrMatch[MATCH_PLAYER_FORMAT][i];

		if (format == PF_PLAYER1)
		{
			return g_CurrMatch[MATCH_PLAYER1];
		}
		else if (format == PF_PLAYER2)
		{
			return g_CurrMatch[MATCH_PLAYER2];
		}
		else
		{
			server_print("GetNextPicker() :: char #%d is decider, probably shouldn't have reached this point", i);
		}

		i++;
	}

	return 0;
}

SaveRecordedCupRun(id)
{
	HLKZ_SaveRecordedRun(id, "cup");
}

// Validate cup stuff and start the cup by showing the map menu to the first player
StartCup(id)
{
	if (!ValidateMapFormat(id, g_CurrMatch[MATCH_MAP_FORMAT]) || !ValidatePlayerFormat(id, g_CurrMatch[MATCH_PLAYER_FORMAT]))
	{
		client_print(id, print_chat, "[%s] Cannot start the cup", PLUGIN_TAG);
		return;
	}

	server_print("[%s] Starting cup", PLUGIN_TAG);
	g_IsCupStarting = true;

	WriteMatchFile(id);

	ResetCupMapStates(id);

	new MAP_FORMAT:      mf      = g_CurrMatch[MATCH_MAP_FORMAT][0];
	new MAP_POOL_ACTION: action  = MapFormatToAction(mf);

	if (g_CurrMatch[MATCH_HAS_RANDOM_SEED])
	{
		new verb[6];
		if (action == MP_ACTION_BAN)
			copy(verb, charsmax(verb), "bans");
		else
			copy(verb, charsmax(verb), "picks");

		client_print(0, print_chat, "[%s] Flipping a coin to decide who %s first...", PLUGIN_TAG, verb);
		
		new data[1];
		data[0] = action;
		set_task(2.0, "CupTensionFirstBan", TASKID_CUP_TENSION_FIRST_BAN, data, sizeof(data));
	}
	else
	{
		new verb[8];
		if (action == MP_ACTION_BAN)
			copy(verb, charsmax(verb), "banning");
		else
			copy(verb, charsmax(verb), "picking");

		new playerName[32];
		GetColorlessName(g_CurrMatch[MATCH_PLAYER1], playerName, charsmax(playerName));

		client_print(0, print_chat, "[%s] %s will start %s now", PLUGIN_TAG, playerName, verb);

		ShowMapsMenu(g_CurrMatch[MATCH_PLAYER1], action);
	}
}

public CupTensionFirstBan(data[], taskId)
{
	new MAP_POOL_ACTION: action = data[0];

	if (action == MP_ACTION_BAN)
		client_print(0, print_chat, "[%s] ...can you guess who bans first?", PLUGIN_TAG);
	else
		client_print(0, print_chat, "[%s] ...can you guess who picks first?", PLUGIN_TAG);

	set_task(3.0, "CupFinallyFirstPickBan", TASKID_CUP_FINALLY_FIRST_BAN, data, 1);
}

public CupFinallyFirstPickBan(data[], taskId)
{
	new MAP_POOL_ACTION: action = data[0];

	new rand = random_num(0, 1);
	if (rand)
	{
		// Switch players
		new oldSteam1[MAX_AUTHID_LENGTH], oldSteam2[MAX_AUTHID_LENGTH];
		new oldPlayer1 = g_CurrMatch[MATCH_PLAYER1];
		new oldPlayer2 = g_CurrMatch[MATCH_PLAYER2];
		copy(oldSteam1, charsmax(oldSteam1), g_CurrMatch[MATCH_STEAM1]);
		copy(oldSteam2, charsmax(oldSteam2), g_CurrMatch[MATCH_STEAM2]);

		g_CurrMatch[MATCH_PLAYER1] = oldPlayer2;
		g_CurrMatch[MATCH_PLAYER2] = oldPlayer1;
		copy(g_CurrMatch[MATCH_STEAM1], charsmax(g_CurrMatch[]), oldSteam2);
		copy(g_CurrMatch[MATCH_STEAM2], charsmax(g_CurrMatch[]), oldSteam1);
	}
	WriteMatchFile(0);

	new playerName[32];
	GetColorlessName(g_CurrMatch[MATCH_PLAYER1], playerName, charsmax(playerName));

	client_print(0, print_chat, "[%s] Okay, %s goes first!", PLUGIN_TAG, playerName);

	ShowMapsMenu(g_CurrMatch[MATCH_PLAYER1], action);
}

bool:ProcessMatchChoice(id, MAP_POOL_ACTION:action, mapName[MAX_MAPNAME_LENGTH])
{
	// FIXME: pass the map name through itemInfo in the menu and send it here,
	// instead of processing the text to get the first part, as the item name
	// may have things like [PICKED] at the end. It could also go OOB
	new left[64];
	new right[256];
	strtok2(mapName, left, charsmax(left), right, charsmax(right), _, .trim = 1);

	new chosenMap[CUP_MAP];
	if (TrieGetArray(g_MatchMapPool, left, chosenMap, sizeof(chosenMap)))
	{
		if (chosenMap[MAP_STATE_] != MAP_IDLE)
		{
			client_print(id, print_chat, "[%s] Please, pick a map that's not already banned/picked.", PLUGIN_TAG);
			ShowMapsMenu(id, action);
			return false;
		}
	}
	else
	{
		log_to_file(HLKZ_LOG_FILENAME, "Cannot find map in the pool: %s. It was somehow in the pick/ban menu", mapName);
		client_print(id, print_chat, "[%s] Something went wrong with the map choice, please try again and/or ask an admin.", PLUGIN_TAG);
		ShowMapsMenu(id, action);
		return false;
	}
	formatex(mapName, charsmax(mapName), "%s", left);

	new totalPoolMaps = TrieGetSize(g_MatchMapPool);
	new availableMaps = CountCupMaps(MAP_IDLE);
	new choiceIndex   = totalPoolMaps - availableMaps;

	// Update map state
	chosenMap[MAP_ORDER]  = choiceIndex;
	chosenMap[MAP_STATE_] = MapActionToState(action);
	chosenMap[MAP_PICKER] = g_CurrMatch[MATCH_PLAYER_FORMAT][choiceIndex];
	TrieSetArray(g_MatchMapPool, chosenMap[MAP_NAME], chosenMap, sizeof(chosenMap));
	availableMaps--;

	new nextChoiceIndex = totalPoolMaps - availableMaps;
	
	// Check who votes next, if it's a pick, ban or already the decider
	if (availableMaps > 1) // last one is decider, it has a dedicated chat message
	{
		new playerName[32], currChoiceVerb[7], nextPlayerName[32], nextChoiceVerb[6];
		GetColorlessName(id, playerName, charsmax(playerName));
		MapActionToVerbPast(action, currChoiceVerb, charsmax(currChoiceVerb));

		new PLAYER_FORMAT:   nextPf      = g_CurrMatch[MATCH_PLAYER_FORMAT][nextChoiceIndex];
		new MAP_FORMAT:      nextMf      = g_CurrMatch[MATCH_MAP_FORMAT][nextChoiceIndex];
		new MAP_POOL_ACTION: nextAction  = MapFormatToAction(nextMf);

		new nextChooser = GetPlayerFromFormat(nextPf);
		GetColorlessName(nextChooser, nextPlayerName, charsmax(nextPlayerName));
		MapActionToVerbPresent(nextAction, nextChoiceVerb, charsmax(nextChoiceVerb));

		client_print(0, print_chat, "[%s] %s %s %s. Remaining %d maps. %s %s next.",
			PLUGIN_TAG, playerName, currChoiceVerb, chosenMap[MAP_NAME], availableMaps, nextPlayerName, nextChoiceVerb);

		ShowMapsMenu(nextChooser, nextAction);

		CmdMapsShowHandler(0);
	}
	else if (availableMaps == 1)
	{
		new lastMap[MAX_MAPNAME_LENGTH];
		GetLastCupMapAvailable(lastMap, charsmax(lastMap));
		TrieGetArray(g_MatchMapPool, lastMap, chosenMap, sizeof(chosenMap));

		// The decider is the last map that's left, no more menus, this is chosen automatically
		chosenMap[MAP_ORDER]  = nextChoiceIndex;
		chosenMap[MAP_STATE_] = MAP_DECIDER;
		chosenMap[MAP_PICKER] = g_CurrMatch[MATCH_PLAYER_FORMAT][nextChoiceIndex];
		TrieSetArray(g_MatchMapPool, chosenMap[MAP_NAME], chosenMap, sizeof(chosenMap));

		client_print(0, print_chat, "[%s] %s will be the decider.", PLUGIN_TAG, chosenMap[MAP_NAME]);

		// Map states during bans/picks only get saved here
		// If the server crashes or there's a map change in the middle of the
		// bans/picks, then all that info will be lost and kz_cup should be issued again
		WriteMapPoolFile(0);

		// Now we're gonna change (or not) the map to start playing
		new nextMap[MAX_MAPNAME_LENGTH];
		GetNextCupMapToPlay(nextMap, charsmax(nextMap));

		if (equal(nextMap, g_Map))
		{
			// We're gonna play in this very map, so no changelevel needed
			client_print(0, print_chat, "[%s] The next map to be played is %s.", PLUGIN_TAG, nextMap);
			client_print(0, print_chat, "[%s] We're already in that map, so just waiting for participants to get /ready to start ;)", PLUGIN_TAG);
		}
		else
		{
			new Float:timeToChange = get_pcvar_float(pcvar_kz_cup_map_change_delay);
			client_print(0, print_chat, "[%s] The next map to be played is %s. Changing the map in %.0f seconds...", PLUGIN_TAG, nextMap, timeToChange);

			set_task(timeToChange, "CupChangeMap", TASKID_CUP_CHANGE_MAP, nextMap, charsmax(chosenMap[MAP_NAME]));
		}
		CmdMapsShowHandler(0);
		return true;
	}
	else
		log_to_file(HLKZ_LOG_FILENAME, "Unexpected number of available maps (%d) when processing a choice", availableMaps);

	return false;
}

MAP_STATE:MapActionToState(MAP_POOL_ACTION:action)
{
	switch (action)
	{
		case MP_ACTION_BAN:  return MAP_BANNED;
		case MP_ACTION_PICK: return MAP_PICKED;
		default: {
			log_to_file(HLKZ_LOG_FILENAME, "Unexpected map action to state value (action: %d)", action);
			return MAP_IDLE;
		}
	}
	return MAP_IDLE;
}

MapActionToVerbPresent(MAP_POOL_ACTION:action, verb[], len)
{
	switch (action)
	{
		case MP_ACTION_BAN:  copy(verb, len, "bans");
		case MP_ACTION_PICK: copy(verb, len, "picks");
		default: {
			log_to_file(HLKZ_LOG_FILENAME, "Unexpected map action to verb value (action: %d)", action);
			return;
		}
	}
}

// TODO: refactor
MapActionToVerbPast(MAP_POOL_ACTION:action, verb[], len)
{
	switch (action)
	{
		case MP_ACTION_BAN:  copy(verb, len, "banned");
		case MP_ACTION_PICK: copy(verb, len, "picked");
		default: {
			log_to_file(HLKZ_LOG_FILENAME, "Unexpected map action to verb value (action: %d)", action);
			return;
		}
	}
}

MAP_POOL_ACTION:MapFormatToAction(MAP_FORMAT:choice)
{
	switch (choice)
	{
		case MF_BAN:  return MP_ACTION_BAN;
		case MF_PICK: return MP_ACTION_PICK;
		default: {
			log_to_file(HLKZ_LOG_FILENAME, "Unexpected map format to action value (map choice: %d)", choice);
			return MP_ACTION_VIEW;
		}
	}
	return MP_ACTION_VIEW;
}

GetPlayerFromFormat(PLAYER_FORMAT:playerFormat)
{
	switch (playerFormat)
	{
		case PF_PLAYER1: return g_CurrMatch[MATCH_PLAYER1];
		case PF_PLAYER2: return g_CurrMatch[MATCH_PLAYER2];
		default: {
			log_to_file(HLKZ_LOG_FILENAME, "Unexpected player format to player id (format: %d)", playerFormat);
			return 0;
		}
	}
	return 0;
}
