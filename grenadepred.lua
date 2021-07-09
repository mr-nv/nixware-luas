-- dogshit grenade prediction/warning/whatever
-- by mrnv / nixware.cc
-- 10 Jul 2021

-- some pasted bit shit
function chk(x, p) return x % (p + p) >= p end
function add(x, p) return chk(x, p) and x or x + p end

-- le round
function round(n)
	return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

-- ffi
ffi.cdef[[
    struct model_t
    {
        void* handle;
        char name[ 260 ];
    };

    typedef struct { float x; float y; float z; } Vector3;
]]

-- UPDATE WHEN NEEDED
-- classids
local classids =
{
    hegrenade = 9, -- CBaseCSGrenadeProjectile
    smokegrenade = 157, -- CSmokeGrenadeProjectile
    decoy = 48, -- CDecoyProjectile
    molotov = 114,-- CMolotovProjectile
    flashbang = 1337
};

-- utils
local function GetClassID( entity )
    local networkable = ffi.cast( "uintptr_t*", entity + 8 )[ 0 ];
    local clientclass = ffi.cast( "uintptr_t*", ffi.cast( "uintptr_t*", networkable + 2 * 4 )[ 0 ] + 1 )[ 0 ];

    return ffi.cast( "int*", clientclass + 20 )[ 0 ];
end

local function GetModel( entity )
    return ffi.cast( "struct model_t**", entity + 0x6C )[ 0 ];
end

local function GetModelName( model )
    return ffi.string( model.name );
end

local function GetGrenadeType( entity )
    local classid = GetClassID( entity );

    if( classid == classids.molotov ) then
        return "molotov";
    elseif( classid == classids.decoy ) then
        return "decoy";
    elseif( classid == classids.smokegrenade ) then
        return "smoke";
    elseif( classid == classids.hegrenade ) then
        local name = GetModelName( GetModel( entity ) );

        if( name:find( "fraggrenade_dropped" ) ) then
            return "he";
        else
            return "flashbang";
        end
    end

    return "";
end

local function Vector_Dot( v1, v2 )
    return ( v1.x * v2.x + v1.y * v2.y + v1.z * v2.z );
end

local function Vector_Normalize( v1 )
    local iradius = 1.0 / math.sqrt( Vector_Dot( v1, v1 ) );

    v1.x = v1.x * iradius;
    v1.y = v1.y * iradius;
    v1.z = v1.z * iradius;

    return v1;
end

local STOP_EPSILON = 0.1;
local function ClipVelocity( argin, normal, overbounce )
    local ret = vec3_t.new( 0, 0, 0 );
    local backoff = Vector_Dot( argin, normal ) * overbounce;
    -- x
    local change_x = normal.x * backoff;
    ret.x = argin.x - change_x;
    if( ret.x > -0.1 and ret.x < 0.1 ) then
        ret.x = 0.0;
    end

    -- y
    local change_y = normal.y * backoff;
    ret.y = argin.y - change_y;
    if( ret.y > -0.1 and ret.y < 0.1 ) then
        ret.y = 0.0;
    end

    -- z
    local change_z = normal.z * backoff;
    ret.z = argin.z - change_z;
    if( ret.z > -0.1 and ret.z < 0.1 ) then
        ret.z = 0.0;
    end

    return ret;
end

local sv_gravity = se.get_convar( "sv_gravity" );
local function AddGravityMove( move, vel, interval )
    local gravity = sv_gravity:get_float( ) * 0.4;
    local z = vel.z - ( gravity * interval );

    move.x = vel.x * interval;
    move.y = vel.y * interval;
    move.z = ( ( vel.z + z ) / 2.0 ) * interval;

    vel.z = z;

    return { move, vel };
end

