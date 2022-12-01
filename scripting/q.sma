#include <amxmodx>

#define PLUGIN "Q"
#define VERSION "1.2"
#define AUTHOR "Quaker"

new g_dir_data[128];

new Array:g_cvar_plugin;
new Array:g_cvar_pluginCvarIndices;
new Array:g_cvar_pointer;
new Array:g_cvar_name;
new Array:g_cvar_defaultValue;
new Array:g_cvar_description;

new Trie:g_clcmd_command;
new Trie:g_clcmd_cid2handler;
new Array:g_clcmd_handler;
new Trie:g_clcmd_aliasRegistered;
new Trie:g_clcmd_commandRegistered;

public plugin_natives() {
	register_library("q");
	
	register_native("q_getDataDirectory", "_q_getDataDirectory");
	register_native("q_registerCvar", "_q_registerCvar");
	register_native("q_registerClcmd", "_q_registerClcmd");
	
	g_cvar_plugin = ArrayCreate(1, 8);
	g_cvar_pluginCvarIndices = ArrayCreate(1, 8);
	g_cvar_pointer = ArrayCreate(1, 8);
	g_cvar_name = ArrayCreate(32, 8);
	g_cvar_defaultValue = ArrayCreate(128, 8);
	g_cvar_description = ArrayCreate(256, 8);
	
	g_clcmd_command = TrieCreate();
	g_clcmd_cid2handler = TrieCreate();
	g_clcmd_handler = ArrayCreate(2, 8);
	g_clcmd_aliasRegistered = TrieCreate();
	g_clcmd_commandRegistered = TrieCreate();
	
	clcmd_loadConfig();
}

public plugin_precache() {
	get_localinfo("amxx_datadir", g_dir_data, charsmax(g_dir_data));
	add(g_dir_data, charsmax(g_dir_data), "/q");
	if(!dir_exists(g_dir_data)) {
		mkdir(g_dir_data);
	}
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_dictionary("q.txt");
	
	cvar_loadConfig();
}

public plugin_end() {
	cvar_saveConfig();
	
	ArrayDestroy(g_cvar_plugin);
	ArrayDestroy(g_cvar_pluginCvarIndices);
	ArrayDestroy(g_cvar_pointer);
	ArrayDestroy(g_cvar_name);
	ArrayDestroy(g_cvar_defaultValue);
	ArrayDestroy(g_cvar_description);
	
	TrieDestroy(g_clcmd_command);
	TrieDestroy(g_clcmd_cid2handler);
	ArrayDestroy(g_clcmd_handler);
	TrieDestroy(g_clcmd_aliasRegistered);
	TrieDestroy(g_clcmd_commandRegistered);
}

clcmd_loadConfig() {
	new buffer[512];
	get_localinfo("amxx_configsdir", buffer, charsmax(buffer));
	format(buffer, charsmax(buffer), "%s/q_clcmds.ini", buffer);
	
	new f = fopen(buffer, "rt");
	if(!f) {
		return;
	}
	
	
	new command[32];
	new alias[32];
	new junk[1];
	
	while(!feof(f)) {
		fgets(f, buffer, charsmax(buffer));
		if(buffer[0] == ';') {
			continue;
		}
		
		trim(buffer);
		parse(buffer, alias, charsmax(alias), command, charsmax(command), junk, charsmax(junk));
		
		if(TrieKeyExists(g_clcmd_aliasRegistered, alias)) {
			log_error(AMX_ERR_GENERAL, "Found duplicate command alias in q_clcmds.ini: %s for %s. Clcmd skipped.", alias, command);
			continue;
		}
		TrieSetCell(g_clcmd_aliasRegistered, alias, true);
		
		if(TrieKeyExists(g_clcmd_command, command)) {
			new Array:arr;
			TrieGetCell(g_clcmd_command, command, arr);
			ArrayPushString(arr, alias);
		}
		else {
			new Array:arr = ArrayCreate(32, 1);
			ArrayPushString(arr, alias);
			TrieSetCell(g_clcmd_command, command, arr);
		}
	}
}

public clcmd_listener(id, level, cid) {
	static str_cid[16];
	num_to_str(cid, str_cid, charsmax(str_cid));
	
	new index;
	TrieGetCell(g_clcmd_cid2handler, str_cid, index);
	
	static handler[2];
	ArrayGetArray(g_clcmd_handler, index, handler);
	
	callfunc_begin_i(handler[1], handler[0]);
	callfunc_push_int(id);
	callfunc_push_int(level);
	callfunc_push_int(cid);
	return callfunc_end();
}

cvar_loadConfig() {
	new path[256];
	get_localinfo("amxx_configsdir", path, charsmax(path));
	formatex(path, charsmax(path), "%s/q.cfg", path);
	server_cmd("exec %s", path);
}

