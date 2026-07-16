require 'ALSharedUtils'

local function getDoorAt(x, y, z, targetType) -- cannot pass complex objects to OnClientCommand - pass target by location
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local targetTypes = ALSharedUtils.ALPickableObjectType
        if (targetType == targetTypes.WorldDoor and instanceof(obj, "IsoDoor"))
            or (targetType == targetTypes.PlayerDoor and instanceof(obj, "IsoThumpable") and obj:isDoor()) then
            return obj
        end
    end
    return nil
end

local function ALOnClientCommand(module, command, player, args)
    if isClient() and not isServer() then return end -- only for server side

    local commands = ALSharedUtils.CommandList
    if not commands or module ~= commands.ALModule then return end

    if command == commands.applyLockpickAttemptServer then

        local targetType = args.targetType
        local targetTypes = ALSharedUtils.ALPickableObjectType

        local tool = player:getInventory():getItemWithID(args.toolID)
        if not tool then
            print("[ERROR] AwesomeLockpicking - could not get tool in ALOnClientCommand")
        end

        local door = nil

        if targetType == targetTypes.VehicleDoor then
            local vehicle = getVehicleById(args.vehicleId)
            if not vehicle then
                print("[ERROR] AwesomeLockpicking - could not get vehicle from ID in ALOnClientCommand")
                return
            end

            local part = vehicle:getPartById(args.vehiclePartId)
            if not part then
                print("[ERROR] AwesomeLockpicking - could not get vehicle part from part ID in ALOnClientCommand")
                return
            end

            door = part:getDoor()
        elseif targetType == targetTypes.WorldDoor or targetType == targetTypes.PlayerDoor then
            door = getDoorAt(args.x, args.y, args.z, targetType)
        end

        if not door then
            print("[ERROR] AwesomeLockpicking - could not get door obj in ALOnClientCommand")
        end

        ALSharedUtils.applyLockpickAttempt(player, tool, door, targetType)
    end
end

local function giveMasterLocksmithStartingTools(player)
    if isClient() and not isServer() then return end -- only for SP and server side

    if not player then
        print("[ERROR] AwesomeLockpicking - player param nil in giveMasterLocksmithStartingTools")
        return
    end

    if tostring(player:getDescriptor():getCharacterProfession()) == "awesomelockpicking:masterlocksmith" then
        player:getInventory():AddItem("AwesomeLockpicking.ProfessionalLockpickingTools")
    end
end

Events.OnClientCommand.Add(ALOnClientCommand)
Events.OnNewGame.Add(giveMasterLocksmithStartingTools)