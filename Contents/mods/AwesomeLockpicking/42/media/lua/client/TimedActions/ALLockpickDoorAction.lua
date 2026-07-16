require "TimedActions/ISBaseTimedAction"
require "ALSharedUtils"

---@class ALLockpickDoorAction : ISBaseTimedAction
---@field character IsoPlayer
---@field target IsoThumpable | IsoDoor | VehiclePart
---@field targetType string
---@field tool InventoryItem
ALLockpickDoorAction = ISBaseTimedAction:derive("ISLockpickDoorAction")

function ALLockpickDoorAction:isValid()
    return self.character and self.target and self.tool and self.tool.getCondition and (self.tool:getCondition() > 0)
end

function ALLockpickDoorAction:waitToStart()
    if instanceof(self.target, "IsoObject") then -- safely check for object type
        ---@diagnostic disable-next-line: param-type-mismatch
        self.character:faceThisObject(self.target)
        return self.character:isTurning() or self.character:shouldBeTurning()
    end
    return false
end

function ALLockpickDoorAction:start()
    self:setActionAnim("Craft")
end

function ALLockpickDoorAction:stop()
	ISBaseTimedAction.stop(self)
end

function ALLockpickDoorAction:perform()

    local target = self.target
    local targetType = self.targetType

    if isClient() and not isServer() then -- is pure client connected to server

        local args = {
            toolId = self.tool:getID(),
            type = targetType
        }

        local targetTypes = ALSharedUtils.ALPickableObjectType

        if targetType == targetTypes.VehicleDoor then

            args.vehicleId = target:getVehicle():getID()
            args.vehiclePartId = target:getId()
        else

            args.x = target:getX()
            args.y = target:getY()
            args.z = target:getZ()
        end

        local commands = ALSharedUtils.CommandList

        sendClientCommand(commands.ALModule, commands.applyLockpickAttemptServer, args)

    else
        ALSharedUtils.applyLockpickAttempt(self.character, self.tool, target, targetType)
    end

    ISBaseTimedAction.perform(self)
end

function ALLockpickDoorAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 60
end

function ALLockpickDoorAction:new(player, target, targetType, tool)
    local LockpickDurationList = {215, 175, 155, 140, 125, 115, 105, 100, 95, 90, 85}
    local o = ISBaseTimedAction.new(self, player)
    o.character = player
    o.target = target
    o.targetType = targetType
    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = LockpickDurationList[player:getPerkLevel(Perks.Lockpicking) + 1] -- smoothish logarithmic curve, fast table lookup.
    return o
end