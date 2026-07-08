---------- Lockpicking Timed Action Helper Functions ----------
local function getValidScrewdriver(inv)
    if not inv then return nil end

    local tag = ItemTag.get(ResourceLocation.new("base", "screwdriver"))
    if not tag then return nil end

    local foundItems = ArrayList.new()
    inv:getAllTagRecurse(tag, foundItems)

    for i = 0, foundItems:size() - 1 do
        local item = foundItems:get(i)
        if item then
            local cond = item:getCondition()
            if cond == nil or cond > 0 then
                return item
            end
        end
    end

    return nil
end

local function getValidLockpickTool(playerObj)
    if not playerObj then return nil end

    local inv = playerObj:getInventory()
    if not inv then return nil end

    local tool = inv:getFirstTypeRecurse("AwesomeLockpicking.ProfessionalLockpickingTools")
        or inv:getFirstTypeRecurse("AwesomeLockpicking.ForgedLockpickingTools")

    if not tool then
        local hasPaperclip = inv:containsTypeRecurse("Base.Paperclip")
        if not hasPaperclip then
            return nil
        end

        local screwdriver = getValidScrewdriver(inv)
        if hasPaperclip and screwdriver then
            tool = screwdriver
        end
    end

    return tool
end

local function getTargetFromArgs(args)
    if not args then return nil end

    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(args.x, args.y, args.z)
    if not square then return nil end

    local target = nil
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                if args.objectType == "IsoDoor" and instanceof(obj, "IsoDoor") then
                    target = obj
                    break
                elseif args.objectType == "IsoThumpable" and instanceof(obj, "IsoThumpable") then
                    target = obj
                    break
                elseif args.objectType == "VehiclePart" and instanceof(obj, "VehiclePart") then
                    target = obj
                    break
                end
            end
        end
    end

    return target
end

--next time: 

local function applyLockpickAttempt(player, target, tool)
    if not player or not target or not tool then return end

    local skillLevel = player:getPerkLevel(Perks.Lockpicking)
    local toolBonus = 1.1
    local toolType = "screwdriver"

    local inv = player:getInventory()
    if not inv then return end

    if inv:getFirstTypeRecurse("AwesomeLockpicking.ProfessionalLockpickingTools") then
        toolType = "professional"
        toolBonus = 1.35
    elseif inv:getFirstTypeRecurse("AwesomeLockpicking.ForgedLockpickingTools") then
        toolType = "forged"
        toolBonus = 1.20
    end

    local baseChance = 10 + (skillLevel * 8)

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
    if SandboxVars and SandboxVars.AwesomeLockpicking and SandboxVars.AwesomeLockpicking.SuccessChanceModifier then
        sandboxMod = SandboxVars.AwesomeLockpicking.SuccessChanceModifier
    end

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod
    finalChance = math.max(5, finalChance)

    local success = ZombRand(100) < finalChance

    if tool and tool:getCondition() > 0 then
        local baseChancePool = tool:getConditionLowerChance()
        local maintenanceMod = player:getMaintenanceMod()
        local finalChancePool = baseChancePool + maintenanceMod

        if not success then
            finalChancePool = finalChancePool * 0.5
        end

        if ZombRand(math.max(1, math.floor(finalChancePool))) == 0 then
            tool:setCondition(tool:getCondition() - 1)
            inv:setDrawDirty(true)
        end
    end

    if toolType == "screwdriver" then
        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip")
        if paperclip then
            local removePaperclipChance = success and 10 or 25
            if ZombRand(100) < removePaperclipChance then
                inv:Remove(paperclip)
            end
        end
    end

    local baseXP = 3
    if success then
        if (instanceof(target, "IsoDoor") or instanceof(target, "IsoThumpable")) then
            target:setLockedByKey(false)
            target:ToggleDoor(player)
        end
        baseXP = 10
    else
        player:Say("failed...")
    end

    player:getXp():AddXP(Perks.Lockpicking, baseXP * skillLevel)
end


---------- Skill Books Helper Functions ----------
local function addSkillBooks()
    SkillBook["Lockpicking"] = {}
    SkillBook["Lockpicking"].perk = Perks.Lockpicking
    SkillBook["Lockpicking"].maxMultiplier1 = 3
    SkillBook["Lockpicking"].maxMultiplier2 = 5
    SkillBook["Lockpicking"].maxMultiplier3 = 8
    SkillBook["Lockpicking"].maxMultiplier4 = 12
    SkillBook["Lockpicking"].maxMultiplier5 = 16
end


---------- Other Helper Functions ----------
local function manageSpawnItems(player)
    if not player then return end
    if tostring(player:getDescriptor():getCharacterProfession()) ~= "awesomelockpicking:masterlocksmith" then return end
    player:getInventory():addItem(instanceItem("AwesomeLockpicking.ProfessionalLockpickingTools"))
end

---------- Exports ----------
AwesomeLockpickingUtils = AwesomeLockpickingUtils or {}
AwesomeLockpickingUtils.getValidLockpickTool = getValidLockpickTool
AwesomeLockpickingUtils.getTargetFromArgs = getTargetFromArgs
AwesomeLockpickingUtils.applyLockpickAttempt = applyLockpickAttempt
AwesomeLockpickingUtils.addSkillBooks = addSkillBooks
AwesomeLockpickingUtils.manageSpawnItems = manageSpawnItems