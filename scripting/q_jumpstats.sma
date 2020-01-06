/**
 * to do:
 * - fix hud channels
 * - tech allow list
 * - tech allowed jump time length (???)
 * - illegal state
 * - get dd stats like sync and, i dunno, some other stuff, maybe
 * - display dd stats if countjump
 * - check for too far drop
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <engine>
#include <hl>
#include <hl_kreedz_util>

#include <q>
#include <q_cookies>
#include <q_menu>
#include <q_message>

#include <q_jumpstats_const>

#pragma semicolon 1

#define PLUGIN "Q::Jumpstats"
#define VERSION "1.0"
#define AUTHOR "Quaker"
#define PLUGIN_TAG "LJStats"

#define TASKID_SPEED 489273421

#define LJSTATS_MENU_ID "LJ Stats Menu"
#define LJSOUNDS_MENU_ID "LJ Sounds Menu"

enum State
{
	State_Initial,
	State_InJump_FirstFrame,
	State_InJump,
	State_InDD_FirstFrame,
	State_InDD,
	State_InDrop,		// fall below duck/jump origin while still in air
	State_InFall,		// walk across the edge of surface
	State_OnLadder,
	State_InLadderDrop,	// jump from ladder
	State_InLadderFall	// slide out of ladder
};

enum _:JUMPSTATS
{
	JUMPSTATS_ID[32],
	JUMPSTATS_NAME[32],
	Float:JUMPSTATS_DISTANCE,
	Float:JUMPSTATS_MAXSPEED,
	Float:JUMPSTATS_PRESTRAFE,
	JUMPSTATS_STRAFES,
	JUMPSTATS_SYNC,
	JUMPSTATS_TIMESTAMP,	// Date
}

new const configsSubDir[] = "/hl_kreedz";
new Array:g_ArrayLJStats;
new g_Map[64];
new g_ConfigsDir[256];
new g_StatsFileLJ[256];

new const FL_ONGROUND2 = FL_ONGROUND | FL_PARTIALGROUND | FL_INWATER | FL_CONVEYOR | FL_FLOAT;

new mfwd_dd_begin;
new mfwd_dd_end;
new mfwd_dd_fail;
new mfwd_dd_interrupt;
new mfwd_jump_begin;
new mfwd_jump_end;
new mfwd_jump_fail;
new mfwd_jump_illegal;
new mfwd_jump_interrupt;

new sv_airaccelerate;
new sv_gravity;

new air_touch[33];

new State:old_player_state[33];
new State:player_state[33];

new player_show_speed[33];
new player_show_stats[33];
new player_show_stats_chat[33];
new player_show_prestrafe[33];

new ducking[33];
new oldDucking[33];
new flags[33];
new oldflags[33];
new buttons[33];
new oldbuttons[33];
new movetype[33];

new Float:origin[33][3];
new Float:oldorigin[33][3];
new Float:velocity[33][3];
new Float:oldvelocity[33][3];
new Float:old_h2_injump[33];

new jump_start_ducking[33];
new Float:jump_start_origin[33][3];
new Float:jump_start_velocity[33][3];
new Float:jump_start_time[33];
new jump_end_ducking[33];
new Float:jump_end_origin[33][3];
new Float:jump_end_time[33];

new injump_started_downward[33];
new injump_frame[33];
new inertia_frames[33];
new obbo[33];
new Float:pre_obbo_velocity[33][3];

new Float:jump_first_origin[33][3];
new Float:jump_first_velocity[33][3];
new Float:jump_last_origin[33][3];
new Float:jump_last_velocity[33][3];
new Float:jump_fail_origin[33][3];
new Float:jump_fail_velocity[33][3];

new jump_turning[33];
new jump_strafing[33];

new JumpType:jump_type[33];
new Float:jump_distance[33];
new Float:jump_prestrafe[33];
new Float:jump_maxspeed[33];
new jump_sync[33];
new jump_frames[33];
new Float:jump_speed[33];
new Float:jump_angles[33][3];
new jump_strafes[33];
new jump_strafe_sync[33][MAX_STRAFES];
new jump_strafe_frames[33][MAX_STRAFES];
new Float:jump_strafe_gain[33][MAX_STRAFES];
new Float:jump_strafe_loss[33][MAX_STRAFES];

new dd_count[33];
new Float:dd_prestrafe[33][3]; // last three dds, not a vector
new Float:dd_start_origin[33][3];
new Float:dd_start_time[33];
new Float:dd_end_origin[33][3];
new Float:dd_end_time[33];

new Float:drop_origin[33][3];
new Float:drop_time[33];

new Float:fall_origin[33][3];
new Float:fall_time[33];

new Float:ladderdrop_origin[33][3];
new Float:ladderdrop_time[33];

new g_DisplayLJStats[33];
new g_DisplayHJStats[33];
new g_DisplayCJStats[33];
new g_DisplayWJStats[33];
new g_DisplayBhStats[33];
new g_DisplayLadderStats[33];
new g_MuteJumpMessages[33];

new g_DisableImpressiveSound[33];
new g_DisablePerfectSound[33];
new g_DisableGodlikeSound[33];
new const g_strSoundImpressive[ ] = "impressive.wav";
new const g_strSoundPerfect[ ] = "perfect.wav";
new const g_strSoundGodlike[ ] = "godlike.wav";

new Trie:illegal_touch_entity_classes;

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	register_dictionary( "q_jumpstats.txt" );
	
	register_forward( FM_PlayerPreThink, "forward_PlayerPreThink" );
	RegisterHam( Ham_Spawn, "player", "forward_PlayerSpawn" );
	RegisterHam( Ham_Touch, "player", "forward_PlayerTouch", 1 );
	RegisterHam(Ham_Use, "func_pushable", "forward_Pre_UsePushable");
	RegisterHam(Ham_Use, "func_pushable", "forward_Post_UsePushable", 1);
	register_touch("trigger_push", "player", "forward_PushTouch");
	register_touch("trigger_teleport", "player", "forward_TeleportTouch");
	
	illegal_touch_entity_classes = TrieCreate( );
	TrieSetCell( illegal_touch_entity_classes, "func_train", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_door", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_door_rotating", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_conveyor", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_rotating", 1 );
	TrieSetCell( illegal_touch_entity_classes, "trigger_push", 1 );
	TrieSetCell( illegal_touch_entity_classes, "trigger_teleport", 1 );

	register_clcmd( "say /ljstats", "clcmd_ljstats" );
	register_clcmd( "say /ljsounds", "clcmd_ljsounds");
	register_clcmd( "say /jumpstats", "clcmd_ljstats" );
	register_clcmd( "say /showpre", "clcmd_prestrafe" );
	register_clcmd( "say /preshow", "clcmd_prestrafe" );
	register_clcmd( "say /prestrafe", "clcmd_prestrafe" );
	register_clcmd( "say /lj15", "show_lj_top" );
	register_clcmd( "say /lj", "show_lj_top" );
	register_clcmd( "say /hj15", "show_lj_top" );
	register_clcmd( "say /hj", "show_lj_top" );

	register_menucmd(register_menuid(LJSTATS_MENU_ID), 1023, "actions_ljstats");
	register_menucmd(register_menuid(LJSOUNDS_MENU_ID), 1023, "actions_ljsounds");

	
	sv_airaccelerate = get_cvar_pointer( "sv_airaccelerate" );
	sv_gravity = get_cvar_pointer( "sv_gravity" );
	
	mfwd_dd_begin = CreateMultiForward( "q_js_ddbegin", ET_IGNORE, FP_CELL );
	mfwd_dd_end = CreateMultiForward( "q_js_ddend", ET_IGNORE, FP_CELL );
	mfwd_dd_fail = CreateMultiForward( "q_js_ddfail", ET_IGNORE, FP_CELL );
	mfwd_dd_interrupt = CreateMultiForward( "q_js_ddinterrupt", ET_IGNORE, FP_CELL );
	mfwd_jump_begin = CreateMultiForward( "q_js_jumpbegin", ET_IGNORE, FP_CELL );
	mfwd_jump_end = CreateMultiForward( "q_js_jumpend", ET_IGNORE, FP_CELL );
	mfwd_jump_fail = CreateMultiForward( "q_js_jumpfail", ET_IGNORE, FP_CELL );
	mfwd_jump_illegal = CreateMultiForward( "q_js_jumpillegal", ET_IGNORE, FP_CELL );
	mfwd_jump_interrupt = CreateMultiForward( "q_js_jumpinterrupt", ET_IGNORE, FP_CELL );
	
	//set_task( 0.1, "task_speed", TASKID_SPEED, _, _, "b" );

	g_ArrayLJStats = ArrayCreate(JUMPSTATS);

}

public plugin_precache()
{
	precache_sound(g_strSoundImpressive);
	precache_sound(g_strSoundPerfect);
	precache_sound(g_strSoundGodlike);
}


public plugin_cfg()
{
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));

	// Dive into our custom directory
	add(g_ConfigsDir, charsmax(g_ConfigsDir), configsSubDir);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	// Load stats
	formatex(g_StatsFileLJ, charsmax(g_StatsFileLJ), "%s/top_%s.dat", g_ConfigsDir, "lj");
	load_lj_records();
}

public plugin_end()
{
	ArrayDestroy(g_ArrayLJStats);
}

public client_connect( id )
{
	reset_state( id );
	
	player_show_speed[id] = false;
	player_show_stats[id] = true;
	player_show_stats_chat[id] = true;
	player_show_prestrafe[id] = false;
	g_DisplayLJStats[id] = false;
	g_DisplayHJStats[id] = false;
	g_DisplayCJStats[id] = false;
	g_DisplayWJStats[id] = false;
	g_DisplayBhStats[id] = false;
	g_DisplayLadderStats[id] = false;
	g_MuteJumpMessages[id] = false;

	g_DisableImpressiveSound[id] = false;
	g_DisablePerfectSound[id] = false;
	g_DisableGodlikeSound[id] = false;
}

public hlkz_cheating( id )
{
	event_jump_illegal( id );
}

reset_state( id )
{
	old_player_state[id] = State_Initial;
	player_state[id] = State_Initial;
	injump_started_downward[id] = false;
	injump_frame[id] = 0;
	
	jump_start_time[id] = 0.0;
	jump_end_time[id] = 0.0;
	dd_start_time[id] = 0.0;
	dd_end_time[id] = 0.0;
	drop_time[id] = 0.0;
	fall_time[id] = 0.0;
	
	reset_stats( id );
}

reset_stats( id )
{
	injump_started_downward[id] = false;
	injump_frame[id] = 0;
	jump_turning[id] = 0;
	jump_strafing[id] = 0;
	
	jump_prestrafe[id] = 0.0;
	jump_maxspeed[id] = 0.0;
	jump_sync[id] = 0;
	jump_frames[id] = 0;
	for( new i = 0; i < sizeof(jump_strafe_sync[]); ++i )
	{
		jump_strafe_sync[id][i] = 0;
		jump_strafe_frames[id][i] = 0;
		jump_strafe_gain[id][i] = 0.0;
		jump_strafe_loss[id][i] = 0.0;
	}
	jump_strafes[id] = 0;
}

public clcmd_ljstats( id )
{
	new menuBody[512], len;
	new keys = MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9;

	len = formatex(menuBody[len], charsmax(menuBody), "%s^n^n", PLUGIN_TAG);
	len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Top 15 Longjump / Highjump^n");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Top 15 Countjump^n");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Display Longjump stats: %s^n", g_DisplayLJStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Display Highjump stats: %s^n", g_DisplayHJStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Display Countjump stats: %s^n", g_DisplayCJStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Display Weirdjump stats: %s^n", g_DisplayWJStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "7. Display Bhop stats: %s^n", g_DisplayBhStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Display Ladder stats: %s^n", g_DisplayLadderStats[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "9. Mute LJStats jump messages of others: %s^n", g_MuteJumpMessages[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "0. Exit");

	show_menu(id, keys, menuBody, -1, LJSTATS_MENU_ID);
	return PLUGIN_HANDLED;
}

public clcmd_ljsounds( id )
{
	new menuBody[512], len;
	new keys = MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3;

	len = formatex(menuBody[len], charsmax(menuBody), "%s^n^n", PLUGIN_TAG);
	len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Disable ^"Impressive^" sound: %s^n", g_DisableImpressiveSound[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Disable ^"Perfect^" sound: %s^n", g_DisablePerfectSound[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Disable ^"Godlike^" sound: %s^n", g_DisableGodlikeSound[id] ? "ON" : "OFF");
	len += formatex(menuBody[len], charsmax(menuBody) - len, "0. Exit");

	show_menu(id, keys, menuBody, -1, LJSOUNDS_MENU_ID);
	return PLUGIN_HANDLED;
}

public actions_ljstats(id, key)
{
	key++;
	switch (key)
	{
		case 0, 10: return PLUGIN_HANDLED;
		case 1: show_lj_top( id );
		case 2: show_hudmessage(id, "Not implemented yet!");
		case 3: g_DisplayLJStats[id] = !g_DisplayLJStats[id];
		case 4: g_DisplayHJStats[id] = !g_DisplayHJStats[id];
		case 5: g_DisplayCJStats[id] = !g_DisplayCJStats[id];
		case 6: g_DisplayWJStats[id] = !g_DisplayWJStats[id];
		case 7: g_DisplayBhStats[id] = !g_DisplayBhStats[id];
		case 8: g_DisplayLadderStats[id] = !g_DisplayLadderStats[id];
		case 9: g_MuteJumpMessages[id] = !g_MuteJumpMessages[id];
	}

	clcmd_ljstats(id);
	return PLUGIN_HANDLED;
}

public actions_ljsounds(id, key)
{
	key++;
	switch (key)
	{
		case 0, 10: return PLUGIN_HANDLED;
		case 1: g_DisableImpressiveSound[id] = !g_DisableImpressiveSound[id];
		case 2: g_DisablePerfectSound[id] = !g_DisablePerfectSound[id];
		case 3: g_DisableGodlikeSound[id] = !g_DisableGodlikeSound[id];
	}

	clcmd_ljsounds(id);
	return PLUGIN_HANDLED;
}

public clcmd_prestrafe( id, level, cid )
{
	player_show_prestrafe[id] = !player_show_prestrafe[id];
	client_print( id, print_chat, "Prestrafe: %s", player_show_prestrafe[id] ? "ON" : "OFF" );
	
	return PLUGIN_HANDLED;
}

public forward_PlayerSpawn( id )
{
	reset_state( id );
}

public forward_PlayerTouch( id, other )
{
	static name[32];
	
	if( flags[id] & FL_ONGROUND2 )
	{
		pev( other, pev_classname, name, charsmax(name) );
		if( TrieKeyExists( illegal_touch_entity_classes, name ) )
			reset_state( id );
	}
	else
	{
		air_touch[id] = true;
	}
}

public forward_PushTouch ( ent, id )
{
	if (is_user_alive( id ))
		event_jump_illegal( id );
}

public forward_TeleportTouch ( ent, id )
{
	if (is_user_alive( id ))
		event_jump_illegal( id );
}

public forward_PlayerPreThink( id )
{
	flags[id] = pev( id, pev_flags );
	buttons[id] = pev( id, pev_button );
	pev( id, pev_origin, origin[id] );
	pev( id, pev_velocity, velocity[id] );
	movetype[id] = pev( id, pev_movetype );
	
	static Float:absmin[3];
	static Float:absmax[3];
	pev( id, pev_absmin, absmin );
	pev( id, pev_absmax, absmax );
	oldDucking[id] = ducking[id];
	ducking[id] = !( ( absmin[2] + 64.0 ) < absmax[2] );
	
	static Float:gravity;
	pev( id, pev_gravity, gravity );

	if (get_player_hspeed(id) <= 450.0)
		inertia_frames[id] = 0;
	if (old_player_state[id] > 1 && player_state[id] == State_Initial && get_player_hspeed(id) > 450.0)
		inertia_frames[id]++;
	else if (inertia_frames[id] > 0 && old_player_state[id] == State_Initial
			&& (player_state[id] == State_Initial || player_state[id] == State_InJump_FirstFrame))
		inertia_frames[id]++;
	else
		inertia_frames[id] = 0;

	old_player_state[id] = player_state[id];

	new Float:someMeasurement = floatsqroot(
		( origin[id][0] - oldorigin[id][0] ) * ( origin[id][0] - oldorigin[id][0] ) +
		( origin[id][1] - oldorigin[id][1] ) * ( origin[id][1] - oldorigin[id][1] ) );
	if( air_touch[id] )
	{
		air_touch[id] = false;
		
		if( !( flags[id] & FL_ONGROUND2 ) && !( oldflags[id] & FL_ONGROUND2 ) )
		{
			event_jump_illegal( id );
		}
	}
	else if( gravity != 1.0
	|| ( pev( id, pev_waterlevel ) != 0 )
	|| ( ( movetype[id] != MOVETYPE_WALK ) && ( movetype[id] != MOVETYPE_FLY ) )
	|| ( someMeasurement > 20.0 )
	|| ( get_pcvar_num( sv_gravity ) != 800 )
	|| ( get_pcvar_num( sv_airaccelerate ) != 10 )
	)
	{
		event_jump_illegal( id );
	}
	else
	{
		// run current state func / no function pointers in pawn :(
		switch ( player_state[id] )
		{
			case State_Initial:
			{
				state_initial( id );
			}
			case State_InJump_FirstFrame:
			{
				state_injump_firstframe( id );
			}
			case State_InJump:
			{
				state_injump( id );
			}
			case State_InDD_FirstFrame:
			{
				state_indd_firstframe( id );
			}
			case State_InDD:
			{
				state_indd( id );
			}
			case State_InDrop:
			{
				state_indrop( id );
			}
			case State_InFall:
			{
				state_infall( id );
			}
			case State_OnLadder:
			{
				state_onladder( id );
			}
			case State_InLadderDrop:
			{
				state_inladderdrop( id );
			}
			default:
			{
				// this shouldn't happen
				reset_state( id );
			}
		}
	}
	
	oldflags[id] = flags[id];
	oldbuttons[id] = buttons[id];
	oldorigin[id] = origin[id];
	oldvelocity[id] = velocity[id];
}

state_initial( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			if( ( buttons[id] & IN_JUMP ) && !( oldbuttons[id] & IN_JUMP ) )
			{
				event_jump_begin( id );
				player_state[id] = State_InJump_FirstFrame;
			}
			else if( !( buttons[id] & IN_DUCK ) && ( oldbuttons[id] & IN_DUCK ) )
			{
				event_dd_begin( id );
				player_state[id] = State_InDD_FirstFrame;
			}
		}
		else
		{
			player_state[id] = State_InFall;
			state_infall( id );
		}
	}
	else // if it's not movetype_walk, it must be movetype_fly (see the prethink function)
	{
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

event_jump_begin( id )
{
	jump_start_ducking[id] = ducking[id];
	jump_start_origin[id] = origin[id];
	jump_start_velocity[id] = velocity[id];
	jump_start_time[id] = get_gametime( );
	jump_prestrafe[id] = floatsqroot( jump_start_velocity[id][0] * jump_start_velocity[id][0] + jump_start_velocity[id][1] * jump_start_velocity[id][1] );
	jump_maxspeed[id] = jump_prestrafe[id];
	jump_speed[id] = jump_prestrafe[id];
	pev( id, pev_angles, jump_angles[id] );
	
	new ret;
	ExecuteForward( mfwd_jump_begin, ret, id );
}

state_injump_firstframe( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		// TODO: tidy up this code -- begin
		new bool:bJumpTypeDisabled = false;
		jump_type[id] = get_jump_type( id );
		switch (jump_type[id])
		{
			case JumpType_LJ: if (!g_DisplayLJStats[id]) bJumpTypeDisabled = true;
			case JumpType_HJ: if (!g_DisplayHJStats[id]) bJumpTypeDisabled = true;
			case JumpType_CJ, JumpType_DCJ, JumpType_MCJ, JumpType_DropCJ: if (!g_DisplayCJStats[id]) bJumpTypeDisabled = true;
			case JumpType_WJ: if (!g_DisplayWJStats[id]) bJumpTypeDisabled = true;
			case JumpType_BJ, JumpType_SBJ, JumpType_DropBJ: if (!g_DisplayBhStats[id]) bJumpTypeDisabled = true;
			case JumpType_LadderBJ: if (!g_DisplayLadderStats[id]) bJumpTypeDisabled = true;
			default: bJumpTypeDisabled = false;
		}

		if (inertia_frames[id] && (get_player_hspeed(id) > 400.0 || velocity[id][2] > 400.0)
				&& (jump_type[id] == JumpType_LJ || jump_type[id] == JumpType_HJ))
			bJumpTypeDisabled = true;
		else
			inertia_frames[id] = 0;
		// TODO: tidy up this code -- end

		if( (flags[id] & FL_ONGROUND2) || bJumpTypeDisabled )
		{
			new ret;
			ExecuteForward( mfwd_jump_interrupt, ret, id );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		jump_first_origin[id] = origin[id];
		jump_first_velocity[id] = velocity[id];
		
		set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 1.0, 0.0, 0.1, 1 );
		for( new i = 1, players = get_maxplayers( ); i <= players; ++i )
		{
			if( ( ( i == id ) || ( pev( i, pev_iuser2 ) == id ) ) && player_show_prestrafe[i] )
			{
				show_hudmessage( i, "%s: %.2f", jump_shortname[jump_type[id]], jump_prestrafe[id] );
			}
		}
		
		player_state[id] = State_InJump;
		state_injump( id );
	}
	else
	{
		new ret;
		ExecuteForward( mfwd_jump_interrupt, ret, id );
		
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

state_injump( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		static Float:h1;
		static Float:h2;
		static Float:correct_old_h2;
		h1 = ( jump_start_ducking[id] ? jump_start_origin[id][2] + 18.0 : jump_start_origin[id][2] );
		h2 = ( ducking[id] ? origin[id][2] + 18.0 : origin[id][2] );

		if (oldDucking[id] < ducking[id])
			correct_old_h2 = old_h2_injump[id] + 18.0;
		else if (oldDucking[id] > ducking[id])
			correct_old_h2 = old_h2_injump[id] - 18.0;
		else
			correct_old_h2 = old_h2_injump[id];

		if( ( ( origin[id][2] + 18.0 ) < jump_start_origin[id][2] )
			|| ( ( flags[id] & FL_ONGROUND2 ) && ( h2 < jump_start_origin[id][2] ) )
			|| hl_get_user_longjump(id) || has_illegal_weapon(id) || obbo[id])
		{
			event_jump_failed( id );
			
			player_state[id] = State_InDrop;
			state_indrop( id );

			old_h2_injump[id] = h2;

			if (hl_get_user_longjump(id))
				show_hudmessage(id, "Stats for this jump are disabled 'cos you have a longjump module");

			if (has_illegal_weapon(id))
				show_hudmessage(id, "Stats for this jump are disabled 'cos you're carrying a boost weapon");
			
			obbo[id] = false;
			return;
		}

		if ( ( correct_old_h2 < h2 ) && old_player_state[id] == player_state[id] && injump_started_downward[id] )
		{
			// this check is because the plugin doesn't realize when the player started another jump when doing perfect autojumping,
			// like FL_ONGROUND is not set when touching the ground for start the next jump
			reset_state( id );
		}

		injump_frame[id]++;
		// when jumping in hl1 it may do something weird as having the second frame of the
		// jump in a lower Z origin than the first frame, which shouldn't happen becase
		// if you jump you should gain Z until you reach the top of the jump, but sometimes
		// it's just not the case somehow
		if (correct_old_h2 > h2 && injump_frame[id] > 2)
			injump_started_downward[id] = true;

		old_h2_injump[id] = h2;
		
		if( flags[id] & FL_ONGROUND2 )
		{
			event_jump_end( id );
			
			injump_started_downward[id] = false;
			injump_frame[id] = 0;
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		if( h2 >= h1 )
		{
			jump_fail_origin[id] = origin[id];
			jump_fail_velocity[id] = velocity[id];
		}
		
		jump_last_origin[id] = origin[id];
		jump_last_velocity[id] = velocity[id];
		
		static Float:speed;
		speed = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
		if( jump_maxspeed[id] < speed )
			jump_maxspeed[id] = speed;
		
		if( speed > jump_speed[id] )
		{
			++jump_sync[id];
			
			if( jump_strafes[id] < MAX_STRAFES )
			{
				++jump_strafe_sync[id][jump_strafes[id]];
				jump_strafe_gain[id][jump_strafes[id]] += speed - jump_speed[id];
			}
		}
		else
		{
			if( jump_strafes[id] < MAX_STRAFES )
			{
				jump_strafe_loss[id][jump_strafes[id]] += jump_speed[id] - speed;
			}
		}
		
		static Float:angles[3];
		pev( id, pev_angles, angles );
		if( jump_angles[id][1] > angles[1] )
		{
			jump_turning[id] = 1;
		}
		else if( jump_angles[id][1] < angles[1] )
		{
			jump_turning[id] = -1;
		}
		else
		{
			jump_turning[id] = 0;
		}
		
		if( jump_turning[id] )
		{
			if( ( jump_strafing[id] != -1 ) && ( buttons[id] & ( IN_MOVELEFT | IN_FORWARD ) ) && !( buttons[id] & ( IN_MOVERIGHT | IN_BACK ) ) )
			{
				jump_strafing[id] = -1;
				++jump_strafes[id];
			}
			else if( ( jump_strafing[id] != 1 ) && ( buttons[id] & ( IN_MOVERIGHT | IN_BACK ) ) && !( buttons[id] & ( IN_MOVELEFT | IN_FORWARD ) ) )
			{
				jump_strafing[id] = 1;
				++jump_strafes[id];
			}
		}
		
		++jump_frames[id];
		if( jump_strafes[id] < MAX_STRAFES )
		{
			++jump_strafe_frames[id][jump_strafes[id]];
		}
		
		jump_speed[id] = speed;
		jump_angles[id] = angles;
	}
	else
	{
		new ret;
		ExecuteForward( mfwd_jump_interrupt, ret, id );
		
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

event_jump_failed( id )
{
	static Float:jumpoff_height;
	jumpoff_height = jump_start_origin[id][2];
	if( flags[id] & FL_DUCKING )
	{
		jumpoff_height -= 18.0;
	}
	
	new Float:airtime = ( -oldvelocity[id][2] - floatsqroot( oldvelocity[id][2] * oldvelocity[id][2] - 2.0 * -800 * ( oldorigin[id][2] - jumpoff_height ) ) ) / -800;
	
	static Float:distance_x;
	static Float:distance_y;
	distance_x = floatabs( oldorigin[id][0] - jump_start_origin[id][0] ) + floatabs( velocity[id][0] * airtime );
	distance_y = floatabs( oldorigin[id][1] - jump_start_origin[id][1] ) + floatabs( velocity[id][1] * airtime );
	
	jump_distance[id] = floatsqroot( distance_x * distance_x + distance_y * distance_y ) + 32.0;
	
	if (jump_frames[id])
		display_stats( id, true );
	
	new ret;
	ExecuteForward( mfwd_jump_fail, ret, id );
	
	reset_stats( id );
}

event_jump_end( id )
{
	jump_end_ducking[id] = ducking[id];
	jump_end_origin[id] = origin[id];
	jump_end_time[id] = get_gametime( );
	
	new Float:h1 = ( jump_start_ducking[id] ? jump_start_origin[id][2] + 18.0 : jump_start_origin[id][2] );
	new Float:h2 = ( jump_end_ducking[id] ? jump_end_origin[id][2] + 18.0 : jump_end_origin[id][2] );
	
	if( h1 == h2 )
	{
		static Float:dist1;
		static Float:dist2;
		
		dist1 = floatsqroot(
			( jump_start_origin[id][0] - jump_end_origin[id][0] ) * ( jump_start_origin[id][0] - jump_end_origin[id][0] ) +
			( jump_start_origin[id][1] - jump_end_origin[id][1] ) * ( jump_start_origin[id][1] - jump_end_origin[id][1] ) );
		
		static Float:airtime;
		airtime = ( -floatsqroot( jump_first_velocity[id][2] * jump_first_velocity[id][2] + ( 1600.0 * ( jump_first_origin[id][2] - origin[id][2] ) ) ) - oldvelocity[id][2] ) / -800.0;
		
		static Float:cl_origin[2];
		if( oldorigin[id][0] < origin[id][0] )	cl_origin[0] = oldorigin[id][0] + airtime * floatabs( oldvelocity[id][0] );
		else									cl_origin[0] = oldorigin[id][0] - airtime * floatabs( oldvelocity[id][0] );
		if( oldorigin[id][1] < origin[id][1] )	cl_origin[1] = oldorigin[id][1] + airtime * floatabs( oldvelocity[id][1] );
		else									cl_origin[1] = oldorigin[id][1] - airtime * floatabs( oldvelocity[id][1] );
		
		dist2 = floatsqroot(
			( jump_start_origin[id][0] - cl_origin[0] ) * ( jump_start_origin[id][0] - cl_origin[0] ) +
			( jump_start_origin[id][1] - cl_origin[1] ) * ( jump_start_origin[id][1] - cl_origin[1] ) );
		
		jump_distance[id] = floatmin( dist1, dist2 ) + 32.0;
		
		display_stats( id );
		if (JumpType_LJ == jump_type[id] || JumpType_HJ == jump_type[id])
			update_lj_records( id );
	}
	
	new ret;
	ExecuteForward( mfwd_jump_end, ret, id );
	reset_stats( id );
}

event_jump_illegal( id )
{
	new ret;
	ExecuteForward( mfwd_jump_illegal, ret, id );
	reset_state( id );
}

event_dd_begin( id )
{
	if( ( dd_start_origin[id][2] == dd_end_origin[id][2] ) && ( dd_end_origin[id][2] == origin[id][2] ) && ( get_gametime( ) - dd_end_time[id] < 0.1 ) )
	{
		++dd_count[id];
	}
	else
	{
		dd_count[id] = 1;
	}
	
	dd_start_origin[id] = origin[id];
	dd_start_time[id] = get_gametime( );
	
	if( dd_count[id] > 3 )
	{
		dd_prestrafe[id][0] = dd_prestrafe[id][1];
		dd_prestrafe[id][1] = dd_prestrafe[id][2];
		dd_prestrafe[id][2] = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
	}
	else
	{
		dd_prestrafe[id][dd_count[id] - 1] = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
	}
	
	new ret;
	ExecuteForward( mfwd_dd_begin, ret, id );
}

state_indd_firstframe( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			new ret;
			ExecuteForward( mfwd_dd_interrupt, ret, id );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		player_state[id] = State_InDD;
		state_indd( id );
	}
	else
	{
		new ret;
		ExecuteForward( mfwd_dd_interrupt, ret, id );
		
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

state_indd( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			event_dd_end( id );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		if( ( origin[id][2] + 18.0 ) < dd_start_origin[id][2] )
		{
			new ret;
			ExecuteForward( mfwd_dd_fail, ret, id );
			
			player_state[id] = State_InFall;
			state_infall( id );
		}
	}
	else
	{
		new ret;
		ExecuteForward( mfwd_dd_interrupt, ret, id );
		
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

event_dd_end( id )
{
	new ret;
	ExecuteForward( mfwd_dd_end, ret, id );
	
	dd_end_origin[id] = origin[id];
	dd_end_time[id] = get_gametime( );
}

state_indrop( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			drop_origin[id] = origin[id];
			drop_time[id] = get_gametime( );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
	}
	else
	{
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

state_infall( id )
{
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			fall_origin[id] = origin[id];
			fall_time[id] = get_gametime( );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
	}
	else
	{
		player_state[id] = State_OnLadder;
		state_onladder( id );
	}
}

state_onladder( id )
{
	if( movetype[id] == MOVETYPE_FLY )
	{
		if( ( buttons[id] & IN_JUMP ) && !( oldbuttons[id] & IN_JUMP ) )
		{
			player_state[id] = State_InLadderDrop;
		}
	}
	else if( movetype[id] == MOVETYPE_WALK )
	{
		player_state[id] = State_Initial;
		state_initial( id );
	}
}

state_inladderdrop( id )
{
	if( flags[id] & FL_ONGROUND2 )
	{
		ladderdrop_origin[id] = origin[id];
		ladderdrop_time[id] = get_gametime( );
		
		player_state[id] = State_Initial;
		state_initial( id );
	}
}

JumpType:get_jump_type( id )
{
	if( jump_start_time[id] - ladderdrop_time[id] < 0.1 ) // z-origin check?
	{
		return JumpType_LadderBJ;
	}
	else if( jump_start_time[id] - dd_end_time[id] < 0.1 ) // z-origin check?
	{
		if( ( dd_start_time[id] - drop_time[id] < 0.1 ) || ( dd_start_time[id] - fall_time[id] < 0.1 ) )
		{
			return JumpType_DropCJ;
		}
		else
		{
			if( dd_count[id] == 1 )
				return JumpType_CJ;
			else if( dd_count[id] == 2 )
				return JumpType_DCJ;
			else
				return JumpType_MCJ;
		}
	}
	else if( jump_start_time[id] - fall_time[id] < 0.1 ) // z-origin check?
	{
		return JumpType_WJ;
	}
	else if( jump_start_time[id] - drop_time[id] < 0.1 ) // z-origin check?
	{
		return JumpType_DropBJ;
	}
	else if( jump_start_time[id] - jump_end_time[id] < 0.1 ) // z-origin check?
	{
		if( velocity[id][2] > 230.0 )
			return JumpType_SBJ;
		else
			return JumpType_BJ;
	}
	else
	{
		static Float:length;
		static Float:start[3], Float:stop[3], Float:maxs_Z;
		
		maxs_Z = flags[id] & FL_DUCKING ? 18.0 : 36.0;
		length = vector_length( jump_start_velocity[id] );
		
		start[0] = jump_start_origin[id][0] + ( jump_start_velocity[id][0] / length * 8.0 );
		start[1] = jump_start_origin[id][1] + ( jump_start_velocity[id][1] / length * 8.0 );
		start[2] = jump_start_origin[id][2] - maxs_Z;
		
		stop[0] = start[0];
		stop[1] = start[1];
		stop[2] = start[2] - 70.0;
		
		engfunc( EngFunc_TraceLine, start, stop, 0, id );
		
		static Float:fraction;
		global_get( glb_trace_fraction, fraction );
		
		if( !( fraction < 1.0 ) )
			return JumpType_HJ;
		else
			return JumpType_LJ;
	}
}

display_stats( id, bool:failed = false )
{
	static jump_info[256];
	formatex( jump_info, charsmax(jump_info), "%s: %.2f^nMaxspeed: %.2f (%.2f)^nPrestrafe: %.2f^nStrafes: %d^nSync: %d",
			jump_name[jump_type[id]],
			jump_distance[id],
			jump_maxspeed[id],
			jump_maxspeed[id] - jump_prestrafe[id],
			jump_prestrafe[id],
			jump_strafes[id],
			jump_sync[id] * 100 / jump_frames[id]
	);
	
	static jump_info_console[128];
	formatex( jump_info_console, charsmax(jump_info_console), "%s Distance: %f Maxspeed: %f (%.2f) Prestrafe: %f Strafes %d Sync: %d",
		jump_shortname[jump_type[id]],
		jump_distance[id],
		jump_maxspeed[id],
		jump_maxspeed[id] - jump_prestrafe[id],
		jump_prestrafe[id],
		jump_strafes[id],
		jump_sync[id] * 100 / jump_frames[id]
	);
	
	/*
	static strafes_info[512];
	static strafes_info_console[MAX_STRAFES][40];
	if( jump_strafes[id] > 1 )
	{
		new len;
		for( new i = 1; i < sizeof(jump_strafes[]); ++i )
		{
			formatex( strafes_info_console[i], charsmax(strafes_info_console[]), "^t%d^t%.3f^t%.3f^t%d^t%d",
				i,
				jump_strafe_gain[id][i],
				jump_strafe_loss[id][i],
				jump_strafe_frames[id][i] * 100 / jump_frames[id],
				jump_strafe_sync[id][i] * 100 / jump_strafe_frames[id][i]
			);
			len += formatex( strafes_info[len], charsmax(strafes_info) - len, "%s^n", strafes_info_console[i] );
		}
	}
	*/
	
	for( new i = 1, players = get_maxplayers( ); i <= players; ++i )
	{
		if( player_show_stats[i] && ( ( i == id ) || ( ( ( pev( i, pev_iuser1 ) == 2 ) || ( pev( i, pev_iuser1 ) == 4 ) ) && ( pev( i, pev_iuser2 ) == id ) ) ) )
		{
			if( failed )
				set_hudmessage( 255, 0, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
			else
				set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
			show_hudmessage( i, "%s", jump_info );
			
			/*
			if( failed )
				set_hudmessage( 255, 0, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
			else
				set_hudmessage( 255, 128, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
			show_hudmessage( i, "%s", strafes_info );
			*/

			console_print( i, "%s", jump_info_console );
			//for( new j = 1; j <= jump_strafes[id]; ++j )
			//	console_print( i, "%s", strafes_info_console[j] );
		}
		
		static jump_info_chat[192];
		jump_info_chat[0] = 0;
		if( !failed )
		{
			if( player_show_stats[i] && player_show_stats_chat[i] && ( !g_MuteJumpMessages[i] || id == i ) )
			{
				new name[32];
				get_user_name( id, name, charsmax(name) );

				if( jump_distance[id] >= jump_level[jump_type[id]][4] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_GODLIKE", name, jump_shortname[jump_type[id]], jump_distance[id] );
					if (!g_DisableGodlikeSound[id])
					{
						client_cmd(id, "spk sound/godlike");
						// console_print(id, "Playing Godlike sound");
					}
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][3] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_PERFECT", name, jump_shortname[jump_type[id]], jump_distance[id] );
					if (!g_DisablePerfectSound[id])
					{
						client_cmd(id, "spk sound/perfect");
						// console_print(id, "Playing Perfect sound");
					}				
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][2] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_IMPRESSIVE", name, jump_shortname[jump_type[id]], jump_distance[id] );
					if (!g_DisableImpressiveSound[id])
					{
						client_cmd(id,"spk sound/impressive");
						// console_print(id, "Playing Impressive sound");
					}
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][1] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_LEET", name, jump_shortname[jump_type[id]], jump_distance[id] );
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][0] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_PRO", name, jump_shortname[jump_type[id]], jump_distance[id] );
				}
				
				if( jump_info_chat[0] )
				{
					new pre[7], dist[7], maxs[7], gain[6], sync[4], strafes[3];
					float_to_str( jump_prestrafe[id], pre, charsmax(pre) ); // prestrafe speed
					float_to_str( jump_distance[id], dist, charsmax(dist) ); // distance from jump start to end point
					float_to_str( jump_maxspeed[id], maxs, charsmax(maxs) ); // maxspeed during jump
					float_to_str( jump_maxspeed[id] - jump_prestrafe[id], gain, charsmax(gain) ); // gain
					num_to_str( jump_sync[id], sync, charsmax(sync) ); // sync
					num_to_str( jump_strafes[id], strafes, charsmax(strafes) ); // strafes during jump
					
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!name", name );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!dist", dist );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!pre", pre );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!maxs", maxs );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!gain", gain );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!sync", sync );
					replace_all( jump_info_chat, charsmax(jump_info_chat), "!strf", strafes );
					
					q_message_SayText( i, MSG_ONE, _, i, "%s", jump_info_chat );
				}
			}
		}
	}
}

