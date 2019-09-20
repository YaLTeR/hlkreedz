/* AMX Mod X script.
*
*   Enhanced Map Searching (amx_ejl_searchmaps.sma)
*   Copyright (C) 2003-2004  Eric Lidman / jtp10181
*
*   This program is free software; you can redistribute it and/or
*   modify it under the terms of the GNU General Public License
*   as published by the Free Software Foundation; either version 2
*   of the License, or (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program; if not, write to the Free Software
*   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*
*   In addition, as a special exception, the author gives permission to
*   link the code of this program with the Half-Life Game Engine ("HL
*   Engine") and Modified Game Libraries ("MODs") developed by Valve,
*   L.L.C ("Valve"). You must obey the GNU General Public License in all
*   respects for all of the code used other than the HL Engine and MODs
*   from Valve. If you modify this file, you may extend this exception
*   to your version of the file, but you are not obligated to do so. If
*   you do not wish to do so, delete this exception statement from your
*   version.
*
****************************************************************************
*
*   Version 1.7 - 14/06/2018
*
*   Original by Eric Lidman aka "Ludwig van" <ejlmozart@hotmail.com>
*   Homepage: http://lidmanmusic.com/cs/plugins.html
*
*   Upgraded to STEAM and ported to AMXx by: jtp10181 <jtp@jtpage.net>
*   Homepage: http://www.jtpage.net
*
*	Modification for Adrenaline Gamer mod by naz
*
*
****************************************************************************
*
*  This plugin allows users to search through all the maps on your server. The
*  plugin can either search through the servers maps folder and lists them
*  from there, or it can read from a file. This can be set as a compile time
*  define below. To cut down on the lag caused by file actions, the maps are
*  loaded into memory at the start of each map and searched from there while
*  games are in progress. Thus if you add a map to your server, it wont show
*  up in the search until you load the next map. If you are loading the map
*  list from a file a map will not show up until it is added to the file being
*  read. This plugin also has an automatic chat response that will tell people
*  what map is currently playing based on some common questions that are asked.
*
*  Commands:
*
*    mapsearch <target>   returns up to 20 maps in the HUD containing the search target
*
*    listmaps             returns all maps in the console paginated amx_help style
*
*    listmaps <target>    returns all maps containing search target in the
*                            console amx_help style.
*
*    listmapsm            returns all maps in a MOTD popup paginated amx_help style
*
*    listmapsm <target>   returns all maps containing search target in a
*                            MOTD popup window.
*
*	 rtv 				  votes a random map of the map list
*
*
*  ***IF LISTCYCLE mode is enabled below***
*
*    listcycle            returns mapcycle in the console paginated amx_help style
*
*    listcycle <target>   returns mapcycle maps containing search target in the
*                            console amx_help style.
*
*    listcyclem           returns mapcycle in a MOTD popup paginated amx_help style
*
*    listcyclem <target>  returns mapcycle maps containing search target in a
*                            MOTD popup window.
*
*
*  Changelog:
*
*  v1.7 - naz - 14/06/2018
*   - Added rockthevote say command to make the player start a vote for
*		a random map. This vote is specific to Adrenaline Gamer mod, so it
*		only works there or in HL MiniAG
*
*  v1.6 - JTP10181 - 07/24/05
*	- Fixed bug causing it to not compile on loadfile mode
*	- Merged in multi-language code from faluco (Thanks!)
*
*  v1.5 - JTP10181 - 10/17/04
*	- Fixed readdir code so it works on linux (thanks PM)
*	- Small tweaks to code to fix some dumb things I did
*
*  v1.4 - JTP10181 - 07/22/04
*	- Added new compile option to enable listcycle to list the current mapcycle
*	- Fixed a few random things that I was doing incorrectly
*	- Condensed the "admin" command function into one function
*
*  v1.3 - JTP10181 - 07/02/04
*	- Added some new code to catch "say listmaps" and block it from
*		being used by other plugins (Deags Map Manager)
*	- Added MOTD popup support in the form of "listmapsm"
*	- Added some basic dupe checking where it loads the maps in from a dir
*	- Added function to sort the array with the maps
*	- Added advanced dupe checking into the sorting function
*
*  v1.2.2 - JTP10181 - 06/08/04
*	- Tweaked the help info for the commands a little
*	- Fixed some hardcoded paths I left in on accident
*
*  v1.2.1 - JTP10181
*	- Changed all printed messages to use the [AMXX] tag instead of [AMX]
*
*  v1.2 - JTP10181
*	- Added ability to read from a file as a compile option
*	- Fixes for steam (.ztmp files ignored)
*	- Added listmaps output to console amx_help style (thanks tcquest78for amx_help code)
*	- Added a "currentmap" response to the say handler, people are always asking this.
*	- Added lots of other common triggers to a handle say catch so anyone trying to find
*             maps should not have a problem
*
*  Below v1.2 was maintained by Eric Lidman
*
***************************************************************************/

