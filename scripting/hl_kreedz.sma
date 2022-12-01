/* AMX Mod X
*	HL KreedZ
*
* http://aghl.ru/forum/ - Russian Half-Life and Adrenaline Gamer Community
*
* This file is provided as is (no warranties)
*
* Credit to Quaker for the snippet of setting light style (nightvision) https://github.com/skyrim/qmxx/blob/master/scripting/q_nightvision.sma
*/

// HACK: remove_filepath() from string_stocks checks for '\' which we use as ctrlchar,
// so we place the include before setting our ctrlchar to avoid it being used inside that include
#include <string_stocks>

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
#include <amx_settings_api>
#include <mysqlt>
#include <regex>

// Compilation options
//#define _DEBUG    // Enable debug output at server console.

#define MAX_PLAYERS         32
#define MAX_ENTITIES        2048  // not really 2048, the max is num_edicts i think, and it can go up to 8192?
#define PLAYER_USE_RADIUS   64.0

#define OBS_NONE            0
#define OBS_CHASE_LOCKED    1
#define OBS_CHASE_FREE      2
#define OBS_ROAMING         3
#define OBS_IN_EYE          4
#define OBS_MAP_FREE        5
#define OBS_MAP_CHASE       6

#define get_bit(%1,%2) (%1 & (1 << (%2 - 1)))
#define set_bit(%1,%2) (%1 |= (1 << (%2 - 1)))
#define clr_bit(%1,%2) (%1 &= ~(1 << (%2 - 1)))

#define IsPlayer(%1) (1 <= %1 <= g_MaxPlayers)
#define IsConnected(%1) (get_bit(g_bit_is_connected,%1))
#define IsAlive(%1) (get_bit(g_bit_is_alive,%1))
#define IsHltv(%1) (get_bit(g_bit_is_hltv,%1))
#define IsBot(%1) (get_bit(g_bit_is_bot,%1))

#define FL_ONGROUND_ALL (FL_ONGROUND | FL_PARTIALGROUND | FL_INWATER | FL_CONVEYOR | FL_FLOAT)

#define MAX_RACE_ID                     65535
#define MAX_FPS_MULTIPLIER              4    // for replaying demos at a max. fps of 250*MAX_FPS_MULTIPLIER
#define MIN_COUNTDOWN                   1.0
#define AG_COUNTDOWN                    10.0 // TODO: account for sv_ag_countdown in AG 6.7
#define MAX_COUNTDOWN                   30.0
#define MATCH_START_CHECK_SECOND        2
#define HUD_UPDATE_TIME                 0.05
#define MIN_TIMELEFT_ALLOWED_NORESET    5.0
#define HUD_SPLIT_HOLDTIME              2.0
#define HUD_LAP_HOLDTIME                2.5
#define HUD_DEFAULT_SPLIT_Y             0.18
//#define HUD_DEFAULT_LAP_Y               0.26
#define HUD_DEFAULT_LAP_Y               0.21
#define HUD_DEFAULT_DELTA_Y             0.28
#define HUD_DELTA_SPLIT_OFFSET          0.03
#define DEFAULT_TIME_DECIMALS           3
#define RUN_STATS_MIN_FPS_AVG_FRAMES    30
#define RUN_STATS_SPEED_FRAME_OFFSET    30   // e.g.: take the speed from the last N-th frame
#define RUN_STATS_SPEED_FRAME_COOLDOWN  200  // we are not gonna check again for a slowdown for the next N frames
#define RUN_STATS_HUD_HOLD_TIME_AT_END  5.0
#define RUN_STATS_HUD_MAX_HOLD_TIME     30.0
#define RUN_STATS_HUD_MIN_HOLD_TIME     0.5
#define RUN_STATS_HUD_X                 0.75
#define RUN_STATS_HUD_Y                 -1.0  // centered
#define START_ZONE_ALLOWED_PRESPEED     540.0
#define START_BUTTON_ALLOWED_PRESPEED   50.0
#define MAX_MAP_INSERTIONS_AT_ONCE      7
#define DEFAULT_HLKZ_NOCLIP_SPEED       800.0

// https://github.com/ValveSoftware/halflife/blob/c7240b965743a53a29491dd49320c88eecf6257b/dlls/triggers.cpp#L1013
#define TRIGGER_HURT_DAMAGE_TIME        0.5

#define CHEAT_HOOK                      1
#define CHEAT_ROPE                      2
#define CHEAT_TAS                       3
#define CHEAT_NOCLIP                    4

#define TASKID_ICON                     5633445
#define TASKID_WELCOME                  43321
#define TASKID_POST_WELCOME             5332178
#define TASKID_KICK_REPLAYBOT           9572626
#define TASKID_CAM_UNFREEZE             1622952
#define TASKID_CONFIGURE_DB             2037262
#define TASKID_MATCH_START_CHECK        2906871
#define TASKID_INIT_PLAYER_GOLDS        468261
#define TASKID_RELOAD_PLAYER_SETTINGS   1975201

#define TASKID_CUP_TENSION_FIRST_BAN    9357015
#define TASKID_CUP_FINALLY_FIRST_BAN    8357015
#define TASKID_CUP_FORCE_SPECTATORS     7357015
#define TASKID_CUP_START_MATCH          6357015
#define TASKID_CUP_CHANGE_MAP           5357015

#define TE_EXPLOSION                    3

enum _:REPLAY
{
  //RP_VERSION,
	Float:RP_TIME,
	Float:RP_ORIGIN[3],
	Float:RP_ANGLES[3],
	RP_BUTTONS,
	Float:RP_SPEED    // horizontal speed
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
	bool:CP_VALID,          // is checkpoint valid
	CP_FLAGS,               // pev flags
	Float:CP_ORIGIN[3],     // position
	Float:CP_ANGLES[3],     // view angles
	Float:CP_VIEWOFS[3],    // view offset
	Float:CP_VELOCITY[3],   // velocity
	Float:CP_HEALTH,        // health
	Float:CP_ARMOR,         // armor
	bool:CP_LONGJUMP,       // longjump
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
	BUTTON_NOT,
	BUTTON_START,
	BUTTON_FINISH,
	BUTTON_SPLIT
}

enum _:WEAPON
{
	WEAPON_CLASSNAME[32],
	Float:WEAPON_ORIGIN[3]
}

enum _:SPLIT {
	SPLIT_DB_ID,          // unique identifier in database
	SPLIT_ID[17],         // unique identifier, e.g.: "sector1"
	SPLIT_ENTITY,         // entity id of the corresponding trigger_multiple (if any - so 0 means no corresponding entity)
	SPLIT_NAME[32],       // the name that will appear in the HUD for this split
	SPLIT_NEXT[17],       // id of the next split
	bool:SPLIT_LAP_START  // tells if this split is the start/end of a lap or run
/*
	// These are for splits defined in a file or ingame, not compiled in the map itself
	Float:SPLIT_START_POINT[3],	// assuming a prism or rectangle, vertex with the lowest X, Y and Z, diagonally opposite to the end point
	Float:SPLIT_END_POINT[3]	// assuming a prism or rectangle, vertex with the highest X, Y and Z, diagonally opposite to the start point
*/
}

enum RECORD_STORAGE_TYPE
{
	STORE_IN_FILE,
	STORE_IN_DB,
	STORE_IN_FILE_AND_DB
}

enum _:CUP_REPLAY_ITEM
{
	CUP_REPLAY_ITEM_FILENAME[128],
	CUP_REPLAY_ITEM_ID[32],
	CUP_REPLAY_ITEM_TOP[32],
	CUP_REPLAY_ITEM_DATE[64],
	CUP_REPLAY_ITEM_TIMESTAMP
}


new const PLUGIN[] = "HL KreedZ Beta";
new const PLUGIN_TAG[] = "HLKZ";
new const VERSION[] = "0.48";
//new const DEMO_VERSION = 36; // Should not be decreased. This is for replays, to know which version they're in, in case the replay format changes
new const AUTHOR[] = "KORD_12.7, Lev, YaLTeR, execut4ble, naz, mxpph";

new const MAIN_MENU_ID[] = "HL KreedZ Menu";
new const TELE_MENU_ID[] = "HL KreedZ Teleport Menu";
new const MAP_BAN_MENU_ID[] = "Ban a map";
new const MAP_PICK_MENU_ID[] = "Pick a map";

new const CONFIGS_SUB_DIR[] = "hl_kreedz";
new const PLUGIN_CFG_FILENAME[] = "hl_kreedz";
new const PLUGIN_CFG_SHORTENED[] = "hlkz";
new const REPLAYS_DIR_NAME[] = "replays";
new const MYSQL_LOG_FILENAME[] = "kz_mysql.log";
new const HLKZ_LOG_FILENAME[] = "hl_kreedz.log";
new const MAP_POOL_FILE[] = "map_pool.ini";
new const CUP_FILE[] = "cup.ini";
new const HUD_SETTINGS[] = "HUD Settings";
new const GAMEPLAY_SETTINGS[] = "Gameplay Settings";

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

new const g_RunModeString[][] =
{
	"",
	"AGStart",
	"Race",
	"NR"
}

new const g_ShowRunStatsOnHudString[][] =
{
	"OFF",
	"ON - Only at run end",
	"ON - Permanently"
}

new const g_RunStatsDetailLevelString[][] =
{
	"Low",
	"High",
	"Full"
}

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
	"weapon_hornetgun",    // no boost, but it could be used to block a moving entity (door, lift, etc.)
	"weapon_rpg",
	"weapon_satchel",
	"weapon_snark",
	"weapon_tripmine"
};

// Entities thay may be still alive without the owner being online
// and affect another player in a way they can take advantage for a run
new const g_DamageBoostEntities[][] = {
	"bolt",                 // DMG_BLAST
	"grenade",              // DMG_BLAST
	"hornet",               // DMG_BULLET
	"monster_satchel",      // DMG_BLAST
	"monster_snark",        // DMG_SLASH
	"monster_tripmine",     // DMG_BLAST
	"rpg_rocket"            // DMG_BLAST
};

// Sounds used for No-Reset run countdown
new const g_CountdownSounds[][] = {
	"barney/ba_bring",
	"fvox/one",
	"fvox/two",
	"fvox/three",
	"fvox/four",
	"fvox/five",
	"fvox/six",
	"fvox/seven",
	"fvox/eight",
	"fvox/nine"
};

new g_bit_is_connected, g_bit_is_alive, g_bit_invis, g_bit_waterinvis;
new g_bit_is_hltv, g_bit_is_bot;
new g_baIsClimbing, g_baIsPaused, g_baIsFirstSpawn, g_baIsPureRunning;
new g_baIsAgFrozen;    // only used when we're running on an AG server, because it unfreezes on player PreThink()

new g_RunStartTimestamp[MAX_PLAYERS + 1];
new Float:g_PlayerTime[MAX_PLAYERS + 1];
new Float:g_PlayerTimePause[MAX_PLAYERS + 1];
new g_SolidState[MAX_PLAYERS + 1];
new g_LastButtons[MAX_PLAYERS + 1];  // only for HUD; for any other usage, use g_Buttons instead
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
new Float:g_PlayerTASed[MAX_PLAYERS + 1];

new g_UniqueId[MAX_PLAYERS + 1][32];
new Trie:g_DbPlayerId;
new Array:g_GoldSplits[MAX_PLAYERS + 1][RUN_TYPE];    // Best individual split times
new Array:g_GoldLaps[MAX_PLAYERS + 1][RUN_TYPE];      // Best individual lap times
new Array:g_PbSplits[MAX_PLAYERS + 1][RUN_TYPE];      // Split times of PB run
new Array:g_PbLaps[MAX_PLAYERS + 1][RUN_TYPE];        // Lap times of PB run
new bool:g_PbSplitsUpToDate[MAX_PLAYERS + 1];         // To decide whether to retrieve split/lap times again
new bool:g_IsUsingSplits[MAX_PLAYERS + 1];

new bool:g_IsInNoclip[MAX_PLAYERS + 1];
new Float:g_NoclipTargetSpeed[MAX_PLAYERS + 1];  // max speed to reach when noclipping


// Splits stuff
new Trie:g_Splits;                       // split id -> SPLIT struct
new Array:g_SplitTimes[MAX_PLAYERS + 1]; // split # -> time, in the current lap
new Array:g_LapTimes[MAX_PLAYERS + 1];   // lap # -> time
new Array:g_OrderedSplits;               // split # -> split id
new g_CurrentLap[MAX_PLAYERS + 1];       // 1-indexed, 0 means player's not running or the map doesn't allow laps
new g_RunLaps;                           // how many laps players have to do to complete a run

// These are for No-Reset runs, races and matches (agstart)
new g_RaceId[MAX_PLAYERS + 1];
new RUN_MODE:g_RunMode[MAX_PLAYERS + 1];
new RUN_MODE:g_RunModeStarting[MAX_PLAYERS + 1];
new Float:g_RunStartTime[MAX_PLAYERS + 1];
new Float:g_RunNextCountdown[MAX_PLAYERS + 1];
new Float:g_RunCountdown[MAX_PLAYERS + 1];
new bool:g_IsBannedFromMatch[MAX_PLAYERS + 1];

new bool:g_IsValidStart[MAX_PLAYERS + 1];

// Player preferences/settings
new g_ShowTimer[MAX_PLAYERS + 1];
new g_ShowKeys[MAX_PLAYERS + 1];
new g_ShowStartMsg[MAX_PLAYERS + 1];
new g_TimeDecimals[MAX_PLAYERS + 1];
new g_Nightvision[MAX_PLAYERS + 1];
new bool:g_Slopefix[MAX_PLAYERS + 1];
new Float:g_Speedcap[MAX_PLAYERS + 1]; // Float indicating your actual cap
new g_Prespeedcap[MAX_PLAYERS + 1]; // 0 = OFF, 1 = cap applied at the start line only, 2 = cap applied everytime when not in a run
new bool:g_ShowSpeed[MAX_PLAYERS + 1];
new bool:g_ShowDistance[MAX_PLAYERS + 1];
new bool:g_ShowHeightDiff[MAX_PLAYERS + 1];
new bool:g_ShowSpecList[MAX_PLAYERS + 1];
new bool:g_TpOnCountdown[MAX_PLAYERS + 1];    // Teleport to start position when agstart or NR countdown starts?
new bool:g_ShowRunStatsOnConsole[MAX_PLAYERS + 1];
new g_ShowRunStatsOnHud[MAX_PLAYERS + 1];  // 0 = off, 1 = at the end of the run, 2 = permanent
new Float:g_RunStatsHudHoldTime[MAX_PLAYERS + 1];
new Float:g_RunStatsHudX[MAX_PLAYERS + 1];
new Float:g_RunStatsHudY[MAX_PLAYERS + 1];
new g_RunStatsConsoleDetailLevel[MAX_PLAYERS + 1];
new g_RunStatsHudDetailLevel[MAX_PLAYERS + 1];

new Float:g_PrevRunCountdown[MAX_PLAYERS + 1];
new g_PrevShowTimer[MAX_PLAYERS + 1];
new g_PrevTimeDecimals[MAX_PLAYERS + 1];
new g_PrevHudRGB[MAX_PLAYERS + 1][3];
new Float:g_RunStatsEndHudStartTime[MAX_PLAYERS + 1];
new bool:g_RunStatsEndHudShown[MAX_PLAYERS + 1];

new g_BotOwner[MAX_PLAYERS + 1];
new g_BotEntity[MAX_PLAYERS + 1];
new g_RecordRun[MAX_PLAYERS + 1];
// Each player has all the frames of their run stored here, the frames are arrays containing the info formatted like the REPLAY enum
new Array:g_RunFrames[MAX_PLAYERS + 1]; // frames of the current run, being stored here while the run is going on
new Array:g_ReplayFrames[MAX_PLAYERS + 1]; // frames to be replayed
new g_ReplayFramesIdx[MAX_PLAYERS + 1]; // How many frames have been replayed
new g_Unfreeze[MAX_PLAYERS + 1];  // number of frames checking for unfreezing
new g_ReplayNum; // How many replays are running
new Float:g_ReplayStartGameTime[MAX_PLAYERS + 1]; // gametime() of the first frame of the demo
//new bool:g_isCustomFpsReplay[MAX_PLAYERS + 1]; // to know if it's replay with custom FPS, so if there's a replay running when changing the FPS multiplier, that replay's FPS is not changed
new g_ConsolePrintNextFrames[MAX_PLAYERS + 1];
new g_ReplayFpsMultiplier[MAX_PLAYERS + 1]; // atm not gonna implement custom fps replays, just ability to multiply demo fps by an integer up to 4
//new Float:g_ArtificialFrames[MAX_PLAYERS + 1][MAX_FPS_MULTIPLIER]; // when will the calculated extra frames happen
new Float:g_LastFrameTime[MAX_PLAYERS + 1];

new g_RunFrameCount[MAX_PLAYERS + 1];
new g_LastSpawnedBot;

new g_FrameTimeMs[MAX_PLAYERS + 1][2];
new Float:g_FrameTime[MAX_PLAYERS + 1];

new g_ControlPoints[MAX_PLAYERS + 1][CP_TYPES][CP_DATA];
new g_CpCounters[MAX_PLAYERS + 1][COUNTERS];
new g_RunType[MAX_PLAYERS + 1][5];
new Float:g_PrevVelocity[MAX_PLAYERS + 1][3];
new Float:g_Velocity[MAX_PLAYERS + 1][3];
new Float:g_PrevOrigin[MAX_PLAYERS + 1][3];
new Float:g_Origin[MAX_PLAYERS + 1][3];
new Float:g_Angles[MAX_PLAYERS + 1][3];
new Float:g_ViewOfs[MAX_PLAYERS + 1][3];
//new g_Impulses[MAX_PLAYERS + 1];
new g_Buttons[MAX_PLAYERS + 1];
new bool:g_bIsSurfing[MAX_PLAYERS + 1];
new bool:g_bWasSurfing[MAX_PLAYERS + 1];
new bool:g_bIsSurfingWithFeet[MAX_PLAYERS + 1];
new bool:g_hasSurfbugged[MAX_PLAYERS + 1];
new bool:g_hasSlopebugged[MAX_PLAYERS + 1];
new bool:g_StoppedSlidingRamp[MAX_PLAYERS + 1];
new g_RampFrameCounter[MAX_PLAYERS + 1];
new MOVEMENT_STATE:g_Movement[MAX_PLAYERS + 1];
new g_PrevFlags[MAX_PLAYERS + 1];

// Run stats
new Float:g_RunAvgSpeed[MAX_PLAYERS + 1]; // horizontal speeds
new Float:g_RunMaxSpeed[MAX_PLAYERS + 1];
new Float:g_RunCurrSpeed[MAX_PLAYERS + 1];
new Float:g_RunAvgFps[MAX_PLAYERS + 1]; // This is effective fps, not the fps_max, but the real fps player has, like the one `net_graph` shows
new Float:g_RunMinFps[MAX_PLAYERS + 1];
new Float:g_RunDistance2D[MAX_PLAYERS + 1];
new Float:g_RunDistance3D[MAX_PLAYERS + 1];
new g_RunJumps[MAX_PLAYERS + 1];
new g_RunDucktaps[MAX_PLAYERS + 1];
new g_RunStrafes[MAX_PLAYERS + 1];
new g_RunSync[MAX_PLAYERS + 1];
new g_RunSlowdowns[MAX_PLAYERS + 1];  // times you crash into a wall, turn too much losing speed, tap +back, or have any other significant slowdown
new g_RunSlowdownLastFrameChecked[MAX_PLAYERS + 1];
new Float:g_RunLostStartTime[MAX_PLAYERS + 1];  // how many frames passed since you pressed the start button until you started moving
new Float:g_RunLostEndTime[MAX_PLAYERS + 1];  // how many frames passed since you could press the end button, until you actually pressed it
new Float:g_RunStartPrestrafeSpeed[MAX_PLAYERS + 1];  // what was the speed you had in the first jump (or ducktap if it came before the first jump)
new Float:g_RunStartPrestrafeTime[MAX_PLAYERS + 1];  // how much time you spent on the first prestrafe (right after pressing the start button)

new g_MapWeapons[256][WEAPON];    // weapons that are in the map, with their origin and angles
new g_HideableEntity[MAX_ENTITIES];

// These are for a fix for players receiving too much damage from trigger_hurt
new Array:g_DamagedByEntity[MAX_PLAYERS + 1];
new Array:g_DamagedTimeEntity[MAX_PLAYERS + 1];
new Array:g_DamagedPreSpeed[MAX_PLAYERS + 1];

new g_HudRGB[MAX_PLAYERS + 1][3];
new colorRed[COLOR], colorGreen[COLOR], colorBlue[COLOR],
	colorCyan[COLOR], colorMagenta[COLOR], colorYellow[COLOR],
	colorDefault[COLOR], colorGray[COLOR], colorWhite[COLOR],
	colorGold[COLOR], colorBehind[COLOR], colorAhead[COLOR];

new Trie:g_ColorsList;

new g_SyncHudTimer;
new g_SyncHudMessage;
new g_SyncHudKeys;
new g_SyncHudHealth;
new g_SyncHudSpeedometer;
new g_SyncHudDistance;
new g_SyncHudHeightDiff;
new g_SyncHudSpecList;
new g_SyncHudCupMaps;
new g_SyncHudKzVote;
new g_SyncHudLoading;
new g_SyncHudRunStats;

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
new g_PlayersDir[256];
new g_StatsFile[RUN_TYPE][256];
new g_TopType[RUN_TYPE][32];
new Array:g_ArrayStats[RUN_TYPE];
new Array:g_NoResetLeaderboard;

new g_MapIniFile[256];
new g_MapDefaultStart[CP_DATA];
new g_MapPoolFile[256];
new g_CupFile[256];
new g_MapDefaultLightStyle[32];
new g_PlayerMapIniFile[128];

new g_SpectatePreSpecMode;
new bool:g_InForcedRespawn;
new Float:g_LastHealth;
new bool:g_RestoreSolidStates;
new bool:g_IsAgClient;
new bool:g_IsAgServer;
new bool:g_bMatchStarting;
new bool:g_bMatchRunning;
new bool:g_DisableSpec;

new g_BestOfN;            // how many maps will runners play to decide who qualifies, NOT the total maps in the pool, e.g.: Bo5 -> 5
new g_CupPlayer1;         // player index of opponent 1
new g_CupPlayer2;         // player index of opponent 2
new g_CupSteam1[32];      // Steam id of opponent 1
new g_CupSteam2[32];      // Steam id of opponent 2
new g_CupScore1;          // score of opponent 1, score meaning maps won
new g_CupScore2;          // score of opponent 2
new bool:g_CupReady1;     // whether opponent 1 is ready or not
new bool:g_CupReady2;     // whether opponent 2 is ready or not
new Trie:g_CupMapPool;    // mapName->mapState (MAP_BANNED, MAP_PICKED, etc.)
new MATCH_FORMAT:g_CupFormat[MAX_MATCH_MAPS + 1];    // ABBAABD, etc.

new bool:g_isAnyBoostWeaponInMap;

new bool:g_usesStartingZone;

// Run requirements
new g_PlayerRunReqs[MAX_PLAYERS + 1]; // conditions that have to be met to be allowed to end the timer, like pressing a button in the way, etc.
new Trie:g_RunReqs;
new g_RunTotalReq;
new Array:g_SortedRunReqIndexes; // ascending order
new Trie:g_FulfilledRunReqs[MAX_PLAYERS + 1];

// There will be only 1 vote at max showing at a time for a player, and the votes might be directed at specific players, not all of them, e.g.: races
new bool:g_IsKzVoteRunning[MAX_PLAYERS + 1];      // if there's a vote running for this player (may not be for all; directed at specific players)
new bool:g_IsKzVoteVisible[MAX_PLAYERS + 1];      // player preference to hide or show kz votes, as they might want to participate but then hide to not clutter the screen
new bool:g_IsKzVoteIgnoring[MAX_PLAYERS + 1];     // player preference to ignore kz votes, not being able to see or participate in them
new KZ_VOTE_POSITION:g_KzVoteAlignment[MAX_PLAYERS + 1];
new g_KzVoteSetting[MAX_PLAYERS + 1][32];         // the thing that we're voting, e.g.: race
new KZVOTE_VALUE:g_KzVoteValue[MAX_PLAYERS + 1];  // the actual vote: yes, no, undecided, unknown
new Float:g_KzVoteStartTime[MAX_PLAYERS + 1];
new g_KzVoteCaller[MAX_PLAYERS + 1];

new g_EndButton;
new Float:g_EndButtonOrigin[3];

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
new pcvar_kz_pure_max_damage_boost;
new pcvar_kz_pure_max_start_speed;
new pcvar_kz_pure_limit_zone_speed;
new pcvar_kz_remove_func_friction;
new pcvar_kz_invis_func_conveyor;
new pcvar_kz_nightvision;
new pcvar_kz_slopefix;
new pcvar_kz_speedcap;
new pcvar_kz_speclist;
new pcvar_kz_speclist_admin_invis;
new pcvar_kz_autorecord;
new pcvar_kz_max_concurrent_replays;
new pcvar_kz_max_replay_duration;
new pcvar_kz_replay_setup_time;
new pcvar_kz_replay_dir_suffix;
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
new pcvar_kz_cup_format;
new pcvar_kz_cup_map_change_delay;
new pcvar_kz_stop_moving_platforms;
new pcvar_kz_noreset_agstart;   // count agstarts as no-reset runs? (there might be some exploit or annoyance with agstart)
//new pcvar_kz_noreset_race;    // same as for agstarts, but for races made through custom kz votes
new pcvar_kz_noreset_countdown; // default countdown for no-reset runs
new pcvar_kz_race_countdown;    // countdown for races done with custom kz votes
new pcvar_kz_vote_hold_time;    // time that the vote will appear and be votable
new pcvar_kz_vote_wait_time;    // minimum time to make a new vote since the last one
new pcvar_kz_noclip;
new pcvar_kz_noclip_speed;

new cvarhook:hookInvisFuncConveyor;

new Handle:g_DbHost;
new Handle:g_DbConnection;

new g_FwLightStyle;
new g_FwKeyValuePre;

new Array:g_AgAllowedGamemodes;
new bool:g_AgVoteRunning;
new bool:g_AgInterruptingVoteRunning;
new g_MsgCountdown;

new pcvar_sv_ag_match_running;

new mfwd_hlkz_cheating;
new mfwd_hlkz_worldrecord;
new mfwd_hlkz_timer_start;

public plugin_precache()
{
	server_print("[%s] Executing plugin_precache()", PLUGIN_TAG);

	g_FwLightStyle = register_forward(FM_LightStyle, "Fw_FmLightStyle");
	g_PauseSprite = precache_model("sprites/pause_icon.spr");
	precache_model("models/player/robo/robo.mdl");
	g_Firework = precache_model("sprites/firework.spr");
	precache_sound(FIREWORK_SOUND);

	// Key/Values are read before plugin_init()
	g_FwKeyValuePre = register_forward(FM_KeyValue, "Fw_FmKeyValuePre");

	// Splits stuff
	g_Splits = TrieCreate();

	// Map requirements to finish a run
	// Requirement = a trigger or something you have to activate or go through
	g_RunReqs = TrieCreate();
}

