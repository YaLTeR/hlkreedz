#include <amxmodx>
#include <curl>
#include <json>
#include <hl_kreedz_util>

#define PLUGIN "HLKZ Discord WR Notifier"
#define VERSION "1.1.0"
#define AUTHOR "Th3-822 & naz"

#define TASKID_RETRY_POST 5810306

#define POST_RETRY_TIME 0.3

#define DISCORD_WEBHOOK_URL_LENGTH 123
#define SHORT_FORMAT_MAX_NAME_LENGTH 15
#define MAX_ENTRIES 20

new const g_szPluginTag[] = "HLKZD";

new const g_szWRecType[][] = {"Noob", "Pro", "Pure"};
new const g_szTLPrefix[][] = {"++-", "--+", "**-", "---"};

new CURL:g_cURLHandle, curl_slist:g_cURLHeaders;
new bool:g_bIsWorking;
new g_cvar_webhook, g_cvar_bot_name, g_cvar_bot_avatar;
new g_cvar_show_tops, g_cvar_trigger_min_records, g_cvar_records, g_cvar_short_format;
new g_szMapName[64];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_cvar_webhook = register_cvar("kz_discord_webhook", "");
	g_cvar_bot_name = register_cvar("kz_discord_bot_name", "HL KreedZ");
	g_cvar_bot_avatar = register_cvar("kz_discord_bot_avatar", "http://212.71.238.124/hlkz/hlkz.png");

	// Making everything customizable at the expense of discord group admins having to be
	// more cautious about who they give permission to connect to their webhook to post WRs

	// What tops to show; it's a bit field
	// TODO: 1<<0 is noob, 1<<1 is pro, 1<<2 is pure ; it probably has to be the reverse though, so
	// kz_discord_show_tops 1 would be intuitively showing only Pure records (probably the main top)
	g_cvar_show_tops = register_cvar("kz_discord_show_tops" , "6");

	// Minimum records to be in the leaderboard to trigger the webhook, if less than that it won't post anything
	g_cvar_trigger_min_records = register_cvar("kz_discord_trigger_min_records", "5");

	// Records to show on Discord, so it shows the first N records including the WR one, if there are that many
	g_cvar_records = register_cvar("kz_discord_records", "5");

	// The short format is nice for small screens (smartphones), and somewhat worse in wide screens
	g_cvar_short_format = register_cvar("kz_discord_short_format", "1");

	get_mapname(g_szMapName, charsmax(g_szMapName));
}

public plugin_end()
{
	if (g_cURLHandle)
	{
		curl_easy_cleanup(g_cURLHandle);
		g_cURLHandle = CURL:0;
	}
	if (g_cURLHeaders)
	{
		curl_slist_free_all(g_cURLHeaders);
		g_cURLHeaders = SList_Empty;
	}
}