#include <amxmodx>
#include <amxmisc>

#define MAX_MAPS 6144	// Max number of maps the plugin will handle
#define MAPAMOUNT 36	// Number of maps per page (3 on a line)

// Number of maps per MOTD page (4 on a line)
// Setting this higher than 56 will cause some output to be cropped
//     due to limitations of the STEAM MOTD boxes.
#define MAPAMOUNT_MOTD 56

/* Set to 0 to read the maps from the maps folder
*  Set to 1 to attempt to read from a file in the following order:
*	<configdir>/map_manage/allmaps.txt
*	<configdir>/map_manage/mapchoice.ini
*	mapcycle.txt
*
*  NOTE: In testing reading the directory had issues with LINUX server
*	where it was reading each map multiples times into the maps array.
*/
#define LOADFILE 1

//Set to 1 to enable listcycle mode which adds an extra command
//to display and search the current mapcycle.
#define LISTCYCLE 1

// Max number of mapcycle maps the plugin will handle
#define MAX_CYCLE_MAPS 64

/***********************************************************************************
*                                                                                  *
*  *END* customizable section of code. other changes can be done with the cvars    *                                            *
*                                                                                  *
************************************************************************************/

new totalmaps
new T_LMaps[MAX_MAPS][32]

#if LISTCYCLE
new totalmapsc
new T_LCycle[MAX_CYCLE_MAPS][32]
#endif

new pcvar_searchmaps_sort

public plugin_init() {
	register_plugin("Enhanced Map Searching","1.6","EJL/JTP10181")
	register_dictionary("searchmaps.txt")
	register_clcmd("say","HandleSay")
	register_clcmd("mapsearch","admin_mapsearch",0,"<search> - Lists available maps in HUD with search target in their name")
	register_concmd("listmaps","admin_listmaps",0,"[search] [start] - Lists/Searches available maps in console")
	register_clcmd("listmapsm","admin_listmaps",0,"[search] [start] - Lists/Searches available maps in MOTD popup")
	#if LISTCYCLE
	register_concmd("listcycle","admin_listmaps",0,"[search] [start] - Lists/Searches current mapcycle in console")
	register_clcmd("listcyclem","admin_listmaps",0,"[search] [start] - Lists/Searches current mapcycle in MOTD popup")
	#endif
	register_clcmd("say listmaps","say_listmaps",0,"[search] [start] - Lists/Searches available maps in console")

	pcvar_searchmaps_sort = register_cvar("searchmaps_sort", "1")

	get_listing()
	if (get_pcvar_num(pcvar_searchmaps_sort))
		sort_maps()
}

