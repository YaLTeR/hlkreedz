#if defined _amx_settings_api_included
  #endinput
#endif
#define _amx_settings_api_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib amx_settings_api
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib amx_settings_api
	#endif
#else
	#pragma library amx_settings_api
#endif

native amx_load_setting_int(const filename[], const section[], const key[], &value)
native amx_load_setting_float(const filename[], const section[], const key[], &Float:value)
native amx_load_setting_string(const filename[], const section[], const key[], string[], len)
native amx_save_setting_int(const filename[], const section[], const key[], value)
native amx_save_setting_float(const filename[], const section[], const key[], Float:value)
native amx_save_setting_string(const filename[], const section[], const key[], const string[])
native amx_load_setting_int_arr(const filename[], const section[], const key[], Array:array_handle)
native amx_load_setting_float_arr(const filename[], const section[], const key[], Array:array_handle)
native amx_load_setting_string_arr(const filename[], const section[], const key[], Array:array_handle)
native amx_save_setting_int_arr(const filename[], const section[], const key[], Array:array_handle)
native amx_save_setting_float_arr(const filename[], const section[], const key[], Array:array_handle)
native amx_save_setting_string_arr(const filename[], const section[], const key[], Array:array_handle)
