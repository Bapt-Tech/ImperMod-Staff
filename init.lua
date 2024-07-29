-- Register the "moderator" and "admin" privileges
minetest.register_privilege("moderator", {
    description = "Allows access to moderator commands",
    give_to_singleplayer = false,
})

minetest.register_privilege("admin", {
    description = "Allows access to all admin commands",
    give_to_singleplayer = false,
})

-- Table to track users in staff chat mode, muted players, and frozen players
local staff_chat_users = {}
local muted_players = {}
local frozen_players = {}
local admin_homes = {}

-- Command to toggle staff chat mode
minetest.register_chatcommand("staff_chat", {
    params = "",
    description = "Toggle staff chat mode",
    privs = {moderator=true, admin=true},
    func = function(name)
        if staff_chat_users[name] then
            staff_chat_users[name] = nil
            return true, "You have left the staff chat. You are now in the global chat."
        else
            staff_chat_users[name] = true
            return true, "You have joined the staff chat. Your messages will only be seen by other staff members."
        end
    end,
})

-- Override the chat message handling to support staff chat
minetest.register_on_chat_message(function(name, message)
    if staff_chat_users[name] then
        -- Send the message only to staff members
        for _, player in ipairs(minetest.get_connected_players()) do
            local pname = player:get_player_name()
            if minetest.check_player_privs(pname, {moderator=true}) or minetest.check_player_privs(pname, {admin=true}) then
                minetest.chat_send_player(pname, "[Staff Chat] <" .. name .. "> " .. message)
            end
        end
        -- Prevent the message from being sent to the global chat
        return true
    end
    -- Allow the message to be sent to the global chat if not in staff chat
    return false
end)

-- Command to enable spectator mode (invisibility only)
minetest.register_chatcommand("spectate", {
    params = "",
    description = "Enter spectator mode (invisible)",
    privs = {moderator=true, admin=true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            player:set_properties({pointable = false, visual_size = {x = 0, y = 0}})
            return true, "You are now invisible in spectator mode"
        else
            return false, "Failed to enter spectator mode"
        end
    end,
})

-- Command to exit spectator mode (visibility)
minetest.register_chatcommand("unspectate", {
    params = "",
    description = "Exit spectator mode",
    privs = {moderator=true, admin=true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            player:set_properties({pointable = true, visual_size = {x = 1, y = 1}})
            return true, "You have exited spectator mode"
        else
            return false, "Failed to exit spectator mode"
        end
    end,
})

-- Command to mute a player
minetest.register_chatcommand("mute", {
    params = "<player> <minutes>",
    description = "Mute a player for a specified number of minutes",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        local target, minutes = string.match(param, "([^ ]+) ([^ ]+)")
        minutes = tonumber(minutes)
        if target and minutes then
            muted_players[target] = minetest.get_gametime() + (minutes * 60)
            return true, target .. " has been muted for " .. minutes .. " minutes"
        else
            return false, "Invalid parameters"
        end
    end,
})

-- Command to unmute a player
minetest.register_chatcommand("unmute", {
    params = "<player>",
    description = "Unmute a player",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        if muted_players[param] then
            muted_players[param] = nil
            return true, param .. " has been unmuted"
        else
            return false, "Player is not muted"
        end
    end,
})

-- Mute handling in chat
minetest.register_on_chat_message(function(name, message)
    if muted_players[name] and muted_players[name] > minetest.get_gametime() then
        return true, "You are muted"
    end
    return false
end)

-- Command for global announcement
minetest.register_chatcommand("announce", {
    params = "<message>",
    description = "Make a global announcement",
    privs = {admin=true},
    func = function(name, message)
        if message and message ~= "" then
            minetest.chat_send_all("[Announcement] " .. message)
            return true, "Announcement sent"
        else
            return false, "Invalid message"
        end
    end,
})

-- Command to freeze a player
minetest.register_chatcommand("freeze", {
    params = "<player>",
    description = "Freeze a player",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        if frozen_players[param] then
            return false, "Player is already frozen"
        end
        local target = minetest.get_player_by_name(param)
        if target then
            frozen_players[param] = true
            target:set_physics_override({speed = 0, jump = 0})
            minetest.chat_send_player(param, "You have been frozen by a moderator")
            return true, param .. " has been frozen"
        else
            return false, "Player not found"
        end
    end,
})

-- Command to unfreeze a player
minetest.register_chatcommand("unfreeze", {
    params = "<player>",
    description = "Unfreeze a player",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        if frozen_players[param] then
            frozen_players[param] = nil
            local target = minetest.get_player_by_name(param)
            if target then
                target:set_physics_override({speed = 1, jump = 1})
                minetest.chat_send_player(param, "You have been unfrozen by a moderator")
                return true, param .. " has been unfrozen"
            end
        else
            return false, "Player is not frozen"
        end
    end,
})

-- Prevent frozen players from entering commands
minetest.register_on_prejoinplayer(function(name, ip)
    if frozen_players[name] then
        return "You are frozen and cannot join the game."
    end
end)

minetest.register_on_prejoinplayer(function(name, ip)
    if frozen_players[name] then
        return "You are frozen and cannot join the game."
    end
end)

minetest.register_on_chat_message(function(name, message)
    if frozen_players[name] then
        return true, "You are frozen and cannot chat."
    end
end)

-- Command to set a home point for admin/moderators
minetest.register_chatcommand("sethome_admin", {
    params = "<home_name>",
    description = "Set a home point",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        if not param or param == "" then
            return false, "Invalid home name"
        end
        if not admin_homes[name] then
            admin_homes[name] = {}
        end
        local player = minetest.get_player_by_name(name)
        if player then
            admin_homes[name][param] = player:get_pos()
            return true, "Home '" .. param .. "' set"
        else
            return false, "Player not found"
        end
    end,
})

-- Command to teleport to a home point for admin/moderators
minetest.register_chatcommand("home_admin", {
    params = "<home_name>",
    description = "Teleport to a home point",
    privs = {moderator=true, admin=true},
    func = function(name, param)
        if not param or param == "" then
            return false, "Invalid home name"
        end
        if admin_homes[name] and admin_homes[name][param] then
            local player = minetest.get_player_by_name(name)
            if player then
                player:set_pos(admin_homes[name][param])
                return true, "Teleported to home '" .. param .. "'"
            else
                return false, "Player not found"
            end
        else
            return false, "Home '" .. param .. "' not set"
        end
    end,
})
