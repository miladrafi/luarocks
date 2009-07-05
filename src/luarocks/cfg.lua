
local rawset, next, table, pairs, print, require, io, os, setmetatable, pcall =
      rawset, next, table, pairs, print, require, io, os, setmetatable, pcall

--- Configuration for LuaRocks.
-- Tries to load the user's configuration file and
-- defines defaults for unset values. See the
-- <a href="http://luarocks.org/en/Config_file_format">config
-- file format documentation</a> for details.
module("luarocks.cfg")

program_version = "1.1"
user_agent = "LuaRocks/"..program_version

local persist = require("luarocks.persist")

local popen_ok, popen_result = pcall(io.popen, "")
if popen_ok then
   if popen_result then
      popen_result:close()
   end
else
   print("Your version of Lua does not support io.popen,")
   print("which is required by LuaRocks. Please check your Lua installation.")
   os.exit(1)
end

-- System detection:

local detected = {}
local system,proc

-- A proper installation of LuaRocks will hardcode the system
-- and proc values with LUAROCKS_UNAME_S and LUAROCKS_UNAME_M,
-- so that this detection does not run every time. When it is
-- performed, we use the Unix way to identify the system,
-- even on Windows (assuming UnxUtils or Cygwin).
system = LUAROCKS_UNAME_S or io.popen("uname -s"):read("*l")
proc = LUAROCKS_UNAME_M or io.popen("uname -m"):read("*l")
if proc:match("i[%d]86") then
   proc = "x86"
elseif proc:match("amd64") or proc:match("x86_64") then
   proc = "x86_64"
elseif proc:match("Power Macintosh") then
   proc = "powerpc"
end

if system == "FreeBSD" then
   detected.unix = true
   detected.freebsd = true
elseif system == "Darwin" then
   detected.unix = true
   detected.macosx = true
elseif system == "Linux" then
   detected.unix = true
   detected.linux = true
elseif system and system:match("^CYGWIN") then
   detected.unix = true
   detected.cygwin = true
elseif system and system:match("^Windows") then
   detected.windows = true
else
   detected.unix = true
   -- Fall back to Unix in unknown systems.
end

-- Path configuration:

local sys_config_file, home_config_file, home_tree
if detected.windows then
   home = os.getenv("APPDATA") or "c:"
   sys_config_file = "c:/luarocks/config.lua"
   home_config_file = home.."/luarocks/config.lua"
   home_tree = home.."/luarocks/"
else
   home = os.getenv("HOME") or ""
   sys_config_file = "/etc/luarocks/config.lua"
   home_config_file = home.."/.luarocks/config.lua"
   home_tree = home.."/.luarocks/"
end

variables = {}
rocks_trees = {}

persist.load_into_table(LUAROCKS_SYSCONFIG or sys_config_file, _M)

if not LUAROCKS_FORCE_CONFIG then
   home_config_file = os.getenv("LUAROCKS_CONFIG") or home_config_file
   local home_overrides = persist.load_into_table(home_config_file, { home = home })
   if home_overrides then
      local util = require("luarocks.util")
      util.deep_merge(_M, home_overrides)
   end
end

if not next(rocks_trees) then
   if home_tree then
      table.insert(rocks_trees, home_tree)
   end
   if LUAROCKS_ROCKS_TREE then
      table.insert(rocks_trees, LUAROCKS_ROCKS_TREE)
   end
end

-- Configure defaults:

local root = LUAROCKS_ROCKS_TREE or home_tree
local defaults = {
   root_dir = root,
   rocks_dir = root.."/lib/luarocks/rocks",
   scripts_dir = root.."/bin/",
   lua_modules_dir = root.."/share/lua/5.1/",
   bin_modules_dir = root.."/lib/lua/5.1/",

   arch = "unknown",
   lib_extension = "unknown",
   obj_extension = "unknown",

   rocks_servers = {
      "http://luarocks.luaforge.net/rocks"
   },

   lua_extension = "lua",
   lua_interpreter = LUA_INTERPRETER or "lua",
   downloader = LUAROCKS_DOWNLOADER or "wget",
   md5checker = LUAROCKS_MD5CHECKER or "md5sum",

   variables = {},
   
   external_deps_subdirs = {
      bin = "bin",
      lib = "lib",
      include = "include"
   },
   runtime_external_deps_subdirs = {
      bin = "bin",
      lib = "lib",
      include = "include"
   },
}

