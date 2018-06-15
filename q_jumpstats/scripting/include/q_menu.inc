/* 
 * Q Menu API by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_menu_included
	#endinput
#endif

#define _q_menu_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib q_menu
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib q_menu
	#endif
#else
	#pragma library q_menu
#endif

#include <q_menu_const>

/**
 * @param   id  player id
 * @return      true if player has any menu opened, false otherwise.
 */
native q_menu_is_displayed(id);

/**
 * Returns menu id of the currently displayed menu to a given player id.
 *
 * @param   id  player id
 * @return      menu id
 *              QMenu_None   = no menu
 *              QMenu_Simple = simple menu
 *              0 or greater = menu created with q_menu_create (complex menu?)
 */
native QMenu:q_menu_current(id);

/**
 * @param  id       player id to whom the menu will be displayed or 0 for all
 * @param  keys     bitsum of keys available in the menu
 * @param  time     how long will the menu be valid (in seconds)
 * @param  menu     string of the entire menu
 * @param  handler  name of the handler function
 *                  prototype:
 *                  public handler_func_name( id, item )
 */
native q_menu_simple(id, keys, time, menu[], handler[]);

/**
 * @param  title
 * @param  handler  Set default menu handler or empty string for none.
 * @return          Menu handle or -1 if error happened.
 */
native QMenu:q_menu_create(title[], handler[] =  "");

native q_menu_destroy(QMenu:menu_handle);

/**
 * @param  id
 * @param  menu_handle
 * @param  menu_time
 * @param  page
 * @param  handler      Override default menu handler, otherwise pass empty string.
 * @return void
 */
native q_menu_display(id, QMenu:menu_handle, menu_time = -1, page = 0, handler[] = "");

native q_menu_get_handler(QMenu:menu_handle);

native q_menu_set_handler(QMenu:menu_handle, handler[]);

native q_menu_get_title(QMenu:menu_handle, title[], len);

native q_menu_set_title(QMenu:menu_handle, title[]);

native q_menu_get_subtitle(QMenu:menu_handle, subtitle[], len);

native q_menu_set_subtitle(QMenu:menu_handle, subtitle[]);

native q_menu_get_data(QMenu:menu_handle, data[], length);

native q_menu_set_data(QMenu:menu_handle, data[]);

native q_menu_get_items_per_page(QMenu:menu_handle);

native q_menu_set_items_per_page(QMenu:menu_handle, per_page);

native q_menu_page_count(QMenu:menu_handle);

native q_menu_item_add(QMenu:menu_handle, name[], data[] = "", bool:pickable = true, bool:enabled = true, formatter[] = "");

native q_menu_item_remove(QMenu:menu_handle, item_position);

native q_menu_item_count(QMenu:menu_handle);

native q_menu_item_clear(QMenu:menu_handle);

native q_menu_item_get_name(QMenu:menu_handle, item_position, item_name[], len);

native q_menu_item_set_name(QMenu:menu_handle, item_position, item_name[]);

native q_menu_item_get_data(QMenu:menu_handle, item_position, item_data[], len);

native q_menu_item_set_data(QMenu:menu_handle, item_position, item_data[]);

native q_menu_item_get_type(QMenu:menu_handle, item_position);

native q_menu_item_set_type(QMenu:menu_handle, item_position, type);

native q_menu_item_get_enabled(QMenu:menu_handle, item_position);

native q_menu_item_set_enabled(QMenu:menu_handle, item_position, bool:enabled);

native q_menu_item_get_pickable(QMenu:menu_handle, item_position);

native q_menu_item_set_pickable(QMenu:menu_handle, item_position, bool:pickable);

/**
 * @param  menu_handle
 * @param  item_position
 * @param  formatter		Formatter array contains plugin index and function id.
 *				Used for callfunc_begin_i function. See the function prototype
 *				in the description for q_menu_item_set_formatter.
 * @return void
 */
native q_menu_item_get_formatter(QMenu:menu_handle, item_position, formatter[2]);

/**
 * @param  menu_handle
 * @param  item_position
 * @param  formatterFuncName	Function called before rendering item name in the menu.
 *				Function prototype: public func_name(id, menu, item, output[64])
 *				Set output string which will later be drawn as a menu item.
 * @return void
 */
native q_menu_item_set_formatter(QMenu:menu_handle, item_position, formatterFuncName[]);

/**
 * @param   title  menu title
 * @return         menu id or -1 if not found
 */
native QMenu:q_menu_find_by_title(title[]);