-- я вообще правильно это спиздил или нет
local molotov_throw_detonate_time = se.get_convar( "molotov_throw_detonate_time" );
local function CheckDetonate( velocity, trace, tick, interval, type )
    if( type == classids.smokegrenade or type == classids.decoy ) then
        if( math.sqrt( velocity.x * velocity.x + velocity.y * velocity.y ) < 0.1 ) then
            local det_tick_mod = round( 0.2 / interval );
            return ( tick % det_tick_mod ) == 0;
        end

        return false;
    elseif( type == classids.molotov ) then
        return ( ( tick * interval ) > molotov_throw_detonate_time:get_float( ) ) or ( trace.fraction < 1.0 and trace.normal.z > 0.7 );
    elseif( type == classids.hegrenade or type == classids.flashbang ) then
        return ( tick * interval ) > 1.5 and ( tick % round( 0.2 / interval ) ) == 0;
    end

    return false;
end

local function ShouldHitEntityFn( entityindex, contentsmask )
    if( entityindex <= 64 ) then return false end; -- players

    local entity = entitylist.get_entity_by_index( entityindex );
    if( entity ~= 0 ) then
        return GetGrenadeType( entity:get_address( ) ) == ""; -- ignore grenades
    end

    return false;
end
local function PushEntity( src, move )
    local traceend = vec3_t.new( src.x + move.x, src.y + move.y, src.z + move.z );
    local datrace = trace.hull( 0x208400B, src, traceend, vec3_t.new( -2, -2, -2 ), vec3_t.new( 2, 2, 2 ), 0, ShouldHitEntityFn );
    return datrace;
end

local function ResolveFlyCollisionBounce( trace, velocity, interval )
    local elasticity = 0.45;

    -- хуй на проверки тута

    local newvelocity = vec3_t.new( 0, 0, 0 );
    local clip = ClipVelocity( velocity, trace.normal, 2.0 );

    newvelocity.x = clip.x * elasticity;
    newvelocity.y = clip.y * elasticity;
    newvelocity.z = clip.z * elasticity;

    local length = newvelocity.x * newvelocity.x + newvelocity.y * newvelocity.y + newvelocity.z * newvelocity.z;
    if( length < 400 ) then
        newvelocity.x = 0;
        newvelocity.y = 0;
        newvelocity.z = 0;
    end

    if( trace.normal.z > 0.7 ) then
        newvelocity.x = newvelocity.x * ( ( 1.0 - trace.fraction ) * interval );
        newvelocity.y = newvelocity.y * ( ( 1.0 - trace.fraction ) * interval );
        newvelocity.z = newvelocity.z * ( ( 1.0 - trace.fraction ) * interval );
            
        trace = PushEntity( trace.endpos, newvelocity );
    else
        velocity.x = newvelocity.x;
        velocity.y = newvelocity.y;
        velocity.z = newvelocity.z;
    end

    return { trace, velocity };
end

-- :thinking:
local function TIME_TO_TICKS( dt )
    return round( ( 0.5 + dt / globalvars.get_interval_per_tick( ) ) );
end

local function Advance( start, velocity, tick, interval, type )
    local move = vec3_t.new( 0, 0, 0 );
    local addgravitymove = AddGravityMove( move, velocity, interval );
    move.x = addgravitymove[ 1 ].x;
    move.y = addgravitymove[ 1 ].y;
    move.z = addgravitymove[ 1 ].z;
    velocity.x = addgravitymove[ 2 ].x;
    velocity.y = addgravitymove[ 2 ].y;
    velocity.z = addgravitymove[ 2 ].z;

    local tr = PushEntity( start, move );
    
    local result = 0;
    if( CheckDetonate( velocity, tr, tick, interval, type ) ) then
        result = add( result, 1 );
    end

    if( tr.fraction ~= 1.0 ) then
        result = add( result, 2 );

        local resolvefly = ResolveFlyCollisionBounce( tr, velocity, interval );
        tr = resolvefly[ 1 ];
    end

    start = tr.endpos;

    return { result, start, velocity };
end

