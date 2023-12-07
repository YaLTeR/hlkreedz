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
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define PLUGIN "Climb Button Maker"
#define VERSION "0.6"
#define AUTHOR "Kr1Zo"

new cbmStart[] = "models/w_c4.mdl"
new cbmStop[] = "models/w_c4.mdl"

new cbmStartTargetName[] = "counter_start"    // "cbm_start"
new cbmStopTargetName[] = "counter_off"       // "cbm_stop"

new cbmFile[97]
new cbmMenu

new className
new cbmClassName[] = "func_button"

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("kr1zo", "cbm0.6", FCVAR_SERVER)

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
}

public plugin_precache() {
	precache_model(cbmStart)
	precache_model(cbmStop)
}

public plugin_cfg() {
	readFile()
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
		}

		case '4': {
			new action[] = "remove"
			new ent = FindButton(id, action)

			if(ent != 0)
				set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME)
		}
		case '5': {
			if(file_exists(cbmFile))
				delete_file(cbmFile)

			new ent, Float:vOrigin[3], Float:vAngles[3], szData[57]
			new f = fopen(cbmFile, "at")

			while((ent = engfunc(EngFunc_FindEntityByString, ent, "target", cbmStartTargetName))) {
				pev(ent, pev_angles, vAngles)
				pev(ent, pev_origin, vOrigin)

				if(vOrigin[0] != 0.0 && vOrigin[1] != 0.0 && vOrigin[2] != 0.0) {
					formatex(szData, 56, "1 %f %f %f %f^n", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[1])
					fputs(f, szData)
				}
			}
			ent = 0

			while((ent = engfunc(EngFunc_FindEntityByString, ent, "target", cbmStopTargetName))) {
				pev(ent, pev_angles, vAngles)
				pev(ent, pev_origin, vOrigin)

				if(vOrigin[0] != 0.0 && vOrigin[1] != 0.0 && vOrigin[2] != 0.0) {
					formatex(szData, 56, "2 %f %f %f %f^n", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[1])
					fputs(f, szData)
				}
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

stock makeButton(id, szTarget[], type, Float:pOrigin[3], Float:pAnglesY) {
	new ent = engfunc(EngFunc_CreateNamedEntity, className)

	if(!pev_valid(ent))
		return PLUGIN_HANDLED

	set_pev(ent, pev_target, szTarget)
	set_pev(ent, pev_solid, SOLID_NOT)
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
	
	return 1;
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
		client_print(id, print_chat, "[CBM] You must aim at an Climb Button to %s it", action)
	else {
		new szTarget[33]

		pev(ent, pev_target, szTarget, 32)

		if(!equal(szTarget, cbmStartTargetName, 0) && !equal(szTarget, cbmStopTargetName, 0))
			client_print(id, print_chat, "[CBM] You must aim at an Climb Button to %s it", action)
		else {
			new Float:vOrigin[3]

			pev(ent, pev_origin, vOrigin)

			if(vOrigin[0] != 0.0 && vOrigin[1] != 0.0 && vOrigin[2] != 0.0) {
				if(equal(szTarget, cbmStartTargetName, 0))
					client_print(id, print_chat, "[CBM] Start Climb Button %sd", action)

				if(equal(szTarget, cbmStopTargetName, 0))
					client_print(id, print_chat, "[CBM] Stop Climb Button %sd", action)

				return ent
			}
			else {
				if(equal(szTarget, cbmStartTargetName, 0))
					client_print(id, print_chat, "[CBM] This standard Start Climb Button, is not %s", action)

				if(equal(szTarget, cbmStopTargetName, 0))
					client_print(id, print_chat, "[CBM] This standard Stop Climb Button, is not %s", action)
			}
		}
	}

	return 0
}
