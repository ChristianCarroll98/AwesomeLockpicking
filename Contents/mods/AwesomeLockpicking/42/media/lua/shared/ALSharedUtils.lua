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

---@const
---@enum logLevels
ALSharedUtils.ALLogLevel = {
    TRACE = 1, -- highly granular, may log per tick
    DEBUG = 2, -- may log often, helpful for debugging
    INFO = 3, -- log extra information
    WARN = 4, -- something that might be bad happened
    ERROR = 5, -- something definitely bad happened
    FATAL = 6 -- something catastrophc happened - we are cooked
}

---@const
local LogLevelStrings = {
    "[TRACE] ",
    "[DEBUG] ",
    "[INFO]  ",
    "[WARN]  ",
    "[ERROR] ",
    "[FATAL] "
}

---@const
local LOG_LEVEL = ALSharedUtils.ALLogLevel.TRACE -- ALTODO set manually before run? maybe add sandbox setting?
---@const
local DEFAULT_LOG_LEVEL = ALSharedUtils.ALLogLevel.INFO

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


--- Internal parse function to hide visited and depth variables. ALTODO: not sure if safety checks actually work..
---@param var any
---@param visited table? (Internal use only)
---@param depth number? (Internal use only)
---@return string
local function parseToStringInternal(var, visited, depth)
    if type(var) ~= "table" then
        if type(var) == "string" then return '"' .. var .. '"' end
        return tostring(var)
    end

    -- Initialize or increment tracking variables
    visited = visited or {}
    depth = depth or 1

    -- Hard safety cutoff for deeply nested structures
    if depth > 20 then
        ALSharedUtils.log("Max recursion depth reached while parsing table", ALSharedUtils.ALLogLevel.WARN,
            "ALSharedUtils.parseToStringInternal")
        return "<MaxDepthReached>"
    end

    -- Track circular dependencies to prevent stack overflow crashes
    if visited[var] then
        ALSharedUtils.log("Circular dependency detected while parsing table", ALSharedUtils.ALLogLevel.WARN,
            "ALSharedUtils.parseToStringInternal")
        return "<Circular>"
    end
    visited[var] = true

    local hasItems = false
    local result = "{"

    for key, value in pairs(var) do
        hasItems = true

        local keyStr = type(key) == "string" and ('"' .. key .. '"') or tostring(key)

        -- Pass along the tracking table and increment the depth counter by 1
        result = result .. keyStr .. ": " .. parseToStringInternal(value, visited, depth + 1) .. ", "
    end

    if hasItems then
        -- Remove the very last trailing ", " (last 2 characters) and close the brace
        result = string.sub(result, 1, -3) .. "}"
    else
        -- Handle empty tables safely
        result = "{}"
    end

    visited[var] = nil
    return result
end


--- Checks if table, if so, recursively parses table and returns string representation. If not table, just tostring(var)
---@param var any
---@return string
function ALSharedUtils.parseToString(var)
    return parseToStringInternal(var)
end

--- Custom function to print logs based on log severity level.
---@param content any
---@param logLevel? logLevels
---@param context? string
function ALSharedUtils.log(content, logLevel, context)
    -- Handle missing log level safely
    logLevel = logLevel or DEFAULT_LOG_LEVEL

    if logLevel >= LOG_LEVEL then
        -- Append context string manually if provided since debug.getinfo is disabled
        local contextStr = context and ("." .. context.." - ") or " - "

        print(LogLevelStrings[logLevel] .. "AwesomeLockpicking" .. contextStr .. ALSharedUtils.parseToString(content))
    end
end