local function Simulate( type, start, velocity )
    local step = TIME_TO_TICKS( 0.05 );
    local timer = 0;

    for i = 0, 500, 1 do
        local s = Advance( start, velocity, i, globalvars.get_interval_per_tick( ), type );
        local result = s[ 1 ];
        if( chk( result, 1 ) ) then
            break;
        end

        start = s[ 2 ];
        velocity = s[ 3 ];

        if( chk( result, 2 ) or timer >= step ) then
            timer = 0;
        else
            timer = timer + 1;
        end

        if( velocity.x == 0.0 and velocity.y == 0.0 and velocity.z == 0.0 ) then
            break;
        end
    end

    return start;
end

-- /// DRAWING SHIT /// --

local weaponiconsfont = renderer.setup_font( "C:/windows/fonts/csgo_icons.ttf", 70, 0 );
local weaponiconsize = 24;

local function Draw3DCircle( pos, points, radius, filled_clr, otline_clr )
    local step = math.pi * 2 / points
    local vec_points = { }
    local z = pos.z
    for i = 0.0, math.pi * 2.0, step 
    do
        local pos_world = vec3_t.new( radius * math.cos( i ) + pos.x, radius * math.sin( i ) + pos.y, z )
        local pos_screen = se.world_to_screen( pos_world )
        if pos_screen 
        then
            table.insert( vec_points, pos_screen )
        end
    end

    if filled_clr ~= nil 
    then
        renderer.filled_polygon( vec_points, filled_clr )
    end

    if otline_clr ~= nil
    then
	    for i = 1, #vec_points
	    do
	        local point = vec_points[i]
	        local next_point = vec_points[i + 1] and vec_points[i + 1] or vec_points[1]

	        renderer.line( point, next_point, otline_clr )
	    end
	end
end

-- ui
local grenadestodraw = ui.add_multi_combo_box( "Grenades", "grenadepred_grenades", { "HE grenade", "Molotov", "Flashbang" }, { true, true, false } );
local hegrenadecolor = ui.add_color_edit( "HE grenade color", "grenadehepred_color", true, color_t.new( 214, 48, 49, 120 ) );
local molotovgrenadecolor = ui.add_color_edit( "Molotov grenade color", "grenademolotovpred_color", true, color_t.new( 225, 112, 85, 120 ) );
local flashgrenadecolor = ui.add_color_edit( "Flash grenade color", "grenadeflashpred_color", true, color_t.new( 250, 250, 250, 120 ) );
local outlinecolor = ui.add_color_edit( "Outline color", "grenadepred_outline", true, color_t.new( 0, 0, 0, 160 ) );
local performance = ui.add_check_box( "Predict only once", "grenadepred_perf", true );

local function CanDraw( classid )
    if( classid == classids.hegrenade ) then
        return grenadestodraw:get_value( 0 );
    elseif( classid == classids.molotov ) then
        return grenadestodraw:get_value( 1 );
    elseif( classid == classids.flashbang ) then
        return grenadestodraw:get_value( 2 );
    end

    return false;
end

local function GetColor( classid )
    if( classid == classids.hegrenade ) then
        return hegrenadecolor:get_value( );
    elseif( classid == classids.molotov ) then
        return molotovgrenadecolor:get_value( );
    elseif( classid == classids.flashbang ) then
        return flashgrenadecolor:get_value( );
    end

    return color_t.new( 255, 255, 255, 255 );
end

local function GetRenderOrigin( player )
    local playertable = ffi.cast( "void***", player );
    local renderable = ffi.cast( "void***(__thiscall*)(void*)", playertable[ 0 ][ 5 ] )( playertable );

    if( renderable ) then
        return ffi.cast( "Vector3*(__thiscall*)(void*)", renderable[ 0 ][ 1 ] )( renderable );
    end

    return vec3_t.new( 0, 0, 0 );
end