// TODO integrate LJ top in hl_kreedz plugin
load_lj_records()
{
	new file = fopen(g_StatsFileLJ, "r");
	if (!file) return;

	new data[1024], stats[JUMPSTATS], uniqueid[32], name[32];
	new distance[15], maxspeed[15], prestrafe[15], strafes[5], sync[4], timestamp[24];
	ArrayClear(g_ArrayLJStats);

	while (!feof(file))
	{
		fgets(file, data, charsmax(data));
		if (!strlen(data))
			continue;

		parse(data, uniqueid, charsmax(uniqueid), name, charsmax(name),
			distance, charsmax(distance), maxspeed, charsmax(maxspeed), prestrafe, charsmax(prestrafe), 
			strafes, charsmax(strafes), sync, charsmax(sync), timestamp, charsmax(timestamp));

		stats[JUMPSTATS_TIMESTAMP] = str_to_num(timestamp);

		copy(stats[JUMPSTATS_ID], charsmax(stats[JUMPSTATS_ID]), uniqueid);
		copy(stats[JUMPSTATS_NAME], charsmax(stats[JUMPSTATS_NAME]), name);
		stats[JUMPSTATS_DISTANCE] = _:str_to_float(distance);
		stats[JUMPSTATS_MAXSPEED] = _:str_to_float(maxspeed);
		stats[JUMPSTATS_PRESTRAFE] = _:str_to_float(prestrafe);
		stats[JUMPSTATS_STRAFES] = str_to_num(strafes);
		stats[JUMPSTATS_SYNC] = str_to_num(sync);

		ArrayPushArray(g_ArrayLJStats, stats);
	}

	fclose(file);
}

