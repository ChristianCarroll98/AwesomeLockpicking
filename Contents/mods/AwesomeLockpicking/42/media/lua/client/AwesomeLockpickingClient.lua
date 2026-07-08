require 'TimedActions/ISLockpickDoorAction'
require 'TimedActions/ISWalkToTimedAction'
require "AwesomeLockpickingShared"

local function isValidLockpickingTarget(obj)
    if not obj then return false end

    if instanceof(obj, "IsoDoor") and obj:isLocked() then
        local sprite = obj:getSprite()
        local props = sprite and sprite:getProperties()
        if props and props:get("HighSecurity") == "true" then
            local settings = SandboxVars and SandboxVars.AwesomeLockpicking
            if settings and not settings.AllowLockpickingHighSecurityDoors then
                return false
            end
        end
        return true
    end

    if instanceof(obj, "VehiclePart") then
        local partId = obj:getId()
        if partId == "Trunk" 
           or partId == "Tailgate" 
           or string.find(partId, "Door") then
            return true
        end
    end

    return false
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, ...)
    if not playerNum or not worldobjects then return end

    local playerObj = getSpecificPlayer(playerNum)
    local tool = AwesomeLockpickingUtils.getValidLockpickTool(playerObj)
    if not tool then return end

    for _, obj in ipairs(worldobjects) do
        if obj and isValidLockpickingTarget(obj) then
            local walkAction = ISWalkToTimedAction:new(playerObj, obj:getSquare(), function(context)
                return context.player:DistTo(context.square:getX() + 0.5, context.square:getY() + 0.5) <= 1.5
            end, {player = playerObj, square = obj:getSquare()})
            
            local tag = ItemTag.get(ResourceLocation.new("base", "screwdriver"))
            local contextText = tool and tool.hasTag and tag and tool:hasTag(tag)
                and "ContextMenu_PickLockWithPaperclip" or "ContextMenu_PickLockWithLockpick"

            local action = ISLockpickDoorAction:new(playerObj, obj, tool)

            context:addOption(getText(contextText), playerNum, function()
                ISTimedActionQueue.add(walkAction)
                ISTimedActionQueue.add(action)
            end)
            break
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)