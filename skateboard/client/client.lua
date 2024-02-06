--- ============================
---          Constants
--- ============================

--- @class Skateboard
local Skateboard = {
    vehicle = 0,       -- The vehicle entity used underneath so the player can ride the skateboard
    board = 0,         -- The skateboard object that the player stands on
    playerPed = 0,     -- The player ped
    driverDummy = 0,   -- The npc ped to use for driving the skateboard (so the player won't do the animations)
    isMounted = false, -- Determines if the player is attached to the skateboard
}

local VehicleModel = 'bmx'                   -- The model used for the vehicle underneath
local BoardModel = 'p_defilied_ragdoll_01_s' -- The board prop model
local DriverDummyModel = 'a_c_cat_01'        -- The ped model to use for driving the skateboard
-- local DriverDummyModel = 'a_f_m_bevhills_01' -- The ped model to use for driving the skateboard

--- @enum EntityType
local EntityType = {
    Vehicle = 1,
    Object = 2,
    Ped = 3,
}

--- @enum Keys
local Keys = {
    W = 32,
    S = 33,
    A = 34,
    D = 35,
    E = 38,
    G = 113
}

--- Make enum for the Task Movements



--- ============================
---           Animator
--- ============================

--- @enum
local AnimationFlags =
{
    ANIM_FLAG_NORMAL = 0,
    ANIM_FLAG_REPEAT = 1,
    ANIM_FLAG_STOP_LAST_FRAME = 2,
    ANIM_FLAG_UPPERBODY = 16,
    ANIM_FLAG_ENABLE_PLAYER_CONTROL = 32,
    ANIM_FLAG_CANCELABLE = 120,
};

local Animations = {
    skateboard =
    {
        putdown = { name = 'putdown_low', dictionary = 'pickup_object', flag = AnimationFlags.ANIM_FLAG_NORMAL, },
        pickup1 = { name = 'pickup_low', dictionary = 'pickup_object', flag = AnimationFlags.ANIM_FLAG_NORMAL, },
        pickup2 = { name = 'pickup_low', dictionary = 'pickup_object', flag = AnimationFlags.ANIM_FLAG_CANCELABLE, },
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

function initializeVehicle(playerForwardCoords, playerHeading)
    -- Create the vehicle underneath the skateboard
    -- Should the vehicle be local only?
    Skateboard.vehicle = createEntity(EntityType.Vehicle, VehicleModel, playerForwardCoords, playerHeading, true)

    -- Make the vehicle invisible
    SetEntityVisible(Skateboard.vehicle, false, false)

    -- Force the vehicle to make no sound
    ForceVehicleEngineAudio(Skateboard.vehicle, '')

    -- Disable collision between the vehicle and the player
    SetEntityNoCollisionEntity(Skateboard.vehicle, Skateboard.playerPed, false)

    -- Disable collision for the vehicle
    SetEntityCollision(Skateboard.vehicle, false, true)
end

function initializeBoard(playerForwardCoords, playerHeading)
    -- Create the skateboard prop
    Skateboard.board = createEntity(EntityType.Object, BoardModel, playerForwardCoords, 0, true)

    -- Attach the skateboard prop to the vehicle
    AttachEntityToEntity(Skateboard.board, Skateboard.vehicle, GetPedBoneIndex(Skateboard.playerPed, PH_R_Hand),
        0.0, 0.0, -0.40,
        0.0, 0.0, 90.0,
        false, true, true, true, 1, true)
end

function putDownBoard()
    -- Attach the vehicle to the player's right hand
    local PH_R_Hand = 28422
    AttachEntityToEntity(Skateboard.vehicle, Skateboard.playerPed, GetPedBoneIndex(Skateboard.playerPed, PH_R_Hand),
        -0.1, 0.0, 0.2,
        70.0, 0.0, 270.0,
        true, true, false, false, 2, true)

    -- Play the animation to put down the skateboard
    local animationTime = executeAnimation(Skateboard.playerPed, Animations.skateboard.pickup1)
    Wait(animationTime * 100)

    -- Detach the vehicle from the player's hand and place it on the ground
    DetachEntity(Skateboard.vehicle, false, true)
    PlaceObjectOnGroundProperly(Skateboard.vehicle)
end

function initializeDummyDriver(playerForwardCoords, playerHeading)
    -- Create the dummy driver
    -- Should the dummy driver be local only?
    Skateboard.driverDummy = createEntity(EntityType.Ped, DriverDummyModel, playerForwardCoords, playerHeading, true)

    SetEntityVisible(Skateboard.driverDummy, false, false)
    SetEnableHandcuffs(Skateboard.driverDummy, true)
    SetEntityInvincible(Skateboard.driverDummy, true)
    FreezeEntityPosition(Skateboard.driverDummy, true)
    TaskWarpPedIntoVehicle(Skateboard.driverDummy, Skateboard.vehicle, -1)
end

--- ============================
---      Skateboard Class
--- ============================

--- Create the skateboard if it doesn't already exist
function Skateboard:start()
    if DoesEntityExist(Skateboard.vehicle) then
        return
    end

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

            Wait(1)
        end
    end)
end

--- Spawn the skateboard
function Skateboard:spawn()
    -- Get the player forward coords
    local playerForwardCoords = getForwardCoordinates(Skateboard.playerPed, 1.0)

    -- Get the player heading
    local playerHeading = GetEntityHeading(Skateboard.playerPed)

    -- Make the vehicle
    initializeVehicle(playerForwardCoords, playerHeading)

    -- Make the board
    initializeBoard(playerForwardCoords, playerHeading)

    -- Do the animation to put down the skateboard
    putDownBoard()

    -- Make the dummy driver
    initializeDummyDriver(playerForwardCoords, playerHeading)

    repeat
        Wait(500)
    until IsPedInVehicle(Skateboard.driverDummy, Skateboard.vehicle, false)
end

--- Handles the controls of the skateboard
--- @param currentDistance number
function Skateboard:handleKeys(currentDistance)
    if currentDistance <= 1.5 then
        if IsControlJustPressed(0, Keys.E) then
            -- Check if player is riding the skateboard
            if Skateboard.isMounted then
                -- Notify the player they can't remove the skateboard while they're riding it
            else
                Skateboard:clear()
            end
        end

        if IsControlJustReleased(0, Keys.G) then
            Skateboard:mount()
        end


        if Skateboard.isMounted then
            local overSpeed = (GetEntitySpeed(Skateboard.vehicle) * 3.6) > Config.MaxSpeedKmh

            -- If no keys are pressed
            if IsControlJustReleased(0, Keys.W) or IsControlJustReleased(0, Keys.S) then
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 1, 500)
            end

            -- W = Accelerate
            if IsControlPressed(0, Keys.W) and not IsControlPressed(0, Keys.S) and not overSpeed then
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 9, 500)
            end

            -- S = Brake and reverse
            if IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.W) then
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 3, 500)
            end

            -- W + A = Turn left
            if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.A) and not overSpeed then
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 7, 500)
            end

            -- W + D = Turn right
            if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.D) then
                TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 8, 500)
            end
        else
            -- Stop the vehicle from moving when not mounted
            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 1, 1)
        end
    end
