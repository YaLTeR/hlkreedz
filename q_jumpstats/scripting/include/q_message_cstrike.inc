/* 
 * Q Messages CStrike API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_message_cstrike_included
	#endinput
#endif

#define _q_message_cstrike_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_message_cstrike
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_message_cstrike
	#endif
#else
	#pragma library q_message_cstrike
#endif

#include <q_cstrike_const>

native q_message_TeamInfo( msg_type, msg_dest, msg_origin[3] = {0, 0, 0}, id, CsTeams:team );
