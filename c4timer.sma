#include <amxmodx>

#define PLUGIN 	"c4 timer"
#define VERSION "1.3"
#define AUTHOR 	"cheap_suit"

new g_c4timer
new mp_c4timer

new cvar_showteam
new cvar_flash
new cvar_sprite
new cvar_msg

new g_msg_showtimer
new g_msg_roundtime
new g_msg_scenario

new const g_timersprite[][] = { "bombticking", "bombticking1" }
new const g_message[] = "Detonation time initialized ....."
new bool:g_roundended

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar(PLUGIN, VERSION, FCVAR_SPONLY|FCVAR_SERVER)

	cvar_showteam 	= register_cvar("amx_showc4timer", "3")
	cvar_flash 	= register_cvar("amx_showc4flash", "0")
	cvar_sprite 	= register_cvar("amx_showc4sprite", "2")
	cvar_msg 	= register_cvar("amx_showc4msg", "0")
	mp_c4timer 	= get_cvar_pointer("mp_c4timer")
	
	g_msg_showtimer	= get_user_msgid("ShowTimer")
	g_msg_roundtime	= get_user_msgid("RoundTime")
	g_msg_scenario	= get_user_msgid("Scenario")
	
	register_event("HLTV", "event_hltv", "a", "1=0", "2=0")
	register_logevent("logevent_roundend", 2, "1=Round_End") 
	register_logevent("logevent_plantedthebomb", 3, "2=Planted_The_Bomb")
}

public plugin_cfg()
	g_c4timer = get_pcvar_num(mp_c4timer)

public event_hltv()
{
	plugin_cfg()
	g_roundended = false
}

public logevent_roundend()
	g_roundended = true

public logevent_plantedthebomb()
{
	if(g_roundended)
		return
	
	new showtteam = get_pcvar_num(cvar_showteam)
	
	static players[32], num, i
	switch(showtteam)
	{
		case 1: get_players(players, num, "ace", "TERRORIST")
		case 2: get_players(players, num, "ace", "CT")
		case 3: get_players(players, num, "ac")
		default: return
	}
	for(i = 0; i < num; ++i) set_task(1.0, "update_timer", players[i])
}

public update_timer(id)
{
	message_begin(MSG_ONE_UNRELIABLE, g_msg_showtimer, _, id)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_msg_roundtime, _, id)
	write_short(g_c4timer)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_msg_scenario, _, id)
	write_byte(1)
	write_string(g_timersprite[clamp(get_pcvar_num(cvar_sprite), 0, (sizeof(g_timersprite) - 1))])
	write_byte(150)
	write_short(get_pcvar_num(cvar_flash) ? 20 : 0)
	message_end()
	
	if(get_pcvar_num(cvar_msg))
	{
		set_hudmessage(255, 180, 0, 0.44, 0.87, 2, 6.0, 6.0)
		show_hudmessage(id, g_message)
	}
}