public plugin_init()
{
	server_print("[%s] Executing plugin_init()", PLUGIN_TAG);

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

	new ag_version[32];
	get_cvar_string("sv_ag_version", ag_version, charsmax(ag_version));
	if (ag_version[0])
	{
		// These will be used to decide whether to send an AG event/message that AG clients can handle,
		// but other mods can't, or a HUDMessage otherwise
		if (containi(ag_version, "mini") == -1)
		{
			// There's a small chance that someone uses for example the HL client for AG
			// I don't know why you would do that, but my assumption would fail in that case
			g_IsAgClient = true;
		}
		g_IsAgServer = true;
	}

	pcvar_kz_uniqueid = register_cvar("kz_uniqueid", "3");  // 1 - name, 2 - ip, 3 - steamid
	pcvar_kz_spawn_mainmenu = register_cvar("kz_spawn_mainmenu", "1");
	pcvar_kz_messages = register_cvar("kz_messages", "2");  // 0 - none, 1 - chat, 2 - hud
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
	pcvar_kz_nostat = register_cvar("kz_nostat", "0");  // Disable stats storing (use for tests or fun)
	pcvar_kz_top_records = register_cvar("kz_top_records", "15");  // show 15 records of a top
	pcvar_kz_top_records_max = register_cvar("kz_top_records_max", "25");  // show max. 25 records even if player requests 100

	// Maximum speed when starting the timer to be considered a pure run
	new defaultMaxStartSpeed[11];
	float_to_str(START_BUTTON_ALLOWED_PRESPEED, defaultMaxStartSpeed, charsmax(defaultMaxStartSpeed));
	pcvar_kz_pure_max_start_speed = register_cvar("kz_pure_max_start_speed", defaultMaxStartSpeed);
	pcvar_kz_pure_limit_zone_speed = register_cvar("kz_pure_limit_zone_speed", "1");

	pcvar_kz_remove_func_friction = register_cvar("kz_remove_func_friction", "0");
	pcvar_kz_invis_func_conveyor = register_cvar("kz_invis_func_conveyor", "1");
	hookInvisFuncConveyor = hook_cvar_change(pcvar_kz_invis_func_conveyor, "InvisFuncConveyorChange");

	pcvar_kz_pure_max_damage_boost = register_cvar("kz_pure_max_damage_boost", "100");

	// 0 = disabled, 1 = all nightvision types allowed, 2 = only flashlight-like nightvision allowed, 3 = only map-global nightvision allowed
	pcvar_kz_nightvision = register_cvar("kz_def_nightvision", "0");

	// 0 - slopebug/surfbug fix disabled, 1 - fix enabled, may want to disable it when you consistently get stuck in little slopes while sliding+wallstrafing
	pcvar_kz_slopefix = register_cvar("kz_slopefix", "0");
	pcvar_kz_speedcap = register_cvar("kz_speedcap", "0");  // 0 means the player can set the speedcap at the horizontal speed they want
	pcvar_kz_speclist = register_cvar("kz_speclist", "0");
	pcvar_kz_speclist_admin_invis = register_cvar("kz_speclist_admin_invis", "0");

	pcvar_kz_autorecord = register_cvar("kz_autorecord", "1");
	pcvar_kz_max_concurrent_replays = register_cvar("kz_max_concurrent_replays", "5");
	pcvar_kz_max_replay_duration = register_cvar("kz_max_replay_duration", "1200");  // in seconds (default: 20 minutes)
	pcvar_kz_replay_setup_time = register_cvar("kz_replay_setup_time", "2");  // in seconds
	pcvar_kz_replay_dir_suffix = register_cvar("kz_replay_dir_suffix", "");

	pcvar_kz_spec_unfreeze = register_cvar("kz_spec_unfreeze", "1");  // unfreeze spectator cam when watching a replaybot teleport

	pcvar_allow_spectators = get_cvar_pointer("allow_spectators");

	pcvar_sv_ag_match_running = get_cvar_pointer("sv_ag_match_running");

	pcvar_kz_denied_sound = register_cvar("kz_denied_sound", "0");

	pcvar_sv_items_respawn_time = register_cvar("sv_items_respawn_time", "0");  // 0 = unchanged, n > 0 = n seconds

	// 0 = store data in files and only store leaderboards,
	// 1 = store data in MySQL and store much more data (not only leaderboards),
	// 2 = store data in both (files and mysql) and retrieve from file only if it fails to retrieve from DB
	pcvar_kz_mysql = register_cvar("kz_mysql", "0");

	// How many threads to use with MySQL, so it can use that many threads per frame to query stuff (1 query per thread?). This depends on the CPU you have in the server I guess
	pcvar_kz_mysql_threads = register_cvar("kz_mysql_threads", "1");
	pcvar_kz_mysql_thread_fps = register_cvar("kz_mysql_thread_fps", "33");  // MySQLT module only admits values between 4 and 33 fps
	pcvar_kz_mysql_collect_time_ms = register_cvar("kz_mysql_collect_time_ms", "30");  // MySQLT module only admits values between 30 and 300 ms
	pcvar_kz_mysql_host = register_cvar("kz_mysql_host", "");  // IP:port, FQDN:port, etc.
	pcvar_kz_mysql_user = register_cvar("kz_mysql_user", "");  // Name of the MySQL user that will be used to read/write data in the DB
	pcvar_kz_mysql_pass = register_cvar("kz_mysql_pass", "");  // Password of the MySQL user
	pcvar_kz_mysql_db   = register_cvar("kz_mysql_db", "");    // MySQL database name

	pcvar_kz_cup_format = register_cvar("kz_cup_format", "ABABABD");
	pcvar_kz_cup_map_change_delay = register_cvar("kz_cup_map_change_delay", "12.0");

	pcvar_kz_stop_moving_platforms = register_cvar("kz_stop_moving_platforms", "0");
	pcvar_kz_noclip = register_cvar("kz_noclip", "0"); // Whether or not /noclip is allowed
	pcvar_kz_noclip_speed = create_cvar("kz_noclip_speed", "0", _, "Max movement speed with noclip, players can't set their speed higher than this. 0 = no limits", true, 0.0);

	pcvar_kz_noreset_agstart   = register_cvar("kz_noreset_agstart", "0");
	//pcvar_kz_noreset_race      = register_cvar("kz_noreset_race", "0");
	pcvar_kz_noreset_countdown = register_cvar("kz_noreset_countdown", "5");
	pcvar_kz_race_countdown    = register_cvar("kz_race_countdown", "5");
	pcvar_kz_vote_hold_time    = register_cvar("kz_vote_hold_time", "10");
	pcvar_kz_vote_wait_time    = register_cvar("kz_vote_wait_time", "10");


	register_dictionary("telemenu.txt");
	register_dictionary("common.txt");

	register_clcmd("kz_teleportmenu", "CmdTPMenuHandler",     ADMIN_CFG, "- displays kz teleport menu");
	register_clcmd("kz_setstart",     "CmdSetStartHandler",   ADMIN_CFG, "- set start position");
	register_clcmd("kz_clearstart",   "CmdClearStartHandler", ADMIN_CFG, "- clear start position");

	// Cup and map pool stuff
	register_clcmd("kz_cup",            "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	register_clcmd("kz_bo",             "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	register_clcmd("kz_bestof",         "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
	register_clcmd("kz_bestofn",        "CmdCupHandler",        ADMIN_CFG, "- start a cup match between 2 players");
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
	register_clcmd("kz_cup_forceready", "CmdCupForceReady",     ADMIN_CFG, "- forces a player to ready.");
	register_clcmd("kz_cup_maps",       "CmdCupMapsHandler",    ADMIN_CFG, "- how many maps to play, e.g.: 5 for a Bo5.");

	register_clcmd("kz_set_custom_start",	"CmdSetCustomStartHandler",    -1, "- sets the custom start position");
	register_clcmd("kz_clear_custom_start",	"CmdClearCustomStartHandler",  -1, "- clears the custom start position");

	// TODO remove these below or make them admin-only to set the availability of these commands for client usage, clients will use say commands instead of console ones to set these variables
	register_clcmd("kz_start_message", "CmdShowStartMsg", -1, "<0|1> - toggles the message that appears when starting the timer");
	register_clcmd("kz_time_decimals", "CmdTimeDecimals", -1, "<1-6> - sets a number of decimals to be displayed for times (seconds)");
	register_clcmd("kz_nightvision",   "CmdNightvision",  -1, "<0-2> - sets nightvision mode. 0=off, 1=flashlight-like, 2=map-global");

	register_clcmd("say",      "CmdSayHandler");
	register_clcmd("say_team", "CmdSayHandler");
	register_clcmd("spectate", "CmdSpectateHandler");

	register_clcmd("jointeam",   "CmdJointeamHandler");
	register_clcmd("changeteam", "CmdJointeamHandler");

	if (g_IsAgServer)
	{
		register_clcmd("agstart",               "CmdAgVoteHandler");
		register_clcmd("vote agstart",          "CmdAgVoteHandler");
		register_clcmd("callvote agstart",      "CmdAgVoteHandler");
		register_clcmd("vote map",              "CmdAgVoteHandler");
		register_clcmd("callvote map",          "CmdAgVoteHandler");
		register_clcmd("vote changelevel",      "CmdAgVoteHandler");
		register_clcmd("callvote changelevel",  "CmdAgVoteHandler");
		register_clcmd("agmap",                 "CmdAgVoteHandler");
		register_clcmd("vote agmap",            "CmdAgVoteHandler");
		register_clcmd("callvote agmap",        "CmdAgVoteHandler");
		register_clcmd("mp_timelimit",          "CmdTimelimitVoteHandler");
		register_clcmd("vote mp_timelimit",     "CmdTimelimitVoteHandler");
		register_clcmd("callvote mp_timelimit", "CmdTimelimitVoteHandler");

		// Changing the gamemode requires the map to change (or restart), leading to No-Reset runners potentially losing
		// their run, so we want to get all the votable gamemodes in this server and handle them
		new ag_allowed_gamemodes[256];
		get_cvar_string("sv_ag_allowed_gamemodes", ag_allowed_gamemodes, charsmax(ag_allowed_gamemodes));

		g_AgAllowedGamemodes = ArrayCreate(32, 24);

		new buffer[33];
		new isSplit = strtok2(ag_allowed_gamemodes, buffer, charsmax(buffer), ag_allowed_gamemodes, charsmax(ag_allowed_gamemodes), ';', 1); // trim just in case
		while (isSplit > -1)
		{
			ArrayPushString(g_AgAllowedGamemodes, buffer);

			buffer[0] = EOS; // clear the string just in case
			isSplit = strtok2(ag_allowed_gamemodes, buffer, charsmax(buffer), ag_allowed_gamemodes, charsmax(ag_allowed_gamemodes), ';', 1);
		}
		ArrayPushString(g_AgAllowedGamemodes, buffer); // push the last one

		for (new i = 0; i < ArraySize(g_AgAllowedGamemodes); i++)
		{
			new gamemode[32], voteGamemode[37], callvoteGamemode[41];
			ArrayGetString(g_AgAllowedGamemodes, i, gamemode, charsmax(gamemode));

			//server_print("registering handler for gamemode '%s'", gamemode);

			formatex(voteGamemode, charsmax(voteGamemode), "vote %s", gamemode);
			formatex(callvoteGamemode, charsmax(callvoteGamemode), "callvote %s", gamemode);

			register_clcmd(gamemode,         "CmdAgVoteHandler");
			register_clcmd(voteGamemode,     "CmdAgVoteHandler");
			register_clcmd(callvoteGamemode, "CmdAgVoteHandler");
		}
	}

	register_clcmd("+hook",              "CheatCmdHandler");
	register_clcmd("-hook",              "CheatCmdHandler");
	register_clcmd("+rope",              "CheatCmdHandler");
	register_clcmd("-rope",              "CheatCmdHandler");
	register_clcmd("+tas_perfectstrafe", "TASCmdHandler");
	register_clcmd("-tas_perfectstrafe", "TASCmdHandler");
	register_clcmd("+tas_autostrafe",    "TASCmdHandler");
	register_clcmd("-tas_autostrafe",    "TASCmdHandler");

	register_menucmd(register_menuid(MAIN_MENU_ID),     1023, "ActionKzMenu");
	register_menucmd(register_menuid(TELE_MENU_ID),     1023, "ActionTeleportMenu");
	register_menucmd(register_menuid(MAP_BAN_MENU_ID),  1023, "ActionMapBanMenu");
	register_menucmd(register_menuid(MAP_PICK_MENU_ID), 1023, "ActionMapPickMenu");

	register_think("replay_bot", "npc_think");

	RegisterHam(Ham_Use, "func_button", "Fw_HamUseButtonPre");
	RegisterHam(Ham_Touch, "trigger_multiple", "Fw_HamUseButtonPre"); // ag_bhop_master.bsp starts timer when jumping on a platform
	RegisterHam(Ham_Spawn, "player", "Fw_HamSpawnPlayerPost", 1);
	RegisterHam(Ham_Spawn, "weaponbox", "Fw_HamSpawnWeaponboxPost", 1);
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPre");
	RegisterHam(Ham_Killed, "player", "Fw_HamKilledPlayerPost", 1);
	RegisterHam(Ham_BloodColor, "player", "Fw_HamBloodColorPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPre");
	RegisterHam(Ham_TakeDamage, "player", "Fw_HamTakeDamagePlayerPost", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_crossbow",    "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_egon",        "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_handgrenade", "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_hornetgun",   "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_rpg",         "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_satchel",     "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_snark",       "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack,   "weapon_tripmine",    "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_9mmAR",       "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_gauss",       "Fw_HamBoostAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_satchel",     "Fw_HamBoostAttack");

	if (get_pcvar_float(pcvar_sv_items_respawn_time) > 0)
	{
		for (new i = 0; i < sizeof(g_ItemNames); i++)
			RegisterHam(Ham_Respawn, g_ItemNames[i], "Fw_HamItemRespawn", 1);

		for (new j = 0; j < sizeof(g_WeaponNames); j++)
			register_touch(g_WeaponNames[j], "worldspawn", "Fw_FmWeaponRespawn");
	}

	// Registered in precache, no longer necessary
	unregister_forward(FM_LightStyle, g_FwLightStyle);
	unregister_forward(FM_KeyValue, g_FwKeyValuePre);

	register_forward(FM_ClientKill,"Fw_FmClientKillPre");
	register_forward(FM_ClientCommand, "Fw_FmClientCommandPost", 1);
	register_forward(FM_Think, "Fw_FmThinkPre");
	register_forward(FM_PlayerPreThink, "Fw_FmPlayerPreThinkPost", 1);
	register_forward(FM_PlayerPostThink, "Fw_FmPlayerPostThinkPre");
	register_forward(FM_AddToFullPack, "Fw_FmAddToFullPackPost", 1);
	register_forward(FM_GetGameDescription,"Fw_FmGetGameDescriptionPre");
	register_forward(FM_Touch, "Fw_FmTouchPre");
	register_forward(FM_CmdStart, "Fw_FmCmdStartPre");
	register_touch("hornet",           "player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_satchel",  "player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_snark",    "player", "Fw_FmPlayerTouchMonster");
	register_touch("monster_tripmine", "player", "Fw_FmPlayerTouchMonster");
	register_touch("trigger_teleport", "player", "Fw_FmPlayerTouchTeleport");

	mfwd_hlkz_cheating    = CreateMultiForward("hlkz_cheating",    ET_IGNORE, FP_CELL);
	mfwd_hlkz_worldrecord = CreateMultiForward("hlkz_worldrecord", ET_IGNORE, FP_CELL, FP_CELL);
	mfwd_hlkz_timer_start = CreateMultiForward("hlkz_timer_start", ET_IGNORE, FP_CELL);

	register_message(get_user_msgid("Health"), "Fw_MsgHealth");
	register_message(SVC_TEMPENTITY, "Fw_MsgTempEntity");

	if (g_IsAgServer)
	{
		g_MsgCountdown = get_user_msgid("Countdown");

		register_message(g_MsgCountdown,             "Fw_MsgCountdown");
		register_message(get_user_msgid("Vote"),     "Fw_MsgVote");
		register_message(get_user_msgid("Settings"), "Fw_MsgSettings");
	}

	g_TaskEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	set_pev(g_TaskEnt, pev_classname, engfunc(EngFunc_AllocString, "timer_entity"));
	set_pev(g_TaskEnt, pev_nextthink, get_gametime() + 1.01);

	g_MaxPlayers = get_maxplayers();

	g_SyncHudTimer          = CreateHudSyncObj();
	g_SyncHudMessage        = CreateHudSyncObj();
	g_SyncHudKeys           = CreateHudSyncObj();
	g_SyncHudHealth         = CreateHudSyncObj();
	g_SyncHudDistance       = CreateHudSyncObj();
	g_SyncHudHeightDiff     = CreateHudSyncObj();
	g_SyncHudSpeedometer    = CreateHudSyncObj();
	g_SyncHudSpecList       = CreateHudSyncObj();
	g_SyncHudCupMaps        = CreateHudSyncObj();
	g_SyncHudKzVote         = CreateHudSyncObj();
	g_SyncHudLoading        = CreateHudSyncObj();
	g_SyncHudRunStats       = CreateHudSyncObj();

	g_ArrayStats[NOOB]   = ArrayCreate(STATS);
	g_ArrayStats[PRO]    = ArrayCreate(STATS);
	g_ArrayStats[PURE]   = ArrayCreate(STATS);
	g_NoResetLeaderboard = ArrayCreate(NORESET);

	g_OrderedSplits = ArrayCreate(17, 3);

	new split[SPLIT];

	//server_print("Unsorted splits:");
	new TrieIter:ti = TrieIterCreate(g_Splits);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetArray(ti, split, sizeof(split));

		//server_print("%s (%d, %s, %d)", split[SPLIT_ID], split[SPLIT_ENTITY], split[SPLIT_NAME], split[SPLIT_LAP_START]);

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	SortSplits();

	g_DbPlayerId = TrieCreate();

	new splitId[17];

	if (ArraySize(g_OrderedSplits))
	{
		server_print("Sorted splits:");
		for (new i = 0; i < ArraySize(g_OrderedSplits); i++)
		{
			ArrayGetString(g_OrderedSplits, i, splitId, charsmax(splitId));
			server_print("#%d - %s", i, splitId);
		}
	}

	g_ReplayNum = 0;
}

public plugin_cfg()
{
	server_print("[%s] [%.3f] Executing plugin_cfg()", PLUGIN_TAG, get_gametime());
	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	// Execute custom config file
	new cfg[256];
	formatex(cfg, charsmax(cfg), "%s/%s.cfg", g_ConfigsDir, PLUGIN_CFG_FILENAME);
	if (file_exists(cfg))
	{
		server_cmd("exec %s", cfg);
		server_exec();
	}

	// Execute custom config file in a multi-instance server environment
	// So you may have several hlds instances running with the same user and same files,
	// and you want to configure different HLKZ databases for each instance. So here we're
	// gonna rely on the `+servercfg` launch param, which you're probably already using
	// with a different value for each server instance. If you have `+servercfg myinstance.cfg`,
	// HLKZ is gonna search for hl_kreedz_myinstance.cfg in amxmodx/configs and execute it
	new serverCfgPath[256], serverCfgFile[128], instanceCfgFile[256];
	get_cvar_string("servercfgfile", serverCfgPath, charsmax(serverCfgPath));
	remove_filepath(serverCfgPath, serverCfgFile, charsmax(serverCfgFile));
	formatex(instanceCfgFile, charsmax(instanceCfgFile), "%s/%s_%s", g_ConfigsDir, PLUGIN_CFG_FILENAME, serverCfgFile);
	if (file_exists(instanceCfgFile))
	{
		server_cmd("exec %s", instanceCfgFile);
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
	format(g_ConfigsDir, charsmax(g_ConfigsDir), "%s/%s", g_ConfigsDir, CONFIGS_SUB_DIR);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	// Get/prepare the different possible replay directories:
	// 1. Check the directory specified by cvar, useful for servers with shared folders
	// 2. Or check for the directory specific for this server instance in a multi-instance environment
	// 3. Otherwise just go for the "replays" directory
	// The instance name should be the value of +servercfgfile minus the extension (".cfg")
	new suffix[128];
	if (get_pcvar_string(pcvar_kz_replay_dir_suffix, suffix, charsmax(suffix)) > 0)
	{
		formatex(g_ReplaysDir, charsmax(g_ReplaysDir), "%s/%s_%s", g_ConfigsDir, REPLAYS_DIR_NAME, suffix);
		if (!dir_exists(g_ReplaysDir))
			mkdir(g_ReplaysDir);
	}
	else
	{
		new instanceName[sizeof(serverCfgFile) - 4];
		copy(instanceName, strlen(serverCfgFile) - 4, serverCfgFile);
		formatex(g_ReplaysDir, charsmax(g_ReplaysDir), "%s/%s_%s", g_ConfigsDir, REPLAYS_DIR_NAME, instanceName);
		// Don't create a folder for the replays of this instance, we expect the admin to create it, because
		// +servercfgfile is set always (i guess?), so since it always has a value we can't know if you actually
		// want to separate this instance's replays from the other servers until you indicate it by creating the folder
		if (!dir_exists(g_ReplaysDir))
		{
			// Fall back to the default folder
			formatex(g_ReplaysDir, charsmax(g_ReplaysDir), "%s/%s", g_ConfigsDir, REPLAYS_DIR_NAME);
			if (!dir_exists(g_ReplaysDir))
				mkdir(g_ReplaysDir);
		}
	}
	server_print("[%s] Replays dir: %s", PLUGIN_TAG, g_ReplaysDir);

	formatex(g_PlayersDir, charsmax(g_PlayersDir), "%s/%s", g_ConfigsDir, "players");
	if (!dir_exists(g_PlayersDir))
		mkdir(g_PlayersDir);

	GetTopTypeString(NOOB, g_TopType[NOOB], charsmax(g_TopType[]));
	GetTopTypeString(PRO,  g_TopType[PRO],  charsmax(g_TopType[]));
	GetTopTypeString(PURE, g_TopType[PURE], charsmax(g_TopType[]));

	// Load stats
	formatex(g_StatsFile[NOOB], charsmax(g_StatsFile[]), "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[NOOB]);
	formatex(g_StatsFile[PRO],  charsmax(g_StatsFile[]), "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[PRO]);
	formatex(g_StatsFile[PURE], charsmax(g_StatsFile[]), "%s/%s_%s.dat", g_ConfigsDir, g_Map, g_TopType[PURE]);

	// Load map settings
	formatex(g_MapIniFile, charsmax(g_MapIniFile), "%s/%s.ini", g_ConfigsDir, g_Map);
	LoadMapSettings();

	// Player settings relative to the map are in this file
	formatex(g_PlayerMapIniFile, charsmax(g_PlayerMapIniFile), "%s/players/%s.ini", CONFIGS_SUB_DIR, g_Map);

	g_isAnyBoostWeaponInMap = false;
	CheckMapWeapons();
	CheckTeleportDestinations();
	CheckHideableEntities();
	CheckStartEnd();

	g_RunTotalReq = TrieGetSize(g_RunReqs);
	if (g_RunTotalReq)
		PrepareRunReqs();

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

	InitHudColors();

	InitTopsAndDB();
}

public plugin_end()
{
	ArrayDestroy(Array:g_ArrayStats[NOOB]);
	ArrayDestroy(Array:g_ArrayStats[PRO]);
	ArrayDestroy(Array:g_ArrayStats[PURE]);
	ArrayDestroy(g_NoResetLeaderboard);
	ArrayDestroy(g_AgAllowedGamemodes);
	ArrayDestroy(g_OrderedSplits);
	ArrayDestroy(g_SortedRunReqIndexes);

	TrieDestroy(g_DbPlayerId);
	TrieDestroy(g_CupMapPool);
	TrieDestroy(g_ColorsList);
	TrieDestroy(g_Splits);

	DestroyForward(mfwd_hlkz_cheating);
	DestroyForward(mfwd_hlkz_worldrecord);
	DestroyForward(mfwd_hlkz_timer_start);
}

// To be executed after cvars in amxx.cfg and other configs have been set,
// important for the DB connection to be up before loading any top
// FIXME: this should be put back in the init without delay, and the commands should go in hl_kreedz.cfg
InitTopsAndDB()
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

		new threadFPS = get_pcvar_num(pcvar_kz_mysql_thread_fps);
		new threadThinkTime = 1000 / threadFPS;
		mysql_performance(get_pcvar_num(pcvar_kz_mysql_collect_time_ms), threadThinkTime, get_pcvar_num(pcvar_kz_mysql_threads));

		GetMapIdAndLeaderboards();

		// TODO: Insert server location data
		// TODO: Insert the `server` if doesn't exist
		// TODO: Insert the `server_map` if doesn't exist
	}
	else
	{
		LoadRecordsFile(PURE);
		LoadRecordsFile(PRO);
		LoadRecordsFile(NOOB);
	}
}

InitHudColors()
{
	//                        Name       R    G    B
	CreateColor(colorRed,     "red",     255,   0,   0);
	CreateColor(colorGreen,   "green",     0, 255,   0);
	CreateColor(colorBlue,    "blue",      0,   0, 255);
	CreateColor(colorCyan,    "cyan",      0, 255, 255);
	CreateColor(colorMagenta, "magenta", 255,   0, 255);
	CreateColor(colorYellow,  "yellow",  255, 255,   0);
	CreateColor(colorDefault, "default", 255, 160,   0);
	CreateColor(colorGray,    "gray",    128, 128, 128);
	CreateColor(colorWhite,   "white",   255, 255, 255);

	// These are defaults for delta times
	CreateColor(colorGold,   "gold",      255, 215,   0);
	CreateColor(colorBehind, "crimson",   220,  20,  60); // crimson color (redish)
	CreateColor(colorAhead,  "emerald",    80, 220, 100); // limegreen color (greenish)

	g_ColorsList = TrieCreate();

	TrieSetArray(g_ColorsList, "red",       colorRed,     sizeof(colorRed));
	TrieSetArray(g_ColorsList, "green",     colorGreen,   sizeof(colorGreen));
	TrieSetArray(g_ColorsList, "blue",      colorBlue,    sizeof(colorBlue));
	TrieSetArray(g_ColorsList, "cyan",      colorCyan,    sizeof(colorCyan));
	TrieSetArray(g_ColorsList, "magenta",   colorMagenta, sizeof(colorMagenta));
	TrieSetArray(g_ColorsList, "yellow",    colorYellow,  sizeof(colorYellow));
	TrieSetArray(g_ColorsList, "default",   colorDefault, sizeof(colorDefault));
	TrieSetArray(g_ColorsList, "gray",      colorGray,    sizeof(colorGray));
	TrieSetArray(g_ColorsList, "white",     colorWhite,   sizeof(colorWhite));

	TrieSetArray(g_ColorsList, "gold",      colorGold,    sizeof(colorGold));
	TrieSetArray(g_ColorsList, "crimson",   colorBehind,  sizeof(colorBehind));
	TrieSetArray(g_ColorsList, "limegreen", colorAhead,   sizeof(colorAhead));
}

public InitPlayerSplits(taskId)
{
	new id = taskId - TASKID_INIT_PLAYER_GOLDS;

	if (!pev_valid(id) || !IsPlayer(id))
		return;

	if (!g_MapId)
	{
		// Ugly way
		set_task(1.0, "InitPlayerSplits", taskId);
		return;
	}

	g_GoldLaps[id][PURE] = ArrayCreate(1, 5);
	g_GoldLaps[id][PRO] = ArrayCreate(1, 5);
	g_GoldLaps[id][NOOB] = ArrayCreate(1, 5);

	g_GoldSplits[id][PURE] = ArrayCreate(1, 15);
	g_GoldSplits[id][PRO] = ArrayCreate(1, 15);
	g_GoldSplits[id][NOOB] = ArrayCreate(1, 15);

	g_PbLaps[id][PURE] = ArrayCreate(1, 5);
	g_PbLaps[id][PRO] = ArrayCreate(1, 5);
	g_PbLaps[id][NOOB] = ArrayCreate(1, 5);

	g_PbSplits[id][PURE] = ArrayCreate(1, 15);
	g_PbSplits[id][PRO] = ArrayCreate(1, 15);
	g_PbSplits[id][NOOB] = ArrayCreate(1, 15);

	g_IsUsingSplits[id] = true;

	// Allocate the number of cells that we're gonna use throughout runs in this map,
	// so we can straight up do ArrayGetCell()/ArraySetCell() later without having
	// to clutter everything with size checks, ArrayPushCell() and stuff
	for (new i = 0; i < g_RunLaps; i++)
	{
		ArrayPushCell(Array:g_GoldLaps[id][PURE], 0.0);
		ArrayPushCell(Array:g_GoldLaps[id][PRO], 0.0);
		ArrayPushCell(Array:g_GoldLaps[id][NOOB], 0.0);

		ArrayPushCell(Array:g_PbLaps[id][PURE], 0.0);
		ArrayPushCell(Array:g_PbLaps[id][PRO], 0.0);
		ArrayPushCell(Array:g_PbLaps[id][NOOB], 0.0);
	}

	new totalSplits = g_RunLaps * ArraySize(g_OrderedSplits);
	for (new i = 0; i < totalSplits; i++)
	{
		ArrayPushCell(Array:g_GoldSplits[id][PURE], 0.0);
		ArrayPushCell(Array:g_GoldSplits[id][PRO], 0.0);
		ArrayPushCell(Array:g_GoldSplits[id][NOOB], 0.0);

		ArrayPushCell(Array:g_PbSplits[id][PURE], 0.0);
		ArrayPushCell(Array:g_PbSplits[id][PRO], 0.0);
		ArrayPushCell(Array:g_PbSplits[id][NOOB], 0.0);
	}

	PlayerGoldLapsSelect(id, PURE);
	PlayerGoldLapsSelect(id, PRO);
	PlayerGoldLapsSelect(id, NOOB);

	PlayerGoldSplitsSelect(id, PURE);
	PlayerGoldSplitsSelect(id, PRO);
	PlayerGoldSplitsSelect(id, NOOB);

	LoadPlayerPbSplits(id);

	// TODO same for No-Reset gold laps when it's implemented
}

LoadPlayerPbSplits(id)
{
	PlayerPbLapsSelect(id, PURE);
	PlayerPbLapsSelect(id, PRO);
	PlayerPbLapsSelect(id, NOOB);

	PlayerPbSplitsSelect(id, PURE);
	PlayerPbSplitsSelect(id, PRO);
	PlayerPbSplitsSelect(id, NOOB);

	// Not really updated yet, until the queries are executed, but this is enough for the moment
	g_PbSplitsUpToDate[id] = true;
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
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "%s\n\n", PLUGIN);
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. START CLIMB\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Checkpoints\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Practice checkpoints\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. HUD settings\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Top climbers\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Lap leaderboards\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "7. Spectate players\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Help\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "8. About\n\n");
			//len += formatex(menuBody[len], charsmax(menuBody) - len, "9. Admin area\n\n");
		}
	case 1:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Climb Menu\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Start position\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Respawn\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Pause timer\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Reset\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Set custom start position\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Clear custom start position\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "7. Start a No-Reset run\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Start a Race\n");
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
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Show Top Climbers\n\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Pure 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Pro 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Noob 15\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. No-Reset 15\n");
		}
	case 6:
		{
			keys |= MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6;

			len = formatex(menuBody[len], charsmax(menuBody) - len, "Show laps from PBs:\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Pure\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Pro\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Noob\n\n");
			// TODO: len += formatex(menuBody[len], charsmax(menuBody) - len, "4. No-Reset\n\n")

			len += formatex(menuBody[len], charsmax(menuBody) - len, "Show Gold laps:\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Pure\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Pro\n");
			len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Noob\n");
			// TODO: len += formatex(menuBody[len], charsmax(menuBody) - len, "8. No-Reset\n");
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

CreateMapMenu(id, const menu_id[], bool:wasBadChoice=false)
{
	new playerName[MAX_NAME_LENGTH];
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

	new i, /*map[32], mapState,*/ cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		//TrieIterGetCell(ti, mapState);
		//TrieIterGetKey(ti, map, charsmax(map));
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		server_print("building menu item %d with map %s", i, cupMap[MAP_NAME]);

		new mapStateText[10];
		if (g_MapStateString[_:cupMap[MAP_STATE_]][0])
		{
			formatex(mapStateText, charsmax(mapStateText), "[%s]", g_MapStateString[_:cupMap[MAP_STATE_]]);
			strtoupper(mapStateText);
		}

		if (cupMap[MAP_STATE_] == MAP_IDLE)
		{
			format(menuText, charsmax(menuText), "%s\\y%d\\w. %s %s\n",
				menuText,
				i+1,
				cupMap[MAP_NAME],
				mapStateText);
		}
		else
		{
			format(menuText, charsmax(menuText), "%s\\r%d\\d. %s %s\n",
				menuText,
				i+1,
				cupMap[MAP_NAME],
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
	new i, /*map[32], mapState*/ cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		if (key == i)
		{
			//TrieIterGetCell(ti, mapState);
			TrieIterGetArray(ti, cupMap, sizeof(cupMap));

			if (cupMap[MAP_STATE_] == MAP_IDLE)
			{
				//TrieIterGetKey(ti, cupMap[MAP_NAME], charsmax(cupMap[MAP_NAME]));
				break;
			}
		}

		i++;
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (cupMap[MAP_STATE_] == MAP_IDLE)
	{
		new totalPoolMaps = TrieGetSize(g_CupMapPool);
		new availableMaps = CountCupMaps(MAP_IDLE);

		// Update map state
		//TrieSetCell(g_CupMapPool, map, MAP_BANNED);
		cupMap[MAP_ORDER]  = totalPoolMaps - availableMaps;
		cupMap[MAP_STATE_] = MAP_BANNED;
		cupMap[MAP_PICKER] = MATCH_FORMAT:g_CupFormat[cupMap[MAP_ORDER]];
		TrieSetArray(g_CupMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap));
		availableMaps--;

		new playerName[32];
		GetColorlessName(id, playerName, charsmax(playerName));

		client_print(0, print_chat, "[%s] %s banned %s.", PLUGIN_TAG, playerName, cupMap[MAP_NAME]);

		new remainingMapsToBan = availableMaps - g_BestOfN;
		if (remainingMapsToBan > 0)
		{
			client_print(0, print_chat, "[%s] Remaining %d map%s to be banned.",
				PLUGIN_TAG, remainingMapsToBan, remainingMapsToBan == 1 ? "" : "s");
		}
		else
		{
			client_print(0, print_chat, "[%s] We're done banning maps. Time to pick! Now %d maps will be picked and then the remaining one is the decider.",
				PLUGIN_TAG, availableMaps - 1);
		}
		CmdMapsShowHandler(0);

		server_print("ActionMapBanMenu :: availableMaps=%d, g_BestOfN=%d", availableMaps, g_BestOfN);
		new nextPicker = GetNextPicker();

		if (availableMaps == g_BestOfN)
		{
			// Time to start picking maps
			server_print("showing map pick menu to player #%d", nextPicker);
			CreateMapMenu(nextPicker, MAP_PICK_MENU_ID);
		}
		else
		{
			// Continue banning
			server_print("showing map ban menu to player #%d", nextPicker);
			CreateMapMenu(nextPicker, MAP_BAN_MENU_ID);
		}
	}
	else
	{
		client_print(id, print_chat, "[%s] Please, ban a map that's not already banned.", PLUGIN_TAG);
		CreateMapMenu(id, MAP_BAN_MENU_ID, true);
	}

	return PLUGIN_HANDLED;
}

public ActionMapPickMenu(id, key)
{
	new i, /*map[32], mapState*/ cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		if (key == i)
		{
			//TrieIterGetCell(ti, mapState);
			TrieIterGetArray(ti, cupMap, sizeof(cupMap));

			if (cupMap[MAP_STATE_] == MAP_IDLE)
			{
				//TrieIterGetKey(ti, map, charsmax(map));
				break;
			}
		}

		i++;
		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (cupMap[MAP_STATE_] == MAP_IDLE)
	{
		new totalPoolMaps = TrieGetSize(g_CupMapPool);
		new availableMaps = CountCupMaps(MAP_IDLE);

		// Update map state
		//TrieSetCell(g_CupMapPool, map, MAP_PICKED);
		cupMap[MAP_ORDER]  = totalPoolMaps - availableMaps;
		cupMap[MAP_STATE_] = MAP_PICKED;
		cupMap[MAP_PICKER] = g_CupFormat[totalPoolMaps - availableMaps];
		TrieSetArray(g_CupMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap));
		availableMaps--;

		new playerName[32];
		GetColorlessName(id, playerName, charsmax(playerName));

		client_print(0, print_chat, "[%s] %s picked %s.", PLUGIN_TAG, playerName, cupMap[MAP_NAME]);

		new mapsToPick = availableMaps - 1; // minus the decider, that is autopicked
		if (mapsToPick > 0)
		{
			client_print(0, print_chat, "[%s] Remaining %d map%s to be picked, and then the decider is autopicked.",
				PLUGIN_TAG, mapsToPick, mapsToPick == 1 ? "" : "s");
		}

		server_print("ActionMapPickMenu :: availableMaps=%d, g_BestOfN=%d", availableMaps, g_BestOfN);
		if (availableMaps == 1)
		{
			new lastMap[MAX_MAPNAME_LENGTH];
			GetLastCupMapAvailable(lastMap, charsmax(lastMap));
			TrieGetArray(g_CupMapPool, lastMap, cupMap, sizeof(cupMap));

			// The decider is the last map that's left, no more menus, this is chosen automatically
			//TrieSetCell(g_CupMapPool, map, MAP_DECIDER);
			cupMap[MAP_ORDER]  = totalPoolMaps - availableMaps;
			cupMap[MAP_STATE_] = MAP_DECIDER;
			cupMap[MAP_PICKER] = g_CupFormat[totalPoolMaps - availableMaps];
			TrieSetArray(g_CupMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap));

			client_print(0, print_chat, "[%s] %s will be the decider.", PLUGIN_TAG, cupMap[MAP_NAME]);

			// Map states during bans/picks only get saved here
			// If the server crashes or there's a map change in the middle of the
			// bans/picks, then all that info will be lost and kz_cup should be issued again
			WriteCupMapPoolFile(0);

			// Now we're gonna change (or not) the map to start playing
			new mapName[MAX_MAPNAME_LENGTH];
			GetNextCupMapToPlay(mapName, charsmax(mapName));

			if (equal(mapName, g_Map))
			{
				// We're gonna play in this very map, so no changelevel needed
				client_print(0, print_chat, "[%s] The next map to be played is %s.", PLUGIN_TAG, mapName);
				client_print(0, print_chat, "[%s] We're already in that map, so just waiting for participants to get /ready to start ;)", PLUGIN_TAG);
			}
			else
			{
				new Float:timeToChange = get_pcvar_float(pcvar_kz_cup_map_change_delay);
				client_print(0, print_chat, "[%s] The next map to be played is %s. Changing the map in %.0f seconds...", PLUGIN_TAG, mapName, timeToChange);

				set_task(timeToChange, "CupChangeMap", TASKID_CUP_CHANGE_MAP, mapName, charsmax(cupMap[MAP_NAME]));
			}
		}
		else
		{
			// Continue picking
			new nextPicker = GetNextPicker();
			server_print("showing map pick menu to player #%d", nextPicker);
			CreateMapMenu(nextPicker, MAP_PICK_MENU_ID);
		}
		CmdMapsShowHandler(0);
	}
	else
	{
		client_print(id, print_chat, "[%s] Please, pick a map that's not already banned/picked.", PLUGIN_TAG);
		CreateMapMenu(id, MAP_PICK_MENU_ID, true);
	}

	return PLUGIN_HANDLED;
}

Array:GetOrderedMapPool()
{
	new Array:result = ArrayCreate(CUP_MAP, TrieGetSize(g_CupMapPool));

	new clean[CUP_MAP];
	// Fill the map list with empty entries
	for (new i = 0; i < TrieGetSize(g_CupMapPool); i++)
		ArrayPushArray(result, clean, sizeof(clean));

	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
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
	new totalPoolMaps = TrieGetSize(g_CupMapPool);
	new availableMaps = CountCupMaps(MAP_IDLE);

	server_print("GetNextPicker() :: totalPoolMaps = %d, availableMaps = %d", totalPoolMaps, availableMaps);

	new i = totalPoolMaps - availableMaps;
	while (g_CupFormat[i])
	{
		new MATCH_FORMAT:format = g_CupFormat[i];

		server_print("GetNextPicker() :: char #%d = %d", i, format);

		if (format == MATCH_PLAYER1)
		{
			return g_CupPlayer1;
		}
		else if (format == MATCH_PLAYER2)
		{
			return g_CupPlayer2;
		}
		else
		{
			server_print("GetNextPicker() :: char #%d is decider, probably shouldn't have reached this point", i);
		}

		i++;
	}

	return 0;
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
		case 6: return DisplayKzMenu(id, 6);
		case 7: CmdSpec(id);
		case 8: CmdHelp(id);
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
		case 7: CmdStartNoReset(id);
		case 8: CmdVoteRace(id);
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
		case 4: ShowTopNoReset(id);
		}
	case 6:
		switch (key)
		{
		case 1: ShowTopClimbersPbLaps(id, PURE);
		case 2: ShowTopClimbersPbLaps(id, PRO);
		case 3: ShowTopClimbersPbLaps(id, NOOB);
		// TODO: case 4: ShowTopNoResetPbLaps(id);
		case 4: ShowTopClimbersGoldLaps(id, PURE);
		case 5: ShowTopClimbersGoldLaps(id, PRO);
		case 6: ShowTopClimbersGoldLaps(id, NOOB);
		// TODO: case 8: ShowTopNoResetGoldLaps(id);
		}
	}

	DisplayKzMenu(id, g_KzMenuOption[id]);
	return PLUGIN_HANDLED;
}

public ShowCupReplayMenu(id)
{
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;

	DestroyMenus(id);

	// TODO: sort replays by date descending
	new Array:cupReplays = GetCupReplays();
	ArraySortEx(cupReplays, "SortReplaysByDateDescending");

	new totalCupReplays = ArraySize(cupReplays);

	new menuHeader[32];
	formatex(menuHeader, charsmax(menuHeader), "Cup replays - Total: %d", totalCupReplays);
	new menu = menu_create(menuHeader, "HandleCupReplaysMenu");

	new cupReplay[CUP_REPLAY_ITEM];
	for (new i = 0; i < totalCupReplays; i++)
	{
		ArrayGetArray(cupReplays, i, cupReplay);

		new itemText[64];
		formatex(itemText, charsmax(itemText), "%s @ %s", cupReplay[CUP_REPLAY_ITEM_ID], cupReplay[CUP_REPLAY_ITEM_DATE]);
		menu_additem(menu, itemText, cupReplay);
	}

	menu_setprop(menu, MPROP_NOCOLORS, false);
	menu_setprop(menu, MPROP_EXIT,     MEXIT_FORCE);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public SortReplaysByDateDescending(Array: array, elem1[], elem2[], const data[], data_size)
{
	if (elem1[CUP_REPLAY_ITEM_TIMESTAMP] < elem2[CUP_REPLAY_ITEM_TIMESTAMP])
		return 1;

	else if (elem1[CUP_REPLAY_ITEM_TIMESTAMP] > elem2[CUP_REPLAY_ITEM_TIMESTAMP])
		return -1;

	else
		return 0;
}

Array:GetCupReplays()
{
	new Array:result = ArrayCreate(CUP_REPLAY_ITEM);

	new fileName[128];
	new dirHandle = open_dir(g_ReplaysDir, fileName, charsmax(fileName));

	if (!dirHandle)
		return result;

	while (next_file(dirHandle, fileName, charsmax(fileName)))
	{
		// We only want the ones starting with "cup"
		if (!equal(fileName, "cup", 3))
			continue;

		new cupReplayItem[CUP_REPLAY_ITEM];
		copy(cupReplayItem[CUP_REPLAY_ITEM_FILENAME], charsmax(cupReplayItem[CUP_REPLAY_ITEM_FILENAME]), fileName);

		// Remove the last ".dat" part
		new nameLen = strlen(fileName);
		fileName[nameLen - 4] = EOS;

		// Remove the first "cup_" part too
		new replayName[128];
		formatex(replayName, charsmax(replayName), "%s", fileName[4]);

		// We only want the ones corresponding to the current map
		new mapNameLen = strlen(g_Map);
		if (!equal(replayName, g_Map, mapNameLen))
			continue;

		// And remove the map part from the name, together with the "_" separator
		new cutReplayName[128];
		formatex(cutReplayName, charsmax(cutReplayName), "%s", replayName[mapNameLen + 1]);

		server_print("cup replay name: %s", cutReplayName);

		// Parse the name format, separated by "_": g_ReplaysDir, g_Map, idNumbers, topType, timestamp
		// e.g.: 0_0_71125161_pure_1600000000
		new Array:nameParts = ArrayCreate(64, 5);

		new buffer[33];
		new isSplit = strtok2(cutReplayName, buffer, charsmax(buffer), cutReplayName, charsmax(cutReplayName), '_', 1); // trim just in case
		while (isSplit > -1)
		{
			ArrayPushString(nameParts, buffer);

			buffer[0] = EOS; // clear the string just in case
			isSplit = strtok2(cutReplayName, buffer, charsmax(buffer), cutReplayName, charsmax(cutReplayName), '_', 1);
		}
		ArrayPushString(nameParts, buffer); // push the last one

		// TODO: get the player name too somehow
		new steamIDFirstDigit[2], steamIDSecondDigit[2], steamIDRest[32], top[32], timestamp[32];
		new steamID[32];

		new partsCount = ArraySize(nameParts);
		if (partsCount == 5)
		{
			// Case: normal Steam ID x:y:zzzzzzzz
			ArrayGetString(nameParts, 0, steamIDFirstDigit, charsmax(steamIDFirstDigit));
			ArrayGetString(nameParts, 1, steamIDSecondDigit, charsmax(steamIDSecondDigit));
			ArrayGetString(nameParts, 2, steamIDRest, charsmax(steamIDRest));
			ArrayGetString(nameParts, 3, top, charsmax(top));
			ArrayGetString(nameParts, 4, timestamp, charsmax(timestamp));

			formatex(steamID, charsmax(steamID), "STEAM_%s:%s:%s", steamIDFirstDigit, steamIDSecondDigit, steamIDRest);
		}
		else if (partsCount > 2)
		{
			// Case: Steam ID LAN shows as something weird like "I___AN" in the filename
			for (new i; i < (partsCount - 2); i++)
			{
				new idPart[32];
				ArrayGetString(nameParts, i, idPart, charsmax(idPart));

				format(steamID, charsmax(steamID), "%s_%s", steamID, idPart);
			}
			ArrayGetString(nameParts, partsCount - 2, top, charsmax(top));
			ArrayGetString(nameParts, partsCount - 1, timestamp, charsmax(timestamp));
		}
		else
		{
			// Unhandled ID
			copy(steamID, charsmax(steamID), "Unknown");
		}
		copy(cupReplayItem[CUP_REPLAY_ITEM_ID], charsmax(cupReplayItem[CUP_REPLAY_ITEM_ID]), steamID);

		copy(cupReplayItem[CUP_REPLAY_ITEM_TOP], charsmax(cupReplayItem[CUP_REPLAY_ITEM_ID]), top);

		new date[64];
		new timestampNumber = str_to_num(timestamp);
		if (timestampNumber < (250 * 15 * 60))
		{
			// The name format is old, it's the number of frames instead of the timestamp
			copy(date, charsmax(date), "Unknown old date");
		}
		else
		{
			format_time(date, charsmax(date), "%d %B %Y %H:%M:%S", timestampNumber);
		}
		copy(cupReplayItem[CUP_REPLAY_ITEM_DATE], charsmax(cupReplayItem[CUP_REPLAY_ITEM_DATE]), date);
		cupReplayItem[CUP_REPLAY_ITEM_TIMESTAMP] = timestampNumber;

		ArrayPushArray(result, cupReplayItem);
	}

	return result;
}

public HandleCupReplaysMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new cupReplay[CUP_REPLAY_ITEM];
	menu_item_getinfo(menu, item, _, cupReplay, sizeof(cupReplay));
	if (!cupReplay[CUP_REPLAY_ITEM_FILENAME][0])
	{
		ShowCupReplayMenu(id);
		return PLUGIN_HANDLED;
	}

	new replayFilePath[256];
	formatex(replayFilePath, charsmax(replayFilePath), "%s/%s", g_ReplaysDir, cupReplay[CUP_REPLAY_ITEM_FILENAME]);
	RunReplayFile(id, replayFilePath);

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

	InitPlayerSettings(id);

	g_ConsolePrintNextFrames[id] = 0;
	g_ReplayFpsMultiplier[id] = 1;

	g_IsInNoclip[id] = false;

	g_RaceId[id] = 0;
	g_RunModeStarting[id] = MODE_NORMAL;
	g_RunStartTime[id] = 0.0;
	g_RunNextCountdown[id] = 0.0;

	if (!g_FulfilledRunReqs[id])
		g_FulfilledRunReqs[id] = TrieCreate();
	
	g_SplitTimes[id] = ArrayCreate(1, 3);
	g_LapTimes[id] = ArrayCreate();
	g_CurrentLap[id] = 0;

	g_IsKzVoteRunning[id] = false;
	g_KzVoteSetting[id][0] = EOS;
	g_KzVoteValue[id] = KZVOTE_NO;
	g_KzVoteStartTime[id] = 0.0;
	g_KzVoteCaller[id] = 0;

	g_RunAvgSpeed[id] = 0.0;
	g_RunMaxSpeed[id] = 0.0;
	g_RunCurrSpeed[id] = 0.0;
	g_RunAvgFps[id] = 0.0;
	g_RunMinFps[id] = 0.0;
	g_RunDistance2D[id] = 0.0;
	g_RunDistance3D[id] = 0.0;
	g_RunJumps[id] = 0;
	g_RunDucktaps[id] = 0;
	g_RunStrafes[id] = 0;
	g_RunSync[id] = 0;
	g_RunSlowdowns[id] = 0;
	g_RunSlowdownLastFrameChecked[id] = 0;
	g_RunLostStartTime[id] = 0.0;
	g_RunLostEndTime[id] = 0.0;
	g_RunStartPrestrafeSpeed[id] = 0.0;
	g_RunStartPrestrafeTime[id] = 0.0;

	g_RunStatsEndHudStartTime[id] = -RUN_STATS_HUD_MAX_HOLD_TIME;
	g_RunStatsEndHudShown[id] = false;

	g_ControlPoints[id][CP_TYPE_DEFAULT_START] = g_MapDefaultStart;

	g_ReplayFrames[id] = ArrayCreate(REPLAY);

	g_DamagedByEntity[id] = ArrayCreate();
	g_DamagedTimeEntity[id] = ArrayCreate();
	g_DamagedPreSpeed[id] = ArrayCreate();

	// Link this player to the cup player
	new uniqueId[32];
	GetUserUniqueId(id, uniqueId, charsmax(uniqueId));
	copy(g_UniqueId[id], charsmax(g_UniqueId[]), uniqueId);

	if (equal(g_CupSteam1, uniqueId))
		g_CupPlayer1 = id;

	if (equal(g_CupSteam2, uniqueId))
		g_CupPlayer2 = id;

	if (get_pcvar_num(pcvar_kz_mysql) && !IsBot(id))
		SelectPlayerId(uniqueId, charsmax(uniqueId));

	LoadPlayerSettings(id);

	set_task(1.20, "DisplayWelcomeMessage", id + TASKID_WELCOME);
}

