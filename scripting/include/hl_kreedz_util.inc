/*
 * Helper functions used by the HL_KreedZ plugin
 */

#include <amxmodx>
#include <fakemeta>
#include <xs>

public GetNextNumber(buffer[], &pos)
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

public Float:GetNextFloat(buffer[], &pos)
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
	while (name[i])
	{
		// ^ symbol is escaping the next ^ symbol
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

// Get the normal of the plane that is in the given direction from the player
public GetNormalPlaneRelativeToPlayer(id, Float:start[3], Float:direction[3], Float:origin[3], Float:normal[3])
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
public GetNormalPlaneAtSideOfPlayer(id, Float:start[3], Float:origin[3], Float:normal[3])
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
public GetNumberArg()
{
	new cmdArg[32], numberPart[32];
	read_args(cmdArg, charsmax(cmdArg));

	new bool:prevWasDigit = false;
    for (new i = 0; cmdArg[i]; i++) {
        if (isdigit(cmdArg[i])) {
            formatex(numberPart, charsmax(numberPart), "%s%s", numberPart, cmdArg[i]);
            prevWasDigit = true;
        }
        else if (prevWasDigit)
        	break; // e.g.: say "/top 42 some text and 123 numbers here" --> get out when parsing the '42'
    }
    return str_to_num(numberPart);
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
	    for (new i = 0, j = 0; cmdArg[i] && j < 2; i++) {
	        if (isdigit(cmdArg[i])) {
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
