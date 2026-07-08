require "AwesomeLockpickingShared"

local function onClientCommand(module, command, playerObj, args)
    if module ~= "AwesomeLockpicking" or command ~= "performLockpick" then
        return
    end

    local target = AwesomeLockpickingUtils.getTargetFromArgs(args)
    if not target then return end

    local tool = AwesomeLockpickingUtils.getValidLockpickTool(playerObj)
    AwesomeLockpickingUtils.applyLockpickAttempt(playerObj, target, tool)
end

if isServer() then
    Events.OnClientCommand.Add(onClientCommand)
end

Events.OnGameStart.Add(AwesomeLockpickingUtils.addSkillBooks)