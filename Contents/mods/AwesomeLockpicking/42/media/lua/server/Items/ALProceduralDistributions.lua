require 'Vehicles/VehicleDistributions'
require 'Items/ProceduralDistributions'


local locksmithVan = VehicleDistributions["Van_LocksmithTruckBed"]
table.insert(locksmithVan.items, "AwesomeLockpicking.ProfessionalLockpickingTools")
table.insert(locksmithVan.items, 20)


local weights = {0.5, 1, 1, 0.5, 0.5, 1, 2, 1.5, 1, 2, 1.5, 1, 0.5, 1.5, 1, 0.5, 0.5, 0.5, 2, 1, 1, 1, 0.5, 0.5, 5}

local toolTargetLocations = {
    "ArmyBunkerLockers",
    "ArmyHangarMechanics",
    "ArmyHangarTools",
    "ArmyStorageElectronics",
    "ArmyStorageGuns",
    "ArmySurplusTools",
    "Antiques",
    "MechanicShelfTools",
    "MechanicShelfMisc",
    "ToolStoreTools",
    "ToolStoreMisc",
    "GarageTools",
    "GarageMetal",
    "SecurityLockers",
    "PoliceLockers",
    "PoliceDesk",
    "GunStoreCounter",
    "GunStoreShelf",
    "HardwareStoreTools",
    "MetalshopTools",
    "WeldingWorkshopTools",
    "WireFactoryTools",
    "UniversityStorageScience",
    "WoodcraftDudeCounter",
    "ToolStoreKeymaking"
}

for i, distribution in ipairs(toolTargetLocations) do
    local list = ProceduralDistributions["list"][distribution]
    if list and list.items then
        table.insert(list.items, "AwesomeLockpicking.ProfessionalLockpickingTools")
        table.insert(list.items, weights[i])
    end
end

local bookData = {
    {name = "AwesomeLockpicking.BookLockpicking1", weights = {8, 10, 2, 4, 6, 4, 2, 6, 8, 6}},
    {name = "AwesomeLockpicking.BookLockpicking2", weights = {6, 8, 4, 3, 4, 3, 2, 4, 6, 4}},
    {name = "AwesomeLockpicking.BookLockpicking3", weights = {4, 6, 8, 2, 3, 2, 1, 3, 4, 3}},
    {name = "AwesomeLockpicking.BookLockpicking4", weights = {2, 4, 6, 1, 2, 1, 1, 2, 2, 2}},
    {name = "AwesomeLockpicking.BookLockpicking5", weights = {1, 2, 4, 0.5, 1, 0.5, 0.5, 1, 1, 1}}
}

local bookTargetLocations = {
    "BookstoreBooks",
    "LibraryBooks",
    "UniversityLibrary",
    "PoliceStorageGuns",
    "ArmySurplusLiterature",
    "WardrobeGeneric",
    "WardrobeClassy",
    "Antiques",
    "ToolStoreMisc",
    "HardwareStoreTools"
}

for i, distribution in ipairs(bookTargetLocations) do
    local list = ProceduralDistributions["list"][distribution]
    if list and list.items then
        for _, book in ipairs(bookData) do
            table.insert(list.items, book.name)
            table.insert(list.items, book.weights[i])
        end
    end
end