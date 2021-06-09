-- primeswitcher (fake prime/nonprime)
-- for nixware
-- by mrnv / 09 Jun 2021

-- memcmp(dst, src, len) = ffi.copy(dst, src, len)
ffi.cdef[[
    int __stdcall VirtualProtect(void* lpAddress, unsigned long dwSize, unsigned long flNewProtect, unsigned long* lpflOldProtect);
]]

-- ui
local prime = ui.add_combo_box( "Status", "primeswitcher_status", { "Prime", "Non-Prime" }, 0 );
local lastprime = -1;

-- main code
local ending = ffi.new( 'uint8_t[?]', 4 );
local patch = ffi.new( 'uint8_t[?]', 4 );
local unpatch = ffi.new( 'uint8_t[?]', 3 );

ending[ 0 ] = 0x8A;
ending[ 1 ] = 0xC3;
ending[ 2 ] = 0x5B;
ending[ 3 ] = 0xC3;

patch[ 0 ] = 0x31;
patch[ 1 ] = 0xC0;
patch[ 2 ] = 0x40;
patch[ 3 ] = 0xC3;

unpatch[ 0 ] = 0x31;
unpatch[ 1 ] = 0xC0;
unpatch[ 2 ] = 0xC3;

-- no memcmp for nixware :(
local function IsEnding( addr )
    return
        addr[ 0 ] == ending[ 0 ] and
        addr[ 1 ] == ending[ 1 ] and
        addr[ 2 ] == ending[ 2 ] and
        addr[ 3 ] == ending[ 3 ];
end

local address = client.find_pattern( "client.dll", "8B 0D ? ? ? ? 85 C9 75 04 33 C0 EB 1E" );
if( address == nil ) then
    client.notify( "[ERROR] Failed to find IsPrime by pattern" );
    client.unload_script( client.get_script_name( ) );
    return;
end

local addressend = 0;
local i = 0;
while( addressend == 0 ) do
    if( i > 300 ) then break end;

    local addr = ffi.cast( "uintptr_t*", ( address + i ) );
    local bytes = ffi.new( 'uint8_t[?]', 4 );
    ffi.copy( bytes, addr, 4 );

    if( IsEnding( bytes ) ) then
        addr = tonumber( ffi.cast( 'uintptr_t', addr ) );
        addressend = addr + 3;
        break;
    end

    i = i + 1;
end

if( i > 300 ) then
    client.notify( "[ERROR] Failed to find function ending" );
    client.unload_script( client.get_script_name( ) );
    return;
end

local functionsize = addressend - address;
local originalbytes = { };
local filledbytes = false;

-- memory shit
local function FillOriginalBytes( )
    for i = 0, functionsize, 1 do
        local addr = ffi.cast( "uintptr_t*", ( address + i ) );
        local bytes = ffi.new( 'uint8_t[?]', 1 );
        ffi.copy( bytes, addr, 1 );
        table.insert( originalbytes, bytes[ 0 ] );
    end

    filledbytes = true;
    client.notify( "Saved " .. #originalbytes .. " original bytes" );
end

FillOriginalBytes( );

local function Toggle( )
    local protect = ffi.new( "unsigned long[1]" );
    local ptr = ffi.cast( "void*", address );
    ffi.C.VirtualProtect( ptr, functionsize, 0x40, protect );

    if( prime:get_value( ) == 0 ) then -- Prime
        client.notify( "Activating Prime" );
        for i = 0, functionsize, 1 do
            local addr = ffi.cast( "uintptr_t*", ( address + i ) );
            if( i < 4 ) then
                ffi.cast( "int*", addr )[ 0 ] = patch[ i ];
            else
                ffi.cast( "int*", addr )[ 0 ] = 0x90; -- NOP
            end
        end
    else -- Non-Prime
        client.notify( "Deactivating Prime" );
        for i = 0, functionsize, 1 do
            local addr = ffi.cast( "uintptr_t*", ( address + i ) );
            if( i < 3 ) then
                ffi.cast( "int*", addr )[ 0 ] = unpatch[ i ];
            else
                ffi.cast( "int*", addr )[ 0 ] = 0x90; -- NOP
            end
        end
    end

    ffi.C.VirtualProtect( ptr, functionsize, protect[ 0 ], protect );
end

local function FullyUnload( )
    local protect = ffi.new( "unsigned long[1]" );
    local ptr = ffi.cast( "void*", address );
    ffi.C.VirtualProtect( ptr, functionsize, 0x40, protect );

    for i = 0, #originalbytes, 1 do
        local addr = ffi.cast( "uintptr_t*", ( address + i ) );

        local byte = 0;
        if( originalbytes[ i + 1 ] ~= nil ) then
            byte = originalbytes[ i + 1 ];
        else
            byte = originalbytes[ i ];
        end

        ffi.cast( "int*", addr )[ 0 ] = byte;
    end

    ffi.C.VirtualProtect( ptr, functionsize, protect[ 0 ], protect );
    client.notify( "Restored " .. #originalbytes .. " bytes" );
end

-- callbacks
client.register_callback( "paint",
function( )
    if( lastprime ~= prime:get_value( ) ) then
        lastprime = prime:get_value( );
        Toggle( );
    end
end );

client.register_callback( "unload",
function( )
    if( filledbytes ) then
        FullyUnload( );
    end
end );