local function DrawNade( type, pos )
    local icon = "";
    local radius3d = 0;

    if( type == classids.smokegrenade ) then
        icon = "I";
    elseif( type == classids.decoy ) then
        icon = "F";
    elseif( type == classids.hegrenade ) then
        icon = "H";
        radius3d = 350;
    elseif( type == classids.flashbang ) then
        icon = "G";
    elseif( type == classids.molotov ) then
        icon = "J";
        radius3d = 130;
    end

    if( radius3d > 0 ) then
        Draw3DCircle( pos, 60, radius3d, GetColor( type ), outlinecolor:get_value( ) );
    end

    local w2s = se.world_to_screen( pos );
    if( w2s == nil ) then
        local angles = engine.get_view_angles( );
        local renderorig = GetRenderOrigin( entitylist.get_local_player( ):get_address( ) );
        local x = pos.x - renderorig.x;
        local z = pos.y - renderorig.y;

        local atan = math.atan2( z, x );
        local deg = atan * ( 180 / math.pi );
        deg = deg - ( angles.yaw + 90 );
        atan = ( deg / 180 * math.pi );
        local cos = math.cos( atan ) * -1;
        local sin = math.sin( atan );

        local screensize = engine.get_screen_size( );

        local draw_x = screensize.x / 2 + cos * 150;
        local draw_y = screensize.y / 2 + sin * 150;

        local outcl = outlinecolor:get_value( );
        local maincl = GetColor( type );
        renderer.circle( vec2_t.new( draw_x, draw_y ), 18, 50, false, color_t.new( maincl.r, maincl.g, maincl.b, 180 ) );
        renderer.circle( vec2_t.new( draw_x, draw_y ), ( 18 + globalvars.get_tick_count( ) / 7 % 5 ), 50, false, color_t.new( maincl.r, maincl.g, maincl.b, 100 ) );
        renderer.circle( vec2_t.new( draw_x, draw_y ), 18, 50, true, color_t.new( outcl.r, outcl.g, outcl.b, 125 ) );

        local textsize = renderer.get_text_size( weaponiconsfont, weaponiconsize, icon );
        renderer.text( icon, weaponiconsfont, vec2_t.new( draw_x - ( textsize.x / 2 ), draw_y - 12 ), weaponiconsize, color_t.new( 255, 255, 255, 255 ) );
    else
        local draw_x = w2s.x;
        local draw_y = w2s.y;

        local outcl = outlinecolor:get_value( );
        local maincl = GetColor( type );
        renderer.circle( vec2_t.new( draw_x, draw_y ), 18, 50, false, color_t.new( maincl.r, maincl.g, maincl.b, 180 ) );
        renderer.circle( vec2_t.new( draw_x, draw_y ), ( 18 + globalvars.get_tick_count( ) / 7 % 5 ), 50, false, color_t.new( maincl.r, maincl.g, maincl.b, 100 ) );
        renderer.circle( vec2_t.new( draw_x, draw_y ), 18, 50, true, color_t.new( outcl.r, outcl.g, outcl.b, 125 ) );

        local textsize = renderer.get_text_size( weaponiconsfont, weaponiconsize, icon );
        renderer.text( icon, weaponiconsfont, vec2_t.new( draw_x - ( textsize.x / 2 ), draw_y - 12 ), weaponiconsize, color_t.new( 255, 255, 255, 255 ) );
    end
end

-- /// DRAWING SHIT END /// --

local m_vecOrigin = se.get_netvar( "DT_BaseEntity", "m_vecOrigin" );
local m_vInitialVelocity = se.get_netvar( "DT_BaseCSGrenadeProjectile", "m_vInitialVelocity" );
local font = renderer.setup_font( "C:/Windows/Fonts/verdana.ttf", 18, 0 ); -- aint no way you dont have verdana installed

-- predicted grenades
local pred = { };

local function IsNadePredicted( addr )
    for i = 1, #pred, 1 do
        local nade = pred[ i ];
        if( nade ~= nil and nade.addr == addr ) then
            return true;
        end
    end

    return false;