update_lj_records(id)
{
	new uniqueid[32], name[32], rank;
	new stats[JUMPSTATS], insertItemId = -1, deleteItemId = -1;
	load_lj_records();

	get_user_authid(id, uniqueid, charsmax(uniqueid));
	GetColorlessName(id, name, charsmax(name));

	new result;
	for (new i = 0; i < ArraySize(g_ArrayLJStats); i++)
	{
		ArrayGetArray(g_ArrayLJStats, i, stats);
		result = floatcmp(jump_distance[id], stats[JUMPSTATS_DISTANCE]);

		if (result == 1 && insertItemId == -1)
			insertItemId = i;

		if (!equal(stats[JUMPSTATS_ID], uniqueid))
			continue;

		if (result != 1)
			return;

		/*
		if (!(equali("ag_longjump", g_Map) || equali("ag_longjump2", g_Map)))
		{
			client_print(id, print_chat, "[%s] Sorry, you can only do new LJ records in ag_longjump(2) due to a bug.", PLUGIN_TAG);
			return;
		}
		*/
		new Float:longer = jump_distance[id] - stats[JUMPSTATS_DISTANCE];
		client_print(id, print_chat, "[%s] You improved your record by %.3f units", PLUGIN_TAG, longer);

		deleteItemId = i;
		break;
	}

	copy(stats[JUMPSTATS_ID], charsmax(stats[JUMPSTATS_ID]), uniqueid);
	copy(stats[JUMPSTATS_NAME], charsmax(stats[JUMPSTATS_NAME]), name);
	stats[JUMPSTATS_DISTANCE] = jump_distance[id];
	stats[JUMPSTATS_MAXSPEED] = jump_maxspeed[id];
	stats[JUMPSTATS_PRESTRAFE] = jump_prestrafe[id];
	stats[JUMPSTATS_STRAFES] = jump_strafes[id];
	stats[JUMPSTATS_SYNC] = jump_sync[id] * 100 / jump_frames[id];
	stats[JUMPSTATS_TIMESTAMP] = get_systime();

	if (insertItemId != -1)
	{
		rank = insertItemId;
		ArrayInsertArrayBefore(g_ArrayLJStats, insertItemId, stats);
	}
	else
	{
		rank = ArraySize(g_ArrayLJStats);
		ArrayPushArray(g_ArrayLJStats, stats);
	}

	if (deleteItemId != -1)
		ArrayDeleteItem(g_ArrayLJStats, insertItemId != -1 ? deleteItemId + 1 : deleteItemId);

	rank++;
	if (rank <= 15)
	{
		client_cmd(0, "spk woop");
		client_print(0, print_chat, "[%s] %s is now on place %d in LJ/HJ 15", PLUGIN_TAG, name, rank);
	}
	else
		client_print(0, print_chat, "[%s] %s's rank is %d of %d among LJ/HJ players", PLUGIN_TAG, name, rank, ArraySize(g_ArrayLJStats));

	save_lj_records();
}

