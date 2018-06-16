#include <amxmodx>
#include <q_message>

#pragma semicolon 1

#define PLUGIN "Q::Message"
#define VERSION "1.0"
#define AUTHOR "Quaker"

enum
{
	SayText,
	ShowMenu,
	
	MessageCount
};

new g_message_id[MessageCount];

new g_message_name[MessageCount][] = {
	"SayText",
	"ShowMenu"
};

new g_message_params[MessageCount] =
{
	-1, // SayText
	6  // ShowMenu
};

public plugin_natives( )
{
	register_library( "q_message" );
	register_native( "q_message_SayText", "_q_message_SayText" );
	register_native( "q_message_ShowMenu", "_q_message_ShowMenu" );
}

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	g_message_id[SayText] = get_user_msgid( g_message_name[SayText] );
	g_message_id[ShowMenu] = get_user_msgid( g_message_name[ShowMenu] );
}

check( message_id, params )
{
	if( g_message_id[message_id] == 0 )
	{
		log_error( AMX_ERR_NATIVE, "Message ^"%s^" is not supported by this mod", g_message_name[message_id] );
		return false;
	}
	
	if( ( g_message_params[message_id] > -1 ) && ( params != g_message_params[message_id] ) )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected %d, found %d", g_message_params[message_id], params );
		return false;
	}
	
	return true;
}

// q_message_SayText( receiver, msg_type, msg_origin[3] = {0,0,0}, sender, message[], any:... )
// byte		sender_id
// string	message
// string	submsg1
// string	submsg2
public _q_message_SayText( plugin, params )
{
	if( !check( SayText, params ) )
		return;
	
	new receiver = get_param( 1 );
	new type = get_param( 2 );
	new origin[3];
	get_array( 3, origin, sizeof(origin) );
	
	new sender = get_param( 4 );
	
	static message[192];
	message[0] = 0x01;
	vdformat( message[1], charsmax(message) - 1, 5, 6 );
	
	replace_all( message, charsmax(message), "!n", "^x01" );
	replace_all( message, charsmax(message), "!t", "^x04" );
	replace_all( message, charsmax(message), "!g", "^x04" );
	
	message_begin( type, g_message_id[SayText], origin, receiver );
	write_byte( sender );
	write_string( message );
	message_end( );
}

// q_message_ShowMenu( id, msg_type, msg_origin[3] = {0,0,0}, keys, time, menu[] )
// short keysbitsum
// char time
// byte notfinalpart (bool)
// string menustring
public _q_message_ShowMenu( plugin, params )
{
	if( !check( ShowMenu, params ) )
		return;
	
	new id = get_param( 1 );
	new type = get_param( 2 );
	
	new origin[3];
	get_array( 3, origin, sizeof(origin) );
	
	new keys = get_param( 4 );
	new menutime = get_param( 5 );
	
	new menu[1024];
	get_string( 6, menu, charsmax(menu) );
	new menulen = strlen( menu );
	
	new ptr;
	new temp[176];
	while( menulen > 0 )
	{
		message_begin( type, g_message_id[ShowMenu], origin, id );
		write_short( keys );
		write_char( menutime );
		
		menulen -= 175;
		if( menulen > 0 )
			write_byte( 1 );
		else
			write_byte( 0 );
		
		copy( temp, charsmax(temp), menu[ptr] );
		ptr += 175;
		write_string( temp );
		
		message_end( );
	}
}
