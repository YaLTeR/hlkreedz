/*
 * Helper functions used by the HL_KreedZ plugin
 */

#include <amxmodx>
#include <fakemeta>
#include <xs>

enum _:STATS
{
	STATS_ID[32],
	STATS_NAME[32],
	STATS_CP,
	STATS_TP,
	Float:STATS_TIME,	// Timer value
	STATS_TIMESTAMP 	// Date
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
	RUN_TYPE:QUERY_RUN_TYPE,	// pure, pro, noob
	QUERY_PID,					// player id in database
	QUERY_NO_RESET,				// was no-reset mode set for this run?
	QUERY_STATS[STATS]			// steam id, nickname, cps, tps, run duration, end date
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

new const g_KzVotePositionString[][] =
{
	"left",
	"center",
	"right"
}

new const Float:g_KzVotePosition[] =
{
	0.05,
	-1.0,
	0.75
}

// TODO: put this into a file and read from it...
new const g_DeathmatchMaps[][] =
{
	"357_box",
	"ag_1",
	"ag_2",
	"ag_arena_b4",
	"ag_courtyard",
	"ag_crossfire",
	"ag_hidden_lab",
	"ag_park",
	"agctf_ag_crossfire",
	"agctf_bootcamp",
	"agctf_brazilian",
	"agctf_dabo",
	"agctf_daydream",
	"agctf_duff",
	"agctf_echo",
	"agctf_face",
	"agctf_forsaken",
	"agctf_gauntlet",
	"agctf_infinity",
	"agctf_innersanctums",
	"agctf_legacy",
	"agctf_omen",
	"agctf_outland",
	"agctf_wormhole",
	"agony",
	"awol",
	"battlegrounds",
	"boot",
	"boot_camp",
	"boot_campx",
	"bootbox",
	"bounce",
	"brave",
	"cabrito",
	"cold_faces",
	"combat2",
	"crossfire",
	"cyanidestalkyard",
	"dabo",
	"DARN",
	"datacore",
	"datax",
	"dm_delve",
	"dm_dust",
	"dm_dust2",
	"DockingBay",
	"doublecross",
	"echo",
	"eden",
	"elixir",
	"endcamp",
	"endworld",
	"farewell",
	"fling",
	"frenzy",
	"frenzied",
	"gasworks",
	"havoc",
	"homeworld",
	"isotonic",
	"justwar2",
	"karnak",
	"lambda_bunker",
	"last_call",
	"lost_village",
	"lost_village2",
	"manhunt",
	"moss",
	"no_remorse",
	"obsolete",
	"olvidada_muerte",
	"oneslip",
	"outcry",
	"pwrcore",
	"rapidcore",
	"rats",
	"re_boot",
	"rebellion",
	"rustmill",
	"scary_1",
	"scary_2",
	"semonz",
	"snark_pit",
	"stalkyard",
	"stalkx",
	"subtransit",
	"tear",
	"the_beach",
	"thunderstruck",
	"undertow",
	"undyz",
	"urethane",
	"varrock",
	"vengeance",
	"vertigo",
	"xbounce",
	"xbounce2"
};

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
Float:GetFloatArg(str[]="")
{
	new cmdArg[64], numberPart[64];

	if (str[0])
		formatex(cmdArg, charsmax(cmdArg), str);
	else
		read_args(cmdArg, charsmax(cmdArg));

	new bool:prevWasDigit = false;
	for (new i = 0; cmdArg[i]; i++)
	{
		if (isdigit(cmdArg[i]))
		{
			add(numberPart, charsmax(numberPart), cmdArg[i], 1);
			prevWasDigit = true;
		}
		else if (prevWasDigit) {
			if (equal(cmdArg[i], "."))
				add(numberPart, charsmax(numberPart), ".", 1);
			else
				break; // e.g.: say "/speedcap 499.5 some text and 123 numbers here" --> get out when parsing the '499.5'
		}
	}
	return str_to_float(numberPart);
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

GetDistancePlayerAiming(id)
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

// You have to pass the numbers of a SteamID in the format X_Y_Z (without STEAM_) and it stores in the result the full SteamID (like STEAM_X:Y:Z)
ConvertNumbersToSteamID32(numbers[], result[])
{
    new a[2], b[2], c[11];
    xs_strmid(numbers, a, 0, 0);
    xs_strmid(numbers, b, 2, 2);
    xs_strmid(numbers, c, 4, charsmax(numbers[]));

    formatex(result, charsmax(result), "STEAM_%s:%s:%s", a, b, c);
}

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
GetTopTypeString(RUN_TYPE:runType, topType[]) {
	switch (runType)
	{
		// TODO I think the same term should be used everywhere, but I also think that "noob" would be more correct than "nub",
		// and leaderboard files for the NOOB top already have _nub in the name... so I guess it should be kept like that
		// not to have to check everytime for both "noob" and "nub" or lose backwards compatibility 
		case NOOB: formatex(topType, charsmax(topType), "nub");
		case PRO:  formatex(topType, charsmax(topType), "pro");
		case PURE: formatex(topType, charsmax(topType), "pure");
	}
}

// Returns a RUN_TYPE
GetTopType(topType[]) {
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

GetNumberOfBitsSet(iBitField)
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