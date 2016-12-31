mute = {}

mute.shadow_mute_list = {}
mute.ignore_lists = {}

local ignore_lists_path = minetest.get_worldpath() .. "/mute/"
local shadow_mute_path = minetest.get_worldpath() .. "/shadow_mute"

minetest.mkdir(ignore_lists_path) -- Make sure the directory exist

local shadow_mute = mute.shadow_mute_list
local ignore = mute.ignore_lists

core.register_privilege("mute", "Can mute players")

local function send_message(sender, target, message)
	if target == sender then
		minetest.chat_send_player(target, message)
		return
	end
	
	for _,muted in ipairs(shadow_mute) do
		-- Check if the player is muted by an admin/mod
		if muted == sender then
			return
		end
	end

	for _,muted_player in ipairs(ignore[target]) do
	-- Check if the player is ignored by the player
		if muted_player == sender then
			return
		end
	end
	
	minetest.chat_send_player(target, message)
end

mute.send_message = send_message

local function broadcast_message(sender, message)
	for _,player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		send_message(sender, name, message)
	end
end

mute.broadcast_message = broadcast_message

local function load_list(path)
	local f = io.open(path, "r")
	if f == nil then
		return {}
	else
		local output = minetest.deserialize(f:read("*all"))
		if output == nil then
			minetest.log("error", "Failed to load " .. path .. " file is corrupted")
			minetest.log("error", "Dumping contents to log file")
			minetest.debug(f:read("*all"))
			output = {}
		end
		
		f:close()
		return output
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	ignore[name] = load_list(ignore_lists_path .. name)
end)

local function save_ignore_list(player)
	local name = player:get_player_name()
	if #ignore[name] == 0 then return end
	local f = io.open(ignore_lists_path .. name, "w")
	f:write(minetest.serialize(ignore[name]))
	f:close()
end

minetest.register_on_leaveplayer(save_ignore_list)

minetest.register_on_shutdown(function()
	for _,player in ipairs(minetest.get_connected_players()) do
		save_ignore_list(player)
	end
	local f = io.open(shadow_mute_path, "w")
	f:write(minetest.serialize(shadow_mute))
	f:close()
end)

minetest.register_on_chat_message(function(username, message)
	for _,player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		if name ~= username then
			send_message(username, name, "<" .. username .. "> " .. message)
		end
	end
	return true
end)

if minetest.chatcommands["me"] then
	minetest.chatcommands["me"].func = function(name, param)
		broadcast_message(name, "* " .. name .. " " .. param)
	end
end

if minetest.chatcommands["msg"] then
	minetest.chatcommands["msg"].func = function(name, param)
		local sendto, message = param:match("^(%S+)%s(.+)$")
		if not sendto then
			return false, "Invalid usage, see /help msg."
		end
		if not minetest.get_player_by_name(sendto) then
			return false, "The player " .. sendto
					.. " is not online."
		end
		minetest.log("action", "PM from " .. name .. " to " .. sendto
				.. ": " .. message)
		send_message(sendto, name, "PM from " .. name .. ": "
				.. message)
		return true, "Message sent."
	end
end

minetest.register_chatcommand("ignore", {
	params = "<player name>",
	description = "Stop messages from this player from appearing in your chat",
	func = function(name, param)
		table.insert(ignore[name],param)
		return true, "Ignored player " .. param
	end,
})

minetest.register_chatcommand("unignore", {
	params = "<player name>",
	description = "Unignore a player",
	func = function(name, param)
		local t = ignore[name]
		for i=#t,1,-1 do
			local v = t[i]
			if v == param then
				table.remove(t, i)
			end
		end 
		return true, "Unignored player " .. param
	end,
})

minetest.register_chatcommand("mute", {
	params = "<player name>",
	description = "Stop a players messages from being displayed",
	privs = {mute = true},
	func = function(name, param)
		table.insert(shadow_mute, param)
		return true, "Muted player " .. param
	end,
})

minetest.register_chatcommand("unmute", {
	params = "<player name>",
	description = "Undo /mute",
	privs = {mute = true},
	func = function(name, param)
		for i=#shadow_mute,1,-1 do
			local v = shadow_mute[i]
			print(i, v)
			if v == param then
				table.remove(shadow_mute, i)
			end
		end 
		return true, "Unmuted player " .. param
	end,
})

shadow_mute = load_list(shadow_mute_path)
