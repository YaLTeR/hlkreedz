#include <amxmodx>
#include <q_message>
#include <q_menu>

/* todo
- menu_destroy crashes if called right after menu_display
- menu parent, menu stack, item access maybe
- remove hacks
*/

#pragma semicolon 1

#define PLUGIN "Q::Menu"
#define VERSION "1.2b"
#define AUTHOR "Quaker"

new g_player_menu[33];
new QMenu:g_player_menu_id[33] = {QMenu_None, ...};
new g_player_menu_forward[33] = {-1, ...};
new g_player_menu_forwardPlugin[33] = {-1, ...};
new g_player_menu_forwardOverride[33] = {-1, ...};
new g_player_menu_keys[33];
new g_player_menu_page[33];
new Float:g_player_menu_expire[33];

new Array:g_menu_title;
new Array:g_menu_subtitle;
new Array:g_menu_data;
new Array:g_menu_forward;
new Array:g_menu_item_name;
new Array:g_menu_item_data;
new Array:g_menu_item_enabled;
new Array:g_menu_item_pickable;
new Array:g_menu_item_formatter;
new Array:g_menu_items_per_page;

/*
struct menu {
	string title
	string subtitle
	string data
	*func(id, menu, item) handler
	struct item {
		string name
		string data
		bool enabled
		bool pickable
		formatter {
			int pluginId
			int functionId // func(id, menu, item, output)
		}
	}
	int items_per_page
}
*/

public plugin_natives( )
{
	register_library( "q_menu" );
	
	register_native( "q_menu_is_displayed", "_q_menu_is_displayed" );
	register_native( "q_menu_current", "_q_menu_current" );
	register_native( "q_menu_simple", "_q_menu_simple" );
	
	register_native( "q_menu_create", "_q_menu_create" );
	register_native( "q_menu_destroy", "_q_menu_destroy" );
	register_native( "q_menu_display", "_q_menu_display" );
	register_native( "q_menu_get_handler", "_q_menu_get_handler" );
	register_native( "q_menu_set_handler", "_q_menu_set_handler" );
	register_native( "q_menu_get_title", "_q_menu_get_title" );
	register_native( "q_menu_set_title", "_q_menu_set_title" );
	register_native( "q_menu_get_subtitle", "_q_menu_get_subtitle" );
	register_native( "q_menu_set_subtitle", "_q_menu_set_subtitle" );
	register_native( "q_menu_get_items_per_page", "_q_menu_get_items_per_page" );
	register_native( "q_menu_set_items_per_page", "_q_menu_set_items_per_page" );
	register_native("q_menu_get_data", "_q_menu_get_data");
	register_native("q_menu_set_data", "_q_menu_set_data");
	register_native( "q_menu_find_by_title", "_q_menu_find_by_title" );
	register_native( "q_menu_page_count", "_q_menu_page_count" );
	
	register_native( "q_menu_item_add", "_q_menu_item_add" );
	register_native( "q_menu_item_remove", "_q_menu_item_remove" );
	register_native( "q_menu_item_clear", "_q_menu_item_clear" );
	register_native( "q_menu_item_count", "_q_menu_item_count" );
	register_native( "q_menu_item_get_name", "_q_menu_item_get_name" );
	register_native( "q_menu_item_set_name", "_q_menu_item_set_name" );
	register_native( "q_menu_item_get_data", "_q_menu_item_get_data" );
	register_native( "q_menu_item_set_data", "_q_menu_item_set_data" );
	register_native( "q_menu_item_get_pickable", "_q_menu_item_get_pickable" );
	register_native( "q_menu_item_set_pickable", "_q_menu_item_set_pickable" );
	register_native( "q_menu_item_get_enabled", "_q_menu_item_get_enabled" );
	register_native( "q_menu_item_set_enabled", "_q_menu_item_set_enabled" );
	register_native("q_menu_item_get_formatter", "_q_menu_item_get_formatter");
	register_native("q_menu_item_set_formatter", "_q_menu_item_set_formatter");
	
	g_menu_title = ArrayCreate( 32, 8 );
	g_menu_subtitle = ArrayCreate( 32, 8 );
	g_menu_data = ArrayCreate(64, 8);
	g_menu_forward = ArrayCreate( 1, 8 );
	g_menu_items_per_page = ArrayCreate( 1, 8 );
	g_menu_item_name = ArrayCreate( 1, 8 );
	g_menu_item_data = ArrayCreate( 1, 8 );
	g_menu_item_enabled = ArrayCreate( 1, 8 );
	g_menu_item_pickable = ArrayCreate( 1, 8 );
	g_menu_item_formatter = ArrayCreate(1, 8);
}

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	register_dictionary("q_menu.txt");
	
	register_clcmd( "menuselect", "clcmd_menuselect" );
}

