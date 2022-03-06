-- name esp with custom (better) font
-- for nixware
-- by mrnv / 01 Jun 2021

-- ffi
ffi.cdef[[
    struct WeaponInfo_t
    {
        char _0x0000[20];
        __int32 max_clip;    
        char _0x0018[12];
        __int32 max_reserved_ammo;
        char _0x0028[96];
        char* hud_name;            
        char* weapon_name;        
        char _0x0090[60];
        __int32 type;            
        __int32 price;            
        __int32 reward;            
        char _0x00D8[20];
        bool full_auto;        
        char _0x00ED[3];
        __int32 damage;            
        float armor_ratio;         
        __int32 bullets;    
        float penetration;    
        char _0x0100[8];
        float range;            
        float range_modifier;    
        char _0x0110[16];
        bool silencer;            
        char _0x0121[15];
        float max_speed;        
        float max_speed_alt;
        char _0x0138[76];
        __int32 recoil_seed;
        char _0x0188[32];
    };
]]

-- menu
local fonttype = ui.add_combo_box( "Font type", "luaesp_fonttype", { "Outline", "Shadow" }, 1 );
local playertype = ui.add_combo_box( "Players", "luaesp_type", { "Enemies", "Teammates", "Both" }, 0 );
local nameesp = ui.add_check_box( "Name ESP", "luaesp_name", true );
local weaponesp = ui.add_check_box( "Weapon ESP", "luaesp_weapon", true );

-- colors
local namecolor =
{
    enemy = ui.add_color_edit( "Enemy name ESP color", "luaesp_enemyncolor", false, color_t.new( 255, 255, 255, 255 ) ),
    team = ui.add_color_edit( "Teammates name ESP color", "luaesp_teamncolor", false, color_t.new( 255, 255, 255, 255 ) )
};

local weaponcolor =
{
    enemy = ui.add_color_edit( "Enemy weapon ESP color", "luaesp_enemywcolor", false, color_t.new( 255, 255, 255, 255 ) ),
    team = ui.add_color_edit( "Teammates weapon ESP color", "luaesp_teamwcolor", false, color_t.new( 255, 255, 255, 255 ) )
};

-- utils
local m_iTeamNum = se.get_netvar( "DT_BaseEntity", "m_iTeamNum" );
local m_hActiveWeapon = se.get_netvar( "DT_BaseCombatCharacter", "m_hActiveWeapon" );

local weapondatacall = ffi.cast( "int*(__thiscall*)(void*)", client.find_pattern( "client.dll", "55 8B EC 81 EC 0C 01 ? ? 53 8B D9 56 57 8D 8B" ) );
local function GetWeaponName( player )
    local weapon = entitylist.get_entity_from_handle( player:get_prop_int( m_hActiveWeapon ) );
    if( weapon == nil ) then return "unknown" end;

    local info = ffi.cast( "struct WeaponInfo_t*", weapondatacall( ffi.cast( "void*", weapon:get_address( ) ) ) );
    if( info == nil or info.weapon_name == nil ) then return "unknown" end;

    local name = ffi.string( info.weapon_name );
    if( name == nil ) then return "unknown" end;

    name = string.sub( name, 8 );

    return name;
end 

local function IsEnemy( player )
    local myteam = entitylist.get_local_player( ):get_prop_int( m_iTeamNum );
    local otherteam = player:get_prop_int( m_iTeamNum );

    return myteam ~= otherteam;
end

-- type -> 0 if weapon esp and 1 if name esp
local function GetNameColor( enemy, alpha, type )
    -- crashes lole
    --[[if( enemy ) then
        local color = ui.get_color_edit( "visuals_esp_enemy_name_color" ).get_value( );
        return color_t.new( color.r, color.g, color.b, alpha );
    end

    local color = ui.get_color_edit( "visuals_esp_team_name_color" ).get_value( );
    return color_t.new( color.r, color.g, color.b, alpha );]]--
    --return color_t.new( 255, 255, 255, alpha );

    if( enemy ) then
        if( type == 0 ) then
            local color = weaponcolor.enemy:get_value( );
            return color_t.new( color.r, color.g, color.b, alpha );
        else
            local color = namecolor.enemy:get_value( );
            return color_t.new( color.r, color.g, color.b, alpha );
        end
    else
        if( type == 0 ) then
            local color = weaponcolor.team:get_value( );
            return color_t.new( color.r, color.g, color.b, alpha );
        else
            local color = namecolor.team:get_value( );
            return color_t.new( color.r, color.g, color.b, alpha );
        end
    end
