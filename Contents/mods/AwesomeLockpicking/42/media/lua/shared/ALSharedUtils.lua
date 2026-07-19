require 'Vehicles/ISUI/ISVehicleMenu'

ALSharedUtils = ALSharedUtils or {}


---------- exported enums ----------

---@const
---@enum toolTypes
ALSharedUtils.LockpickToolTypes = {
    Screwdriver = "Screwdriver",
    Professional = "Professional",
    Forged = "Forged",
    Invalid = "Invalid"
}

---@const
---@enum targetTypes
ALSharedUtils.LockpickableObjectTypes = {
    WorldDoor = "WorldDoor",
    PlayerDoor = "PlayerDoor",
    VehicleDoor = "VehicleDoor",
    Invalid = "Invalid"
}


---------- exported helper functions ----------

---Returns tool type enum from object for easy checking
---@param tool InventoryItem|nil
---@return toolTypes
function ALSharedUtils.getLockpickToolTypeFromObj(tool)
    if not tool then return ALSharedUtils.LockpickToolTypes.Invalid end
    local toolType = tool:getFullType()

    if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
        return ALSharedUtils.LockpickToolTypes.Professional

    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        return ALSharedUtils.LockpickToolTypes.Forged

    elseif tool:hasTag(ItemTag.get(ResourceLocation.new("base", "screwdriver"))) then
        return ALSharedUtils.LockpickToolTypes.Screwdriver
    end

    return ALSharedUtils.LockpickToolTypes.Invalid
end


---Returns target type enum from object for easy checking
---@param target IsoDoor|IsoThumpable|VehiclePart|nil
---@return targetTypes
function ALSharedUtils.getTargetTypeFromObj(target)
    if not target then return ALSharedUtils.LockpickableObjectTypes.Invalid end

    if instanceof(target, "IsoDoor") then
        return ALSharedUtils.LockpickableObjectTypes.WorldDoor

    elseif instanceof(target, "IsoThumpable") and target.isDoor and target:isDoor() then
        return ALSharedUtils.LockpickableObjectTypes.PlayerDoor

    elseif instanceof(target, "VehiclePart") then
        return ALSharedUtils.LockpickableObjectTypes.VehicleDoor
    end

    return ALSharedUtils.LockpickableObjectTypes.Invalid
end
