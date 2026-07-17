require 'Vehicles/ISUI/ISVehicleMenu'

ALSharedUtils = ALSharedUtils or {}

local settings = SandboxVars and SandboxVars.AwesomeLockpicking

local function listAllVehiclePartInfo(vehicle)
    local partCount = vehicle:getPartCount()
    for i = 0, (partCount - 1) do
        local part = vehicle:getPartByIndex(i)
        if part then
            local partId = part:getId()
            -- Perform your checks here (e.g., is it a lock?)
            print("Part ID: " .. tostring(partId) .. "; part area: " .. tostring(part:getArea()) .. "; isContainer: " .. tostring(part:getItemContainer() ~= nil))
        end
    end
end

local function getSeatIndexFromPart(part)
    if not part then return -1 end
    local vehicle = part:getVehicle()
    if not vehicle then return -1 end

    for i = 0, vehicle:getMaxPassengers() - 1 do
        -- Only check the doors mapped to this seat index
        if vehicle:getPassengerDoor(i) == part or vehicle:getPassengerDoor2(i) == part then
            return i
        end
    end

    return -1 -- Not a door assigned to a seat
end


local function applyLockpickAttempt(playerObj, tool, target, targetType)
    local targetTypes = ALSharedUtils.ALPickableObjectType
    if not playerObj or not target or not tool or not targetType or targetType == targetTypes.None then
        print("[ERROR] AwesomeLockpicking - nil param or None targetType in applyLockpickAttempt")
        return
    end

    local inv = playerObj:getInventory()
    if not inv then
        print("[ERROR] AwesomeLockpicking - player:getInventory() returned nil in applyLockpickAttempt")
        return
    end

    local toolTypes = {
        screwdriver = "screwdriver",
        professional = "professional",
        forged = "forged"
    }

    local toolBonus = 1 -- default for screwdriver
    local toolType = tool:getFullType()
    if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
        toolType = toolTypes.professional
        toolBonus = 1.5
    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        toolType = toolTypes.forged
        toolBonus = 1.3
    else
        toolType = toolTypes.screwdriver -- any screwdriver if not lockpicking tools
    end

    local baseChance = 20 + (playerObj:getPerkLevel(Perks.Lockpicking) * 7)

    local doorMultiplier = 1.0
    if targetType == targetTypes.VehicleDoor then
        doorMultiplier = 0.55
    else
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()
        if props then
            if props:get("HighSecurity") == "true" then
                doorMultiplier = 0.5
            elseif props:get("MetalDoor") == "true" then
                doorMultiplier = 0.65
            elseif props:get("GlassDoor") == "true" then
                doorMultiplier = 0.8
            end
        end
    end

    local sandboxMod = 1.0
    if settings then
        sandboxMod = settings.SuccessChanceModifier or 1.0
    end

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod
    finalChance = math.max(5, finalChance)

    local success = ZombRand(100) < finalChance

    if tool.getCondition and tool:getCondition() > 0 then
        local baseChancePool = tool:getConditionLowerChance()
        local maintenanceMod = playerObj:getMaintenanceMod()
        local finalChancePool = baseChancePool + maintenanceMod

        if success then
            finalChancePool = finalChancePool * 2
        end

        if ZombRand(finalChancePool) == 0 then
            tool:setCondition(tool:getCondition() - 1)
            inv:setDrawDirty(true)
        end
    end

    if toolType == toolTypes.screwdriver then
        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip")
        if paperclip then
            local removePaperclipChance = success and 10 or 25
            if ZombRand(100) < removePaperclipChance then
                inv:Remove(paperclip)
            end
        end
    end

    local commands = ALSharedUtils.CommandList
    local xpGain = 10

    if success then -- unlock and open doors.
        if targetType == targetTypes.VehicleDoor then -- borrowed from ISUnlockVehicleDoor:complete()
            local vehicle = target:getVehicle()
            if vehicle then
                if not target then
                    print('[ERROR] AwesomeLockpicking.applyLockpickAttempt - no such vehicle part '..tostring(target))
                    return
                end
                local vehicleDoor = target:getDoor()
                if not vehicleDoor then
                    print('[ERROR] AwesomeLockpicking.applyLockpickAttempt - part ' .. target .. ' has no door')
                    return
                end

                vehicleDoor:setLocked(false)
                vehicle:transmitPartDoor(target) -- required??

                print("target Part ID: " .. tostring(target:getId()) .. "; part area: "
                    .. tostring(target:getArea()) .. "; isContainer: "
                    .. tostring(target:getItemContainer() ~= nil))

                print("All parts: ")
                listAllVehiclePartInfo(vehicle)

                if target:getArea() ~= "TruckBed" then -- unlocking a door
                    if settings.AutoEnterOnLockpickingVehicleDoor then
                        local seatIndex = getSeatIndexFromPart(target)

                        if seatIndex > -1 then -- enter vehicle

                            if isServer() then
                                sendServerCommand(playerObj, commands.ALModule, commands.enterVehicle,
                                    {vehicle = vehicle, seatIndex = seatIndex})

                            else
                                local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicle, seatIndex) -- sandbox option..
                                ISTimedActionQueue.add(enterVehicleAction)
                            end
                        end
                    end
                else
                    local truckBed = vehicle:getPartById("TruckBed")
                    if truckBed and truckBed:getItemContainer() then
                        if isServer() then
                            sendServerCommand(playerObj, commands.ALModule, commands.openVehicleDoor,
                                {vehicle = vehicle, vehiclePart = target})
                        else
                            local openTrunkAction = ISOpenVehicleDoor:new(playerObj, vehicle, target)
                            ISTimedActionQueue.add(openTrunkAction)
                        end
                    end
                end
            else
                print('[ERROR] AwesomeLockpicking.applyLockpickAttempt - no such vehicle id='..tostring(vehicle))
                return
            end
        else
            if targetType == targetTypes.PlayerDoor then
                if target.setIsLocked then target:setIsLocked(false) end -- PlayerDoor

            elseif targetType == targetTypes.WorldDoor then
                if target.setLockedByKey then target:setLockedByKey(false) end -- WorldDoor
            end
            if target.ToggleDoor then target:ToggleDoor(playerObj) end -- both PlayerDoor and WorldDoor
        end

        xpGain = 20

    elseif isServer() then -- fail from server, send halo note text to client
        sendServerCommand(playerObj, commands.ALModule, commands.setHaloNoteClient,
            {text = "IGUI_ingame_LockpickingTaskFailed"})
    else
        local badColor = getCore():getBadHighlitedColor()
        local r = math.floor(badColor:getR() * 255)
        local g = math.floor(badColor:getG() * 255)
        local b = math.floor(badColor:getB() * 255)

        playerObj:setHaloNote(getText("IGUI_ingame_LockpickingTaskFailed"), r, g, b, 150.0)
    end

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * xpGain, false, true, false)
end


---------- Enums ----------
local CommandList = {
    ALModule = "ALModule",
    applyLockpickAttemptServer = "applyLockpickAttemptServer",
    setHaloNoteClient = "setHaloNoteClient",
    enterVehicle = "enterVehicle",
    openVehicleDoor = "openVehicleDoor"
}

local ALPickableObjectType = {
    WorldDoor = "WorldDoor",
    PlayerDoor = "PlayerDoor",
    VehicleDoor = "VehicleDoor",
    None = "None"
}

local ALValidVehiclePartIds = {
    DoorFrontLeft = "DoorFrontLeft", -- all cars
    DoorFrontRight = "DoorFrontRight", -- all cars
    DoorRear = "DoorRear", -- large van back doors
    TrunkDoor = "TrunkDoor", -- most trunks
    TrunkDoorOpened = "TrunkDoorOpened" -- trailers
}

---------- Exports ----------
ALSharedUtils.applyLockpickAttempt = applyLockpickAttempt
ALSharedUtils.CommandList = CommandList
ALSharedUtils.ALPickableObjectType = ALPickableObjectType
ALSharedUtils.ALValidVehiclePartIds = ALValidVehiclePartIds