require "TimedActions/ISBaseTimedAction"

ISLockpickDoorAction = ISBaseTimedAction:derive("ISLockpickDoorAction")

function ISLockpickDoorAction:isValid()
    return self.character ~= nil and self.tool ~= nil and self.tool:getCondition() > 0 and self.target ~= nil
end

function ISLockpickDoorAction:waitToStart()
    self.character:faceThisObject(self.target)
	return  self.character:isTurning() or self.character:shouldBeTurning()
end

function ISLockpickDoorAction:update()
end

function ISLockpickDoorAction:start()
end

function ISLockpickDoorAction:stop()
	ISBaseTimedAction.stop(self)
end

function ISLockpickDoorAction:perform()
    local targetSquare = self.target and self.target.getSquare and self.target:getSquare()
    if self.character and targetSquare then
        local targetData = {
            x = targetSquare:getX(),
            y = targetSquare:getY(),
            z = targetSquare:getZ(),
            objectType = instanceof(self.target, "IsoDoor") and "IsoDoor" 
                      or instanceof(self.target, "IsoThumpable") and "IsoThumpable"
                      or instanceof(self.target, "VehiclePart") and "VehiclePart" 
                      or "Unknown"
        }

        if isClient() and not isServer() then
            -- Real multiplayer: send to server
            sendClientCommand(self.character, "AwesomeLockpicking", "performLockpick", targetData)
        else
            -- Single-player or integrated server: call directly
            local tool = AwesomeLockpickingUtils.getValidLockpickTool(self.character)
            AwesomeLockpickingUtils.applyLockpickAttempt(self.character, self.target, tool)
        end
    end

    ISBaseTimedAction.perform(self)
end

function ISLockpickDoorAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 60
end

function ISLockpickDoorAction:new(character, target, tool)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.target = target
    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 450 - (character:getPerkLevel(Perks.Lockpicking) * 37.5)
    return o
end