public hlkz_worldrecord(iWRecType, Array:arTop)
{
	server_print("[%.4f] Receiving WR of type %d from HLKZ", get_gametime(), iWRecType);

	// The power is a hack while the main HLKZ plugin is refactorized so tops are a bit field
	new bool:bIsAllowedType = bool:(get_pcvar_num(g_cvar_show_tops) & power(2, iWRecType));
	new iTopListMinimum = get_pcvar_num(g_cvar_trigger_min_records);

	static iTopSize;
	if (g_bIsWorking || !bIsAllowedType || (iTopSize = ArraySize(arTop)) < iTopListMinimum)
	{
		if (g_bIsWorking)
		{
			// 2 WRs may arrive at a time, just don't discard the second one and retry at least once...				new payLoad[2];
			new payload[STATS*MAX_ENTRIES];
			payload[0] = iWRecType;
			payload[1] = arTop;
			set_task(POST_RETRY_TIME, "retryPost", TASKID_RETRY_POST, payload, sizeof(payload));
		}
		else
		{
			server_print("[%.4f] Doesn't meet criteria (isWorking: %d, isAllowedType: %d, topSize: %d, arSize: %d)",
				get_gametime(), g_bIsWorking, bIsAllowedType, iTopSize, ArraySize(arTop));
		}
		return;
	}

	static szURL[128];
	if (get_pcvar_string(g_cvar_webhook, szURL, charsmax(szURL)) < DISCORD_WEBHOOK_URL_LENGTH)
	{ // naz: not sure about the URL length, it's unlikely but it may change after some years...
	  // maybe check if empty, if contains http... instead of checking the length
		server_print("[%.4f] Invalid Webhook URL", get_gametime());
		log_amx("[%s] Invalid Webhook URL? -> %s", g_szPluginTag, szURL);
		return;
	}

	static szBuffer[128], sTopEntry[STATS], szMessage[2001], iMsgLen, szDate[11], iMinutes, Float:flSeconds;
	new JSON:jWebhook = json_init_object();
	new iTopList = get_pcvar_num(g_cvar_records);

	if (get_pcvar_string(g_cvar_bot_name, szBuffer, charsmax(szBuffer)))
	{
		json_object_set_string(jWebhook, "username", szBuffer);
	}
	if (get_pcvar_string(g_cvar_bot_avatar, szBuffer, charsmax(szBuffer)))
	{
		json_object_set_string(jWebhook, "avatar_url", szBuffer);
	}

	for (new i, iTop = min(iTopSize, iTopList); i < iTop; i++)
	{
		ArrayGetArray(arTop, i, sTopEntry);
		replace_string(sTopEntry[STATS_NAME], charsmax(sTopEntry[STATS_NAME]), "`", "'");
		floatToMinSec(sTopEntry[STATS_TIME], iMinutes, flSeconds);

		if (!i)
		{
			copy(szBuffer, charsmax(szBuffer), sTopEntry[STATS_NAME]);
			replace_string(szBuffer, charsmax(szBuffer), "\", "\\");
			replace_string(szBuffer, charsmax(szBuffer), "~", "\~");
			replace_string(szBuffer, charsmax(szBuffer), "*", "\*");
			replace_string(szBuffer, charsmax(szBuffer), "@", "\@");

			iMsgLen = formatex(szMessage, charsmax(szMessage), "[HLKZ] **%s** has now the %s WR for **%s**! Finished in **%02d:%06.3f**^n^n**Top %d %s [%s]**^n```diff", szBuffer, g_szWRecType[iWRecType], g_szMapName, iMinutes, flSeconds, iTopList, g_szWRecType[iWRecType], g_szMapName);
		}

		if (get_pcvar_num(g_cvar_short_format))
		{
			new szClampedName[SHORT_FORMAT_MAX_NAME_LENGTH+1];
			copy(szClampedName, charsmax(szClampedName), sTopEntry[STATS_NAME]);
			iMsgLen += formatex(szMessage[iMsgLen], charsmax(szMessage) - iMsgLen, "^n%s %-2d %16s %02d:%06.3f", g_szTLPrefix[min(i, charsmax(g_szTLPrefix))], i + 1, szClampedName, iMinutes, flSeconds);
		}
		else
		{
			format_time(szDate, charsmax(szDate), "%d/%m/%Y", sTopEntry[STATS_TIMESTAMP]);
			iMsgLen += formatex(szMessage[iMsgLen], charsmax(szMessage) - iMsgLen, "^n%s %-2d %30s %02d:%06.3f @ %s", g_szTLPrefix[min(i, charsmax(g_szTLPrefix))], i + 1, sTopEntry[STATS_NAME], iMinutes, flSeconds, szDate);
		}
	}
	iMsgLen += formatex(szMessage[iMsgLen], charsmax(szMessage) - iMsgLen, "```");
	json_object_set_string(jWebhook, "content", szMessage);

	postJSON(szURL, jWebhook);
	json_free(jWebhook);
}

floatToMinSec(const Float:flTime, &iMinutes, &Float:flSeconds)
{
	iMinutes = floatround(flTime, floatround_floor) / 60;
	flSeconds = flTime - (60 * iMinutes);
}

postJSON(const szUrl[], JSON:jData)
{
	if (!g_cURLHandle)
	{
		if (!(g_cURLHandle = curl_easy_init()))
		{
			set_fail_state("[%s] Cannot init cURL's Handle.", g_szPluginTag);
		}
		if (!g_cURLHeaders)
		{
			if (!(g_cURLHeaders = curl_slist_append(SList_Empty, "Content-Type: application/json")))
			{
				set_fail_state("[%s] Cannot init cURL's Headers.", g_szPluginTag);
			}
			curl_slist_append(g_cURLHeaders, "User-Agent: 822_AMXX_PLUGIN/1.1"); // User-Agent
			curl_slist_append(g_cURLHeaders, "Connection: Keep-Alive"); // Keep-Alive
		}

		// Static Options
		curl_easy_setopt(g_cURLHandle, CURLOPT_SSL_VERIFYPEER,	0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_SSL_VERIFYHOST,	0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_SSLVERSION,		CURL_SSLVERSION_TLSv1);
		curl_easy_setopt(g_cURLHandle, CURLOPT_FAILONERROR,		0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_FOLLOWLOCATION,	0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_FORBID_REUSE,	0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_FRESH_CONNECT,	0);
		curl_easy_setopt(g_cURLHandle, CURLOPT_CONNECTTIMEOUT,	10);
		curl_easy_setopt(g_cURLHandle, CURLOPT_TIMEOUT,			10);
		curl_easy_setopt(g_cURLHandle, CURLOPT_HTTPHEADER,		g_cURLHeaders);
		curl_easy_setopt(g_cURLHandle, CURLOPT_POST,			1);
	}

	static szPostData[4096];
	json_serial_to_string(jData, szPostData, charsmax(szPostData));

	curl_easy_setopt(g_cURLHandle, CURLOPT_URL, szUrl);
	curl_easy_setopt(g_cURLHandle, CURLOPT_COPYPOSTFIELDS, szPostData);

	g_bIsWorking = true;
	curl_easy_perform(g_cURLHandle, "postJSON_done");
}

public postJSON_done(CURL:curl, CURLcode:code)
{
	g_bIsWorking = false;
	if (code == CURLE_OK)
	{
		static iStatusCode;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, iStatusCode);
		if (iStatusCode >= 400)
		{
			log_amx("[%s] [Error] HTTP Error: %d", g_szPluginTag, iStatusCode);
		}
	}
	else
	{
		log_amx("[%s] [Error] cURL Error: %d", g_szPluginTag, code);
		curl_easy_cleanup(g_cURLHandle);
		g_cURLHandle = CURL:0;
	}
}

public retryPost(payload[], taskId)
{
	server_print("[%.4f] Retrying to post WR of type %d from HLKZ", get_gametime(), payload[0]);
	hlkz_worldrecord(payload[0], Array:payload[1]);
}
