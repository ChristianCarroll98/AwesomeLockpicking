require "TimedActions/ISBaseTimedAction"
require "ALSharedUtils"
-- require 'ALNetworkRouter' -- included in ALSharedUtils

---@class ALLockpickDoorAction : ISBaseTimedAction
---@field character IsoPlayer
---@field target IsoThumpable|IsoDoor|VehiclePart|nil
---@field targetType targetTypes
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
    if not target then
        print("[ERROR] AwesomeLockpicking.ALLockpickDoorAction.perform - target nil")
        return
    end

    local targetType = self.targetType
    local targetTypes = ALSharedUtils.LockpickableObjectTypes
    local playerId = -1
    if ALNetworkRouter:isSinglePlayerContext() then
        playerId = self.character:getPlayerNum()
    else
        playerId = self.character:getOnlineID()
    end

    local args = {
        playerId = playerId,
        toolId = self.tool:getID(),
        targetType = targetType
    }

    if targetType == targetTypes.VehicleDoor then
        args.vehicleId = target:getVehicle():getId()
        args.vehiclePartId = target:getId()

    elseif targetType == targetTypes.WorldDoor or targetType == targetTypes.PlayerDoor then
        args.squarePos = {
            x = target:getX(),
            y = target:getY(),
            z = target:getZ()
        }
    elseif targetType == targetTypes.Invalid then
        print("[ERROR] AwesomeLockpicking.ALLockpickDoorAction.perform - invalid target type")
        return
    end

    -- Expected params: integer playerId, integer toolId, targetTypes targetType, if VehicleDoor: integer vehicleId and 
    -- string vehiclePartId, or if WorldDoor or PlayerDoor: table<string, number>: {x, y, z} squarePos
    ALNetworkRouter.sendToServer(ALNetworkRouter.clientCommands.applyLockpickAttempt, args)

    ISBaseTimedAction.perform(self)
end

function ALLockpickDoorAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return self.maxTime
end

---@param target IsoThumpable|IsoDoor|VehiclePart|nil
---@param targetType targetTypes
---@param tool InventoryItem
function ALLockpickDoorAction:new(player, target, targetType, tool)
    local LockpickDurationList = {215, 175, 155, 140, 125, 115, 105, 100, 95, 90, 85}
    local o = ISBaseTimedAction.new(self, player)
    o.character = player
    o.target = target ---@diagnostic disable-line inject-field
    o.targetType = targetType ---@diagnostic disable-line inject-field
    o.tool = tool ---@diagnostic disable-line inject-field
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = LockpickDurationList[player:getPerkLevel(Perks.Lockpicking) + 1] -- smoothish logarithmic curve, fast table lookup.
    return o
end