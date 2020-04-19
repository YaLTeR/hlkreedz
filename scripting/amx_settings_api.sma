/*================================================================================
	
	---------------------------
	-*- [AMXX] Settings API -*-
	---------------------------
	
	- API to load/save settings in a Key+Value format that resembles
	   Windows INI files (http://en.wikipedia.org/wiki/INI_file)
	
================================================================================*/

#include <amxmodx>
#include <amxmisc>

public plugin_init()
{
	register_plugin("[AMXX] Settings API", "1.0", "MeRcyLeZZ")
}

public plugin_natives()
{
	register_library("amx_settings_api")
	register_native("amx_load_setting_int", "native_load_setting_int")
	register_native("amx_load_setting_float", "native_load_setting_float")
	register_native("amx_load_setting_string", "native_load_setting_string")
	register_native("amx_save_setting_int", "native_save_setting_int")
	register_native("amx_save_setting_float", "native_save_setting_float")
	register_native("amx_save_setting_string", "native_save_setting_string")
	register_native("amx_load_setting_int_arr", "native_load_setting_int_arr")
	register_native("amx_load_setting_float_arr", "native_load_setting_float_arr")
	register_native("amx_load_setting_string_arr", "native_load_setting_string_arr")
	register_native("amx_save_setting_int_arr", "native_save_setting_int_arr")
	register_native("amx_save_setting_float_arr", "native_save_setting_float_arr")
	register_native("amx_save_setting_string_arr", "native_save_setting_string_arr")
}

public native_load_setting_int(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return int by reference
	new value[16]
	SeekReturnValues(file, keypos_start, value, charsmax(value))
	set_param_byref(4, str_to_num(value))
	
	// Value succesfully retrieved
	fclose(file)
	return true;
}

public native_load_setting_float(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return float by reference
	new value[16]
	SeekReturnValues(file, keypos_start, value, charsmax(value))
	set_float_byref(4, str_to_float(value))	
	
	// Value succesfully retrieved
	fclose(file)
	return true;
}

public native_load_setting_string(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return string by reference
	new value[128]
	SeekReturnValues(file, keypos_start, value, charsmax(value))
	set_string(4, value, get_param(5))
	
	// Value succesfully retrieved
	fclose(file)
	return true;
}

public native_save_setting_int(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Get int
	new value = get_param(4)
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueInt(file, setting_key, value)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueInt(file, setting_key, value)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueInt(tempfile, setting_key, value)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}

public native_save_setting_float(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Get float
	new Float:value = get_param_f(4)
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueFloat(file, setting_key, value)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueFloat(file, setting_key, value)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueFloat(tempfile, setting_key, value)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}
public native_save_setting_string(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	// Get string
	new string[128]
	get_string(4, string, charsmax(string))
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueString(file, setting_key, string)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueString(file, setting_key, string)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueString(tempfile, setting_key, string)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}

public native_load_setting_int_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return array
	new values[1024]
	SeekReturnValues(file, keypos_start, values, charsmax(values))
	ParseValuesArrayInt(values, charsmax(values), array_handle)
	
	// Values succesfully retrieved
	fclose(file)
	return true;
}

public native_load_setting_float_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return array
	new values[1024]
	SeekReturnValues(file, keypos_start, values, charsmax(values))
	ParseValuesArrayFloat(values, charsmax(values), array_handle)
	
	// Values succesfully retrieved
	fclose(file)
	return true;
}

public native_load_setting_string_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		fclose(file)
		return false;
	}
	
	// Return array
	new values[1024]
	SeekReturnValues(file, keypos_start, values, charsmax(values))
	ParseValuesArrayString(values, charsmax(values), array_handle)
	
	// Values succesfully retrieved
	fclose(file)
	return true;
}

public native_save_setting_int_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueArrayInt(file, setting_key, array_handle)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueArrayInt(file, setting_key, array_handle)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueArrayInt(tempfile, setting_key, array_handle)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}

public native_save_setting_float_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueArrayFloat(file, setting_key, array_handle)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueArrayFloat(file, setting_key, array_handle)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueArrayFloat(tempfile, setting_key, array_handle)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}

public native_save_setting_string_arr(plugin_id, num_params)
{
	// Retrieve and check params
	new filename[32], setting_section[64], setting_key[64]
	if (!RetrieveParams(filename, charsmax(filename), setting_section, charsmax(setting_section), setting_key, charsmax(setting_key)))
		return false;
	
	new Array:array_handle
	if (!RetrieveArray(array_handle))
		return false;
	
	// Open file for read
	new path[64], file
	if (!OpenCustomFileRead(path, charsmax(path), filename, file, true))
		return false;
	
	// Try to find section
	if (!SectionExists(file, setting_section))
	{
		// Section not found, append at the end
		if (!CustomFileAppend(file, path)) return false;
		WriteSection(file, setting_section)
		WriteKeyValueArrayString(file, setting_key, array_handle)
		fclose(file)
		return true;
	}
	
	// Try to find key in section
	new keypos_start, keypos_end, replace_values = true
	if (!KeyExists(file, setting_key, keypos_start, keypos_end))
	{
		if (feof(file))
		{
			// End of file, append at the end
			if (!CustomFileAppend(file, path)) return false;
			WriteKeyValueArrayString(file, setting_key, array_handle)
			fclose(file)
			return true;
		}
		
		// End of section, add new key + value pair at the end
		replace_values = false
	}
	
	// We have to use a second file (tempfile) to add data at an arbitrary position
	new temppath[64], tempfile
	if (!OpenTempFileWrite(temppath, charsmax(temppath), tempfile))
	{
		fclose(file)
		return false;
	}
	
	// Copy new data into temp file
	CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
	WriteKeyValueArrayString(tempfile, setting_key, array_handle)
	CopyDataAfterKey(file, tempfile)
	
	// Replace original with new
	if (!ReplaceFile(file, path, tempfile, temppath))
	{
		fclose(tempfile)
		return false;
	}
	
	return true;
}