public plugin_end() {
	g_menu_title ? ArrayDestroy( g_menu_title ) : 0;
	g_menu_subtitle ? ArrayDestroy( g_menu_subtitle ) : 0;
	g_menu_data ? ArrayDestroy(g_menu_data) : 0;
	
	g_menu_forward ? ArrayDestroy( g_menu_forward ) : 0;
	g_menu_items_per_page ? ArrayDestroy( g_menu_items_per_page ) : 0;
	
	new Array:name, Array:data, Array:enab, Array:pick, Array:form;
	for( new i = 0, size = ArraySize( g_menu_item_name ); i < size; ++i )
	{
		name = ArrayGetCell( g_menu_item_name, i );
		if( name ) ArrayDestroy( name );
		
		data = ArrayGetCell( g_menu_item_data, i );
		if( data ) ArrayDestroy( data );
		
		enab = ArrayGetCell( g_menu_item_enabled, i );
		if( enab ) ArrayDestroy( enab );
		
		pick = ArrayGetCell( g_menu_item_pickable, i );
		if( pick ) ArrayDestroy( pick );
		
		form = ArrayGetCell(g_menu_item_formatter, i);
		if(form) ArrayDestroy(form);
	}
	g_menu_item_name ? ArrayDestroy( g_menu_item_name ) : 0;
	g_menu_item_data ? ArrayDestroy( g_menu_item_data ) : 0;
	g_menu_item_enabled ? ArrayDestroy( g_menu_item_enabled ) : 0;
	g_menu_item_pickable ? ArrayDestroy( g_menu_item_pickable ) : 0;
	g_menu_item_formatter ? ArrayDestroy(g_menu_item_formatter) : 0;
}