end

-- main code
local font = renderer.setup_font( "C:/Windows/Fonts/Verdana.ttf", 17, 0 );

local m_vecOrigin = se.get_netvar( "DT_BaseEntity", "m_vecOrigin" );

local function SortByDistance( players, me )
    local ret = { };

    local pos = me:get_prop_vector( m_vecOrigin );

    -- get players, calculate our distance to them and put info in a table
    for i = 1, #players do
        local player = players[ i ];
        if( player ~= nil ) then
            local playerpos = player:get_prop_vector( m_vecOrigin );
            local distance = pos:dist_to( playerpos );

            table.insert( ret, { player, distance } );
        end
    end

    -- sort
    table.sort( ret, function( a, b )
        return a[ 2 ] > b[ 2 ];
    end );

    return ret;
end

local function luaesp_Paint( )
    if( not engine.is_connected( ) or not engine.is_in_game( ) ) then return end;

    local players = entitylist.get_players( playertype:get_value( ) );
    if( players == nil ) then return end;

    local me = entitylist.get_local_player( );
    if( me == nil ) then return end;

    players = SortByDistance( players, me );

    for i = 1, #players do
        local player = players[ i ][ 1 ];

        if( player ~= nil and player:get_index( ) ~= engine.get_local_player( ) and player:is_alive( ) ) then
            local alpha = 255;
            if( player:is_dormant( ) ) then
                alpha = 170;
            end

            local bbox = player:get_bbox( );
            if( bbox ~= nil ) then
                -- box esp
                --renderer.rect( vec2_t.new( bbox.left - 1, bbox.top - 1 ), vec2_t.new( bbox.right + 1, bbox.bottom + 1 ), color_t.new( 0, 0, 0, alpha ) );
                --renderer.rect( vec2_t.new( bbox.left, bbox.top ), vec2_t.new( bbox.right, bbox.bottom ), color_t.new( 255, 255, 255, alpha ) );

                -- name esp
                if( nameesp:get_value( ) ) then
                    local info = engine.get_player_info( player:get_index( ) );
                    if( info ~= nil ) then
                        local textsize = renderer.get_text_size( font, 17, info.name );
                        local x = bbox.right - ( ( bbox.right - bbox.left ) / 2 ) - ( textsize.x / 2 );
                        local y = bbox.top - textsize.y - 3;

                        if( fonttype:get_value( ) == 0 ) then -- outline
                            renderer.text( info.name, font, vec2_t.new( x - 1, y - 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( info.name, font, vec2_t.new( x + 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( info.name, font, vec2_t.new( x - 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( info.name, font, vec2_t.new( x + 1, y - 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                        elseif( fonttype:get_value( ) == 1 ) then -- shadow
                            renderer.text( info.name, font, vec2_t.new( x + 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                        end
                    
                        renderer.text( info.name, font, vec2_t.new( x, y ), 17, GetNameColor( IsEnemy( player ), alpha, 1 ) );
                    end
                end

                -- weapon esp
                if( weaponesp:get_value( ) ) then
                    local weaponname = GetWeaponName( player );
                    if( weaponname ~= nil ) then
                        local icon = 0;
                        if( IsEnemy( player ) ) then
                            icon = ui.get_check_box( "visuals_esp_enemy_weapon_icon" );
                        else
                            icon = ui.get_check_box( "visuals_esp_team_weapon_icon" );
                        end

                        local textsize = renderer.get_text_size( font, 17, weaponname );
                        local x = bbox.right - ( ( bbox.right - bbox.left ) / 2 ) - ( textsize.x / 2 );
                        local y = bbox.bottom + 5;
                        if( icon ~= nil and icon:get_value( ) ) then
                            y = y + textsize.y - 2;
                        end

                        if( fonttype:get_value( ) == 0 ) then -- outline
                            renderer.text( weaponname, font, vec2_t.new( x - 1, y - 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( weaponname, font, vec2_t.new( x + 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( weaponname, font, vec2_t.new( x - 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                            renderer.text( weaponname, font, vec2_t.new( x + 1, y - 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                        elseif( fonttype:get_value( ) == 1 ) then -- shadow
                            renderer.text( weaponname, font, vec2_t.new( x + 1, y + 1 ), 17, color_t.new( 0, 0, 0, alpha ) );
                        end
                    
                        renderer.text( weaponname, font, vec2_t.new( x, y ), 17, GetNameColor( IsEnemy( player ), alpha, 0 ) );
                    end
                end
            end
        end
    end
end

client.register_callback( 'paint', luaesp_Paint );