public client_disconnect(id)
{
	SavePlayerSettings(id);

	clr_bit(g_bit_is_connected, id);
	clr_bit(g_bit_is_hltv, id);
	clr_bit(g_bit_invis, id);
	clr_bit(g_bit_waterinvis, id);
	clr_bit(g_baIsFirstSpawn, id);
	clr_bit(g_baIsPureRunning, id);

	g_SolidState[id] = -1;
	g_IsBannedFromMatch[id] = false;
	g_PlayerRunReqs[id] = 0;

	g_IsValidStart[id] = false;
	g_IsInNoclip[id] = false;

	g_RaceId[id] = 0;
	g_RunMode[id] = MODE_NORMAL;
	g_RunModeStarting[id] = MODE_NORMAL;
	g_RunStartTime[id] = 0.0;
	g_RunNextCountdown[id] = 0.0;
	g_RunCountdown[id] = get_pcvar_float(pcvar_kz_noreset_countdown);

	g_IsKzVoteRunning[id] = false;
	g_KzVoteSetting[id][0] = EOS;
	g_KzVoteValue[id] = KZVOTE_NO;
	g_KzVoteStartTime[id] = 0.0;
	g_KzVoteCaller[id] = 0;

	g_RunAvgSpeed[id] = 0.0;
	g_RunMaxSpeed[id] = 0.0;
	g_RunCurrSpeed[id] = 0.0;
	g_RunAvgFps[id] = 0.0;
	g_RunMinFps[id] = 0.0;
	g_RunDistance2D[id] = 0.0;
	g_RunDistance3D[id] = 0.0;
	g_RunJumps[id] = 0;
	g_RunDucktaps[id] = 0;
	g_RunStrafes[id] = 0;
	g_RunSync[id] = 0;
	g_RunSlowdowns[id] = 0;
	g_RunSlowdownLastFrameChecked[id] = 0;
	g_RunLostStartTime[id] = 0.0;
	g_RunLostEndTime[id] = 0.0;
	g_RunStartPrestrafeSpeed[id] = 0.0;
	g_RunStartPrestrafeTime[id] = 0.0;

	g_RunStatsEndHudStartTime[id] = -RUN_STATS_HUD_MAX_HOLD_TIME;
	g_RunStatsEndHudShown[id] = false;

	ArrayClear(g_SplitTimes[id]);
	ArrayClear(g_LapTimes[id]);
	g_CurrentLap[id] = 0;

	if (!IsBot(id) && g_IsUsingSplits[id])
	{
		ArrayClear(Array:g_GoldLaps[id][PURE]);
		ArrayClear(Array:g_GoldLaps[id][PRO]);
		ArrayClear(Array:g_GoldLaps[id][NOOB]);

		ArrayClear(Array:g_GoldSplits[id][PURE]);
		ArrayClear(Array:g_GoldSplits[id][PRO]);
		ArrayClear(Array:g_GoldSplits[id][NOOB]);

		ArrayClear(Array:g_PbLaps[id][PURE]);
		ArrayClear(Array:g_PbLaps[id][PRO]);
		ArrayClear(Array:g_PbLaps[id][NOOB]);

		ArrayClear(Array:g_PbSplits[id][PURE]);
		ArrayClear(Array:g_PbSplits[id][PRO]);
		ArrayClear(Array:g_PbSplits[id][NOOB]);

		g_IsUsingSplits[id] = false;

		// TODO clear No-Reset gold laps too when they're implemented
	}

	if (g_RecordRun[id])
	{
		if (IsCupPlayer(id) && g_bMatchRunning)
		{
			// A participant might ragequit or get disconnected due to lag or something
			// before finishing the run, so we save their demo to the point where they disconnected
			SaveRecordedRunCup(id, NOOB);
		}
		else
		{
			//console_print(id, "clearing recorded run with %d frames from memory", ArraySize(g_RunFrames[id]));
			g_RecordRun[id] = 0;
			ArrayClear(g_RunFrames[id]);
		}
	}
	ArrayClear(g_ReplayFrames[id]);
	g_ReplayFramesIdx[id] = 0;

	g_RunFrameCount[id] = 0;

	ArrayClear(g_DamagedByEntity[id]);
	ArrayClear(g_DamagedTimeEntity[id]);
	ArrayClear(g_DamagedPreSpeed[id]);

	g_UniqueId[id][0] = EOS;

	// Clear and reset other things
	ResetPlayer(id, true, false);

	g_ControlPoints[id][CP_TYPE_START][CP_VALID] = false;

	clr_bit(g_bit_is_bot, id);

	// This player is gone, so reset settings to defaults
	InitPlayerSettings(id);

	// Cancel tasks that might be running and could potentially affect another player
	// that joins immediately after and takes this leaving player's id
	remove_task(id + TASKID_WELCOME);
	remove_task(id + TASKID_POST_WELCOME);
	remove_task(id + TASKID_RELOAD_PLAYER_SETTINGS);
	remove_task(id + TASKID_ICON);
	remove_task(id + TASKID_INIT_PLAYER_GOLDS);
}

InitPlayerSettings(id)
{
	g_ShowTimer[id]    = get_pcvar_num(pcvar_kz_show_timer);
	g_ShowKeys[id]     = get_pcvar_num(pcvar_kz_show_keys);
	g_ShowStartMsg[id] = get_pcvar_num(pcvar_kz_show_start_msg);
	// FIXME: get default value from client, and then fall back to server if client doesn't have the command set
	g_TimeDecimals[id] = get_pcvar_num(pcvar_kz_time_decimals) ? get_pcvar_num(pcvar_kz_time_decimals) : DEFAULT_TIME_DECIMALS;
	g_Nightvision[id]  = get_pcvar_num(pcvar_kz_nightvision);
	g_Slopefix[id]     = false;

	// Nightvision value 1 in server cvar is "all modes allowed", if that's the case we default it to mode 2 in client,
	// every other mode in cvar is +1 than client command, so we do -1 to get the correct mode
	if (g_Nightvision[id] > 1)
		g_Nightvision[id]--;
	else if (g_Nightvision[id] == 1)
		g_Nightvision[id] = 2;

	g_Speedcap[id] = get_pcvar_float(pcvar_kz_speedcap);
	g_Prespeedcap[id] = 1;

	g_NoclipTargetSpeed[id] = DEFAULT_HLKZ_NOCLIP_SPEED;

	g_ShowSpeed[id]                  = false;
	g_ShowDistance[id]               = false;
	g_ShowHeightDiff[id]             = false;
	g_ShowSpecList[id]               = true;
	g_TpOnCountdown[id]              = true;
	g_ShowRunStatsOnConsole[id]      = true;
	g_ShowRunStatsOnHud[id]          = 0;
	g_RunStatsHudHoldTime[id]        = RUN_STATS_HUD_HOLD_TIME_AT_END;
	g_RunStatsHudX[id]               = RUN_STATS_HUD_X;
	g_RunStatsHudY[id]               = RUN_STATS_HUD_Y;
	g_RunStatsHudDetailLevel[id]     = 1;
	g_RunStatsConsoleDetailLevel[id] = 2;

	g_RunMode[id]          = MODE_NORMAL;
	g_RunCountdown[id]     = get_pcvar_float(pcvar_kz_noreset_countdown);

	g_IsKzVoteVisible[id]  = true;
	g_IsKzVoteIgnoring[id] = false;
	g_KzVoteAlignment[id]  = POSITION_RIGHT;

	// Set up hud color
	new rgb[12], r[4], g[4], b[4];
	get_pcvar_string(pcvar_kz_hud_rgb, rgb, charsmax(rgb));
	parse(rgb, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	g_HudRGB[id][0] = str_to_num(r);
	g_HudRGB[id][1] = str_to_num(g);
	g_HudRGB[id][2] = str_to_num(b);
}

public ReloadPlayerSettings(taskId)
{
	new id = taskId - TASKID_RELOAD_PLAYER_SETTINGS;

	if (!pev_valid(id) || !IsPlayer(id))
		return;

	LoadPlayerSettings(id);

	if (areColorsZeroed(id))
	{
		// Still failing to load settings? Then the settings file is already corrupted...
		// At this point we do some damage control, at least we're gonna set default values
		InitPlayerSettings(id);
	}
}

// This might lag out the server if it's using HDD or some slow storage
// TODO: Try to do it non-blocking like the SQL queries, probably needs a new module
LoadPlayerSettings(id)
{
	static authid[32], idNumbers[24], playerFileName[56];
	get_user_authid(id, authid, charsmax(authid));
	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(playerFileName, charsmax(playerFileName), "%s/players/%s.ini", CONFIGS_SUB_DIR, idNumbers);

	// We build another path because the one we previously built is what amx_settings_api exclusively understands...
	// and we need to check if the file exists, which doesn't work with the path for amx_settings_api
	new fullPlayerMapIniFile[256];
	formatex(fullPlayerMapIniFile, charsmax(fullPlayerMapIniFile), "%s/%s.ini", g_PlayersDir, g_Map);
	if (file_exists(fullPlayerMapIniFile))
	{
		// Map-dependent player settings
		amx_load_setting_int(g_PlayerMapIniFile, idNumbers, "no_reset", _:g_RunMode[id]);
		if (g_RunMode[id] == MODE_NORESET)
		{
			new Float:kztime, isPure, isFirstSpawn, isPaused;

			amx_load_setting_int(  g_PlayerMapIniFile, idNumbers, "run_type",    isPure);
			amx_load_setting_float(g_PlayerMapIniFile, idNumbers, "run_time",    kztime);
			amx_load_setting_int(  g_PlayerMapIniFile, idNumbers, "first_spawn", isFirstSpawn);
			amx_load_setting_int(  g_PlayerMapIniFile, idNumbers, "paused",      isPaused);

			//console_print(0, "loading kztime: %.3f", kztime);

			g_PlayerTime[id] = get_gametime() - kztime;

			if (isPure)			set_bit(g_baIsPureRunning, id);
			if (isFirstSpawn)	set_bit(g_baIsFirstSpawn, id);
			if (isPaused)		set_bit(g_baIsPaused, id);

			// If we're in no-reset mode, it means the run was ongoing, so set this right away
			set_bit(g_baIsClimbing, id);
		}
	}

	new fullPlayerFileName[256];
	formatex(fullPlayerFileName, charsmax(fullPlayerFileName), "%s/%s.ini", g_PlayersDir, idNumbers);
	if (!file_exists(fullPlayerFileName))
		return;

	// Global player settings
	new hasLiquidsInvis, hasPlayersInvis;

	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_timer",              g_ShowTimer[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_keys",               g_ShowKeys[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_start_msg",          g_ShowStartMsg[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_speed",              g_ShowSpeed[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_distance",           g_ShowDistance[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_height_diff",        g_ShowHeightDiff[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "time_decimals",           g_TimeDecimals[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "show_spec_list",          g_ShowSpecList[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_con",           g_ShowRunStatsOnConsole[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_hud",           g_ShowRunStatsOnHud[id]);
	amx_load_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_hold_time", g_RunStatsHudHoldTime[id]);
	amx_load_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_x",         g_RunStatsHudX[id]);
	amx_load_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_y",         g_RunStatsHudY[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_hud_details",   g_RunStatsHudDetailLevel[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_con_details",   g_RunStatsConsoleDetailLevel[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_r",             g_HudRGB[id][0]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_g",             g_HudRGB[id][1]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_b",             g_HudRGB[id][2]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_visible",         g_IsKzVoteVisible[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_ignore",          g_IsKzVoteIgnoring[id]);
	amx_load_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_align",           _:g_KzVoteAlignment[id]);

	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "invis_liquids",      hasLiquidsInvis);
	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "invis_players",      hasPlayersInvis);
	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "nightvision",        g_Nightvision[id]);
	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "slopefix",           g_Slopefix[id]);
	amx_load_setting_float(playerFileName, GAMEPLAY_SETTINGS, "speedcap",           g_Speedcap[id]);
	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "prespeedcap",        g_Prespeedcap[id]);
	amx_load_setting_float(playerFileName, GAMEPLAY_SETTINGS, "run_countdown",      g_RunCountdown[id]);
	amx_load_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "tp_on_countdown",    g_TpOnCountdown[id]);
	amx_load_setting_float(playerFileName, GAMEPLAY_SETTINGS, "noclip_speed",       g_NoclipTargetSpeed[id]);

	// TODO: load run stats, in case we're in a NR run and come back later to finish it


	if (hasLiquidsInvis) set_bit(g_bit_waterinvis, id);
	if (hasPlayersInvis) set_bit(g_bit_invis, id);
}

