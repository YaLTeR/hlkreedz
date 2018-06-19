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

#include <q>
#include <q_cookies>
#include <q_menu>
#include <q_message>

#include <q_jumpstats_const>

#pragma semicolon 1

#define PLUGIN "Q::Jumpstats"
#define VERSION "1.0"
#define AUTHOR "Quaker"

#define TASKID_SPEED 489273421

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

new State:player_state[33];

new player_show_speed[33];
new player_show_stats[33];
new player_show_stats_chat[33];
new player_show_prestrafe[33];

new ducking[33];
new flags[33];
new oldflags[33];
new buttons[33];
new oldbuttons[33];
new movetype[33];

new Float:origin[33][3];
new Float:oldorigin[33][3];
new Float:velocity[33][3];
new Float:oldvelocity[33][3];

new jump_start_ducking[33];
new Float:jump_start_origin[33][3];
new Float:jump_start_velocity[33][3];
new Float:jump_start_time[33];
new jump_end_ducking[33];
new Float:jump_end_origin[33][3];
new Float:jump_end_time[33];

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

new Trie:illegal_touch_entity_classes;

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	register_dictionary( "q_jumpstats.txt" );
	
	register_forward( FM_PlayerPreThink, "forward_PlayerPreThink" );
	RegisterHam( Ham_Spawn, "player", "forward_PlayerSpawn" );
	RegisterHam( Ham_Touch, "player", "forward_PlayerTouch", 1 );
	
	illegal_touch_entity_classes = TrieCreate( );
	TrieSetCell( illegal_touch_entity_classes, "func_train", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_door", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_door_rotating", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_conveyor", 1 );
	TrieSetCell( illegal_touch_entity_classes, "func_rotating", 1 );
	TrieSetCell( illegal_touch_entity_classes, "trigger_push", 1 );
	TrieSetCell( illegal_touch_entity_classes, "trigger_teleport", 1 );
	
	register_clcmd( "say /ljstats", "clcmd_ljstats" );
	register_clcmd( "say /jumpstats", "clcmd_ljstats" );
	register_clcmd( "say /speed", "clcmd_speed" );
	register_clcmd( "say /showpre", "clcmd_prestrafe" );
	register_clcmd( "say /preshow", "clcmd_prestrafe" );
	register_clcmd( "say /prestrafe", "clcmd_prestrafe" );
	
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
	
	set_task( 0.1, "task_speed", TASKID_SPEED, _, _, "b" );
}

public client_connect( id )
{
	reset_state( id );
	
	player_show_speed[id] = false;
	player_show_stats[id] = false;
	player_show_stats_chat[id] = false;
	player_show_prestrafe[id] = false;
}

