/*
 * Climb Button Maker
 *
 *  Descriptions:
 * This plugin make climb buttons of start and stop (no timer, only buttons).
 * Interacts with ProKreedz plugin.
 *
 *  Commands:
 * say /cbm - open Climb Button Maker menu (need immunity flag)
 *
 *  Notes:
 * Plugin based on Bunnyhop Course Maker v2.0 by FatalisDK.
 * I know this small job but is useful for public servers on some unfinished maps (kz_ascension_v7, kz_giantbean_v8 and others)
 *
 *  Change log:
 * v0.1 - Ñlearing BCM plugin
 * v0.2 - Changed BCM to CBM
 * v0.3 - Added buttons
 * v0.4 - Edited functions
 * v0.5 - Added rotate buttons
 * v0.6 - Finded and fixed double make buttons bug
 * v0.7 - Fixed buttons not getting saved sometimes
 * v0.8 - Fixed not being able to rotate or remove buttons
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define PLUGIN "Climb Button Maker"
#define VERSION "0.8"
#define AUTHOR "Kr1Zo & naz"

new cbmStart[] = "models/cbm/kz_timer_start.mdl"
new cbmStop[] = "models/cbm/kz_timer_stop.mdl"

new cbmStartTargetName[] = "counter_start"    // "cbm_start"
new cbmStopTargetName[] = "counter_off"       // "cbm_stop"

new cbmFile[97]
new cbmMenu

new className
new cbmClassName[] = "func_button"

new Array:buttons

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("kr1zo", "cbm0.8", FCVAR_SERVER)

	register_clcmd("say /cbm", "cmdCbmMenu", ADMIN_IMMUNITY, "- open Climb Button Maker menu")

	cbmMenu = menu_create("Climb Button Maker by Kr1Zo", "cbmMnu")

	menu_additem(cbmMenu, "Make start", "1", 0, -1)
	menu_additem(cbmMenu, "Make stop", "2", 0, -1)
	menu_additem(cbmMenu, "Rotate button", "3", 0, -1)
	menu_additem(cbmMenu, "Remove button", "4", 0, -1)
	menu_additem(cbmMenu, "Save to file", "5", 0, -1)

	className = engfunc(EngFunc_AllocString, cbmClassName)

	new szDir[65]
	new szMap[33]

	get_datadir(szDir, 64)
	get_mapname(szMap, 32)

	add(szDir, 64, "/cbm", 0)

	if(!dir_exists(szDir))
		mkdir(szDir)

	formatex(cbmFile, 96, "%s/%s.cfg", szDir, szMap)

	buttons = ArrayCreate(1, 4)
}

public plugin_precache() {
	precache_model(cbmStart)
	precache_model(cbmStop)
}

public plugin_cfg() {
	readFile()
}

public plugin_end()
{
	ArrayDestroy(buttons)
}

readFile() {
	if(!file_exists(cbmFile))
		return

	new szData[41]
	new szType[2], szX[13], szY[13], szZ[13], szAnglesY[11]
	new Float:vOrigin[3], Float:vAnglesY
	new f = fopen(cbmFile, "rt")

	while(!feof(f)) {
		fgets(f, szData, 40)
		parse(szData, szType, 1, szX, 12, szY, 12, szZ, 12, szAnglesY, 10)

		vAnglesY = str_to_float(szAnglesY)

		vOrigin[0] = str_to_float(szX)
		vOrigin[1] = str_to_float(szY)
		vOrigin[2] = str_to_float(szZ)

		if(szType[0] == '1')
			makeButton(0, cbmStartTargetName, 1, vOrigin, vAnglesY)

		else if(szType[0] == '2')
			makeButton(0, cbmStopTargetName, 2, vOrigin, vAnglesY)
	}

	fclose(f)
}

public cmdCbmMenu(id, level, cid) {
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	menu_display(id, cbmMenu, 0)

	return PLUGIN_HANDLED
}

public cbmMnu(id, menu, item) {
	new szCmd[2], _access, callback

	menu_item_getinfo(menu, item, _access, szCmd, 1, "", 0, callback)

	if(item == MENU_EXIT)
		return PLUGIN_HANDLED

	switch(szCmd[0]) {
		case '-':
			return PLUGIN_HANDLED

		case '1':
			makeButton(id, cbmStartTargetName, 1, Float:{0.0, 0.0, 0.0}, 0.0)

		case '2':
			makeButton(id, cbmStopTargetName, 2, Float:{0.0, 0.0, 0.0}, 0.0)

		case '3': {
			new action[] = "rotate"

			SolidifyButtons()
			new ent = FindButton(id, action)

			if(ent != 0) {
				new Float:vAngles[3]

				pev(ent, pev_angles, vAngles)

				if(vAngles[1] == 270.0)
					vAngles[1] -= 270.0

				else
					vAngles[1] += 90.0

				set_pev(ent, pev_angles, vAngles)
			}

			// Restore the original solidity
			UnsolidifyButtons()
		}

		case '4': {
			new action[] = "remove"

			SolidifyButtons()
			new ent = FindButton(id, action)

			if(ent != 0)
			{
				set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)

				new index = ArrayFindValue(buttons, ent)
				if (-1 != index)
					ArrayDeleteItem(buttons, index)
			}
			UnsolidifyButtons()
		}
		case '5': {
			if(file_exists(cbmFile))
				delete_file(cbmFile)

			new ent, Float:vOrigin[3], Float:vAngles[3], szData[57]
			new f = fopen(cbmFile, "at")

			for (new i = 0; i < ArraySize(buttons); i++) {
				ent = ArrayGetCell(buttons, i)
				pev(ent, pev_angles, vAngles)
				pev(ent, pev_origin, vOrigin)

				new szTarget[33]
				pev(ent, pev_target, szTarget, charsmax(szTarget))

				if (equal(szTarget, cbmStartTargetName))
					formatex(szData, charsmax(szData), "1 %f %f %f %f^n", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[1])
				else if (equal(szTarget, cbmStopTargetName))
					formatex(szData, charsmax(szData), "2 %f %f %f %f^n", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[1])

				fputs(f, szData)
			}

			formatex(szData, 56, ":: This line to fix double make climb buttons bug ::")
			fputs(f, szData)

			fclose(f)

			client_print(id, print_chat, "[CBM] Saved successfully")
		}
	}

	menu_display(id, cbmMenu, 0)

	return PLUGIN_HANDLED
}

stock makeButton(id, szTarget[], type, Float:pOrigin[3], Float:pAnglesY, solidity = SOLID_NOT) {
	new ent = engfunc(EngFunc_CreateNamedEntity, className)

	if(!pev_valid(ent))
		return PLUGIN_HANDLED

	set_pev(ent, pev_target, szTarget)
	set_pev(ent, pev_solid, solidity)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)

	engfunc(EngFunc_SetModel, ent, type == 1 ? cbmStart : cbmStop)
	engfunc(EngFunc_SetSize, ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 64.0})

	if(pOrigin[0] == 0.0 && pOrigin[1] == 0.0 && pOrigin[2] == 0.0) {
		new origin[3], Float:vOrigin[3]

		get_user_origin(id, origin, 3)

		IVecFVec(origin, vOrigin)

		engfunc(EngFunc_SetOrigin, ent, vOrigin)
	}
	else
		engfunc(EngFunc_SetOrigin, ent, pOrigin)

	if(pAnglesY != 0.0) {
		new Float:vAngles[3]

		pev(ent, pev_angles, vAngles)

		vAngles[1] = pAnglesY

		set_pev(ent, pev_angles, vAngles)
	}

	if(isNearSpawn(ent)) {
		client_print(id, print_chat, "[CBM] Cannot place near spawns or teleport")

		set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)
	}


	SetEntityRendering(ent, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, type == 1 ? 30 : 60);

	ArrayPushCell(buttons, ent)
	
	return ent;
}

stock SetEntityRendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16) 
{
	static Float:rendercolor[3];
	rendercolor[0] = float(r);
	rendercolor[1] = float(g);
	rendercolor[2] = float(b);
	
	set_pev(entity, pev_renderfx, fx)
	set_pev(entity, pev_rendercolor, rendercolor);
	set_pev(entity, pev_rendermode, render);
	set_pev(entity, pev_renderamt, float(amount));
	
	return 1;
}

bool:isNearSpawn(id) {
	new Float:vOrigin[3], ent, szClassname[33]

	pev(id, pev_origin, vOrigin)

	while((ent = engfunc(EngFunc_FindEntityInSphere, ent, vOrigin, 64.0))) {
		pev(ent, pev_classname, szClassname, 32)

		if(equal(szClassname, "info_player_start", 0) || equal(szClassname,"info_player_deathmatch", 0) || equal(szClassname,"info_teleport_destination", 0))
			return true
	}

	return false
}

FindButton(id, action[]) {
	new ent, body

	get_user_aiming(id, ent, body, 9999)

	if(!pev_valid(ent))
		client_print(id, print_chat, "[CBM] You must aim at a start/end button to %s it", action)
	else {
		new szTarget[33]

		pev(ent, pev_target, szTarget, 32)

		if(!equal(szTarget, cbmStartTargetName, 0) && !equal(szTarget, cbmStopTargetName, 0))
			client_print(id, print_chat, "[CBM] You must aim at a start/end button to %s it", action)
		else {
			new Float:vOrigin[3]

			pev(ent, pev_origin, vOrigin)

			new index = ArrayFindValue(buttons, ent)
			if(-1 != index) {
				if(equal(szTarget, cbmStartTargetName, 0))
					client_print(id, print_chat, "[CBM] Start button %sd", action)

				if(equal(szTarget, cbmStopTargetName, 0))
					client_print(id, print_chat, "[CBM] Stop button %sd", action)

				return ent
			}
			else {
				if(equal(szTarget, cbmStartTargetName, 0))
					client_print(id, print_chat, "[CBM] This a standard start button, cannot %s it", action)

				if(equal(szTarget, cbmStopTargetName, 0))
					client_print(id, print_chat, "[CBM] This a standard stop button, cannot %s it", action)
			}
		}
	}

	return 0
}

/**
 * Make all of the buttons solid so that the tracing to the button works properly
 *
 * The other option i see is doing something like getting the point the player is
 * looking at and then find in a sphere all the buttons created by us and getting
 * the closest one, but this is inconsistent when you have 2 end buttons very close
 * to eachother, as you may end up deleting the one that you do not have up front in
 * your screen, which is what in theory you wanted to delete
 */
