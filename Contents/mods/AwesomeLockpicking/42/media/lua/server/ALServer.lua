---@type ALSharedUtils
local u = require 'ALSharedUtils'

---@type ALNetworkRouter
local net = require 'ALNetworkRouter'

---@const
local fileName = "ALServer"

--- Gives the player a Professional Lockpicking Tools item on start if they selected the Master Locksmith profession
---@param playerObj IsoPlayer
local function giveMasterLocksmithStartingTools(playerObj)
    if net.isPureClientContext() then return end -- only for SP and server side ALTODO might not be needed? check in SP.
    if not playerObj then u.ALlog("playerObj nil", u.ALLogLevel.ERROR,
        fileName .. "giveMasterLocksmithStartingTools") return end

    if tostring(playerObj:getDescriptor():getCharacterProfession()) == "awesomelockpicking:masterlocksmith" then
        playerObj:getInventory():AddItem("AwesomeLockpicking.ProfessionalLockpickingTools")
    end
end
Events.OnNewGame.Add(giveMasterLocksmithStartingTools)


local function ALOnClientCommand(module, command, player, args)
    if module ~= net.MODULE_NAME then return end

    net.handleClientCommand(command, args)
end
Events.OnClientCommand.Add(ALOnClientCommand)