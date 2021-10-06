/*	Copyright © 2009, ConnorMcLeod

	AutoReload on NewRound is free software;
	you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with AutoReload on NewRound; if not, write to the
	Free Software Foundation, Inc., 59 Temple Place - Suite 330,
	Boston, MA 02111-1307, USA.
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Reloaded Weapons On New Round"
#define AUTHOR "ConnorMcLeod"
#define VERSION "2.1.0"

#define XO_WEAPON	4
#define m_pNext		42
#define m_fInReload	54

#define XO_PLAYER				5
#define m_flNextAttack			83
#define m_bNotKilled			113
#define m_rgpPlayerItems_Slot1	368
#define m_rgpPlayerItems_Slot2	369

new g_bitFirstSpawn
#define MarkUserFirstSpawn(%0)	g_bitFirstSpawn |= 1<<(%0&31)
#define ClearUserFirstSpawn(%0)	g_bitFirstSpawn &= ~(1<<(%0&31))
#define IsUserFirstSpawn(%0)	( g_bitFirstSpawn & 1<<(%0&31) )

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	RegisterHam(Ham_Spawn, "player", "Ham_CBasePlayer_Spawn_Pre", 0)
}

public client_connect(id)
{
	MarkUserFirstSpawn(id)
}

public client_putinserver(id)
{
	ClearUserFirstSpawn(id)
}

public Ham_CBasePlayer_Spawn_Pre( id )
{
	if( !IsUserFirstSpawn(id) && get_pdata_int(id, m_bNotKilled, XO_PLAYER) )
	{
		new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, XO_PLAYER)
		set_pdata_float(id, m_flNextAttack, -0.001, XO_PLAYER)

		for(new iPlayerItems=m_rgpPlayerItems_Slot1, iWeapon; iPlayerItems<=m_rgpPlayerItems_Slot2; iPlayerItems++)
		{
			iWeapon = get_pdata_cbase(id, iPlayerItems, XO_PLAYER)
			while( pev_valid(iWeapon) )
			{
				set_pdata_int(iWeapon, m_fInReload, 1, XO_WEAPON)
				ExecuteHamB(Ham_Item_PostFrame, iWeapon)
				iWeapon = get_pdata_cbase(iWeapon, m_pNext, XO_WEAPON)
			}
		}

		set_pdata_float(id, m_flNextAttack, flNextAttack, XO_PLAYER)
	}
}