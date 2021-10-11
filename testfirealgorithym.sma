#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <xs>

#define PLUGIN "New Plug-In"
#define VERSION "1.0"
#define AUTHOR "BARRY."

enum _:FireInfo
{
	Float:m_pos[ 3 ],					// location of this fire
	Float:m_center[ 3 ],				// center of fire
	Float:m_normal[ 3 ],					// surface normal at this fire
	bool:m_burning,
	m_treeDepth,
	m_spawnCount,
	m_parent,							// the fire that spawned us
	Float:m_spawnLifetime,				// how long we attempt to spawn new fires
	Float:m_spawnTimer,					// when we try to spawn a new fire
	Float:m_lifetime,					// lifetime of this fire
	Float:m_flWaterHeight				// how much we were raised above water
};

#define MAX_INFERNO_FIRES 64
new m_fire[ MAX_INFERNO_FIRES ][ FireInfo ]
new m_fireCount
new m_fireSpawnOffset

enum ECreateFireResult_t
{
	k_ECreateFireResult_OK,
	k_ECreateFireResult_LimitExceed,
	k_ECreateFireResult_AlrdyOnFire,
	k_ECreateFireResult_InSmoke,
	k_ECreateFireResult_AllSolid,
}

new g_pSprite
new bool:bTest[ 33 ]

public plugin_init() 
{
	register_plugin( PLUGIN, VERSION, AUTHOR )
	
	register_clcmd( "test", "cmd_test" )
}

public plugin_precache()
{
	g_pSprite = precache_model( "sprites/xenobeam.spr" )
}

public cmd_test( id )
{
	bTest[ id ] = true
	return PLUGIN_HANDLED

	new Float:flOrigin[ 3 ], Float:flNormal[ 3 ], Float:flVelocity[ 3 ]
	
	if ( m_fireCount == 0 )
	{
		fm_get_aim_origin_normal( id, flOrigin, flNormal )
		velocity_by_aim( id, 250, flVelocity )

		CreateFire( flOrigin, 0, 0 )
		m_fireSpawnOffset = 0
	}

	for ( new i = 0; i < m_fireCount; i++ )
	{
		 m_fire[ i ][ m_spawnCount ] += 1
	}
	
	new nextFireOffset = m_fireSpawnOffset + 1
	for ( new i = 0; i < m_fireCount; i++ )
	{
		if ( m_fireCount >= 16 )
			break

		new fireIndex = ( i + m_fireSpawnOffset ) % m_fireCount
		nextFireOffset = fireIndex
		
		if ( m_fire[ fireIndex ][ m_spawnCount ] < 1 )
			continue

		new depth = m_fire[ fireIndex ][ m_treeDepth ] += 1
		if ( depth >= 4 )
			continue

		m_fire[ fireIndex ][ m_spawnCount ] -= 1
		
		new Float:out[ 3 ]
		new parent = m_fire[ fireIndex ][ m_parent ]

		if ( !parent )
		{
			// initial fire spreads outward in a circle
			new Float:randomangle = random_float( -3.14159, 3.14159 )
			out[ 0 ] =  floatcos( randomangle ) 
			out[ 1 ] =  floatsin( randomangle )
			out[ 2 ] = 0.0
		}
		else
		{
			// child flames tend to spread away from their parent
			new Float:to[ 3 ]
			xs_vec_sub( m_fire[ fireIndex ][ m_pos ],  m_fire[ parent ][ m_pos ], to )
			xs_vec_normalize( to, to )

			//VectorAngles( to, angles )
			new Float:angles[ 3 ]
			vector_to_angle( to, angles )
			angles[ 1 ] += random_float( -45.0, 45.0 )

			//AngleVectors( angles, &out )
			angle_vector( angles, ANGLEVECTOR_FORWARD, out )
		}

		// If we're going into a wall, don't keep trying to spread into a wall the entire lifetime - back off to
		// a circular spread at the end.
		//float velocityDecay = pow( InfernoVelocityDecayFactor.GetFloat(), float(fire->m_treeDepth) );
		//new Float:velocityDecay = floatpower( 0.2, float( m_fire[ fireIndex ][ m_treeDepth ] )  )
		//Vector timeAdjustedSpreadVelocity = spreadVelocity * fire->m_lifetime.GetRemainingRatio() * velocityDecay;
		//out += InfernoVelocityFactor.GetFloat() * timeAdjustedSpreadVelocity;	
		//Vector pos = fire->m_pos + range * out;

		//angle_vector( out, ANGLEVECTOR_FORWARD, out )
		//xs_vec_add( out, flVelocity, out )

		new Float:randomRange = random_float( 50.0, 75.0 )
		xs_vec_mul_scalar( out, randomRange, out )

		new Float:pos[ 3 ]
		xs_vec_add( m_fire[ fireIndex ][ m_pos ], out, pos  )
		
		CreateFire( pos, fireIndex, depth )

		continue
	}
	m_fireSpawnOffset = nextFireOffset + 1

	return PLUGIN_HANDLED
}

