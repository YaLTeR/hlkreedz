/* 
 * Quaker's KZ Mod Duel API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_kz_duel_included
	#endinput
#endif

#define _q_kz_duel_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_kz_duel
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_kz_duel
	#endif
#else
	#pragma library q_kz_duel
#endif

forward q_kz_duel_start( player1, player2 );
forward q_kz_duel_end( winner, loser );
