/*
 * Helper functions used by the HL_KreedZ plugin
 */


#if defined _hlkz_included
	#endinput
#endif
#define _hlkz_included

#pragma reqlib hlkz
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib hlkz
#endif

#include <amxmodx>
#include <fakemeta>
#include <xs>


#define MAX_PLAYERS    32
#define MAX_MATCH_MAPS 101


/**
 * Called when +hook/+rope/healthbooster/noclip is used
 * @param id           client id of the player that cheated
 */
forward hlkz_cheating(id);

/**
 * Called when a map's best time is beaten
 * @param type         run type: 0 = pure, 1 = pro, 2 = noob
 * @param top          Array with items of type STATS, which includes the info relative to the run
 */
forward hlkz_worldrecord(type, Array:top);

/**
 * Called when a run's timer start
 * @param id           client id of the player that is starting a run
 */
forward hlkz_timer_start(id);

/**
 * Called after displaying the welcome message to a player, 1.4s after client_putinserver(),
 * but only when there's an ongoing match and for those who are put in spectator mode (or not yet)
 * to set a default spectating behaviour to them, like switching them automatically to some match
 * player's viewpoint
 * @param id           client id of the player that is starting a run
 */
forward hlkz_postwelcome(id);

/**
 * Called when a match ends due to explicit agabort, timelimit or some player hitting the end button
 */
forward hlkz_stop_match();

/**
 * Called when a run ends, after writing the time to the leaderboard file, and before resetting
 * player state, like the recording of the run. Note that if database storage is enabled (kz_mysql 1 or 2)
 * it will very likely execute before the run gets inserted to database, since that may take some time
 * @param id           client id of the player that finished a run
 */
forward hlkz_run_finish(id);

/**
 * Called when a player disconnects (client_disconnect() forward), before clearing player state
 * @param id           client id of the player that is disconnecting
 */
forward hlkz_pre_save_on_disconnect(id);


// What kind of run a player is doing. A normal run, no-reset run, race or agstart
native RUN_MODE:HLKZ_GetRunMode(id);

// Whether the map uses a starting area as opposed to a start button
native bool:HLKZ_UsesStartingZone();

// Whether a player is allowed to teleport to some checkpoint
native bool:HLKZ_CanTeleportNr(id, cpType);

// Get the color that a player has set for the HUD elements shown by HLKZ
native HLKZ_GetHudColor(id, rgb[]);

// Show a message on HUD or chat to a player, depending on the kz_messages cvar
native HLKZ_ShowMessage(id, const message[]);

// Get a player's unique identifier, which depends on the kz_uniqueid cvar (it may be steam ID, ip, colorless nickname)
native HLKZ_GetUserUniqueId(id, uniqueId[]);

// Save a serverside recording of a player's run, with the demo name prefixed
native HLKZ_SaveRecordedRun(id, prefix[]);

// Whether there's an agstart run ongoing
native HLKZ_IsMatchRunning();

// Allow switching from/to spectator mode or not
native HLKZ_AllowSpectate(bool:status);

// Whether a player is participating in an agstart run
native HLKZ_IsPlayingMatch(id);


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

// TODO: maybe rename to something more accurate
enum _:STATS
{
	STATS_RUN_ID,
	STATS_ID[32],
	STATS_NAME[32],
	STATS_CP,
	STATS_TP,
	Float:STATS_TIME,	// Timer value
	STATS_TIMESTAMP 	// Date
}

enum _:RUNSTATS
{
	Float:RS_AVG_FPS,
	Float:RS_MIN_FPS,
	Float:RS_AVG_SPEED,
	Float:RS_MAX_SPEED,
	Float:RS_END_SPEED,
	Float:RS_PRESTRAFE_SPEED,
	Float:RS_PRESTRAFE_TIME,
	Float:RS_TIMELOSS_START,
	Float:RS_TIMELOSS_END,
	Float:RS_DISTANCE_2D,
	Float:RS_DISTANCE_3D,
	Float:RS_LAST_FAIL_ORIGIN[3],
	RS_JUMPS,
	RS_DUCKTAPS,
	RS_SLOWDOWNS
}