end

--- Mount/unmount the skateboard
function Skateboard:mount()
    -- If already mounted then, unmount
    if Skateboard.isMounted then
        DetachEntity(Skateboard.playerPed, false, false)
        SetPedRagdollOnCollision(Skateboard.playerPed, false)
        StopAnimTask(Skateboard.playerPed, 'move_strafe@stealth', 'idle', 1.0)
        StopAnimTask(Skateboard.playerPed, 'move_crouch_proto', 'idle_intro', 1.0)

        Skateboard.isMounted = false
    else
        -- Mount the skateboard
        TaskPlayAnim(Skateboard.playerPed, 'move_strafe@stealth', 'idle', 8.0, 8.0, -1, 1, 1.0, false, false, false)

        -- print(tostring(GetPedBoneIndex(Skateboard.playerPed, 52301))) -- SKEL_R_Foot 16
        -- print(tostring(GetPedBoneIndex(Skateboard.playerPed, 20781))) -- SKEL_R_Toe0 17
        -- print(tostring(GetPedBoneIndex(Skateboard.playerPed, 35502))) -- IK_R_Foot 18
        -- print(tostring(GetPedBoneIndex(Skateboard.playerPed, 24806))) -- PH_R_Foot 19
        -- print(tostring(GetPedBoneIndex(Skateboard.playerPed, 34414))) -- 20

        -- Bone index from bone id 34414: https://wiki.rage.mp/index.php?title=Bones
        local boneIndex = 20
        AttachEntityToEntity(Skateboard.playerPed, Skateboard.vehicle, boneIndex,
            0.0, 0, 0.7,
            0.0, 0.0, -15.0,
            true, true, false, true, 2, true)

        SetPedRagdollOnCollision(Skateboard.playerPed, true)

        Skateboard.isMounted = true
    end
end

--- Deletes all the skateboard-related entities
function Skateboard:clear()
    -- Do the pick up animation
    local animationTime = executeAnimation(Skateboard.playerPed, Animations.skateboard.pickup2)
    -- Wait before attaching the skateboard to the player
    Wait(animationTime * 500)

    -- Attach the skateboard to the player's right hand
    local PH_R_Hand = 28422
    AttachEntityToEntity(Skateboard.vehicle, Skateboard.playerPed, GetPedBoneIndex(Skateboard.playerPed, PH_R_Hand),
        -0.1, -0.1, -0.4,
        90.0, 0.0, 270.0,
        true, true, false, false, 2, true)

    -- Wait again after the skateboard's picked up
    Wait(animationTime * 500)

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
