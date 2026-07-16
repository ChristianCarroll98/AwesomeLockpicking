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
        if not screwdriverTag then return nil end

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

local function toolIsInMainInventory(player, item)
    local mainInv = player:getInventory()
    if mainInv:contains(item) then
        return true  -- already in main inventory
    end

    return false
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
            print("player doors not allowed: " .. tostring(settings.AllowLockpickingPlayerDoors))
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

            local lockpickAction = ALLockpickDoorAction:new(playerObj, target, targetType, tool)

            context:addOption(getText(getContextTextFromLockpickingToolObj(tool)), player, function()
                local originalToolContainer = tool:getContainer()
                local inv = playerObj:getInventory()
                local toolInMainInv = toolIsInMainInventory(playerObj, tool)
                local originalPaperclipContainer = nil
                local shouldReturnPaperclip = false
                if not toolInMainInv then -- move lockpicking tools into main inventory
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, tool, originalToolContainer, inv))
                end
                if tool:hasTag(ItemTag.get(ResourceLocation.new("base", "screwdriver"))) then
                    if not inv:containsType("Base.Paperclip") then
                        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip") -- move paperclip into main inventory
                        originalPaperclipContainer = paperclip:getContainer()
                        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, paperclip,
                            originalPaperclipContainer, inv))
                        shouldReturnPaperclip = true
                    end
                end
                ISTimedActionQueue.add(walkAction)
                ISTimedActionQueue.add(lockpickAction)
                if not toolInMainInv then -- return lockpicking tools to where it was
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, tool, inv, originalToolContainer))
                end
                -- check if paperclip still exists (might have broken)
                print("shouldReturnPaperclip: " .. tostring(shouldReturnPaperclip))
                print("originalPaperclipContainer: " .. tostring(originalPaperclipContainer))
                print("inventory contains paperclip: " .. tostring(inv:containsType("Base.Paperclip")))
                if shouldReturnPaperclip and originalPaperclipContainer and inv:containsType("Base.Paperclip") then
                    print("try return paperclip")
                    local paperclip = inv:getFirstType("Base.Paperclip") -- move paperclip into back into container
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, paperclip, inv,
                        originalPaperclipContainer))
                end
            end)
            break
        end
    end
end


---------- VehiclePart functions ----------

local function tryAddLockpickOptions(playerObj)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if not menu or menu:isEmpty() then return end

    -- Get the door the player is currently "using" / closest usable door
    local vehiclePart = vehicle:getUseablePart(playerObj)
    if not vehiclePart then return end

    local partId = vehiclePart:getId()

    print(tostring(partId))

    if not (partId == "DoorFrontLeft"
        or partId == "DoorFrontRight"
        or partId == "TrunkDoor") then
        return
    end

    local vehicleDoor = vehiclePart:getDoor()

    if not vehicleDoor or not vehicleDoor:isLocked() or vehicle:canUnlockDoor(vehiclePart, playerObj) then return end

    -- if we are here then we have a valid vehicle part that we could pick if we have the right tool

    local tool = getValidLockpickTool(playerObj)
    if not tool then return end -- no valid tool found

    local action = ALLockpickDoorAction:new(playerObj, vehiclePart, ALSharedUtils.ALPickableObjectType.VehicleDoor,
        tool)

    menu:addSlice(getText(getContextTextFromLockpickingToolObj(tool),
        getTexture("media/textures/Vehicle_pick_lock.png"),
        function()
            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, vehiclePart:getVehicle(),
                vehiclePart:getArea()))
            ISTimedActionQueue.add(action)
        end)
    )
end

local originalShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside -- store original showRadialMenuOutside
function ISVehicleMenu.showRadialMenuOutside(player) -- overridden
    -- Call vanilla FIRST so the base menu (doors, trunk, etc.) is built
    if originalShowRadialMenuOutside then
        originalShowRadialMenuOutside(player)
    end
    
    -- Now safely add your lockpick options
    tryAddLockpickOptions(player)
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
    end
end

Events.OnServerCommand.Add(ALOnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(addLockpickingContextMenuOption)