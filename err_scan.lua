#!/usr/bin/env lua

-- optional log
local log_f = io.open("dump.log", "wa+")

---- Linux Utils ---------------------------------------------------------------

-- sprintf
local
function sprintf(fmt, ...)
	-- replace %S with "%s"
	local expanded_fmt = fmt:gsub("%%S", "\"%%s\"")

	return expanded_fmt:format(...)
end

-- printf
local
function printf(fmt, ...)
	local s = sprintf(fmt, ...)
	print(s)
	
	if (log_f)	then log_f:write(s.."\n") end
end

-- assertf	
local
function assertf(f, fmt, ...)
	if (f) then
		return
	end
	if (nil == fmt) then
		fmt = "<missing assertf() fmt>"
	end
	
	assert(f, sprintf(fmt, ...))
end

-- exec
local shell = {}
setmetatable(shell, {__index =
	function(t, func)
		-- print(("_lut %s()"):format(tostring(func)))
		local shell_fn = func.." "
		return	function (...)
			return os.execute(shell_fn..table.concat({...}," "))
		end
	end})

-- piped SINGLE-line res
local pshell = {}
setmetatable(pshell, {__index =
	function(t, func)
		-- print(("_lut %s()"):format(tostring(func)))
		local shell_fn = func.." "
		return	function (...)
			-- return shell_fn..table.concat({...}," ")
			return io.popen(shell_fn..table.concat({...}," ")):read("*l")
		end
	end})

-- piped MULTI-line res, returned as table
local tshell = {}
setmetatable(tshell, {__index =
	function(t, func)
		-- print(("_lut %s()"):format(tostring(func)))
		local shell_fn = func.." "
		return	function (...)
			local ln_t = {}
			io.popen(shell_fn..table.concat({...}," ")):read("*a"):gsub("([^\n]*)\n", function(ln) table.insert(ln_t, ln) end)
			return ln_t
		end
	end})

---- Main ----------------------------------------------------------------------

	local wd = os.getenv("PWD")
	
	local lua_dir 
	
	if (arg[1]) then
		lua_dir = pshell.readlink("-f", arg[1])
	else
		-- cd to "../../lua-5.2.2/" (chop last 2 subdirs)
		lua_dir = wd:gsub("[^/]+/[^/]+$", "lua-5.2.2")
	end
	
	assertf(shell.test("-d", lua_dir) == 0, "lua_dir %S not a dir", lua_dir)
	-- collapse double dir-seps
	local src_dir = (lua_dir .. "/src/"):gsub("//", "/")
	assertf(shell.test("-d", src_dir) == 0, "lua_src %S not a dir", src_dir)
	
	printf("Lua source dir %S\n", tostring(src_dir))
	
	-- get lua source files list
	local flist = tshell.ls(src_dir)
	assert(type(flist) == "table", "couldn't get table")
	
	printf("  found %d Lua source files", #flist)
	
	local luaL_error_tab = {}

	-- per lua source file
	for k, fn in ipairs(flist) do
		local fpath = src_dir..fn
		local f = io.open(fpath, "r")
		assertf(f, "couldn't read-open %S", fpath)
	
		local f_s = f:read("*a")
		
		local capt_list = {}
		
		-- find luaL_error() and luaG_runerror()
		for ind1, w, ind2 in f_s:gmatch("()(lua[LG]_[run]?error%b()%s*;)()") do
			table.insert(capt_list, {ind1 = ind1, ind2 = ind2, capt = w})
		end
		
		-- save any captures
		if (#capt_list > 0) then
			-- NO sort per char index (not needed with single regex?)
			-- table.sort(capt_list, function (e1, e2) return e1.ind1 < e2.ind1 end)
			luaL_error_tab[fn] = capt_list
		end
	end
	
	-- dump per-file hits
	local hits = 0
	
	for fn, loc_list in pairs(luaL_error_tab) do
		printf("\n%S", fn)

		for _, loc in ipairs(loc_list) do
			-- collapse whitespaces
			local capt = loc.capt:gsub("%s+", " ")
			
			printf("  [%5d:%5d] '%s'", loc.ind1, loc.ind2, capt)
			hits = hits + 1
		end
	end
	
	printf("\n %d total hits", hits)

	if (log_f ~= nil) then
		log_f:close()
	end