if detected.windows then
   home_config_file = home_config_file:gsub("\\","/")
   defaults.arch = "win32-"..proc
   defaults.platforms = {"win32", "windows" }
   defaults.lib_extension = "dll"
   defaults.external_lib_extension = "dll"
   defaults.obj_extension = "obj"
   defaults.external_deps_dirs = { "c:/external/" }
   defaults.variables.LUA_BINDIR = LUA_BINDIR and LUA_BINDIR:gsub("\\", "/") or "c:/lua5.1/bin"
   defaults.variables.LUA_INCDIR = LUA_INCDIR and LUA_INCDIR:gsub("\\", "/") or "c:/lua5.1/include"
   defaults.variables.LUA_LIBDIR = LUA_LIBDIR and LUA_LIBDIR:gsub("\\", "/") or "c:/lua5.1/lib"
   defaults.cmake_generator = "MinGW Makefiles"
   defaults.make = "nmake" -- TODO: Split Windows flavors between mingw and msvc
   defaults.makefile = "Makefile.win"
   defaults.variables.CC = "cl"
   defaults.variables.LD = "link"
   defaults.variables.MT = "mt"
   defaults.variables.CFLAGS = "/MD /O2"
   defaults.variables.LIBFLAG = "/dll"
   defaults.external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      lib = { "?.lib", "?.dll" },
      include = { "?.h" }
   }
   defaults.runtime_external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      lib = { "?.dll" },
      include = { "?.h" }
   }
end

if detected.unix then
   defaults.lib_extension = "so"
   defaults.external_lib_extension = "so"
   defaults.obj_extension = "o"
   defaults.external_deps_dirs = { "/usr/local", "/usr" }
   defaults.variables.LUA_BINDIR = LUA_BINDIR or "/usr/local/bin"
   defaults.variables.LUA_INCDIR = LUA_INCDIR or "/usr/local/include"
   defaults.variables.LUA_LIBDIR = LUA_LIBDIR or "/usr/local/lib"
   defaults.variables.CFLAGS = "-O2"
   defaults.cmake_generator = "Unix Makefiles"
   defaults.make = "make"
   defaults.platforms = { "unix" }
   defaults.variables.CC = "cc"
   defaults.variables.LD = "ld"
   defaults.variables.LIBFLAG = "-shared"
   defaults.external_deps_patterns = {
      bin = { "?" },
      lib = { "lib?.a", "lib?.so" },
      include = { "?.h" }
   }
   defaults.runtime_external_deps_patterns = {
      bin = { "?" },
      lib = { "lib?.so" },
      include = { "?.h" }
   }
end

if detected.cygwin then
   defaults.lib_extension = "so" -- can be overridden in the config file for mingw builds
   defaults.arch = "cygwin-"..proc
   defaults.platforms = {"unix", "cygwin"}
   defaults.cmake_generator = "Unix Makefiles"
   defaults.variables.CC = "echo -llua | xargs gcc"
   defaults.variables.LD = "echo -llua | xargs gcc"
   defaults.variables.LIBFLAG = "-shared"
end

if detected.macosx then
   defaults.external_lib_extension = "dylib"
   defaults.arch = "macosx-"..proc
   defaults.platforms = {"unix", "macosx"}
   defaults.variables.CC = "export MACOSX_DEPLOYMENT_TARGET=10.3; gcc"
   defaults.variables.LD = "export MACOSX_DEPLOYMENT_TARGET=10.3; gcc"
   defaults.variables.LIBFLAG = "-bundle -undefined dynamic_lookup -all_load"
end

if detected.linux then
   defaults.arch = "linux-"..proc
   defaults.platforms = {"unix", "linux"}
   defaults.variables.CC = "gcc"
   defaults.variables.LD = "gcc"
   defaults.variables.LIBFLAG = "-shared"
end

if detected.freebsd then
   defaults.arch = "freebsd-"..proc
   defaults.make = "gmake"
   defaults.platforms = {"unix", "freebsd"}
   defaults.variables.CC = "gcc"
   defaults.variables.LD = "gcc"
   defaults.variables.LIBFLAG = "-shared"
end

if proc == "x86_64" and not defaults.variables.CFLAGS:match("-fPIC") then
   defaults.variables.CFLAGS = defaults.variables.CFLAGS.." -fPIC"
end

-- Expose some more values detected by LuaRocks for use by rockspec authors.
defaults.variables.LUA = defaults.lua_interpreter
defaults.variables.LIB_EXTENSION = defaults.lib_extension
defaults.variables.OBJ_EXTENSION = defaults.obj_extension
defaults.variables.LUAROCKS_PREFIX = LUAROCKS_PREFIX

-- Use defaults:

-- Populate values from 'defaults.variables' in 'variables' if they were not
-- already set by user.
if not _M.variables then
   _M.variables = {}
end
for k,v in pairs(defaults.variables) do
   if not _M.variables[k] then
      _M.variables[k] = v
   end
end

-- For values not set in the config file, use values from the 'defaults' table.
local cfg_mt = {
   __index = function(t, k)
      local default = defaults[k]
      if default then
         rawset(t, k, default)
      end
      return default
   end
}
setmetatable(_M, cfg_mt)
