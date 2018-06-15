#if defined _q_cstrike_const_included
	#endinput
#endif

#define _q_cstrike_const_included

#define EXTRA_OFFSET 5

#if cellbits == 32
	#define OFFSET_TEAM 114
#else
	#define OFFSET_TEAM 139
#endif

enum CsTeams
{
	CS_TEAM_UNASSIGNED = 0,
	CS_TEAM_T = 1,
	CS_TEAM_CT = 2,
	CS_TEAM_SPECTATOR = 3
};