enum RUN_TYPE
{
	NOOB,
	PRO,
	PURE
}

enum RUN_MODE
{
	MODE_NORMAL,		// not racing, not in agstart, not in a No-Rest run... so definitely a normal run without countdowns
	MODE_AGSTART,
	MODE_RACE,
	MODE_NORESET
}

enum AGVOTE_STATUS
{
	AGVOTE_NOT_RUNNING,
	AGVOTE_CALLED,
	AGVOTE_ACCEPTED,
	AGVOTE_DENIED
}

enum KZVOTE_VALUE
{
	KZVOTE_NO,
	KZVOTE_YES,
	KZVOTE_UNKNOWN,	// this player doesn't know about the vote, it was not shown/directed to him
	//KZVOTE_UNDECIDED
}

// Encapsulates all the info that might be required in the different queries to DB
enum _:QUERY
{
	RUN_TYPE:QUERY_RUN_TYPE,  // pure, pro, noob
	QUERY_PID,                // player ID in database
	QUERY_NO_RESET,           // was no-reset mode set for this run?
	QUERY_STATS[STATS],       // steam ID, nickname, cps, tps, run duration, end date
	QUERY_RUN_START_TS,	      // timestamp of the time the run was started, might have to put this into STATS instead
	QUERY_RUNSTATS[RUNSTATS], // start/end/average speed, average fps
	QUERY_HLKZ_VERSION        // id in database for the HLKZ version
}

enum _:NORESET
{
	NORESET_ID[32],
	NORESET_NAME[32],
	Float:NORESET_AVG_TIME,
	NORESET_RUNS,
	NORESET_LATEST_RUN
}

enum _:COLOR
{
	COLOR_RED, 
	COLOR_GREEN,
	COLOR_BLUE,
	COLOR_NAME[32]
}

enum KZ_VOTE_POSITION
{
	POSITION_LEFT,
	POSITION_CENTER,
	POSITION_RIGHT
}

enum MAP_STATE
{
	MAP_IDLE,
	MAP_BANNED,
	MAP_PICKED,
	MAP_PLAYED,
	MAP_DECIDER
}

enum PLAYER_FORMAT
{
	PF_UNKNOWN = 0,
	PF_PLAYER1 = 'A',
	PF_PLAYER2 = 'B',
	PF_DECIDER = 'D'
}

enum MAP_FORMAT
{
	MF_UNKNOWN = 0,
	MF_BAN     = 'B',
	MF_PICK    = 'P',
	MF_DECIDER = 'D'
}

enum _:CUP_MAP
{
	MAP_ORDER,
	MAP_STATE:MAP_STATE_,
	MAP_NAME[MAX_MAPNAME_LENGTH],
	PLAYER_FORMAT:MAP_PICKER
}

enum MOVEMENT_STATE
{
	MOVEMENT_OTHER,
	MOVEMENT_JUMPING,
	MOVEMENT_DUCKTAPPING
}

enum CHAT_TYPE (<<= 1)
{
	CHAT_NONE  = 0,
	CHAT_RUN_FINISHED = 1,
	CHAT_RUN_PB,
	CHAT_RUN_PB_TOP15,
	CHAT_RUN_WR
}

/*
new const g_CupFormatLetters[][] =
{
	"?",
	"A",
	"B",
	"D"
}
*/
new const g_KzVotePositionString[][] =
{
	"left",
	"center",
	"right"
};

new const Float:g_KzVotePosition[] =
{
	0.05,
	-1.0,
	0.75
};

stock const g_MapStateString[][] =
{
	"",
	"banned",
	"picked",
	"played",
	"decider"
};

new const HLKZ_LOG_FILENAME[] = "hl_kreedz.log";


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

