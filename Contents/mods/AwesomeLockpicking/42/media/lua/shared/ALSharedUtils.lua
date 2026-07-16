require 'Vehicles/ISUI/ISVehicleMenu'

ALSharedUtils = ALSharedUtils or {}

local function applyLockpickAttempt(playerObj, tool, target, targetType)
    local targetTypes = ALSharedUtils.ALPickableObjectType
    if not playerObj or not target or not tool or not targetType or targetType == targetTypes.None then
        print("[ERROR] AwesomeLockpicking - nil param in applyLockpickAttempt")
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
        toolBonus = 1.55
    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        toolType = toolTypes.forged
        toolBonus = 1.35
    else
        toolType = toolTypes.screwdriver -- any screwdriver if not lockpicking tools
    end

    local baseChance = 20 + (playerObj:getPerkLevel(Perks.Lockpicking) * 7)

    local doorMultiplier = 1.0
    local sprite = target:getSprite()
    local props = sprite and sprite:getProperties()
    if props then
        if props:get("HighSecurity") == "true" then
            doorMultiplier = 0.45
        elseif props:get("MetalDoor") == "true" then
            doorMultiplier = 0.75
        elseif props:get("GlassDoor") == "true" then
            doorMultiplier = 0.90
        end
    end

    local sandboxMod = 1.0
    if SandboxVars and SandboxVars.AwesomeLockpicking then
        sandboxMod = SandboxVars.AwesomeLockpicking.SuccessChanceModifier or 1.0
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
        if target.setLockedByKey then target:setLockedByKey(false) end
        -- if target.setLocked then target:setLocked(false) end
        if target.setIsLocked then target:setIsLocked(false) end
        if target.ToggleDoor then target:ToggleDoor(playerObj) end

        xpGain = 20
    elseif isServer() then -- fail from server, send halo note text to client
        sendServerCommand(playerObj, commands.ALModule, commands.setHaloNoteClient,
            {text = "IGUI_ingame_LockpickingTaskFailed"})
    else
        playerObj:setHaloNote(getText("IGUI_ingame_LockpickingTaskFailed"))
    end

    local settings = SandboxVars and SandboxVars.AwesomeLockpicking
    if not settings then
        print("[ERROR] AwesomeLockpicking - could not retrieve sandbox settings in applyLockpickAttempt")
        return
    end

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * xpGain, false, true, false)
end


---------- Enums ----------
local CommandList = {
    ALModule = "ALModule",
    applyLockpickAttemptServer = "applyLockpickAttemptServer",
    setHaloNoteClient = "setHaloNoteClient"
}

local ALPickableObjectType = {
    WorldDoor = "WorldDoor",
    PlayerDoor = "PlayerDoor",
    VehicleDoor = "VehicleDoor",
    None = "None"
}

---------- Exports ----------
ALSharedUtils.applyLockpickAttempt = applyLockpickAttempt
ALSharedUtils.CommandList = CommandList
ALSharedUtils.ALPickableObjectType = ALPickableObjectType