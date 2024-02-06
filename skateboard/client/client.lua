--- ============================
---          Constants
--- ============================

--- @class Skateboard
local Skateboard = {
    vehicle = nil,     -- The vehicle entity used underneath so the player can ride the skateboard
    board = nil,       -- The skateboard object that the player stands on
    playerPed = nil,   -- The player ped
    driverDummy = nil, -- The npc ped to use for driving the skateboard (so the player won't do the animations)
    isAttached = nil,  -- Determines if the player is attached to the skateboard
}

local VehicleModel = 'bmx'                   -- The model used for the vehicle underneath
local BoardModel = 'p_defilied_ragdoll_01_s' -- The board prop model
local DriverDummyModel = 's_m_m_ammucountry' -- The ped model to use for driving the skateboard

--- @enum EntityType
local EntityType = {
    Vehicle = 1,
    Object = 2,
    Ped = 3,
}

--- Keys
local KeyE = 38
local KeyG = 113

--- ============================
---           Animator
--- ============================

local ANIM_FLAG_NORMAL = 0

local Animations = {
    skateboard =
    {
        putdown = { name = 'putdown_low', dictionary = 'pickup_object', flag = ANIM_FLAG_NORMAL, },
        pickup = { name = 'pickup_low', dictionary = 'pickup_object', flag = ANIM_FLAG_NORMAL, },
    },
}

--- Wait until animation is loaded
--- @param dictionary string
function waitForAnimation(dictionary)
    RequestAnimDict(dictionary)
    repeat
        Wait(100)
    until HasAnimDictLoaded(dictionary)

    return true
end

--- Load the animation then play
--- @param entity number
--- @param animation table
--- @return number animDuration
function executeAnimation(entity, animation)
    local animDuration = GetAnimDuration(animation.dictionary, animation.name)

    waitForAnimation(animation.dictionary)
    TaskPlayAnim(entity, animation.dictionary, animation.name,
        8.0, 8.0, animDuration, animation.flag,
        0.0, false, false, false)

    return animDuration
end

--- ============================
---           Helpers
--- ============================

--- Get the forward coordinates of the specified entity
--- @param entity number
--- @param multiplier number
--- @return vector3
function getForwardCoordinates(entity, multiplier)
    multiplier = multiplier or 1.0

    local playerCoords = GetEntityCoords(entity)
    local forward = GetEntityForwardVector(entity)
    return (playerCoords + forward * multiplier)
end

--- Load model and wait until finished
--- @param modelHash number
function loadModel(modelHash)
    -- Request the model and wait for it to load
    RequestModel(modelHash)
    repeat
        Wait(100)
    until HasModelLoaded(modelHash)
end

--- Load ped model, create the ped, then release the model
--- @param type EntityType
--- @param model string
--- @param coords vector3
--- @param heading number
--- @param isNetwork boolean
--- @return number obj
function createEntity(type, model, coords, heading, isNetwork)
    coords = coords or vec3(0, 0, 0)
    heading = heading or 0.0
    isNetwork = isNetwork or true

    -- Get the model hash
    local modelHash = GetHashKey(model)

    -- Load the model
    loadModel(modelHash)

    -- Create the entity
    local entity

    if type == EntityType.Vehicle then
        entity = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading,
            isNetwork, false, false)
    elseif type == EntityType.Object then
        entity = CreateObject(modelHash, coords.x, coords.y, coords.z,
            isNetwork, false, false)
    elseif type == EntityType.Ped then
        entity = CreatePed(0, modelHash, coords.x, coords.y, coords.z, heading,
            isNetwork, true)
    end

    -- Release the model
    SetModelAsNoLongerNeeded(modelHash)

    return entity
end

--- Triggers the event to delete the entity on the server-side
--- @param entity number
function deleteEntity(entity)
    TriggerServerEvent('pet-companion:server:deleteEntity', NetworkGetNetworkIdFromEntity(entity))
end

--- ============================
---          Functions
--- ============================

--- Create the skateboard if it doesn't already exist
function Skateboard:start()
    if DoesEntityExist(Skateboard.vehicle) then
        return
    end

    local animationTime = executeAnimation(Skateboard.playerPed, Animations.skateboard.putdown)
    Wait(animationTime * 500)
    Skateboard:spawn()

    -- Thread to check if player is too far from the skateboard
    CreateThread(function()
        while DoesEntityExist(Skateboard.vehicle) do
            local currentDistance = #(GetEntityCoords(Skateboard.playerPed) - GetEntityCoords(Skateboard.vehicle))

            -- If distance is lesser than the lose connection distance
            if currentDistance <= Config.LoseConnectionDistance then
                -- Give player control if not already in control
                if not NetworkHasControlOfEntity(Skateboard.vehicle) then
                    NetworkRequestControlOfEntity(Skateboard.vehicle)
                end
            else
                -- Make the skateboard stop moving for 3 seconds
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 6, 3000)
            end

            Wait(1000)
        end
    end)

    -- Thread to check the player controls for the skateboard
    CreateThread(function()
        while DoesEntityExist(Skateboard.vehicle) do
            local currentDistance = #(GetEntityCoords(Skateboard.playerPed) - GetEntityCoords(Skateboard.vehicle))

            -- Gives control to the player to put down and pick up the skateboard
            Skateboard:handleKeys(currentDistance)

            Wait(0)
        end
    end)
end

--- Spawn the skateboard
function Skateboard:spawn()
    -- Get the player forward coords
    local playerForwardCoords = getForwardCoordinates(Skateboard.playerPed, 1.0)

    -- Get the player heading
    local playerHeading = GetEntityHeading(Skateboard.playerPed)

    -- Create the vehicle underneath the skateboard
    -- Should the vehicle be local only?
    Skateboard.vehicle = createEntity(EntityType.Vehicle, VehicleModel, playerForwardCoords, playerHeading, true)

    -- Create the skateboard prop
    Skateboard.board = createEntity(EntityType.Object, BoardModel, playerForwardCoords, 0, true)

    -- Create the dummy driver
    -- Should the dummy driver be local only?
    Skateboard.driverDummy = createEntity(EntityType.Ped, DriverDummyModel, playerForwardCoords, playerHeading, true)
end

--- Handles the controls of the skateboard
--- @param currentDistance number
function Skateboard:handleKeys(currentDistance)
    if currentDistance <= 1.5 then
        if IsControlJustPressed(0, KeyE) then
            local animationTime = executeAnimation(Skateboard.playerPed, Animations.skateboard.pickup)
            Wait(animationTime * 1000)

            Skateboard:clear()
        end

        if IsControlJustReleased(0, KeyG) then

        end
    end
end

--- Deletes all the skateboard-related entities
function Skateboard:clear()
    -- Delete the vehicle
    deleteEntity(Skateboard.vehicle)

    -- Delete the skateboard prop
    deleteEntity(Skateboard.board)

    -- Delete the driver dummy
    deleteEntity(Skateboard.driverDummy)
end

--- ============================
---          NetEvents
--- ============================
RegisterNetEvent('skateboard:start', function()
    Skateboard.playerPed = PlayerPedId()
    Skateboard:start()
end)

-- AddEventHandler('baseevents:onPlayerDied', function()
--     Skateboard:removePlayer()
-- end)