SavePlayerSettings(id)
{
	static authid[32], idNumbers[24], playerFileName[56];
	get_user_authid(id, authid, charsmax(authid));
	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(playerFileName, charsmax(playerFileName), "%s/players/%s.ini", CONFIGS_SUB_DIR, idNumbers);

	// Map-dependent player settings
	if (g_RunMode[id] == MODE_NORESET)
	{
		new Float:kztime = get_gametime() - g_PlayerTime[id];
		console_print(0, "saving kztime: %.3f", kztime);


		// TODO: also save position and velocity?
		amx_save_setting_int(  g_PlayerMapIniFile, idNumbers, "no_reset",    _:g_RunMode[id]);
		amx_save_setting_int(  g_PlayerMapIniFile, idNumbers, "run_type",    get_bit(g_baIsPureRunning, id));
		amx_save_setting_float(g_PlayerMapIniFile, idNumbers, "run_time",    kztime);
		amx_save_setting_int(  g_PlayerMapIniFile, idNumbers, "first_spawn", get_bit(g_baIsFirstSpawn, id));
		amx_save_setting_int(  g_PlayerMapIniFile, idNumbers, "paused",      get_bit(g_baIsPaused, id));
	}
	else
	{
		amx_save_setting_int(  g_PlayerMapIniFile, idNumbers, "no_reset",    _:MODE_NORMAL);
	}

	// Global player settings
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_timer",              g_ShowTimer[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_keys",               g_ShowKeys[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_start_msg",          g_ShowStartMsg[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_speed",              g_ShowSpeed[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_distance",           g_ShowDistance[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_height_diff",        g_ShowHeightDiff[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "time_decimals",           g_TimeDecimals[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "show_spec_list",          g_ShowSpecList[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_con",           g_ShowRunStatsOnConsole[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_hud",           g_ShowRunStatsOnHud[id]);
	amx_save_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_hold_time", g_RunStatsHudHoldTime[id]);
	amx_save_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_x",         g_RunStatsHudX[id]);
	amx_save_setting_float(playerFileName, HUD_SETTINGS, "run_stats_hud_y",         g_RunStatsHudY[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_hud_details",   g_RunStatsHudDetailLevel[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "run_stats_con_details",   g_RunStatsConsoleDetailLevel[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_r",             g_HudRGB[id][0]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_g",             g_HudRGB[id][1]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "hud_color_b",             g_HudRGB[id][2]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_visible",         g_IsKzVoteVisible[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_ignore",          g_IsKzVoteIgnoring[id]);
	amx_save_setting_int(  playerFileName, HUD_SETTINGS, "kz_vote_align",           _:g_KzVoteAlignment[id]);

	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "invis_liquids",      get_bit(g_bit_waterinvis, id));
	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "invis_players",      get_bit(g_bit_invis, id));
	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "nightvision",        g_Nightvision[id]);
	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "slopefix",           g_Slopefix[id]);
	amx_save_setting_float(playerFileName, GAMEPLAY_SETTINGS, "speedcap",           g_Speedcap[id]);
	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "prespeedcap",        g_Prespeedcap[id]);
	amx_save_setting_float(playerFileName, GAMEPLAY_SETTINGS, "run_countdown",      g_RunCountdown[id]);
	amx_save_setting_int(  playerFileName, GAMEPLAY_SETTINGS, "tp_on_countdown",    g_TpOnCountdown[id]);
	amx_save_setting_float(playerFileName, GAMEPLAY_SETTINGS, "noclip_speed",       g_NoclipTargetSpeed[id]);

	// TODO: save run stats and position, in case we're in a NR run and come back later to finish it
}

ResetPlayer(id, bool:onDisconnect = false, bool:onlyTimer = false)
{
	// Unpause
	UnfreezePlayer(id);

	InitPlayer(id, onDisconnect, onlyTimer);

	if (!onDisconnect)
	{
		if (onlyTimer)
			ShowMessage(id, "Timer reset");
		else
			ShowMessage(id, "Timer and checkpoints reset");
	}
}

InitPlayer(id, bool:onDisconnectOrAgstart = false, bool:onlyTimer = false)
{
	new i;

	// Reset timer
	clr_bit(g_baIsClimbing, id);
	clr_bit(g_baIsAgFrozen, id);
	clr_bit(g_baIsPaused, id);
	clr_bit(g_baIsPureRunning, id);

	g_RunMode[id] = MODE_NORMAL;

	g_RunStartTimestamp[id] = 0;
	g_PlayerTime[id] = 0.0;
	g_PlayerTimePause[id] = 0.0;
	g_PlayerRunReqs[id] = 0;
	TrieClear(g_FulfilledRunReqs[id]);
	// Init the trie with all entity requirements to false
	new TrieIter:ti = TrieIterCreate(g_RunReqs);
	while (!TrieIterEnded(ti))
	{
		new entId[6];
		TrieIterGetKey(ti, entId, charsmax(entId));

		TrieSetCell(g_FulfilledRunReqs[id], entId, false);

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	ArrayClear(g_SplitTimes[id]);
	ArrayClear(g_LapTimes[id]);
	g_CurrentLap[id] = 0;

	g_RunFrameCount[id] = 0;

	if (!onDisconnectOrAgstart)
	{
		// Clear the timer hud
		client_print(id, print_center, "");
		ClearSyncHud(id, g_SyncHudTimer);
		if (g_ShowRunStatsOnHud[id] >= 2)
		{
			ClearSyncHud(id, g_SyncHudRunStats);
		}

		// Clear the timer hud for spectating spectators
		for (i = 1; i <= g_MaxPlayers; i++)
		{
			if (pev(i, pev_iuser1) == OBS_IN_EYE && pev(i, pev_iuser2) == id)
			{
				client_print(i, print_center, "");
				ClearSyncHud(i, g_SyncHudTimer);

				if (g_ShowRunStatsOnHud[i] >= 2)
				{
					ClearSyncHud(id, g_SyncHudRunStats);
				}
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
	{
		if (i == CP_TYPE_PRACTICE || i == CP_TYPE_PRACTICE_OLD)
		{
			// TODO: test if we can safely do the same with CP_TYPE_CURRENT and CP_TYPE_OLD
			continue;
		}

		g_ControlPoints[id][i][CP_VALID] = false;
	}

	// Reset counters
	for (i = 0; i < COUNTERS; i++)
		g_CpCounters[id][i] = 0;
}

InitPlayerVariables(id)
{
	g_RunAvgSpeed[id] = 0.0;
	g_RunMaxSpeed[id] = 0.0;
	g_RunCurrSpeed[id] = 0.0;
	g_RunAvgFps[id] = 0.0;
	g_RunMinFps[id] = 0.0;
	g_RunDistance2D[id] = 0.0;
	g_RunDistance3D[id] = 0.0;
	g_RunJumps[id] = 0;
	g_RunDucktaps[id] = 0;
	g_RunStrafes[id] = 0;
	g_RunSync[id] = 0;
	g_RunSlowdowns[id] = 0;
	g_RunSlowdownLastFrameChecked[id] = 0;
	g_RunLostStartTime[id] = 0.0;
	g_RunLostEndTime[id] = 0.0;
	g_RunStartPrestrafeSpeed[id] = 0.0;
	g_RunStartPrestrafeTime[id] = 0.0;

	if (g_ShowRunStatsOnHud[id] >= 2)
	{
		// Reset these so that the end HUD disappears before the hold time is over and you can continue
		// seeing realtime stats upon doing /start
		// FIXME: this behaviour is not good for spectators, as their settings dont come into play here
		g_RunStatsEndHudStartTime[id] = -RUN_STATS_HUD_MAX_HOLD_TIME;
		g_RunStatsEndHudShown[id] = false;
	}
}

public DisplayWelcomeMessage(id)
{
	id -= TASKID_WELCOME;

	if (!pev_valid(id) || !IsPlayer(id))
		return;

	client_print(id, print_chat, "[%s] Welcome to %s", PLUGIN_TAG, PLUGIN);
	client_print(id, print_chat, "[%s] Visit sourceruns.org & www.aghl.ru", PLUGIN_TAG);
	client_print(id, print_chat, "[%s] You can say /kzhelp to see available commands", PLUGIN_TAG);

	if (!get_pcvar_num(pcvar_kz_checkpoints))
		client_print(id, print_chat, "[%s] Checkpoints are off", PLUGIN_TAG);

	if (get_pcvar_num(pcvar_kz_spawn_mainmenu))
		DisplayKzMenu(id, 0);

	new isInObserverMode = (pev(id, pev_flags) & FL_SPECTATOR) && pev(id, pev_iuser1) == OBS_NONE;
	if (isInObserverMode && g_DisableSpec && (g_bMatchStarting || g_bMatchRunning))
	{
		ExecuteHamB(Ham_Spawn, id);

		set_task(0.2, "PostWelcome", id + TASKID_POST_WELCOME);
	}
}

public PostWelcome(id)
{
	id -= TASKID_POST_WELCOME;

	if (!pev_valid(id) || !IsPlayer(id))
		return;

	//server_cmd("agforcespectator #%d", get_user_userid(id));

	if (g_CupPlayer1 || g_CupPlayer2)
		set_pev(id, pev_iuser1, OBS_IN_EYE);
	else
		set_pev(id, pev_iuser1, OBS_ROAMING);

	if (g_CupPlayer1)
		set_pev(id, pev_iuser2, g_CupPlayer1);
	else if (g_CupPlayer2)
		set_pev(id, pev_iuser2, g_CupPlayer2);

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

CmdNoclip(id)
 {
	g_IsInNoclip[id] = get_user_noclip(id);
	
	if (get_pcvar_num(pcvar_kz_noclip) == 0)
	{
		client_print(id, print_chat, "[%s] Noclip is not enabled on this server.", PLUGIN_TAG);
		return;
	}
	if (!IsAlive(id) || pev(id, pev_iuser1))
	{
		client_print(id, print_chat, "[%s] You must be alive to use this command.", PLUGIN_TAG);
		return;
	}
	
	if (g_IsInNoclip[id] == false)           // enter noclip
	{	
		if (g_RunMode[id] || g_RunModeStarting[id] != MODE_NORMAL)
		{
			client_print(id, print_chat, "[%s] No cheating in a race or a no-reset run!", PLUGIN_TAG);
			return;
		}
		CmdPracticeCp(id);                   // create a cp to return to when disabling noclip
		set_user_noclip(id, 1);              // turn on noclip
		HandleNoclipCheating(id);
		g_IsInNoclip[id] = true;
		ResetPlayer(id)
		client_print(id, print_chat, "[%s] Noclip enabled", PLUGIN_TAG);
		return;
	}
	else                                     // exit noclip
	{	
		set_user_noclip(id, 0);              // turn off noclip
		set_user_velocity(id, {0.0, 0.0, 0.0})  // just in case
		HandleNoclipCheating(id);
		g_IsInNoclip[id] = false;
		client_print(id, print_chat, "[%s] Noclip disabled", PLUGIN_TAG);
		ResetPlayer(id)
		CmdPracticeTp(id);                   // return to cp made when entering noclip
		return;
	}
}

CmdNoclipSpeed(id)
{
	new Float:allowedSpeed = get_pcvar_float(pcvar_kz_noclip_speed);
	new Float:desiredSpeed = GetFloatArg();

	if (allowedSpeed && desiredSpeed > allowedSpeed)
	{
		g_NoclipTargetSpeed[id] = allowedSpeed;
		ShowMessage(id, "Horizontal noclip max speed set to %.2f (max. allowed)", allowedSpeed);
	}
	else if (desiredSpeed <= 0.0)
	{
		g_NoclipTargetSpeed[id] = 0.0;
		ShowMessage(id, "Your horizontal noclip max speed is back to normal (%.2f?)", get_cvar_float("sv_maxspeed"));
	}
	else
	{
		g_NoclipTargetSpeed[id] = desiredSpeed;
		ShowMessage(id, "Your horizontal noclip max speed is now: %.2f", g_NoclipTargetSpeed[id]);
	}

 	return PLUGIN_HANDLED;
}

CmdPracticeCp(id)
{
	if (CanCreateCp(id, true, true))
		CreateCp(id, CP_TYPE_PRACTICE)
}

CmdPracticeTp(id)
{
	if (CanTeleport(id, CP_TYPE_PRACTICE))
	{
		ResetPlayer(id, false, true);
		Teleport(id, CP_TYPE_PRACTICE);
	}
}

CmdStuck(id)
{
	if (CanTeleport(id, CP_TYPE_OLD))
		Teleport(id, CP_TYPE_OLD);
}

CmdPracticePrev(id)
{
	if(CanTeleport(id, CP_TYPE_PRACTICE_OLD))
	{
		ResetPlayer(id, false, true)
		Teleport(id, CP_TYPE_PRACTICE_OLD);
	}
}

CmdStart(id)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		// This is because players might hit the /start bind accidentally during a race due to muscle memory
		// from normal runs, so we disable it but still make it possible to /start with /startnr
		// Also we allow them to do this because they may get stuck at some part and this is the way to unstuck
		ShowMessage(id, "You're in No-Reset mode! Say /startnr if you really want to go back to the start");
		return;
	}

	// Reset the start validation. It's set to true when going through the start zone
	g_IsValidStart[id] = false;

	if (CanTeleport(id, CP_TYPE_CUSTOM_START, false))
	{
		ResetPlayer(id, false, true);
		Teleport(id, CP_TYPE_CUSTOM_START);
		return;
	}

	new bool:isTeleported = false;
	// TODO: refactor
	if (CanTeleport(id, CP_TYPE_START))
	{
		Teleport(id, CP_TYPE_START);
		isTeleported = true;
	}
	else if (CanTeleport(id, CP_TYPE_DEFAULT_START))
	{
		Teleport(id, CP_TYPE_DEFAULT_START);
		isTeleported = true;
	}

	if (!isTeleported)
		return;

	ResetPlayer(id, false, true);
	StartClimb(id);

	// Not a custom start, so we know that it goes through the start zone or button, therefore it's valid
	g_IsValidStart[id] = true;
}

CmdStartNr(id)
{
	if (g_RunMode[id] == MODE_NORMAL)
	{
		// We're in a normal run, behave the same as "/start"
		CmdStart(id);
		return;
	}
	
	if (g_IsInNoclip[id])
	{
		client_print(id, print_chat, "[%s] Disable noclip to start a no-reset run.", PLUGIN_TAG);
		return;
	}

	if (g_RunLaps)
	{
		// This run has laps, so the player will probably be able to cheat by teleporting to the start
		// It might be their only way to unstuck during a No-Reset run, and we cannot reset the run as
		// it goes against the mode's rules. So we're just gonna add a minute to their timer
		g_PlayerTime[id] -= 60;
	}

	// Reset the start validation. It's set to true when going through the start zone
	g_IsValidStart[id] = false;

	// The teleport is enough, we're not gonna reset their timer
	if (CanTeleportNr(id, CP_TYPE_CUSTOM_START) && g_usesStartingZone)
		Teleport(id, CP_TYPE_CUSTOM_START);
	else if (CanTeleportNr(id, CP_TYPE_START))
		Teleport(id, CP_TYPE_START);
	else if (CanTeleportNr(id, CP_TYPE_DEFAULT_START))
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
	if (g_IsInNoclip[id]) //exit noclip, prevents the game saying you are cheating when exiting spec
	{
		CmdNoclip(id);
	}
	client_cmd(id, "spectate");	// CanSpectate is called inside of command hook handler
}

CmdInvis(id)
{
	if(get_bit(g_bit_invis, id))
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
	if (get_bit(g_bit_waterinvis, id))
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

	if (g_ShowTimer[id] < 2)
		ShowMessage(id, "Timer display position: %s", g_ShowTimer[id]++ < 1 ? "center" : "HUD");
	else
	{
		g_ShowTimer[id] = 0;
		ShowMessage(id, "Timer display: off");
	}
}

public CmdHudColor(id)
{
	new args[32];
	read_args(args, charsmax(args));
	remove_quotes(args);
	trim(args);

	new cmd[12], color1[8], color2[4], color3[4];
	new numR, numG, numB;

	parse(args, cmd, charsmax(cmd), color1, charsmax(color1), color2, charsmax(color2), color3, charsmax(color3));

	new wordColor[COLOR];
	if (TrieGetArray(g_ColorsList, color1, wordColor, sizeof(wordColor))) // color1 is the first argument containing color word
	{
		numR = wordColor[COLOR_RED];
		numG = wordColor[COLOR_GREEN];
		numB = wordColor[COLOR_BLUE];
	}
	else if (!color2[0] || !color3[0])
	{
		ShowMessage(id, "Invalid color. Usage examples: /hudcolor red ; /hudcolor 255 0 0");
		return;
	}
	else
	{
		numR = str_to_num(color1);
		numG = str_to_num(color2);
		numB = str_to_num(color3);

		if (numR > 255 || numR < 0)
			numR = 255;

		if (numG > 255 || numG < 0)
			numG = 255;

		if (numB > 255 || numB < 0)
			numB = 255;

		if (numR < 20 && numG < 20 && numB < 20) // (0,0,0) is invisible, prevent that.
		{
			numR = colorDefault[COLOR_RED];
			numG = colorDefault[COLOR_GREEN];
			numB = colorDefault[COLOR_BLUE];
			ShowMessage(id, "That color is barely visible! Setting default color");
		}
	}

	g_HudRGB[id][0] = numR;
	g_HudRGB[id][1] = numG;
	g_HudRGB[id][2] = numB;
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
	new maxReplays = get_pcvar_num(pcvar_kz_max_concurrent_replays);
	if (maxReplays <= 0)
	{
		client_print(id, print_chat, "[%s] Sorry, this server doesn't allow replaying records :(", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	static authid[32], replayFile[256], idNumbers[24], stats[STATS], time[32];
	new args[32], cmd[15], replayRank, replayArg[33], Regex:pattern;
	new minutes, Float:seconds;

	read_args(args, charsmax(args));
	remove_quotes(args);
	trim(args);
	parse(args, cmd, charsmax(cmd), replayArg, charsmax(replayArg));

	if (is_str_num(replayArg))
		replayRank = str_to_num(replayArg);
	else
		pattern = regex_compile_ex(fmt(".*%s.*", replayArg), PCRE_CASELESS);

	// TODO: the replaybot would have to spawn in the callback of the query,
	// so that the leaderboard is up to date and we leave no chance to have a replay of
	// a different record going on. Right now it works 99% of the time cos
	// leaderboards are updated right after a new PB is done and by the time we get here
	// leaderboards are already up to date
	LoadRecords(runType);
	new Array:arr = g_ArrayStats[runType];

	for (new i = 0; i < ArraySize(arr); i++)
	{
		ArrayGetArray(arr, i, stats);
		if ((replayRank && i == replayRank - 1) || (_:pattern == 1 && regex_match_c(stats[STATS_NAME], pattern) == 1))
		{
			stats[STATS_NAME][17] = EOS;
			formatex(authid, charsmax(authid), "%s", stats[STATS_ID]);
			break; // the desired record info is now stored in stats, so exit loop
		}
	}
	if (!replayRank)
		regex_free(pattern);

	new replayingMsg[96], replayFailedMsg[96], szTopType[32];
	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(szTopType, charsmax(szTopType), "%s", g_TopType[runType]);
	strtolower(szTopType);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, szTopType);
	//formatex(g_ReplayFile[id], charsmax(replayFile), "%s", replayFile);
	//console_print(id, "rank %d's idNumbers: '%s', replay file: '%s'", replayRank, idNumbers, replayFile);

	minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
	seconds = stats[STATS_TIME] - (60 * minutes);

	formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%0"), minutes, seconds);
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

	if (file)
		fclose(file);

	// TODO: refactor these replayingMsg params
	RunReplayFile(id, replayFile, replayingMsg, charsmax(replayingMsg));

	return PLUGIN_HANDLED;
}

RunReplayFile(id, replayFileName[], replayingMsg[] = "", lenMsg = 0)
{
	new file = fopen(replayFileName, "rb");
	if (!file)
	{
		client_print(id, print_chat, "[%s] Sorry, that replay is not available.", PLUGIN_TAG);
		server_print("[%s] Replay not found: %s.", PLUGIN_TAG, replayFileName);
		return;
	}
	new Float:setupTime = get_pcvar_float(pcvar_kz_replay_setup_time);
	new bool:canceled = false;

	if (g_ReplayFramesIdx[id])
	{
		new bot = GetOwnersBot(id);
		//console_print(1, "CmdReplay :: removing bot %d", bot);
		FinishReplay(id);
		KickReplayBot(bot + TASKID_KICK_REPLAYBOT);
		canceled = true;
	}

	if (g_ReplayNum >= get_pcvar_num(pcvar_kz_max_concurrent_replays))
	{
		client_print(id, print_chat, "[%s] Sorry, there are too many replays running! Please, wait until one of the %d replays finish", PLUGIN_TAG, g_ReplayNum);
		fclose(file);
		return;
	}
	else if (GetOwnersBot(id))
	{
		client_print(id, print_chat, "[%s] Your previous bot is still setting up. Please, wait %.1f seconds to start a new replay", PLUGIN_TAG, setupTime);
		fclose(file);
		return;
	}

	if (canceled)
		client_print(id, print_chat, "[%s] Your previous replay has been canceled. Initializing the replay you've just requested...", PLUGIN_TAG);

	if (!lenMsg)
		copy(replayingMsg, lenMsg, "Starting replay...");

	client_print(id, print_chat, "%s", replayingMsg);

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
			//fread_blocks(file, replay, sizeof(replay) - 1, BLOCK_INT);
			fread_blocks(file, replay, sizeof(replay) - 2, BLOCK_INT);
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
			// TODO: use the AG cvar for starting health?
			entity_set_float(bot, EV_FL_health, 200.0);

			entity_set_byte(bot, EV_BYTE_controller1, 125);
			entity_set_byte(bot, EV_BYTE_controller2, 125);
			entity_set_byte(bot, EV_BYTE_controller3, 125);
			entity_set_byte(bot, EV_BYTE_controller4, 125);

			new Float:maxs[3] = {16.0, 16.0, 36.0};
			new Float:mins[3] = {-16.0, -16.0, -36.0};
			entity_set_size(bot, mins, maxs);

			static replay[REPLAY];
			ArrayGetArray(g_ReplayFrames[id], 0, replay);

			set_pev(bot, pev_origin, replay[RP_ORIGIN]);
			set_pev(bot, pev_angles, replay[RP_ANGLES]);
			set_pev(bot, pev_v_angle, replay[RP_ANGLES]);
			set_pev(bot, pev_button, replay[RP_BUTTONS]);
			g_ReplayStartGameTime[id] = replay[RP_TIME];
			//g_isCustomFpsReplay[id] = g_ReplayFpsMultiplier[id] > 1;

			g_BotOwner[bot] = id;
			g_Unfreeze[bot] = 0;
			//console_print(1, "player %d spawned the bot %d", id, bot);

			g_LastSpawnedBot = bot;

			// TODO: countdown hud; 2 seconds to start the replay, so there's time to switch to spectator
			entity_set_float(ent, EV_FL_nextthink, get_gametime() + get_pcvar_float(pcvar_kz_replay_setup_time));
			engfunc(EngFunc_RunPlayerMove, bot, replay[RP_ANGLES], 0.0, 0.0, 0.0, replay[RP_BUTTONS], 0, 4);

			if (pev(id, pev_iuser1) != OBS_NONE)
			{
				// Owner is in spec mode. Make them watch this new replaybot
				set_pev(id, pev_iuser1, OBS_IN_EYE);
				set_pev(id, pev_iuser2, bot);

				new payLoad[2];
				payLoad[0] = id;
				payLoad[1] = bot;

				RestoreSpecCam(payLoad, TASKID_CAM_UNFREEZE);
			}
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

			engfunc(EngFunc_RunPlayerMove, bot, botAngles, 0.0, 0.0, 0.0, pev(bot, pev_button), 0, 4);
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
	set_user_info(id, "team",				"robo");
	set_user_info(id, "rate",				"100000.000000");
	set_user_info(id, "cl_updaterate",		"102");
	set_user_info(id, "cl_lw",				"0");
	set_user_info(id, "cl_lc",				"0");
	set_user_info(id, "tracker",			"0");
	set_user_info(id, "cl_dlmax",			"1024");
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
/*
		if (g_Unfreeze[bot] > 3)
		{
			if (get_pcvar_num(pcvar_kz_spec_unfreeze))
				UnfreezeSpecCam(bot);
			g_Unfreeze[bot] = 0;
		}
*/
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

		//new Float:botPrevHSpeed = floatsqroot(floatpower(botVelocity[0], 2.0) + floatpower(botVelocity[1], 2.0));
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

		set_pev(bot, pev_origin, replay[RP_ORIGIN]);
		set_pev(bot, pev_angles, replay[RP_ANGLES]);
		set_pev(bot, pev_v_angle, replay[RP_ANGLES]);
		set_pev(bot, pev_button, replay[RP_BUTTONS]);
		set_pev(bot, pev_velocity, botVelocity);

		entity_set_float(id, EV_FL_nextthink, get_gametime() + replayNext[RP_TIME] - replay[RP_TIME]);

		new Float:botCurrHSpeed = xs_vec_len_2d(botVelocity);
		new Float:botCurrPos[3];
		xs_vec_copy(replay[RP_ORIGIN], botCurrPos);

		new Float:demoTime = replay[RP_TIME] - g_ReplayStartGameTime[owner];

		if (g_ConsolePrintNextFrames[owner] > 0)
		{
			console_print(owner, "[t=%d %.5f] dp: %.2f, px: %.2f, py: %.2f, pz: %.2f, s: %.2f, btns: %d",
				g_ReplayFramesIdx[owner], demoTime, get_distance_f(botCurrPos, botPrevPos),
				replay[RP_ORIGIN][0], replay[RP_ORIGIN][1], replay[RP_ORIGIN][2], botCurrHSpeed, replay[RP_BUTTONS]);
			g_ConsolePrintNextFrames[owner]--;
		}

		if (g_ReplayFramesIdx[owner] == 1)
		{
			// For some reason sometimes the bot doesn't press the start button even though it has
			// the IN_USE bit set for pev_buttons in the first frame, so we make it press it here
			// in the second frame and thus spectators will be able to see the replay's HUD properly
			StartClimb(bot);

			// We also change the time the run started, cos it should have been first frame's gametime
			g_PlayerTime[bot] = get_gametime() - (replay[RP_TIME] - replayPrev[RP_TIME]);
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

public UnfreezeSpecCam(target)
{
	for (new spec = 1; spec <= g_MaxPlayers; spec++)
	{
		if (is_user_connected(spec))
		{
			// Iterate from 1 to g_MaxPlayers, if it doesn't exist or is not playing don't do anything
			if (is_user_alive(spec))
				continue;

			if (pev(spec, pev_iuser2) == target)
			{
				// This spectator is watching the frozen target (not really, what is frozen is the cam, the target is moving)
				new botName[33], specName[33];
				GetColorlessName(target, botName, charsmax(botName));
				GetColorlessName(spec, specName, charsmax(specName));

				new Float:botOrigin[3], Float:botAngles[3];
				pev(target, pev_origin, botOrigin);
				pev(target, pev_v_angle, botAngles);

				set_pev(spec, pev_origin, botOrigin);
				set_pev(spec, pev_angles, botAngles);
				set_pev(spec, pev_v_angle, botAngles);

				new payLoad[2];
				payLoad[0] = spec;
				payLoad[1] = target;
				new taskId = spec * 36;
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
	new target = payLoad[1];

	if (!pev_valid(spec) || !pev_valid(target) || !IsPlayer(spec) || !IsPlayer(target))
		return;

	// Checking if the spectator continues spectating, otherwise if unspecs during
	// the time this task is executed it will be teleported to the runner position
	if (pev(spec, pev_iuser1))
	{
		// This spectator is watching the frozen target (not really, what is frozen is the cam, the target is moving)
		new botName[33], specName[33];
		GetColorlessName(target, botName, charsmax(botName));
		GetColorlessName(spec, specName, charsmax(specName));

		new Float:botOrigin[3], Float:botAngles[3];
		pev(target, pev_origin, botOrigin);
		pev(target, pev_v_angle, botAngles);

		set_pev(spec, pev_iuser2, target);

		set_pev(spec, pev_origin, botOrigin);
		set_pev(spec, pev_angles, botAngles);
		set_pev(spec, pev_v_angle, botAngles);
	}
}

public CmdPrintNextFrames(id)
{
	g_ConsolePrintNextFrames[id] = GetNumberArg();
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

	UnfreezePlayer(id);
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

	if (g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
	{
		ShowMessage(id, "You can't respawn during a race or No-Reset run");
		return;
	}
	
	if (g_IsInNoclip[id])
	{
		client_print(id, print_chat, "[%s] Exit noclip to respawn.", PLUGIN_TAG);
		return;
	}

	ResetPlayer(id, false, true);

	g_InForcedRespawn = true;	// this blocks teleporting to CP after respawn

	strip_user_weapons(id);
	ExecuteHamB(Ham_Spawn, id);

	ResumeTimer(id);
}

CmdHelp(id)
{
	new motd[MAX_MOTD_LENGTH], title[32], len;

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
	//  /distance - toggle showing horizontal distance\n");
	// 	No more space in motd for the moment.

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
		/hudcolor <#> <#> <#> - set custom HUD color (R, G, B)\n\
		/hudcolor <red|green|blue|cyan|magenta|yellow|gray|white>\n\
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
	remove_quotes(args);
	trim(args);

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

	else if (equali(args[1], "startnr") || equali(args[1], "nrstart"))
		CmdStartNr(id);

	else if (equali(args[1], "cancelnr") || equali(args[1], "nrcancel"))
		CmdCancelNoReset(id);

	else if (equali(args[1], "timer"))
		CmdTimer(id);

	else if (equali(args[1], "speclist"))
		CmdSpecList(id);

	else if (equali(args[1], "spectate") || equali(args[1], "spec"))
		CmdSpec(id);

	else if (equali(args[1], "checkspec")) // TODO: is this useful?
		CmdSpectatingName(id);

	else if (equali(args[1], "setstart") || equali(args[1], "ss"))
		CmdSetCustomStartHandler(id);

	else if (equali(args[1], "clearstart") || equali(args[1], "cs"))
		CmdClearCustomStartHandler(id);

	else if (equali(args[1], "invis"))
		CmdInvis(id);

	else if (equali(args[1], "winvis") || equali(args[1], "waterinvis") || equali(args[1], "water")
		|| equali(args[1], "liquidinvis") || equali(args[1], "liquids"))
		CmdWaterInvis(id);

	else if (equali(args[1], "showkeys") || equali(args[1], "keys"))
		CmdShowkeys(id);

	else if (equali(args[1], "startmsg"))
		CmdMenuShowStartMsg(id);

	else if (equali(args[1], "spawn") || equali(args[1], "respawn"))
		CmdRespawn(id);

	else if (equali(args[1], "kzmenu") || equali(args[1], "menu") || equali(args[1], "kz"))
		DisplayKzMenu(id, 0);

	else if (equali(args[1], "rpmenu") || equali(args[1], "replaymenu") || equali(args[1], "replaysmenu"))
	{
		if (is_user_admin(id))
		{
			// TODO: show a menu where you can choose to replay pure, pro, noob, or cup replays,
			// and in the future custom replays (replays of tricks, of the last run attempt, etc.)
			ShowCupReplayMenu(id);
		}
	}

	else if (equali(args[1], "kzhelp") || equali(args[1], "help") || equali(args[1], "h"))
		CmdHelp(id);

	else if (equali(args[1], "slopefix"))
		CmdSlopefix(id);

	else if (equali(args[1], "speed"))
		CmdSpeed(id);

	else if (equali(args[1], "dist") || equali(args[1], "distance") || equali(args[1], "measure") || equali(args[1], "ruler"))
		CmdDistance(id);

	else if (equali(args[1], "height") || equali(args[1], "heightdiff"))
		CmdHeightDiff(id);

	else if (equali(args[1], "ready"))
		CmdReady(id);

	else if (equali(args[1], "noreset") || equali(args[1], "no-reset") || equali(args[1], "nr"))
		CmdStartNoReset(id);

	else if (equali(args[1], "bot"))
	{
		if (is_user_admin(id))
			SpawnDummyBot(id);
	}
	else if (equali(args[1], "tpcountdown"))
		CmdSetTpOnCountdown(id);

	else if (equali(args[1], "y") || equali(args[1], "yes"))
		CmdVote(id, KZVOTE_YES);

	else if (equali(args[1], "n") || equali(args[1], "no"))
		CmdVote(id, KZVOTE_NO);

	//else if (equali(args[1], "idk") || equali(args[1], "undecided"))
	//	CmdVote(id, KZVOTE_UNDECIDED);

	else if (equali(args[1], "hidevote") || equali(args[1], "votehide"))
		CmdToggleVoteVisibility(id);

	else if (equali(args[1], "ignorevote") || equali(args[1], "voteignore"))
		CmdToggleVoteIgnore(id);

	else if (equali(args[1], "runstats_con") || equali(args[1], "runstats_console"))
		CmdShowRunStatsOnConsole(id);
	
	else if (equali(args[1], "noclip"))
		CmdNoclip(id);

	// The ones below use containi() because they can be passed parameters
	else if (containi(args[1], "alignvote") == 0)
		CmdAlignVote(id);

	else if (containi(args[1], "printframes") == 0)
		CmdPrintNextFrames(id);

	else if (containi(args[1], "race") == 0)
		CmdVoteRace(id);

	else if (containi(args[1], "replaypro") == 0)
		CmdReplayPro(id);

	else if (containi(args[1], "replaynub") == 0 || containi(args[1], "replaynoob") == 0)
		CmdReplayNoob(id);

	else if (containi(args[1], "replaypure") == 0 || containi(args[1], "replaybot") == 0
		|| containi(args[1], "replay") == 0 || containi(args[1], "rp") == 0)
		CmdReplayPure(id);
/*
	else if (containi(args[1], "replaysmooth") == 0)
		CmdReplaySmoothen(id);
*/
	else if (containi(args[1], "speedcap") == 0)
		CmdSpeedcap(id);

	else if (containi(args[1], "prespeedcap") == 0)
		CmdPreSpeedcap(id);

	else if (containi(args[1], "dec") == 0)
		CmdTimeDecimals(id);

	else if (containi(args[1], "nv") == 0 || containi(args[1], "nightvision") == 0)
		CmdNightvision(id);

	else if (containi(args[1], "runstats_con_detail") == 0 || containi(args[1], "runstats_console_detail") == 0)
		CmdRunStatsConsoleDetails(id)

	else if (containi(args[1], "runstats_hud_detail") == 0)
		CmdRunStatsHudDetails(id);

	else if (containi(args[1], "runstats_hud_time") == 0)
		CmdRunStatsHudHoldTime(id);

	else if (containi(args[1], "runstats_hud_x") == 0)
		CmdRunStatsHudX(id);

	else if (containi(args[1], "runstats_hud_y") == 0)
		CmdRunStatsHudY(id);

	else if (containi(args[1], "runstats_hud") == 0)
		CmdShowRunStatsOnHud(id);

	else if (containi(args[1], "purepblaps") == 0)
		ShowTopClimbersPbLaps(id, PURE);

	else if (containi(args[1], "propblaps") == 0)
		ShowTopClimbersPbLaps(id, PRO);

	else if (containi(args[1], "nubpblaps") == 0 || containi(args[1], "noobpblaps") == 0)
		ShowTopClimbersPbLaps(id, NOOB);

	else if (containi(args[1], "puregoldlaps") == 0)
		ShowTopClimbersGoldLaps(id, PURE);

	else if (containi(args[1], "progoldlaps") == 0)
		ShowTopClimbersGoldLaps(id, PRO);

	else if (containi(args[1], "nubgoldlaps") == 0 || containi(args[1], "noobgoldlaps") == 0)
		ShowTopClimbersGoldLaps(id, NOOB);

	else if (containi(args[1], "pure") == 0)
		ShowTopClimbers(id, PURE);

	else if (containi(args[1], "pro") == 0)
		ShowTopClimbers(id, PRO);

	else if (containi(args[1], "nub") == 0 || containi(args[1], "noob") == 0)
		ShowTopClimbers(id, NOOB);

	else if (containi(args[1], "nrtop") == 0 || containi(args[1], "topnr") == 0)
		ShowTopNoReset(id);

	else if (containi(args[1], "top") == 0)
		DisplayKzMenu(id, 5);

	else if (containi(args[1], "countdown") == 0)
		CmdSetCountdown(id);

	else if (containi(args[1], "hudcolor") == 0 || containi(args[1], "hudcolour") == 0
		|| containi(args[1], "hud_color") == 0 || containi(args[1], "hud_colour") == 0)
	{
		CmdHudColor(id);
	}
	
	else if (containi(args[1], "noclipspeed") == 0)
		CmdNoclipSpeed(id);
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
	if (g_RunMode[id] != MODE_NORMAL)
		return PLUGIN_HANDLED;

	new cmd[32];
	read_argv(0, cmd, charsmax(cmd));
	new bit;
	switch (cmd[1])
	{
	case 'h', 'H': set_bit(bit, CHEAT_HOOK);  // +|-hook
	case 'r', 'R': set_bit(bit, CHEAT_ROPE);  // +|-rope
	default: return PLUGIN_CONTINUE;
	}

	new const hookOrRopeBits = (1 << (CHEAT_HOOK - 1)) | (1 << (CHEAT_ROPE - 1));

	if (cmd[0] == '+')
		g_CheatCommandsGuard[id] |= bit;
	else
	{
		// Skip timer reset if hook isn't used, the case when console opened/closed with bind to command (it sends -command)
		if (!(g_CheatCommandsGuard[id] & hookOrRopeBits))
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
	if (g_RunMode[id] != MODE_NORMAL)
		return PLUGIN_HANDLED;

	new cmd[32];
	read_argv(0, cmd, charsmax(cmd));

	if (cmd[0] == '+')
		set_bit(g_CheatCommandsGuard[id], CHEAT_TAS);
	else
	{
		// Skip timer reset if hook isn't used, the case when console opened/closed with bind to command (it sends -command)
		if (!get_bit(g_CheatCommandsGuard[id], CHEAT_TAS))
			return PLUGIN_CONTINUE;

		clr_bit(g_CheatCommandsGuard[id], CHEAT_TAS)
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
	if (g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
	{
		if (showMessages) ShowMessage(id, "You can't create a checkpoint while in race or No-Reset run");
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
	if (g_IsInNoclip[id])
	{
		client_print(id, print_chat, "[%s] You can't create a checkpoint in noclip.", PLUGIN_TAG);
		return false;
	}

	return true;
}

bool:CanTeleport(id, cp, bool:showMessages = true)
{
	if ((g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
		&& cp != CP_TYPE_START && cp != CP_TYPE_CUSTOM_START && cp != CP_TYPE_DEFAULT_START)
	{
		// If a NR is during countdown or already started, cannot TP to any other than start or default one,
		// no custom TP, no practice TP, no normal TP, no old TP to unstuck
		if (showMessages) ShowMessage(id, "Unable to teleport to a checkpoint during race or No-Reset run!");
		return false;
	}

	return CanTeleportNr(id, cp, showMessages);
}

bool:CanTeleportNr(id, cp, bool:showMessages = true)
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
		if (g_usesStartingZone && (cp == CP_TYPE_START || cp == CP_TYPE_CUSTOM_START))
			set_pev(id, pev_velocity, g_ControlPoints[id][cp][CP_VELOCITY]);
		else
			set_pev(id, pev_velocity, Float:{ 0.0, 0.0, 0.0 });
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
		if (get_pcvar_num(pcvar_sv_ag_match_running) == 1 || g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
		{
			if (CanTeleport(id, CP_TYPE_CUSTOM_START, false) && g_usesStartingZone)
				Teleport(id, CP_TYPE_CUSTOM_START);
			else if (CanTeleport(id, CP_TYPE_START, false))
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
		else if (CanTeleport(id, CP_TYPE_CUSTOM_START, false) && g_usesStartingZone)
			Teleport(id, CP_TYPE_CUSTOM_START);
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
	return xs_vec_len_2d(velocity);
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
	if (g_bMatchRunning || g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
	{
		if (showMessages) ShowMessage(id, "A match is running, spectate is disabled");
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

public CmdJointeamHandler(id)
{
	if(pev(id, pev_iuser1) != OBS_NONE)
	{
		client_cmd(id, "spectate");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public CmdAgVoteHandler(id)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		// TODO: others can still vote agstart and get you into a new no-reset before finishing this one,
		// it requires some effort for the exploiter but gotta be handled at some point
		ShowMessage(id, "You're in a no-reset/race/agstart run. Please, finish it before voting a new match!");
		return PLUGIN_HANDLED;
	}

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
	for (new i = 0; i < playersNum; i++)
	{
		new id2 = players[i];

		if (g_RunMode[id2] == MODE_NORESET)
		{
			new playerName[32];
			GetColorlessName(id2, playerName, charsmax(playerName));

			// TODO: think of a better way to handle the situation where a player is doing a No-Reset run,
			// and people in the server want to agstart. Can this be exploited to bother other players?
			// FIXME: What if you leave in the middle of a No-Reset run, and when you come back some people is in agstart? your timer would continue going on...
			client_print(id, print_chat, "[%s] Cannot vote agstart or agmap because %s is doing a No-Reset run", PLUGIN_TAG, playerName);
			client_print(id, print_chat, "[%s] You can vote right when they finish their run", PLUGIN_TAG, playerName);
			ShowMessage(id, "Please, vote when %s finishes their No-Reset run", playerName);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public CmdTimelimitVoteHandler(id)
{
	new Float:proposedTimelimit = GetFloatArg(); // minutes

	new Float:timeleft  = get_cvar_float("mp_timeleft") / 60.0; // mp_timeleft comes in seconds
	new Float:timelimit = get_cvar_float("mp_timelimit"); // minutes

	//server_print("timeleft: %.2f, timelimit: %.2f, proposed timelimit: %.2f", timeleft, timelimit, proposedTimelimit);

	if (IsAnyActiveNR() && proposedTimelimit && (proposedTimelimit < timelimit)
		&& (proposedTimelimit < (timelimit - timeleft + MIN_TIMELEFT_ALLOWED_NORESET)))
	{
		client_print(id, print_chat, "[%s] Sorry, there are No-Reset runs ongoing and they might run out of time with your proposed timelimit", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
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

	if (g_DisableSpec)
	{
		ShowMessage(id, "Spectator mode is disabled during cup races");
		return PLUGIN_HANDLED;
	}

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

		if (g_IsKzVoteRunning[id])
			g_KzVoteValue[id] = KZVOTE_UNKNOWN;
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
				UnfreezePlayer(id);
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

			new bot = GetOwnersBot(id);
			if (!bot && g_ReplayNum > 0)
				bot = g_LastSpawnedBot;

			if (bot && is_user_alive(bot) && pev(bot, pev_iuser1) == OBS_NONE)
			{
				// Spec your bot or the last spawned one, if you didn't want to (very unlikely),
				// then it doesn't really matter cos you probably would have to spend a few
				// clicks switching to the desired target either way
				set_pev(id, pev_iuser1, OBS_IN_EYE);
				set_pev(id, pev_iuser2, bot);

				new payLoad[2];
				payLoad[0] = id;
				payLoad[1] = bot;

				RestoreSpecCam(payLoad, TASKID_CAM_UNFREEZE);
			}
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
	if (g_RunMode[id] != MODE_NORMAL) // not checking on countdown... if a vote pops up during countdown, cancel your run with /cancelnr
	{
		if (showMessages) ShowMessage(id, "A match is running, pause is disabled");
		return false;
	}

	return true;
}

bool:CanReset(id, bool:showMessages = true)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		if (showMessages) ShowMessage(id, "A match is running, reset is disabled");
		return false;
	}

	return true;
}

ResetRecording(id)
{
	if (g_RecordRun[id])
	{
		g_RecordRun[id] = 0;
		ArrayClear(g_RunFrames[id]);
	}

	if (get_pcvar_num(pcvar_kz_autorecord) && !IsBot(id))
	{
		g_RecordRun[id] = 1;
		g_RunFrames[id] = ArrayCreate(REPLAY);
		RecordRunFrame(id);
	}
}

StartClimb(id, bool:isMatch = false)
{
	if (g_CheatCommandsGuard[id] || g_IsInNoclip[id])
	{
		if(get_pcvar_num(pcvar_kz_denied_sound))
		{
			client_cmd(id, "spk \"vox/access denied\"");
		}
		ShowMessage(id, "Using timer while cheating is prohibited");
		return;
	}

	if (!isMatch && g_PlayerTime[id] && g_RunMode[id] != MODE_NORMAL)
	{
		ShowMessage(id, "A match is running, start is disabled");
		return;
	}

	ResetRecording(id);

	if (isMatch)
		ResetPlayer(id);
	else
		InitPlayer(id);

	if (g_RunLaps)
		g_CurrentLap[id] = 1;

	CreateCp(id, CP_TYPE_START);
	InitPlayerVariables(id);

	set_bit(g_baIsClimbing, id);
	g_RunFrameCount[id] = 1;

	CheckSpeedcap(id, true);
	CheckStartSpeed(id);

	StartTimer(id);
}

// TODO: refactor this and StartClimb
AgstartClimb(id)
{
	ResetRecording(id);

	ResetPlayer(id, true);

	if (g_RunLaps)
		g_CurrentLap[id] = 1;

	CreateCp(id, CP_TYPE_START);
	InitPlayerVariables(id);

	set_bit(g_baIsClimbing, id);
	g_RunFrameCount[id] = 1;

	CheckSpeedcap(id, true);
	CheckStartSpeed(id);

	StartTimer(id);
}

FinishClimb(id)
{
	new kzDeniedSound = get_pcvar_bool(pcvar_kz_denied_sound);
	new bool:canFinish = true;
	if (g_CheatCommandsGuard[id] || g_IsInNoclip[id])
	{
		ShowMessage(id, "Using timer while cheating is prohibited");
		canFinish = false;
	}
	if (canFinish && !get_bit(g_baIsClimbing, id))
	{
		ShowMessage(id, "You must press the start button first");
		canFinish = false;
	}
	if (canFinish && g_RunStartTime[id])
	{
		ShowMessage(id, "It's not allowed to finish the map while on countdown");
		canFinish = false;
	}
	if (canFinish && g_RunTotalReq && g_PlayerRunReqs[id] != g_RunTotalReq)
	{
		ShowMessage(id, "You don't meet the requirements to finish. Press the required buttons or pass through the required places first");
		canFinish = false;
	}
	if (canFinish && g_RunLaps && ArraySize(g_SplitTimes[id]) != ArraySize(g_OrderedSplits))
	{
		ShowMessage(id, "Can't finish. Make sure you have passed through all splits");
		canFinish = false;
	}
	if (canFinish && g_usesStartingZone && !g_IsValidStart[id])
	{
		// TODO: show this message halfway through the run, but without resetting the player
		ShowMessage(id, "Invalid run: didn't touch/press start? (might be due to lag)");

		// Just in case somehow this goes wrong during a cup, we print the exact run time
		// to help admins judge together with replays or VOD
		new name[32], minutes, Float:seconds, pureRun[12];
		new Float:kztime = get_gametime() - g_PlayerTime[id];
		new RUN_TYPE:topType = GetTopType(id);

		minutes = floatround(kztime, floatround_floor) / 60;
		seconds = kztime - (60 * minutes);
		pureRun = get_bit(g_baIsPureRunning, id) ? " (Pure Run)" : "";

		get_user_name(id, name, charsmax(name));
		client_print(0, print_chat, GetVariableDecimalMessage(id, "[%s] %s^0 would have finished in %02d:%0", "%s%s, but had a seemingly wrong custom start"),
			PLUGIN_TAG, name, minutes, seconds, pureRun, g_RunMode[id] == MODE_NORESET ? " No-Reset" : "");

		if (IsCupMap() && IsCupPlayer(id))
		{
			// Save the replay as we probably need to see what was that custom start
			SaveRecordedRunCup(id, topType);

			// TODO: ugly, refactor
			if (id == g_CupPlayer1)
				g_CupReady1 = false;
			else if (id == g_CupPlayer2)
				g_CupReady2 = false;
		}
		ResetPlayer(id);

		return;
	}

	if (!canFinish)
	{
		if (kzDeniedSound)
			client_cmd(id, "spk \"vox/access denied\"");

		return;
	}

	g_IsValidStart[id] = false;

	FinishTimer(id);
	InitPlayer(id);
}

Float:GetStartSpeed(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);

	new Float:speed;
	if (g_usesStartingZone)
	{
		// For start zones we just take into account horizontal speed
		speed = xs_vec_len_2d(velocity);
	}
	else
	{
		// Account for vertical speed too. Important because in some maps you can
		// fall down on the button slope and take advantage of its boost, pressing
		// the button before getting the horizontal boost. So by accounting for the
		// vertical speed we can avoid that exploit
		speed = vector_length(velocity);
	}

	return speed;
}

// Check prespeed to decide whether it's Pure or not
CheckStartSpeed(id)
{
	new Float:speed = GetStartSpeed(id);

	if (speed <= get_pcvar_float(pcvar_kz_pure_max_start_speed))
		set_bit(g_baIsPureRunning, id);
}

StartTimer(id)
{
	g_RunStartTimestamp[id] = get_systime();
	g_PlayerTime[id] = get_gametime();

	new ret;
	ExecuteForward(mfwd_hlkz_timer_start, ret, id);

	if (g_ShowStartMsg[id])
	{
		new msg[38];
		if (g_RunMode[id] == MODE_NORESET)
			formatex(msg, charsmax(msg), "No-Reset run started!");
		else if (g_RunMode[id] == MODE_AGSTART || g_RunMode[id] == MODE_RACE)
			formatex(msg, charsmax(msg), "Race started!");
		else
		{
			new Float:speed = GetStartSpeed(id);
			formatex(msg, charsmax(msg), "Timer started with speed %5.2fu/s", speed);
		}

		ShowMessage(id, msg);
	}
}

FinishTimer(id)
{
	new name[32], minutes, Float:seconds, pureRun[12];
	new Float:kztime = get_gametime() - g_PlayerTime[id];
	new RUN_TYPE:topType = GetTopType(id);

	minutes = floatround(kztime, floatround_floor) / 60;
	seconds = kztime - (60 * minutes);
	pureRun = get_bit(g_baIsPureRunning, id) ? " (Pure Run)" : "";

	client_cmd(0, "spk fvox/bell");

	get_user_name(id, name, charsmax(name));
	client_print(0, print_chat, GetVariableDecimalMessage(id, "[%s] %s^0 finished in %02d:%0", " (CPs: %d | TPs: %d)%s%s"),
		PLUGIN_TAG, name, minutes, seconds, g_CpCounters[id][COUNTER_CP], g_CpCounters[id][COUNTER_TP], pureRun, g_RunMode[id] == MODE_NORESET ? " No-Reset" : "");

	g_RunStatsEndHudStartTime[id] = get_gametime();
	g_RunStatsEndHudShown[id] = false;

	if (g_ShowRunStatsOnConsole[id])
	{
		// Tried in a single console_print() call, and it printed like the first hundred chars only
		console_print(id, "------------------------------------------------");
		console_print(id, "Stats for your run with time %02d:%09.6f", minutes, seconds);
		console_print(id, "------------------------------------------------");

		if (g_RunStatsConsoleDetailLevel[id] >= 1)
		{
			console_print(id, "Avg speed: %.2f",             g_RunAvgSpeed[id]);
		}

		console_print(id, "Max speed: %.2f",                 g_RunMaxSpeed[id]);
		console_print(id, "End speed: %.2f",                 g_RunCurrSpeed[id]);

		if (g_RunStatsConsoleDetailLevel[id] >= 1)
		{
			console_print(id, "Avg fps: %.2f",               g_RunAvgFps[id]);
			console_print(id, "Min fps: %.2f",               g_RunMinFps[id]);
		}
		console_print(id, "Distance: %.2f",                  g_RunDistance2D[id]);

		if (g_RunStatsConsoleDetailLevel[id] >= 2)
		{
			console_print(id, "Distance 3D: %.2f",           g_RunDistance3D[id]);
		}

		console_print(id, "Jumps: %d",                       g_RunJumps[id]);
		console_print(id, "Ducktaps: %d",                    g_RunDucktaps[id]);

		//if (g_RunStatsConsoleDetailLevel[id] >= 2)
		//{
		//	console_print(id, "Strafes: %d",                 g_RunStrafes[id]);
		//}

		//if (g_RunStatsConsoleDetailLevel[id] >= 1)
		//{
		//	console_print(id, "Sync: %d",                    g_RunSync[id]);
		//}

		console_print(id, "Slowdowns: %d",                   g_RunSlowdowns[id]);

		if (g_RunStatsConsoleDetailLevel[id] >= 2)
		{
			console_print(id, "Time lost at start: %.4f",    g_RunLostStartTime[id]);
			console_print(id, "Time lost at end: %.4f",      g_RunLostEndTime[id]);
			console_print(id, "Start prestrafe speed: %.2f", g_RunStartPrestrafeSpeed[id]);
			console_print(id, "Start prestrafe time: %.4f",  g_RunStartPrestrafeTime[id]);
		}
		console_print(id, "------------------------------------------------");
	}

	// Bots are not gonna set new records yet, unless some bhop AI is created for fun
	if (!get_pcvar_num(pcvar_kz_nostat) && !IsBot(id))
	{
		UpdateRecords(id, kztime, topType);
	}

	if (g_bMatchRunning && !IsBot(id))
	{
		StopMatch();
		server_cmd("agabort");
		server_exec();

		if (IsCupMap() && IsCupPlayer(id))
		{
			// Do stuff for the cup

			g_DisableSpec = false;

			// Save replays of both participants, for the one that didn't reach the button too
			if (g_RecordRun[g_CupPlayer1])
				SaveRecordedRunCup(g_CupPlayer1, topType);

			if (g_RecordRun[g_CupPlayer2])
				SaveRecordedRunCup(g_CupPlayer2, topType);

			SetCupMapWinner(id);
		}

		LaunchRecordFireworks();
	}

	if (g_RunMode[id] == MODE_RACE)
	{
		client_print(0, print_chat, "[%s] %s^0 won the race!", PLUGIN_TAG, name);
		// Same behaviour as in agstart: the first one to finish also ends the runs of the rest of runners
		CancelRaces(g_RaceId[id]);
	}

	if (g_RecordRun[id])
	{
		// By this point any worthy run should have been saved already
		server_print("[%s] Clearing recorded run for player #%d with %d frames from memory", PLUGIN_TAG, get_user_userid(id), ArraySize(g_RunFrames[id]));
		g_RecordRun[id] = 0;
		ArrayClear(g_RunFrames[id]);
	}

	g_RunFrameCount[id] = 0;
}

RUN_TYPE:GetTopType(id)
{
	if (!g_CpCounters[id][COUNTER_CP] && !g_CpCounters[id][COUNTER_TP])
	{
		if (get_bit(g_baIsPureRunning, id))
			return PURE;
		else
			return PRO;
	}
	else
		return NOOB;
}

SplitTime(id, ent)
{
	if (!get_bit(g_baIsClimbing, id))
		return;

	new split[SPLIT], splitIdx, splitsPerLap, lastSplitIdx, previousSplitIdx, previousSplitId[17], previousSplit[SPLIT];

	GetSplitByEntityId(ent, split);
	splitIdx = ArrayFindString(g_OrderedSplits, split[SPLIT_ID]);
	splitsPerLap = ArraySize(g_OrderedSplits);
	lastSplitIdx = splitsPerLap - 1;
	previousSplitIdx = splitIdx - 1;
	if (previousSplitIdx == -1)
		previousSplitIdx = lastSplitIdx;

	ArrayGetString(g_OrderedSplits, previousSplitIdx, previousSplitId, charsmax(previousSplitId));
	TrieGetArray(g_Splits, previousSplitId, previousSplit, sizeof(previousSplit));

	new playerSplitRelative = ArraySize(g_SplitTimes[id]);
	if (playerSplitRelative >= lastSplitIdx)
	{
		playerSplitRelative -= splitsPerLap;
	}

	if ((splitIdx - 1) != playerSplitRelative)
	{
		// Cases leading here:
		// - Player is still touching the same split that they've gone through a few frames ago, because the bounding box has
		//   some thickness and takes some frames to stop touching it (player is still inside the bounding box of the split)
		// - Player is going backwards, touching the previous split(s)
		// - Player has skipped some split, because some split's bounding box is wrong letting them pass without touching it,
		//   or because the map is designed like that
		return;
	}

	if (splitIdx == 1 && ArraySize(g_SplitTimes[id]) == splitsPerLap)
	{
		// We clear this on the 2nd split (index=1) because the 1st one is still used to get previous lap's last split's time
		// and during the first split the HUD still has to show that split's time
		ArrayClear(g_SplitTimes[id]);
	}

	new currLap = g_CurrentLap[id];
	new timestamp = get_systime();
	new RUN_TYPE:topType = GetTopType(id);

	FinishSplit(id, currLap, timestamp, topType, previousSplit, splitsPerLap);

	if (splitIdx == 0)
	{
		if (g_RunLaps)
		{
			FinishLap(id, currLap, timestamp, topType);
		}

		// Extra parentheses because my editor has some syntax highlighting problems
		if ((!g_RunLaps) || (g_RunLaps && g_CurrentLap[id] > g_RunLaps))
		{
			FinishClimb(id);
		}
	}
}

FinishSplit(id, currLap, timestamp, RUN_TYPE:topType, previousSplit[SPLIT], splitsPerLap)
{
	new splitText[54];
	new Float:splitTime = GetCurrentRunTime(id) - GetPreviousLapTimes(id) - GetCurrentLapTime(id);
	formatex(splitText, charsmax(splitText), "%s - %s", previousSplit[SPLIT_NAME], GetSplitTimeText(id, splitTime));

	ArrayPushCell(g_SplitTimes[id], splitTime);
	SplitTimeInsert(id, previousSplit[SPLIT_DB_ID], splitTime, currLap, topType, timestamp);

	// Get the split index over the total splits (5 laps with 3 splits each -> 15 splits)
	new totalSplitIdx       = (splitsPerLap * (currLap - 1)) + ArraySize(g_SplitTimes[id]);

	new Float:pbSplitTime, Float:goldSplitTime, bool:isNewGold;

	if (!IsBot(id))
	{
		pbSplitTime   = ArrayGetCell(g_PbSplits[id][topType], totalSplitIdx - 1);
		goldSplitTime = ArrayGetCell(g_GoldSplits[id][topType], totalSplitIdx - 1);

		isNewGold = goldSplitTime > splitTime
		if (isNewGold)
			ArraySetCell(g_GoldSplits[id][topType], totalSplitIdx - 1, splitTime);
	}

	// HUD and logging for this split
	new msgColor[COLOR];
	console_print(id, splitText);

	if (isNewGold)
		datacopy(msgColor, colorGold, sizeof(colorGold));
	else
	{
		msgColor[COLOR_RED]   = g_HudRGB[id][0];
		msgColor[COLOR_GREEN] = g_HudRGB[id][1];
		msgColor[COLOR_BLUE]  = g_HudRGB[id][2];
	}
	//set_dhudmessage(msgColor[COLOR_RED], msgColor[COLOR_GREEN], msgColor[COLOR_BLUE], _, HUD_DEFAULT_SPLIT_Y, 0, 0.0, HUD_SPLIT_HOLDTIME, _, 0.4);
	//show_dhudmessage(id, splitText);
	BroadcastSplitHudMessage(id, splitText, msgColor, HUD_DEFAULT_SPLIT_Y, HUD_SPLIT_HOLDTIME);

	if (!IsBot(id))
		ShowDeltaMessage(id, pbSplitTime, currLap, topType);
}

FinishLap(id, currLap, timestamp, RUN_TYPE:topType)
{
	new lapText[24];
	new Float:lapTime = GetCurrentLapTime(id);
	formatex(lapText, charsmax(lapText), "Lap %d - %s", currLap, GetSplitTimeText(id, lapTime));

	ArrayPushCell(g_LapTimes[id], lapTime);
	LapTimeInsert(id, currLap, lapTime, topType, timestamp);

	new Float:pbLapTime, Float:goldLapTime, bool:isNewGold;

	if (!IsBot(id))
	{
		//pbLapTime   = ArrayGetCell(g_PbLaps[id][topType], currLap - 1);
		goldLapTime = ArrayGetCell(g_GoldLaps[id][topType], currLap - 1);

		isNewGold = goldLapTime > lapTime;
		if (isNewGold)
			ArraySetCell(g_GoldLaps[id][topType], currLap - 1, lapTime);
	}

	// HUD and logging for this lap. Show it a bit below the split time
	new msgColor[COLOR];
	console_print(id, lapText);

	if (isNewGold)
		datacopy(msgColor, colorGold, sizeof(colorGold));
	else
	{
		msgColor[COLOR_RED]   = g_HudRGB[id][0];
		msgColor[COLOR_GREEN] = g_HudRGB[id][1];
		msgColor[COLOR_BLUE]  = g_HudRGB[id][2];
	}
	//set_dhudmessage(msgColor[COLOR_RED], msgColor[COLOR_GREEN], msgColor[COLOR_BLUE], _, HUD_DEFAULT_LAP_Y, 0, 0.0, HUD_LAP_HOLDTIME, _, 0.4);
	//show_dhudmessage(id, lapText);
	BroadcastSplitHudMessage(id, lapText, msgColor, HUD_DEFAULT_LAP_Y, HUD_LAP_HOLDTIME);

	//ShowDeltaMessage(id, pbLapTime, currLap, topType);

	g_CurrentLap[id]++;
}

ShowDeltaMessage(id, Float:pbTime, currLap, RUN_TYPE:topType)
{
	if (!pbTime)
	{
		// TODO: implement a user setting to compare against PB or against gold,
		// for the moment we only show delta time against PB, so if no PB yet, nothing to do here
		return;
	}

	new totalSplitIdx, Float:runDeltaTime, deltaColor[COLOR];

	totalSplitIdx = (ArraySize(g_OrderedSplits) * (currLap - 1)) + ArraySize(g_SplitTimes[id]);

	runDeltaTime  = GetCurrentRunTime(id) - GetPbRunTime(id, totalSplitIdx - 1, topType);

	if (runDeltaTime > 0.0)
		datacopy(deltaColor, colorBehind, sizeof(colorBehind));
	else if (runDeltaTime < 0.0)
		datacopy(deltaColor, colorAhead, sizeof(colorAhead));
	else
		datacopy(deltaColor, colorCyan, sizeof(colorCyan));

	new deltaText[24];
	formatex(deltaText, charsmax(deltaText), "(%s%s)", runDeltaTime > 0.0 ? "+" : "", GetSplitTimeText(id, runDeltaTime));
	//set_dhudmessage(deltaColor[COLOR_RED], deltaColor[COLOR_GREEN], deltaColor[COLOR_BLUE], _, HUD_DEFAULT_DELTA_Y, 0, 0.0, HUD_LAP_HOLDTIME, _, 0.4);
	//show_dhudmessage(id, deltaText);
	BroadcastSplitHudMessage(id, deltaText, deltaColor, HUD_DEFAULT_DELTA_Y, HUD_LAP_HOLDTIME);
}

BroadcastSplitHudMessage(id, text[], color[COLOR], Float:y, Float:holdTime)
{
	new auxColor[COLOR];

	if (IsBot(id))
		datacopy(auxColor, colorDefault, sizeof(colorDefault));
	else
		datacopy(auxColor, color, sizeof(color));

	new players[MAX_PLAYERS], playersNum, id2, mode, targetId;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);

	for (new i = 0; i < playersNum; i++)
	{
		id2 = players[i];

		mode = pev(id2, pev_iuser1);
		targetId = mode == OBS_CHASE_LOCKED || mode == OBS_CHASE_FREE || mode == OBS_IN_EYE || mode == OBS_MAP_CHASE ? pev(id2, pev_iuser2) : id2;

		new playerName[32], targetName[32];
		GetColorlessName(id2, playerName, charsmax(playerName));
		GetColorlessName(targetId, targetName, charsmax(targetName));

		if (targetId != id)
		{
			server_print("[%.3f] SKIPPING showing splits HUD about player '%s' to player '%s'", get_gametime(), targetName, playerName);
			continue;
		}
		server_print("[%.3f] showing splits HUD about player '%s' to player '%s'", get_gametime(), targetName, playerName);

		// Now we only have players that are spectating us, or ourselves, so show the message to these
		set_dhudmessage(auxColor[COLOR_RED], auxColor[COLOR_GREEN], auxColor[COLOR_BLUE], _, y, 0, 0.0, holdTime, _, 0.4);
		show_dhudmessage(id2, text);
	}
}

/**
 * This has a different format than the one used in the rest of the plugin when the time is less than 1 minute
 */
GetSplitTimeText(id, Float:time)
{
	new Float:absTime = xs_fabs(time);
	new minutes       = floatround(absTime, floatround_tozero) / 60;
	new Float:seconds = absTime - (60 * minutes);

	new sign[2];
	if (time < 0.0)
		sign[0] = '-';

	new result[14];
	if (minutes)
		formatex(result, charsmax(result), GetVariableDecimalMessage(id, "%s%d:%0"), sign, minutes, seconds);
	else
		formatex(result, charsmax(result), GetVariableDecimalMessage(id, "%s%"), sign, seconds);

	return result;
}

Float:GetCurrentRunTime(id)
{
	return get_gametime() - g_PlayerTime[id];
}

Float:GetPbRunTime(id, idx, RUN_TYPE:topType)
{
	new Float:result;

	for (new i = 0; i <= idx; i++)
	{
		result += Float:ArrayGetCell(g_PbSplits[id][topType], i);
	}

	return result;
}

Float:GetPreviousLapTimes(id)
{
	new Float:result;

	for (new i = 0; i < ArraySize(g_LapTimes[id]); i++)
	{
		result += Float:ArrayGetCell(g_LapTimes[id], i);
	}

	return result;
}

/**
 * Doesn't take into account current (ongoing) split's time, only the ones already finished
 */
Float:GetCurrentLapTime(id)
{
	new Float:result;

	for (new i = 0; i < ArraySize(g_SplitTimes[id]); i++)
	{
		result += Float:ArrayGetCell(g_SplitTimes[id], i);
	}

	return result;
}

CancelRaces(runId)
{
	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		if (g_RaceId[id] == runId)
		{
			g_RaceId[id] = 0;

			if (g_RunMode[id] == MODE_RACE)
			{
				// Apparently there is some case where races or agstarts might be conflicting with no-reset
				// runs of unrelated players... some state might be left dangling somewhere
				g_RunMode[id] = MODE_NORMAL;
				g_RunModeStarting[id] = MODE_NORMAL;
			}
		}
	}
}

StopMatch()
{
	g_bMatchStarting = false;
	g_bMatchRunning = false;

	g_CupReady1 = false;
	g_CupReady2 = false;

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		if (g_RunMode[id] != MODE_AGSTART)
			continue;

		g_RunMode[id] = MODE_NORMAL;
		g_RunModeStarting[id] = MODE_NORMAL;

		ShowMessage(id, "Race or match has ended");
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
		FreezePlayer(id);
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

	UnfreezePlayer(id);
}

FreezePlayer(id)
{
	set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);

	if (g_IsAgServer)
		set_bit(g_baIsAgFrozen, id);

	ShowPauseIcon(id + TASKID_ICON);
	set_task(2.0, "ShowPauseIcon", id + TASKID_ICON, _, _, "b");
}

UnfreezePlayer(id)
{
	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);

	if (g_IsAgServer)
		clr_bit(g_baIsAgFrozen, id);

	remove_task(id + TASKID_ICON);
}

public ShowPauseIcon(id)
{
	id -= TASKID_ICON;

	if (!pev_valid(id) || !IsPlayer(id))
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
	if (!pev_valid(id) || !IsPlayer(id))
		return HAM_IGNORED;

	if (pev(id, pev_flags) & FL_SPECTATOR)
	{
		// Players in AG are set in an observer mode when joining a server,
		// and they are able to press buttons, and then they will spawn as they
		// have just pressed one of the keys that makes you spawn. So we check
		// if they're in that state here. Could also check if they have spawned,
		// but this will do it for now
		return HAM_IGNORED;
	}

	new BUTTON_TYPE:type = GetEntityButtonType(ent);
	switch (type)
	{
		case BUTTON_START:
		{
			// Player has gone through the start zone. We need this validation for custom starts
			// because in agstart or NR you can now start at the custom start position, and the
			// timer starts automatically. We're enabling the use of custom starts because a cup
			// may have standstill start among the rules, so in that case in maps with start zones
			// it's a bit of a hassle to start without prespeed, so we allow using custom starts
			// and this validation is needed so that you don't place a custom start position close
			// to the end or something
			g_IsValidStart[id] = true;

			StartClimb(id);
		}
		case BUTTON_FINISH:
		{
			new Float:origin[3];
			fm_get_brush_entity_origin(ent, origin); // find origin of button for fireworks

			g_PrevButtonOrigin[0] = origin[0];
			g_PrevButtonOrigin[1] = origin[1];
			g_PrevButtonOrigin[2] = origin[2];

			FinishClimb(id);
		}
		case BUTTON_SPLIT:
		{
			SplitTime(id, ent);
		}
		case BUTTON_NOT: CheckRunReqs(ent, id);
	}

	return HAM_IGNORED;
}

BUTTON_TYPE:GetEntityButtonType(ent)
{
	static name[32];
	static pevsToCheck[] = {pev_target, pev_targetname};

	for (new i = 0; i < sizeof(pevsToCheck); i++)
	{
		pev(ent, pevsToCheck[i], name, charsmax(name));
		if (name[0])
		{
			new BUTTON_TYPE:type = GetButtonTypeFromName(name);

			if (type != BUTTON_NOT)
				return type;
		}
	}

	new split[SPLIT];
	if (GetSplitByEntityId(ent, split))
	{
		return BUTTON_SPLIT;
	}

	return BUTTON_NOT;
}

bool:IsStartEntityName(name[])
{
	for (new i = 0; i < sizeof(g_szStarts); i++)
	{
		if (containi(name, g_szStarts[i]) != -1)
		{
			return true;
		}
	}

	return false;
}

bool:IsStopEntityName(name[])
{
	for (new i = 0; i < sizeof(g_szStops); i++)
	{
		if (containi(name, g_szStops[i]) != -1)
		{
			return true;
		}
	}

	return false;
}

BUTTON_TYPE:GetButtonTypeFromName(name[])
{
	if (IsStartEntityName(name))
	{
		return BUTTON_START;
	}
	else if (IsStopEntityName(name))
	{
		return BUTTON_FINISH;
	}

	return BUTTON_NOT;
}

CheckRunReqs(ent, id)
{
	new entId[6];
	num_to_str(ent, entId, charsmax(entId));

	new nextReqNumber = g_PlayerRunReqs[id];
	if (nextReqNumber == g_RunTotalReq)
		return; // already fulfilled every requirement

	if (!TrieKeyExists(g_RunReqs, entId))
		return; // this is not a requirement

	new nextReqIdx = ArrayGetCell(g_SortedRunReqIndexes, nextReqNumber);
	new entReqIdx;
	TrieGetCell(g_RunReqs, entId, entReqIdx);

	if (entReqIdx != nextReqIdx)
		return; // this is not the next requirement in the run

	new hasPlayerFulfilledReq = false;
	TrieGetCell(g_FulfilledRunReqs[id], entId, hasPlayerFulfilledReq);
	if (hasPlayerFulfilledReq)
		return; // you already completed this requirement

	// Requirement fulfilled
	g_PlayerRunReqs[id]++;
	TrieSetCell(g_FulfilledRunReqs[id], entId, true);

	ShowMessage(id, "Requirement #%d completed", g_PlayerRunReqs[id]);
}



//*******************************************************
//*                                                     *
//* Hud display                                         *
//*                                                     *
//*******************************************************

public Fw_FmThinkPre(ent)
{

	if (ent == g_TaskEnt)
	{
		// Hud update task
		static Float:currGameTime;
		currGameTime = get_gametime();
		UpdateHud(currGameTime);
		set_pev(ent, pev_nextthink, currGameTime + HUD_UPDATE_TIME);
	}
}

UpdateHud(Float:currGameTime)
{
	static Float:kztime, min, sec, mode, targetId, ent, body;
	static players[MAX_PLAYERS], playersNum, id, i, playerName[33];
	static specHud[1280];

	get_players(players, playersNum);

	for (i = 0; i < playersNum; i++)
	{
		id = players[i];
		GetColorlessName(id, playerName, charsmax(playerName));

		// HUD for custom votes
		if (g_IsKzVoteRunning[id] && !g_IsKzVoteIgnoring[id] && g_IsKzVoteVisible[id])
		{
			new Float:voteCountdown = (g_KzVoteStartTime[id] + get_pcvar_float(pcvar_kz_vote_hold_time)) - currGameTime;
			if (voteCountdown > 0.0)
			{
				new voteMsg[1424], voteCallerName[33];
				GetColorlessName(g_KzVoteCaller[id], voteCallerName, charsmax(voteCallerName));

				if (equal(g_KzVoteSetting[id], "race"))
				{
					// This is for race votes, loop through players once out here and then it's the same HUD text for everyone
					new raceCandidatesText[1360];
					GetRaceCandidates(raceCandidatesText, charsmax(raceCandidatesText), g_KzVoteCaller[id], players, playersNum);
					formatex(voteMsg, charsmax(voteMsg), "%s wants to race in %d\nRunners:\n%s", voteCallerName, floatround(voteCountdown, floatround_tozero), raceCandidatesText);
				}
				// TODO: other votes


				set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], g_KzVotePosition[_:g_KzVoteAlignment[id]], 0.35, 0, 0.0, 999999.9, 0.0, 0.0, -1);
				ShowSyncHudMsg(id, g_SyncHudKzVote, voteMsg);
			}
			else
			{
				ClearSyncHud(id, g_SyncHudKzVote);

				if (g_KzVoteValue[id] == KZVOTE_YES)
				{
					if (equal(g_KzVoteSetting[id], "race"))
					{
						g_RaceId[id] = 0;
						StartRace(id);
					}
					else
					{
						// TODO: other votes
					}
				}
				EndKzVote(id);
			}
		}
		HudShowRun(id, currGameTime);

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
			ClearSyncHud(id, g_SyncHudSpeedometer);
			ClearSyncHud(id, g_SyncHudDistance);
			ClearSyncHud(id, g_SyncHudHeightDiff);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(targetId, g_SyncHudSpecList);
			ClearSyncHud(id, g_SyncHudRunStats);
		}
		if (g_LastTarget[id] != targetId)
		{
			// Clear hud if we are switching between different targets
			g_LastTarget[id] = targetId;
			ClearSyncHud(id, g_SyncHudTimer);
			ClearSyncHud(id, g_SyncHudKeys);
			ClearSyncHud(id, g_SyncHudSpeedometer);
			ClearSyncHud(id, g_SyncHudDistance);
			ClearSyncHud(id, g_SyncHudHeightDiff);
			ClearSyncHud(id, g_SyncHudSpecList);
			ClearSyncHud(targetId, g_SyncHudSpecList);
			ClearSyncHud(id, g_SyncHudRunStats);
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
						set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], 0.75, 0.15, 0, 0.0, 999999.0, 0.0, 0.0, -1);
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
				case BUTTON_SPLIT: ShowInHealthHud(id, "SPLIT");
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
			kztime = get_bit(g_baIsPaused, targetId) ? g_PlayerTimePause[targetId] - g_PlayerTime[targetId] : currGameTime - g_PlayerTime[targetId];

			min = floatround(kztime / 60.0, floatround_floor);
			sec = floatround(kztime - min * 60.0, floatround_floor);

			if (g_CpCounters[targetId][COUNTER_CP] || g_CpCounters[targetId][COUNTER_TP])
				g_RunType[targetId] = "Noob";
			else if (get_bit(g_baIsPureRunning, targetId))
				g_RunType[targetId] = "Pure";
			else
				g_RunType[targetId] = "Pro";

			new reqsText[16];
			if (g_RunTotalReq)
				formatex(reqsText, charsmax(reqsText), " | Reqs: %d/%d", g_PlayerRunReqs[targetId], g_RunTotalReq);

			new lapsText[17];
			if (g_RunLaps)
				formatex(lapsText, charsmax(lapsText), " | Lap: %d/%d", g_CurrentLap[targetId], g_RunLaps);

			new splitText[18];
			if (ArraySize(g_OrderedSplits))
			{
				new ongoingSplit = ArraySize(g_SplitTimes[targetId]) + 1;
				if (ongoingSplit > ArraySize(g_OrderedSplits))
					ongoingSplit -= ArraySize(g_OrderedSplits); // instead of "Split: 4/3", make it "Split: 1/3"

				formatex(splitText, charsmax(splitText), " | Split: %d/%d", ongoingSplit, ArraySize(g_OrderedSplits));
			}

			new runModeText[16];
			if (g_RunMode[targetId] != MODE_NORMAL)
				formatex(runModeText, charsmax(runModeText), " %s", g_RunModeString[_:g_RunMode[targetId]]);

			new timerText[128];
			formatex(timerText, charsmax(timerText), "%s%s run | Time: %02d:%02d | CPs: %d | TPs: %d%s%s%s%s",
					g_RunType[targetId], runModeText, min, sec, g_CpCounters[targetId][COUNTER_CP], g_CpCounters[targetId][COUNTER_TP],
					reqsText, lapsText, splitText, get_bit(g_baIsPaused, targetId) ? " | *Paused*" : "");

			switch (g_ShowTimer[id])
			{
			case 1:
				{
					client_print(id, print_center, timerText);
				}
			case 2:
				{
					set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.1, 0, 0.0, 999999.0, 0.0, 0.0, -1);
					ShowSyncHudMsg(id, g_SyncHudTimer, timerText);
				}
			}
		}

		if (g_ShowSpeed[id])
		{
			set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.7, 0, 0.0, 999999.0, 0.0, 0.0, -1);
			if (is_user_alive(id))
				ShowSyncHudMsg(id, g_SyncHudSpeedometer, "%.2f", xs_vec_len_2d(g_Velocity[id]));
			else
			{
				new specmode = pev(id, pev_iuser1);
				if (specmode == OBS_CHASE_FREE || specmode == OBS_IN_EYE)
				{
					new t = pev(id, pev_iuser2);
					ShowSyncHudMsg(id, g_SyncHudSpeedometer, "%.2f", xs_vec_len_2d(g_Velocity[t]));
				}
			}
		}

		if (g_ShowDistance[id])
		{
			set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.72, 0, 0.0, 999999.0, 0.0, 0.0, -1);
			new Float:distance;

			if (is_user_alive(id))
			{
				distance = GetDistancePlayerAiming(id);
				ShowSyncHudMsg(id, g_SyncHudDistance, "%.2f", distance);
			}
			else
			{
				new specmode = pev(id, pev_iuser1);
				if (specmode == OBS_CHASE_FREE || specmode == OBS_IN_EYE)
				{
					new t = pev(id, pev_iuser2);
					distance = GetDistancePlayerAiming(t);

					ShowSyncHudMsg(id, g_SyncHudDistance, "%.2f", distance);
				}
			}
		}

		if (g_ShowHeightDiff[id])
		{
			set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.74, 0, 0.0, 999999.0, 0.0, 0.0, -1);
			new Float:heightDiff;

			if (is_user_alive(id))
			{
				heightDiff = GetHeightDiffPlayerAiming(id);
				ShowSyncHudMsg(id, g_SyncHudHeightDiff, "%.2f", heightDiff);
			}
			else
			{
				new specmode = pev(id, pev_iuser1);
				if (specmode == OBS_CHASE_FREE || specmode == OBS_IN_EYE)
				{
					new t = pev(id, pev_iuser2);
					heightDiff = GetHeightDiffPlayerAiming(t);

					ShowSyncHudMsg(id, g_SyncHudHeightDiff, "%.2f", heightDiff);
				}
			}
		}

		// Boring code because the approach of broadcasting the update from FinishTimer() failed, and i couldn't see why
		new bool:shouldUpdateRunStatsHud;
		if (!g_ShowRunStatsOnHud[id])
		{
			// This player doesn't want to see run stats on HUD
			shouldUpdateRunStatsHud = false;
		}
		else if (((g_RunStatsEndHudStartTime[targetId] + g_RunStatsHudHoldTime[id]) > currGameTime))
		{
			// We're in the moment to hold the stats HUD for a bit as the run
			// has just ended and you need some time to see the stats
			if (!g_RunStatsEndHudShown[targetId])
			{
				// Updated end stats haven't been shown yet, so we should show them
				shouldUpdateRunStatsHud = true;

				g_RunStatsEndHudShown[targetId] = true;
			}
			else
			{
				// We don't update anything yet, we have to hold the stats on screen due to the run end
				shouldUpdateRunStatsHud = false;
			}
		}
		else if (g_ShowRunStatsOnHud[id] >= 2)
		{
			// Keep updating stats in realtime
			shouldUpdateRunStatsHud = true;
		}

		if (shouldUpdateRunStatsHud)
		{
			if (g_ShowRunStatsOnHud[id] == 1)
			{
				// Player finishing a run while the previous stats HUD is still on screen
				ClearSyncHud(id, g_SyncHudRunStats);
			}

			new runStats[768];
			GetRunStatsHudText(targetId, runStats, charsmax(runStats), g_RunStatsHudDetailLevel[id]);
			set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], g_RunStatsHudX[id], g_RunStatsHudY[id], _, 0.0, 999999.0, _, 0.5);
			ShowSyncHudMsg(id, g_SyncHudRunStats, runStats);
		}
		else if (
		    g_ShowRunStatsOnHud[id] == 1
		&&  (g_RunStatsEndHudStartTime[targetId] + g_RunStatsHudHoldTime[id]) > currGameTime
		&&  (g_RunStatsEndHudStartTime[targetId] + g_RunStatsHudHoldTime[id] - (HUD_UPDATE_TIME * 2)) < currGameTime
		)
		{
			// Right before the hold time ends, we clear it
			ClearSyncHud(id, g_SyncHudRunStats);
		}
	}
}

GetRaceCandidates(raceCandidatesText[], len, caller, players[], playersNum)
{
	new playerName[33];
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		if (g_KzVoteCaller[id] != caller)
			continue; // assuming a player can only call a custom vote at a time, so this works as an identifier

		if (!g_IsKzVoteRunning[id] || g_IsKzVoteIgnoring[id] || !g_IsKzVoteVisible[id])
			continue;

		GetColorlessName(id, playerName, charsmax(playerName));
		format(raceCandidatesText, len, "%s%s: %s\n", raceCandidatesText, playerName, g_KzVoteValue[id] == KZVOTE_YES ? "Yes" : "No");
	}
}

HudShowRun(id, Float:currGameTime)
{
	//server_print("mode: %d, start: %.3f, next: %.3f, curr: %.3f", g_RunMode[id], g_RunStartTime[id], g_RunNextCountdown[id], currGameTime);
	if (g_RunStartTime[id])
	{
		if (g_RunStartTime[id] < currGameTime)
		{
			// Start the no-reset run or race
			StopCountdown(id);
			new RUN_MODE:runMode = g_RunModeStarting[id];
			g_RunStartTime[id] = 0.0;

			strip_user_weapons(id);
			ExecuteHamB(Ham_Spawn, id);
			amxclient_cmd(id, "fullupdate");

			StartClimb(id, true);

			g_RunMode[id] = runMode;
			g_RunModeStarting[id] = MODE_NORMAL;

			server_print("[%s] Starting a race in mode %s", PLUGIN_TAG, g_RunModeString[_:g_RunMode[id]]);
		}
		else if (g_RunNextCountdown[id] && g_RunNextCountdown[id] < currGameTime)
		{
			RunCountdown(id, currGameTime, g_RunStartTime[id], g_RunCountdown[id], true);

			// Also show countdown to the ones spectating him
			new players[MAX_PLAYERS], playersNum;
			get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
			for (new i = 0; i < playersNum; i++)
			{
				new id2 = players[i];

				if (pev(id2, pev_iuser1) == OBS_IN_EYE && pev(id2, pev_iuser2) == id)
				{
					RunCountdown(id2, currGameTime, g_RunStartTime[id], g_RunCountdown[id], true);
				}
			}
		}
	}
}

RunCountdown(id, Float:currGameTime, Float:runStartTime, Float:totalCountdownTime, bool:isNoReset)
{
	//server_print("noreset: %d, runStartTime: %.3f, totalCountdownTime: %.3f, currGameTime: %.3f", isNoReset, runStartTime, totalCountdownTime, currGameTime, isNoReset);
	new countdownNumber       = floatround(runStartTime - currGameTime, floatround_tozero);
	new conditionsCheckSecond = floatround(totalCountdownTime, floatround_tozero) - MATCH_START_CHECK_SECOND;

	if (conditionsCheckSecond < 0)
		conditionsCheckSecond = 0;

	g_RunNextCountdown[id] += 1.0;

	//client_print(id, print_chat, "counting down... %d", countdownNumber);

	if (g_IsAgClient)
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgCountdown, _, id);
		write_byte(countdownNumber);	// countdown countdownNumber
		write_byte(1);					// emit sound for countdown?
		write_string("");				// player 1 (used for round-based gametypes, ignored here)
		write_string("");				// player 2 (same as above, ignored)
		message_end();
	}
	else
	{
		set_dhudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], _, 0.35, 0, 0.0, 0.999 - HUD_UPDATE_TIME, 0.0, 0.0);
		show_dhudmessage(id, "%d", countdownNumber);

		if (sizeof(g_CountdownSounds) > countdownNumber && countdownNumber >= 0)
			client_cmd(id, "spk \"%s\"", g_CountdownSounds[countdownNumber]);
	}

	if (countdownNumber == conditionsCheckSecond)
	{
		if (CanTeleport(id, CP_TYPE_START, false) || CanTeleport(id, CP_TYPE_DEFAULT_START, false)
			|| (CanTeleport(id, CP_TYPE_CUSTOM_START) && g_usesStartingZone))
		{
			if (g_TpOnCountdown[id])
			{
				if (CanTeleport(id, CP_TYPE_CUSTOM_START, false) && g_usesStartingZone)
					Teleport(id, CP_TYPE_CUSTOM_START);
				else if (CanTeleport(id, CP_TYPE_START, false))
					Teleport(id, CP_TYPE_START);
				else if (CanTeleport(id, CP_TYPE_DEFAULT_START, false))
					Teleport(id, CP_TYPE_DEFAULT_START);
			}
		}
		else
		{
			// The ShowMessage doesn't actually seem to appear, maybe because the HUD is reset upon switching to spectator
			// or something, so showing this chat print instead
			client_print(id, print_chat, "[%s] You have to press the start button before starting the match!", PLUGIN_TAG);

			ResetPlayer(id);

			if (isNoReset)
			{
				g_RunModeStarting[id] = MODE_NORMAL;
				g_RunStartTime[id] = 0.0;
				g_RunNextCountdown[id] = 0.0;
			}
		}
	}

	if (countdownNumber == 0)
	{
		if (isNoReset)
		{
			g_RunNextCountdown[id] = 0.0;
		}
		// TODO: reset the nextCountdown for races, or refactor and actually use a common variable, as no 2 countdowns can be running at a time?
	}
}

StopCountdown(id)
{
	if (g_IsAgClient)
	{
		// We hide the countdown number at the center, otherwise the last number (0) will stay there for a while
		message_begin(MSG_ONE_UNRELIABLE, g_MsgCountdown, _, id);
		write_byte(-1);		// countdown number
		write_byte(0);		// emit sound for countdown?
		write_string("");	// player 1 (used for round-based gametypes, ignored here)
		write_string("");	// player 2 (same as above, ignored)
		message_end();
	}
	// else the number is gone soon automatically as per the holdtime set in the DHUD message
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

CheckSettings(id)
{
	if (areColorsZeroed(id))
	{
		// The settings bug occurred, for the moment just gonna restore the important settings and log the incident
		new name[32];
		GetColorlessName(id, name, charsmax(name));
		// TODO: replace with log_amx()?
		log_to_file(HLKZ_LOG_FILENAME, "ERROR | CheckSettings() | Settings bug detected on player with ID %s and nickname %s", g_UniqueId[id], name);

		g_ShowTimer[id] = g_PrevShowTimer[id];
		g_TimeDecimals[id] = g_PrevTimeDecimals[id];
		g_HudRGB[id][0] = g_PrevHudRGB[id][0];
		g_HudRGB[id][1] = g_PrevHudRGB[id][1];
		g_HudRGB[id][2] = g_PrevHudRGB[id][2];
		g_RunCountdown[id] = g_PrevRunCountdown[id];

		// Try to load settings again
		set_task(1.5, "ReloadPlayerSettings", id + TASKID_RELOAD_PLAYER_SETTINGS);
	}
}

bool:areColorsZeroed(id)
{
	// If all of the colors have been reset, it means the bug with settings happened...
	// because within the plugin we don't let players to set RGB 0 0 0, as the hud becomes
	// invisible, but we do let them set something that is ALMOST invisible
	return !g_HudRGB[id][0] && !g_HudRGB[id][1] && !g_HudRGB[id][2];
}

BuildRunStats(id)
{
	new frameNumberForSpeed = -1;
	if (g_RunFrames[id])
		frameNumberForSpeed = ArraySize(g_RunFrames[id]) - RUN_STATS_SPEED_FRAME_OFFSET - 1;

	// Get some stuff from frames that have already been stored for the replay
	new prevButtons, Float:prevTime, Float:prevSpeed;
	if (g_RunFrames[id] && ArraySize(g_RunFrames[id]) > 1)
	{
		new frameState[REPLAY];
		ArrayGetArray(g_RunFrames[id], ArraySize(g_RunFrames[id]) - 2, frameState);

		prevButtons = frameState[RP_BUTTONS];
		prevTime    = frameState[RP_TIME];

		if (ArraySize(g_RunFrames[id]) > RUN_STATS_SPEED_FRAME_OFFSET)
		{
			ArrayGetArray(g_RunFrames[id], frameNumberForSpeed, frameState);
			prevSpeed = frameState[RP_SPEED];
		}
	}

	new flags    = pev(id, pev_flags);
	new buttons  = pev(id, pev_button);
	new moveType = pev(id, pev_movetype);

	if (get_bit(g_baIsPureRunning, id) && xs_vec_equal(g_ControlPoints[id][CP_TYPE_START][CP_ORIGIN], g_Origin[id]))
	{
		// Not moving yet, we're losing time at the start button!
		new Float:secondFrameTime, Float:lastFrameTime;
		if (g_RunFrames[id] && ArraySize(g_RunFrames[id]) > 1)
		{
			new frameState[REPLAY];
			ArrayGetArray(g_RunFrames[id], ArraySize(g_RunFrames[id]) - 1, frameState);
			lastFrameTime = frameState[RP_TIME];

			ArrayGetArray(g_RunFrames[id], 1, frameState);
			secondFrameTime = frameState[RP_TIME];
		}
		// FIXME: we take the second frame's time because for some reason the first one doesn't work for this purpose,
		// even if we start with some prespeed it would still say 0.004 seconds lost at the start with 250 fps; so we
		// gotta investigate why at some point
		g_RunLostStartTime[id] = lastFrameTime - secondFrameTime;

		// TODO: make this stat available for pro runs that for some reason don't start with prespeed
	}

	if ((moveType == MOVETYPE_WALK) && (g_PrevFlags[id] & FL_ONGROUND_ALL && !(flags & FL_ONGROUND_ALL)))
	{
		new bool:isInitialPrestrafeDone = false;

		if (!(prevButtons & IN_JUMP) && (buttons & IN_JUMP))
		{
			if (g_RunJumps[id] == 0 && g_RunDucktaps[id] == 0)
				isInitialPrestrafeDone = true;

			g_Movement[id] = MOVEMENT_JUMPING;
			g_RunJumps[id]++;
		}
		else if ((prevButtons & IN_DUCK) && !(buttons & IN_DUCK))
		{
			if (g_RunJumps[id] == 0 && g_RunDucktaps[id] == 0)
			{
				// Probably an initial countjump
				isInitialPrestrafeDone = true;
			}

			g_Movement[id] = MOVEMENT_DUCKTAPPING;
			g_RunDucktaps[id]++;
		}

		if (isInitialPrestrafeDone)
		{
			// TODO: handle pure starts with prespeed, like in the hl1_bhop maps, with a start trigger instead button
			g_RunStartPrestrafeSpeed[id] = xs_vec_len_2d(g_Velocity[id]);
			g_RunStartPrestrafeTime[id]  = get_gametime() - g_PlayerTime[id];
		}
	}
	else
	{
		g_Movement[id] = MOVEMENT_OTHER;
	}

	g_RunDistance2D[id] += xs_vec_distance_2d(g_PrevOrigin[id], g_Origin[id]);
	g_RunDistance3D[id] += get_distance_f(g_PrevOrigin[id], g_Origin[id]);

	g_RunCurrSpeed[id] = xs_vec_len_2d(g_Velocity[id]);

	if (g_RunMaxSpeed[id] < g_RunCurrSpeed[id])
		g_RunMaxSpeed[id] = g_RunCurrSpeed[id];

	new Float:kzTime = get_gametime() - g_PlayerTime[id];
	if (kzTime)
	{
		g_RunAvgSpeed[id] = g_RunDistance2D[id] / kzTime;

		if (g_RunFrameCount[id])
			g_RunAvgFps[id] = g_RunFrameCount[id] / kzTime;
	}

	// Get the last 30th frame and the last one, to get the average of the last frames
	// TODO: this won't work if the run is less than 30 frames long, but getting an average of less frames might yield bad results,
	// lower min fps, because shit happens like getting a frame that is the same time as the previous one which brings down the average
	// a lot, so the min fps of the first frames (when there aren't 30 frames yet) might never get overwritten afterwards as it would
	// be hard to have a lower min fps when taking more frames into account. This is only my guess anyways
	if (g_RunFrames[id] && ArraySize(g_RunFrames[id]) > RUN_STATS_MIN_FPS_AVG_FRAMES)
	{
		// FIXME: this feature only works if demo recording is ON... so it won't show for bots?
		new frameState[REPLAY];
		ArrayGetArray(g_RunFrames[id], ArraySize(g_RunFrames[id]) - RUN_STATS_MIN_FPS_AVG_FRAMES - 1, frameState);

		new Float:fpsAvg = 1.0 / ((get_gametime() - frameState[RP_TIME]) / float(RUN_STATS_MIN_FPS_AVG_FRAMES));
		if (!g_RunMinFps[id] || (g_RunMinFps[id] > fpsAvg))
			g_RunMinFps[id] = fpsAvg;
	}

	if (xs_vec_distance(g_Origin[id], g_EndButtonOrigin) <= PLAYER_USE_RADIUS)
	{
		g_RunLostEndTime[id] += (get_gametime() - prevTime);
	}

	if (frameNumberForSpeed > RUN_STATS_SPEED_FRAME_OFFSET)
	{
		if (!g_RunSlowdownLastFrameChecked[id]
			|| frameNumberForSpeed > (g_RunSlowdownLastFrameChecked[id] + RUN_STATS_SPEED_FRAME_COOLDOWN))
		{
			new Float:speedLoss = prevSpeed - g_RunCurrSpeed[id];

			if (speedLoss > 0.0)
			{
				// Lost some speed, check if it should be considered a slowdown
				new Float:lossFraction = speedLoss / prevSpeed;

				if (prevSpeed >= 300.0 && (lossFraction >= 0.1 || speedLoss >= 30.0))
				{
					g_RunSlowdowns[id]++;
					g_RunSlowdownLastFrameChecked[id] = frameNumberForSpeed;
				}
			}
		}

	}
}

GetRunStatsHudText(id, text[], len, detailLevel)
{
	if (detailLevel >= 1)
	{
		format(text, len, "%sAvg speed: %.2f\n",             text, g_RunAvgSpeed[id]);
	}

	format(text, len, "%sMax speed: %.2f\n",                 text, g_RunMaxSpeed[id]);
	format(text, len, "%sEnd speed: %.2f\n",                 text, g_RunCurrSpeed[id]);

	if (detailLevel >= 1)
	{
		format(text, len, "%sAvg fps: %.2f\n",               text, g_RunAvgFps[id]);
		format(text, len, "%sMin fps: %.2f\n",               text, g_RunMinFps[id]);
	}
	format(text, len, "%sDistance: %.2f\n",                  text, g_RunDistance2D[id]);

	if (detailLevel >= 2)
	{
		format(text, len, "%sDistance 3D: %.2f\n",           text, g_RunDistance3D[id]);
	}

	format(text, len, "%sJumps: %d\n",                       text, g_RunJumps[id]);
	format(text, len, "%sDucktaps: %d\n",                    text, g_RunDucktaps[id]);

	//if (detailLevel >= 2)
	//{
	//	format(text, len, "%sStrafes: %d\n",                 text, g_RunStrafes[id]);
	//}

	//if (detailLevel >= 1)
	//{
	//	format(text, len, "%sSync: %d\n",                    text, g_RunSync[id]);
	//}

	format(text, len, "%sSlowdowns: %d\n",                   text, g_RunSlowdowns[id]);

	if (detailLevel >= 1)
	{
		format(text, len, "%sTime lost at start: %.4f\n",    text, g_RunLostStartTime[id]);
		format(text, len, "%sTime lost at end: %.4f\n",      text, g_RunLostEndTime[id]);
		format(text, len, "%sStart prestrafe speed: %.2f\n", text, g_RunStartPrestrafeSpeed[id]);
		format(text, len, "%sStart prestrafe time: %.4f\n",  text, g_RunStartPrestrafeTime[id]);
	}
}

HudStorePressedKeys(id)
{
	if (!get_pcvar_num(pcvar_kz_show_keys))
		return;

	static Float:currGameTime;
	currGameTime = get_gametime();

	static button;
	button = pev(id, pev_button);

	// Prolong Jump key show
	if (button & IN_JUMP)
		g_LastPressedJump[id] = currGameTime;
	else if (currGameTime > g_LastPressedJump[id] && currGameTime - g_LastPressedJump[id] < HUD_UPDATE_TIME)
		button |= IN_JUMP;

	// Prolong Duck key show
	if (button & IN_DUCK)
		g_LastPressedDuck[id] = currGameTime;
	else if (currGameTime > g_LastPressedDuck[id] && currGameTime - g_LastPressedDuck[id] < HUD_UPDATE_TIME)
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

	set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, -1.0, 0, _, 999999.0, _, _, -1);
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
			set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.89, 0, 0.0, 2.0, 0.0, 1.0, 4);
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

	set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], -1.0, 0.92, 0, _, 2.0, _, _, -1);
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

	FreezePlayer(id);
}

