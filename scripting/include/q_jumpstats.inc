/* 
 * Q Jumpstats API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_jumpstats_included
	#endinput
#endif

#define _q_jumpstats_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_jumpstats
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_jumpstats
	#endif
#else
	#pragma library q_jumpstats
#endif

#include <q_jumpstats_const>

forward q_js_jumpbegin( id );
forward q_js_jumpend( id, type, Float:distance, Float:prestrafe, Float:gain, strafes, sync );
forward q_js_jumpillegal( id );
