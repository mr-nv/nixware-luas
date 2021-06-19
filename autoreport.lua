-- autoreport
-- https://github.com/mr-nv/nixware-luas/
-- by mrnv / 19 Jun 2021

local panorama = require( 'panorama' );

ffi.cdef[[
    typedef unsigned long DWORD;
    DWORD __stdcall GetTickCount( );
]]

-- ui
local who = ui.add_combo_box( "Who", "autoreport_who", { "Enemies", "Teammates", "Everybody" }, 0 );
local when = ui.add_multi_combo_box( "When", "autoreport_when", { "Player connection", "Death", "Teamkill", "Kill", "Joining a server" }, { false, false, false, false, true } );

-- utils n Shieet
local m_iTeamNum = se.get_netvar( "DT_BaseEntity", "m_iTeamNum" );
if( m_iTeamNum == nil ) then
    client.notify( "[ERROR] Failed to find m_iTeamNum netvar!" );
    client.unload_script( client.get_script_name( ) );
    return;
end

local function TeamCheck( player )
    if( who:get_value( ) == 2 ) then return true end;

    local me = entitylist.get_local_player( );
    if( who:get_value( ) == 0 ) then -- enemies
        return me:get_prop_int( m_iTeamNum ) ~= player:get_prop_int( m_iTeamNum );
    else -- teammates
        return me:get_prop_int( m_iTeamNum ) == player:get_prop_int( m_iTeamNum );
    end

    return false;
end

-- main code
local reportedplayers = { };
local checkqueue = { };
local reportqueue = { };
local nextreport = 0;
local connected = false;

--[[if( engine.is_in_game( ) and engine.is_connected( ) and engine.get_local_player( ) ) then
    connected = true;
end]]--

local function IsPlayerReported( steamid )
    for i = 1, #reportedplayers, 1 do
        if( reportedplayers[ i ] == steamid ) then
            return true;
        end
    end

    return false;
end

local function ReportPlayer( index )
    local info = engine.get_player_info( index );
    if( info == nil ) then
        client.notify( "Failed to get player info for player #" .. index );
        return;
    end

    panorama.eval( [[
        try
        {
            var xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex( ]] .. index .. [[ );
            var name = GameStateAPI.GetPlayerName( xuid );

            // speedhack rofl
            GameStateAPI.SubmitPlayerReport( xuid, "aimbot,wallhack,speedhack,grief" );
            $.Msg( "Successfully reported player " + name );
        }
        catch( e )
        {
            $.Msg( "Exception while reporting player #]] .. index .. [[" );
        }
    ]] );

    table.insert( reportedplayers, info.steam_id64 );
end

local function ProcessReportQueue( )
    -- no players in report queue
    if( #reportqueue == 0 ) then return end;

    -- delay
    if( nextreport > ffi.C.GetTickCount( ) ) then return end;

    local player = reportqueue[ 1 ];
    table.remove( reportqueue, 1 );

    nextreport = ffi.C.GetTickCount( ) + 2200;

    ReportPlayer( player );
end

local function ProcessCheckQueue( )
    -- no players in check queue
    if( #checkqueue == 0 ) then return end;

    local me = entitylist.get_local_player( );
    if( me ~= nil ) then
        local myteam = me:get_prop_int( m_iTeamNum );
        if( myteam ~= 0 and myteam ~= 1 ) then
            for i = 1, #checkqueue, 1 do
                local index = checkqueue[ i ];
                local player = entitylist.get_entity_by_index( index );
        
                if( player ~= nil ) then
                    local team = player:get_prop_int( m_iTeamNum );
                    if( team ~= 0 and team ~= 1 ) then
                        local info = engine.get_player_info( index );
                        if( info ~= nil ) then
                            if( not info.is_bot and TeamCheck( player ) and not IsPlayerReported( info.steam_id64 ) ) then
                                table.insert( reportqueue, index );
                            end
        
                            table.remove( checkqueue, i );
                            break;
                        end
                    end
                end
            end
        end
    end
end

-- callbacks
local function Paint( )
    if( ( engine.is_in_game( ) and engine.is_connected( ) and engine.get_local_player( ) ) and not connected ) then
        -- report people when you have joined a server
        if( when:get_value( 4 ) ) then
            local me = entitylist.get_local_player( );
            if( me ~= nil ) then
                local myteam = me:get_prop_int( m_iTeamNum );
                if( myteam ~= 0 and myteam ~= 1 ) then
                    connected = true;

                    local players = entitylist.get_players( 2 );
                    for i = 1, #players, 1 do
                        local player = players[ i ];
                        if( player ~= nil and player ~= me and TeamCheck( player ) ) then
                            local index = player:get_index( );
                            local info = engine.get_player_info( index );
                            if( info ~= nil and not info.is_bot and not IsPlayerReported( info.steam_id64 ) ) then
                                table.insert( reportqueue, index );
                            end
                        end
                    end
                end
            end
        else
            connected = true;
        end
    end

    if( not engine.is_in_game( ) or not engine.is_connected( ) ) then
        connected = false;
    end

    if( engine.is_in_game( ) and engine.is_connected( ) and engine.get_local_player( ) ) then
        ProcessCheckQueue( );
        ProcessReportQueue( );
    end
end

se.register_event( "player_connect_full" );
se.register_event( "player_death" );

local function FireGameEvent( event )
    if( event:get_name( ) == "player_connect_full" ) then
        if( when:get_value( 0 ) ) then -- on connection
            local index = engine.get_player_for_user_id( event:get_int( "userid", 0 ) );

            table.insert( checkqueue, index );
        end
    elseif( event:get_name( ) == "player_death" ) then
        local attacker = engine.get_player_for_user_id( event:get_int( "attacker", 0 ) );
        local victim = engine.get_player_for_user_id( event:get_int( "userid", 1 ) );
        if( attacher == victim ) then return end;

        local attackerplayer = entitylist.get_entity_by_index( attacker );
        local victimplayer = entitylist.get_entity_by_index( victim );
        local me = entitylist.get_local_player( );

        if( attackerplayer ~= nil and victimplayer ~= nil and me ~= nil ) then
            if( attacker ~= engine.get_local_player( ) ) then
                if( victim == engine.get_local_player( ) ) then
                    if( me:get_prop_int( m_iTeamNum ) == attackerplayer:get_prop_int( m_iTeamNum ) ) then
                        if( when:get_value( 2 ) ) then -- on teamkill
                            table.insert( reportqueue, attacker ); -- прямая дорога НАХУЙ
                        end
                    else
                        if( when:get_value( 1 ) ) then -- on death
                            table.insert( reportqueue, attacker );
                        end
                    end
                end
            else
                if( when:get_value( 3 ) and TeamCheck( victimplayer ) ) then -- on kill
                    table.insert( reportqueue, victim );
                end
            end
        end
    end
end

client.register_callback( "paint", Paint );
client.register_callback( "fire_game_event", FireGameEvent );