public clcmd_menuselect( id, level, cid )
{
	// hack
	new junk1, junk2;
	if( player_menu_info( id, junk1, junk2 ) )
		return PLUGIN_CONTINUE;
	
	if( g_player_menu[id] && ( g_player_menu_expire[id] < get_gametime( ) ) )
	{
		new slot[3];
		read_argv( 1, slot, charsmax(slot) );
		new key = str_to_num( slot ) - 1;
		
		if( g_player_menu_keys[id] & (1<<key) )
		{
			if( g_player_menu_id[id] == QMenu_Simple ) // simple menu
			{
				new ret;
				ExecuteForward( g_player_menu_forward[id], ret, id, key );
				
				g_player_menu[id] = false;
				g_player_menu_id[id] = QMenu_None;
				g_player_menu_keys[id] = 0;
				g_player_menu_expire[id] = 0.0;
				g_player_menu_forward[id] = -1;
				g_player_menu_forwardOverride[id] = -1;
				g_player_menu_page[id] = 0;
			}
			else
			{
				new QMenu:menu = g_player_menu_id[id];
				new page = g_player_menu_page[id];
				
				new item;
				if( q_menu_page_count( menu ) > 1 )
				{
					if( key == 7 )
						item = QMenuItem_Back;
					else if( key == 8 )
						item = QMenuItem_Next;
					else if( key == 9 )
						item = QMenuItem_Exit;
					else
						item = ( page * q_menu_get_items_per_page( menu ) ) + key;
				}
				else
				{
					if( key == 9 ) {
						item = QMenuItem_Exit;
					}
					else {
						item = key;
					}
				}
				
				new forwardOverride = g_player_menu_forwardOverride[id];
				new forwardPlugin = g_player_menu_forwardPlugin[id];
				
				g_player_menu[id] = false;
				g_player_menu_id[id] = QMenu_None;
				g_player_menu_keys[id] = 0;
				g_player_menu_expire[id] = 0.0;
				g_player_menu_forward[id] = -1;
				g_player_menu_forwardPlugin[id] = -1;
				g_player_menu_forwardOverride[id] = -1;
				g_player_menu_page[id] = 0;
				
				new ret;
				if(forwardOverride > -1) {
					callfunc_begin_i(forwardOverride, forwardPlugin);
					callfunc_push_int(id);
					callfunc_push_int(_:menu);
					callfunc_push_int(item);
					ret = callfunc_end();
				}
				else {
					new fwd = ArrayGetCell(g_menu_forward, _:menu);
					if(fwd != -1) {
						ExecuteForward(fwd, ret, id, _:menu, item);
					}
				}
				
				if(ret != PLUGIN_HANDLED) {
					if(item == QMenuItem_Back) {
						if(forwardOverride > -1) {
							g_player_menu_forwardPlugin[id] = forwardPlugin;
							g_player_menu_forwardOverride[id] = forwardOverride;
						}
						
						// TODO: what if menutime is not -1?
						q_menu_display(id, menu, -1, page - 1);
					}
					else if(item == QMenuItem_Next) {
						if(forwardOverride > -1) {
							g_player_menu_forwardPlugin[id] = forwardPlugin;
							g_player_menu_forwardOverride[id] = forwardOverride;
						}
						
						// TODO: what if menutime is not -1?
						q_menu_display(id, menu, -1, page + 1);
					}
				}
			}
			
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

// q_menu_is_displayed( id )
public _q_menu_is_displayed( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return 0;
	}
	
	return g_player_menu[get_param( 1 )];
}

// q_menu_current( id )
public _q_menu_current( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match, Expected 1, found %d", params );
		return 0;
	}
	
	return _:g_player_menu_id[get_param( 1 )];
}

// q_menu_simple( id, keys, time, menu[], handler[] )
public _q_menu_simple( plugin, params )
{
	if( params != 5 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 5, found %d", params );
		return;
	}
	
	new id = get_param( 1 );
	new keys = get_param( 2 );
	new menutime = get_param( 3 );
	new menutext[1024];
	get_string( 4, menutext, charsmax(menutext) );
	
	new handler[64];
	get_string( 5, handler, charsmax(handler) );
	new fwd = CreateOneForward( plugin, handler, FP_CELL, FP_CELL );
	if( fwd == -1 )
	{
		log_error( AMX_ERR_NATIVE, "Function ^"%s^" was not found", handler );
		return;
	}
	
	g_player_menu[id] = true;
	g_player_menu_id[id] = QMenu_Simple;
	g_player_menu_forward[id] = fwd;
	g_player_menu_forwardOverride[id] = -1;
	g_player_menu_keys[id] = keys;
	if( menutime == -1 )
		g_player_menu_expire[id] = Float:0xffffffff;
	else
		g_player_menu_expire[id] = get_gametime( ) + float(menutime);
	
	q_message_ShowMenu( id, id ? MSG_ONE : MSG_ALL, _, keys, menutime, menutext );
}

// q_menu_create( title[], handler[] )
public _q_menu_create( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return -1;
	}
	
	new title[32];
	get_string( 1, title, charsmax(title) );
	
	new handler[32];
	get_string(2, handler, charsmax(handler));
	new fwd;
	if(strlen(handler) != 0) {
		fwd = CreateOneForward(plugin, handler, FP_CELL, FP_CELL, FP_CELL);
		if(fwd == -1) {
			log_error(AMX_ERR_NATIVE, "Function ^"%s^" was not found", handler);
			return -1;
		}
	}
	else {
		fwd = -1;
	}
	
	new Array:item_name = ArrayCreate(64, 4);
	ArrayPushString( item_name, "Exit" );
	ArrayPushString( item_name, "Next" );
	ArrayPushString( item_name, "Back" );
	
			
	new Array:item_data = ArrayCreate(64, 4);
	ArrayPushString( item_data, "" );
	ArrayPushString( item_data, "" );
	ArrayPushString( item_data, "" );
	
	new Array:item_enabled = ArrayCreate(1, 4);
	ArrayPushCell( item_enabled, true );
	ArrayPushCell( item_enabled, true );
	ArrayPushCell( item_enabled, true );
	
	new Array:item_pickable = ArrayCreate(1, 4);
	ArrayPushCell( item_pickable, true );
	ArrayPushCell( item_pickable, true );
	ArrayPushCell( item_pickable, true );
	
	new Array:item_formatter = ArrayCreate(2, 4);
	ArrayPushArray(item_formatter, {-1, -1});
	ArrayPushArray(item_formatter, {-1, -1});
	ArrayPushArray(item_formatter, {-1, -1});
	
	new insert_index = 0;
	for( new size = ArraySize( g_menu_title ); insert_index < size; ++insert_index )
	{
		if( ArrayGetCell( g_menu_item_name, insert_index ) == 0 )
		{
			ArraySetString( g_menu_title, insert_index, title );
			ArraySetString( g_menu_subtitle, insert_index, "" );
			ArraySetString(g_menu_data, insert_index, "");
			ArraySetCell( g_menu_forward, insert_index, fwd );
			ArraySetCell( g_menu_item_name, insert_index, item_name );
			ArraySetCell( g_menu_item_data, insert_index, item_data );
			ArraySetCell( g_menu_item_enabled, insert_index, item_enabled );
			ArraySetCell( g_menu_item_pickable, insert_index, item_pickable );
			ArraySetCell(g_menu_item_formatter, insert_index, item_formatter);
			ArraySetCell( g_menu_items_per_page, insert_index, 7 );
			
			return insert_index;
		}
	}
	
	ArrayPushString( g_menu_title, title );
	ArrayPushString( g_menu_subtitle, "" );
	ArrayPushString(g_menu_data, "");
	ArrayPushCell( g_menu_forward, fwd );
	ArrayPushCell( g_menu_item_name, item_name );
	ArrayPushCell( g_menu_item_data, item_data );
	ArrayPushCell( g_menu_item_enabled, item_enabled );
	ArrayPushCell( g_menu_item_pickable, item_pickable );
	ArrayPushCell(g_menu_item_formatter, item_formatter);
	ArrayPushCell( g_menu_items_per_page, 7 );
	
	return ArraySize( g_menu_title ) - 1;
}

