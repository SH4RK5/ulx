local ulxBuildNumURL = ulx.release and "https://teamulysses.github.io/ulx/ulx.build" or
"https://raw.githubusercontent.com/TeamUlysses/ulx/master/ulx.build"
ULib.registerPlugin {
	Name              = "ULX",
	Version           = string.format("%.2f", ulx.version),
	IsRelease         = ulx.release,
	Author            = "Team Ulysses",
	URL               = "https://ulyssesmod.net",
	WorkshopID        = 557962280,
	BuildNumLocal     = tonumber(ULib.fileRead("ulx.build")),
	BuildNumRemoteURL = ulxBuildNumURL,
	--BuildNumRemoteReceivedCallback = nil
}

function ulx.getVersion() -- This function will be removed in the future
	return ULib.pluginVersionStr("ULX")
end

local ulxCommand = inheritsFrom(ULib.cmds.TranslateCommand)

function ulxCommand:logString(str)
	Msg("Warning: <ulx command>:logString() was called, this function is being phased out!\n")
end

function ulxCommand:oppositeLogString(str)
	Msg("Warning: <ulx command>:oppositeLogString() was called, this function is being phased out!\n")
end

function ulxCommand:help(str)
	self.helpStr = str
end

function ulxCommand:getUsage(ply)
	local str = self:superClass().getUsage(self, ply)

	if self.helpStr or self.say_cmd or self.opposite then
		str = str:Trim() .. " - "
		if self.helpStr then
			str = str .. self.helpStr
		end
		if self.helpStr and self.say_cmd then
			str = str .. " "
		end
		if self.say_cmd then
			str = str .. "(say: " .. self.say_cmd[1] .. ")"
		end
		if self.opposite and (self.helpStr or self.say_cmd) then
			str = str .. " "
		end
		if self.opposite then
			str = str .. "(opposite: " .. self.opposite .. ")"
		end
	end

	return str
end

ulx.cmdsByCategory = ulx.cmdsByCategory or {}
function ulx.command(category, command, fn, say_cmd, hide_say, nospace, unsafe)
	if type(say_cmd) == "string" then say_cmd = { say_cmd } end
	local obj = ulxCommand(command, fn, say_cmd, hide_say, nospace, unsafe)
	obj:addParam { type = ULib.cmds.CallingPlayerArg }
	ulx.cmdsByCategory[category] = ulx.cmdsByCategory[category] or {}
	for cat, cmds in pairs(ulx.cmdsByCategory) do
		for i = 1, #cmds do
			if cmds[i].cmd == command then
				table.remove(ulx.cmdsByCategory[cat], i)
				break
			end
		end
	end
	table.insert(ulx.cmdsByCategory[category], obj)
	obj.category = category
	obj.say_cmd = say_cmd
	obj.hide_say = hide_say
	return obj
end

local function cc_ulx(ply, command, argv)
	local argn = #argv

	if argn == 0 then
		ULib.console(ply, "No command entered. If you need help, please type \"ulx help\" in your console.")
	else
		-- TODO, need to make this cvar hack actual commands for sanity and autocomplete
		-- First, check if this is a cvar and they just want the value of the cvar
		local cvar = ulx.cvars[argv[1]:lower()]
		if cvar and not argv[2] then
			ULib.console(ply, "\"ulx " .. argv[1] .. "\" = \"" .. GetConVarString("ulx_" .. cvar.cvar) .. "\"")
			if cvar.help and cvar.help ~= "" then
				ULib.console(ply, cvar.help .. "\n  CVAR generated by ULX")
			else
				ULib.console(ply, "  CVAR generated by ULX")
			end
			return
		elseif cvar then -- Second, check if this is a cvar and they specified a value
			local args = table.concat(argv, " ", 2, argn)
			if ply:IsValid() then
				-- Workaround: gmod seems to choke on '%' when sending commands to players.
				-- But it's only the '%', or we'd use ULib.makePatternSafe instead of this.
				ply:ConCommand("ulx_" .. cvar.cvar .. " \"" .. args:gsub("(%%)", "%%%1") .. "\"")
			else
				cvar.obj:SetString(argv[2])
			end
			return
		end
		ULib.console(ply, "Invalid command entered. If you need help, please type \"ulx help\" in your console.")
	end
end
ULib.cmds.addCommand("ulx", cc_ulx)

function ulx.help(ply)
	ULib.console(ply, "ULX Help:")
	ULib.console(ply, "If a command can take multiple targets, it will usually let you use the keywords '*' for target")
	ULib.console(ply, "all, '^' to target yourself, '@' for target your picker, '$<userid>' to target by ID (steamid,")
	ULib.console(ply, "uniqueid, userid, ip), '#<group>' to target users in a specific group, and '%<group>' to target")
	ULib.console(ply, "users with access to the group (inheritance counts). IE, ulx slap #user slaps all players who are")
	ULib.console(ply, "in the default guest access group. Any of these keywords can be preceded by '!' to negate it.")
	ULib.console(ply, "EG, ulx slap !^ slaps everyone but you.")
	ULib.console(ply, "You can also separate multiple targets by commas. IE, ulx slap bob,jeff,henry.")
	ULib.console(ply, "All commands must be preceded by \"ulx \", ie \"ulx slap\"")
	ULib.console(ply, "\nCommand Help:\n")

	for category, cmds in pairs(ulx.cmdsByCategory) do
		local lines = {}
		for _, cmd in ipairs(cmds) do
			local tag = cmd.cmd
			if cmd.manual then tag = cmd.access_tag end
			if ULib.ucl.query(ply, tag) then
				local usage
				if not cmd.manual then
					usage = cmd:getUsage(ply)
				else
					usage = cmd.helpStr
				end
				table.insert(lines, string.format("\to %s %s", cmd.cmd, usage:Trim()))
			end
		end

		if #lines > 0 then
			table.sort(lines)
			ULib.console(ply, "\nCategory: " .. category)
			for _, line in ipairs(lines) do
				ULib.console(ply, line)
			end
			ULib.console(ply, "") -- New line
		end
	end


	ULib.console(ply, "\n-End of help\nULX version: " .. ULib.pluginVersionStr("ULX") .. "\n")
end

local help = ulx.command("Utility", "ulx help", ulx.help)
help:help("Shows this help.")
help:defaultAccess(ULib.ACCESS_ALL)

function ulx.dumpTable(t, indent, done)
	done = done or {}
	indent = indent or 0
	local str = ""

	for k, v in pairs(t) do
		str = str .. string.rep("\t", indent)

		if type(v) == "table" and not done[v] then
			done[v] = true
			str = str .. tostring(k) .. ":" .. "\n"
			str = str .. ulx.dumpTable(v, indent + 1, done)
		else
			str = str .. tostring(k) .. "\t=\t" .. tostring(v) .. "\n"
		end
	end

	return str
end

function ulx.uteamEnabled()
	return ULib.isSandbox() and GAMEMODE.Name ~= "DarkRP"
end
