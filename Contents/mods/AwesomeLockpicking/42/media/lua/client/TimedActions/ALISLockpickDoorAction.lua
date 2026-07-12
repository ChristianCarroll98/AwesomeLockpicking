require "TimedActions/ISBaseTimedAction"
require "ALSharedUtils"

---@class ALISLockpickDoorAction : ISBaseTimedAction
---@field character IsoPlayer
---@field target IsoObject | IsoDoor
---@field tool InventoryItem
ALISLockpickDoorAction = ISBaseTimedAction:derive("ISLockpickDoorAction")

function ALISLockpickDoorAction:isValid()
    return self.character and self.target and self.tool and self.tool.getCondition and (self.tool:getCondition() > 0)
end

function ALISLockpickDoorAction:waitToStart()
    self.character:faceThisObject(self.target)
	return  self.character:isTurning() or self.character:shouldBeTurning()
end

function ALISLockpickDoorAction:start()
    self:setActionAnim("Craft")
end

function ALISLockpickDoorAction:stop()
	ISBaseTimedAction.stop(self)
end

function ALISLockpickDoorAction:perform()

    if isClient() and not isServer() then -- is pure client connected to server

        local commands = ALSharedUtils.ALCommandList
        local args = {
            x = self.target:getX(),
            y = self.target:getY(),
            z = self.target:getZ(),
            toolID = self.tool:getID()
        }

        sendClientCommand(commands.ALModule, commands.applyLockpickAttemptServer, args)

    else
        ALSharedUtils.applyLockpickAttempt(self.character, self.target, self.tool)
    end

    ISBaseTimedAction.perform(self)
end

function ALISLockpickDoorAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 60
end

function ALISLockpickDoorAction:new(player, target, tool)
    local LockpickDurationList = {215, 175, 155, 140, 125, 115, 105, 100, 95, 90, 85}
    local o = ISBaseTimedAction.new(self, player)
    o.character = player
    o.target = target
    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = LockpickDurationList[player:getPerkLevel(Perks.Lockpicking) + 1] -- smoothish logarithmic curve, fast table lookup.
    return o
end