public HandleSay(id) {
	new Speech[192]
	read_args(Speech,192)
	remove_quotes(Speech)
	if (equali(Speech,"rtv", 3) || equali(Speech,"rockthevote", 11) ||
		equali(Speech,"/rtv",4) || equali(Speech,"/rockthevote",12) ||
		equali(Speech,"!rtv",4) || equali(Speech,"!rockthevote",12)) {
		vote_random_map(id)
	} else if(equal(Speech,"mapsearch",9)){
		search_engine(id,Speech[10])
	}
	else if(equal(Speech,"find",4)){
		search_engine(id,Speech[5])
	}
	else if(equal(Speech,"findmaps",8)){
		search_engine(id,Speech[9])
	}
	else if(equal(Speech,"searchmaps",10)){
		search_engine(id,Speech[11])
	}
	else if(equal(Speech,"maplist",7)){
		search_engine(id,Speech[8])
	}
	else if(equal(Speech,"listmapsm",9)){
		client_print(id, print_chat, "%L", id, "DISP_IN_MOTD")
		new cmd[32],arg1[32],arg2[32]
		parse(Speech,cmd,31,arg1,31,arg2,31)
		listmaps_motd_engine(id,arg1,arg2,cmd,T_LMaps,totalmaps)
	}
	else if(equal(Speech,"listmaps",8)){
		client_print(id, print_chat, "%L", id, "DISP_IN_CONS")
		new cmd[32],arg1[32],arg2[32]
		parse(Speech,cmd,31,arg1,31,arg2,31)
		listmaps_engine(id,arg1,arg2,cmd,T_LMaps,totalmaps)
	}
#if LISTCYCLE
	else if(equal(Speech,"listcyclem",10)){
		client_print(id, print_chat, "%L", id, "DISP_CYCLE_MOTD")
		new cmd[32],arg1[32],arg2[32]
		parse(Speech,cmd,31,arg1,31,arg2,31)
		listmaps_motd_engine(id,arg1,arg2,cmd,T_LCycle,totalmapsc)
	}
	else if(equal(Speech,"listcycle",9)){
		client_print(id, print_chat, "%L", id, "DISP_CYCLE_CONS")
		new cmd[32],arg1[32],arg2[32]
		parse(Speech,cmd,31,arg1,31,arg2,31)
		listmaps_engine(id,arg1,arg2,cmd,T_LCycle,totalmapsc)
	}
#endif
	else if(equal(Speech,"current map",11) || equal(Speech,"currentmap",10) || equal(Speech,"thismap",7) || (containi(Speech, "this map") != -1) || (containi(Speech, "map is this") != -1)){
		new mapname[32]
		get_mapname(mapname,31)
		client_print(id, print_chat, "%L", id, "EJL_CUR_MAP", mapname)
	}
	return PLUGIN_CONTINUE
}

public admin_mapsearch(id) {
	new argx[32]
	read_argv(1,argx,32)
	search_engine(id,argx)
	return PLUGIN_HANDLED
}

public admin_listmaps(id) {
	new cmd[32], argx[32], argy[32]
	read_argv(0,cmd,32)
	read_argv(1,argx,32)
	read_argv(2,argy,32)

	if (equali(cmd,"listmaps")) {
		listmaps_engine(id,argx,argy,cmd,T_LMaps,totalmaps)
	}
	else if (equali(cmd,"listmapsm")) {
		console_print(id, "%L", id, "DISP_IN_MOTD")
		listmaps_motd_engine(id,argx,argy,cmd,T_LMaps,totalmaps)
	}
#if LISTCYCLE
	else if (equali(cmd,"listcycle")) {
		listmaps_engine(id,argx,argy,cmd,T_LCycle,totalmapsc)
	}
	else if (equali(cmd,"listcyclem")) {
		console_print(id, "%L", id, "DISP_CYCLE_MOTD")
		listmaps_motd_engine(id,argx,argy,cmd,T_LCycle,totalmapsc)
	}
#endif
	return PLUGIN_HANDLED
}

//This event is only being used to catch the say listmaps and block it so other plugins wont respond.
//The actual response handling from this plugin is in the HandleSay function
public say_listmaps(id) {
	return PLUGIN_HANDLED
}