// q_menu_item_add(menu_id, item[], data[] = "", bool:pickable = true, bool:enabled = true, formatter[] = "")
public _q_menu_item_add( plugin, params )
{
	if(params < 5) {
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected at least 5, found %d", params );
		return -1;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return -1;
	}
	
	new item[64];
	get_string( 2, item, charsmax(item) );
	ArrayPushString( ArrayGetCell( g_menu_item_name, menu_id ), item );
	
	new item_data[64];
	get_string( 3, item_data, charsmax(item_data) );
	ArrayPushString( ArrayGetCell( g_menu_item_data, menu_id ), item_data );
	
	ArrayPushCell( ArrayGetCell( g_menu_item_pickable, menu_id ), get_param( 4 ) );
	
	ArrayPushCell( ArrayGetCell( g_menu_item_enabled, menu_id ), get_param( 5 ) );
	
	new formatterFuncId = -1;
	if(params == 6) {
		new formatterFuncName[64];
		get_string(6, formatterFuncName, charsmax(formatterFuncName));
		if(strlen(formatterFuncName) > 0) {
			formatterFuncId = get_func_id(formatterFuncName, plugin);
			if(formatterFuncId != -1) {
				new formatterArray[2];
				formatterArray[0] = plugin;
				formatterArray[1] = formatterFuncId;
				ArrayPushArray(ArrayGetCell(g_menu_item_formatter, menu_id), formatterArray);
			}
		}
	}
	if(formatterFuncId == -1) {
		ArrayPushArray(ArrayGetCell(g_menu_item_formatter, menu_id), {-1, -1});
	}
	
	return ArraySize( ArrayGetCell( g_menu_item_name, menu_id ) ) - 1;
}

