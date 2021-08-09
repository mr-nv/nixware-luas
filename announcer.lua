-- announcer
-- by mrnv / nixware.cc
-- 6 Jul 2021

-- https://mega.nz/file/7exmjQhS#LgmplEFcFgn2MEuIHfV5jnD3Oz9KLV5Z6uZRSpQNIJM
-- drop to steamapps\common\Counter-Strike Global Offensive\lua\
local imagesize = require( "imagesize" );

-- ui
local volume = ui.add_slider_int( "Volume", "babloannouncer_volume", 0, 100, 100 );
local events = ui.add_multi_combo_box( "Events", "babloannouncer_events",
    {
        "Doublekill (2)",
        "Triplekill (3)",
        "Dominating (4)",
        "Megakill (5)",
        "Unstoppable (6)",
        "Wicked sick (7)",
        "Monsterkill (8)",
        "Server connection",
        "Round start",
        "Round end",
        "Headshot",
        "First blood",
        "Grenade kill",
        "Knife kill",
        "Bomb planted",
        "Bomb timer",
        "Vote created",
        "Suicide"
    },
    {
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false
    } );
local roundreset = ui.add_check_box( "Reset on round start", "babloannouncer_roundreset", true );
local hspriority = ui.add_check_box( "Prioritize headshots", "babloannouncer_hspriority", false );
local outline = ui.add_check_box( "Outlined text", "babloannouncer_outline", false );
local debug = ui.add_check_box( "Debug messages", "babloannouncer_debug", false );

-- ffi
ffi.cdef[[
    #pragma pack(push)
	#pragma pack(1)
		struct WIN32_FIND_DATAW {
			uint32_t dwFileWttributes;
			uint64_t ftCreationTime;
			uint64_t ftLastAccessTime;
			uint64_t ftLastWriteTime;
			uint32_t dwReserved[4];
			char cFileName[520];
			char cAlternateFileName[28];
		};
	#pragma(pop)

    int MultiByteToWideChar(unsigned int CodePage, uint32_t dwFlags, const char* lpMultiByteStr, int cbMultiByte, const char* lpWideCharStr, int cchWideChar);
	int WideCharToMultiByte(unsigned int CodePage, uint32_t dwFlags, const char* lpWideCharStr, int cchWideChar, const char* lpMultiByteStr, int cchMultiByte, const char* default, int* used);

    void* FindFirstFileW(const char* pattern, struct WIN32_FIND_DATAW* fd);
	bool FindNextFileW(void* ff, struct WIN32_FIND_DATAW* fd);
	bool FindClose(void* ff);

    typedef unsigned long DWORD;
    DWORD __stdcall GetTickCount( );

    typedef void* HANDLE;
    typedef void* HMODULE;
    typedef char *LPSTR;
    typedef const char* LPCSTR;
    DWORD GetModuleFileNameA( HMODULE hModule, LPSTR lpFilename, DWORD nSize );
    bool CreateDirectoryA( const char *path, void *lpSecurityAttributes );
    DWORD GetFileAttributesA( LPCSTR lpFileName );
]]

local WIN32_FIND_DATA = ffi.typeof( 'struct WIN32_FIND_DATAW' );
local INVALID_HANDLE = ffi.cast( 'void*', -1 );

-- multicolored string util
-- can be done MUCH better

