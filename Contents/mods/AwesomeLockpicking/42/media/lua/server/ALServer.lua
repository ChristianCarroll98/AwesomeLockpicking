require 'ALNetworkRouter'

--- Gives the player a Professional Lockpicking Tools item on start if they selected the Master Locksmith profession
---@param playerObj IsoPlayer
local function giveMasterLocksmithStartingTools(playerObj)
    if ALNetworkRouter.isPureClientContext() then return end -- only for SP and server side ALTODO might not be needed? check in SP.

    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALServer.giveMasterLocksmithStartingTools - playerObj nil")
        return
    end

    if tostring(playerObj:getDescriptor():getCharacterProfession()) == "awesomelockpicking:masterlocksmith" then
        playerObj:getInventory():AddItem("AwesomeLockpicking.ProfessionalLockpickingTools")
    end
end
Events.OnNewGame.Add(giveMasterLocksmithStartingTools)


local function ALOnClientCommand(module, command, player, args)
    if module ~= ALNetworkRouter.MODULE_NAME then return end

    ALNetworkRouter.handleClientCommand(command, args)
end
Events.OnClientCommand.Add(ALOnClientCommand)