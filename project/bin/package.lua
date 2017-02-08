--[[
Titanium License File

At the time of writing, all source code used in Titanium is open source under
the MIT license.

This essentially means that the code can be used however you wish as long as my
license (and therefor the license of any work I adapted) is included with my
code.

Titanium source

All Titanium source is written by Harry Felton unless otherwise stated, the
below describes what you can do with my code under the conditions given:
The MIT License (MIT)

Copyright (c) 2016 Harry Felton

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

--[[
    The main method of packaging custom projects that use Titanium.

    Call with --help/-h to display help
]]

local lfs, explore, addFromExplore, showHelp = type( fs ) ~= "table" and require "lfs"

--[[ Constants ]]--
local SETTINGS, FLAGS = {
    EXTRACT = {
        TARGETS = {},
        EXCLUDE = {},
        ALLOW_OVERRIDE = true
    },
    TITANIUM = {
        INSTALL = false,
        DISABLE_CHECK = false,
        VERSION = "latest",
        MANAGER_PATH = "/tpm",
        MINIFY = false,
        SILENT = false
    },
    SOURCE = {
        CLASSES = {},
        EXCLUDE = {},
        LOCATION = "src",
        PRE = false,
        POST = false
    },
    VFS = {
        ENABLE = true,
        EXPOSE_GLOBAL = false,
        PRESERVE_PROXY = false,
        ALLOW_RAW_FS_ACCESS = false,
        ALLOW_FS_REDIRECTION = false,
        EXCLUDE = {}
    },

    GLOBAL_EXCLUDE = {
        [".DS_Store"] = true
    },

    PICKLE_LOCATION = "bin/Pickle.lua",

    MINIFY_LOCATION = "bin/Minify.lua",
    MINIFY_SOURCE = false,

    INIT_FILE = false,

    OUTPUT_LOCATION = "titanium-project.tpkg"
}

FLAGS = {
    -- Source flags
    {"source", "s", function( path ) SETTINGS.SOURCE.LOCATION = path end, true, "Defines the source folder for your project. Files not set as a class file or extractable (see below) will be accessible via virtual file system"},
    {"class-source", "cs", function( path ) addFromExplore( path, SETTINGS.SOURCE.CLASSES ) end, true, "Files inside the path given will be set as a class file and will be executed and the class created will be compiled"},
    {"extract", "e", function( path ) addFromExplore( path, SETTINGS.EXTRACT.TARGETS ) end, true, "Files inside the path given will be extracted from the package when it's executed"},
    {"output", "o", function( location ) SETTINGS.OUTPUT_LOCATION = location end, true, "The output path of the package"},
    {"init", "i", function( path ) SETTINGS.INIT_FILE = path end, true, "This file will be run when the package is executed"},
    {"minify", "m", function() SETTINGS.MINIFY_SOURCE = true end, false, "Files ending with the `.ti` or `.lua` extension will be minified"},
    {"pre-init", false, function( path ) SETTINGS.SOURCE.PRE = path end, true, "This file will be executed just before loading Titanium. Therefore, this file can used to load Titanium instead of using built-in features"},
    {"titanium-init", false, function( path ) SETTINGS.SOURCE.POST = path end, true, "This file will be executed just after loading Titanium, and consequently just before loading custom classes. This provides the oppourtunity to load custom classes/packages before loading this packages classes (ie: dependencies)"},

    -- Path Exclusion
    {"exclude-class-source", "exclude-cs", function( path ) addFromExplore( path, SETTINGS.SOURCE.EXCLUDE ) end, true, "Files inside this path will not be loaded as a class file"},
    {"exclude-extract", false, function( path ) addFromExplore( path, SETTINGS.EXTRACT.EXCLUDE ) end, true, "Files inside this path will not be extracted"},
    {"exclude-vfs", false, function( path ) addFromExplore( path, SETTINGS.VFS.EXCLUDE ) end, true, "Files inside this path will not be available via the virtual file system"},
    {"exclude", false, function( path ) addFromExplore( path, SETTINGS.GLOBAL_EXCLUDE ) end, true, "Files inside this path will not be processed"},
    {"block-extract-override", false, function() SETTINGS.EXTRACT.ALLOW_OVERRIDE = false end, false, "Disallows the package to be extracted to a certain path at execution time"},

    -- Titanium flags
    {"titanium", "ti", function() SETTINGS.TITANIUM.INSTALL = true end, false, "Automatically downloads the latest version of Titanium via TPM. Version can be set using --titanium-version"},
    {"titanium-version", false, function( tag ) SETTINGS.TITANIUM.VERSION = tag end, true, "When installing (--titanium), this release will be downloaded rather than the latest release"},
    {"titanium-manager-path", false, function( path ) SETTINGS.TITANIUM.MANAGER_PATH = path end, true, "This path will be used to store the Titanium Package Manager (TPM). Defaults to '/tpm'"},
    {"titanium-minify", false, function() SETTINGS.TITANIUM.MINIFY = true end, false, "Minified Titanium builds will be downloaded if available for the release targeted"},
    {"titanium-silent", false, function() SETTINGS.TITANIUM.SILENT = true end, false, "Silently installs Titanium, hiding all output from TPM"},
    {"titanium-disable-check", "tid", function() SETTINGS.TITANIUM.DISABLE_CHECK = true end, false, "Supresses the error that will occur when packaging class files without -ti. Allows Titanium to be loaded externally"},

    -- VFS Flags
    {"vfs-disable", false, function() SETTINGS.VFS.ENABLE = false end, false, "Disables the virtual file system"},
    {"vfs-expose-global", false, function() SETTINGS.VFS.EXPOSE_GLOBAL = true end, false, "The package will allow setting in the raw environment (the environment the package was called in)"},
    {"vfs-preserve-proxy", false, function() SETTINGS.VFS.PRESERVE_PROXY = true end, false, "If this package is run inside another Titanium package, the sandbox environment of that package will be used - instead of using the other packages raw environment"},
    {"vfs-allow-raw-fs-access", false, function() SETTINGS.VFS.ALLOW_RAW_FS_ACCESS = true end, false, "Allows access of the raw FS from inside the package via TI_VFS_RAW. Without this flag, the VFS will be returned instead"},
    {"vfs-allow-fs-redirection", false, function() SETTINGS.VFS.ALLOW_FS_REDIRECTION = true end, false, "Exposes the setVFSFallback function, which can be used to set the file system the VFS will use as it's fallback (defaults to the raw FS). If true is NOT passed as the second argument, no further redirections can be set, blocking further use of the function"},

    -- Advanced flags
    {"pickle-source", false, function( path ) SETTINGS.PICKLE_LOCATION = path end, true, "The path given will be executed when the builder is run outside of ComputerCraft and will be used to serialize tables"},
    {"minify-source", false, function( path ) SETTINGS.MINIFY_LOCATION = path end, true, "The path given will be executed when the builder is run with minify enabled. This file will be used to minify Lua source code"},

    -- Help flag
    {"help", "h", function()
        print( "Titanium packager help\n" .. ("="):rep( 22 ) .. "\n" )
        local isCC = type( textutils ) == "table" and type( term ) == "table"
        local isColour = isCC and term.isColour and ( type( term.isColour ) ~= "function" or ( type( term.isColour ) == "function" and term.isColour() ) )

        local function colPrint( col, text ) term.setTextColour( col ); write( text ) end

        showHelp = true
        for i = 1, #FLAGS do
            local f = FLAGS[ i ]

            if isColour then
                colPrint( colours.orange, ("--%s"):format( f[ 1 ] ) )
                if f[ 2 ] then colPrint( colours.blue, "(-"..f[ 2 ]..")" ) end
                colPrint( colours.white, ": " .. f[ 5 ] .. "\n\n" )
            else
                print( ("--%s%s: %s"):format( f[ 1 ], f[ 2 ] and "(-"..f[ 2 ]..")" or "", f[ 5 ] ) .. "\n" )
            end

            if isCC then
                local x, y = term.getCursorPos()

                term.setCursorPos( 1, select( 2, term.getSize() ) )
                term.write "Any key to continue (q to exit)"
                while true do
                    if select( 2, os.pullEvent "key" ) == keys.q then sleep() return end
                    break
                end

                term.clearLine()
                term.setCursorPos( x, y )
            end
        end
    end, false, "Show this help menu"}
}

--[[ Helper Functions ]]--
local function isDir( path )
    if type( fs ) == "table" then
        return fs.isDir( path )
    else
        local attr, err = lfs.attributes( path, "mode" )
        if not attr and err then
            error("Failed to fetch attributes of path '"..tostring( path ).."': "..tostring( err ))
        end

        return attr == "directory"
    end
end

local function isFile( path )
    if type( fs ) == "table" then
        return fs.exists( path ) and not fs.isDir( path )
    else
        local attr, err = lfs.attributes( path, "mode" )
        if not attr and err then
            error("Failed to fetch attributes of path '"..tostring( path ).."': "..tostring( err ))
        end

        return attr == "file"
    end
end

function explore( path, results )
    local results = results or {}

    if isDir( path ) then
        if type( fs ) == "table" then
            for _, file in pairs( fs.list( path ) ) do
                if file ~= ".DS_Store" then
                    local p = path .. "/" .. file
                    if isDir( p ) then
                        results = explore( p, results )
                    else
                        results[ #results + 1 ] = p
                    end
                end
            end
        else
            for file in lfs.dir( path ) do
                if file ~= "." and file ~= ".." and file ~= ".DS_Store" then
                    local p = path .. "/" .. file

                    if lfs.attributes( p, "mode" ) == "directory" then
                        results = explore( p, results )
                    elseif lfs.attributes( p, "mode" ) == "file" then
                        results[ #results + 1 ] = p
                    end
                end
            end
        end
    elseif isFile( path ) then results[ #results + 1 ] = path
    else return error("Path '"..tostring( path ).."' cannot be explored. Doesn't exist.") end

    return results
end

function addFromExplore( path, tbl )
    local r = explore( path )
    for i = 1, #r do tbl[ r[ i ] ] = true end
end

local preprocessTargets = {"class", "extends", "alias", "mixin"}
local function preprocess( text )
    local keyword
    for i = 1, #preprocessTargets do
        keyword = preprocessTargets[ i ]

        for value in text:gmatch( keyword .. " ([_%a][_%w]*)%s" ) do
            text = text:gsub( keyword .. " " .. value, keyword.." \""..value.."\"" )
        end
    end

    for name in text:gmatch( "abstract class (\".[^%s]+\")" ) do
        text = text:gsub( "abstract class "..name, "class "..name.." abstract()" )
    end

    return text
end

local function getFileContents( path, allowMinify, allowPreprocess )
    if isFile( path ) then
        local file, err = io.open( path )
        if not file or err then
            return error("Failed to fetch file contents of '"..path.."': "..tostring( err ))
        end

        local cnt = file:read("*a")
        file:close()

        cnt = allowPreprocess and preprocess( cnt ) or cnt
        if allowMinify and SETTINGS.MINIFY_SOURCE then
            if type( _G.Minify ) ~= "function" then dofile( SETTINGS.MINIFY_LOCATION ) end

            local ok, cnt = Minify( cnt )
            if not ok and cnt then error( "Failed to minify target '"..tostring( path ).."': "..tostring( cnt ) ) end

            return cnt
        end

        return cnt
    else
        return error("Cannot get file contents of path '"..tostring( path ).."'. Is directory.")
    end
end

local function serialise( target )
    if type( textutils ) == "table" then
        return textutils.serialise( target )
    else
        return pickle( target )
    end
end

local function getName( path )
    if fs and fs.getName then
        return fs.getName( path )
    end

    return path:match ".-([^/\\]-[^%.]+)$"
end

--[[ Settings Initialisation ]]--

local function checkFlags( property, double, singleton, value )
    for f = 1, #FLAGS do
        flag = FLAGS[ f ]
        if ( ( singleton and not flag[ 4 ] ) or ( not singleton and flag[ 4 ] ) ) and ( ( double and flag[ 1 ] == property ) or ( not double and flag[ 2 ] == property ) ) then
            flag[ 3 ]( value )
            return true
        end
    end
end

local args = { ... }
for i = 1, #args do
    local double, property, value = args[ i ]:match "^(%-?%-)([%w%-]+)%=(.+)" --Format: -(-)property(-)name=value
    if double and property and value then
        if not checkFlags( property, double == "--", false, value ) then
            error("Argument invalid. Argument accepting flag for type '"..args[ i ].."' not found.")
        end
    else
        local double, property = args[ i ]:match "^(%-?%-)([%w%-]+)$"
        if double and property then
            if not checkFlags( property, double == "--", true, value ) then
                error("Argument invalid. Argument rejecting flag for type '"..args[ i ].."' not found.")
            end
        else
            error("Argument format invalid ("..tostring( args[ i ] ).."). Should be format '-(-)property=value'")
        end
    end
end

if showHelp then return end

if SETTINGS.TITANIUM.VERSION ~= "latest" and SETTINGS.TITANIUM.UPDATE_CHECK then
    printError "Warning: You have specified a version of Titanium to install (--titanium-version), but have also told us to update Titanium to the most recent version (--titanium-update-check)"
end

--[[ Main ]]--
local GLOBAL_EXCLUDE, EXTRACT_EXCLUDE, CLASS_EXCLUDE, VFS_EXCLUDE = SETTINGS.GLOBAL_EXCLUDE, SETTINGS.EXTRACT.EXCLUDE, SETTINGS.SOURCE.EXCLUDE, SETTINGS.VFS.EXCLUDE
local vfs_assets, vfs_dirs, extract_assets, class_assets = {}, {}, {}, {}
for file in pairs( SETTINGS.EXTRACT.TARGETS ) do
    if not ( GLOBAL_EXCLUDE[ file ] or EXTRACT_EXCLUDE[ file ] ) then
        extract_assets[ file ] = getFileContents( file, file:find("%.lua$") or file:find("%.ti$") )
    end
end

for file in pairs( SETTINGS.SOURCE.CLASSES ) do
    if not ( GLOBAL_EXCLUDE[ file ] or CLASS_EXCLUDE[ file ] ) then
        class_assets[ getName( file ) ] = getFileContents( file, true, true )
    end
end

do
    local r, rI = explore( SETTINGS.SOURCE.LOCATION )
    for i = 1, #r do
        rI = r[ i ]
        if not ( class_assets[ getName( rI ) ] or extract_assets[ rI ] ) and not ( GLOBAL_EXCLUDE[ rI ] or VFS_EXCLUDE[ rI ] ) then
            vfs_assets[ rI:sub(("compiled/"):len()+1, #rI) ] = getFileContents( rI, rI:find("%.lua$") or rI:find("%.ti$") )
        end
    end
end

for path in pairs( vfs_assets ) do
    while path do
        path = path:match "^(.+)/"
        if not path then break end

        vfs_dirs[ path ] = true
    end
end

if type( textutils ) ~= "table" then
    dofile( SETTINGS.PICKLE_LOCATION )
end

--[[ Output ]]--
local output = [=[
--[[
    Built using Titanium Packager (Harry Felton - hbomb79)
]]

local exportDirectory = ]=] .. ( SETTINGS.EXTRACT.ALLOW_OVERRIDE and 'select( 1, ... ) or ""' or '""' ) .. "\n"

if next( class_assets ) then
    if not SETTINGS.TITANIUM.DISABLE_CHECK and not SETTINGS.TITANIUM.INSTALL then
        error "Failed to compile project. When class source is present, The Titanium module must be set to automatically install. Use flag --titanium to set the install path, or --titanium-disable-check to disable this check"
    end

    output = output .. "local classSource = " .. serialise( class_assets ).."\n"
end

local useVFS = SETTINGS.VFS.ENABLE and next( vfs_assets )
if useVFS then
    output = output .. "local vfsAssets = " .. serialise( vfs_assets ) .. [[
local env = type( getfenv ) == "function" and getfenv() or _ENV or _G
]] .. ( SETTINGS.VFS.PRESERVE_PROXY and "" or "if env.TI_VFS_RAW then env = env.TI_VFS_RAW end" ) .. [[

local fallbackFS = env.fs
local RAW = setmetatable({
    fs = ]]..( SETTINGS.VFS.ALLOW_RAW_FS_ACCESS and "fallbackFS" or "setmetatable( {}, { __index = _G[\"fs\"] })" )..[[,
    os = setmetatable( {}, { __index = _G["os"] } )
}, { __index = env })

local VFS = ]]..( SETTINGS.VFS.ALLOW_RAW_FS_ACCESS and "setmetatable( {}, { __index = RAW.fs } )" or "RAW[\"fs\"]" )..[[

local VFS_ENV = setmetatable({},{__index = function( _, key )
    if key == "TI_VFS_RAW" then return RAW ]]..( SETTINGS.VFS.ALLOW_RAW_FS_ACCESS and "elseif key == \"fs\" then return VFS end" or "end" )..[[

    return RAW[ key ]
end})

VFS_ENV._G = ]]..( SETTINGS.VFS.EXPOSE_GLOBAL and "env\n" or "VFS_ENV\n" )..[[
VFS_ENV._ENV = ]]..( SETTINGS.VFS.EXPOSE_GLOBAL and "env\n" or "VFS_ENV\n" )..[[

local VFS_DIRS = ]] .. serialise( vfs_dirs ) .. [[

local matches = { ["^"] = "%^", ["$"] = "%$", ["("] = "%(", [")"] = "%)", ["%"] = "%%", ["*"] = "[^/]*", ["."] = "%.", ["["] = "%[", ["]"] = "%]", ["+"] = "%+", ["-"] = "%-" }

]] .. ( SETTINGS.VFS.ALLOW_FS_REDIRECTION and [[
local redirected
function VFS_ENV.setVFSFallback( tblFs, allowFurtherRedirect )
    if redirected then
        return error "VFS fallback already redirected"
    end
    redirected = not allowFurtherRedirect

    if type( tblFs ) ~= "table" then
        return error("Failed to set VFS fallback. FS given '"..tostring( tblFs ).."' is invalid, table expected")
    end

    fallbackFS = tblFs
end
]] or "") .. [[

function VFS_ENV.load(src, name, mode, env)
    return load( src, name or '(load)', mode, env or VFS_ENV )
end

function VFS_ENV.loadstring(src, name)
    return VFS_ENV.load( src, name, 't', VFS_ENV )
end

function VFS_ENV.loadfile(file, env)
    local _ENV = VFS_ENV
    local h = fs.open( file, "r" )
    if h then
        local fn, e = load(h.readAll(), fs.getName(file), 't', env or VFS_ENV)
        h.close()
        return fn, e
    end

    return nil, 'File not found'
end
if type( setfenv ) == "function" then setfenv( VFS_ENV.loadfile, VFS_ENV ) end

function VFS_ENV.os.run( _tEnv, _sPath, ... )
    local _ENV = VFS_ENV
    local tArgs, tEnv = { ... }, _tEnv

    setmetatable( tEnv, { __index = VFS_ENV } )
    local fnFile, err = loadfile( _sPath, tEnv )
    if fnFile then
        local ok, err = pcall( function()
            fnFile( table.unpack( tArgs ) )
        end )
        if not ok then
            if err and err ~= "" then
                printError( err )
            end
            return false
        end
        return true
    end
    if err and err ~= "" then
        printError( err )
    end
    return false
end

local tAPIsLoading = {}
function VFS_ENV.os.loadAPI( _sPath )
    local _ENV, sName = VFS_ENV, fs.getName( _sPath )
    if tAPIsLoading[sName] == true then
        printError( "API "..sName.." is already being loaded" )
        return false
    end
    tAPIsLoading[sName] = true

    local tEnv = setmetatable( {}, { __index = VFS_ENV } )
    local fnAPI, err = loadfile( _sPath, tEnv )
    if fnAPI then
        local ok, err = pcall( fnAPI )
        if not ok then
            printError( err )
            tAPIsLoading[sName] = nil
            return false
        end
    else
        printError( err )
        tAPIsLoading[sName] = nil
        return false
    end

    local tAPI = {}
    for k,v in pairs( tEnv ) do if k ~= "_ENV" then tAPI[k] =  v end end

    VFS_ENV[sName], tAPIsLoading[sName] = tAPI, nil
    return true
end

VFS_ENV.os.loadAPI "/rom/apis/io"
function VFS_ENV.dofile(file)
    local _ENV = VFS_ENV
    local fn, e = loadfile(file, VFS_ENV)

    if fn then return fn()
    else error(e, 2) end
end
if type( setfenv ) == "function" then setfenv( VFS_ENV.dofile, VFS_ENV ) end

function VFS.open( path, mode )
    path = fs.combine( "", path )
    if vfsAssets[ path ] then
        if mode == "w" or mode == "wb" or mode == "a" or mode == "ab" then
            return error("Cannot open file in mode '"..tostring( mode ).."'. File is inside of Titanium VFS and is read only")
        end

        local content, handle = vfsAssets[ path ], {}
        if mode == "rb" then
            handle.read = function()
                if #content == 0 then return end
                local b = content:sub( 1, 1 ):byte()

                content = content:sub( 2 )
                return b
            end
        end

        handle.readLine = function()
            if #content == 0 then return end

            local line, rest = content:match "^([^\n\r]*)[\n\r](.*)$"

            content = rest or ""
            return line or content
        end

        handle.readAll = function()
            if #content == 0 then return end

            local c = content
            content = ""

            return c
        end

        handle.close = function() content = "" end

        return handle
    else return fallbackFS.open( fs.combine( exportDirectory, path ), mode ) end
end

function VFS.isReadOnly( path )
    path = fs.combine( "", path )
    if vfsAssets[ path ] then return true end

    return fallbackFS.isReadOnly( fs.combine( exportDirectory, path ) )
end

function VFS.getSize( path )
    return vfsAssets[ path ] and #vfsAssets[ path ] or fallbackFS.getSize( path )
end

function VFS.list( target )
    target = fs.combine( "", target )
    local list = fallbackFS.isDir( target ) and fallbackFS.list( target ) or {}

    local function addResult( res )
        for i = 1, #list do if list[ i ] == res then return end end
        list[ #list + 1 ] = res
    end

    if VFS_DIRS[ target ] then
        for path in pairs( vfsAssets ) do
            if path:match( ("^%s/"):format( target ) ) then
                addResult( path:match( ("^%s/([^/]+)"):format( target ) ) )
            end
        end
    elseif target == "" then
        for path in pairs( vfsAssets ) do addResult( path:match "^([^/]+)" ) end
    end

    return list
end

function VFS.find( target )
    target = fs.combine( "", target )
    local list = fallbackFS.find( target ) or {}

    target = ("^(%s)(.*)$"):format( target:gsub( ".", matches ) )
    for path in pairs( vfsAssets ) do
        local res, tail = path:match( target )
        if res and ( tail == "" or tail:sub( 1, 1 ) == "/" ) then
            local isMatch
            for i = 1, #list do if list[ i ] == res then isMatch = true; break end end

            if not isMatch then list[ #list + 1 ] = res end
        end
    end

    return list
end

function VFS.isDir( path )
    path = fs.combine( "", path )
    return VFS_DIRS[ path ] or fallbackFS.isDir( fs.combine( exportDirectory, path ) )
end

function VFS.exists( path )
    path = fs.combine( "", path )
    if vfsAssets[ path ] or VFS_DIRS[ path ] then return true end

    return fallbackFS.exists( fs.combine( exportDirectory, path ) )
end
]]
end

if next( extract_assets ) then
    output = output .. "local extractAssets = "..serialise( extract_assets ) .. [[

for file, content in pairs( extractAssets ) do
    local path = fs.combine( exportDirectory, file )
    if not fs.exists( path ) then
        local h = fs.open( path, "w" )
        h.write( content )
        h.close()
    end
end
]]
end

function runFile( path )
    if useVFS and vfs_assets[ path ] then
        output = output .. [[

local fn, err = VFS_ENV.loadfile "]]..path..[["
if fn then fn()
else return error( "Failed to run file from bundle vfs: "..tostring( err ) ) end
]]
    elseif extract_assets[ path ] then
        if useVFS then
            output = output .. "VFS_ENV.dofile '"..path.."'\n"
        else
            output = output .. "dofile( fs.combine( exportDirectory, '"..path.."' ) )"
        end
    else
        error("File '"..path.."' cannot be run. Not found inside application bundle. " .. ( not SETTINGS.VFS.ENABLE and not next( extract_assets ) and "This maybe caused by the VFS and extract being disabled. Re-enable the VFS or extract the files needed using --extract" or "" ))
    end
end

if SETTINGS.SOURCE.PRE then
    runFile( SETTINGS.SOURCE.PRE )
end

local titanium = SETTINGS.TITANIUM.INSTALL
if titanium then
    local VERSION = SETTINGS.TITANIUM.VERSION
    output = output .. [[
local managerPath = fs.combine( exportDirectory, "]] .. SETTINGS.TITANIUM.MANAGER_PATH .. [[")

if not fs.exists( managerPath ) then
    if not http then return error "HTTP API required" end
    local h = http.get "https://gitlab.com/hbomb79/Titanium-Package-Manager/raw/master/tpm"
    if not h then return error "Failed to download TPM" end

    local f = fs.open( managerPath, "w" )
    f.write( h.readAll() )
    h.close()
    f.close()
end

local ok, err = loadfile( managerPath )
if not ok then return error("Failed to load TPM '"..tostring( err ).."'") end

ok "fetch"
ok( "--disposable", "--depend", shell.getRunningProgram(), "install", "Titanium:]]..VERSION..[["]] .. ( SETTINGS.TITANIUM.SILENT and ', "--silent"' or "" ) .. [[ )
]]
    if VERSION == "latest" then
        output = output .. [[local FAILURE = "Failed to execute Titanium package. Latest Titanium version cannot be found %s (/.tpm/cache)"
print "Determining latest version of Titanium from TPM cache"
if not fs.exists("/.tpm/cache") then
    return error( FAILURE:format "because TPM cache is missing" )
end

local cacheHandle = fs.open("/.tpm/cache", "r")
local cache = textutils.unserialise( cacheHandle.readAll() )
cacheHandle.close()

if not cache then
    return error( FAILURE:format "because TPM cache is malformed" )
elseif not cache.Titanium then
    return error( FAILURE:format "because TPM cache missing Titanium version information" )
end
]]
    end

    output = output .. "if not VFS_ENV.Titanium then VFS_ENV.dofile( \"/.tpm/packages/Titanium/"..( VERSION == "latest" and "\"..cache.Titanium[1]" or VERSION .. "\"" ).." ) end\n"
end

output = output .. [[
local ti = VFS_ENV.Titanium
if not ti then
    return error "Failed to execute Titanium package. Titanium is not loaded. Please load Titanium before executing this package, or repackage this application using the --titanium flag."
end
]]

if SETTINGS.SOURCE.POST then
    runFile( SETTINGS.SOURCE.POST )
end

if next( class_assets ) then
    output = output .. [[

local loaded = {}
local function loadClass( name, source )
    if not source then return error( "Failed to load class '"..name.."'. No source found within class assets" )
    elseif loaded[ name ] then return end

    local className = name:gsub( "%..*", "" )
    if not ti.getClass( className ) then
        local output, err = ( VFS_ENV or _G ).loadstring( source, name )
        if not output or err then return error( "Failed to load Lua chunk. File '"..name.."' has a syntax error: "..tostring( err ), 0 ) end

        local ok, err = pcall( output )
        if not ok or err then return error( "Failed to execute Lua chunk. File '"..name.."' crashed: "..tostring( err ), 0 ) end

        local class = ti.getClass( className )
        if class then
            if not class:isCompiled() then class:compile() end
            loaded[ name ] = true
        else return error( "File '"..name.."' failed to create class '"..className.."'" ) end
    else
        print( "WARNING: Class " .. className .. " failed to load because a class with the same name already exists." )
    end
end

ti.setClassLoader(function( c )
    local name = classSource[ c .. ".lua" ] and c .. ".lua" or c .. ".ti"
    loadClass( name, classSource[ name ] )
end)
for name, source in pairs( classSource ) do
    loadClass( name, source )
end
]]
end

local init = SETTINGS.INIT_FILE
if init then
    runFile( init )
end

local handle = io.open( SETTINGS.OUTPUT_LOCATION, "w" )
if SETTINGS.MINIFY_SOURCE then
    local ok, cnt = Minify( output )
    if not ok and cnt then error( "Failed to minify complete build file: " .. cnt ) end

    handle:write( cnt )
else handle:write( output ) end

handle:close()
