/* 
 * Quaker's KZ Cookies
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_cookies_included
	#endinput
#endif

#define _q_cookies_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_cookies
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_cookies
	#endif
#else
	#pragma library q_cookies
#endif

/**
 * Returns cookie value by reference (3rd arg). The func itself
 * returns true or false depending on whether the cookie exists.
 */
native q_get_cookie_num( id, key[], &value );
native Float:q_get_cookie_float( id, key[], &Float:value );
native q_get_cookie_string( id, key[], value[] );

/**
 * Obvious.
 */
native q_set_cookie_num( id, key[], value );
native q_set_cookie_float( id, key[], Float:value );
native q_set_cookie_string( id, key[], value[] );
