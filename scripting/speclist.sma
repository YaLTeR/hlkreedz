#include <amxmodx>
#include <fakemeta>
#include <hl_kreedz_util>

#pragma semicolon 1

#define RED 64
#define GREEN 64
#define BLUE 64

// Comment below if you do not want /speclist showing up on chat
#define ECHOCMD

// Admin flag used for immunity
#define FLAG ADMIN_IMMUNITY

new const PLUGIN[] = "SpecList";
new const VERSION[] = "1.2a";
new const AUTHOR[] = "FatalisDK";

new gMaxPlayers;
new gCvarOn;
new gCvarImmunity;
new gCvarRefreshInterval;
new bool:gOnOff[33] = { true, ... };

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar(PLUGIN, VERSION, FCVAR_SERVER, 0.0);
	gCvarOn = register_cvar("amx_speclist", "1", 0, 0.0);
	gCvarImmunity = register_cvar("amx_speclist_immunity", "1", 0, 0.0);
	gCvarRefreshInterval = register_cvar("amx_speclist_refresh_interval", "1");

	register_clcmd("say /speclist", "cmdSpecList", -1, "");

	gMaxPlayers = get_maxplayers();
	
	set_task(get_pcvar_float(gCvarRefreshInterval), "tskShowSpec", 123094, "", 0, "b", 0);
}

public cmdSpecList(id)
{
	if( gOnOff[id] )
	{
		client_print(id, print_chat, "[AMXX] You will no longer see who's spectating you.");
		gOnOff[id] = false;
	}
	else
	{
		client_print(id, print_chat, "[AMXX] You will now see who's spectating you.");
		gOnOff[id] = true;
	}
	
	#if defined ECHOCMD
	return PLUGIN_CONTINUE;
	#else
	return PLUGIN_HANDLED;
	#endif
}

public tskShowSpec()
{
	if( !get_pcvar_num(gCvarOn) )
	{
		return PLUGIN_CONTINUE;
	}
	
	static szHud[1280];
	static szName[33];
	static bool:send;
	
	// FRUITLOOOOOOOOOOOOPS!
	for( new alive = 1; alive <= gMaxPlayers; alive++ )
	{
		new bool:sendTo[33];
		send = false;
		
		if( !is_user_alive(alive) )
		{
			continue;
		}
		
		sendTo[alive] = true;
		
		GetColorlessName(alive, szName, charsmax(szName));
		format(szHud, 45, "Spectating %s:^n", szName);
		
		for( new dead = 1; dead <= gMaxPlayers; dead++ )
		{
			if( is_user_connected(dead) )
			{
				if( is_user_alive(dead)
				|| is_user_bot(dead) )
				{
					continue;
				}
				
				if( pev(dead, pev_iuser2) == alive )
				{
					if( !(get_pcvar_num(gCvarImmunity)&&get_user_flags(dead, 0)&FLAG) )
					{
						get_user_name(dead, szName, 32);
						add(szName, 33, "^n", 0);
						add(szHud, 1279, szName, 0);
						send = true;
					}

					sendTo[dead] = true;
					
				}
			}
		}
		
		if( send == true )
		{
			for( new i = 1; i <= gMaxPlayers; i++ )
			{
				if( sendTo[i] == true
				&& gOnOff[i] == true )
				{
					set_hudmessage(RED, GREEN, BLUE,
						0.75, 0.15, 0, 0.0, get_pcvar_float(gCvarRefreshInterval) + 0.1, 0.0, 0.0, -1);
					
					show_hudmessage(i, szHud);
				}
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public client_connect(id)
{
	gOnOff[id] = true;
}

public client_disconnect(id)
{
	gOnOff[id] = true;
}
