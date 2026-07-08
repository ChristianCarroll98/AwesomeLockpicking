require "AwesomeLockpickingShared"

if isClient() then
    require("AwesomeLockpickingClient")
end

if isServer() then
    require("AwesomeLockpickingServer")
end

print("=======================manageSpawnItems about to be added to OnNewGame")
Events.OnNewGame.Add(AwesomeLockpickingUtils.manageSpawnItems)