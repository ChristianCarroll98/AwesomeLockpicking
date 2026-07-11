ALSharedUtils = ALSharedUtils or {}

local function applyLockpickAttempt(player, target, tool)
    if not player or not target or not tool then
        print("[ERROR] AwesomeLockpicking - nil param in applyLockpickAttempt")
        return
    end

    local inv = player:getInventory()
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

    local baseChance = 20 + (player:getPerkLevel(Perks.Lockpicking) * 7)

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
        local maintenanceMod = player:getMaintenanceMod()
        local finalChancePool = baseChancePool + maintenanceMod
        
        if not success then
            finalChancePool = finalChancePool * 0.5
        end

        finalChancePool = math.floor(finalChancePool + 0.5)
        
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

    local commands = ALSharedUtils.ALCommandList

    local xpGain = 10

    if success then
        if (instanceof(target, "IsoDoor") or instanceof(target, "IsoThumpable")) then
            if target.setLockedByKey then target:setLockedByKey(false) end
            if target.ToggleDoor then target:ToggleDoor(player) end
        end
        xpGain = 20
    elseif isServer() then -- fail from server, send halo note text to client
        sendServerCommand(player, commands.ALModule, commands.setHaloNoteClient,
            {text = "IGUI_ingame_LockpickingTaskFailed"})
    else
        player:setHaloNote(getText("IGUI_ingame_LockpickingTaskFailed"))
    end

    player:getXp():AddXP(Perks.Lockpicking, xpGain, false, true, false)
end


---------- Enums ----------
local ALCommandList = {
    ALModule = "ALModule",
    applyLockpickAttemptServer = "applyLockpickAttemptServer",
    setHaloNoteClient = "setHaloNoteClient"
}


---------- Exports ----------
ALSharedUtils.applyLockpickAttempt = applyLockpickAttempt
ALSharedUtils.ALCommandList = ALCommandList