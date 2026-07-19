require 'TimedActions/ALLockpickDoorAction'
require 'TimedActions/WalkToTimedAction'
require 'ALNetworkRouter'
-- require 'Vehicles/ISUI/ISVehicleMenu' - already comes from ALSharedUtils
-- require 'ALSharedUtils' - already comes from ALLockpickDoorAction

---------- General Helper Functions ----------

local settings = SandboxVars and SandboxVars.AwesomeLockpicking

--- Returns first unbroken inventory item from the list
---@param items ArrayList<InventoryItem>
---@return InventoryItem|nil
local function findFirstUnbroken(items)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if not item.getCondition or (item:getCondition() > 0) then return item end
        end
    end
    return nil
end


--- Returns the first valid and unbroken lockpicking tool, searching in order of quality with professional tools first,
--- then forged, and finally any item with tag screwdriver (if player has a paperclip)
---@param playerObj IsoPlayer
---@return InventoryItem|nil
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


--- Returns the correct context menu translation text key from the tool InventoryItem
---@param tool InventoryItem
---@return string
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


--- Adds lockpicking task to the queue, checking if tools need to be moved into main inventory first. If so, tasks are
--- added to move the items back after the lockpicking task is done.
---@param playerObj IsoPlayer
---@param target IsoThumpable|IsoDoor|VehiclePart|nil
---@param targetType targetTypes
---@param tool InventoryItem
local function addLockpickingTaskToQueue(playerObj, target, targetType, tool)

    local lockpickAction = ALLockpickDoorAction:new(playerObj, target, targetType, tool)

    local inv = playerObj:getInventory()
    local originalToolContainer = tool:getContainer()
    local toolInMainInv = inv:contains(tool)
    ---@type ItemContainer
    local originalPaperclipContainer = nil
    ---@type InventoryItem
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

--- Returns either WorldDoor or PlayerDoor based on target, should only be called from OnFillWorldObjectContextMenu so 
--- no vehicle type
---@param target IsoObject
---@return targetTypes
local function getIsoLockpickingTargetType(target)
    if not target then return ALSharedUtils.LockpickableObjectTypes.Invalid end

    if instanceof(target, "IsoDoor") and target--[[@as IsoDoor]]:isLocked() then
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()
        if props and props:get("HighSecurity") == "true" then
            if settings and not settings.AllowLockpickingHighSecurityDoors then
                return ALSharedUtils.LockpickableObjectTypes.Invalid
            end
        end

        return ALSharedUtils.LockpickableObjectTypes.WorldDoor
    end

    if instanceof(target, "IsoThumpable") and target--[[@as IsoThumpable]].isDoor
        and target--[[@as IsoThumpable]]:isDoor() and target--[[@as IsoThumpable]]:isLocked() then

        if settings and not settings.AllowLockpickingPlayerDoors then
            return ALSharedUtils.LockpickableObjectTypes.Invalid
        end

        return ALSharedUtils.LockpickableObjectTypes.PlayerDoor
    end

    return ALSharedUtils.LockpickableObjectTypes.Invalid
end


--- My custom OnFillWorldObjectContextMenu function
---@param player integer
---@param context ISContextMenu
---@param worldobjects IsoObject[]
---@param test boolean
local function addLockpickingContextMenuOption(player, context, worldobjects, test)
    -- If 'test' is true, the game is just validating if a menu should exist
    if test then return end
    if not worldobjects then return end -- no objects found

    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        print("[ERROR] AwesomeLockpicking - player param nil in addLockpickingContextMenuOption")
        return
    end

    local tool = getValidLockpickTool(playerObj)
    if not tool then return end -- no valid tool found

    local targetTypes = ALSharedUtils.LockpickableObjectTypes

    for _, target in ipairs(worldobjects) do
        local targetType = getIsoLockpickingTargetType(target)
        if targetType == targetTypes.WorldDoor
            or targetType == targetTypes.PlayerDoor then

            -- create walkAction with function to abort early if close enough to target
            local walkAction = ISWalkToTimedAction:new(playerObj, target:getSquare(), function(context)
                return context.player:DistTo(context.square:getX() + 0.5, context.square:getY() + 0.5) <= 1.5
            end, {player = playerObj, square = target:getSquare()})

            context:addOption(getText(getContextTextFromLockpickingToolObj(tool)), player, function()
                ISTimedActionQueue.add(walkAction) -- add walkAction separately and first
                addLockpickingTaskToQueue(playerObj, target--[[@as IsoDoor|IsoThumpable]], targetType, tool)
            end)
            break
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(addLockpickingContextMenuOption)


---------- VehiclePart functions ----------

--- Checks if player is near a vehicle and if so adds lockpicking option if conditions are correct
---@param playerObj IsoPlayer
local function tryAddVehicleLockpickOption(playerObj)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if not menu or menu:isEmpty() then return end

    -- Get the door the player is currently "using" / closest usable door
    local vehiclePart = vehicle:getUseablePart(playerObj)
    if not vehiclePart then return end

    local partId = vehiclePart:getId()

    local ALValidVehiclePartIds = {
        DoorFrontLeft = "DoorFrontLeft", -- all cars
        DoorFrontRight = "DoorFrontRight", -- all cars
        DoorRear = "DoorRear", -- large van back doors
        TrunkDoor = "TrunkDoor", -- most trunks
        TrunkDoorOpened = "TrunkDoorOpened" -- trailers
    }

    if not ALValidVehiclePartIds[partId] then return end

    local vehicleDoor = vehiclePart:getDoor()

    if not vehicleDoor or vehicleDoor:isOpen() or not vehicleDoor:isLocked()
        or vehicle:canUnlockDoor(vehiclePart, playerObj) then return end

    -- if we are here then we have a valid vehicle part that we could pick if we have the right tool

    local tool = getValidLockpickTool(playerObj)
    if not tool then return end -- no valid tool found

    menu:addSlice(
        getText(getContextTextFromLockpickingToolObj(tool)),
        getTexture("textures/Vehicle_pick_lock.png"),
        addLockpickingTaskToQueue,
        playerObj,
        vehiclePart,
        ALSharedUtils.LockpickableObjectTypes.VehicleDoor,
        tool
    )
end


local originalShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside -- store original showRadialMenuOutside
---Overrides vanilla showRadialMenuOutside and calls tryAddVehicleLockpickingOption if vehicle lockpicking is enabled
---@param player IsoPlayer
function ISVehicleMenu.showRadialMenuOutside(player) ---@diagnostic disable-line: duplicate-set-field
    -- Call vanilla FIRST so the base menu (doors, trunk, etc.) is built
    if originalShowRadialMenuOutside then
        originalShowRadialMenuOutside(player)
    end

    if settings and not settings.AllowLockpickingVehicleDoors then return end
    -- Now safely add lockpick options
    tryAddVehicleLockpickOption(player)
end
