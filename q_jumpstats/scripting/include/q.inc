/* 
 * Q API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_included
	#endinput
#endif

#define _q_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q
	#endif
#else
	#pragma library q
#endif

native q_getDataDirectory(path[], len);

native q_registerCvar(cvarHandle, defaultValue[], description[]);

native q_registerClcmd(command[], handler[], flags = -1, description[] = "");