--[[
    (horrible) EXAMPLE

    -- building strings
    local strings = { };
    table.insert( strings, { string = "string 1", color = color_t.new( 30, 30, 30, 255 ) } );
    table.insert( strings, { string = " / ", color = color_t.new( 60, 60, 60, 255 ) } );
    table.insert( strings, { string = "string 2", color = color_t.new( 90, 90, 90, 200 ) } );
    table.insert( strings, { string = " / ", color = color_t.new( 120, 120, 120, 255 ) } );
    table.insert( strings, { string = "string 3", color = color_t.new( 150, 150, 150, 150 ) } );
    table.insert( strings, { string = " / ", color = color_t.new( 180, 180, 180, 255 ) } );
    table.insert( strings, { string = "string 4", color = color_t.new( 210, 210, 210, 100 ) } );

    -- calling the func
    DrawMulticoloredString( strings, font, 18, screensize.x / 2, screensize.y / 2, 1, true );

    type argument accepts these values:
        0 - normal
        1 - dropshadow
        2 - outline
]]--
local function DrawMulticoloredString( strings, font, fontsize, x, y, type, centered )
    -- get the complete string
    local fullstr = "";
    local sizes = { };
    for i = 1, #strings, 1 do
        local str = strings[ i ];
        fullstr = fullstr .. str.string;
        table.insert( sizes, renderer.get_text_size( font, fontsize, str.string ) );
    end

    local fullstrsize = renderer.get_text_size( font, fontsize, fullstr );

    if( centered ) then
        x = x - ( fullstrsize.x / 2 );
    end

    -- just for this announcer lua
    if( outline:get_value( ) ) then
        type = 2;
    end

    local add = 0;
    for i = 1, #strings, 1 do
        local string = strings[ i ];
        local size = sizes[ i ];

        if( type == 0 ) then -- normal
            renderer.text( string.string, font, vec2_t.new( x + add, y ), fontsize, string.color );
        elseif( type == 1 ) then -- dropshadow
            renderer.text( string.string, font, vec2_t.new( x + add + 1, y + 1 ), fontsize, color_t.new( 0, 0, 0, string.color.a ) );
            renderer.text( string.string, font, vec2_t.new( x + add, y ), fontsize, string.color );
        elseif( type == 2 ) then -- outline
            renderer.text( string.string, font, vec2_t.new( x + add - 1, y - 1 ), fontsize, color_t.new( 0, 0, 0, string.color.a ) );
            renderer.text( string.string, font, vec2_t.new( x + add - 1, y + 1 ), fontsize, color_t.new( 0, 0, 0, string.color.a ) );
            renderer.text( string.string, font, vec2_t.new( x + add + 1, y + 1 ), fontsize, color_t.new( 0, 0, 0, string.color.a ) );
            renderer.text( string.string, font, vec2_t.new( x + add + 1, y - 1 ), fontsize, color_t.new( 0, 0, 0, string.color.a ) );

            renderer.text( string.string, font, vec2_t.new( x + add, y ), fontsize, string.color );
        end

        add = add + size.x;
    end
end