SolidifyButtons() {
	new Array:tempArr = ArrayClone(buttons)
	ArrayClear(buttons)

	// Recreate all the buttons, but with the solid flag, because you changing
	// the solidity dynamically does not work and we need it to be solid for the tracing
	for (new i = 0; i < ArraySize(tempArr); i++) {
		new ent = ArrayGetCell(tempArr, i)
		set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)

		new Float:vOrigin[3], Float:vAngles[3], szTarget[33];
		pev(ent, pev_origin, vOrigin)
		pev(ent, pev_angles, vAngles)
		pev(ent, pev_target, szTarget, charsmax(szTarget))

		// makeButton already adds the button to the array, so we're good
		if (equal(szTarget, cbmStartTargetName))
			makeButton(0, szTarget, 1, vOrigin, vAngles[1], SOLID_BBOX)
		else
			makeButton(0, szTarget, 2, vOrigin, vAngles[1], SOLID_BBOX)
	}
	ArrayDestroy(tempArr)
}

// Like SolidifyButtons but the opposite
UnsolidifyButtons() {
	new Array:tempArr = ArrayClone(buttons)
	ArrayClear(buttons)

	for (new i = 0; i < ArraySize(tempArr); i++) {
		new ent = ArrayGetCell(tempArr, i)
		set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)

		new Float:vOrigin[3], Float:vAngles[3], szTarget[33];
		pev(ent, pev_origin, vOrigin)
		pev(ent, pev_angles, vAngles)
		pev(ent, pev_target, szTarget, charsmax(szTarget))

		if (equal(szTarget, cbmStartTargetName))
			makeButton(0, szTarget, 1, vOrigin, vAngles[1])
		else
			makeButton(0, szTarget, 2, vOrigin, vAngles[1])
	}
	ArrayDestroy(tempArr)
}