public Fw_HamKilledPlayerPre(victim, killer, shouldgib)
{
	if (!IsPlayer(victim))
		return;

	clr_bit(g_bit_is_alive, victim);

	// Clear freeze to allow correct animation of the corpse
	if (!get_bit(g_baIsPaused, victim))
		return;

	UnfreezePlayer(victim);
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

	if (IsPlayer(victim) && pev_valid(aggressor) && !IsPlayer(aggressor))
	{
		new Float:currVelocity[3], Float:currTotalSpeed;
		pev(victim, pev_velocity, currVelocity);
		currTotalSpeed = xs_vec_len(currVelocity);

		new entityName[32], victimName[32];
		pev(aggressor, pev_classname, entityName, charsmax(entityName));
		GetColorlessName(victim, victimName, charsmax(victimName));

		new idx = ArrayFindValue(g_DamagedByEntity[victim], aggressor);
		if (idx != -1)
		{
			if (aggressor != 0 && damage > 0.0 && (Float:ArrayGetCell(g_DamagedTimeEntity[victim], idx) + TRIGGER_HURT_DAMAGE_TIME) > get_gametime())
			{
				// We have already been damaged by this entity less than 0.5 seconds ago, so ignore this damage...
				// Case: players receiving 100 damage from a 10 damage trigger_hurt, in a few frames...
				// We don't ignore:
				// * Falldamage (aggressor == 0 == worldspawn)
				// * Healthboost damage (negative damage)
				if (!equal(entityName, "trigger_hurt"))
				{
					// Unexpected entity dealing damage with too much frequency, let's see what it is
					server_print("[%s] [t=%.4f] Avoided receiving too many damage ticks for %s, would have gotten %.1f damage from %s",
						PLUGIN_TAG, get_gametime(), victimName, damage, entityName);
				}
				return HAM_SUPERCEDE;
			}
			else
			{
				// Update the damage time and speed
				ArraySetCell(g_DamagedTimeEntity[victim], idx, get_gametime());
				ArraySetCell(g_DamagedPreSpeed[victim], idx, currTotalSpeed);
			}
		}
		else
		{
			// First time we get damage from this entity, so register some data about it
			ArrayPushCell(g_DamagedByEntity[victim], aggressor);
			ArrayPushCell(g_DamagedTimeEntity[victim], get_gametime());
			ArrayPushCell(g_DamagedPreSpeed[victim], currTotalSpeed);
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

	// Check if the player is gaining too much speed from this damage tick... filter out falldamage
	if (IsPlayer(victim) && !IsPlayer(aggressor) && aggressor != 0)
	{
		new idx = ArrayFindValue(g_DamagedByEntity[victim], aggressor);
		if (idx == -1)
		{
			server_print("[%s] Aggressor entity %d not found. Review why it didn't get registered in pre TakeDamage", PLUGIN_TAG, aggressor);
			return;
		}
		new Float:prevTotalSpeed = Float:ArrayGetCell(g_DamagedPreSpeed[victim], idx);

		new Float:currVelocity[3], Float:currTotalSpeed;
		pev(victim, pev_velocity, currVelocity);
		currTotalSpeed = xs_vec_len(currVelocity);

		new Float:overspeed = currTotalSpeed - (prevTotalSpeed + get_pcvar_float(pcvar_kz_pure_max_damage_boost));
		if (overspeed > 0.0)
		{
			// Downgrade run to Pro
			clr_bit(g_baIsPureRunning, victim);
		}
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

public Fw_FmKeyValuePre(ent, kvd)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	static className[32];
	pev(ent, pev_classname, className, charsmax(className));

	if (equali(className, "trigger_multiple"))
	{
		GetSplitsFromMap(ent, kvd);
		GetRequirementsFromMap(ent, kvd);
	}
	else if (equali(className, "func_button"))
	{
		GetRequirementsFromMap(ent, kvd);
	}
	// TODO: review if there are more entities to account for regarding requirements,
	// and maybe refactor this if it gets too big. Can we just check in 

	return FMRES_IGNORED;
}

/**
 * Gets and stores splits that were created directly in the map (compiled with them),
 * via trigger_multiple entities with specific properties. This will get called
 * for each key->value pair of any trigger_multiple
 */
GetSplitsFromMap(ent, kvd)
{
	new key[32], value[32], split[SPLIT];
	get_kvd(kvd, KV_KeyName, key, charsmax(key));
	get_kvd(kvd, KV_Value, value, charsmax(value));

	if (!GetSplitByEntityId(ent, split))
	{
		split[SPLIT_ENTITY] = ent;
	}

	if (equal(key, "split_id"))
	{
		copy(split[SPLIT_ID], charsmax(split[SPLIT_ID]), value);

		// Now that we have the proper split id, we remove the entry for this split
		// that has the entity id as the key, and a new entry will be created later with the split id as the key instead
		new entityId[5];
		num_to_str(ent, entityId, charsmax(entityId));
		TrieDeleteKey(g_Splits, entityId);
	}
	else if (equal(key, "split_name"))
	{
		copy(split[SPLIT_NAME], charsmax(split[SPLIT_NAME]), value);
	}
	else if (equal(key, "split_next"))
	{
		copy(split[SPLIT_NEXT], charsmax(split[SPLIT_NEXT]), value);
	}
	else if (equal(key, "split_lap_start"))
	{
		split[SPLIT_LAP_START] = true;
	}
	else if (equal(key, "run_laps"))
	{
		g_RunLaps = str_to_num(value);
	}
	else
	{
		// Nothing to do, it's a normal trigger_multiple property that we don't need
		return;
	}

	new trieKey[32];

	// The trie key will be either the split_id value if we already got it, or the entity number (stringified)
	if (split[SPLIT_ID][0])
		copy(trieKey, charsmax(trieKey), split[SPLIT_ID]);
	else
		num_to_str(ent, trieKey, charsmax(trieKey));

	//server_print("[GetSplits] trieKey: %s | key: %s | value: %s", trieKey, key, value);

	TrieSetArray(g_Splits, trieKey, split, sizeof(split));
}

GetRequirementsFromMap(ent, kvd)
{
	new key[32], value[32], split[SPLIT];
	get_kvd(kvd, KV_KeyName, key, charsmax(key));
	get_kvd(kvd, KV_Value, value, charsmax(value));

	if (equal(key, "requirement_id"))
	{
		// We want to save it with the `targetname` instead of entity id, but that keyvalue will come
		// either after or before this `requirement_id`, so we'll replace these stringified entity
		// ids later when all of these entity keyvalues have been processed
		new entId[6];
		new reqIdx = str_to_num(value);

		num_to_str(ent, entId, charsmax(entId));
		TrieSetCell(g_RunReqs, entId, reqIdx);

		server_print("Ent %d has a requirement id %d", ent, reqIdx);
	}

}

public Fw_FmClientKillPre(id)
{
	if (get_pcvar_num(pcvar_kz_nokill) || g_RunMode[id] != MODE_NORMAL || g_RunModeStarting[id] != MODE_NORMAL)
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
	static count, sound;
	count = get_msg_arg_int(1);
	sound = get_msg_arg_int(2);

	g_bMatchStarting = true;

	if (count != -1 || sound != 0)
	{
		new conditionsCheckSecond = floatround(AG_COUNTDOWN, floatround_tozero) - MATCH_START_CHECK_SECOND;
		if (count == conditionsCheckSecond)
		{
			// Not doing the call instantly, because it crashes the server with this error message:
			// "New message started when msg '98' has not been sent yet"
			set_task(0.000001, "CheckAgstartConditions", TASKID_MATCH_START_CHECK);
		}
		return;
	}

	// Start the timer, disable pause/reset/start button/commands
	g_bMatchStarting = false;
	g_bMatchRunning = true;
	for (new i = 1; i <= g_MaxPlayers; i++)
	{
		if (g_IsBannedFromMatch[i])
			continue; // don't start the timer for these; TODO: maybe ResetPlayer(i)?

		if (is_user_alive(i) && pev(i, pev_iuser1) == OBS_NONE)
		{
			server_print("[%s] Starting match (agstart)", PLUGIN_TAG);

			g_IsValidStart[i] = false;

			AgstartClimb(i);

			if (get_pcvar_num(pcvar_kz_noreset_agstart))
				g_RunMode[i] = MODE_NORESET; // TODO: maybe it's better to keep it as MODE_AGSTART and take into account the cvar elsewhere
			else
				g_RunMode[i] = MODE_AGSTART;

			g_RaceId[i] = 0; // reset this in case they were starting a race and suddenly an agstart started

			g_RecordRun[i] = 1;
			g_RunFrames[i] = ArrayCreate(REPLAY);
			RecordRunFrame(i);
		}
	}
}

public Fw_MsgVote(id)
{
	static AGVOTE_STATUS:status, setting[32], value[32];

	status = AGVOTE_STATUS:get_msg_arg_int(1);
	get_msg_arg_string(5, setting, charsmax(setting));
	get_msg_arg_string(6, value,   charsmax(value));

	if (status == AGVOTE_CALLED)
		g_AgVoteRunning = true;
	else
	{
		g_AgVoteRunning = false;
		g_AgInterruptingVoteRunning = false;
	}

	if (!g_AgVoteRunning)
		return;

	if (containi(setting, "agstart") != -1 || containi(setting, "map") != -1 || containi(setting, "changelevel") != -1)
	{
		g_AgInterruptingVoteRunning = true;
	}
	else if (containi(setting, "mp_timelimit") != -1)
	{
		new Float:proposedTimelimit = GetFloatArg(value); // minutes

		new Float:timeleft  = get_cvar_float("mp_timeleft") / 60.0; // mp_timeleft comes in seconds
		new Float:timelimit = get_cvar_float("mp_timelimit"); // minutes

		if (IsAnyActiveNR() && proposedTimelimit && (proposedTimelimit < timelimit)
			&& (proposedTimelimit < (timelimit - timeleft + MIN_TIMELEFT_ALLOWED_NORESET)))
		{
			g_AgInterruptingVoteRunning = true;
		}
	}
	else
	{
		for (new i = 0; i < ArraySize(g_AgAllowedGamemodes); i++)
		{
			new gamemode[32];
			ArrayGetString(g_AgAllowedGamemodes, i, gamemode, charsmax(gamemode));

			if (containi(setting, gamemode) != -1)
			{
				g_AgInterruptingVoteRunning = true;
			}
		}
	}

	//server_print("[%.4f] Vote :: status = %d, setting = %s", get_gametime(), status, setting);
}

public Fw_MsgSettings(msg_id, msg_dest, msg_entity)
{
	static arg1;
	arg1 = get_msg_arg_int(1);
	if (arg1 == 0)
		StopMatch();
}

public Fw_FmGetGameDescriptionPre()
{
	forward_return(FMV_STRING, PLUGIN);
	return FMRES_SUPERCEDE;
}

public Fw_FmCmdStartPre(id, uc_handle, seed)
{
	g_FrameTimeMs[id][1] = g_FrameTimeMs[id][0];
	g_FrameTimeMs[id][0] = get_uc(uc_handle, UC_Msec);
	g_FrameTime[id] = g_FrameTimeMs[id][0] * 0.001;
	//g_Buttons[id] = get_uc(uc_handle, UC_Buttons);
	//g_Impulses[id] = get_uc(uc_handle, UC_Impulse);
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

public Fw_HamSpawnWeaponboxPost(weaponboxId)
{
	set_pev(weaponboxId, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, weaponboxId);

	return HAM_IGNORED;
}

//*******************************************************
//*                                                     *
//* Semiclip                                            *
//*                                                     *
//*******************************************************

public Fw_FmPlayerPreThinkPost(id)
{
	if (get_bit(g_baIsAgFrozen, id) && !(pev(id, pev_flags) & FL_FROZEN))
	{
		FreezePlayer(id);
	}

	g_bWasSurfing[id] = g_bIsSurfing[id];
	g_bIsSurfing[id] = false;
	g_bIsSurfingWithFeet[id] = false;
	g_hasSurfbugged[id] = false;
	g_hasSlopebugged[id] = false;

	if (g_RampFrameCounter[id] > 0)
		g_RampFrameCounter[id] -= 1;

	CheckSettings(id);

	// Copy some settings to be able to log when the bug with settings being zeroed happens mid-game
	g_PrevRunCountdown[id] = g_RunCountdown[id];
	g_PrevShowTimer[id] = g_ShowTimer[id];
	g_PrevTimeDecimals[id] = g_TimeDecimals[id];
	g_PrevHudRGB[id][0] = g_HudRGB[id][0];
	g_PrevHudRGB[id][1] = g_HudRGB[id][1];
	g_PrevHudRGB[id][2] = g_HudRGB[id][2];

	xs_vec_copy(g_Origin[id],   g_PrevOrigin[id]);
	xs_vec_copy(g_Velocity[id], g_PrevVelocity[id]);

	pev(id, pev_origin, g_Origin[id]);
	pev(id, pev_angles, g_Angles[id]);
	pev(id, pev_view_ofs, g_ViewOfs[id]);
	pev(id, pev_velocity, g_Velocity[id]);
	g_Buttons[id] = pev(id, pev_button);
	//console_print(id, "sequence: %d, pev_gaitsequence: %d", pev(id, pev_sequence), pev(id, pev_gaitsequence));

	// Store pressed keys here, cos HUD updating is called not so frequently
	HudStorePressedKeys(id);

	if (g_Unfreeze[id] > 3)
	{
		if (get_pcvar_num(pcvar_kz_spec_unfreeze))
			UnfreezeSpecCam(id);
		g_Unfreeze[id] = 0;
	}

	new Float:prevHSpeed = xs_vec_len_2d(g_PrevVelocity[id]);
	new Float:currHSpeed = xs_vec_len_2d(g_Velocity[id]);

	if ((prevHSpeed > 0.0 && currHSpeed == 0.0 && get_distance_f(g_Origin[id], g_PrevOrigin[id]) > 50.0)
		|| get_distance_f(g_Origin[id], g_PrevOrigin[id]) > 100.0) // Has teleported?
	{
		g_Unfreeze[id]++;
	}
	else if (g_Unfreeze[id])
		g_Unfreeze[id]++;

	// When a player dies, noclip apparently gets removed, and I don't know in what other cases it can get removed
	// So we track the state of it every frame... otherwise we could lose track and give them the noclipspeed when
	// they don't want to or in a way that it can be abused
	HandleNoclipCheating(id);

	if (g_IsInNoclip[id] || pev(id, pev_iuser1) == OBS_ROAMING)
		CheckNoclipSpeed(id);
	else
		CheckSpeedcap(id);

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
    }

}

HandleNoclipCheating(id)
{
	new isNoclip = get_user_noclip(id);
	if (isNoclip && !g_IsInNoclip[id])
	{
		// Player has just started noclipping
		set_bit(g_CheatCommandsGuard[id], CHEAT_NOCLIP);
	}
	else if (!isNoclip && g_IsInNoclip[id])
	{
		// Player has just stopped noclipping
		clr_bit(g_CheatCommandsGuard[id], CHEAT_NOCLIP);
	}
	g_IsInNoclip[id] = isNoclip;

	if (get_bit(g_CheatCommandsGuard[id], CHEAT_NOCLIP))
	{
		new ret;
		ExecuteForward(mfwd_hlkz_cheating, ret, id);
	}
}

CheckNoclipSpeed(id)
{
	if (!HasMovementKeys(g_Buttons[id]) || g_NoclipTargetSpeed[id] <= 0.0)
		return;

	new Float:allowedSpeed = get_pcvar_float(pcvar_kz_noclip_speed);
	if (allowedSpeed && g_NoclipTargetSpeed[id] > allowedSpeed)
		g_NoclipTargetSpeed[id] = allowedSpeed;

	new Float:addedVelocity[3], Float:totalVelocity[3], Float:inputAddedVelocity[3], Float:inputTotalVelocity[3];
	new Float:vAngles[3], Float:forwardMove[3], Float:rightMove[3];
	pev(id, pev_v_angle, vAngles);
	angle_vector(vAngles, ANGLEVECTOR_FORWARD, forwardMove);
	angle_vector(vAngles, ANGLEVECTOR_RIGHT, rightMove);
	
	new Float:input[3];
	if (g_Buttons[id] & IN_FORWARD)
		input[0]++;

	if (g_Buttons[id] & IN_BACK)
		input[0]--;

	if (g_Buttons[id] & IN_MOVELEFT)
		input[1]--;

	if (g_Buttons[id] & IN_MOVERIGHT)
		input[1]++;

	new Float:inputLen = xs_vec_len_2d(input);  // should we care about Z?
	new Float:auxSpeed = g_NoclipTargetSpeed[id];
	if (pev(id, pev_iuser1) != OBS_ROAMING)
	{
		// Game already moves you at sv_maxspeed when noclipping, so we have
		// to add speed on top of what the game already does, so if we want
		// 1000 speed and the normal noclip is 300, we have to handle the
		// movement for the remaining 700 speed
		// But spectator mode's Free Roaming is handled differently, we don't
		// need to do anything for that apparently, we handle the whole thing
		auxSpeed -= get_cvar_float("sv_maxspeed");
	}
	
	// If you're pressing forward and right with a noclip maxspeed of 800, the x velocity should be 565
	// and the y velocity 565 too, so that the total speed is 800; so that's what we do here
	for (new i = 0; i < 3; i++)
	{
		inputAddedVelocity[i] = (auxSpeed * input[i]) / inputLen;
		inputTotalVelocity[i] = (g_NoclipTargetSpeed[id] * input[i]) / inputLen;
	}

	// Then we have to account for the viewangles, so if you're looking upwards for example,
	// the forward movement gets translated to upwards velocity
	for (new i = 0; i < 3; i++)
	{
		addedVelocity[i] = forwardMove[i] * inputAddedVelocity[0] + rightMove[i] * inputAddedVelocity[1];
		totalVelocity[i] = forwardMove[i] * inputTotalVelocity[0] + rightMove[i] * inputTotalVelocity[1];
	}

	// Account for +moveup or +movedown i guess
	addedVelocity[2] += inputAddedVelocity[2];
	totalVelocity[2] += inputTotalVelocity[2];

	if (xs_vec_len(totalVelocity) <= 0.0)
		return;

	// Calculate the new origin with this extra speed
	xs_vec_add_scaled(g_Origin[id], addedVelocity, g_FrameTime[id], g_Origin[id]);
	set_pev(id, pev_origin, g_Origin[id]);

	// Update the velocity too so that the HUD shows it correctly (at least /speed, maybe not the client's hud_speedometer)
	xs_vec_copy(totalVelocity, g_Velocity[id]);
	set_pev(id, pev_velocity, totalVelocity);
}

CheckSpeedcap(id, bool:isAtStart = false)
{
	new Float:currVelocity[3];
	pev(id, pev_velocity, currVelocity);
	new Float:endSpeed = xs_vec_len_2d(currVelocity);

	new Float:speedcap = g_Speedcap[id];

	new Float:allowedSpeedcap = get_pcvar_float(pcvar_kz_speedcap);
	if (allowedSpeedcap > 0.0 && speedcap > allowedSpeedcap)
		speedcap = allowedSpeedcap;

	new shouldDowngradeRun = true;
	if (g_usesStartingZone && g_RunFrameCount[id] <= 2 && get_pcvar_num(pcvar_kz_pure_limit_zone_speed))
	{
		if ((isAtStart && g_Prespeedcap[id] > 0) || (!isAtStart && g_Prespeedcap[id] == 2))
		{
			// We're before the starting zone or inside it, and we have to limit the speed you have before starting the run
			new Float:prespeedcap = get_pcvar_float(pcvar_kz_pure_max_start_speed);

			if (prespeedcap != 0.0 && prespeedcap < 300.0)
			{
				// Probably missing config for this map, so set a reasonable prespeed limit
				prespeedcap = START_ZONE_ALLOWED_PRESPEED;
				set_pcvar_float(pcvar_kz_pure_max_start_speed, prespeedcap);
				server_print("[%s] Setting kz_pure_max_start_speed to %.1f due to missing or too low prespeed limit for a start zone", PLUGIN_TAG, prespeedcap);
			}

			if (prespeedcap > 0.0 && (speedcap == 0.0 || prespeedcap < speedcap))
			{
				// The cap for prespeed is lower than your speedcap, so use this as the cap, whichever is more restrictive
				speedcap = prespeedcap;
				shouldDowngradeRun = false;
			}
		}
	}

	if (speedcap > 0.0 && endSpeed > speedcap)
	{
		if (shouldDowngradeRun)
			clr_bit(g_baIsPureRunning, id);

		new Float:m = (endSpeed / speedcap) * 1.000001;
		new Float:cappedVelocity[3];
		cappedVelocity[0] = currVelocity[0] / m;
		cappedVelocity[1] = currVelocity[1] / m;
		cappedVelocity[2] = currVelocity[2];
		set_pev(id, pev_velocity, cappedVelocity);
	}
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
	new Float:endSpeed = xs_vec_len_2d(currVelocity);
	if (g_Slopefix[id])
	{
		new Float:currOrigin[3], Float:futureOrigin[3], Float:futureVelocity[3];
		pev(id, pev_origin, currOrigin);
		new Float:startSpeed = xs_vec_len_2d(g_Velocity[id]);

		new Float:svGravity = get_cvar_float("sv_gravity");
		new Float:pGravity;
		pev(id, pev_gravity, pGravity);

		futureOrigin[0] = currOrigin[0] + g_Velocity[id][0] * g_FrameTime[id];
		futureOrigin[1] = currOrigin[1] + g_Velocity[id][1] * g_FrameTime[id];
		futureOrigin[2] = currOrigin[2] + 0.4 + g_FrameTime[id] * (g_Velocity[id][2] - pGravity * svGravity * g_FrameTime[id] / 2);

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
	
	if (!g_IsInNoclip[id] && pev(id, pev_iuser1) != OBS_ROAMING)
		CheckSpeedcap(id);

	// TODO: refactor, same code in StartClimb(), but sometimes it doesn't work there...
	// e.g.: in kz_cargo, or hl1_bhop_oar_beta with normal /start, not custom or practice cp
	if (get_bit(g_baIsClimbing, id))
	{
		if (!g_RecordRun[id] && get_pcvar_num(pcvar_kz_autorecord) && !IsBot(id))
		{
			g_RecordRun[id] = 1;
			g_RunFrames[id] = ArrayCreate(REPLAY);
		}

		if (!IsBot(id) && g_RecordRun[id])
			RecordRunFrame(id);

		g_RunFrameCount[id]++;

		BuildRunStats(id);
	}

	g_PrevFlags[id] = pev(id, pev_flags);

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

/*
(Documentaion copied from HLSDK -> client.cpp -> AddToFullPack())

es is the server maintained copy of the state info that is transmitted to the client
a MOD could alter values copied into es to send the "host" a different look for a particular entity update, etc.
e and ent are the entity that is being added to the update, if 1 is returned
host is the player's edict of the player whom we are sending the update to
player is 1 if the ent/e is a player and 0 otherwise
pSet is either the PAS or PVS that we previous set up.  We can use it to ask the engine to filter the entity against the PAS or PVS.
we could also use the pas/ pvs that we set in SetupVisibility, if we wanted to.  Caching the value is valid in that case, but still only for the current frame
*/
public Fw_FmAddToFullPackPost(es, e, ent, host, hostflags, player, pSet)
{
	if (!IsConnected(host))
		return FMRES_IGNORED;

	if (!player)
	{
		if (get_bit(g_bit_waterinvis, host) && g_HideableEntity[ent])
		{
			set_es(es, ES_Effects, get_es(es, ES_Effects) | EF_NODRAW);
		}
		return FMRES_IGNORED;
	}
	else if (player && (g_Nightvision[host] == 1) && (ent == host))
		set_es(es, ES_Effects, get_es(es, ES_Effects) | EF_BRIGHTLIGHT);

	if (ent == host || IsHltv(host) || !IsConnected(ent) || !get_pcvar_num(pcvar_kz_semiclip) || pev(host, pev_iuser1) || !get_orig_retval())
		return FMRES_IGNORED;

	if(get_bit(g_bit_invis, host))
	{
		set_es(es, ES_RenderMode, kRenderTransTexture);
		set_es(es, ES_RenderAmt, 0);
		set_es(es, ES_Origin, { 999999999.0, 999999999.0, 999999999.0 } );
		// Reverted this change due to a player saying they can't hear their own jumps with the new version,
		// only happened to that player, but it needs more testing i guess
		//set_es(es, ES_Origin, { 8000.0, -8000.0, -8000.0 } );
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

SortSplits()
{
	new firstId[17], split[SPLIT];

	// Find the starting split, the one that marks the start/end of a lap
	new TrieIter:ti = TrieIterCreate(g_Splits);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetArray(ti, split, sizeof(split));

		if (IsFirstSplit(split))
		{
			copy(firstId, charsmax(firstId), split[SPLIT_ID]);
			ArrayPushString(g_OrderedSplits, split[SPLIT_ID]);

			break;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	if (!firstId[0])
	{
		// This map has no splits
		return;
	}

	// Splits have a property pointing to the next split a player should go through to continue the run
	// So we check that to jump from split to split, until the first split is found again or there's no next split
	do
	{
		if (FindNextSplit(split, split))
		{
			ArrayPushString(g_OrderedSplits, split[SPLIT_ID]);
		}
	}
	while (!equal(firstId, split[SPLIT_NEXT]));
}

bool:IsFirstSplit(split[])
{
	return bool:split[SPLIT_LAP_START];
}

bool:FindNextSplit(prev[], result[])
{
	new split[SPLIT], emptySplit[SPLIT];

	if (!prev[SPLIT_NEXT])
	{
		// There's no next, so this map doesn't support laps, just a normal non-looping run
		datacopy(result, emptySplit, sizeof(emptySplit));

		return false;
	}

	new TrieIter:ti = TrieIterCreate(g_Splits);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetArray(ti, split, sizeof(split));

		if (equal(prev[SPLIT_NEXT], split[SPLIT_ID]))
		{
			datacopy(result, split, sizeof(split));

			return true;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	// Haven't found any split by that id
	datacopy(result, emptySplit, sizeof(emptySplit));

	return false;
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

CheckTeleportDestinations()
{
	if (find_ent_by_class(-1, "info_teleport_destination"))
	{
		server_print("[%s] The current map has teleports", PLUGIN_TAG);
	}
	else
		server_print("[%s] The current map doesn't have teleports", PLUGIN_TAG);
}

public InvisFuncConveyorChange(pcvar, const old_value[], const new_value[])
{
	CheckHideableEntities();
}

CheckHideableEntities()
{
	new ent, entCount;

	for (ent = g_MaxPlayers + 1; ent < global_get(glb_maxEntities); ent++)
	{
		if (!pev_valid(ent))
			continue;

		if (IsLiquid(ent))
		{
			g_HideableEntity[ent] = true;
			entCount++;
		}
		else
		{
			// Could be true if for example kz_invis_func_conveyor's value was switches a couple times,
			// so we have to update the state here too for /winvis to work correctly
			g_HideableEntity[ent] = false;
		}
	}

	server_print("[%s] The current map has %d entities that can be hidden with /winvis", PLUGIN_TAG, entCount);
}

CheckStartEnd()
{
	new ent, className[32];

	for (ent = g_MaxPlayers + 1; ent < global_get(glb_maxEntities); ent++)
	{
		if (!pev_valid(ent))
			continue;

		pev(ent, pev_classname, className, charsmax(className));

		if (equali(className, "func_button"))
		{
			if (GetEntityButtonType(ent) != BUTTON_FINISH)
				continue;

			// Store the origin so that we can check later if we could have hit the end button faster
			g_EndButton = ent;
			fm_get_brush_entity_origin(g_EndButton, g_EndButtonOrigin);
			// TODO: handle edge case of more than one end button

		}
		else if (equali(className, "trigger_multiple"))
		{
			if (GetEntityButtonType(ent) != BUTTON_START)
				continue;

			g_usesStartingZone = true;
			// TODO: handle edge case of also having a start button
			// TODO: handle start split? (GetEntityButtonType(ent) = BUTTON_SPLIT)
			
		}
	}

	if (g_usesStartingZone)
		server_print("[%s] The current map has a starting zone", PLUGIN_TAG);
}

bool:IsLiquid(ent)
{
	static className[32];
	pev(ent, pev_classname, className, charsmax(className));

	if (equali(className, "func_water", 10))
		return true;

	if (equali(className, "func_conveyor", 13) && get_pcvar_num(pcvar_kz_invis_func_conveyor) == 1)
		return true;

	if (equali(className, "func_illusionary"))
	{
		new contents = pev(ent, pev_skin);

		// CONTENTS_ORIGIN is Volumetric light, which is the only content option
		// other than Empty in some map editors and is used for liquids too
		if (contents == CONTENTS_WATER || contents == CONTENTS_ORIGIN
			|| contents == CONTENTS_LAVA || contents == CONTENTS_SLIME)
		{
			return true;
		}
	}

	return false;
}

PrepareRunReqs()
{
	// Build a sorted array with all the requirement indexes
	g_SortedRunReqIndexes = ArrayCreate(1, 5);

	new TrieIter:ti = TrieIterCreate(g_RunReqs);
	while (!TrieIterEnded(ti))
	{
		new reqIdx;
		TrieIterGetCell(ti, reqIdx);

		ArrayPushCell(g_SortedRunReqIndexes, reqIdx)

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	ArraySortEx(g_SortedRunReqIndexes, "SortReqsAscending");
}

public SortReqsAscending(Array: array, elem1, elem2, const data[], data_size)
{
	if (elem1 < elem2)
		return -1;

	else if (elem1 > elem2)
		return 1;

	else
		return 0;
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
		console_print(0, "[%s] [%.3f] %s (%s) is setting a default start point for %s (point = {%.2f, %.2f, %.2f})",
				PLUGIN_TAG, time, name, uniqueid, g_Map,
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

CmdCancelNoReset(id)
{
	if (g_RunMode[id] == MODE_NORESET)
	{
		ShowMessage(id, "You can only cancel a No-Reset during countdown");
		return PLUGIN_HANDLED;
	}

	if (g_RunModeStarting[id] != MODE_NORESET)
	{
		ShowMessage(id, "This command only works during No-Reset run countdown");
		return PLUGIN_HANDLED;
	}

	client_print(id, print_chat, "[%s] No-Reset run cancelled!", PLUGIN_TAG);

	ResetPlayer(id);

	g_RunModeStarting[id] = MODE_NORMAL;
	g_RunStartTime[id] = 0.0;
	g_RunNextCountdown[id] = 0.0;

	return PLUGIN_HANDLED;
}

CmdStartNoReset(id)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		ShowMessage(id, "A match is already running. Please, try again later");
		return PLUGIN_HANDLED;
	}

	if (pev(id, pev_iuser1))
	{
		ShowMessage(id, "You have to quit spectator mode before starting a run");
		return PLUGIN_HANDLED;
	}

	if (g_AgInterruptingVoteRunning || equal(g_KzVoteSetting[id], "race"))
	{
		ShowMessage(id, "Cannot start. There's a vote running that can potentially interrupt your run");
		return PLUGIN_HANDLED;
	}
	if (g_IsInNoclip[id])
	{
		client_print(id, print_chat, "[%s] Disable noclip to start a no-reset run.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	FreezePlayer(id);

	g_IsValidStart[id] = false;

	g_RaceId[id] = 0;
	g_RunMode[id] = MODE_NORMAL; // will be set to MODE_NORESET later, right after countdown
	g_RunModeStarting[id] = MODE_NORESET;
	g_RunStartTime[id] = get_gametime() + g_RunCountdown[id];
	g_RunNextCountdown[id] = get_gametime();

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
	for (new i = 0; i < playersNum; i++)
	{
		new id2 = players[i];

		if (pev(id2, pev_iuser1) == OBS_IN_EYE && pev(id2, pev_iuser2) == id)
		{
			new targetPlayerName[33];
			GetColorlessName(id, targetPlayerName, charsmax(targetPlayerName));
			client_print(id2, print_chat, "[%s] %s is starting a No-Reset run in %.1f seconds!", PLUGIN_TAG, targetPlayerName, g_RunCountdown[id]);
		}
	}

	return PLUGIN_HANDLED;
}

StartRace(id)
{
	if (pev(id, pev_iuser1) || g_IsInNoclip[id])
	{
		ShowMessage(id, "You can't participate in races while being in spectator mode or noclip.");
		return;
	}

	FreezePlayer(id);

	g_RunMode[id] = MODE_NORMAL;
	g_RunModeStarting[id] = MODE_RACE;
	g_RunStartTime[id] = get_gametime() + get_pcvar_float(pcvar_kz_race_countdown);
	g_RunNextCountdown[id] = get_gametime();
}

EndKzVote(id)
{
	g_IsKzVoteRunning[id]  = false;
	g_KzVoteSetting[id][0] = EOS;
	g_KzVoteValue[id]      = KZVOTE_UNKNOWN;
	g_KzVoteStartTime[id]  = 0.0;
	g_KzVoteCaller[id]     = 0;
}

CmdVote(id, KZVOTE_VALUE:value)
{
	if (g_RunMode[id] != MODE_NORMAL && KZVOTE_YES == value)
	{
		ShowMessage(id, "You are not allowed to vote while you're in a no-reset/race/agstart run!");
		return PLUGIN_HANDLED;
	}

	if (g_IsKzVoteRunning[id])
		g_KzVoteValue[id] = value;

	return PLUGIN_HANDLED;
}

CmdVoteRace(id)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		ShowMessage(id, "You're in a no-reset/race/agstart run. Please, finish it before voting a new race!");
		return PLUGIN_HANDLED;
	}

	new Float:voteWaitTime = get_pcvar_float(pcvar_kz_vote_wait_time);
	if (g_KzVoteStartTime[id] && get_gametime() < (g_KzVoteStartTime[id] + get_pcvar_float(pcvar_kz_vote_hold_time) + voteWaitTime))
	{
		ShowMessage(id, "You have to wait %.2f seconds before making a new vote", voteWaitTime);
		return PLUGIN_HANDLED;
	}

	new FindPlayerFlags:findFlags = FindPlayer_CaseInsensitive | FindPlayer_ExcludeBots | FindPlayer_MatchNameSubstring | FindPlayer_MatchUserId | FindPlayer_MatchAuthId;
	new Array:targets = ArrayCreate(1, 8);
	new fullCommand[256], buffer[33];
	read_args(fullCommand, charsmax(fullCommand));
	remove_quotes(fullCommand);
	trim(fullCommand);

	new targetId;
	new isSplit = strtok2(fullCommand, buffer, charsmax(buffer), fullCommand, charsmax(fullCommand), ' ', 1);
	//server_print("[first] fullCommand: %s, buffer: %s, isSplit: %d", fullCommand, buffer, isSplit);

	new playerName[33];
	if (fullCommand[0])
	{
		// Players have been specified in the say command, so find them

		// This is repeated to ignore the first part, which would be "/race"
		isSplit = strtok2(fullCommand, buffer, charsmax(buffer), fullCommand, charsmax(fullCommand), ' ', 1);
		while (isSplit > -1)
		{
			//server_print("[loop, specific] fullCommand: %s, buffer: %s, isSplit: %d", fullCommand, buffer, isSplit);

			targetId = find_player_ex(findFlags, buffer);
			buffer[0] = EOS; // clear the string just in case
			isSplit = strtok2(fullCommand, buffer, charsmax(buffer), fullCommand, charsmax(fullCommand), ' ', 1);

			if (!targetId)
			{
				console_print(id, "[%s] Couldn't find player with name or id '%s'", PLUGIN_TAG, buffer);
				continue;
			}

			if (g_IsKzVoteIgnoring[targetId])
				continue;

			if (ArrayFindValue(targets, targetId) != -1)
				continue;

			GetColorlessName(targetId, playerName, charsmax(playerName));
			//server_print("[loop, specific] adding %s to race vote", playerName);
			ArrayPushCell(targets, targetId);
		}
		//server_print("[last, specific] fullCommand: %s, buffer: %s, isSplit: %d", fullCommand, buffer, isSplit);
		targetId = find_player_ex(findFlags, buffer);
		if (targetId && ArrayFindValue(targets, targetId) == -1)
		{
			GetColorlessName(targetId, playerName, charsmax(playerName));
			//server_print("[last, specific] adding %s to race vote", playerName);
			ArrayPushCell(targets, targetId);
		}
	}
	else
	{
		// No player has been specified, so assume the race is for all
		new players[MAX_PLAYERS], playersNum;
		get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
		for (new i = 0; i < playersNum; i++)
		{
			new targetId = players[i];

			if (g_IsKzVoteIgnoring[targetId])
				continue;

			if (ArrayFindValue(targets, targetId) != -1)
				continue;

			GetColorlessName(targetId, playerName, charsmax(playerName));
			//server_print("[all] adding %s to race vote", playerName);
			ArrayPushCell(targets, targetId);
		}
	}

	if (ArrayFindValue(targets, id) == -1)
	{
		GetColorlessName(id, playerName, charsmax(playerName));
		//server_print("adding caller %s to the race vote", playerName);
		ArrayPushCell(targets, id); // the vote caller will also be included into the race; if they don't want, just say /no
	}

	if (ArraySize(targets) == 1 && id == ArrayGetCell(targets, 0))
	{
		ShowMessage(id, "You can only make races for 2 or more players");
		return PLUGIN_HANDLED;
	}

	new raceId = random_num(1, MAX_RACE_ID);

	for (new i = 0; i < ArraySize(targets); i++)
	{
		new targetId = ArrayGetCell(targets, i);

		new targetPlayerName[33];
		GetColorlessName(targetId, targetPlayerName, charsmax(targetPlayerName));

		if (id != targetId)
		{
			new playerName[33], playersText[25];
			GetColorlessName(id, playerName, charsmax(playerName));

			if (ArraySize(targets) > 3)
				formatex(playersText, charsmax(playersText), " and another %d players", ArraySize(targets));
			else if (ArraySize(targets) > 2)
				formatex(playersText, charsmax(playersText), " and another player");

			client_print(targetId, print_chat, "[%s] %s wants to race with you%s!", PLUGIN_TAG, playerName, playersText);
		}

		//server_print("showing vote to %s", targetPlayerName);

		g_RaceId[targetId]          = raceId;
		g_IsKzVoteRunning[targetId] = true;
		g_KzVoteSetting[targetId]   = "race";
		g_KzVoteValue[targetId]     = KZVOTE_NO;
		g_KzVoteStartTime[targetId] = get_gametime();
		g_KzVoteCaller[targetId]    = id;
	}

	if (!pev(id, pev_iuser1))
	{
		// We assume that the vote starter wants to participate in the race if they're not in spec mode
		g_KzVoteValue[id] = KZVOTE_YES;
	}

	return PLUGIN_HANDLED;
}

CmdToggleVoteVisibility(id)
{
	g_IsKzVoteVisible[id] = !g_IsKzVoteVisible[id];
	ShowMessage(id, "Votes are now %s", g_IsKzVoteVisible[id] ? "visible" : "invisible");

	return PLUGIN_HANDLED;
}

CmdToggleVoteIgnore(id)
{
	g_IsKzVoteIgnoring[id] = !g_IsKzVoteIgnoring[id];
	ShowMessage(id, "Votes are %s", g_IsKzVoteIgnoring[id] ? "now ignored" : "not ignored anymore");

	return PLUGIN_HANDLED;
}

CmdAlignVote(id)
{
	new fullCommand[256], buffer[33];
	read_args(fullCommand, charsmax(fullCommand));
	remove_quotes(fullCommand);
	trim(fullCommand);

	strtok2(fullCommand, buffer, charsmax(buffer), fullCommand, charsmax(fullCommand), ' ', 1); // remove "/alignvote"
	strtok2(fullCommand, buffer, charsmax(buffer), fullCommand, charsmax(fullCommand), ' ', 1); // and the alignmnent position (the string) is left in buffer

	if (buffer[0])
	{
		// Change to specified position, e.g.: "center"
		for (new i = 0; i < _:KZ_VOTE_POSITION; i++)
		{
			if (containi(buffer, g_KzVotePositionString[i]) != -1)
			{
				g_KzVoteAlignment[id] = KZ_VOTE_POSITION:i;
				break;
			}
		}
	}
	else
	{
		// No position specified, just switch to next position (left -> center -> right -> left...)
		g_KzVoteAlignment[id]++;

		if (g_KzVoteAlignment[id] >= KZ_VOTE_POSITION)
			g_KzVoteAlignment[id] = POSITION_LEFT;
	}

	ShowMessage(id, "Votes are now aligned to the %s", g_KzVotePositionString[_:g_KzVoteAlignment[id]]);

	return PLUGIN_HANDLED;
}

CmdSetTpOnCountdown(id)
{
	g_TpOnCountdown[id] = !g_TpOnCountdown[id];
	ShowMessage(id, "TP on countdown is now %s", g_TpOnCountdown[id] ? "enabled" : "disabled");

	return PLUGIN_HANDLED;
}

CmdSetCountdown(id)
{
	new Float:countdown = GetFloatArg();

	if (countdown < MIN_COUNTDOWN)
	{
		g_RunCountdown[id] = MIN_COUNTDOWN;
		ShowMessage(id, "Countdown set to %.2fs (min. allowed)", MIN_COUNTDOWN);
	}
	else if (countdown > MAX_COUNTDOWN)
	{
		g_RunCountdown[id] = MAX_COUNTDOWN;
		ShowMessage(id, "Countdown set to %.2fs (max. allowed)", MAX_COUNTDOWN);
	}
	else
	{
		g_RunCountdown[id] = countdown;
		ShowMessage(id, "Countdown set to %.2fs", countdown);
	}

	return PLUGIN_HANDLED;
}

public CmdReady(id)
{
	if (g_RunMode[id] != MODE_NORMAL)
	{
		client_print(id, print_chat, "[%s] Cannot /ready now, a match is already running!", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (!IsCupPlayer(id))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you are not a participant in the current cup match.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (CountCupMaps(MAP_IDLE))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, there are still maps to be banned/picked.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (!IsCupMap())
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you must be in one of the maps to be played.", PLUGIN_TAG);
		return PLUGIN_HANDLED;
	}

	if (g_usesStartingZone)
	{
		if (!CanTeleportNr(id, CP_TYPE_CUSTOM_START))
		{
			client_print(id, print_chat, "[%s] Cannot /ready yet, you must set a custom start position first (through KZ menu or saying /ss).", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}
	}
	else if (!CanTeleportNr(id, CP_TYPE_START))
	{
		client_print(id, print_chat, "[%s] Cannot /ready yet, you must press the start button first, to set the start point.", PLUGIN_TAG);
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
		server_print("player2 is %s", ready ? "ready" : "NOT ready");
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
		// Players that won't be playing the match will be forced into spectators and no one will be able to change spec mode
		g_DisableSpec = true;

		client_print(0, print_chat, "[%s] Starting in 5 seconds... non-participants will now be switched to spectator mode.", PLUGIN_TAG);
		set_task(1.5,  "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS);
		set_task(4.5,  "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS + 1);
		set_task(4.98, "CupForceSpectators", TASKID_CUP_FORCE_SPECTATORS + 2); // just in case someone's being an idiot
		set_task(5.0,  "CupStartMatch",      TASKID_CUP_START_MATCH);
	}

	return PLUGIN_HANDLED;
}

/**
 *	Get the players that are not spectators and have no start point set,
 *	and switch them to spectators and disable the possibility of finishing
 *	the run, because otherwise they might start in a spawn point that gives them
 *	advantage, specially if it's a deathmatch map
 */
public CheckAgstartConditions(taskId)
{
	new players[MAX_PLAYERS], playersNum, switchedPlayers = 0;
	get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		if (pev(id, pev_iuser1)) // ignore specs
			continue;

		if (get_pcvar_num(pcvar_kz_noreset_agstart))
			g_RunModeStarting[id] = MODE_NORESET;
		else
			g_RunModeStarting[id] = MODE_AGSTART;

		if (CanTeleport(id, CP_TYPE_START, false) || CanTeleport(id, CP_TYPE_DEFAULT_START, false)
			|| (CanTeleport(id, CP_TYPE_CUSTOM_START, false) && g_usesStartingZone))
		{
			// Might be entering here again after banning from match
			// If they can teleport then it's fine, remove the ban
			g_IsBannedFromMatch[id] = false;

			if (g_TpOnCountdown[id])
			{
				if (CanTeleport(id, CP_TYPE_CUSTOM_START, false) && g_usesStartingZone)
					Teleport(id, CP_TYPE_CUSTOM_START);
				else if (CanTeleport(id, CP_TYPE_START, false))
					Teleport(id, CP_TYPE_START);
				else if (CanTeleport(id, CP_TYPE_DEFAULT_START, false))
					Teleport(id, CP_TYPE_DEFAULT_START);
			}
			continue;
		}

		// The ShowMessage doesn't actually seem to appear, maybe because the HUD is reset upon switching to spectator
		// or something, so showing this chat print instead
		client_print(id, print_chat, "[%s] You have to press the start button before starting the match!", PLUGIN_TAG);

		ResetPlayer(id);
		server_cmd("agforcespectator #%d", get_user_userid(id));

		g_IsBannedFromMatch[id] = true;
		g_RunModeStarting[id] = MODE_NORMAL;
		g_RunStartTime[id] = 0.0;
		g_RunNextCountdown[id] = 0.0;

		switchedPlayers++;
	}

	if (switchedPlayers)
		server_exec();

	if (switchedPlayers == playersNum)
	{
		// No player remaining for this agstart, so abort it
		server_cmd("agabort");
		server_exec();
	}
}

// TODO: Cache the result when starting the map or when the map pool file is read
bool:IsCupMap()
{
	// Check if the current map is one of the maps to be played
	new /*map[32], mapState,*/ cupMap[CUP_MAP], bool:result;
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
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

bool:IsCupPlayer(id) {
	return id == g_CupPlayer1 || id == g_CupPlayer2;
}

SetCupMapWinner(id)
{
	if (id == g_CupPlayer1)
		g_CupScore1++;
	else if (id == g_CupPlayer2)
		g_CupScore2++;

	new cupMap[CUP_MAP];
	TrieGetArray(g_CupMapPool, g_Map, cupMap, sizeof(cupMap));

	// Update map state
	cupMap[MAP_STATE_] = MAP_PLAYED;
	TrieSetArray(g_CupMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap));

	// Save the changes to file, because we're gonna change the map in a while
	// and this info has to be taken again from the file right after changing
	WriteCupMapPoolFile(0);
	WriteCupFile(0);
	CmdMapsShowHandler(0); // TODO: maybe this should show who won each map instead of just [PLAYED]

	// Commented out because this shouldn't happen, and if it does it has to be fixed in a better way
	//if (!topType)
	//	topType = PURE;

	new playerName[32];
	GetColorlessName(id, playerName, charsmax(playerName));
	client_print(0, print_chat, "[%s] Player %s has won in this map! Congrats!", PLUGIN_TAG, playerName);

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
		new buffer[256];
		read_args(buffer, charsmax(buffer));
		remove_quotes(buffer);
		trim(buffer);

		new cupMaps[4], target1[32], target2[32], cupFormat[MAX_MATCH_MAPS + 1];
		parse(buffer,
				cupMaps,	charsmax(cupMaps),
				target1,	charsmax(target1),
				target2,	charsmax(target2),
				cupFormat,	charsmax(cupFormat));

		trim(cupMaps);
		trim(target1);
		trim(target2);
		trim(cupFormat);

		if (!cupMaps[0] || !target1[0] || !target2[0])
		{
			console_print(id, "Usage: kz_cup <number_of_maps> <#player1> <#player2> <format>");
			console_print(id, "- number_of_maps would be 5 if it's a Bo5; and for the format, A and B are players and D is decider, e.g.: ABBAABD");
			console_print(id, "- For #player1 and #player2 you can type status and get their user IDs from there, so e.g.: #152 and #157");
			console_print(id, "- Full example: kz_cup 5 #152 #157 ABBAABD");
			return PLUGIN_HANDLED;
		}

		new player1 = cmd_target(id, target1, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS);
		new player2 = cmd_target(id, target2, CMDTARGET_ALLOW_SELF | CMDTARGET_NO_BOTS);

		if (!player1)
		{
			console_print(id, "[%s] Cannot find the first player specified in the kz_cup command", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}

		if (!player2)
		{
			console_print(id, "[%s] Cannot find the second player specified in the kz_cup command", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}

		if (cupFormat[0] && strlen(cupFormat) != TrieGetSize(g_CupMapPool))
		{
			console_print(id, "[%s] The specified format doesn't match the map pool size", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}

		if (!cupFormat[0] || !ProcessCupFormat(id, cupFormat))
		{
			new format[MAX_MATCH_MAPS + 1];
			// TODO: deprecate this cvar? it's only used when picking/banning maps
			// and it makes more sense to have the format only in the kz_cup command anyways
			get_pcvar_string(pcvar_kz_cup_format, format, charsmax(format));

			if (!ProcessCupFormat(id, format))
			{
				return PLUGIN_HANDLED;
			}
		}

		server_print("[%s] Starting cup (best of %s, players #%d and #%d, format %s)", PLUGIN_TAG, cupMaps, target1, target2, cupFormat);

		g_BestOfN = str_to_num(cupMaps);
		g_CupPlayer1 = player1;
		g_CupPlayer2 = player2;
		GetUserUniqueId(player1, g_CupSteam1, charsmax(g_CupSteam1));
		GetUserUniqueId(player2, g_CupSteam2, charsmax(g_CupSteam2));
		g_CupScore1 = 0;
		g_CupScore2 = 0;
		g_CupReady1 = false;
		g_CupReady2 = false;
		ResetCupMapStates(id);

		if (g_BestOfN < TrieGetSize(g_CupMapPool))
			client_print(0, print_chat, "[%s] Flipping a coin to decide who bans first...", PLUGIN_TAG);
		else
			client_print(0, print_chat, "[%s] Flipping a coin to decide who picks first...", PLUGIN_TAG);

		set_task(2.0, "CupTensionFirstBan", TASKID_CUP_TENSION_FIRST_BAN);
	}

	return PLUGIN_HANDLED;
}

bool:ProcessCupFormat(id, cupFormat[])
{
	new i;
	while (cupFormat[i])
	{
		// TODO: refactor to make it simpler, no conditions
		if (equali(cupFormat[i], "A", 1))
			g_CupFormat[i] = MATCH_PLAYER1;
		else if (equali(cupFormat[i], "B", 1))
			g_CupFormat[i] = MATCH_PLAYER2;
		else if (equali(cupFormat[i], "D", 1))
			g_CupFormat[i] = MATCH_DECIDER;
		else
		{
			g_CupFormat[i] = MATCH_UNKNOWN;

			new format[MAX_MATCH_MAPS + 1];
			get_pcvar_string(pcvar_kz_cup_format, format, charsmax(format));

			console_print(id, "[%s] The provided format is wrong! You can set it with kz_cup_format <format>", PLUGIN_TAG);
			console_print(id, "[%s] Example: \"kz_cup_format ABBAABD\". The default one is %s", PLUGIN_TAG, format);
			console_print(id, "[%s] A is first opponent's pick/ban, B is second opponent's pick/ban, and D is the decider map", PLUGIN_TAG);

			return false;
		}
		i++;
	}

	return true;
}

public CupTensionFirstBan(taskId)
{
	if (g_BestOfN < TrieGetSize(g_CupMapPool))
		client_print(0, print_chat, "[%s] ...can you guess who bans first?", PLUGIN_TAG);
	else
		client_print(0, print_chat, "[%s] ...can you guess who picks first?", PLUGIN_TAG);

	set_task(3.0, "CupFinallyFirstPickBan", TASKID_CUP_FINALLY_FIRST_BAN);
}

public CupFinallyFirstPickBan(taskId)
{
	new rand = random_num(0, 1);
	if (rand)
	{
		// Switch players
		new oldSteam1[MAX_AUTHID_LENGTH], oldSteam2[MAX_AUTHID_LENGTH];
		new oldPlayer1 = g_CupPlayer1;
		new oldPlayer2 = g_CupPlayer2;
		copy(oldSteam1, charsmax(oldSteam1), g_CupSteam1);
		copy(oldSteam2, charsmax(oldSteam1), g_CupSteam2);

		g_CupPlayer1 = oldPlayer2;
		g_CupPlayer2 = oldPlayer1;
		copy(g_CupSteam1, charsmax(g_CupSteam1), oldSteam2);
		copy(g_CupSteam2, charsmax(g_CupSteam2), oldSteam1);
	}

	WriteCupFile(0);

	new playerName[32];
	GetColorlessName(g_CupPlayer1, playerName, charsmax(playerName));

	if (g_BestOfN < TrieGetSize(g_CupMapPool))
	{
		client_print(0, print_chat, "[%s] Okay, %s bans first!", PLUGIN_TAG, playerName);
		CreateMapMenu(g_CupPlayer1, MAP_BAN_MENU_ID);
	}
	else
	{
		client_print(0, print_chat, "[%s] Okay, %s picks first!", PLUGIN_TAG, playerName);
		CreateMapMenu(g_CupPlayer1, MAP_PICK_MENU_ID);
	}
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
		server_print("getting decider map %s", map);
	}

	// Then the picked ones
	new Array:pickedMaps = GetCupMapsWithState(MAP_PICKED);
	for (new i = 0; i < ArraySize(pickedMaps); i++)
	{
		ArrayGetString(pickedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [PICKED]\n", msg, map);
		server_print("getting picked map %s", map);
	}

	// Then the played ones
	new Array:playedMaps = GetCupMapsWithState(MAP_PLAYED);
	for (new i = 0; i < ArraySize(playedMaps); i++)
	{
		ArrayGetString(playedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [PLAYED]\n", msg, map);
		server_print("getting played map %s", map);
	}

	// Then the banned ones
	new Array:bannedMaps = GetCupMapsWithState(MAP_BANNED);
	for (new i = 0; i < ArraySize(bannedMaps); i++)
	{
		ArrayGetString(bannedMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s - [BANNED]\n", msg, map);
		server_print("getting banned map %s", map);
	}

	// Then the maps that remain untouched yet
	new Array:idleMaps = GetCupMapsWithState(MAP_IDLE);
	for (new i = 0; i < ArraySize(idleMaps); i++)
	{
		ArrayGetString(idleMaps, i, map, charsmax(map));
		format(msg, charsmax(msg), "%s > %s\n", msg, map);
		server_print("getting idle map %s", map);
	}

	set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], _, 0.2, 0, 0.0, 6.0, 0.0, 1.0, -1);
	ShowSyncHudMsg(id, g_SyncHudCupMaps, msg);

	return PLUGIN_HANDLED;
}

Array:GetCupMapsWithState(MAP_STATE:stateNumber)
{
	new Array:result = ArrayCreate(32, 7);

	//new map[32], mapState;
	new cupMap[CUP_MAP];
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti))
	{
		//TrieIterGetCell(ti, mapState);
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		if (cupMap[MAP_STATE_] == stateNumber)
		{
			//TrieIterGetKey(ti, cupMap[MAP_NAME], charsmax(cupMap[MAP_NAME]));
			ArrayPushString(result, cupMap[MAP_NAME]);
			//server_print("pushed map %s", cupMap[MAP_NAME]);
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
		new maps[MAX_MAP_INSERTIONS_AT_ONCE][32];
		for (new i = 0; i < sizeof(maps); i++) {
			read_argv(i+1, maps[i], charsmax(maps[]));

			if (maps[i][0])
			{
				new cupMap[CUP_MAP];
				TrieGetArray(g_CupMapPool, maps[i], cupMap, sizeof(cupMap));

				copy(cupMap[MAP_NAME], charsmax(cupMap[MAP_NAME]), maps[i]);
				TrieSetArray(g_CupMapPool, maps[i], cupMap, sizeof(cupMap));
			}
		}

		if (read_argc() > MAX_MAP_INSERTIONS_AT_ONCE + 1)
			console_print(id, "[%s] Added %d maps, can't add more per command.", PLUGIN_TAG, MAX_MAP_INSERTIONS_AT_ONCE);

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

		if (TrieKeyExists(g_CupMapPool, map))
		{
			new cupMap[CUP_MAP];
			TrieGetArray(g_CupMapPool, map, cupMap, sizeof(cupMap));

			cupMap[MAP_STATE_] = _:mapState;
			TrieSetArray(g_CupMapPool, map, cupMap, sizeof(cupMap));

			client_print(0, print_chat, "[%s] %s's new state is: %s.",
				PLUGIN_TAG, map, g_MapStateString[mapState][0] ? g_MapStateString[mapState] : "idle");
		}
		else
			client_print(id, print_chat, "[%s] Sorry, the specified map is not in the pool.", PLUGIN_TAG);

		WriteCupMapPoolFile(id);
	}

	return PLUGIN_HANDLED;
}

// Let an admin set the winner in case something goes wrong
public CmdMapWinnerHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
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
	new i, cupMap[CUP_MAP];
	//cupMap[MAP_ORDER] = 0;
	//cupMap[MAP_STATE_] = MAP_IDLE;
	//cupMap[MAP_NAME][0] = EOS;
	//cupMap[MAP_PICKER] = MATCH_DECIDER; // TODO: refactor; it's not rightly - to go like it

	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
	while (!TrieIterEnded(ti)) {
		//new map[MAX_MAPNAME_LENGTH];
		//TrieIterGetKey(ti, map, charsmax(map));
		TrieIterGetArray(ti, cupMap, sizeof(cupMap));

		cupMap[MAP_ORDER]  = 0;
		cupMap[MAP_STATE_] = MAP_IDLE;
		cupMap[MAP_PICKER] = MATCH_UNKNOWN; // will get corrected later, TODO: make something 

		//if (TrieSetCell(g_CupMapPool, map, MAP_IDLE))
		if (TrieSetArray(g_CupMapPool, cupMap[MAP_NAME], cupMap, sizeof(cupMap)))
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

// Clears the cached cup data, including the map states
public CmdClearCup(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		ClearCup(id);
	}
	return PLUGIN_HANDLED;
}

public CmdCupForceReady(id, level, cid)
{
	if(cmd_access(id, level, cid, 1))
	{
		if(!g_CupPlayer2 || !g_CupPlayer2)
		{
			console_print(id, "The players could not be found.")
			return PLUGIN_HANDLED;
		}

		if(!g_CupReady1)
			CmdReady(g_CupPlayer1);

		if(!g_CupReady2)
			CmdReady(g_CupPlayer2);
	}

	return PLUGIN_HANDLED;
}

public CmdCupMapsHandler(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new mapsToPlay[8];
		read_argv(1, mapsToPlay, charsmax(mapsToPlay));

		g_BestOfN = str_to_num(mapsToPlay);
	}

	return PLUGIN_HANDLED;
}

ClearCup(id)
{
	g_BestOfN = 0;
	g_CupPlayer1 = 0;
	g_CupPlayer2 = 0;
	g_CupSteam1[0] = EOS;
	g_CupSteam2[0] = EOS;
	g_CupScore1 = 0;
	g_CupScore2 = 0;
	g_CupReady1 = false;
	g_CupReady2 = false;
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

	WriteCupMapPoolFile(0);
	WriteCupFile(0);
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
	new cupMap[CUP_MAP], TrieIter:ti = TrieIterCreate(g_CupMapPool);
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
WriteCupFile(id)
{
	new file = fopen(g_CupFile, "wt");
	if (!file)
	{
		ShowMessage(id, "Failed to write cup file");
		return;
	}

	if (g_BestOfN && g_CupSteam1[0] && g_CupSteam2[0])
	{
		fprintf(file, "%d %s %s %d %d\n", g_BestOfN, g_CupSteam1, g_CupSteam2, g_CupScore1, g_CupScore2);
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
	if (g_IsInNoclip[id])
	{
		ShowMessage(id, "You must not be in noclip to use this command.");
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

 	g_ShowStartMsg[id] = str_to_num(arg1);

 	return PLUGIN_HANDLED;
}

public CmdSlopefix(id)
{
	g_Slopefix[id] = !g_Slopefix[id];
	if (g_Slopefix[id] && !get_pcvar_num(pcvar_kz_slopefix))
	{
		g_Slopefix[id] = false;
		ShowMessage(id, "Slopebug/Surfbug fix is disabled by server");
	}
	else
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
	ClearSyncHud(id, g_SyncHudSpeedometer);
	g_ShowSpeed[id] = !g_ShowSpeed[id];
	ShowMessage(id, "Speed: %s", g_ShowSpeed[id] ? "ON" : "OFF");

	return PLUGIN_HANDLED;
}

public CmdDistance(id)
{
	ClearSyncHud(id, g_SyncHudDistance);
	g_ShowDistance[id] = !g_ShowDistance[id];
	ShowMessage(id, "Distance: %s", g_ShowDistance[id] ? "ON" : "OFF");

	return PLUGIN_HANDLED;
}

public CmdHeightDiff(id)
{
	ClearSyncHud(id, g_SyncHudHeightDiff);
	g_ShowHeightDiff[id] = !g_ShowHeightDiff[id];
	ShowMessage(id, "Height difference: %s", g_ShowHeightDiff[id] ? "ON" : "OFF");

	return PLUGIN_HANDLED;
}

public CmdSpeedcap(id)
{
	new Float:allowedSpeedcap = get_pcvar_float(pcvar_kz_speedcap);
	new Float:speedcap = GetFloatArg();
	//console_print(id, "allowedSpeedcap = %.2f; speedcap = %.2f", allowedSpeedcap, speedcap);

	if (allowedSpeedcap && speedcap > allowedSpeedcap)
	{
		g_Speedcap[id] = allowedSpeedcap;
		ShowMessage(id, "Horizontal speed set to %.2f (max. allowed)", allowedSpeedcap);
	}
	else
	{
		g_Speedcap[id] = speedcap;
		ShowMessage(id, "Your horizontal speedcap is now: %.2f", g_Speedcap[id]);
	}
	clr_bit(g_baIsPureRunning, id);

	return PLUGIN_HANDLED;
}

public CmdPreSpeedcap(id)
{
	new level = GetNumberArg();

	if (level > 2)
		level = 2;

	if (g_Prespeedcap[id] == 0 && level == 0)
	{
		// We will receive a 0 if they don't type a number, and if it was already 0 it's likely
		// that they meant to toggle it instead, so we will do that, and if they meant to make sure
		// that it's off for some reason, well then it won't work as they expected :/
		level = 1;
	}

	if (level < 0)
		level = 0;

	if (level > 0 && g_usesStartingZone && !get_pcvar_float(pcvar_kz_pure_limit_zone_speed))
	{
		g_Prespeedcap[id] = 0;
		ShowMessage(id, "You're not allowed to enable the prespeed cap. Start zone prespeed cap: OFF");
		return PLUGIN_HANDLED;
	}
	g_Prespeedcap[id] = level;

	if (g_Prespeedcap[id] == 0)
		ShowMessage(id, "Prespeed cap: OFF");
	else if (g_Prespeedcap[id] == 1)
		ShowMessage(id, "Prespeed cap: ON, only at the start zone");
	else if (g_Prespeedcap[id] == 2)
		ShowMessage(id, "Prespeed cap: always ON");

	return PLUGIN_HANDLED;
}

/*
public SetPOV(id)
{
	new target = GetNumberArg();
	set_pev(id, pev_iuser2, target);

	return PLUGIN_HANDLED;
}
*/
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

CmdShowRunStatsOnConsole(id)
{
	g_ShowRunStatsOnConsole[id] = !g_ShowRunStatsOnConsole[id];
	ShowMessage(id, "Run stats on console: %s", g_ShowRunStatsOnConsole[id] ? "ON" : "OFF");

	return PLUGIN_HANDLED;
}

CmdShowRunStatsOnHud(id)
{
	new level = GetNumberArg();

	if (level > 2)
		level = 2;

	if (g_ShowRunStatsOnHud[id] == 0 && level == 0)
	{
		// We will receive a 0 if they don't type a number, and if it was already 0 it's likely
		// that they meant to toggle it instead, so we will do that, and if they meant to make sure
		// that it's off for some reason, well then it won't work as they expected :/
		level = 1;
	}

	if (level < 0)
		level = 0;

	ClearSyncHud(id, g_SyncHudRunStats);

	g_ShowRunStatsOnHud[id] = level;

	ShowMessage(id, "Run stats on HUD: %s", g_ShowRunStatsOnHudString[level]);

	return PLUGIN_HANDLED;
}

CmdRunStatsHudHoldTime(id)
{
	new Float:holdTime = GetFloatArg();
	new bool:isMsgAlreadyShown = false;

	if (holdTime > RUN_STATS_HUD_MAX_HOLD_TIME)
	{
		holdTime = RUN_STATS_HUD_MAX_HOLD_TIME;
		ShowMessage(id, "Run stats HUD hold time set to %.1f (max. allowed)", holdTime);
		
		isMsgAlreadyShown = true;
	}
	else if (holdTime < RUN_STATS_HUD_MIN_HOLD_TIME)
	{
		holdTime = RUN_STATS_HUD_MIN_HOLD_TIME;
		ShowMessage(id, "Run stats HUD hold time set to %.1f (min. allowed)", holdTime);
		
		isMsgAlreadyShown = true;
	}
	g_RunStatsHudHoldTime[id] = holdTime;

	// TODO: if it's showing the run end stats HUD right now, make it show this change
	ClearSyncHud(id, g_SyncHudRunStats);

	if (!isMsgAlreadyShown)
		ShowMessage(id, "Run stats HUD hold time set to %.1f", g_RunStatsHudHoldTime[id]);

	return PLUGIN_HANDLED;
}

CmdRunStatsConsoleDetails(id)
{
	new level = GetNumberArg();

	if (level > 2)
		level = 2;

	if (g_RunStatsConsoleDetailLevel[id] == 0 && level == 0)
	{
		// We will receive a 0 if they don't type a number, and if it was already 0 it's likely
		// that they meant to toggle it instead, so we will do that, and if they meant to make sure
		// that it's off for some reason, well then it won't work as they expected :/
		level = 2;
	}

	if (level < 0)
		level = 0;

	g_RunStatsConsoleDetailLevel[id] = level;

	ShowMessage(id, "Run stats console detail level: %s", g_RunStatsDetailLevelString[level]);

	return PLUGIN_HANDLED;
}

CmdRunStatsHudDetails(id)
{
	new level = GetNumberArg();

	if (level > 2)
		level = 2;

	if (g_RunStatsHudDetailLevel[id] == 0 && level == 0)
	{
		// We will receive a 0 if they don't type a number, and if it was already 0 it's likely
		// that they meant to toggle it instead, so we will do that, and if they meant to make sure
		// that it's off for some reason, well then it won't work as they expected :/
		level = 2;
	}

	if (level < 0)
		level = 0;

	// TODO: if it's showing the run end stats HUD right now, make it show this change
	ClearSyncHud(id, g_SyncHudRunStats);

	g_RunStatsHudDetailLevel[id] = level;

	ShowMessage(id, "Run stats HUD detail level: %s", g_RunStatsDetailLevelString[level]);

	return PLUGIN_HANDLED;
}

CmdRunStatsHudX(id)
{
	new Float:x = GetFloatArg();
	new bool:isMsgAlreadyShown = false;

	if (x > 1.0)
	{
		x = 1.0;
		ShowMessage(id, "Run stats HUD X set to %.1f (max. allowed)", x);
		
		isMsgAlreadyShown = true;
	}
	else if (x < 0.0 && x != -1.0)
	{
		// -1.0 means centered, so we allow that value
		x = 0.0;
		ShowMessage(id, "Run stats HUD X set to %.1f (min. allowed)", x);
		
		isMsgAlreadyShown = true;
	}
	g_RunStatsHudX[id] = x;

	// TODO: if it's showing the run end stats HUD right now, make it show this change
	ClearSyncHud(id, g_SyncHudRunStats);

	if (!isMsgAlreadyShown)
		ShowMessage(id, "Run stats HUD X set to %.1f", g_RunStatsHudX[id]);

	return PLUGIN_HANDLED;
}

CmdRunStatsHudY(id)
{
	new Float:y = GetFloatArg();
	new bool:isMsgAlreadyShown = false;

	if (y > 1.0)
	{
		y = 1.0;
		ShowMessage(id, "Run stats HUD Y set to %.1f (max. allowed)", y);
		
		isMsgAlreadyShown = true;
	}
	else if (y < 0.0 && y != -1.0)
	{
		// -1.0 means centered, so we allow that value
		y = 0.0;
		ShowMessage(id, "Run stats HUD Y set to %.1f (min. allowed)", y);
		
		isMsgAlreadyShown = true;
	}
	g_RunStatsHudY[id] = y;

	// TODO: if it's showing the run end stats HUD right now, make it show this change
	ClearSyncHud(id, g_SyncHudRunStats);

	if (!isMsgAlreadyShown)
		ShowMessage(id, "Run stats HUD Y set to %.1f", g_RunStatsHudY[id]);

	return PLUGIN_HANDLED;
}


// TODO: refactor to use AMX_SETTINGS_API
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
		g_MapDefaultStart[CP_LONGJUMP] = GetNextNumber(buffer, pos) ? true : false;
		g_MapDefaultStart[CP_VALID] = true;
	}

	fclose(file);
}

LoadMapPool()
{
	g_CupMapPool = TrieCreate();

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

		server_print("filling g_CupMapPool with map %s (%s)", mapName, cupMap[MAP_NAME]);

		TrieSetArray(g_CupMapPool, mapName, cupMap, sizeof(cupMap));
	}
	fclose(file);
	server_print("[%s] Map pool loaded (%d maps).", PLUGIN_TAG, TrieGetSize(g_CupMapPool));
}

LoadCup()
{
	// Load current cup's info
	new file = fopen(g_CupFile, "rt");
	if (!file) return;

	new buffer[256];
	while(fgets(file, buffer, charsmax(buffer)))
	{
		new maps[4], /*cupFormat[MAX_MATCH_MAPS + 1],*/ id1[MAX_AUTHID_LENGTH], id2[MAX_AUTHID_LENGTH], score1[4], score2[4];
		parse(buffer,
				maps,		charsmax(maps),
				//cupFormat,	charsmax(cupFormat),
				id1,		charsmax(id1),
				id2,		charsmax(id2),
				score1,		charsmax(score1),
				score2,		charsmax(score2));

		g_BestOfN = str_to_num(maps);
		//ProcessCupFormat(0, cupFormat);
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

		server_print("GetNextCupMapToPlay :: #%d map = %s", i, cupMap[MAP_NAME]);

		if (cupMap[MAP_STATE_] == MAP_PICKED || cupMap[MAP_STATE_] == MAP_DECIDER)
		{
			formatex(map, len, cupMap[MAP_NAME]);
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
	new TrieIter:ti = TrieIterCreate(g_CupMapPool);
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

CreateGlobalHealer()
{
	new Float:health = get_pcvar_float(pcvar_kz_autoheal_hp) * 2.0;
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "trigger_hurt"));
	dllfunc(DLLFunc_Spawn, ent);
	// FIXME: it's possible to have maps much larger than these bounds (e.g.: fastrun_x25.bsp),
	// but only in AG 6.7+ it's possible to have entities further than these founds
	engfunc(EngFunc_SetSize, ent, Float:{-8192.0, -8192.0, -8192.0}, Float:{8192.0, 8192.0, 8192.0});
	set_pev(ent, pev_spawnflags, SF_TRIGGER_HURT_CLIENTONLYTOUCH);
	set_pev(ent, pev_dmg, -1.0 * health);
}

bool:IsAnyActiveNR()
{
	for (new i = 1; i <= g_MaxPlayers; i++)
	{
		if (g_RunMode[i] == MODE_NORESET)
			return true;
	}

	return false;
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

GetPlayerFromUniqueId(uniqueId[])
{
	for (new i = 1; i <= sizeof(g_UniqueId) - 1; i++)
	{
		if (equal(uniqueId, g_UniqueId[i]))
			return i;
	}
	return 0;
}

LoadRecords(RUN_TYPE:topType)
{
	if (get_pcvar_num(pcvar_kz_mysql))
	{
		new query[1184];
		if (topType == PRO)
		{
			// Pure records no longer will generate an equivalent pro record in database,
			// so we do a different query as we still want the pro leaderboard to show player's
			// pure PB if they don't have a pro PB
			formatex(query, charsmax(query), "\
			    SELECT \
			        r.id, \
			        p.unique_id, \
			        pn.name, \
			        r.checkpoints, \
			        r.teleports, \
			        r.time, \
			        UNIX_TIMESTAMP(r.date) \
			    FROM run r \
			    INNER JOIN player p ON p.id = r.player \
			    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date \
			    JOIN ( \
			            SELECT MAX(r2.id) as maxRunId, r2.player, r2.time \
			            FROM run r2 \
			            JOIN ( \
			                    SELECT r3.player, MIN(r3.time) AS minTime \
			                    FROM run r3 \
			                    WHERE \
			                            r3.is_valid = TRUE \
			                        AND r3.map = %d \
			                        AND (r3.type = 'pure' OR r3.type = 'pro') \
			                    GROUP BY r3.player \
			                    ORDER BY minTime ASC \
			            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime \
			            GROUP BY \
			                r2.player, \
			                r2.time \
			        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time \
			    ORDER BY r.time ASC",
			    g_MapId);
		}
		else
		{
			formatex(query, charsmax(query), "\
			    SELECT \
			        r.id, \
			        p.unique_id, \
			        pn.name, \
			        r.checkpoints, \
			        r.teleports, \
			        r.time, \
			        UNIX_TIMESTAMP(r.date) \
			    FROM \
			        run r \
			    INNER JOIN player p ON \
			        p.id = r.player \
			    INNER JOIN player_name pn ON \
			        pn.player = r.player AND pn.date = r.date \
			    WHERE \
			        r.is_valid = TRUE AND r.map = %d AND r.type = '%s' AND(r.player, r.time) IN( \
			        SELECT \
			            r2.player, \
			            MIN(r2.time) AS minTime \
			        FROM run r2 \
			        WHERE \
			                r2.is_valid = TRUE \
			            AND r2.map = %d \
			            AND r2.type = '%s' \
			        GROUP BY r2.player \
			        ORDER BY minTime ASC \
			    ) \
			    ORDER BY r.time ASC",
			    g_MapId, g_TopType[topType], g_MapId, g_TopType[topType]);
		}

		new data[1];
		data[0] = _:topType;

		mysql_query(g_DbConnection, "RunSelectHandler", query, data, sizeof(data));
	}
	else
		LoadRecordsFile(topType);

}

LoadRecordsFile(RUN_TYPE:topType)
{
	console_print(0, "LoadRecordsFile :: loading %s", g_StatsFile[topType]);
	new file = fopen(g_StatsFile[topType], "r");
	if (!file) return;

	new data[1024], stats[STATS], uniqueid[32], name[32], cp[24], tp[24];
	new kztime[24], timestamp[24];

	new Array:arr = g_ArrayStats[topType];
	if (!arr)
		arr = ArrayCreate(STATS);

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

GetMapIdAndLeaderboards()
{
	mysql_escape_string(g_EscapedMap, charsmax(g_EscapedMap), g_Map);

	// Insert the current map if doesn't exist
	new insertMapQuery[352];
	formatex(insertMapQuery, charsmax(insertMapQuery), "\
	    INSERT INTO map (name) \
	    SELECT '%s' \
	    FROM (select 1) as a \
	    WHERE NOT EXISTS( \
	        SELECT name \
	        FROM map \
	        WHERE name = '%s' \
	    ) \
	    LIMIT 1", g_EscapedMap, g_EscapedMap);

	mysql_query(g_DbConnection, "MapInsertHandler", insertMapQuery, g_EscapedMap, sizeof(g_EscapedMap));
}

GetSplitIds()
{
	for (new i = 0; i < ArraySize(g_OrderedSplits); i++)
	{
		new splitId[17], split[SPLIT];
		ArrayGetString(g_OrderedSplits, i, splitId, charsmax(splitId));
		TrieGetArray(g_Splits, splitId, split, sizeof(split));

		// Things to escape before inserting
		new escapedSplitId[33], escapedSplitName[65], escapedSplitNext[33];
		mysql_escape_string(escapedSplitId, charsmax(escapedSplitId), splitId);
		mysql_escape_string(escapedSplitName, charsmax(escapedSplitName), split[SPLIT_NAME]);
		mysql_escape_string(escapedSplitNext, charsmax(escapedSplitNext), split[SPLIT_NEXT]);

		// Insert the split if it doesn't exist
		new insertSplitQuery[448];
		formatex(insertSplitQuery, charsmax(insertSplitQuery), "\
		    INSERT INTO split (name, displayname, map, next) \
		    SELECT '%s', '%s', %d, '%s' \
		    FROM (select 1) as a \
		    WHERE NOT EXISTS( \
		        SELECT name, displayname, map \
		        FROM split \
		        WHERE name = '%s' \
		          AND map = %d \
		    ) \
		    LIMIT 1",
		    escapedSplitId, escapedSplitName, g_MapId, escapedSplitNext,
		    escapedSplitId, g_MapId);


		//server_print("GetSplitIds(): splitId: %s, id: %s, name: %s", splitId, split[SPLIT_ID], split[SPLIT_NAME], split[SPLIT_NEXT]);

		mysql_query(g_DbConnection, "SplitInsertHandler", insertSplitQuery, splitId, sizeof(splitId));
	}
}

LoadNoResetRecords()
{
	if (get_pcvar_num(pcvar_kz_mysql))
	{
		new query[704];
		formatex(query, charsmax(query), "\
		    SELECT t.unique_id, pn.name, t.average_time, t.runs, UNIX_TIMESTAMP(t.latest_run) \
		    FROM ( \
		        SELECT p.unique_id, p.id AS pid, AVG(r.time) AS average_time, COUNT(*) AS runs, MAX(r.date) AS latest_run \
		        FROM run r \
		        INNER JOIN player p ON p.id = r.player \
		        INNER JOIN map m ON m.id = r.map \
		        WHERE \
		            r.is_valid \
		            AND r.is_no_reset = true \
		            AND m.name = '%s' \
		        GROUP BY p.id \
		        ORDER BY average_time \
		    ) as t \
		    INNER JOIN player_name pn ON pn.player = t.pid AND pn.date = t.latest_run",
			g_EscapedMap);

		mysql_query(g_DbConnection, "SelectNoResetRunsHandler", query);
	}
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

FillQueryData(id, queryData[QUERY], RUN_TYPE:topType, stats[STATS])
{
	new pid;
	TrieGetCell(g_DbPlayerId, stats[STATS_ID], pid);

	queryData[QUERY_RUN_START_TS] = g_RunStartTimestamp[id];
	queryData[QUERY_RUN_TYPE] = topType;
	queryData[QUERY_NO_RESET] = g_RunMode[id] == MODE_NORESET;
	queryData[QUERY_PID] = pid;
	datacopy(queryData[QUERY_STATS], stats, sizeof(stats));
}

// Here instead of writing the whole file again, we just insert a few rows in the DB, so it's much less expensive in this case
SaveRunDB(queryData[QUERY])
{
	new escapedUniqueId[64];
	mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), queryData[QUERY_STATS][STATS_ID]);

	if (queryData[QUERY_PID])
	{
		PlayerNameInsert(queryData, sizeof(queryData));
	}
	else
	{
		new query[384];
		formatex(query, charsmax(query), "\
		    INSERT INTO player (unique_id) \
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
		mysql_query(g_DbConnection, "RunnerIdSelect", query, queryData, sizeof(queryData));
	}
}

// Refactor if somehow more than 2 tops have to be passed
// The second top is only in case you do a Pure that is
// better than your Pro record, so it gets updated in both
UpdateRecords(id, Float:kztime, RUN_TYPE:topType)
{
	new uniqueid[32], name[32], rank;
	new stats[STATS], insertItemId = -1, deleteItemId = -1;
	new minutes, Float:seconds, Float:slower, Float:faster;
	new RECORD_STORAGE_TYPE:storageType = RECORD_STORAGE_TYPE:get_pcvar_num(pcvar_kz_mysql);
	new bool:storeInMySql = storageType == STORE_IN_DB || storageType == STORE_IN_FILE_AND_DB;
	new Array:arr = g_ArrayStats[topType]; // contains the current leaderboard

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
				client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You failed your %s time by %02d:%0"),
					PLUGIN_TAG, g_TopType[topType], minutes, seconds);
			}

			if (storeInMySql)
			{
				// Runs that are pure and in no-reset mode are saved even if failed,
				// so we can later make the leaderboard for No-Reset averages
				new failedStats[STATS];
				copy(failedStats[STATS_ID], charsmax(failedStats[STATS_ID]), uniqueid);
				copy(failedStats[STATS_NAME], charsmax(failedStats[STATS_NAME]), name);
				failedStats[STATS_CP] = g_CpCounters[id][COUNTER_CP];
				failedStats[STATS_TP] = g_CpCounters[id][COUNTER_TP];
				failedStats[STATS_TIME] = _:kztime;
				failedStats[STATS_TIMESTAMP] = get_systime();

				new queryData[QUERY];
				FillQueryData(id, queryData, topType, failedStats);

				SaveRunDB(queryData);
			}

			return;
		}

		faster = stats[STATS_TIME] - kztime;
		minutes = floatround(faster, floatround_floor) / 60;
		seconds = faster - (60 * minutes);
		client_print(id, print_chat, GetVariableDecimalMessage(id, "[%s] You improved your %s time by %02d:%0"),
			PLUGIN_TAG, g_TopType[topType], minutes, seconds);

		deleteItemId = i;

		g_PbSplitsUpToDate[id] = false;

		break;
	}

	// Put into stats the current run's data
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

	if (storeInMySql)
	{
		// Every No-Reset pure run is saved in DB, so it's been already saved before, right before where failed runs are discarded
		new queryData[QUERY];
		FillQueryData(id, queryData, topType, stats);

		SaveRunDB(queryData);
	}

	if (storageType == STORE_IN_FILE || storageType == STORE_IN_FILE_AND_DB)
	{
		server_print("[%s] Saving records file", PLUGIN_TAG);
		SaveRecordsFile(topType);
	}

	if (g_RecordRun[id])
	{
		server_print("[%s] Stopped recording player #%d", PLUGIN_TAG, get_user_userid(id));
		SaveRecordedRun(id, topType);
	}

	if (rank == 1)
	{
		new ret;
		ExecuteForward(mfwd_hlkz_worldrecord, ret, topType, arr);

		LaunchRecordFireworks();
	}
}

ShowTopClimbersPbLaps(id, RUN_TYPE:topType)
{
	new cvarDefaultRecords = get_pcvar_num(pcvar_kz_top_records);
	new cvarMaxRecords = get_pcvar_num(pcvar_kz_top_records_max);

	// TODO: DRY, same as ShowTopClimbers
	// Get the info... from what record until what record we have to show
	new topArgs[2];
	GetRangeArg(topArgs); // e.g.: "say /pro 20-30" --> the '20' goes to topArgs[0] and '30' to topArgs[1]
	new recFrom = min(topArgs[0], topArgs[1]);
	new recTo = max(topArgs[0], topArgs[1]);
	if (recTo > ArraySize(g_ArrayStats[topType])) ShowMessage(id, "There are less records than requested");
	if (!recTo)	recTo = cvarDefaultRecords;
	if (recFrom < 0) recFrom = 0;
	if (recTo < 0) recTo = 1;
	if (recFrom) 	recFrom -= 1; // so that in "say /pro 1-20" it takes from 1 to 20 both inclusive
	// Yeah this one below is duplicated, because recTo may have changed in the previous checks and the first check is only to notify the player
	if (recTo > ArraySize(g_ArrayStats[topType])) recTo = ArraySize(g_ArrayStats[topType]); // there may be less records than the player is requesting, limit it to that amount
	if (recTo - cvarMaxRecords > recFrom)
	{
		// Limit max. records to show
		recTo = recFrom + cvarMaxRecords;
		client_print(id, print_chat, "[%s] Sorry, cannot load more than %d records at once", PLUGIN_TAG, cvarMaxRecords);
	}

	new query[80];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectBestProRunLaps(%d)", g_MapId);
	else
		formatex(query, charsmax(query), "CALL SelectBestRunLaps(%d, '%s')", g_MapId, g_TopType[topType]);

	set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], _, -1.0, _, 0.0, 999999.9);
	ShowSyncHudMsg(id, g_SyncHudLoading, "Loading...");

	new data[4];
	data[0] = id;
	data[1] = _:topType;
	data[2] = recFrom;
	data[3] = recTo;
	mysql_query(g_DbConnection, "PbLapsTopSelectHandler", query, data, sizeof(data));
}

ShowTopClimbersGoldLaps(id, RUN_TYPE:topType)
{
	new cvarDefaultRecords = get_pcvar_num(pcvar_kz_top_records);
	new cvarMaxRecords = get_pcvar_num(pcvar_kz_top_records_max);

	// TODO: DRY, same as ShowTopClimbers
	// Get the info... from what record until what record we have to show
	new topArgs[2];
	GetRangeArg(topArgs); // e.g.: "say /pro 20-30" --> the '20' goes to topArgs[0] and '30' to topArgs[1]
	new recFrom = min(topArgs[0], topArgs[1]);
	new recTo = max(topArgs[0], topArgs[1]);
	// FIXME: args not working, maybe being a query handler affects it somehow?
	//server_print("pre | from: %d -> to %d", recFrom, recTo);
	if (recTo > ArraySize(g_ArrayStats[topType])) ShowMessage(id, "There are less records than requested");
	if (!recTo)	recTo = cvarDefaultRecords;
	if (recFrom < 0) recFrom = 0;
	if (recTo < 0) recTo = 1;
	if (recFrom) 	recFrom -= 1; // so that in "say /pro 1-20" it takes from 1 to 20 both inclusive
	// Yeah this one below is duplicated, because recTo may have changed in the previous checks and the first check is only to notify the player
	if (recTo > ArraySize(g_ArrayStats[topType])) recTo = ArraySize(g_ArrayStats[topType]); // there may be less records than the player is requesting, limit it to that amount
	if (recTo - cvarMaxRecords > recFrom)
	{
		// Limit max. records to show
		recTo = recFrom + cvarMaxRecords;
		client_print(id, print_chat, "[%s] Sorry, cannot load more than %d records at once", PLUGIN_TAG, cvarMaxRecords);
	}

	new query[80];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectGoldProLaps(%d)", g_MapId);
	else
		formatex(query, charsmax(query), "CALL SelectGoldLaps(%d, '%s')", g_MapId, g_TopType[topType]);

	set_hudmessage(g_HudRGB[id][0], g_HudRGB[id][1], g_HudRGB[id][2], _, -1.0, _, 0.0, 999999.9);
	ShowSyncHudMsg(id, g_SyncHudLoading, "Loading...");

	new data[4];
	data[0] = id;
	data[1] = _:topType;
	data[2] = recFrom;
	data[3] = recTo;
	mysql_query(g_DbConnection, "GoldLapsTopSelectHandler", query, data, sizeof(data));
}

// FIXME: PRO leaderboard is not merged with PURE when using file storage
ShowTopClimbers(id, RUN_TYPE:topType)
{
	new buffer[MAX_MOTD_LENGTH], len;
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
	// Yeah this one below is duplicated, because recMax may have changed in the previous checks and the first check is only to notify the player
	if (recMax > ArraySize(arr)) recMax = ArraySize(arr); // there may be less records than the player is requesting, limit it to that amount
	if (recMax - cvarMaxRecords > recMin)
	{
		// Limit max. records to show
		recMax = recMin + cvarMaxRecords;
		client_print(id, print_chat, "[%s] Sorry, cannot load more than %d records at once", PLUGIN_TAG, cvarMaxRecords);
	}

	if (topType == NOOB)
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time       CP  TP         Date        Demo\n\n");
	else
		len = formatex(buffer[len], charsmax(buffer) - len, "#   Player             Time              Date        Demo\n\n");

	new szTopType[32], szTopTypeUCFirst[32];
	formatex(szTopType, charsmax(szTopType), g_TopType[topType]);
	formatex(szTopTypeUCFirst, charsmax(szTopTypeUCFirst), g_TopType[topType]);
	ucfirst(szTopTypeUCFirst);

	for (new i = recMin; i < recMax && charsmax(buffer) - len > 0; i++)
	{
		static authid[32], idNumbers[24], replayFile[256];
		ArrayGetArray(arr, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[STATS_NAME][17] = EOS;

		minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
		seconds = stats[STATS_TIME] - (60 * minutes);

		formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%0"), minutes, seconds);
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
		{
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s  %3d %3d        %s   %s\n",
								i + 1, stats[STATS_NAME], time, stats[STATS_CP], stats[STATS_TP], date, hasDemo ? "yes" : "no");
		}
		else
		{
			len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s         %s   %s\n",
								i + 1, stats[STATS_NAME], time, date, hasDemo ? "yes" : "no");
		}
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
	for (new i = 0; i < ArraySize(Array:g_ArrayStats[PURE]); i++)
	{
		ArrayGetArray(Array:g_ArrayStats[PURE], i, stats);

		if (equal(stats[STATS_ID], runnerId))
			return floatcmp(runnerTime, stats[STATS_TIME]);
	}
	return 1;
}

ShowTopNoReset(id)
{
	new buffer[MAX_MOTD_LENGTH], len;
	new stats[NORESET], date[32], time[32], minutes, Float:seconds;
	LoadNoResetRecords();

	new cvarDefaultRecords = get_pcvar_num(pcvar_kz_top_records);
	new cvarMaxRecords = get_pcvar_num(pcvar_kz_top_records_max);

	// TODO: DRY, same as ShowTopClimbers
	// Get the info... from what record until what record we have to show
	new topArgs[2];
	GetRangeArg(topArgs); // e.g.: "say /pro 20-30" --> the '20' goes to topArgs[0] and '30' to topArgs[1]
	new recMin = min(topArgs[0], topArgs[1]);
	new recMax = max(topArgs[0], topArgs[1]);
	if (recMax > ArraySize(g_NoResetLeaderboard)) ShowMessage(id, "There are less records than requested");
	if (!recMax)	recMax = cvarDefaultRecords;
	if (recMin < 0) recMin = 0;
	if (recMax < 0) recMax = 1;
	if (recMin) 	recMin -= 1; // so that in "say /pro 1-20" it takes from 1 to 20 both inclusive
	// Yeah this one below is duplicated, because recMax may have changed in the previous checks and the first check is only to notify the player
	if (recMax > ArraySize(g_NoResetLeaderboard)) recMax = ArraySize(g_NoResetLeaderboard); // there may be less records than the player is requesting, limit it to that amount
	if (recMax - cvarMaxRecords > recMin)
	{
		// Limit max. records to show
		recMax = recMin + cvarMaxRecords;
		client_print(id, print_chat, "[%s] Sorry, cannot load more than %d records at once", PLUGIN_TAG, cvarMaxRecords);
	}

	len = formatex(buffer[len], charsmax(buffer) - len, "#   Player               Avg. Time    Runs      Latest Run\n\n");

	for (new i = recMin; i < recMax && charsmax(buffer) - len > 0; i++)
	{
		ArrayGetArray(g_NoResetLeaderboard, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[NORESET_NAME][17] = EOS;

		minutes = floatround(stats[NORESET_AVG_TIME], floatround_floor) / 60;
		seconds = stats[NORESET_AVG_TIME] - (60 * minutes);

		formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%0"), minutes, seconds);
		format_time(date, charsmax(date), "%d/%m/%Y", stats[NORESET_LATEST_RUN]);

		len += formatex(buffer[len], charsmax(buffer) - len, "%-2d  %-17s  %10s  %3d        %s\n", i + 1, stats[NORESET_NAME], time, stats[NORESET_RUNS], date);
	}
	len += formatex(buffer[len], charsmax(buffer) - len, "\n%s %s", PLUGIN, VERSION);

	new header[36];
	formatex(header, charsmax(header), "No-Reset Average Times [%d-%d]", recMin ? recMin : 1, recMax);
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
// TODO: refactor to reduce confusion, make it return just the "%.3f" part for example
GetVariableDecimalMessage(id, msg1[], msg2[] = "")
{
	new sec[3]; // e.g.: number 6 in "%06.3f"
	new dec[3]; // e.g.: number 3 in "%06.3f"
	num_to_str(g_TimeDecimals[id], dec, charsmax(dec));
	new iSec = g_TimeDecimals[id] + 3; // the left part is the sum of all digits to be printed + 3 (= 2 digits for seconds + the dot)
	num_to_str(iSec, sec, charsmax(sec));

	new msg[192];
	strcat(msg, msg1, charsmax(msg));
	//strcat(msg, "0", charsmax(msg));
	strcat(msg, sec, charsmax(msg));
	strcat(msg, ".", charsmax(msg));
	strcat(msg, dec, charsmax(msg));
	strcat(msg, "f", charsmax(msg));
	strcat(msg, msg2, charsmax(msg));
	return msg;
}

RecordRunFrame(id)
{
	new Float:maxDuration = get_pcvar_float(pcvar_kz_max_replay_duration);
	new Float:kztime = get_gametime() - g_PlayerTime[id];

	if (maxDuration < kztime)
	{
		g_RecordRun[id] = 0;
		ArrayClear(g_RunFrames[id]);
		return;
	}

	new frameState[REPLAY];
	frameState[RP_TIME]    = get_gametime();
	frameState[RP_ORIGIN]  = g_Origin[id];
	frameState[RP_ANGLES]  = g_Angles[id];
	frameState[RP_BUTTONS] = pev(id, pev_button);
	frameState[RP_SPEED]   = xs_vec_len_2d(g_Velocity[id]);
	ArrayPushArray(g_RunFrames[id], frameState);
	//console_print(id, "[%.3f] recording run...", frameState[RP_TIME]);

}

SaveRecordedRun(id, RUN_TYPE:topType)
{
	static authid[32], replayFile[256], idNumbers[24];
	get_user_authid(id, authid, charsmax(authid));

	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(replayFile, charsmax(replayFile), "%s/%s_%s_%s.dat", g_ReplaysDir, g_Map, idNumbers, g_TopType[topType]);

	g_RecordRun[id] = fopen(replayFile, "wb");
	server_print("[%s] Saving run to: '%s'", PLUGIN_TAG, replayFile);

	//fwrite(g_RecordRun[id], DEMO_VERSION, BLOCK_SHORT); // version

	new frameState[REPLAY];
	for (new i; i < ArraySize(g_RunFrames[id]); i++)
	{
		ArrayGetArray(g_RunFrames[id], i, frameState);
		//fwrite_blocks(g_RecordRun[id], frameState, sizeof(frameState) - 1, BLOCK_INT); // gametime, origin and angles
		fwrite_blocks(g_RecordRun[id], frameState, sizeof(frameState) - 2, BLOCK_INT); // gametime, origin and angles
		fwrite(g_RecordRun[id], frameState[RP_BUTTONS], BLOCK_SHORT); // buttons
		// TODO: write the replay version and speed (RP_SPEED), simplify angles to 1 number and process with anglemod
	}
	fclose(g_RecordRun[id]);
	server_print("[%s] Saved %d frames to replay file", PLUGIN_TAG, ArraySize(g_RunFrames[id]));
}

SaveRecordedRunCup(id, RUN_TYPE:topType)
{
	static authid[32], replayFile[256], idNumbers[24];
	get_user_authid(id, authid, charsmax(authid));

	ConvertSteamID32ToNumbers(authid, idNumbers);
	formatex(replayFile, charsmax(replayFile), "%s/cup_%s_%s_%s_%d.dat",
		g_ReplaysDir, g_Map, idNumbers, g_TopType[topType], get_systime());

	g_RecordRun[id] = fopen(replayFile, "wb");
	server_print("[%s] Saving cup run to: '%s'", PLUGIN_TAG, replayFile);

	new frameState[REPLAY];
	for (new i; i < ArraySize(g_RunFrames[id]); i++)
	{
		ArrayGetArray(g_RunFrames[id], i, frameState);
		fwrite_blocks(g_RecordRun[id], frameState, sizeof(frameState) - 2, BLOCK_INT); // gametime, origin and angles
		fwrite(g_RecordRun[id], frameState[RP_BUTTONS], BLOCK_SHORT); // buttons
	}
	fclose(g_RecordRun[id]);
	server_print("[%s] Saved %d frames to cup replay file", PLUGIN_TAG, ArraySize(g_RunFrames[id]));
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

bool:GetSplitByEntityId(id, result[])
{
	new split[SPLIT];
	new TrieIter:ti = TrieIterCreate(g_Splits);
	while (!TrieIterEnded(ti))
	{
		TrieIterGetArray(ti, split, sizeof(split));

		if (id && split[SPLIT_ENTITY] == id)
		{
			TrieIterDestroy(ti);
			datacopy(result, split, sizeof(split));

			return true;
		}

		TrieIterNext(ti);
	}
	TrieIterDestroy(ti);

	return false;
}



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
	server_print("[%s] [%.3f] Inserted %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), what, queuetime);
}

// TODO: big SQL handling refactor
public SelectPlayerId(uniqueId[], size)
{
	new escapedUniqueId[64];
	mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), uniqueId);

	new query[384];
	formatex(query, charsmax(query), "\
	    INSERT INTO player (unique_id) \
	    SELECT '%s' \
	    FROM (select 1) as a \
	    WHERE NOT EXISTS( \
	        SELECT unique_id \
	        FROM player \
	        WHERE unique_id = '%s' \
	    ) \
	    LIMIT 1", escapedUniqueId, escapedUniqueId);

	mysql_query(g_DbConnection, "PlayerIdInsertHandler", query, uniqueId, size);
}

public PlayerIdInsertHandler(failstate, error[], errNo, uniqueId[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerIdInsertHandler(): [%d] - [%s] - [%s]", errNo, error, uniqueId);
		return;
	}

	// The last insert ID might not be reliable (I haven't checked the inner workings of this MySQL driver)
	// That's why we will do a SELECT to get the player ID from database
	if (mysql_affected_rows())
		server_print("[%s] [%.3f] Inserted runner (#%d?) with unique id %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), mysql_get_insert_id(), uniqueId, queuetime);

	new escapedUniqueId[64], query[112];
	mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), uniqueId);
	formatex(query, charsmax(query), "SELECT id FROM player WHERE unique_id = '%s'", escapedUniqueId);

	mysql_query(g_DbConnection, "PlayerIdSelectHandler", query, uniqueId, size);
}

public PlayerIdSelectHandler(failstate, error[], errNo, uniqueId[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerIdSelectHandler(): [%d] - [%s] - [%s]", errNo, error, uniqueId);
		return;
	}

	new pid = mysql_read_result(0);
	TrieSetCell(g_DbPlayerId, uniqueId, pid);

	new id = GetPlayerFromUniqueId(uniqueId);
	InitPlayerSplits(TASKID_INIT_PLAYER_GOLDS + id);

	server_print("[%s] [%.3f] Selected runner #%d with unique id %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), pid, uniqueId, queuetime);
}

public RunSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new RUN_TYPE:topType = RUN_TYPE:data[0];
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ RunSelectHandler(): [%d] - [%s] - [%s]", errNo, error, g_TopType[topType]);

		if (get_pcvar_num(pcvar_kz_mysql) == _:STORE_IN_FILE_AND_DB)
			LoadRecordsFile(topType);

		return;
	}

	new stats[STATS], rid, uniqueId[32], name[32], cp, tp, Float:kztime, timestamp;

	new Array:arr = g_ArrayStats[topType];
	if (!arr)
	{
		// TODO: check how is this being cleared, it should be defined by this time
		arr = ArrayCreate(STATS);
	}

	ArrayClear(arr);

	while (mysql_more_results())
	{
		rid = mysql_read_result(0);
		mysql_read_result(1, uniqueId, charsmax(uniqueId));
		mysql_read_result(2, name, charsmax(name));
		cp = mysql_read_result(3);
		tp = mysql_read_result(4);
		mysql_read_result(5, kztime);
		timestamp = mysql_read_result(6);

		// TODO check if this language allows to dump the data directly to the stats array

		stats[STATS_RUN_ID] = rid;
		stats[STATS_TIMESTAMP] = timestamp;
		copy(stats[STATS_ID], charsmax(stats[STATS_ID]), uniqueId);
		copy(stats[STATS_NAME], charsmax(stats[STATS_NAME]), name);
		stats[STATS_CP] = cp;
		stats[STATS_TP] = tp;
		stats[STATS_TIME] = _:kztime;

		ArrayPushArray(arr, stats);

		mysql_next_row();
	}

	server_print("[%s] [%.3f] Selected %s runs, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_TopType[topType], queuetime);
}

public SelectNoResetRunsHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SelectNoResetRunsHandler(): [%d] - [%s]", errNo, error);
		return;
	}

	new stats[NORESET], uniqueId[32], name[32], Float:avgtime, runs, latestRun;

	ArrayClear(g_NoResetLeaderboard);

	while (mysql_more_results())
	{
		mysql_read_result(0, uniqueId, charsmax(uniqueId));
		mysql_read_result(1, name, charsmax(name));
		mysql_read_result(2, avgtime);
		runs = mysql_read_result(3);
		latestRun = mysql_read_result(4);

		copy(stats[NORESET_ID], charsmax(stats[NORESET_ID]), uniqueId);
		copy(stats[NORESET_NAME], charsmax(stats[NORESET_NAME]), name);
		stats[NORESET_AVG_TIME] = _:avgtime;
		stats[NORESET_RUNS] = runs;
		stats[NORESET_LATEST_RUN] = latestRun;

		ArrayPushArray(g_NoResetLeaderboard, stats);

		mysql_next_row();
	}

	server_print("[%s] [%.3f] Selected No-Reset runs, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), queuetime);
}

// Gets the player id from the `player` table so we can use it to insert stuff in the `player_name` table
public RunnerIdSelect(failstate, error[], errNo, queryData[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ RunnerIdSelect(): [%d] - [%s] - [%s]", errNo, error, queryData);
		return;
	}

	server_print("[%s] [%.3f] Inserted runner %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), queryData[QUERY_STATS][STATS_ID], queuetime);

	if (queryData[QUERY_STATS][STATS_ID])
	{
		new escapedUniqueId[64], query[112];
		mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), queryData[QUERY_STATS][STATS_ID]);
		formatex(query, charsmax(query), "SELECT id FROM player WHERE unique_id = '%s'", escapedUniqueId);

		// Here one callback will call another, and that one will call another, and another...
		// because we have to wait until the previous data has been inserted, and only if it has been inserted at all
		// so we insert the player if doesn't exist, then the name they were using at that time, then the run corresponding to that player
		mysql_query(g_DbConnection, "RunnerIdSelectHandler", query, queryData, size);
	}
	else
	{
		// Something new must have been inserted in SaveRunDB() because there's no unique_id...
		// so we get directly the last inserted id
		queryData[QUERY_PID] = mysql_get_insert_id();
		PlayerNameInsert(queryData, size);
	}
}

// Gets the player id from the SELECT query result
public RunnerIdSelectHandler(failstate, error[], errNo, queryData[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ RunnerIdSelectHandler(): [%d] - [%s] - [%s]", errNo, error, queryData);
		return;
	}

	if (mysql_more_results())
		queryData[QUERY_PID] = mysql_read_result(0);

	server_print("[%s] [%.3f] Selected runner #%d, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), queryData[QUERY_PID], queuetime);

	PlayerNameInsert(queryData, size);
}

// Launches the query to insert the player name that was in use when the record was done
PlayerNameInsert(queryData[], size)
{
	new escapedName[64], query[512];
	mysql_escape_string(escapedName, charsmax(escapedName), queryData[QUERY_STATS][STATS_NAME]);
	formatex(query, charsmax(query), "\
		INSERT INTO player_name (player, name, date) \
	    SELECT %d, '%s', FROM_UNIXTIME(%i) \
	    FROM (select 1) as a \
	    WHERE NOT EXISTS( \
	        SELECT player, name, date \
	        FROM player_name \
	        WHERE player = %d AND name = '%s' AND date = FROM_UNIXTIME(%i) \
	    ) \
	    LIMIT 1",
	    queryData[QUERY_PID], escapedName, queryData[QUERY_STATS][STATS_TIMESTAMP],
	    queryData[QUERY_PID], escapedName, queryData[QUERY_STATS][STATS_TIMESTAMP]);

	mysql_query(g_DbConnection, "PlayerNameInsertHandler", query, queryData, size);
}

// Launches the query to insert the run
public PlayerNameInsertHandler(failstate, error[], errNo, queryData[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerNameInsertHandler(): [%d] - [%s] - [%s]", errNo, error, queryData);
		return;
	}
	server_print("[%s] [%.3f] Inserted name of the runner with PID %d, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), queryData[QUERY_PID], queuetime);

	new escapedUniqueId[64], query[576];
	mysql_escape_string(escapedUniqueId, charsmax(escapedUniqueId), queryData[QUERY_STATS][STATS_ID]);

	// This stored procedure inserts the run and then updates the corresponding splits so that they have the ID of this run
	// For this to work the splits should be inserted first. Right now they are because there's the player_name insert and
	// the run insert queries before this one, so it would be weird to have the splits update query run before the splits insert one,
	// but it's a race condition and has to be tackled at some moment... FIXME: make sure the run is inserted only after the splits insert
	formatex(query, charsmax(query), "\
	    CALL InsertRunAndUpdateSplits(%d, %d, '%s', %.6f, FROM_UNIXTIME(%i), FROM_UNIXTIME(%i), %d, %d, %d)",
	    queryData[QUERY_PID], g_MapId, g_TopType[queryData[QUERY_RUN_TYPE]], queryData[QUERY_STATS][STATS_TIME], queryData[QUERY_RUN_START_TS],
	    queryData[QUERY_STATS][STATS_TIMESTAMP], queryData[QUERY_STATS][STATS_CP], queryData[QUERY_STATS][STATS_TP], queryData[QUERY_NO_RESET]
	);

	mysql_query(g_DbConnection, "RunInsertHandler", query, queryData, size);
}

public RunInsertHandler(failstate, error[], errNo, queryData[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ RunInsertHandler(): [%d] - [%s] - [%d]", errNo, error, queryData[QUERY_RUN_TYPE]);
		return;
	}
	server_print("[%s] [%.3f] Inserted run with id #%d, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), mysql_read_result(0), queuetime);

	new id = GetPlayerFromUniqueId(queryData[QUERY_STATS][STATS_ID]);
	if (!g_PbSplitsUpToDate[id])
		LoadPlayerPbSplits(id);

	// Load records and hope that they're retrieved before the client requests the data (e.g.: writes /pure)
	LoadRecords(queryData[QUERY_RUN_TYPE]);

	if (queryData[QUERY_RUN_TYPE] == PURE)
	{
		// We have to do this as the pro leaderboard shows pure records if they're better
		// than the pro ones, so if something changes within pure stats, we have to update pro ones too
		LoadRecords(PRO);
	}

	if (queryData[QUERY_NO_RESET])
		LoadNoResetRecords();
}

public MapInsertHandler(failstate, error[], errNo, escapedMapName[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ MapInsertHandler(): [%d] - [%s] - [%s]", errNo, error, escapedMapName);
		return;
	}

	// TODO: do the SELECT first and if there are no results then do the INSERT, and get the id with mysql_get_insert_id()
	if (mysql_affected_rows())
		server_print("[%s] [%.3f] Inserted map %s (#%d), QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), escapedMapName, mysql_get_insert_id(), queuetime);

	new query[176];
	formatex(query, charsmax(query), "SELECT id FROM map WHERE name = '%s'", escapedMapName);
	mysql_query(g_DbConnection, "MapIdSelectHandler", query);
}

// Gets the map id corresponding to the map that is currently being played
// Then load leaderboards
public MapIdSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ MapIdSelectHandler(): [%d] - [%s]", errNo, error);
		return;
	}

	if (mysql_more_results())
		g_MapId = mysql_read_result(0);

	if (!g_MapId)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ MapIdSelectHandler(): Could not find the map id for %s", g_EscapedMap);
		server_print("Queries using the map id won't work, so storage to DB will be disabled to avoid weird stuff from happening");

		set_pcvar_num(pcvar_kz_mysql, _:STORE_IN_FILE);

		LoadRecordsFile(PURE);
		LoadRecordsFile(PRO);
		LoadRecordsFile(NOOB);

		return;
	}

	LoadRecords(PURE);
	LoadRecords(PRO);
	LoadRecords(NOOB);
	LoadNoResetRecords();

	if (ArraySize(g_OrderedSplits))
		GetSplitIds();

	server_print("[%s] [%.3f] Selected map #%d, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_MapId, queuetime);
}

public SplitInsertHandler(failstate, error[], errNo, splitId[], size, Float:queuetime)
{
	new escapedSplitId[33];
	mysql_escape_string(escapedSplitId, charsmax(escapedSplitId), splitId);

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SplitInsertHandler(): [%d] - [%s] - [%s]", errNo, error, escapedSplitId);
		return;
	}

	// TODO: do the SELECT first and if there are no results then do the INSERT, and get the id with mysql_get_insert_id()
	if (mysql_affected_rows())
		server_print("[%s] [%.3f] Inserted split #%d (%s), QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), mysql_get_insert_id(), splitId, queuetime);

	new query[192];
	formatex(query, charsmax(query), "SELECT id FROM split WHERE name = '%s' AND map = %d", escapedSplitId, g_MapId);
	mysql_query(g_DbConnection, "SplitIdSelectHandler", query, splitId, size);
}

public SplitIdSelectHandler(failstate, error[], errNo, splitId[], size, Float:queuetime)
{
	new escapedSplitId[33];
	mysql_escape_string(escapedSplitId, charsmax(escapedSplitId), splitId);

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SplitIdSelectHandler(): [%d] - [%s] - [%s]", errNo, error, escapedSplitId);
		return;
	}

	// TODO: check the displayname for this split and if it's different
	// to the one compiled into the map, override it with the one from DB

	new splitDbId = 0;
	if (mysql_more_results())
	{
		splitDbId = mysql_read_result(0);

		new split[SPLIT];
		TrieGetArray(g_Splits, splitId, split, sizeof(split));
		split[SPLIT_DB_ID] = splitDbId;
		TrieSetArray(g_Splits, splitId, split, sizeof(split));

	}
	server_print("[%s] [%.3f] Selected split #%d (%s), QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), splitDbId, splitId, queuetime);
}

SplitTimeInsert(id, sid, Float:splitTime, lapNumber, RUN_TYPE:topType, timestamp)
{
	if (IsBot(id))
		return;

	new uniqueid[32], pid;
	GetUserUniqueId(id, uniqueid, charsmax(uniqueid));
	TrieGetCell(g_DbPlayerId, uniqueid, pid);

	// Insert the split time if it doesn't exist
	new query[608];
	formatex(query, charsmax(query), "\
	    INSERT INTO split_run (split, player, lap, type, is_no_reset, time, date) \
	    SELECT %d, %d, %d, '%s', %d, %.6f, FROM_UNIXTIME(%i) \
	    FROM (select 1) as a \
	    WHERE NOT EXISTS( \
	        SELECT split, player, lap, type, is_no_reset, time, date \
	        FROM split_run \
	        WHERE \
	              split = %d \
	          AND player = %d \
	          AND type = '%s' \
	          AND date = FROM_UNIXTIME(%i) \
	    ) \
	    LIMIT 1",
	    sid, pid, lapNumber, g_TopType[topType], g_RunMode[id] == MODE_NORESET, splitTime, timestamp,
	    sid, pid, g_TopType[topType], timestamp);

	new data[1];
	data[0] = sid;
	mysql_query(g_DbConnection, "SplitTimeInsertHandler", query, data, sizeof(data));
}

public SplitTimeInsertHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new sid = data[0];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ SplitTimeInsertHandler(): [%d] - [%s] - [%d]", errNo, error, sid);
		return;
	}

	if (mysql_affected_rows())
	{
		server_print("[%s] [%.3f] Inserted split_run #%d for split #%d, QueueTime:[%.3f]",
			PLUGIN_TAG, get_gametime(), mysql_get_insert_id(), sid, queuetime);
	}
}

LapTimeInsert(id, lap, Float:lapTime, RUN_TYPE:topType, timestamp)
{
	if (IsBot(id))
		return;

	new uniqueid[32], pid;
	GetUserUniqueId(id, uniqueid, charsmax(uniqueid));
	TrieGetCell(g_DbPlayerId, uniqueid, pid);

	// Insert the split time if it doesn't exist
	new query[608];
	formatex(query, charsmax(query), "\
	    INSERT INTO lap_run (lap, player, map, type, is_no_reset, time, date) \
	    SELECT %d, %d, %d, '%s', %d, %.6f, FROM_UNIXTIME(%i) \
	    FROM (select 1) as a \
	    WHERE NOT EXISTS( \
	        SELECT lap, player, map, type, is_no_reset, time, date \
	        FROM lap_run \
	        WHERE \
	              lap = %d \
	          AND player = %d \
	          AND type = '%s' \
	          AND date = FROM_UNIXTIME(%i) \
	    ) \
	    LIMIT 1",
	    lap, pid, g_MapId, g_TopType[topType], g_RunMode[id] == MODE_NORESET, lapTime, timestamp,
	    lap, pid, g_TopType[topType], timestamp);

	new data[1];
	data[0] = lap;
	mysql_query(g_DbConnection, "LapTimeInsertHandler", query, data, sizeof(data));
}

public LapTimeInsertHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new lap = data[0];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ LapTimeInsertHandler(): [%d] - [%s] - [%d]", errNo, error, lap);
		return;
	}

	if (mysql_affected_rows())
	{
		server_print("[%s] [%.3f] Inserted lap_run #%d for lap #%d, QueueTime:[%.3f]",
			PLUGIN_TAG, get_gametime(), mysql_get_insert_id(), lap, queuetime);
	}
}

// TODO: DRY, refactor player's gold and PB times retrieval
PlayerGoldLapsSelect(id, RUN_TYPE:topType)
{
	new pid = 0;
	TrieGetCell(g_DbPlayerId, g_UniqueId[id], pid);

	new query[96];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectPlayerGoldProLaps(%d, %d)", g_MapId, pid);
	else
		formatex(query, charsmax(query), "CALL SelectPlayerGoldLaps(%d, %d, '%s')", g_MapId, pid, g_TopType[topType]);

	new data[2];
	data[0] = id;
	data[1] = _:topType;

	mysql_query(g_DbConnection, "PlayerGoldLapsSelectHandler", query, data, sizeof(data));
}

public PlayerGoldLapsSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerGoldLapsSelectHandler(): [%d] - [%s] - [%s] - [%s]", errNo, error, g_UniqueId[id], g_TopType[topType]);
		return;
	}

	new lap, Float:lapTime;

	while (mysql_more_results())
	{
		lap = mysql_read_result(0);
		mysql_read_result(1, lapTime);

		//console_print(id, "Retrieving gold %s lap #%d with time %.3f", g_TopType[topType], lap, lapTime);

		ArraySetCell(g_GoldLaps[id][topType], lap - 1, lapTime);

		mysql_next_row();
	}
	server_print("[%s] [%.3f] Selected gold %s laps for %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_TopType[topType], g_UniqueId[id], queuetime);
}

PlayerGoldSplitsSelect(id, RUN_TYPE:topType)
{
	new pid = 0;
	TrieGetCell(g_DbPlayerId, g_UniqueId[id], pid);

	new query[96];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectPlayerGoldProSplits(%d, %d)", g_MapId, pid);
	else
		formatex(query, charsmax(query), "CALL SelectPlayerGoldSplits(%d, %d, '%s')", g_MapId, pid, g_TopType[topType]);

	new data[2];
	data[0] = id;
	data[1] = _:topType;

	mysql_query(g_DbConnection, "PlayerGoldSplitsSelectHandler", query, data, sizeof(data));
}

public PlayerGoldSplitsSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerGoldSplitsSelectHandler(): [%d] - [%s] - [%s] - [%s]", errNo, error, g_UniqueId[id], g_TopType[topType]);
		return;
	}

	new split, lap, Float:splitTime;

	while (mysql_more_results())
	{
		split = mysql_read_result(0);
		lap = mysql_read_result(1);
		mysql_read_result(2, splitTime);

		//console_print(id, "Retrieving gold %s split %d-%d with time %.3f", g_TopType[topType], split, lap, splitTime);

		new splitIdx = (ArraySize(g_OrderedSplits) * (lap - 1)) + split;
		ArraySetCell(g_GoldSplits[id][topType], splitIdx - 1, splitTime);

		mysql_next_row();
	}
	server_print("[%s] [%.3f] Selected gold %s splits for %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_TopType[topType], g_UniqueId[id], queuetime);
}

PlayerPbLapsSelect(id, RUN_TYPE:topType)
{
	new pid = 0;
	TrieGetCell(g_DbPlayerId, g_UniqueId[id], pid);

	new query[96];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectPlayerPbProLaps(%d, %d)", g_MapId, pid);
	else
		formatex(query, charsmax(query), "CALL SelectPlayerPbLaps(%d, %d, '%s')", g_MapId, pid, g_TopType[topType]);

	new data[2];
	data[0] = id;
	data[1] = _:topType;

	mysql_query(g_DbConnection, "PlayerPbLapsSelectHandler", query, data, sizeof(data));
}

public PlayerPbLapsSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerPbLapsSelectHandler(): [%d] - [%s] - [%s] - [%s]", errNo, error, g_UniqueId[id], g_TopType[topType]);
		return;
	}

	new lap, Float:lapTime;

	while (mysql_more_results())
	{
		lap = mysql_read_result(0);
		mysql_read_result(1, lapTime);

		//console_print(id, "Retrieving PB run's %s lap #%d with time %.3f", g_TopType[topType], lap, lapTime);

		ArraySetCell(g_PbLaps[id][topType], lap - 1, lapTime);

		mysql_next_row();
	}
	server_print("[%s] [%.3f] Selected PB run's %s laps for %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_TopType[topType], g_UniqueId[id], queuetime);
}

PlayerPbSplitsSelect(id, RUN_TYPE:topType)
{
	new pid = 0;
	TrieGetCell(g_DbPlayerId, g_UniqueId[id], pid);

	new query[96];
	if (topType == PRO)
		formatex(query, charsmax(query), "CALL SelectPlayerPbProSplits(%d, %d)", g_MapId, pid);
	else
		formatex(query, charsmax(query), "CALL SelectPlayerPbSplits(%d, %d, '%s')", g_MapId, pid, g_TopType[topType]);

	new data[2];
	data[0] = id;
	data[1] = _:topType;

	mysql_query(g_DbConnection, "PlayerPbSplitsSelectHandler", query, data, sizeof(data));
}

public PlayerPbSplitsSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PlayerPbSplitsSelectHandler(): [%d] - [%s] - [%s] - [%s]", errNo, error, g_UniqueId[id], g_TopType[topType]);
		return;
	}

	new split, lap, Float:splitTime;

	while (mysql_more_results())
	{
		split = mysql_read_result(0);
		lap = mysql_read_result(1);
		mysql_read_result(2, splitTime);

		//console_print(id, "Retrieving PB run's %s split %d-%d with time %.3f", g_TopType[topType], split, lap, splitTime);

		new splitIdx = (ArraySize(g_OrderedSplits) * (lap - 1)) + split;
		ArraySetCell(g_PbSplits[id][topType], splitIdx - 1, splitTime);

		mysql_next_row();
	}
	server_print("[%s] [%.3f] Selected PB run's %s splits for %s, QueueTime:[%.3f]", PLUGIN_TAG, get_gametime(), g_TopType[topType], g_UniqueId[id], queuetime);
}

public PbLapsTopSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];
	new recFrom = data[2];
	new recTo = data[3];

	ClearSyncHud(id, g_SyncHudLoading);

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ PbLapsTopSelectHandler(): [%d] - [%s] - [%s]", errNo, error, g_TopType[topType]);
		return;
	}

	new len, buffer[MAX_MOTD_LENGTH], time[32], minutes, Float:seconds, totalLaps;

	new runId, name[32], lap, Float:lapTime;

	new prevRank, rank, prevRunId;
	while (mysql_more_results())
	{
		runId = mysql_read_result(0);
		mysql_read_result(1, name, charsmax(name));
		lap = mysql_read_result(2);
		mysql_read_result(3, lapTime);

		if (totalLaps < lap)
			totalLaps = lap;

		if (runId != prevRunId)
		{
			// The data corresponds to a different run than we had before, so it's already the next run
			rank++;
		}
		prevRunId = runId;

		if (rank < recFrom || rank > recTo)
		{
			mysql_next_row();
			continue;
		}

		if (prevRank != rank)
			len += formatex(buffer[len], charsmax(buffer) - len, "\n%-2d  %-17s", rank, name);

		prevRank = rank;

		// Put the lap time into "mm:ss.ms" format
		minutes = floatround(lapTime, floatround_floor) / 60;
		seconds = lapTime - (60 * minutes);
		formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%0"), minutes, seconds);

		len += formatex(buffer[len], charsmax(buffer) - len, "  %10s", time);

		mysql_next_row();
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "\n\n%s %s", PLUGIN, VERSION);


	new header[48], subHeader[96];

	// Sub-header text
	new shLen = 0;
	if (totalLaps)
	{
		shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "#   Player           ");
		for (new i = 1; i <= totalLaps; i++)
		{
			shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "   Lap %3d  ", i);
		}
	}
	else
		shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "#   Player               Laps\n");

	formatex(header, charsmax(header), "Lap Times From PB Runs [%d-%d]", recFrom ? recFrom : 1, recTo);
	format(buffer, charsmax(buffer), "%s\n%s", subHeader, buffer);
	show_motd(id, buffer, header);
}

