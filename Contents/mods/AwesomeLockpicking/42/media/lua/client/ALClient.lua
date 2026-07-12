require 'TimedActions/ALISLockpickDoorAction'
require 'TimedActions/WalkToTimedAction'
require 'ALSharedUtils'

local function isValidLockpickingTarget(target)
    if not target then return false end

    if instanceof(target, "IsoDoor") and target:isLocked() then -- or instanceof(target, "IsoThumpable")) and target:isLocked() then
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()
        if props and props:get("HighSecurity") == "true" then
            local settings = SandboxVars and SandboxVars.AwesomeLockpicking
            if settings and not settings.AllowLockpickingHighSecurityDoors then
                return false
            end
        end

        return true
    end

    -- vehicles coming soon
    --[[ if instanceof(target, "VehiclePart") then
        local partId = target:getId()
        if partId == "Trunk"
           or partId == "Tailgate"
           or string.find(partId, "Door") then
            return true
        end
    end ]]

    return false
end

local function findFirstUnbroken(items)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if not item.getCondition or (item:getCondition() > 0) then return item end
        end
    end
    return nil
end

local function getValidLockpickTool(player)
    if not player then return nil end

    local inv = player:getInventory()
    if not inv then return nil end

    local tool = findFirstUnbroken(inv:getAllTypeRecurse("AwesomeLockpicking.ProfessionalLockpickingTools"))
    if not tool then tool = findFirstUnbroken(inv:getAllTypeRecurse("AwesomeLockpicking.ForgedLockpickingTools")) end

    if not tool and inv:containsTypeRecurse("Base.Paperclip") then
    
        local screwdriverTag = ItemTag.get(ResourceLocation.new("base", "screwdriver"))
        if not screwdriverTag then return nil end

        local screwdriverList = ArrayList.new()
        inv:getAllTagRecurse(screwdriverTag, screwdriverList)

        tool = findFirstUnbroken(screwdriverList)
    end

    return tool
end

local function addLockpickingOption(playerNum, context, worldobjects, ...)
    if not worldobjects then return end -- no objects found
    
    local player = getSpecificPlayer(playerNum)
    if not player then
        print("[ERROR] AwesomeLockpicking - player param nil in addLockpickingOption")
        return
    end

    local tool = getValidLockpickTool(player)
    if not tool then return end -- no valid tool found

    for _, obj in ipairs(worldobjects) do
        if obj and isValidLockpickingTarget(obj) then

            -- create walkAction with function to abort early if close enough to target
            local walkAction = ISWalkToTimedAction:new(player, obj:getSquare(), function(context)
                return context.player:DistTo(context.square:getX() + 0.5, context.square:getY() + 0.5) <= 1.5
            end, {player = player, square = obj:getSquare()})

            local toolType = tool:getFullType()
            local contextText = "ContextMenu_PickLockWithPaperclip" -- default

            if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
                contextText = "ContextMenu_PickLockWithProfessionalLockpick"
            elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
                contextText = "ContextMenu_PickLockWithForgedLockpick"
            end

            local action = ALISLockpickDoorAction:new(player, obj, tool)

            context:addOption(getText(contextText), playerNum, function()
                ISTimedActionQueue.add(walkAction)
                ISTimedActionQueue.add(action)
            end)
            break
        end
    end
end

local function ALOnServerCommand(module, command, args)
    local commands = ALSharedUtils.ALCommandList
    if module ~= commands.ALModule then return end
    
    local player = getPlayer()
    if not player then
        print("[ERROR] AwesomeLockpicking - player nil in ALOnServerCommand")
        return
    end

    if command == commands.setHaloNoteClient then
        player:setHaloNote(getText(args.text))
    end
end

Events.OnServerCommand.Add(ALOnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(addLockpickingOption)