RetrieveParams(filename[], len1, setting_section[], len2, setting_key[], len3)
{
	// Filename
	get_string(1, filename, len1)
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't save settings: empty filename.")
		return false;
	}
	
	// Section + Key
	get_string(2, setting_section, len2)
	get_string(3, setting_key, len3)
	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't save settings: empty section/key.")
		return false;
	}
	
	return true;
}

RetrieveArray(&Array:array_handle)
{
	// Array handle
	array_handle = Array:get_param(4)
	if (array_handle == Invalid_Array)
	{
		log_error(AMX_ERR_NATIVE, "[AMXX] Array not initialized.")
		return false;
	}
	
	return true;
}

OpenCustomFileRead(path[], len1, filename[], &file, create = false)
{	
	// Build customization file path
	get_configsdir(path, len1)
	format(path, len1, "%s/%s", path, filename)
	
	// File not present, create new file?
	if (!file_exists(path))
	{
		if (create)
			write_file(path, "", -1)
		else
			return false;
	}
	
	// Open customization file for reading
	file = fopen(path, "rt")
	if (!file)
	{
		// File couldn't be read
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't read file (%s).", path)
		return false;
	}
	
	return true;
}

CustomFileAppend(&file, path[])
{
	fclose(file)
	file = fopen(path, "at")
	if (!file)
	{
		// File couldn't be accessed
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't write file (%s).", path)
		return false;
	}
	
	return true;
}

OpenTempFileWrite(temppath[], len1, &tempfile)
{
	// Build temp file path
	get_configsdir(temppath, len1)
	format(temppath, len1, "%s/tempfile.txt", temppath)
	
	// Open temp file for writing+reading (creates a blank file)
	tempfile = fopen(temppath, "wt+")
	if (!tempfile)
	{
		// File couldn't be created
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't write file (%s).", temppath)
		return false;
	}
	
	return true;
}

SectionExists(file, setting_section[])
{
	// Seek to setting's section
	new linedata[96], section[64]	
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				return true;
		}
	}
	
	return false;
}

KeyExists(file, setting_key[], &keypos_start, &keypos_end)
{
	// Seek to setting's key
	new linedata[96], key[64]
	while (!feof(file))
	{
		// Read one line at a time
		keypos_start = ftell(file)
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key
		keypos_end = ftell(file)
		copyc(key, charsmax(key), linedata, '=')
		trim(key)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
			return true;
	}
	
	return false;
}

CopyDataBeforeKey(file, tempfile, keypos_start, keypos_end, replace_values)
{
	new linedata[1024]
	if (!replace_values)
	{
		// Copy original data from beginning up to keypos_end (pos after reading last valid key)
		fseek(file, 0, SEEK_SET)
		while(ftell(file) < keypos_end)
		{
			fgets(file, linedata, charsmax(linedata))
			fputs(tempfile, linedata)
		}
	}
	else
	{
		// Copy original data from beginning up to keypos_start (pos before reading key)
		fseek(file, 0, SEEK_SET)
		while(ftell(file) < keypos_start)
		{
			fgets(file, linedata, charsmax(linedata))
			fputs(tempfile, linedata)
		}
		
		// Move read cursor past the line we are replacing
		fgets(file, linedata, charsmax(linedata))
	}
}

CopyDataAfterKey(file, tempfile)
{
	// Copy remaining data until the end
	new linedata[1024]
	while (!feof(file))
	{
		fgets(file, linedata, charsmax(linedata))
		fputs(tempfile, linedata)
	}
}

ReplaceFile(&file, path[], tempfile, temppath[])
{
	// Replace file with temp
	fclose(file)
	file = fopen(path, "wt")
	if (!file)
	{
		// File couldn't be created
		log_error(AMX_ERR_NATIVE, "[AMXX] Can't write file (%s).", path)
		return false;
	}
	
	// Copy all data
	new linedata[1024]
	fseek(tempfile, 0, SEEK_SET)
	while (!feof(tempfile))
	{
		fgets(tempfile, linedata, charsmax(linedata))
		fputs(file, linedata)
	}
	
	// Close files and delete temp file
	fclose(file)
	fclose(tempfile)
	delete_file(temppath)
	return true;
}