search_engine(id,argx[]){
	new LMaps[20][32]
	new b
	for(new a = 0; a < totalmaps; a++) {
		if (containi(T_LMaps[a],argx) != -1) {
			if(b < 20){
				copy(LMaps[b], 32, T_LMaps[a])
				b++
			}
		}
	}
	new msg[800]
	set_hudmessage(10,100,250, 0.75, 0.10, 2, 0.02, 14.0, 0.01, 0.1, 23)
	if(b > 0){
		format(msg,800,"%L^n^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n   %s^n",
		id, "SRC_RES_HUD", totalmaps, LMaps[0],LMaps[1],LMaps[2],LMaps[3],LMaps[4],LMaps[5],LMaps[6],LMaps[7],LMaps[8],LMaps[9],LMaps[10],LMaps[11],LMaps[12],LMaps[13],LMaps[14],LMaps[15],LMaps[16],LMaps[17],LMaps[18],LMaps[19])
		show_hudmessage(id,msg)
	}else{
		show_hudmessage(id, "%L", id, "NO_RES_SRC", totalmaps)
	}
	client_print(id, print_chat, "%L", id, "SRC_RES_LRIGHT")
	return PLUGIN_CONTINUE
}

listmaps_engine(id,arg1[],arg2[],cmd[],MapList[][],TMaps){

	if (equal(cmd,"listcycle"))
		console_print(id,"^n---------------- %L -----------------", id, "CONS_CYCLELISTING")
	else
		console_print(id,"^n------------------- %L -------------------", id, "CONS_MAPLISTING")

	new start=0, end=0, tmcount=0
	new tempmap[4][32]
	if (!isdigit(arg1[0]) && !equal("", arg1)) {
		new n=1
		start = arg2 ? str_to_num(arg2) : 1
		if (--start < 0) start = 0
		end = start + MAPAMOUNT
		for(new x = 0; x < TMaps; x++) {
			if (containi(MapList[x], arg1) != -1) {
				if (n > start && n <= end) {
					copy(tempmap[tmcount],31,MapList[x])
					tmcount++
					if (tmcount > 2) {
						tmcount = 0
						console_print(id,"%-20s %-20s %-20s",tempmap[0],tempmap[1],tempmap[2])
					}
				}
  				n++
  			}
		}

		if (tmcount != 0 ) {
			new z
			for (z = tmcount; z < 3; z++) {
				tempmap[z] = ""
			}
			console_print(id,"%-20s %-20s %-20s",tempmap[0],tempmap[1],tempmap[2])
		}

		if (n-1 == 0)
	 		console_print(id,"--------------- %L ---------------", id, "NO_MATCHES_SRC")
		else if (start+1 > n-1)
			console_print(id,"---------------- %L ----------------", id, "HIGHEST_ENTRY", n-1)
		else if (n-1 < end)
			console_print(id,"---------------- %L ----------------", id, "CONS_ENTRIES", start+1,n-1,n-1)
		else
			console_print(id,"---------------- %L ----------------", id, "CONS_ENTRIES", start+1,end,n-1)

		if (end < n-1)
	     		console_print(id,"-------------- %L --------------", id, "USE_FOR_MORE", cmd,arg1,end+1)
	}
	else {
	  	start = arg1 ? str_to_num(arg1) : 1
	  	if (--start < 0) start = 0
	  	if (start >= TMaps) start = TMaps - 1
	  	end = start + MAPAMOUNT
	  	if (end > TMaps) end = TMaps
	  	for (new i = start; i < end; i++){
			copy(tempmap[tmcount],31,MapList[i])
			tmcount++
			if (tmcount > 2) {
				tmcount = 0
				console_print(id,"%-20s %-20s %-20s",tempmap[0],tempmap[1],tempmap[2])
			}
	  	}

		if (tmcount != 0 ) {
			new z
			for (z = tmcount; z < 3; z++) {
				tempmap[z] = ""
			}
			console_print(id,"%-20s %-20s %-20s",tempmap[0],tempmap[1],tempmap[2])
		}

	  	console_print(id,"---------------- %L ----------------", id, "CONS_ENTRIES", start+1,end,TMaps)
	  	if (end < TMaps)
			console_print(id,"-------------- %L --------------", id, "USE_FOR_MORE2", cmd,end+1)
	}
#if LISTCYCLE
	if (equal(cmd,"listcycle"))
		console_print(id,"%L", id, "ALSO_LISTMAPS")
	else if (equal(cmd,"listmaps"))
		console_print(id,"%L", id, "ALSO_LISTCYCLE")
#endif
	console_print(id,"")
	return PLUGIN_HANDLED
}