ECreateFireResult_t:CreateFire( Float:pos[ 3 ], parent, depth )
{
	new Float:firePos[ 3 ]
	xs_vec_copy( pos, firePos )
	xs_vec_copy( pos, m_fire[ m_fireCount ][ m_pos ] )
	
	m_fire[ m_fireCount ][ m_parent ] = parent
	m_fire[ m_fireCount ][ m_treeDepth ] = depth
	m_fire[ m_fireCount ][ m_spawnCount ] = 0

	firePos[ 2 ] += 100.0
	te_beampoints( firePos, pos )
	
	if ( parent )
	{
		new Float:parentPos[ 3 ]
		xs_vec_copy( m_fire[ parent ][ m_pos ], parentPos )
		te_beampoints( parentPos, pos )
	}

	++m_fireCount

	return k_ECreateFireResult_OK
}

public client_PreThink( id )
{
	if ( !bTest[ id ] ) return PLUGIN_HANDLED
	
	new Float:myOrigin[ 3 ]
	pev( id, pev_origin, myOrigin )

	new Float:flOrigin[ 3 ], Float:flNormal[ 3 ]
	fm_get_aim_origin_normal( id, flOrigin, flNormal )

	new Float:flVelocity[ 3 ]
	velocity_by_aim( id, 500, flVelocity )
	
	//new Float:flSpash = xs_vec_dot( flVelocity, flNormal )
	//new Float:flSpashVelocity[ 3 ]
	//xs_vec_mul_scalar( flNormal, flSpash, flNormal )
	//xs_vec_sub( flVelocity, flNormal, flSpashVelocity )

	new Float:to[ 3 ]
	xs_vec_sub( flOrigin, myOrigin, to )
	xs_vec_normalize( to, to )

	new Float:angles[ 3 ]
	vector_to_angle( to, angles )
	angles[ 1 ] += random_float( -45.0, 45.0 )

	new Float:out[ 3 ]
	angle_vector( angles, ANGLEVECTOR_FORWARD, out )

	// put fire on plane of ground
	//Vector side = CrossProduct( fire->m_normal, out );
	//out = CrossProduct( side, fire->m_normal );
	new Float:side[ 3 ]
	xs_vec_cross( flNormal, out, side )
	xs_vec_cross( side, flNormal, out )

	xs_vec_mul_scalar( out, 50.0, out )

	new Float:pos[ 3 ]
	xs_vec_add( flOrigin, out, pos )

	te_beampoints(flOrigin, pos )
	
	return PLUGIN_HANDLED
}

stock te_beampoints( Float:flStartOrigin[ 3 ], Float:flEndOrigin[ 3 ] )
{
	message_begin( MSG_ALL, SVC_TEMPENTITY )
	write_byte( TE_BEAMPOINTS ) // write_byte(TE_BEAMPOINTS)		
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 0 ] ) // write_coord(startposition.x)
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 1 ] ) // write_coord(startposition.y)
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 2 ] ) // write_coord(startposition.z)
	engfunc( EngFunc_WriteCoord, flEndOrigin[ 0 ] ) // write_coord(endposition.x)
	engfunc( EngFunc_WriteCoord, flEndOrigin[ 1 ] ) // write_coord(endposition.y)
	engfunc( EngFunc_WriteCoord, flEndOrigin[ 2 ] ) // write_coord(endposition.z)
	write_short( g_pSprite ) // write_short(sprite index) 
	write_byte( 1 ) 		// write_byte(starting frame) 
	write_byte( 1 ) 	// write_byte(frame rate in 0.1's) 
	write_byte( 1 ) 		// write_byte(life in 0.1's) 
	write_byte( 5 )		// write_byte(line width in 0.1's) 
	write_byte( 0 )		// write_byte(noise amplitude in 0.01's) 
	write_byte( 255 )	// write_byte(red)
	write_byte( 255 )	// write_byte(green)
	write_byte( 255 )	// write_byte(blue)
	write_byte( 150 )	// write_byte(brightness)
	write_byte( 1 )		// write_byte(scroll speed in 0.1's)
	message_end()
}
	
