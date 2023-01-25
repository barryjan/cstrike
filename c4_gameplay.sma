#include < amxmodx >
#include < cstrike > 
#include < hamsandwich >
#include < fakemeta >
#include < engine >
#include < xs >

#tryinclude < cstrike_pdatas >

#if !defined _cbaseentity_included
	#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
		1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
		2. Put it into amxmodx/scripting/include/ folder   \
		3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
		4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

const m_bStartedArming = 320
const m_bBombPlacedAnimation = 321
const m_flArmedTime2 = 81

new g_iMaxPlayers
new g_iMsgId_BarTime2 

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "C4 Gameplay",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_c4", "forward_PrimaryAttack" )
	RegisterHam( Ham_Touch, "weaponbox", "forward_Touch" )
	
	g_iMaxPlayers = get_maxplayers()
	g_iMsgId_BarTime2 = get_user_msgid( "BarTime2" )
}

public forward_PrimaryAttack( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	
	if ( get_pdata_bool( iEnt, m_bStartedArming, 4 ) )
	{
		message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_BarTime2, _, id )
		write_short( 1 )
		write_short( 90 )
		message_end() 

		set_pdata_float( iEnt, m_flArmedTime2, 0.0, 4 )
	}
}

public forward_Touch( iEnt, id )
{
	static szModel[ 22 ]
	
	pev( iEnt, pev_model, szModel, charsmax( szModel ) )
	
	if ( !equal( szModel[ 9 ], "backpack.mdl" ) )
	{
		return HAM_IGNORED
	}
	
	if ( 1 <= id <= g_iMaxPlayers && cs_get_user_team( id ) == CS_TEAM_CT )
	{
		if ( pev( id, pev_button ) & IN_USE )//&& !( pev( id, pev_oldbuttons ) & IN_USE ) )
		{
			new iC4 = create_entity( "weapon_c4" )
			
			if ( iC4 )
			{
				static flOrigin[ 3 ]
				
				pev( iEnt, pev_origin, flOrigin )
				set_pev( iEnt, pev_flags, pev( iEnt, pev_flags ) | FL_KILLME )
			
				DispatchKeyValue( iC4, "detonatedelay", "10" )
				DispatchSpawn( iC4 )
				
				set_pev( iC4, pev_origin, flOrigin )
			
				force_use( iC4, iC4 )
			}
			/*
			if ( ( iC4 = engfunc( EngFunc_FindEntityByString, -1, "model", "models/w_c4.mdl" ) ) > 0 )
			{
				cs_set_c4_defusing( iC4, true )
				set_pdata_float( iC4, m_flDefuseCountDown, 0.0, 5 )
				
				set_pdata_bool( id, m_bStartDefuse, true, 5 )
				set_pdata_bool( id, m_bBombDefusing, true, 5)
				
				force_use( iC4, id )
			}
			*/
		}
	}
	return HAM_IGNORED
}


stock ham_give_weapon(id,weapon[])
{
    if(!equal(weapon,"weapon_",7)) return 0;

    new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon));
    if(!pev_valid(wEnt)) return 0;

    set_pev(wEnt,pev_spawnflags,SF_NORESPAWN);
    dllfunc(DLLFunc_Spawn,wEnt);
    
    if(!ExecuteHamB(Ham_AddPlayerItem,id,wEnt))
    {
        if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) | FL_KILLME);
        return 0;
    }

    ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,id)
    return 1;
}