reset_state( id )
{
	player_state[id] = State_Initial;
	
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

public clcmd_ljstats( id, level, cid )
{
	// TODO: create menu blah blah blah
	player_show_stats[id] = !player_show_stats[id];
	player_show_stats_chat[id] = !player_show_stats_chat[id];
	client_print( id, print_chat, "LJStats: %s", player_show_stats[id] ? "ON" : "OFF" );
	
	return PLUGIN_HANDLED;
}

public clcmd_speed( id, level, cid )
{
	player_show_speed[id] = !player_show_speed[id];
	client_print( id, print_chat, "Speed: %s", player_show_speed[id] ? "ON" : "OFF" );
	
	return PLUGIN_HANDLED;
}

public clcmd_prestrafe( id, level, cid )
{
	player_show_prestrafe[id] = !player_show_prestrafe[id];
	client_print( id, print_chat, "Prestrafe: %s", player_show_prestrafe[id] ? "ON" : "OFF" );
	
	return PLUGIN_HANDLED;
}

public task_speed( )
{
	set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 1.0, 0.0, 0.1, 1 );
	for( new id = 1, players = get_maxplayers( ), Float:gametime = get_gametime( ); id < players; ++id )
	{
		if( is_user_connected( id ) && player_show_speed[id] )
		{
			if( is_user_alive( id ) )
			{
				if( ( gametime - jump_start_time[id] ) > 3.7 )
					show_hudmessage( id, "%.2f", floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] ) );
			}
			else
			{
				new specmode = pev( id, pev_iuser1 );
				if( specmode == 2 || specmode == 4 )
				{
					new t = pev( id, pev_iuser2 );
					if( ( gametime - jump_start_time[t] ) > 3.7 )
						show_hudmessage( id, "%.2f", floatsqroot( velocity[t][0] * velocity[t][0] + velocity[t][1] * velocity[t][1] ) );
				}
			}
		}
	}
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
	ducking[id] = !( ( absmin[2] + 64.0 ) < absmax[2] );
	
	// Maxspeed is somehow always 0 in Adrenaline Gamer, I think in CS 1.6 depends on weapon, ie. knife 250.0 maxspeed
	//static Float:maxspeed;
	//pev( id, pev_maxspeed, maxspeed );
	
	static Float:gravity;
	pev( id, pev_gravity, gravity );
	
	new Float:someMeasurement = floatsqroot(
		( origin[id][0] - oldorigin[id][0] ) * ( origin[id][0] - oldorigin[id][0] ) +
		( origin[id][1] - oldorigin[id][1] ) * ( origin[id][1] - oldorigin[id][1] ) );
	if( air_touch[id] )
	{
		air_touch[id] = false;
		
		if( !( flags[id] & FL_ONGROUND2 ) && !( oldflags[id] & FL_ONGROUND2 ) )
		{
			//console_print(id, "illegal. FL_ONGROUND2: true");
			event_jump_illegal( id );
		}
	}
	else if( /*maxspeed != 250.0
	||*/ gravity != 1.0
	|| ( pev( id, pev_waterlevel ) != 0 )
	|| ( ( movetype[id] != MOVETYPE_WALK ) && ( movetype[id] != MOVETYPE_FLY ) )
	|| ( someMeasurement > 20.0 )
	|| ( get_pcvar_num( sv_gravity ) != 800 )
	|| ( get_pcvar_num( sv_airaccelerate ) != 10 )
	)
	{
		//console_print(id, "illegal. g: %.2f, mt: %d, sm: %.2f", gravity, movetype[id], someMeasurement);
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
	//console_print(id, "event_jump_begin");
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
	//console_print(id, "state_injump_firstframe");
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( flags[id] & FL_ONGROUND2 )
		{
			new ret;
			ExecuteForward( mfwd_jump_interrupt, ret, id );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		jump_first_origin[id] = origin[id];
		jump_first_velocity[id] = velocity[id];
		jump_type[id] = get_jump_type( id );
		
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
	//console_print(id, "state_injump");
	if( movetype[id] == MOVETYPE_WALK )
	{
		if( ( ( origin[id][2] + 18.0 ) < jump_start_origin[id][2] ) || ( ( flags[id] & FL_ONGROUND2 ) && ( ( ducking[id] ? origin[id][2] + 18.0 : origin[id][2] ) < jump_start_origin[id][2] ) ) )
		{
			event_jump_failed( id );
			
			player_state[id] = State_InDrop;
			state_indrop( id );
			
			return;
		}
		
		if( flags[id] & FL_ONGROUND2 )
		{
			event_jump_end( id );
			
			player_state[id] = State_Initial;
			state_initial( id );
			
			return;
		}
		
		static Float:h1;
		static Float:h2;
		h1 = ( jump_start_ducking[id] ? jump_start_origin[id][2] + 18.0 : jump_start_origin[id][2] );
		h2 = ( ducking[id] ? origin[id][2] + 18.0 : origin[id][2] );
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
	
	display_stats( id, true );
	
	new ret;
	ExecuteForward( mfwd_jump_fail, ret, id );
	
	reset_stats( id );
}

event_jump_end( id )
{
	//console_print(id, "event_jump_end");
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
		else					cl_origin[0] = oldorigin[id][0] - airtime * floatabs( oldvelocity[id][0] );
		if( oldorigin[id][1] < origin[id][1] )	cl_origin[1] = oldorigin[id][1] + airtime * floatabs( oldvelocity[id][1] );
		else					cl_origin[1] = oldorigin[id][1] - airtime * floatabs( oldvelocity[id][1] );
		
		dist2 = floatsqroot(
			( jump_start_origin[id][0] - cl_origin[0] ) * ( jump_start_origin[id][0] - cl_origin[0] ) +
			( jump_start_origin[id][1] - cl_origin[1] ) * ( jump_start_origin[id][1] - cl_origin[1] ) );
		
		jump_distance[id] = floatmin( dist1, dist2 ) + 32.0;
		
		display_stats( id );
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
	//console_print(id, "event_dd_begin");
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
	//console_print(id, "state_indd_firstframe");
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
	//console_print(id, "state_indd");
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
		
		maxs_Z = flags[id] & FL_DUCKING ? 32.0 : 36.0;
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
		{
			return JumpType_HJ;
		}
	}
	
	return JumpType_LJ;
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
	
	for( new i = 1, players = get_maxplayers( ); i <= players; ++i )
	{
		if( player_show_stats[i] && ( ( i == id ) || ( ( ( pev( i, pev_iuser1 ) == 2 ) || ( pev( i, pev_iuser1 ) == 4 ) ) && ( pev( i, pev_iuser2 ) == id ) ) ) )
		{
			if( failed )
				set_hudmessage( 255, 0, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
			else
				set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
			show_hudmessage( i, "%s", jump_info );
			
			if( failed )
				set_hudmessage( 255, 0, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
			else
				set_hudmessage( 255, 128, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
			show_hudmessage( i, "%s", strafes_info );
			
			console_print( i, "%s", jump_info_console );
			for( new j = 1; j <= jump_strafes[id]; ++j )
				console_print( i, "%s", strafes_info_console[j] );
		}
		
		static jump_info_chat[192];
		jump_info_chat[0] = 0;
		if( !failed )
		{
			if( player_show_stats[i] && player_show_stats_chat[i] )
			{
				new name[32];
				get_user_name( id, name, charsmax(name) );

				if( jump_distance[id] >= jump_level[jump_type[id]][2] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_GODLIKE", name, jump_shortname[jump_type[id]], jump_distance[id] );
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][1] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_PERFECT", name, jump_shortname[jump_type[id]], jump_distance[id] );
				}
				else if( jump_distance[id] >= jump_level[jump_type[id]][0] )
				{
					formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_IMPRESSIVE", name, jump_shortname[jump_type[id]], jump_distance[id] );
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
