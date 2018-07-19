#include <amxmodx>
#include <curl>
#include <json>
#include <hl_kreedz_util>

#define PLUGIN "HLKZ Discord WR Notifier"
#define PLUGIN_TAG "HLKZ"
#define VERSION "0.1.0"
#define AUTHOR "naz"

new Handle:curl;
new Handle:header;
new pcvar_kz_discord_webhook;
new pcvar_kz_discord_service;


public plugin_init() 
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR);
    pcvar_kz_discord_webhook = register_cvar("kz_discord_webhook", "");
    pcvar_kz_discord_service = register_cvar("kz_discord_service", "");

    header = curl_create_slist();
    curl_slist_append(header, "Content-Type: application/json"); 
}

public hlkz_worldrecord(id, Float:flTime, type, Array:arr)
{
	if (ArraySize(arr) < 5)
		return;

    static szName[32], szPostdata[640], szTime[12], szType[5], szMap[64], szWebhook[160], szURL[256];
	new minutes, Float:seconds, stats[STATS];
	new szRecDate[32], szRecTime[32];
    GetColorlessName(id, szName, charsmax(szName));
	minutes = floatround(flTime, floatround_floor) / 60;
	seconds = flTime - (60 * minutes);
	get_mapname(szMap, charsmax(szMap));
	get_pcvar_string(pcvar_kz_discord_webhook, szWebhook, charsmax(szWebhook));
	get_pcvar_string(pcvar_kz_discord_service, szURL, charsmax(szURL));

	if (equal(szWebhook, "") || equal(szURL, ""))
		return;

	switch (type)
	{
		case 0: szType = "pure";
		case 1: szType = "pro";
		case 2: return;
	}
	formatex(szTime, charsmax(szTime), "%02d:%06.3f", minutes, seconds);

	new JSON:root = json_init_object();
	json_object_set_string(root, "holder", szName);
	json_object_set_string(root, "time", szTime);
	json_object_set_string(root, "type", szType);
	json_object_set_string(root, "map", szMap);
	json_object_set_string(root, "webhook", szWebhook);

	new JSONArray:records = json_init_array();
	for (new i = 0; i < 5; i++)
	{
		ArrayGetArray(arr, i, stats);

		// TODO: Solve UTF halfcut at the end
		stats[STATS_NAME][17] = EOS;

		minutes = floatround(stats[STATS_TIME], floatround_floor) / 60;
		seconds = stats[STATS_TIME] - (60 * minutes);

		formatex(szRecTime, charsmax(szRecTime), "%02d:%06.3f", minutes, seconds);
		format_time(szRecDate, charsmax(szRecDate), "%d/%m/%Y", stats[STATS_TIMESTAMP]);
		
		new JSON:record = json_init_object();
		json_object_set_string(record, "name", stats[STATS_NAME]);
		json_object_set_string(record, "time", szRecTime);
		json_object_set_string(record, "date", szRecDate);
		json_array_append_value(records, record);
	}
	json_object_set_value(root, "records", records);
	json_serial_to_string(root, szPostdata, charsmax(szPostdata));
    json_free(records);
    json_free(root);

    curl = curl_init();
    curl_setopt_string(curl, CURLOPT_URL, szURL);
	curl_setopt_cell(curl, CURLOPT_FAILONERROR, 1);
    curl_setopt_cell(curl, CURLOPT_FOLLOWLOCATION, 0);
    curl_setopt_cell(curl, CURLOPT_FORBID_REUSE, 1);
    curl_setopt_cell(curl, CURLOPT_FRESH_CONNECT, 1);
    curl_setopt_cell(curl, CURLOPT_CONNECTTIMEOUT, 10);
    curl_setopt_cell(curl, CURLOPT_TIMEOUT, 10);
    curl_setopt_handle(curl, CURLOPT_HTTPHEADER, header);
    curl_setopt_cell(curl, CURLOPT_POST, 1);
    curl_setopt_string(curl, CURLOPT_POSTFIELDS, szPostdata);
    //curl_thread_exec(curl, "OnExecComplete");
    curl_thread_exec(curl, "OnExecComplete");
}

public OnExecComplete(Handle:curl, CURLcode:code, const response[], any:eventType)
{
    curl_close(curl);
    //curl_destroy_slist(header);
}
