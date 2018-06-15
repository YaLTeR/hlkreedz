/* 
 * Quaker's KZ Mod API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_kz_included
	#endinput
#endif

#define _q_kz_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_kz
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_kz
	#endif
#else
	#pragma library q_kz
#endif

/**
 *  Gets qkz version. */
native q_kz_getVersion( version[], len );

/**
 *  Gets qkz data folder path. */
native q_kz_getDataDirectory( path[], len );

/**
 *  Gets qkz config folder path. */
native q_kz_getConfigDirectory( path[], len );

/**
 *  Gets commonly used q_kz_prefix cvar string */
native q_kz_getPrefix( output[], len );

/**
 *  Prints message to user in QKZ style. */
native q_kz_print( id, message[], any:... );

/**
 * ... */
native q_kz_saytext( id, message[], any:... );

/**
 *  Terminates player's run by given id only if player is actually in a run. */
native q_kz_player_stopTimer( id, reason[], any:... );

/**
 *  Retrieves hud color from main QKZ plugin. */
native q_kz_getHudColor( &red, &green, &blue );

/**
 *  Returns 1 or 0 */
native q_kz_player_isTimerStarted( id );

/**
 *  Returns how much time has passed since run started. */
native Float:q_kz_player_getTimer( id );

/**
 *  Returns number of checpoints user set */
native q_kz_player_getCheckpoints( id );

/**
 *  Returns number of teleports user did */
native q_kz_player_getTeleports( id );

/**
 *  Returns 1 if start position is set or 0 otherwise */
native q_kz_isStartOriginFound( );

/**
 *  Gets start origin if set */
native q_kz_getStartOrigin( Float:origin[3] );

/**
 *  Returns 1 if end position is set or 0 otherwise */
native q_kz_isStopOriginFound( );

/**
 *  Get end origin if set */
native q_kz_getStopOrigin( Float:origin[3] );

/**
 *  Returns 1 if user is vip or 0 otherwise */
native q_kz_player_isVip( id );

/**
 *  Registers rewards in QKZ Rewards menu.
 *  When player finishes the map a menu with a list of
 *  all registered rewards will appear. Before displaying
 *  your item callback function will be called. You can
 *  create and pass callback function, but you don't have to.
 *  Callback func should be prototyped as:
 *  public <func>( id )
 *  You should return ITEM_ENABLED or ITEM_DISABLED from it.
 *  Usefull when player already has your reward, so you can
 *  disable it.
 *  When player selects an item, handler function will be called
 *  prototyped as:
 *  public <func>( id )
 *  In handler function you should enable user's reward or
 *  do some weird stuff I haven't predicted.
 *  NOTE: You can call this func only in QKZ_RegisteringRewards */
native q_kz_registerReward( name[], handler[], callback[] = "" );

native Array:q_kz_getStartButtonEntities( );

native Array:q_kz_getStopButtonEntities( );

// FORWARDS
forward QKZ_RegisterSettings( );
forward QKZ_RegisterRewards( );

native q_kz_registerForward( Q_KZ_Forward:forwardType, callback[], _post = false );

enum Q_KZ_Forward {
	Q_KZ_TimerStart,	// id
	Q_KZ_TimerStop,		// id, successful
	Q_KZ_TimerPause,	// id, paused
	Q_KZ_OnCheckpoint,	// id
	Q_KZ_OnTeleport		// id
}
