require 'TimedActions/ALLockpickDoorAction'
require 'TimedActions/WalkToTimedAction'
-- require 'Vehicles/ISUI/ISVehicleMenu' - already comes from ALSharedUtils
-- require 'ALSharedUtils' - already comes from ALLockpickDoorAction

---------- General Helper Functions ----------

local function findFirstUnbroken(items)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if not item.getCondition or (item:getCondition() > 0) then return item end
        end
    end
    return nil
end

local function getValidLockpickTool(playerObj)
    if not playerObj then return nil end

    local inv = playerObj:getInventory()
    if not inv then return nil end

    local tool = findFirstUnbroken(inv:getAllTypeRecurse("AwesomeLockpicking.ProfessionalLockpickingTools"))
    if not tool then tool = findFirstUnbroken(inv:getAllTypeRecurse("AwesomeLockpicking.ForgedLockpickingTools")) end

    if not tool and inv:containsTypeRecurse("Base.Paperclip") then

        local screwdriverTag = ItemTag.get(ResourceLocation.new("base", "screwdriver"))

        local screwdriverList = ArrayList.new()
        inv:getAllTagRecurse(screwdriverTag, screwdriverList)

        tool = findFirstUnbroken(screwdriverList)
    end

    return tool
end

local function getContextTextFromLockpickingToolObj(tool)
    local toolType = tool:getFullType()
    local contextText = "ContextMenu_PickLockWithPaperclip" -- default

    if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
        contextText = "ContextMenu_PickLockWithProfessionalLockpick"
    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        contextText = "ContextMenu_PickLockWithForgedLockpick"
    end

    return contextText
end

local function addLockpickingTaskToQueue(playerObj,  target, targetType, tool)

    local lockpickAction = ALLockpickDoorAction:new(playerObj, target, targetType, tool)

    local inv = playerObj:getInventory()
    local originalToolContainer = tool:getContainer()
    local toolInMainInv = inv:contains(tool)
    local originalPaperclipContainer = nil
    local paperclip = nil
    local shouldReturnPaperclip = false

    if not toolInMainInv then -- move lockpicking tool into main inventory
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, tool, originalToolContainer, inv))
    end

    -- check for paperclip if tool is screwdriver
    if tool:hasTag(ItemTag.get(ResourceLocation.new("base", "screwdriver"))) then
        if not inv:containsType("Base.Paperclip") then
            paperclip = inv:getFirstTypeRecurse("Base.Paperclip") -- move paperclip into main inventory
            originalPaperclipContainer = paperclip:getContainer()
            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, paperclip, originalPaperclipContainer, inv))
            shouldReturnPaperclip = true
        end
    end

    ISTimedActionQueue.add(lockpickAction)

    -- return lockpicking tool to where it was (make sure still exists)
    if not toolInMainInv and originalToolContainer and tool then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, tool, inv, originalToolContainer))
    end

    -- if shouldReturnPaperclip then move paperclip to where it was (make sure still exists)
    if shouldReturnPaperclip and originalPaperclipContainer and paperclip then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, paperclip, inv, originalPaperclipContainer))
    end
end


---------- IsoObject Lockpicking Functions ----------

local function isValidIsoLockpickingTarget(target)
    if not target then return ALSharedUtils.ALPickableObjectType.None end

    local settings = SandboxVars and SandboxVars.AwesomeLockpicking

    if instanceof(target, "IsoDoor") and target:isLocked() then
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()
        if props and props:get("HighSecurity") == "true" then
            if settings and not settings.AllowLockpickingHighSecurityDoors then
                return ALSharedUtils.ALPickableObjectType.None
            end
        end

        return ALSharedUtils.ALPickableObjectType.WorldDoor
    end

    if instanceof(target, "IsoThumpable") and target:isDoor() and target:isLocked() then
        if settings and not settings.AllowLockpickingPlayerDoors then
            return ALSharedUtils.ALPickableObjectType.None
        end

        return ALSharedUtils.ALPickableObjectType.PlayerDoor
    end

    return ALSharedUtils.ALPickableObjectType.None
end

local function addLockpickingContextMenuOption(player, context, worldobjects, ...)
    if not worldobjects then return end -- no objects found

    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        print("[ERROR] AwesomeLockpicking - player param nil in addLockpickingContextMenuOption")
        return
    end

    local tool = getValidLockpickTool(playerObj)
    if not tool then return end -- no valid tool found

    for _, target in ipairs(worldobjects) do
        local targetType = isValidIsoLockpickingTarget(target)
        if targetType == ALSharedUtils.ALPickableObjectType.WorldDoor
            or targetType == ALSharedUtils.ALPickableObjectType.PlayerDoor then

            -- create walkAction with function to abort early if close enough to target
            local walkAction = ISWalkToTimedAction:new(playerObj, target:getSquare(), function(context)
                return context.player:DistTo(context.square:getX() + 0.5, context.square:getY() + 0.5) <= 1.5
            end, {player = playerObj, square = target:getSquare()})

            context:addOption(getText(getContextTextFromLockpickingToolObj(tool)), player, function()
                ISTimedActionQueue.add(walkAction) -- add walkAction separately and first
                addLockpickingTaskToQueue(playerObj, target, targetType, tool)
            end)
            break
        end
    end
end


---------- VehiclePart functions ----------

local function tryAddVehicleLockpickOption(playerObj)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if not menu or menu:isEmpty() then return end

    -- Get the door the player is currently "using" / closest usable door
    local vehiclePart = vehicle:getUseablePart(playerObj)
    if not vehiclePart then return end

    local partId = vehiclePart:getId()

    if not ALSharedUtils.ALValidVehiclePartIds[partId] then return end

    local vehicleDoor = vehiclePart:getDoor()

    if not vehicleDoor or not vehicleDoor:isLocked() or vehicle:canUnlockDoor(vehiclePart, playerObj) then return end

    -- if we are here then we have a valid vehicle part that we could pick if we have the right tool

    local tool = getValidLockpickTool(playerObj)
    if not tool then return end -- no valid tool found

    menu:addSlice(
        getText(getContextTextFromLockpickingToolObj(tool)),
        getTexture("textures/Vehicle_pick_lock.png"),
        addLockpickingTaskToQueue,
        playerObj,
        vehiclePart,
        ALSharedUtils.ALPickableObjectType.VehicleDoor,
        tool
    )
end

local originalShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside -- store original showRadialMenuOutside
function ISVehicleMenu.showRadialMenuOutside(player) -- overridden
    -- Call vanilla FIRST so the base menu (doors, trunk, etc.) is built
    if originalShowRadialMenuOutside then
        originalShowRadialMenuOutside(player)
    end
    
    -- Now safely add your lockpick options
    tryAddVehicleLockpickOption(player)
end


local function ALOnServerCommand(module, command, args)
    local commands = ALSharedUtils.CommandList
    if module ~= commands.ALModule then return end
    
    local player = getPlayer()
    if not player then
        print("[ERROR] AwesomeLockpicking - player nil in ALOnServerCommand")
        return
    end

    if command == commands.setHaloNoteClient then
        player:setHaloNote(getText(args.text))
    elseif command == commands.enterVehicle then
        local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicle, seatIndex) -- sandbox option..
        ISTimedActionQueue.add(enterVehicleAction)
    end
end

Events.OnServerCommand.Add(ALOnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(addLockpickingContextMenuOption)