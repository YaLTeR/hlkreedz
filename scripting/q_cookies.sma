#include <amxmodx>

#include <q>
#include <q_cookies>

#pragma semicolon 1

#define PLUGIN "Q::Cookies"
#define VERSION "1.0.2"
#define AUTHOR "Quaker"

new g_dir_cookies[128];

new g_player_steamid[33][40];

public plugin_natives() {
	register_library("q_cookies");
	
	register_native("q_set_cookie_num",	"_q_set_cookie_num");
	register_native("q_get_cookie_num",	"_q_get_cookie_num");
	
	register_native("q_set_cookie_float",	"_q_set_cookie_float");
	register_native("q_get_cookie_float",	"_q_get_cookie_float");
	
	register_native("q_set_cookie_string",	"_q_set_cookie_string");
	register_native("q_get_cookie_string",	"_q_get_cookie_string");
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	q_getDataDirectory(g_dir_cookies, charsmax(g_dir_cookies));
	add(g_dir_cookies, charsmax(g_dir_cookies), "/cookies");
	if(!dir_exists(g_dir_cookies)) {
		mkdir(g_dir_cookies);
	}
}

public client_putinserver(id) {
	get_user_authid(id, g_player_steamid[id], charsmax(g_player_steamid[]));
}

public _q_get_cookie_num(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new value[64];
	new cookie_exists = get_cookie(id, key, value);
	
	set_param_byref(3, str_to_num(value));
	
	return cookie_exists;
}

public _q_get_cookie_float(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new value[64];
	new cookie_exists = get_cookie(id, key, value);
	
	set_param_byref(3, _:str_to_float(value));
	
	return cookie_exists;
}

public _q_get_cookie_string(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new value[64];
	new cookie_exists = get_cookie(id, key, value);
	
	set_string(3, value, charsmax(value));
	
	return cookie_exists;
}

public _q_set_cookie_num(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new value[64];
	num_to_str(get_param(3), value, charsmax(value));
	
	set_cookie(id, key, value);
}

public _q_set_cookie_float(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new Float:val;
	val = get_param_f(3);
	
	new value[64];
	float_to_str(val, value, charsmax(value));
	
	set_cookie(id, key, value);
}

public _q_set_cookie_string(plugin, params) {
	new id = get_param(1);
	
	new key[34];
	get_plugin(plugin, _, _, key, charsmax(key));
	new len = strlen(key);
	get_string(2, key[len], charsmax(key) - len);
	md5(key, key);
	
	new value[64];
	get_string(3, value, charsmax(value));
	
	set_cookie(id, key, value);
}

get_cookie(id, key[], value[64]) {
	static temp[140];
	formatex(temp, charsmax(temp), "%s/%s.qc", g_dir_cookies, g_player_steamid[id]);
	
	new found = false;
	new f = fopen(temp, "rb");
	if(!f) {
		return false;
	}
	
	new cookie_num;
	fread(f, cookie_num, BLOCK_INT);
	
	for(new i = 0; i < cookie_num; ++i) {
		fread_blocks(f, temp, 34, BLOCK_BYTE);
		if(equal(temp, key)) {
			found = true;
			fread_blocks(f, value, 64, BLOCK_BYTE);
			
			break;
		}
		else {
			fseek(f, 64, SEEK_CUR);
		}
	}
	
	fclose(f);
	
	return found;
}

set_cookie(id, key[], value[]) {
	static temp[140];
	formatex(temp, charsmax(temp), "%s/%s.qc", g_dir_cookies, g_player_steamid[id]);
	
	new f = fopen(temp, "r+b");
	if(f)
	{
		new cookie_num;
		fread(f, cookie_num, BLOCK_INT);
		
		new found = false;
		for(new i = 0; i < cookie_num; ++i)
		{
			fread_blocks(f, temp, 34, BLOCK_BYTE);
			
			if(equal(key, temp))
			{
				found = true;
				fseek(f, 0, SEEK_CUR);
				fwrite_blocks(f, value, 64, BLOCK_BYTE);
				
				break;
			}
			else
			{
				fseek(f, 64, BLOCK_BYTE);
			}
		}
		
		if(!found)
		{
			fseek(f, 0, SEEK_CUR);
			fwrite_blocks(f, key, 34, BLOCK_BYTE);
			fwrite_blocks(f, value, 64, BLOCK_BYTE);
			
			fseek(f, 0, SEEK_SET);
			fwrite(f, ++cookie_num, BLOCK_INT);
		}
		
		fclose(f);
	}
	else
	{
		f = fopen(temp, "wb");
		fwrite(f, 1, BLOCK_INT);
		fwrite_blocks(f, key, 34, BLOCK_BYTE);
		fwrite_blocks(f, value, 64, BLOCK_BYTE);
		fclose(f);
	}
}