// q_menu_item_get_name( menu_id, item_position, name[], len )
public _q_menu_item_get_name( plugin, params )
{
	if( params != 4 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 4, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_item = ArrayGetCell( g_menu_item_name, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	new item_name[64];
	ArrayGetString( arr_item, item, item_name, charsmax(item_name) );
	
	set_string( 3, item_name, get_param( 4 ) );
}

// q_menu_item_set_name( menu_id, item_position, name[] )
public _q_menu_item_set_name( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_item = ArrayGetCell( g_menu_item_name, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	new item_name[64];
	get_string( 3, item_name, charsmax(item_name) );
	
	ArraySetString( arr_item, item, item_name );
}

// q_menu_item_get_data( menu_id, item, data[], len )
public _q_menu_item_get_data( plugin, params )
{
	if( params != 4 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 4, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_item_data = ArrayGetCell( g_menu_item_data, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item_data ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	new item_data[64];
	ArrayGetString( arr_item_data, item, item_data, charsmax(item_data) );
	
	set_string( 3, item_data, get_param( 4 ) );
}

// q_menu_item_set_data( menu_id, item, item_data[] )
public _q_menu_item_set_data( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_item_data = ArrayGetCell( g_menu_item_data, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item_data ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	new item_data[64];
	get_string( 3, item_data, charsmax(item_data) );
	
	ArraySetString( arr_item_data, item, item_data );
}

// q_menu_item_set_pickable( menu_id, item, bool:pickable )
public _q_menu_item_set_pickable( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_item_data = ArrayGetCell( g_menu_item_data, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item_data ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	ArraySetCell( ArrayGetCell( g_menu_item_pickable, menu_id ), item, get_param( 3 ) );
}


// q_menu_item_get_pickable( menu_id, item )
public _q_menu_item_get_pickable( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return false;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return false;
	}
	
	new Array:arr_item_data = ArrayGetCell( g_menu_item_data, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_item_data ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return false;
	}
	
	return ArrayGetCell( ArrayGetCell( g_menu_item_pickable, menu_id ), item );
}

// q_menu_item_get_enabled( menu_id, item )
public _q_menu_item_get_enabled( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return false;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return false;
	}
	
	new Array:arr_items = ArrayGetCell( g_menu_item_name, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_items ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return false;
	}
	
	return ArrayGetCell( ArrayGetCell( g_menu_item_enabled, menu_id ), item );
}

// q_menu_item_set_enabled( menu_id, item, bool:enable )
public _q_menu_item_set_enabled( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_items = ArrayGetCell( g_menu_item_name, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_items ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	ArraySetCell( ArrayGetCell( g_menu_item_enabled, menu_id ), item, get_param( 3 ) );
}

// q_menu_item_get_formatter(menu_id, item, formatter[2])
public _q_menu_item_get_formatter(plugin, params) {
	if(params != 3) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params);
		return;
	}
	
	new menu_id = get_param(1);
	if((menu_id < 0) || (menu_id >= ArraySize(g_menu_title))) {
		log_error(AMX_ERR_NATIVE, "Invalid menu id %d", menu_id);
		return;
	}
	
	new Array:arr_items = ArrayGetCell(g_menu_item_name, menu_id);
	new item = get_param(2) + 3;
	if((item < 0) || (item >= ArraySize(arr_items))) {
		log_error(AMX_ERR_NATIVE, "Invalid item id %d", item - 3);
		return;
	}
	
	new fmtArray[2];
	ArrayGetArray(ArrayGetCell(g_menu_item_formatter, menu_id), item, fmtArray);
	set_array(3, fmtArray, sizeof(fmtArray));
}

// q_menu_item_set_formatter(menu_id, item, formatter[])
public _q_menu_item_set_formatter(plugin, params) {
	if(params != 3) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params);
		return;
	}
	
	new menu_id = get_param(1);
	if((menu_id < 0) || (menu_id >= ArraySize(g_menu_title))) {
		log_error(AMX_ERR_NATIVE, "Invalid menu id %d", menu_id);
		return;
	}
	
	new Array:arr_items = ArrayGetCell(g_menu_item_name, menu_id);
	new item = get_param(2) + 3;
	if((item < 0) || (item >= ArraySize(arr_items))) {
		log_error(AMX_ERR_NATIVE, "Invalid item id %d", item - 3);
		return;
	}
	
	new fmtName[64];
	get_string(3, fmtName, charsmax(fmtName));
	new fmtId = get_func_id(fmtName, plugin);
	if(fmtId == -1) {
		log_error(AMX_ERR_NATIVE, "Formatter function not found: ^"%s^"", fmtName);
		return;
	}
	
	new fmtArray[2];
	fmtArray[0] = plugin;
	fmtArray[1] = fmtId;
	ArraySetArray(ArrayGetCell(g_menu_item_formatter, menu_id), item, fmtArray);
}

// q_menu_item_remove( menu_id, item )
public _q_menu_item_remove( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:arr_items = ArrayGetCell( g_menu_item_name, menu_id );
	new item = get_param( 2 ) + 3;
	if( ( item < 0 ) || ( item >= ArraySize( arr_items ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid item id %d", item - 3 );
		return;
	}
	
	if( item < 3 )
	{
		log_error( AMX_ERR_NATIVE, "Items BACK, NEXT and EXIT cannot be removed" );
		return;
	}
	
	// It has to be a reference to some variable, so I have to do this
	ArrayDeleteItem( arr_items, item );
	
	new Array:arr_items_data = ArrayGetCell( g_menu_item_data, menu_id );
	ArrayDeleteItem( arr_items_data, item );
	
	new Array:arr_items_pickable = ArrayGetCell( g_menu_item_pickable, menu_id );
	ArrayDeleteItem( arr_items_pickable, item );
	
	new Array:arr_items_enabled = ArrayGetCell( g_menu_item_enabled, menu_id );
	ArrayDeleteItem( arr_items_enabled, item );
}

// q_menu_item_clear( menu )
public _q_menu_item_clear( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new Array:temp;
	temp = ArrayGetCell( g_menu_item_name, menu_id );
	ArrayClear( temp );
	ArrayPushString( temp, "Exit" );
	ArrayPushString( temp, "Next" );
	ArrayPushString( temp, "Back" );
	
	temp = ArrayGetCell( g_menu_item_data, menu_id );
	ArrayClear( temp );
	ArrayPushString( temp, "" );
	ArrayPushString( temp, "" );
	ArrayPushString( temp, "" );
	
	temp = ArrayGetCell( g_menu_item_enabled, menu_id );
	ArrayClear( temp );
	ArrayPushCell( temp, true );
	ArrayPushCell( temp, true );
	ArrayPushCell( temp, true );
	
	temp = ArrayGetCell( g_menu_item_pickable, menu_id );
	ArrayClear( temp );
	ArrayPushCell( temp, true );
	ArrayPushCell( temp, true );
	ArrayPushCell( temp, true );
}

// q_menu_item_count( menu_id )
public _q_menu_item_count( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return -1;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return -1;
	}
	
	return ArraySize( ArrayGetCell( g_menu_item_name, menu_id ) ) - 3;
}

// q_menu_page_count( menu_id )
public _q_menu_page_count( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return 0;
	}
	
	new QMenu:menu_id = QMenu:get_param( 1 );
	if( ( _:menu_id < 0 ) || ( _:menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return -1;
	}
	
	new per_page = q_menu_get_items_per_page( menu_id );
	new item_count = q_menu_item_count( menu_id );
	
	if( item_count > 9 )
		return item_count / per_page + ( ( item_count % per_page ) ? 1 : 0 );
	
	return 1;
}

// q_menu_get_items_per_page( menu_id )
public _q_menu_get_items_per_page( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return 0;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return 0;
	}
	
	return ArrayGetCell( g_menu_items_per_page, menu_id );
}

// q_menu_set_items_per_page( menu_id, per_page )
public _q_menu_set_items_per_page( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new per_page = get_param( 2 );
	clamp( per_page, 1, 7 );
	
	ArraySetCell( g_menu_items_per_page, menu_id, per_page );
}

// q_menu_display(id, menu_id, menu_time, page, handler[] = "")
public _q_menu_display(plugin, params) {
	if(params < 4) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected at least 4, found %d", params);
		return;
	}
	
	new id = get_param( 1 );
	new QMenu:menu_id = QMenu:get_param( 2 );
	if( ( _:menu_id < 0 ) || ( _:menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new junk1, junk2;
	if( player_menu_info( id, junk1, junk2 ) )
		show_menu( id, 0, "^n" ); // hack
	
	new menu_time = get_param( 3 );
	new page = get_param( 4 );
	new page_count = q_menu_page_count( menu_id );
	if( page < 0 )
		page = 0;
	else if( page >= page_count )
		page = page_count - 1;
	
	new fwd = -1;
	if(params == 5) {
		new handler[32];
		get_string(5, handler, charsmax(handler));
		if(strlen(handler) != 0) {
			fwd = get_func_id(handler, plugin);
			if(fwd == -1) {
				log_error(AMX_ERR_NATIVE, "Function ^"%s^" was not found", handler);
				return;
			}
			g_player_menu_forwardPlugin[id] = plugin;
			g_player_menu_forwardOverride[id] = fwd;
		}
	}
	
	new menu[1024];
	new menu_len;
	
	new menu_title[32];
	ArrayGetString( g_menu_title, _:menu_id, menu_title, charsmax(menu_title) );
	menu_len = formatex( menu, charsmax(menu), "\r%s^n", menu_title );
	
	new menu_subtitle[32];
	ArrayGetString( g_menu_subtitle, _:menu_id, menu_subtitle, charsmax(menu_subtitle) );
	menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", menu_subtitle );
	
	new keys;
	new item[64];
	new formatter[2];
	new Array:arr_items = ArrayGetCell( g_menu_item_name, _:menu_id );
	new Array:arr_items_enabled = ArrayGetCell( g_menu_item_enabled, _:menu_id );
	new Array:arr_items_pickable = ArrayGetCell( g_menu_item_pickable, _:menu_id );
	new Array:arr_items_formatter = ArrayGetCell(g_menu_item_formatter, _:menu_id);
	
	new c;
	new i = 3;
	
	if( page_count > 1 ) // paged menu
	{
		new per_page = q_menu_get_items_per_page( menu_id );
		
		// menu items
		for( new size = ArraySize( arr_items ); ( i - 3 < per_page ) && ( ( page * per_page ) + i < size ); ++i )
		{
			ArrayGetArray(arr_items_formatter, (page * per_page) + i, formatter);
			if(formatter[1] == -1) {
				ArrayGetString( arr_items, ( page * per_page ) + i, item, charsmax(item) );
			}
			else {
				callfunc_begin_i(formatter[1], formatter[0]);
				callfunc_push_int(id);
				callfunc_push_int(_:menu_id);
				callfunc_push_int(i - 3);
				callfunc_push_array(item, sizeof(item));
				callfunc_end();
			}
			
			if( ArrayGetCell( arr_items_pickable, ( page * per_page ) + i ) )
			{
				if( ArrayGetCell( arr_items_enabled, ( page * per_page ) + i ) )
				{
					keys |= (1<<(i-3));
					c = 'w';
				}
				else
				{
					c = 'd';
				}
				
				menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\y%d. \%c%s^n", i - 2, c, item ); // i + 1 - 3
			}
			else
			{
				menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", item );
			}
		}
		
		for( ; i - 3 < 7; ++i )
		{
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "^n" );
		}
		
		// back button
		i = QMenuItem_Back + 3;
		ArrayGetString( arr_items, i, item, charsmax(item) );
		if( ArrayGetCell( arr_items_pickable, i ) )
		{
			if( ArrayGetCell( arr_items_enabled, i ) && ( page > 0 ) )
			{
				keys |= (1<<7);
				c = 'w';
			}
			else
			{
				c = 'd';
			}
			
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\r8. \%c%s^n", c, item );
		}
		else
		{
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", item );
		}
		
		// next button
		i = QMenuItem_Next + 3;
		ArrayGetString( arr_items, i, item, charsmax(item) );
		if( ArrayGetCell( arr_items_pickable, i ) )
		{
			if( ArrayGetCell( arr_items_enabled, i ) && ( page < ( page_count - 1 ) ) )
			{
				keys |= (1<<8);
				c = 'w';
			}
			else
			{
				c = 'd';
			}
			
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\r9. \%c%s^n", c, item );
		}
		else
		{
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", item );
		}
	}
	else // no pages => we can use all nine slots
	{
		for( new size = ArraySize( arr_items ); ( i - 3 < 9 ) && ( i < size ); ++i )
		{
			ArrayGetArray(arr_items_formatter, i, formatter);
			if(formatter[1] == -1) {
				ArrayGetString( arr_items, i, item, charsmax(item) );
			}
			else {
				callfunc_begin_i(formatter[1], formatter[0]);
				callfunc_push_int(id);
				callfunc_push_int(_:menu_id);
				callfunc_push_int(i - 3);
				callfunc_push_array(item, sizeof(item));
				callfunc_end();
			}
			
			if( ArrayGetCell( arr_items_pickable, i ) )
			{
				if( ArrayGetCell( arr_items_enabled, i ) )
				{
					keys |= (1<<(i-3));
					c = 'w';
				}
				else
				{
					c = 'd';
				}
				
				menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\y%d. \%c%s^n", i - 2, c, item ); // i + 1 - 3
			}
			else
			{
				menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", item );
			}
		}
		
		for( ; i - 3 < 9; ++i )
		{
			menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "^n" );
		}
	}
	
	// exit button
	i = QMenuItem_Exit + 3;
	ArrayGetString( arr_items, i, item, charsmax(item) );
	if( ArrayGetCell( arr_items_pickable, i ) )
	{
		if( ArrayGetCell( arr_items_enabled, i ) )
		{
			keys |= (1<<9);
			c = 'w';
		}
		else
		{
			c = 'd';
		}
		
		menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\r0. \%c%s^n", c, item );
	}
	else
	{
		menu_len += formatex( menu[menu_len], charsmax(menu) - menu_len, "\w%s^n", item );
	}
	
	g_player_menu[id] = true;
	g_player_menu_id[id] = QMenu:menu_id;
	g_player_menu_keys[id] = keys;
	
	if( menu_time == -1 ) {
		g_player_menu_expire[id] = Float:0xffffffff;
	}
	else {
		g_player_menu_expire[id] = get_gametime( ) + float(menu_time);
	}
	
	g_player_menu_forward[id] = ArrayGetCell( g_menu_forward, _:menu_id );
	g_player_menu_page[id] = page;
	
	q_message_ShowMenu( id, MSG_ONE, _, keys, menu_time, menu );
}

// q_menu_find_by_title( title[] )
public _q_menu_find_by_title( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return -1;
	}
	
	new title[32];
	get_string( 1, title, charsmax(title) );
	
	new temptitle[32];
	for( new i = 0, size = ArraySize( g_menu_title ); i < size; ++i )
	{
		ArrayGetString( g_menu_title, i, temptitle, charsmax(temptitle) );
		if( equal( title, temptitle ) )
			return i;
	}
	
	return -1;
}