end

local function CreateMove( cmd )
    for i = 1, #pred, 1 do
        local nade = pred[ i ];
        if( nade ~= nil ) then
            nade.removed = true;
        end
    end

    for i = 64, entitylist.get_highest_entity_index( ), 1 do
        local entity = entitylist.get_entity_by_index( i );
        if( entity ~= nil ) then
            for j = 1, #pred, 1 do
                local nade = pred[ j ];
                if( nade ~= nil and entity:get_address( ) == nade.addr ) then
                    nade.removed = false;
                end
            end
        end
    end

    for i = 1, #pred, 1 do
        local nade = pred[ i ];
        if( nade ~= nil ) then
            if( nade.removed ) then
                table.remove( pred, i );
                break;
            end

            if( performance:get_value( ) ) then
                if( nade.shouldpredict and nade.lastpred == 0 ) then
                    local predicted_position = Simulate( nade.type, nade.firstorigin, nade.entity:get_prop_vector( m_vInitialVelocity ) );
                    nade.lastpred = vec3_t.new(predicted_position.x, predicted_position.y, predicted_position.z);
                end
            else
                if( nade.shouldpredict ) then
                    local predicted_position = Simulate( nade.type, nade.firstorigin, nade.entity:get_prop_vector( m_vInitialVelocity ) );
                    nade.lastpred = vec3_t.new(predicted_position.x, predicted_position.y, predicted_position.z);
                end
            end
     
            if( math.abs( globalvars.get_real_time( ) - nade.spawntime ) > 0.5 ) then
                local origin = nade.entity:get_prop_vector( m_vecOrigin );
                if( origin.x == nade.lastorigin.x and
                    origin.y == nade.lastorigin.y and
                    origin.z == nade.lastorigin.z ) then
                    if( nade.shouldpredict ) then
                        nade.predticks = nade.predticks + 1;

                        if( nade.predticks >= 12 ) then
                            nade.shouldpredict = false;
                        end
                    end
                else
                    nade.predticks = 0;
                    nade.lastorigin = origin;
                end
            end
        end
    end
end
client.register_callback( "create_move", CreateMove );

local function Paint( )
    if( not engine.is_connected( ) or not engine.is_in_game( ) or entitylist.get_local_player( ) == nil ) then
        pred = { };
        return;
    end

    for i = 64, entitylist.get_highest_entity_index( ), 1 do
        local entity = entitylist.get_entity_by_index( i );
        if( entity ~= nil ) then
            local classid = GetClassID( entity:get_address( ) );
            if( not IsNadePredicted( entity:get_address( ) ) and
                ( classid == classids.smokegrenade or classid == classids.hegrenade or
                classid == classids.decoy or classid == classids.molotov ) ) then
                
                if( classid == classids.hegrenade ) then
                    local type = GetGrenadeType( entity:get_address( ) );
                    if( type == "flashbang" ) then
                        classid = classids.flashbang;
                    end
                end

                if( CanDraw( classid ) ) then
                    local add = { };
                    add.entity = entity;
                    add.addr = entity:get_address( );
                    add.vel = entity:get_prop_vector( m_vInitialVelocity );
                    add.spawntime = globalvars.get_real_time( );
                    add.firstorigin = entity:get_prop_vector( m_vecOrigin );
                    add.lastorigin = entity:get_prop_vector( m_vecOrigin );
                    add.type = classid;
                    add.removed = false;
                    add.shouldpredict = true;
                    add.predticks = 0;
                    add.lastpred = 0;
                    table.insert( pred, add );
                end
            end
        end
    end

    for i = 1, #pred, 1 do
        local nade = pred[ i ];
        if( nade ~= nil and nade.shouldpredict ) then
            DrawNade( nade.type, nade.lastpred );
        end
    end
end
client.register_callback( "paint", Paint );