-- utils
local function u2w( str, code )
    local size = ffi.C.MultiByteToWideChar( code or 65001, 0, str, #str, nil, 0 );
    local buf = ffi.new( "char[?]", size * 2 + 2 );
    ffi.C.MultiByteToWideChar( code or 65001, 0, str, #str, buf, size * 2 );
    return buf;
end

local function w2u( wstr, code )
    local size = ffi.C.WideCharToMultiByte( code or 65001, 0, wstr, -1, nil, 0, nil, nil );
    local buf = ffi.new( "char[?]", size + 1 );
    size = ffi.C.WideCharToMultiByte( code or 65001, 0, wstr, -1, buf, size, nil, nil );
    return ffi.string( buf );
end

local function GetFilesInDirectory( dir )
    local finddata = ffi.new( WIN32_FIND_DATA );
    local handle = ffi.C.FindFirstFileW( u2w( dir .. "\\*" ), finddata );
    ffi.gc( handle, ffi.C.FindClose );

    local files = { };

    local exists = false;
    if( handle ~= INVALID_HANDLE ) then
        exists = true;

        repeat
            table.insert( files, w2u( finddata.cFileName ) );
        until not ffi.C.FindNextFileW( handle, finddata );
    end

    if( not exists ) then
        ffi.C.CreateDirectoryA( dir, nil );
    end

    ffi.C.FindClose( ffi.gc( handle, nil ) );

    return files;
end

local function GetPlayerColor( player )
    local info = engine.get_player_info( player:get_index( ) );
    if( info == nil ) then return color_t.new( 255, 255, 255, 255 ) end;

    math.randomseed( tonumber( info.steam_id64 ) );

    return color_t.new( math.random( 0, 255 ), math.random( 0, 255 ), math.random( 0, 255 ), 255 );
end

local function GetRandomEntry( array )
    --math.randomseed( globalvars.get_tick_count( ) );
    math.randomseed( os.clock( ) ^ 5 );
    local entry = array[ math.random( #array ) ];
    return entry;
end

local function GetLocalPlayerName( )
    local info = engine.get_player_info( engine.get_local_player( ) );
    if( info == nil ) then return "unknown" end;

    return info.name;
end

local function GetEXEPath( )
    local path = ffi.new( "char[260]", "\0" );
    ffi.C.GetModuleFileNameA( ffi.cast( "void*", 0 ), path, 260 );
    path = tostring( ffi.string( path ) );
    
    path = string.sub( path, 1, string.match( path, "^.*()\\" ) );

    return path;
end

local function IsKilledUsingGrenade( weapon )
    return
        weapon == "hegrenade" or weapon == "smokegrenade" or
        weapon == "inferno" or weapon == "flashbang" or
        weapon == "decoy";
end

-- https://stackoverflow.com/questions/22831701/lua-read-beginning-of-a-string
local function StringStartsWith( str, substr )
    return str:find( '^' .. substr ) ~= nil;
end

local function IsKilledWithKnife( weapon )
    return StringStartsWith( weapon, "knife" );
end

local m_flC4Blow = se.get_netvar( "DT_PlantedC4", "m_flC4Blow" );
local function GetC4Time( entity )
    return ( globalvars.get_current_time( ) - entity:get_prop_float( m_flC4Blow ) ) * -1;
end

local m_iTeamNum = se.get_netvar( "DT_BaseEntity", "m_iTeamNum" );
local function GetTeamNumber( player )
    return player:get_prop_int( m_iTeamNum );
end

local basedirectory = GetEXEPath( );

-- check if nix/sounds folder exists, if not then create it
if( ffi.C.GetFileAttributesA( basedirectory .. "nix\\sounds\\" ) == 0xFFFFFFFF ) then
    ffi.C.CreateDirectoryA( basedirectory .. "nix\\sounds\\", nil );
end

-- check if nix/images folder exists, if not then create it
if( ffi.C.GetFileAttributesA( basedirectory .. "nix\\images\\" ) == 0xFFFFFFFF ) then
    ffi.C.CreateDirectoryA( basedirectory .. "nix\\images\\", nil );
end

-- main code
-- sounds
local sounds =
{
    doublekill = { },
    triplekill = { },
    headshot = { },
    megakill = { },
    roundstart = { },
    dominating = { },
    unstoppable = { },
    wickedsick = { },
    monsterkill = { },
    serverjoin = { },
    firstblood = { },
    roundend = { },
    nadekill = { },
    knifekill = { },
    bombplanted = { },
    votecreated = { },
    bombtimer = { },
    suicide = { }
};

local bombsounds = { };

local function GetSounds( foldername )
    local files = GetFilesInDirectory( basedirectory .. foldername );
    local ret = { };

    for i = 1, #files, 1 do
        local file = files[ i ];
        if( file:sub( -4 ) == ".wav" or file:sub( -4 ) == ".mp3" ) then
            table.insert( ret, file );
        end
    end

    return ret;
end

local function GetBombSounds( files, second )
    local ret = { };

    for i = 1, #files, 1 do
        local file = files[ i ];

        if( StringStartsWith( file, second .. "%." ) or StringStartsWith( file, second .. "s" ) ) then
            table.insert( ret, file );
        end
    end

    return ret;
end

sounds.doublekill = GetSounds( "nix\\sounds\\doublekill" );
sounds.triplekill = GetSounds( "nix\\sounds\\triplekill" );
sounds.headshot = GetSounds( "nix\\sounds\\headshot" );
sounds.megakill = GetSounds( "nix\\sounds\\megakill" );
sounds.roundstart = GetSounds( "nix\\sounds\\roundstart" );
sounds.dominating = GetSounds( "nix\\sounds\\dominating" );
sounds.unstoppable = GetSounds( "nix\\sounds\\unstoppable" );
sounds.wickedsick = GetSounds( "nix\\sounds\\wickedsick" );
sounds.monsterkill = GetSounds( "nix\\sounds\\monsterkill" );
sounds.serverjoin = GetSounds( "nix\\sounds\\serverjoin" );
sounds.firstblood = GetSounds( "nix\\sounds\\firstblood" );
sounds.roundend = GetSounds( "nix\\sounds\\roundend" );
sounds.nadekill = GetSounds( "nix\\sounds\\nadekill" );
sounds.knifekill = GetSounds( "nix\\sounds\\knifekill" );
sounds.bombplanted = GetSounds( "nix\\sounds\\bombplanted" );
sounds.votecreated = GetSounds( "nix\\sounds\\votecreated" );
sounds.bombtimer = GetSounds( "nix\\sounds\\bombtimer" );
sounds.suicide = GetSounds( "nix\\sounds\\suicide" );

-- adding bomb sounds
for i = 1, 120, 1 do
    bombsounds[ i ] = GetBombSounds( sounds.bombtimer, i );
end

-- images
local images =
{
    doublekill = { },
    triplekill = { },
    headshot = { },
    megakill = { },
    roundstart = { },
    dominating = { },
    unstoppable = { },
    wickedsick = { },
    monsterkill = { },
    firstblood = { },
    roundend = { },
    suicide = { }
};

local function GetImages( foldername )
    local files = GetFilesInDirectory( basedirectory .. foldername );
    local ret = { };

    for i = 1, #files, 1 do
        local file = files[ i ];
        if( file:sub( -4 ) == ".png" ) then
            local width, height, type = imagesize.imgsize( basedirectory .. foldername .. "\\" .. file );

            local add = { };
            add.name = file;
            add.width = width;
            add.height = height;
            add.texture = renderer.setup_texture( basedirectory .. foldername .. "\\" .. file );

            table.insert( ret, add );
        end
    end

    return ret;
end

images.doublekill = GetImages( "nix\\images\\doublekill" );
images.triplekill = GetImages( "nix\\images\\triplekill" );
images.headshot = GetImages( "nix\\images\\headshot" );
images.megakill = GetImages( "nix\\images\\megakill" );
images.roundstart = GetImages( "nix\\images\\roundstart" );
images.dominating = GetImages( "nix\\images\\dominating" );
images.unstoppable = GetImages( "nix\\images\\unstoppable" );
images.wickedsick = GetImages( "nix\\images\\wickedsick" );
images.monsterkill = GetImages( "nix\\images\\monsterkill" );
images.firstblood = GetImages( "nix\\images\\firstblood" );
images.roundend = GetImages( "nix\\images\\roundend" );
images.suicide = GetImages( "nix\\images\\suicide" );

-- info
local kills = 0;
local streak = "";
local time = 0;
local wasdisconnected = false;
local playroundstart = false;
local firstblood = false;
local c4 = 0;
local pictime = 0;
local lastimage = 0;
local lastvotetime = 0;

-- photo thing
local function UpdatePhoto( array )
    if( #array > 0 ) then
        math.randomseed( os.clock( ) ^ 5 );
        lastimage = array[ math.random( #array ) ];
        pictime = ffi.C.GetTickCount( );
    else
        lastimage = 0;
        pictime = 0;
    end
end

-- events
se.register_event( "player_death" );
se.register_event( "round_prestart" );
se.register_event( "round_end" );
se.register_event( "bomb_planted" );
se.register_event( "vote_options" );

local function FireGameEvent( event )
    --[[if( event:get_name( ) == "vote_cast" and ffi.C.GetTickCount( ) > ( lastvotetime + 20000 ) ) then
        if( events:get_value( 16 ) and #sounds.votecreated > 0 and event:get_int( "team", 0 ) == GetTeamNumber( entitylist.get_local_player( ) ) ) then
            lastvotetime = ffi.C.GetTickCount( );

            local sound = GetRandomEntry( sounds.votecreated );
            engine.execute_client_cmd( "playvol \"../../nix/sounds/votecreated/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
        end]]--
    if( event:get_name( ) == "vote_options" ) then
        if( events:get_value( 16 ) and #sounds.votecreated > 0 ) then
            local sound = GetRandomEntry( sounds.votecreated );
            engine.execute_client_cmd( "playvol \"../../nix/sounds/votecreated/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
        end
    elseif( event:get_name( ) == "player_death" ) then
        local attacker = event:get_int( "attacker", 0 );
        local victim = event:get_int( "userid", 0 );

        if( engine.get_player_for_user_id( victim ) == engine.get_local_player( ) ) then
            kills = 0;

            if( attacker == 0 or engine.get_player_for_user_id( attacker ) == engine.get_local_player( ) ) then
                if( events:get_value( 17 ) and #sounds.suicide > 0 ) then
                    local sound = GetRandomEntry( sounds.suicide );
                    UpdatePhoto( images.suicide );
                    engine.execute_client_cmd( "playvol \"../../nix/sounds/suicide/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                end
            end
        end

        if( attacker ~= victim ) then -- not a suicide
            if( engine.get_player_for_user_id( attacker ) == engine.get_local_player( ) ) then -- we killed someone
                kills = kills + 1;

                local headshot = event:get_bool( "headshot", false );
                local weapon = event:get_string( "weapon", "" );

                if( events:get_value( 12 ) and IsKilledUsingGrenade( weapon ) and #sounds.nadekill > 0 ) then
                    local sound = GetRandomEntry( sounds.nadekill );
                    engine.execute_client_cmd( "playvol \"../../nix/sounds/nadekill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                    firstblood = false;
                    return;
                end

                if( events:get_value( 13 ) and IsKilledWithKnife( weapon ) and #sounds.knifekill > 0 ) then
                    local sound = GetRandomEntry( sounds.knifekill );
                    engine.execute_client_cmd( "playvol \"../../nix/sounds/knifekill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                    firstblood = false;
                    return;
                end

                if( firstblood and events:get_value( 11 ) and #sounds.firstblood > 0 ) then
                    local sound = GetRandomEntry( sounds.firstblood );
                    time = ffi.C.GetTickCount( );
                    streak = "firstblood";
                    UpdatePhoto( images.firstblood );
                    engine.execute_client_cmd( "playvol \"../../nix/sounds/firstblood/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                    firstblood = false;
                    return;
                end

                if( ( headshot and kills < 2 ) or ( headshot and kills >= 2 and hspriority:get_value( ) ) ) then
                    if( events:get_value( 10 ) and event:get_bool( "headshot", false ) and #sounds.headshot > 0 ) then
                        local sound = GetRandomEntry( sounds.headshot );
                        time = ffi.C.GetTickCount( );
                        streak = "headshot";
                        UpdatePhoto( images.headshot );
                        engine.execute_client_cmd( "playvol \"../../nix/sounds/headshot/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                    end
                else
                    if( kills >= 2 ) then
                        time = ffi.C.GetTickCount( );
                        if( kills == 2 ) then
                            if( events:get_value( 0 ) and #sounds.doublekill > 0 ) then
                                local sound = GetRandomEntry( sounds.doublekill );
                                streak = "doublekill";
                                UpdatePhoto( images.doublekill );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/doublekill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills == 3 ) then
                            if( events:get_value( 1 ) and #sounds.triplekill > 0 ) then
                                local sound = GetRandomEntry( sounds.triplekill );
                                streak = "triplekill";
                                UpdatePhoto( images.triplekill );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/triplekill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills == 4 ) then
                            if( events:get_value( 2 ) and #sounds.dominating > 0 ) then
                                local sound = GetRandomEntry( sounds.dominating );
                                streak = "dominating";
                                UpdatePhoto( images.dominating );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/dominating/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills == 5 ) then
                            if( events:get_value( 3 ) and #sounds.megakill > 0 ) then
                                local sound = GetRandomEntry( sounds.megakill );
                                streak = "megakill";
                                UpdatePhoto( images.megakill );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/megakill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills == 6 ) then
                            if( events:get_value( 4 ) and #sounds.unstoppable > 0 ) then
                                local sound = GetRandomEntry( sounds.unstoppable );
                                streak = "unstoppable";
                                UpdatePhoto( images.unstoppable );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/unstoppable/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills == 7 ) then
                            if( events:get_value( 5 ) and #sounds.wickedsick > 0 ) then
                                local sound = GetRandomEntry( sounds.wickedsick );
                                streak = "wickedsick";
                                UpdatePhoto( images.wickedsick );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/wickedsick/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        elseif( kills >= 8 ) then
                            if( events:get_value( 6 ) and #sounds.monsterkill > 0 ) then
                                local sound = GetRandomEntry( sounds.monsterkill );
                                streak = "monsterkill";
                                UpdatePhoto( images.monsterkill );
                                engine.execute_client_cmd( "playvol \"../../nix/sounds/monsterkill/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                            end
                        end
                    end
                end
            end
        end

        firstblood = false;
    elseif( event:get_name( ) == "round_prestart" ) then
        firstblood = true;
        if( roundreset:get_value( ) ) then
            kills = 0;
        end

        if( events:get_value( 8 ) and #sounds.roundstart > 0 ) then
            playroundstart = true;
        end
    elseif( event:get_name( ) == "round_end" ) then
        c4 = 0;
        if( events:get_value( 9 ) and #sounds.roundend > 0 ) then
            local sound = GetRandomEntry( sounds.roundend );
            UpdatePhoto( images.roundend );
            engine.execute_client_cmd( "playvol \"../../nix/sounds/roundend/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
        end
    elseif( event:get_name( ) == "bomb_planted" ) then
        if( events:get_value( 14 ) and #sounds.bombplanted > 0 ) then
            local sound = GetRandomEntry( sounds.bombplanted );
            engine.execute_client_cmd( "playvol \"../../nix/sounds/bombplanted/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
        end

        if( events:get_value( 15 ) ) then
            local mp_c4timer = se.get_convar( "mp_c4timer" );
            c4 = mp_c4timer:get_float( );
        end
    end
end
client.register_callback( "fire_game_event", FireGameEvent );

local font = renderer.setup_font( "C:\\Windows\\Fonts\\verdana.ttf", 24, 0 );
local function Paint( )
    if( entitylist.get_local_player( ) == nil ) then
        wasdisconnected = true;
        kills = 0;
        streak = "";
        time = 0;
        return;
    end

    if( wasdisconnected and entitylist.get_local_player( ) ~= nil ) then
        wasdisconnected = false;
        if( #sounds.serverjoin > 0 ) then
            local sound = GetRandomEntry( sounds.serverjoin );
            engine.execute_client_cmd( "playvol \"../../nix/sounds/serverjoin/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
        end
    end

    local me = entitylist.get_local_player( );

    if( me ~= nil and c4 > 0 and events:get_value( 15 ) ) then
        local bombs = entitylist.get_entities_by_class( "CPlantedC4" );
        if( #bombs == 1 ) then
            local bomb = bombs[ 1 ];
            local time = GetC4Time( bomb );

            if( time < 0 ) then
                c4 = 0;
            else
                if( math.floor( time ) ~= c4 ) then
                    c4 = math.floor( time );

                    local sound = GetRandomEntry( bombsounds[ c4 ] );
                    engine.execute_client_cmd( "playvol \"../../nix/sounds/bombtimer/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
                end
            end
        else
            c4 = 0;
        end
    end

    if( playroundstart ) then
        playroundstart = false;
        UpdatePhoto( images.roundstart );
        local sound = GetRandomEntry( sounds.roundstart );
        engine.execute_client_cmd( "playvol \"../../nix/sounds/roundstart/" .. sound .. "\" " .. ( volume:get_value( ) / 100 ) );
    end

    local screensize = engine.get_screen_size( );

    if( pictime > 0 and lastimage ~= 0 ) then
        local midx = screensize.x / 2;
        local midy = screensize.y / 2;

        renderer.texture( lastimage.texture,
            vec2_t.new( midx - ( lastimage.width / 2 ), midy - ( lastimage.height / 2 ) - 220 ),
            vec2_t.new( midx + ( lastimage.width / 2 ), midy + ( lastimage.height / 2 ) - 220 ), color_t.new( 255, 255, 255, 255 ) );
    end

    if( ffi.C.GetTickCount( ) > ( pictime + 5000 ) ) then
        lastimage = 0;
        pictime = 0;
    end

    if( time > 0 and streak ~= "" ) then
        local strings = { };
        table.insert( strings, { string = GetLocalPlayerName( ), color = GetPlayerColor( me ) } );

        if( streak == "doublekill" ) then
            table.insert( strings, { string = " got a double kill!", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "triplekill" ) then
            table.insert( strings, { string = " got a triple kill!", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "dominating" ) then
            table.insert( strings, { string = " is dominating", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "megakill" ) then
            table.insert( strings, { string = " is on a mega kill streak", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "unstoppable" ) then
            table.insert( strings, { string = " is unstoppable", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "wickedsick" ) then
            table.insert( strings, { string = " is wicked sick", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "monsterkill" ) then
            table.insert( strings, { string = " is on a monster kill streak", color = color_t.new( 255, 255, 255, 255 ) } );
        elseif( streak == "firstblood" ) then
            table.insert( strings, { string = " drew first blood", color = color_t.new( 255, 255, 255, 255 ) } );
        end

        DrawMulticoloredString( strings, font, 24, screensize.x / 2, ( screensize.y / 2 ) - 230, 1, true );

        if( ffi.C.GetTickCount( ) > ( time + 5000 ) ) then
            streak = "";
            time = 0;
            lastimage = 0;
        end
    end
end
client.register_callback( "paint", Paint );