public GoldLapsTopSelectHandler(failstate, error[], errNo, data[], size, Float:queuetime)
{
	new id = data[0];
	new RUN_TYPE:topType = RUN_TYPE:data[1];
	new recFrom = data[2];
	new recTo = data[3];

	ClearSyncHud(id, g_SyncHudLoading);

	if (failstate != TQUERY_SUCCESS)
	{
		log_to_file(MYSQL_LOG_FILENAME, "ERROR @ GoldLapsTopSelectHandler(): [%d] - [%s] - [%s]", errNo, error, g_TopType[topType]);
		return;
	}

	new len, timeBufLen, buffer[MAX_MOTD_LENGTH], timeBuf[MAX_MOTD_LENGTH - 256], time[32], minutes, Float:seconds, totalLaps;

	// TODO: try to refactor, too complex, also it could be easier but not taking
	// some things for granted like lap amount, since it might not be always 5 in the
	// future or in other maps, and we want to keep compatibility with querying tops
	// of other maps than the current one, with a possibly different total laps number

	new uniqueId[32], name[32], lap, Float:lapTime;
	new prevRank, rank, prevUniqueId[32], prevName[32], nameToDisplay[32];

	new i = 1;
	while (mysql_more_results())
	{
		mysql_read_result(0, uniqueId, charsmax(uniqueId));
		mysql_read_result(1, name, charsmax(name)); // has NULL for all laps except the last one
		lap = mysql_read_result(2);
		mysql_read_result(3, lapTime);

		if (totalLaps < lap)
			totalLaps = lap;

		if (prevUniqueId[0] && !equal(uniqueId, prevUniqueId))
		{
			// The data corresponds to a different run than we had before, so it's already the next run
			rank++;
			copy(nameToDisplay, charsmax(nameToDisplay), prevName);
		}
		copy(prevUniqueId, charsmax(prevUniqueId), uniqueId);
		copy(prevName, charsmax(prevName), name);

		//server_print("i=%d, prevRank=%d, rank=%d, lap=%d, name=%s, uniqueId=%s, prevUniqueId=%s", i, prevRank, rank, lap, name, uniqueId, prevUniqueId);

		if (rank < recFrom || rank > recTo)
		{
			i++;
			mysql_next_row();
			continue;
		}

		if (prevRank != rank)
		{
			len += formatex(buffer[len], charsmax(buffer) - len, "\n%-2d  %-17s%s", rank, nameToDisplay, timeBuf);
			timeBuf[0] = EOS;
			timeBufLen = 0;
		}
		prevRank = rank;

		// Put the lap time into "mm:ss.ms" format
		minutes = floatround(lapTime, floatround_floor) / 60;
		seconds = lapTime - (60 * minutes);
		formatex(time, charsmax(time), GetVariableDecimalMessage(id, "%02d:%0"), minutes, seconds);

		timeBufLen += formatex(timeBuf[timeBufLen], charsmax(timeBuf) - timeBufLen, "  %10s", time);

		i++;
		mysql_next_row();
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "\n%-2d  %-17s%s", ++rank, name, timeBuf);

	len += formatex(buffer[len], charsmax(buffer) - len, "\n\n%s %s", PLUGIN, VERSION);


	new header[48], subHeader[96];

	// Sub-header text
	new shLen = 0;
	if (totalLaps)
	{
		shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "#   Player           ");
		for (new i = 1; i <= totalLaps; i++)
		{
			shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "   Lap %3d  ", i);
		}
	}
	else
		shLen += formatex(subHeader[shLen], charsmax(subHeader) - shLen, "#   Player               Laps\n");

	formatex(header, charsmax(header), "Gold Lap Times [%d-%d]", recFrom ? recFrom : 1, recTo);
	format(buffer, charsmax(buffer), "%s\n%s", subHeader, buffer);
	show_motd(id, buffer, header);
}

/*
------------------------------------------
Query to get Pure WR Top:
------------------------------------------
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

------------------------------------------
Query to get Pure WRs of a given player:
------------------------------------------
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
