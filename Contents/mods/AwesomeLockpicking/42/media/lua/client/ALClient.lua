local function ALOnServerCommand(module, serverCommand, args)
    if module ~= ALNetworkRouter.MODULE_NAME then return end

    ALNetworkRouter.handleServerCommand(serverCommand, args)
end
Events.OnServerCommand.Add(ALOnServerCommand)