WriteSection(file, setting_section[])
{
	// Copy section header
	new linedata[96]
	formatex(linedata, charsmax(linedata), "^n[%s]", setting_section)
	fputs(file, linedata)
	fputc(file, '^n')
}

WriteKeyValueInt(file, setting_key[], value)
{
	// Copy new data (key + values) into file
	new linedata[96]
	FormatKeyValueInt(linedata, charsmax(linedata), setting_key, value)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueInt(linedata[], len1, setting_key[], value)
{
	formatex(linedata, len1, "%s = %d", setting_key, value)
}

WriteKeyValueFloat(file, setting_key[], Float:value)
{
	// Copy new data (key + values) into file
	new linedata[96]
	FormatKeyValueFloat(linedata, charsmax(linedata), setting_key, value)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueFloat(linedata[], len1, setting_key[], Float:value)
{
	formatex(linedata, len1, "%s = %.2f", setting_key, value)
}

WriteKeyValueString(file, setting_key[], string[])
{
	// Copy new data (key + values) into file
	new linedata[256]
	FormatKeyValueString(linedata, charsmax(linedata), setting_key, string)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueString(linedata[], len1, setting_key[], string[])
{
	formatex(linedata, len1, "%s = %s", setting_key, string)
}

WriteKeyValueArrayInt(file, setting_key[], Array:array_handle)
{
	// Copy new data (key + values) into file
	new linedata[1024]
	FormatKeyValueArrayInt(linedata, charsmax(linedata), setting_key, array_handle)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueArrayInt(linedata[], len1, setting_key[], Array:array_handle)
{
	// Format key
	new index
	formatex(linedata, len1, "%s =", setting_key)
	
	// First value, append to linedata with no commas
	format(linedata, len1, "%s %d", linedata, ArrayGetCell(array_handle, index))
	
	// Successive values, append to linedata with commas (start on index = 1 to skip first value)
	for (index = 1; index < ArraySize(array_handle); index++)
		format(linedata, len1, "%s , %d", linedata, ArrayGetCell(array_handle, index))
}

WriteKeyValueArrayFloat(file, setting_key[], Array:array_handle)
{
	// Copy new data (key + values) into file
	new linedata[1024]
	FormatKeyValueArrayFloat(linedata, charsmax(linedata), setting_key, array_handle)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueArrayFloat(linedata[], len1, setting_key[], Array:array_handle)
{
	// Format key
	new index
	formatex(linedata, len1, "%s =", setting_key)
	
	// First value, append to linedata with no commas
	format(linedata, len1, "%s %.2f", linedata, ArrayGetCell(array_handle, index))
	
	// Successive values, append to linedata with commas (start on index = 1 to skip first value)
	for (index = 1; index < ArraySize(array_handle); index++)
		format(linedata, len1, "%s , %.2f", linedata, ArrayGetCell(array_handle, index))
}

WriteKeyValueArrayString(file, setting_key[], Array:array_handle)
{
	// Copy new data (key + values) into file
	new linedata[1024]
	FormatKeyValueArrayString(linedata, charsmax(linedata), setting_key, array_handle)
	fputs(file, linedata)
	fputc(file, '^n')
}

FormatKeyValueArrayString(linedata[], len1, setting_key[], Array:array_handle)
{
	// Format key
	new index, current_value[128]
	formatex(linedata, len1, "%s =", setting_key)
	
	// First value, append to linedata with no commas
	ArrayGetString(array_handle, index, current_value, charsmax(current_value))
	format(linedata, len1, "%s %s", linedata, current_value)
	
	// Successive values, append to linedata with commas (start on index = 1 to skip first value)
	for (index = 1; index < ArraySize(array_handle); index++)
	{
		ArrayGetString(array_handle, index, current_value, charsmax(current_value))
		format(linedata, len1, "%s , %s", linedata, current_value)
	}
}

SeekReturnValues(file, keypos_start, values[], len1)
{
	// Seek to key and parse it
	new linedata[1024], key[64]
	fseek(file, keypos_start, SEEK_SET)
	fgets(file, linedata, charsmax(linedata))
	
	// Replace newlines with a null character
	replace(linedata, charsmax(linedata), "^n", "")
	
	// Get values
	strtok(linedata, key, charsmax(key), values, len1, '=')
	trim(values)
}

ParseValuesArrayString(values[], len1, Array:array_handle)
{
	// Parse values
	new current_value[128]
	while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, len1, ','))
	{
		// Trim spaces
		trim(current_value)
		trim(values)
		
		// Add to array
		ArrayPushString(array_handle, current_value)
	}
}

ParseValuesArrayInt(values[], len1, Array:array_handle)
{
	// Parse values
	new current_value[16]
	while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, len1, ','))
	{
		// Trim spaces
		trim(current_value)
		trim(values)
		
		// Add to array
		ArrayPushCell(array_handle, str_to_num(current_value))
	}
}

ParseValuesArrayFloat(values[], len1, Array:array_handle)
{
	// Parse values
	new current_value[16]
	while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, len1, ','))
	{
		// Trim spaces
		trim(current_value)
		trim(values)
		
		// Add to array
		ArrayPushCell(array_handle, str_to_float(current_value))
	}	
}