// q_menu_get_handler( menu_id )
public _q_menu_get_handler( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return -1;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return -1;
	}
	
	return ArrayGetCell( g_menu_forward, menu_id );
}

// q_menu_set_handler( menu_id, handler[] )
public _q_menu_set_handler( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new handler[64];
	get_string( 2, handler, charsmax(handler) );
	new fwd = CreateOneForward( plugin, handler, FP_CELL, FP_CELL, FP_CELL );
	if( fwd == -1 )
	{
		log_error( AMX_ERR_NATIVE, "Function ^"%s^" was not found", handler );
		return;
	}
	
	DestroyForward( ArrayGetCell( g_menu_forward, menu_id ) );
	ArraySetCell( g_menu_forward, menu_id, fwd );
}

// q_menu_get_title( menu, title[], len )
public _q_menu_get_title( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new title[32];
	ArrayGetString( g_menu_title, menu_id, title, charsmax(title) );
	set_string( 2, title, get_param( 3 ) );
}

// q_menu_set_title( menu, title[] )
public _q_menu_set_title( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new title[32];
	get_string( 2, title, charsmax(title) );
	ArraySetString( g_menu_title, menu_id, title );

}

// q_menu_get_subtitle( menu_id, subtitle[], len )
public _q_menu_get_subtitle( plugin, params )
{
	if( params != 3 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new subtitle[32];
	ArrayGetString( g_menu_subtitle, menu_id, subtitle, charsmax(subtitle) );
	set_string( 2, subtitle, get_param( 3 ) );
}

// q_menu_set_subtitle( menu_id, subtitle[] )
public _q_menu_set_subtitle( plugin, params )
{
	if( params != 2 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	new subtitle[32];
	get_string( 2, subtitle, charsmax(subtitle) );
	ArraySetString( g_menu_subtitle, menu_id, subtitle );
}

// q_menu_get_data(QMenu:menu, data[], length)
public _q_menu_get_data(plugin, params) {
	if(params != 3) {
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params );
		return;
	}
	
	new menu = get_param(1);
	if((menu < 0) || (menu >= ArraySize(g_menu_title))) {
		log_error(AMX_ERR_NATIVE, "Invalid menu id %d", menu);
		return;
	}
	
	new data[64];
	ArrayGetString(g_menu_data, menu, data, charsmax(data));
	
	set_string(2, data, get_param(3));
}

// q_menu_set_data(QMenu:menu, data[])
public _q_menu_set_data(plugin, params) {
	if(params != 2) {
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params );
		return;
	}
	
	new menu = get_param(1);
	if((menu < 0) || (menu >= ArraySize(g_menu_title))) {
		log_error(AMX_ERR_NATIVE, "Invalid menu id %d", menu);
		return;
	}
	
	new data[64];
	get_string(2, data, charsmax(data));
	
	ArraySetString(g_menu_data, menu, data);
}