save_lj_records()
{
	new file = fopen(g_StatsFileLJ, "w+");
	if (!file) return;

	new stats[JUMPSTATS];
	for (new i; i < ArraySize(g_ArrayLJStats); i++)
	{
		ArrayGetArray(g_ArrayLJStats, i, stats);

		fprintf(file, "^"%s^" ^"%s^" %.6f %.6f %.6f %d %d %i^n",
			stats[JUMPSTATS_ID],
			stats[JUMPSTATS_NAME],
			stats[JUMPSTATS_DISTANCE],
			stats[JUMPSTATS_MAXSPEED],
			stats[JUMPSTATS_PRESTRAFE],
			stats[JUMPSTATS_STRAFES],
			stats[JUMPSTATS_SYNC],
			stats[JUMPSTATS_TIMESTAMP]);
	}

	fclose(file);
}

public show_lj_top(id)
{
	new buffer[1536], len, stats[JUMPSTATS], date[32], dist[15], maxspeed[15], prestrafe[15], strafes[5], sync[4];
	load_lj_records();
	new size = min(ArraySize(g_ArrayLJStats), 15);

	len = formatex(buffer[len], charsmax(buffer) - len, "#   Player               Distance     Prestrafe    Maxspeed   Strafes Sync   Date^n^n");
	
	for (new i = 0; i < size && charsmax(buffer) - len > 0; i++)
	{
		ArrayGetArray(g_ArrayLJStats, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[JUMPSTATS_NAME][17] = EOS;

		formatex(dist, charsmax(dist), "%.3f", stats[JUMPSTATS_DISTANCE]);
		formatex(prestrafe, charsmax(prestrafe), "%.3f", stats[JUMPSTATS_MAXSPEED]);
		formatex(maxspeed, charsmax(maxspeed), "%.3f", stats[JUMPSTATS_PRESTRAFE]);
		formatex(strafes, charsmax(strafes), "%d", stats[JUMPSTATS_STRAFES]);
		formatex(sync, charsmax(sync), "%d", stats[JUMPSTATS_SYNC]);
		format_time(date, charsmax(date), "%d/%m/%Y", stats[JUMPSTATS_TIMESTAMP]);

		len += formatex(buffer[len], charsmax(buffer) - len, "%-2d %-19s %11s %11s %11s %7s %5s   %s^n", i + 1, stats[JUMPSTATS_NAME], dist, maxspeed, prestrafe, strafes, sync, date);
	}

	len += formatex(buffer[len], charsmax(buffer) - len, "^n%s %s", PLUGIN, VERSION);

	show_motd(id, buffer, "LJ15 Jumpers");

	return PLUGIN_HANDLED;
}

bool:has_illegal_weapon(id)
{
	new weapon = get_user_weapon(id);
	switch(weapon)
	{
		case HLW_NONE, HLW_CROWBAR, HLW_GLOCK, HLW_PYTHON, HLW_SHOTGUN, HLW_HORNETGUN: return false;
	}
	return true;
}

Float:get_player_hspeed(id)
{
	new Float:velocity[3];
	pev(id, pev_velocity, velocity);
	return floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0));
}

public forward_Pre_UsePushable(ent, id)
{
	if (!(1 <= id <= get_maxplayers()))
		return HAM_IGNORED;

	pev(id, pev_velocity, pre_obbo_velocity[id]);

	return HAM_IGNORED;
}

public forward_Post_UsePushable(ent, id)
{
	if (!(1 <= id <= get_maxplayers()))
		return HAM_IGNORED;

	new Float:preObboHSpeed = floatsqroot(floatpower(pre_obbo_velocity[id][0], 2.0) + floatpower(pre_obbo_velocity[id][1], 2.0));
	new Float:postObboHSpeed = get_player_hspeed(id);
	if (preObboHSpeed * 1.1 < postObboHSpeed && postObboHSpeed > 450.0)
		obbo[id] = true;

	return HAM_IGNORED;
}