stock check_angle( Float:flStartOrigin[ 3 ], Float:flVector[ 3 ] )
{
	message_begin( MSG_ALL, SVC_TEMPENTITY )
	write_byte( TE_STREAK_SPLASH )
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 0 ] )
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 1 ] )
	engfunc( EngFunc_WriteCoord, flStartOrigin[ 2 ] )
	engfunc( EngFunc_WriteCoord, flVector[ 0 ] )
	engfunc( EngFunc_WriteCoord, flVector[ 1 ] )
	engfunc( EngFunc_WriteCoord, flVector[ 2 ] )
	write_byte( 255 )
	write_short( 20 )
	write_short( 100 )
	write_short( 50 )
	message_end()
}

stock create_line( Float:flOrigin1[ 3 ], Float:flOrigin2[ 3 ] )
{
	message_begin( MSG_ALL, SVC_TEMPENTITY )
	write_byte( TE_LINE )
	engfunc( EngFunc_WriteCoord, flOrigin1[ 0 ] )
	engfunc( EngFunc_WriteCoord, flOrigin1[ 1 ] )
	engfunc( EngFunc_WriteCoord, flOrigin1[ 2 ] )
	engfunc( EngFunc_WriteCoord, flOrigin2[ 0 ] )
	engfunc( EngFunc_WriteCoord, flOrigin2[ 1 ] )
	engfunc( EngFunc_WriteCoord, flOrigin2[ 2 ] )
	write_short( 1 )
	write_byte( 100 )
	write_byte( 100 )
	write_byte( 100 )
	message_end()
}

//from fakemeta_util.inc, modified by stupok
stock fm_get_aim_origin_normal(index, Float:origin[3], Float:normal[3])
{
	static Float:start[3], Float:view_ofs[3]
	pev(index, pev_origin, start)
	pev(index, pev_view_ofs, view_ofs)
	xs_vec_add(start, view_ofs, start)
	
	static Float:dest[3]
	pev(index, pev_v_angle, dest)
	engfunc(EngFunc_MakeVectors, dest)
	global_get(glb_v_forward, dest)
	xs_vec_mul_scalar(dest, 9999.0, dest)
	xs_vec_add(start, dest, dest)
	
	static tr
	//static Float:dist
	tr = create_tr2()
	engfunc(EngFunc_TraceLine, start, dest, DONT_IGNORE_MONSTERS, index, tr)
	get_tr2(tr, TR_vecEndPos, origin)
	
	new Float:dist = get_distance_f(start, origin)
	origin[0] -= (origin[0] - start[0])/dist
	origin[1] -= (origin[1] - start[1])/dist
	origin[2] -= (origin[2] - start[2])/dist

	get_tr2(tr, TR_vecPlaneNormal, normal)
	free_tr2(tr)
}


/*
stock get_front_origin(id, Float:dist, Float:origin[3], Float:angle = 0.0)
{
	new iVectorStart[3]; 
	get_user_origin(id, iVectorStart, 1);

	new iVectorEnd[3]; 
	get_user_origin(id, iVectorEnd, 3);

	new Float:fVectorStart[3]; 
	IVecFVec(iVectorStart, fVectorStart);

	new Float:fVectorEnd[3]; 
	IVecFVec(iVectorEnd, fVectorEnd);
	
	new Float:fAddVec[3]; 
	xs_vec_sub(fVectorEnd, fVectorStart, fAddVec);
	fAddVec[2] = 0.0;
	xs_vec_normalize(fAddVec, fAddVec);
	
	new Float: velocity[3];
	pev(id, pev_velocity, velocity);
	velocity[2] = 0.0;
	
	new Float:vec_angle = vectors_angle(fAddVec, velocity);
	if(vec_angle < 80.0)
	{
		dist += vector_length(velocity) * CHECK_TIME;
	}
	
	xs_vec_mul_scalar(fAddVec, dist, fAddVec);
	
	if(angle != 0.0)
	{
		fAddVec = vec_rotation(fAddVec, angle);
	}
	
	pev(id, pev_origin, origin);
	xs_vec_add(origin, fAddVec, origin);
}

stock Float:vec_rotation(Float:vec[3], Float:angle)
{
	new Float:out[3];
	out[0] = vec[0] * floatcos(angle, degrees) - vec[1] * floatsin(angle, degrees);
	out[1] = vec[0] * floatsin(angle, degrees) + vec[1] * floatcos(angle, degrees);
	out[2] = vec[2];
	return out;
}

stock Float:vectors_angle(Float:v1[3], Float:v2[3])
{ 
    return floatacos( (v1[0]*v2[0]+v1[1]*v2[1])/(floatsqroot(v1[0]*v1[0]+v1[1]*v1[1])*floatsqroot(v2[0]*v2[0]+v2[1]*v2[1])), degrees);
}

*/
