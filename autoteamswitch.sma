/********************************************************************************
*                        Auto Team Switch Every X Rounds By                     *
*                                                                               *
* Author: nikhilgupta345                                                        *
* ------------------------------------------------------------------------      *
* Info:                                                                         *
* This plugin allows you to switch sides of teams every set number              *
* of rounds. Also gives a command to restart the number of rounds played.       *													  	  		*
* ------------------------------------------------------------------------      *
* Cvars:                                                                        *
* amx_atsrounds - sets the number of rounds before a team switch occurs.        *
* ------------------------------------------------------------------------      *
* Commands:                                                                     *
* amx_roundrestart - restarts the number of rounds that have been played.       *
* say /roundnumber - displays the amount of rounds that have been played.       *
* ------------------------------------------------------------------------      *
* Credits:                                                                      *
* Nextra - Giving suggestions and making the code more efficient.               *
* Tirant - Giving suggestions as well and providing code for the delay.	        *
* Connormcleod - Final suggestions on optimizing code.                          *
* ------------------------------------------------------------------------      *
* Changelog:                                                                    *
* v1.0 - Initial release                                                        *
* v1.01 - Fixed Bugs - Optimized Code                                           *
* v1.1 - Fixed crashing with certain amount of people.                          *********************************
* v1.1.1 - Added new client command - /roundnumber, which displays the amount of rounds that have passed.       *
* v1.2 - Further optimized. Changed name of cvar to make it easier to remember. Added comments.                 *
*                                                                                                               *
* Plugin Main Thread: http://forums.alliedmods.net/showthread.php?p=1288262                                     *
*                                                                                                               *
****************************************************************************************************************/
	
#include <amxmodx>
#include <amxmisc>
#include <cstrike>

#define PLUGIN "Auto Team Switcher"
#define VERSION "1.0"
#define AUTHOR "nikhilgupta345"

#pragma semicolon 1

new roundnumber = 0;
new Atsround;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd( "say /roundnumber", "sayRound" );
	register_concmd( "amx_roundrestart", "restartnumber", ADMIN_KICK );
	
	register_logevent( "roundend", 2, "1=Round_End" );
	register_event( "TextMsg","restart","a","2&#Game_C", "2&#Game_W" ); // Event for "Game Commencing" TextMsg and "Game Will Restart in X Seconds" TextMsg
	
	Atsround = register_cvar( "amx_atsrounds", "5" );
	
}

public sayRound( id )
{
	client_print( id, print_chat, "The current round is %i.", roundnumber );
	return PLUGIN_HANDLED;
}

public roundend()
{
	roundnumber++;
	
	if( roundnumber >= get_pcvar_num( Atsround ) )
	{
		new players[32], num;
		get_players( players, num );
		
		for( new i; i < num; i++ )
			add_delay( players[i] ); // Prevent Server Crash with a lot of people.
			
	}
}


public restartnumber( id, level, cid )
{
	if( !cmd_access( id, level, cid, 1 ) )
		return PLUGIN_HANDLED;
	
	roundnumber = 0;
	return PLUGIN_HANDLED;
}

public restart( id )
{
	roundnumber = 0;
	return PLUGIN_HANDLED;
}

public changeTeam( id )
{
	switch( cs_get_user_team( id ) )
	{
		case CS_TEAM_CT: cs_set_user_team( id, CS_TEAM_T );
		
		case CS_TEAM_T: cs_set_user_team( id, CS_TEAM_CT );
	}

	roundnumber = 0;
}

add_delay( id )
{
	switch( id )
	{
		case 1..7: set_task( 0.1, "changeTeam", id );
		case 8..15: set_task( 0.2, "changeTeam", id );
		case 16..23: set_task( 0.3, "changeTeam", id );
		case 24..32: set_task( 0.4, "changeTeam", id );
	}
}