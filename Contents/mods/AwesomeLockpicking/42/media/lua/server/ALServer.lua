require 'ALSharedUtils'

local function getDoorAt(x, y, z) -- cannot pass complex objects to OnClientCommand - pass target by location
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoDoor") then -- or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
            return obj
        end
    end
    return nil
end

local function ALOnClientCommand(module, command, player, args)
    if isClient() and not isServer() then return end -- only for server side

    local commands = ALSharedUtils.ALCommandList
    if not commands or module ~= commands.ALModule then return end

    if command == commands.applyLockpickAttemptServer then

        local door = getDoorAt(args.x, args.y, args.z)
        if not door then
            print("[ERROR] AwesomeLockpicking - could not get door obj in ALOnClientCommand")
        end

        local tool = player:getInventory():getItemWithID(args.toolID)
        if not tool then
            print("[ERROR] AwesomeLockpicking - could not get tool in ALOnClientCommand")
        end

        ALSharedUtils.applyLockpickAttempt(player, door, tool)
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