cvar_saveConfig() {
	new path[256];
	get_localinfo("amxx_configsdir", path, charsmax(path));
	add(path[strlen(path)-1], charsmax(path), "/q.cfg", 6);
	
	if(file_exists(path)) {
		delete_file(path);
	}
	
	new f = fopen(path, "wt");
	if(!f) {
		return;
	}
	
	for(new i = 0, pluginCount = ArraySize(g_cvar_plugin); i < pluginCount; ++i) {
		new pluginName[32];
		get_plugin(ArrayGetCell(g_cvar_plugin, i), _, _, pluginName, charsmax(pluginName), _, _, _, _, _, _);
		new Array:cvarIndices = ArrayGetCell(g_cvar_pluginCvarIndices, i);
		fprintf(f, "//-------------^n// %s^n//-------------^n", pluginName);
		for(new j = 0, cvarCount = ArraySize(cvarIndices); j < cvarCount; ++j) {
			new cvarIndex = ArrayGetCell(cvarIndices, j);
			new cvarName[32];
			ArrayGetString(g_cvar_name, cvarIndex, cvarName, charsmax(cvarName));
			new cvarPointer = ArrayGetCell(g_cvar_pointer, cvarIndex);
			new cvarValue[128];
			get_pcvar_string(cvarPointer, cvarValue, charsmax(cvarValue));
			new cvarDefaultValue[128];
			ArrayGetString(g_cvar_defaultValue, cvarIndex, cvarDefaultValue, charsmax(cvarDefaultValue));
			new cvarDescription[256];
			ArrayGetString(g_cvar_description, cvarIndex, cvarDescription, charsmax(cvarDescription));
			
			fprintf(f, "// %s^n(Default: ^"%s^")^n%s ^"%s^"^n^n", cvarDescription, cvarDefaultValue, cvarName, cvarValue);
		}
	}
	
	fclose(f);
}

// q_getDataDirectory(path[], len)
public _q_getDataDirectory(plugin, params) {
	if(params != 2) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected 2, found %d", params);
		return;
	}
	
	set_string(1, g_dir_data, get_param(2));
}

// q_registerCvar(cvarPointer, defaultValue[], description[])
public _q_registerCvar(plugin, params) {
	if(params != 3) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected 3, found %d", params);
		return;
	}
	
	new pluginIndex = -1;
	for(new i = 0, size = ArraySize(g_cvar_plugin); i < size; ++i) {
		if(ArrayGetCell(g_cvar_plugin, i) == plugin) {
			pluginIndex = i;
			break;
		}
	}
	new Array:pluginIndices;
	if(pluginIndex == -1) {
		pluginIndex = ArraySize(g_cvar_plugin);
		ArrayPushCell(g_cvar_plugin, plugin);
		pluginIndices = ArrayCreate(1, 1);
		ArrayPushCell(g_cvar_pluginCvarIndices, pluginIndices);
	}
	else {
		pluginIndices = ArrayGetCell(g_cvar_pluginCvarIndices, pluginIndex);
	}
	
	new cvarPointer = get_param(1);
	for(new i = 0, size = ArraySize(g_cvar_pointer); i < size; ++i) {
		if(cvarPointer == ArrayGetCell(g_cvar_pointer, i)) {
			return;
		}
	}
	new cvarIndex = ArraySize(g_cvar_pointer);
	ArrayPushCell(pluginIndices, cvarIndex);
	
	new defaultValue[128];
	get_string(2, defaultValue, charsmax(defaultValue));
	replace_all(defaultValue, charsmax(defaultValue), "^n", "");
	new description[256];
	get_string(3, description, charsmax(description));
	replace_all(description, charsmax(description), "^n", "^n// ");
	
	new name[32];
	new tempPointer;
	for(new i = 0, size = get_plugins_cvarsnum(); i < size; ++i) {
		get_plugins_cvar(i, name, charsmax(name), _, _, tempPointer);
		if(cvarPointer == tempPointer) {
			break;
		}
	}
	
	ArrayPushCell(g_cvar_pointer, cvarPointer);
	ArrayPushString(g_cvar_name, name);
	ArrayPushString(g_cvar_defaultValue, defaultValue);
	ArrayPushString(g_cvar_description, description);
}

// q_registerClcmd(command[], handler[], flags = -1, description[] = "")
public _q_registerClcmd(plugin, params) {
	if(params != 4) {
		log_error(AMX_ERR_NATIVE, "Parameters do not match. Expected 4, found %d", params);
		return;
	}
	
	new handler[32];
	get_string(2, handler, charsmax(handler));
	new handler_id = get_func_id(handler, plugin);
	if(handler_id == -1) {
		log_error(AMX_ERR_NATIVE, "Handler function not found: %s", handler);
		return;
	}
	
	new command[32];
	get_string(1, command, charsmax(command));
	if(TrieKeyExists(g_clcmd_commandRegistered, command)) {
		log_error(AMX_ERR_NATIVE, "Command already registered: %s", command);
		return;
	}
	TrieSetCell(g_clcmd_commandRegistered, command, true);
	
	new flags = get_param(3);
	
	new description[256];
	get_string(4, description, charsmax(description));
	
	new Array:commandAliases;
	if(TrieGetCell(g_clcmd_command, command, commandAliases)) {
		new tempAlias[32];
		for(new i = 0, count = ArraySize(commandAliases); i < count; ++i) {
			ArrayGetString(commandAliases, i, tempAlias, charsmax(tempAlias));
			new cid = register_clcmd(tempAlias, "clcmd_listener", flags, description);
			new str_cid[16];
			num_to_str(cid, str_cid, charsmax(str_cid));
			TrieSetCell(g_clcmd_cid2handler, str_cid, ArraySize(g_clcmd_handler));
		}
		
		// todo: reconsider this
		ArrayDestroy(commandAliases);
	}
	
	new handler_array[2];
	handler_array[0] = plugin;
	handler_array[1] = handler_id;
	ArrayPushArray(g_clcmd_handler, handler_array);
}