listmaps_motd_engine(id,arg1[],arg2[],cmd[],MapList[][],TMaps){

	new len = 2047
	new buffer[2048]
	new s = 0

#if !defined NO_STEAM
	s += copy( buffer[s],len-s,"<html><head><style type=^"text/css^">pre{color:#FFB000;}body{background:#000000;margin-left:8px;margin-top:0px;}</style></head><body><pre>^n")
#endif

#if LISTCYCLE
	s += format( buffer[s],len-s,"<div align=^"center^">%L</div>^n", id, "USAGE_LISTCYCLE")
#endif
	s += format( buffer[s],len-s,"<div align=^"center^">%L</div>^n^n^n", id, "USAGE_LISTMAPS")

	new start=0, end=0, tmcount=0
	new tempmap[5][32]
	if (!isdigit(arg1[0]) && !equal("", arg1)) {
		new n=1,x
		start = arg2 ? str_to_num(arg2) : 1
		if (--start < 0) start = 0
		end = start + MAPAMOUNT_MOTD
		for( x = 0; x < TMaps; x++) {
			if (containi(MapList[x], arg1) != -1) {
				if (n > start && n <= end) {
					copy(tempmap[tmcount],31,MapList[x])
					tmcount++
					if (tmcount > 3) {
						tmcount = 0
						s += format( buffer[s],len-s,"%-20s %-20s %-20s %-20s^n",tempmap[0],tempmap[1],tempmap[2],tempmap[3])
					}
				}
  				n++
  			}
		}

		if (tmcount != 0 ) {
			new z
			for (z = tmcount; z < 4; z++) {
				tempmap[z] = ""
			}
			s += format( buffer[s],len-s,"%-20s %-20s %-20s %-20s^n",tempmap[0],tempmap[1],tempmap[2],tempmap[3])
		}

		s += copy( buffer[s],len-s,"^n")

	 	if (n-1 == 0)
	 		s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "NO_MATCHES_SRC")
		else if (start+1 > n-1)
			s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "HIGHEST_ENTRY", n-1)
		else if (n-1 < end)
			s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "CONS_ENTRIES", start+1,n-1,n-1)
		else
			s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "CONS_ENTRIES", start+1,end,n-1)

		if (end < n-1)
	     		s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>", id, "USE_FOR_MORE", cmd,arg1,end+1)
	}
	else {
	  	start = arg1 ? str_to_num(arg1) : 1
	  	if (--start < 0) start = 0
	  	if (start >= TMaps) start = TMaps - 1
	  	end = start + MAPAMOUNT_MOTD
	  	if (end > TMaps) end = TMaps
	  	for (new i = start; i < end; i++){
			copy(tempmap[tmcount],31,MapList[i])
			tmcount++
			if (tmcount > 3) {
				tmcount = 0
				s += format( buffer[s],len-s,"%-20s %-20s %-20s %-20s^n",tempmap[0],tempmap[1],tempmap[2],tempmap[3])
			}
	  	}

		if (tmcount != 0 ) {
			new z
			for (z = tmcount; z < 4; z++) {
				tempmap[z] = ""
			}
			s += format( buffer[s],len-s,"%-20s %-20s %-20s %-20s^n",tempmap[0],tempmap[1],tempmap[2],tempmap[3])
		}

		s += copy( buffer[s],len-s,"^n")
	  	s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "CONS_ENTRIES", start+1,end,TMaps)

	  	if (end < TMaps) {
			s += format( buffer[s],len-s,"<div align=^"center^"><[ %L ]></div>^n", id, "USE_FOR_MORE2", cmd,end+1)
		}
	}

#if !defined NO_STEAM
	s += copy( buffer[s],len-s,"</pre></body></html>")
#endif

	if (equal(cmd,"listcyclem")) {
		show_motd(id,buffer ,"MapCycle Listing")
	}
	else {
		show_motd(id,buffer ,"Map Listing")
	}

	return PLUGIN_HANDLED
}

