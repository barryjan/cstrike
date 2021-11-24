/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <xs>
#include <engine>

#define PLUGIN "test srpite on ground"
#define VERSION "1.0"
#define AUTHOR "barry"


new ground_fire4
public plugin_precache()
{
	ground_fire4 = precache_model("sprites/ground_fire_4.spr")
	precache_model("sprites/fire_explosion_1.spr")
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_clcmd("say /test", "test")
}

public test( id )
{
	new spriteorigin[3]
	get_user_origin(id, spriteorigin);
	
	set_task( 0.4, "firefield", _, spriteorigin, 3, "a", 2 )
	
	/*
	#define TEFIRE_FLAG_ADDITIVE	32
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte( TE_FIREFIELD );
	write_coord( spriteorigin[0] ); //coord coord coord (position)
	write_coord( spriteorigin[1] );
	write_coord( spriteorigin[2]-30 );
	write_short( 45 ); //Radius
	switch( i )
	{
		case 0: write_short( ground_fire1 );
		case 1: write_short( ground_fire2 );
		case 2: write_short( ground_fire3 );
	}
	write_byte( 3 ); // count
	write_byte( TEFIRE_FLAG_PLANAR | TEFIRE_FLAG_ADDITIVE | TEFIRE_FLAG_LOOP ); //flags
	write_byte( 1000 ); // duration in sec.
	message_end();	
	*/
	new ent = create_entity("env_sprite")
	
	new Float:fOrigin[3]
	IVecFVec(spriteorigin, fOrigin)
	fOrigin[2] += 200.0
	entity_set_model(ent, "sprites/fire_explosion_1.spr")
	entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
	entity_set_float(ent, EV_FL_framerate, 24.0)
	entity_set_origin(ent, fOrigin)
	entity_set_size(ent, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0})
	DispatchSpawn(ent)
	
	drop_to_floor(ent)

	//entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
	//entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS)
	entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
	entity_set_float(ent, EV_FL_renderamt, 255.0)
	entity_set_float(ent, EV_FL_scale, 1.0)
	entity_set_edict(ent,EV_ENT_owner, id)
	drop_to_floor(ent)
	
	new Float:flTraceStart[ 3 ]
	new Float:flTraceEnd[ 3 ]
	new Float:flNormal[ 3 ]

	new g_pLaserMineTrace = create_tr2()
	pev( ent, pev_origin, flTraceStart )
	xs_vec_copy( flTraceStart, flTraceEnd )
	flTraceEnd[2] -= 990.0
	
	engfunc( EngFunc_TraceLine, flTraceStart, flTraceEnd, DONT_IGNORE_MONSTERS|IGNORE_GLASS, id, g_pLaserMineTrace )
	get_tr2( g_pLaserMineTrace, TR_vecPlaneNormal, flNormal	)
	get_tr2( g_pLaserMineTrace, TR_vecEndPos, flTraceEnd )
	
	free_tr2(g_pLaserMineTrace)
	new Float:flAngles[ 3 ]
	flNormal[0] *= -1.0
	flNormal[1] *= -1.0
	vector_to_angle(flNormal, flAngles)
	set_pev(ent, pev_angles, flAngles)
	flTraceEnd[2] += 1.0
	set_pev( ent, pev_origin, flTraceEnd)
	//drop_to_floor(ent)

	return PLUGIN_HANDLED
}

public firefield(spriteorigin[])
{
	#define TEFIRE_FLAG_ADDITIVE	32

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte( TE_FIREFIELD );
	write_coord( spriteorigin[0] ); //coord coord coord (position)
	write_coord( spriteorigin[1] );
	write_coord( spriteorigin[2]-20 );
	write_short( 0 ); //Radius
	write_short( ground_fire4 );
	write_byte( 1 ); // count
	write_byte( TEFIRE_FLAG_PLANAR | TEFIRE_FLAG_ADDITIVE | TEFIRE_FLAG_LOOP ); //flags
	write_byte( 1000 ); // duration in sec.
	message_end();
}