/* 
 * Q Jumpstats constants by Quaker
 *
 * This file is provided as is (no warranties).
 */

#if defined _q_jumpstats_const_included
	#endinput
#endif

#define _q_jumpstats_const_included

#define MAX_STRAFES 12
#define MAX_DROP_HEIGHT 280.0

enum JumpType
{
	JumpType_LJ,
	JumpType_HJ,
	JumpType_BJ,
	JumpType_SBJ,
	JumpType_DropBJ,
	JumpType_CJ,
	JumpType_DCJ,
	JumpType_MCJ,
	JumpType_DropCJ,
	JumpType_WJ,
	JumpType_LadderBJ,
	
	JumpType_TOTAL
};

stock jump_name[JumpType_TOTAL][] =
{
	"LongJump",
	"HighJump",
	"BhopJump",
	"StandUp BhopJump",
	"Drop BhopJump",
	"CountJump",
	"Double CountJump",
	"Multi CountJump",
	"Drop CountJump",
	"WeirdJump",
	"Ladder BhopJump"
};

stock jump_shortname[JumpType_TOTAL][] =
{
	"LJ",
	"HJ",
	"BJ",
	"SBJ",
	"Drop BJ",
	"CJ",
	"DCJ",
	"MCJ",
	"Drop CJ",
	"WJ",
	"Ladder BJ"
};

stock const Float:g_jump_minpre[JumpType_TOTAL] =
{
	375.0, // LJ
	375.0, // HJ
	395.0, // BJ
	395.0, // SBJ
	395.0, // Drop BJ
	385.0, // CJ
	385.0, // DCJ
	385.0, // MCJ
	385.0, // Drop CJ
	385.0, // WJ
	395.0  // Ladder BJ
};

stock const Float:g_jump_mindist[JumpType_TOTAL] =
{
	320.0, // LJ
	320.0, // HJ
	320.0, // BJ
	320.0, // SBJ
	330.0, // Drop BJ
	330.0, // CJ
	330.0, // DCJ
	330.0, // MCJ
	330.0, // Drop CJ
	340.0, // WJ
	340.0  // Ladder BJ
};

stock jump_level[JumpType_TOTAL][5] =
{
	{ 355, 365, 375, 380, 385 },
	{ 360, 370, 380, 385, 390 },
	{ 345, 355, 365, 375, 380 },
	{ 800, 1000, 1250, 1600, 2000 },
	{ 355, 365, 375, 385, 390 },
	{ 365, 375, 385, 395, 400 },
	{ 365, 375, 385, 395, 400 },
	{ 365, 375, 385, 395, 400 },
	{ 365, 375, 385, 395, 400 },
	{ 365, 375, 385, 395, 400 },
	{ 365, 375, 385, 395, 400 }
};