public get_listing() {

	#if LOADFILE
	new linestr[32], filename[128], stextsize, numword
	new allmaps[128],mapchoice[128],configsdir[64]
	copy(filename,127,"null")
	get_configsdir(configsdir, 63)
	format(allmaps,127,"%s/allmaps.txt",configsdir)
	format(mapchoice,127,"%s/mapchoice.ini",configsdir)

	if (file_exists(allmaps)) {
		copy(filename,127,allmaps)
	}
	else if (file_exists(mapchoice)) {
		copy(filename,127,mapchoice)
	}
	else if (file_exists("mapcycle.txt")) {
		copy(filename,127,"mapcycle.txt")
	}
	else {
		log_amx("No File found for reading map list, SearchMaps will not work.")
	}

	if (!equal(filename,"null")) {
		while((numword = read_file(filename,numword,linestr,32,stextsize)) != 0) {
			if(numword >= MAX_MAPS){
				log_amx("MAX_MAPS has been exceeded, not all maps are able to load for searching")
				break
			}
			replace(linestr, charsmax(linestr), ".bsp", "")
			strtolower(linestr)

			if (!equali(linestr, "")) {
				copy(T_LMaps[totalmaps], 32, linestr)
				totalmaps++
			}
		}
		log_amx("Loaded %d maps for listmaps searching from %s",totalmaps,filename)
	}

	#else

	new data[64], temp, numword

	while((numword = read_dir("maps",numword,data,63,temp)) != 0) {
		strtolower(data)
		if((contain(data,".bsp") != -1) && (containi(data,".ztmp") == -1)) {
			replace(data,63,".bsp","")
			if(totalmaps >= MAX_MAPS){
				log_amx("MAX_MAPS has been exceeded, not all maps are able to load for listmaps searching")
				break
			}
			copy(T_LMaps[totalmaps],31, data)
			totalmaps++
		}
	}
	log_amx("Loaded %d maps for searching from the maps folder",totalmaps)
	#endif

	#if LISTCYCLE
	new linestrc[32], filenamec[16], stextsizec, numwordc

	if (file_exists("mapcycle.txt")) {
		copy(filenamec,15,"mapcycle.txt")
		while(read_file(filenamec,numwordc,linestrc,32,stextsizec)) {
			strtolower(linestrc)
			if(numwordc >= MAX_CYCLE_MAPS){
				log_amx("MAX_CYCLE_MAPS has been exceeded, not all maps are able to load for listcycle searching")
				break
			}
			if (!equali(linestrc, "")) {
				copy(T_LCycle[totalmapsc], 32, linestrc)
				totalmapsc++
			}
			numwordc++
		}
		log_amx("Loaded %d maps for listcycle searching from %s",totalmapsc,filenamec)
	}
	else {
		log_amx("MapCycle file not found for reading, listcycle will not work.")
	}
	#endif

	return PLUGIN_CONTINUE
}

sort_maps() {
	new x,y,z,d
	new bool:swap
	new temp[32]
	for ( x = 0; x < totalmaps; x++ ) {
		for ( y = x + 1; y < totalmaps; y++ ) {
			swap = false
			for (z = 0; z < 32; z++) {
				if ( T_LMaps[x][z] != T_LMaps[y][z]) {
					if ( T_LMaps[x][z] > T_LMaps[y][z] ) swap = true
					break
				}
			}
			if (swap) {
				temp = T_LMaps[x]
				T_LMaps[x] = T_LMaps[y]
				T_LMaps[y] = temp
			}
			else if (equal(T_LMaps[x],T_LMaps[y])) {
				for ( d = y; d < totalmaps - 1; d++ ) {
					T_LMaps[d] = T_LMaps[d + 1]
				}
				y = totalmaps--
				x--
			}
		}
	}
}

// AdrenalineGamer-only
vote_random_map(id)
{
	if (T_LMaps[0][0]) {
		new rand = random_num(0, sizeof(T_LMaps))
		new mapName[32]
		formatex(mapName, charsmax(mapName), "%s", T_LMaps[rand])
		console_print(id, "Map to vote: %s", mapName)
		client_cmd(id, "callvote agmap %s", mapName)
	} else {
		client_print(id, print_chat, "Sorry, an error happened when trying to get the map.")
	}
	return PLUGIN_HANDLED
}
