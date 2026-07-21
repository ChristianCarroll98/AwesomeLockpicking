---@type ALNetworkRouter
local net = require 'ALNetworkRouter'

local function ALOnServerCommand(module, serverCommand, args)
    if module ~= net.MODULE_NAME then return end

    net.handleServerCommand(serverCommand, args)
end
Events.OnServerCommand.Add(ALOnServerCommand)