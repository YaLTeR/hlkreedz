# HL KreedZ

This repository contains AMX Mod X plugins for Half-Life jump servers, extended with several features for the SourceRuns AG jump server. The already compiled plugins are compiled with AMX Mod X 1.8.3 which is not backwards compatible with 1.8.2 or any other, so if you just grab them without compiling them by yourself, make sure to have AMX Mod X 1.8.3 installed in your server. You can find it here: [AMX Mod X 1.8.3 dev builds](https://www.amxmodx.org/snapshots.php)

## hl_kreedz

hl_kreedz provides essential functionality such as start and stop buttons, timer and leaderboards.

## q_jumpstats

q_jumpstats monitors and records players' high scores in various types of jumps.

## searchmaps

searchmaps provides commands to search through the maps installed on the server, with an optional search term and pagination.  
For this version to work, you have to create an _allmaps.txt_ file (in _addons/amxmodx/configs_) containing a map per line, with all the maps you want.
Doing `cd` into your _ag/maps_ folder and executing `ls *.bsp >> ../addons/amxmodx/configs/allmaps.txt` should be enough for this plugin to work correctly.

## speclist

speclist provides a command to toggle a list of spectators watching you


TODO: explain all the available commands for admins and players