// q_menu_destroy( menu_id )
public _q_menu_destroy( plugin, params )
{
	if( params != 1 )
	{
		log_error( AMX_ERR_NATIVE, "Parameters do not match. Expected 1, found %d", params );
		return;
	}
	
	new menu_id = get_param( 1 );
	if( ( menu_id < 0 ) || ( menu_id >= ArraySize( g_menu_title ) ) )
	{
		log_error( AMX_ERR_NATIVE, "Invalid menu id %d", menu_id );
		return;
	}
	
	ArraySetString( g_menu_title, menu_id, "" );
	
	new Array:arr_items = ArrayGetCell( g_menu_item_name, menu_id );
	arr_items ? ArrayDestroy( arr_items ) : 0;
	ArraySetCell( g_menu_item_name, menu_id, 0 );
	
	new Array:arr_items_data = ArrayGetCell( g_menu_item_data, menu_id );
	arr_items_data ? ArrayDestroy( arr_items_data ) : 0;
	ArraySetCell( g_menu_item_data, menu_id, 0 );
	
	new Array:arr_items_enabled = ArrayGetCell( g_menu_item_enabled, menu_id );
	arr_items_enabled ? ArrayDestroy( arr_items_enabled ) : 0;
	ArraySetCell( g_menu_item_enabled, menu_id, 0 );
	
	new Array:arr_items_pickable = ArrayGetCell( g_menu_item_pickable, menu_id );
	arr_items_pickable ? ArrayDestroy( arr_items_pickable ) : 0;
	ArraySetCell( g_menu_item_pickable, menu_id, 0 );
	
	DestroyForward( ArrayGetCell( g_menu_forward, menu_id ) );
	ArraySetCell( g_menu_forward, menu_id, 0 );
	
	ArraySetCell( g_menu_items_per_page, menu_id, 0 );
}
