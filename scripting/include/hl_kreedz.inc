/* 
 * HLKZ API by naz
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


/**
 * When +hook/+rope/healthbooster is used
 * @param id		client id of the player that cheated
 */
forward hlkz_cheating(id);

/**
 * When a map's best time is beaten
 * @param id		client id of the player who got the best time
 * @param kztime	how many seconds it took to run the map
 * @param type		run type: 0 = pure, 1 = pro, 2 = noob
 */
forward hlkz_worldrecord(id, Float:kztime, type);