GetColorlessName(id, name[], len)
{
	get_user_name(id, name, len);

	// Clear out color codes
	new i, j;
	new const hat[3] = "^^";
	while (name[i])
	{
		if (name[i] == hat[0] && name[i + 1] >= '0' && name[i + 1] <= '9')
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

// Get the normal of the plane that is in the given direction from the player
GetNormalPlaneRelativeToPlayer(id, Float:start[3], Float:direction[3], Float:origin[3], Float:normal[3])
{
	static Float:dest[3];
	// Make a vector that points to the given direction, and add it to the player position
	xs_vec_add(start, direction, dest);

	// Declare a handle for the traceline function and a variable to hold the distance
	// between the player and the brush at the sides of them
	static tr, Float:dist;
	tr = create_tr2();
	engfunc(EngFunc_TraceLine, start, dest, IGNORE_MONSTERS, id, tr);
	// Put the endpoint, where we hit a brush, into the variable origin
	get_tr2(tr, TR_vecEndPos, origin);
	// Get the distance between the player and the endpoint
	dist = get_distance_f(start, origin);

	origin[0] -= (origin[0] - start[0])/dist;
	origin[1] -= (origin[1] - start[1])/dist;
	origin[2] -= (origin[2] - start[2])/dist;

	// This returns the vector that is perpendicular to the surface in the given direction from the player
	get_tr2(tr, TR_vecPlaneNormal, normal);
	free_tr2(tr);
}

// Get the normal of the nearest plane at a side of the player,
// (e.g.: player is surfing a slope, get that slope's plane the player is touching)
GetNormalPlaneAtSideOfPlayer(id, Float:start[3], Float:origin[3], Float:normal[3])
{
	new Float:lfOrigin[3], Float:rtOrigin[3], Float:lfNormal[3], Float:rtNormal[3];
	GetNormalPlaneRelativeToPlayer(id, start, Float:{-9999.0, 0.0, 0.0}, lfOrigin, lfNormal); // get plane at left
	GetNormalPlaneRelativeToPlayer(id, start, Float:{9999.0, 0.0, 0.0}, rtOrigin, rtNormal); // get plane at right

	new Float:px = start[0], Float:lfox = lfOrigin[0], Float:rtox = rtOrigin[0];

	if (floatabs(px - lfox) <= floatabs(px - rtox)) // what if both planes are at the same distance
	{
		origin = lfOrigin;
		normal = lfNormal;
	}
	else
	{
		origin = rtOrigin;
		normal = rtNormal;
	}
}

// e.g.: say "/decimals 4" // get the '4'
GetNumberArg()
{
	new cmdArg[64], numberPart[64];
	read_args(cmdArg, charsmax(cmdArg));

	new bool:prevWasDigit = false;
	for (new i = 0; cmdArg[i]; i++)
	{
		if (isdigit(cmdArg[i]))
		{
			add(numberPart, charsmax(numberPart), cmdArg[i], 1);
			prevWasDigit = true;
		}
		else if (prevWasDigit)
			break; // e.g.: say "/top 42 some text and 123 numbers here" --> get out when parsing the '42'
	}
	return str_to_num(numberPart);
}

// e.g.: say "/speedcap 499.5" // get the '499.5'
Float:GetFloatArg(str[]="", pos=0)
{
	new cmdArg[64], unused[64], aux[64];

	if (str[0])
		formatex(cmdArg, charsmax(cmdArg), str);
	else
	{
		read_args(aux, charsmax(aux));
		remove_quotes(aux);
		trim(aux);
		strtok2(aux, unused, charsmax(unused), cmdArg, charsmax(cmdArg), _, 1);

		if (!cmdArg[0])
		{
			// Couldn't split by whitespace, so it's probably messagemode or something
			copy(cmdArg, charsmax(cmdArg), unused);
		}
	}

	new _pos = pos;
	return GetNextFloat(cmdArg, _pos);
}

// e.g.: say "/pro 1-18" --> get the 1 and 18 in an array of 2 cells
GetRangeArg(range[2])
{
	new cmdArg[32], numberPart[2][32];
	read_args(cmdArg, charsmax(cmdArg));
	//remove_quotes(cmdArg); trim(cmdArg);

	if (isdigit(cmdArg[0]))
	{
		// ignoring slot# commands as they're used to choose from menus, and those show a default amount of records
		range[0] = 0;
		range[1] = 0;
		// dunno if it's necessary in Pawn to set these cells to 0 or they're by default
	}
	else
	{	
		new bool:prevWasDigit = false;
		for (new i = 0, j = 0; cmdArg[i] && j < 2; i++)
		{
			if (isdigit(cmdArg[i]))
			{
				new aux[32];
				formatex(aux, charsmax(aux), "%s%s", numberPart[j], cmdArg[i]);
				numberPart[j] = aux;
				prevWasDigit = true;
			}
			else if (prevWasDigit)
			{
				prevWasDigit = false;
				j++; // e.g.: say "/top 15-30 some text and 123 numbers here" --> get out when parsing the '30', having also stored the previous number '15'
			}
		}
		range[0] = str_to_num(numberPart[0]);
		range[1] = str_to_num(numberPart[1]);
	}
}

Float:GetDistancePlayerAiming(id)
{
	new pOrigin[3], aimOrigin[3];
	new Float:distance;

	get_user_origin(id, aimOrigin, 3); // aim end position from client position
	get_user_origin(id, pOrigin, 1); // position of eyes

	new Float:pOriginX = float(pOrigin[0]); // convert to float
	new Float:pOriginY = float(pOrigin[1]);
	new Float:aimOriginX = float(aimOrigin[0]);
	new Float:aimOriginY = float(aimOrigin[1]);			

	distance = floatsqroot((pOriginX - aimOriginX) * (pOriginX - aimOriginX) + (pOriginY - aimOriginY) * (pOriginY - aimOriginY));
	return distance;
}

Float:GetHeightDiffPlayerAiming(id)
{
	new Float:pOrigin[3], Float:aimOrigin[3], Float:aimNormal[3];
	GetAimingPoint(id, aimOrigin, aimNormal);
	pev(id, pev_origin, pOrigin);

	new Float:feetZ = (pev(id, pev_flags) & FL_DUCKING) ? -18.0 : -36.0;
	new Float:heightDiff = floatabs(pOrigin[2] + feetZ - aimOrigin[2]);

	return heightDiff;
}

GetAimingPoint(id, Float:end[3], Float:normal[3])
{
	new Float:origin[3], Float:angles[3], Float:viewOffsets[3];
	pev(id, pev_origin, origin);
	pev(id, pev_v_angle, angles);
	pev(id, pev_view_ofs, viewOffsets);

	new Float:start[3];
	xs_vec_add(origin, viewOffsets, start);
	angle_vector(angles, ANGLEVECTOR_FORWARD, angles);
	xs_vec_mul_scalar(angles, 9999.9, angles);
	// Store in end a far away (outside the map probably) point where we're aiming
	xs_vec_add(angles, start, end);

	// Trace a line until that point and get the origin of the point
	// where the line first collided with some wall or something
	new tr = create_tr2();
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS | IGNORE_MISSILE, id, tr);
	get_tr2(tr, TR_vecEndPos, end); // now this is exactly the point where we're aiming
	get_tr2(tr, TR_vecPlaneNormal, normal);

	free_tr2(tr);
}

/*
// You have to pass the numbers of a SteamID in the format X_Y_Z (without STEAM_) and it stores in the result the full SteamID (like STEAM_X:Y:Z)
ConvertNumbersToSteamID32(numbers[], result[])
{
    new a[2], b[2], c[11];
    xs_strmid(numbers, a, 0, 0);
    xs_strmid(numbers, b, 2, 2);
    xs_strmid(numbers, c, 4, charsmax(numbers[]));

    formatex(result, charsmax(result), "STEAM_%s:%s:%s", a, b, c);
}
*/

// You have to pass a STEAM_X:Y:Z and it stores in the result the numbers in the X_Y_Z format (without STEAM_)
ConvertSteamID32ToNumbers(steamId32[], result[])
{
    new a[2], b[2], c[11];
    xs_strmid(steamId32, a, 6, 6);
    xs_strmid(steamId32, b, 8, 8);
    xs_strmid(steamId32, c, 10, charsmax(steamId32[]));

    formatex(result, 24, "%s_%s_%s", a, b, c);
}

/* DOESN'T WORK DUE TO INT64 NOT BEING AVAILABLE IN AMXMODX OR PAWN
// You have to pass the Community ID (e.g.: a number higher than 76561197960265728) and the string for the result to be stored
public ConvertSteamID64to32(steamId64, result[])
{
	// FIXME calculate correctly the universe, because for my id it calculates a 3 for universe which is wrong, should be 0
	//new universe = (steamId64 >> 56) & 255;
	//if (universe == 1) universe = 0;
	new accountIdLowBit = steamId64 & 1;
	new accountIdHighBits = (steamId64 >> 1) & 134217727;

	//formatex(result, charsmax(result), "STEAM_%d:%d:%d", universe, accountIdLowBit, accountIdHighBits);
	formatex(result, charsmax(result), "STEAM_0:%d:%d", accountIdLowBit, accountIdHighBits); // hardcoded 0 universe while calc is broken, haven't seen in logs any with a different universe
}
*/

/* DOESN'T WORK DUE TO INT64 NOT BEING AVAILABLE IN AMXMODX OR PAWN
// You have to pass a STEAM_X:Y:Z and it stores in the result the Community ID (e.g.: a number higher than 76561197960265728), or nothing if something went wrong
public ConvertSteamID32to64(steamId32[], result[])
{
    // ID64 = 76561197960265728 + (B * 2) + A
    // ID3 = (B * 2) + A
    // ID32 = STEAM_0:A:B

    new a[2], b[11];
    server_print("steamId32: %s", steamId32);
    xs_strmid(steamId32, a, 8, 9);
    xs_strmid(steamId32, b, 10, charsmax(steamId32[]));
    server_print("a: %s, b: %s", a, b);

    if (isdigit(a[0]) && isdigit(b[0]))
    {
	    new x = str_to_num(a), y = str_to_num(b);
    	server_print("x: %s, y: %s", a, b);
	    new id64 = ((y * 2) + x) + 76561197960265728; // error, max int32 type
	    server_print("id64: %d", id64);
	    num_to_str(id64, result, charsmax(result));
    }
}
*/

// Returns the passed string now filled with the corresponding text
GetTopTypeString(RUN_TYPE:runType, topType[], size) {
	switch (runType)
	{
		// TODO I think the same term should be used everywhere, but I also think that "noob" would be more correct than "nub",
		// and leaderboard files for the NOOB top already have _nub in the name... so I guess it should be kept like that
		// not to have to check everytime for both "noob" and "nub" or lose backwards compatibility 
		case NOOB: formatex(topType, size, "nub");
		case PRO:  formatex(topType, size, "pro");
		case PURE: formatex(topType, size, "pure");
	}
}

// Returns a RUN_TYPE
/*
GetTopTypeFromString(topType[]) {
	new type[64];
	formatex(type, charsmax(type), topType);
	strtolower(type);
	switch (type)
	{
		case "nub" : return NOOB;
		case "noob": return NOOB;
		case "pro" : return PRO;
		case "pure": return PURE;
	}
}
*/

/**
 * Copies information from one array into another. By Tirant
 * https://forums.alliedmods.net/showthread.php?t=166930
 * 
 * @param into        The array to place the data into
 * @param from        The array to get the data from
 * @param len         The number of cells to copy
 * @param ignoretags  True to enable tag comparison, false to
 *                    ignore them.
 * @param intotag     The tagof constant for the into array
 * @param intosize    The max size of data to place into
 *                    the array
 * @param intopos     The starting position to place data
 *                    into
 * @param fromtag     The tagof constant for the from array
 * @param fromsize    The max size of data to place from
 *                    the array
 * @param frompos     The starting position to begin copying
 *                    data from
 */
stock arraycopy( any:into[], any:from[], len = sizeof into, bool:ignoretags = false, intotag = tagof into, intosize = sizeof into, intopos = 0, fromtag = tagof from, fromsize = sizeof from, frompos = 0)
{
    if (!ignoretags && intotag != fromtag)
    {
        //So we know no elements were copied (we did not remove an element ie. returning -1)
        return 0;
    }
    
    new i;
    while (i < len)
    {
        if (intopos >= intosize || frompos >= fromsize)
            break;
        
        into[intopos++] = from[frompos++];
        i++;
    }
    
    return i;
}

stock datacopy(any:into[], any:from[], positionsToCopy, intoStartPos = 0, fromStartPos = 0)
{
	new i;
	while (i < positionsToCopy) {
        into[intoStartPos++] = from[fromStartPos++];
        i++;
    }
}

stock GetNumberOfBitsSet(iBitField)
{
	iBitField = iBitField - ((iBitField >> 1) & 0x55555555);
	iBitField = (iBitField & 0x33333333) + ((iBitField >> 2) & 0x33333333);
	return (((iBitField + (iBitField >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}

CreateColor(color[], name[], red, green, blue)
{
	color[COLOR_RED] = red;
	color[COLOR_GREEN] = green;
	color[COLOR_BLUE] = blue;
	add(color[COLOR_NAME], COLOR_NAME, name);
}

DestroyMenus(id)
{
	new menu, newmenu;
	player_menu_info(id, menu, newmenu);

	if (newmenu != -1)
		menu_destroy(newmenu);
}

bool:HasMovementKeys(buttons)
{
	return !!(buttons & (IN_MOVELEFT|IN_MOVERIGHT|IN_FORWARD|IN_BACK));
}

// A wrapper for returning ITEM_DISABLED, but greying out the menu item, as the AMXX menu system doesn't do it
stock DisableMenuItem(menu, item)
{
	new itemName[64];
	menu_item_getinfo(menu, item, _, _, _, itemName, charsmax(itemName));
	format(itemName, charsmax(itemName), "\\d%s\\w", itemName); // make this text grey, then continue with white
	menu_item_setname(menu, item, itemName);

	return ITEM_DISABLED;
}

public RestoreSpecCam(payLoad[], taskId)
{
	new spec   = payLoad[0];
	new target = payLoad[1];

	if (!pev_valid(spec) || !pev_valid(target) || !is_user_connected(spec) || !is_user_connected(target))
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

// Wrapper to limit calls to HLKZ_ShowMessage
stock ShowMessageHLKZ(id, const message[], {Float,Sql,Result,_}:...)
{
	static msg[192];
	vformat(msg, charsmax(msg), message, 3);

	// TODO: limit the amount of times this is called to like twice per second per player, for performance reasons
	HLKZ_ShowMessage(id, msg);
}

stock ClearLastMenu(id)
{
	new _dummy, menu;
	player_menu_info(id, _dummy, menu);

	if (menu > -1)
		menu_destroy(menu);
}

stock ClearAllMenus(id)
{
	new _dummy, menu;
	player_menu_info(id, _dummy, menu);

	while (menu > -1)
	{
		menu_destroy(menu);
		player_menu_info(id, _dummy, menu);
	}
}

stock Float:GetPlayerSpeed(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);
	return xs_vec_len_2d(velocity);
}

ClearRunStats(runstats[RUNSTATS])
{
	// TODO: see if there's a way to do this with less code
	runstats[RS_AVG_FPS] = 0.0;
	runstats[RS_MIN_FPS] = 0.0;
	runstats[RS_AVG_SPEED] = 0.0;
	runstats[RS_MAX_SPEED] = 0.0;
	runstats[RS_END_SPEED] = 0.0;
	runstats[RS_PRESTRAFE_SPEED] = 0.0;
	runstats[RS_PRESTRAFE_TIME] = 0.0;
	runstats[RS_TIMELOSS_START] = 0.0;
	runstats[RS_TIMELOSS_END] = 0.0;
	runstats[RS_DISTANCE_2D] = 0.0;
	runstats[RS_DISTANCE_3D] = 0.0;
	xs_vec_copy(Float:{0.0, 0.0, 0.0}, runstats[RS_LAST_FAIL_ORIGIN]);
	runstats[RS_JUMPS] = 0;
	runstats[RS_DUCKTAPS] = 0;
	runstats[RS_SLOWDOWNS] = 0;
}
