-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

-- Add luarocks paths for AeroSpaceLua dependencies (Lua 5.4)
local USER = os.getenv("USER")
package.path = package.path
    .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    .. ";/opt/homebrew/lib/lua/5.4/?.lua;/opt/homebrew/lib/lua/5.4/?/init.lua"
    .. ";/Users/" .. USER .. "/.luarocks/share/lua/5.4/?.lua;/Users/" .. USER .. "/.luarocks/share/lua/5.4/?/init.lua"
package.cpath = package.cpath
    .. ";/opt/homebrew/lib/lua/5.4/?.so"
    .. ";/Users/" .. USER .. "/.luarocks/lib/lua/5.4/?.so"

os.execute("(cd helpers && make)")
