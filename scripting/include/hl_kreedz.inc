/* 
 * Q Jumpstats API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _hl_kreedz_included
	#endinput
#endif

#define _hl_kreedz_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib hl_kreedz
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib hl_kreedz
	#endif
#else
	#pragma library hl_kreedz
#endif

forward hlkz_cheating( id );
