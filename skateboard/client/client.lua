--- ============================
---          Constants
--- ============================

--- @class Skateboard
local Skateboard = {
    vehicle = nil,           -- The vehicle entity used underneath so the player can ride the skateboard
    board = nil,             -- The skateboard object that the player stands on
    speed = 0.0,             -- The speed of the vehicle
    playerPed = nil,         -- The player ped
    driverDummy = nil,       -- The npc ped to use for driving the vehicle (so the player won't do the animations)
    isMounted = false,       -- Determines if the player is attached to the skateboard
    isMaxSpeed = false,      -- Determines if the skateboard is at max speed
    waitTime = 1,            -- The wait time for threads
    upHillPitch = 1.0,       -- The pitch used to determine whether the vehicle is uphill
    downHillPitch = -1.0,    -- The pitch used to determine whether the vehicle is downhill
    momentumBase = 10.0,     -- The base number to divide the speed by to determine whether the vehicle should keep moving
    momentumIncrement = 0.2, -- The number used to increase the base momentum
    airRotation = 0.0,       -- z rotation
    airRotationMin = 1.5,    -- Min z rotation
    airRotationMax = 4.0,    -- Max z rotation
    zTick = 0.02             -- Rate that z rotation changes
}

local VehicleModel = 'bmx'                   -- The model used for the vehicle underneath
local BoardModel = 'p_defilied_ragdoll_01_s' -- The board prop model
local DriverDummyModel = 'a_c_rabbit_01'     -- The ped model to use for driving the skateboard
-- local DriverDummyModel = 'a_c_cat_01'        -- The ped model to use for driving the skateboard
-- local DriverDummyModel = 'a_f_m_bevhills_01' -- The ped model to use for driving the skateboard

--- @enum EntityType
local EntityType = {
    Vehicle = 1,
    Object = 2,
    Ped = 3,
}

--- @enum Keys
local Keys = {
    LeftShift = 21,
    Spacebar = 22,
    W = 32,
    S = 33,
    A = 34,
    D = 35,
    E = 38,
    G = 113
}

--- Make enum for the Task Movements
local VehicleAction = {
    Brake = 1,
    BrakePlusReverse = 3,
    TurnLeftPlusBrake = 4,
    TurnRightPlusBrake = 5,
}


--- ============================
---           Animator
--- ============================

--- enum
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
        lean = { name = 'idle', dictionary = 'move_strafe@stealth', flag = AnimationFlags.ANIM_FLAG_REPEAT },
        jump = { name = 'idle_intro', dictionary = 'move_crouch_proto', flag = AnimationFlags.ANIM_FLAG_REPEAT },
        sprint = { name = 'sprint', dictionary = 'move_crouch_proto', flag = AnimationFlags.ANIM_FLAG_NORMAL },
        -- sprint = { name = 'idle_intro', dictionary = 'anim@move_f@grooving@', flag = AnimationFlags.ANIM_FLAG_NORMAL },
    },
}

--- Wait until animation is loaded
--- @param dictionary string
function requestAnimation(dictionary)
    RequestAnimDict(dictionary)
    repeat
        Wait(100)
    until HasAnimDictLoaded(dictionary)

    return true
end

--- Unload animations
--- @param animations table
function unloadAnimations(animations)
    for _, value in pairs(animations) do
        RemoveAnimDict(value.dictionary)
    end
end

--- Load animations
--- @param animations table
function loadAnimations(animations)
    for _, value in pairs(animations) do
        if not HasAnimDictLoaded(value.dictionary) then
            requestAnimation(value.dictionary)
        end
    end
end

--- Load the animation then play
--- @param entity number
--- @param animation table
--- @return number animDuration
function executeAnimation(entity, animation)
    -- waitForAnimation(animation.dictionary)
    TaskPlayAnim(entity, animation.dictionary, animation.name,
        8.0, 8.0, -1, animation.flag,
        0.0, false, false, false)

    return GetAnimDuration(animation.dictionary, animation.name)
end

--- ============================
---           Helpers
--- ============================

--- Get vehicle speed
--- @return boolean
function isMaxSpeed()
    return Skateboard.speed > Config.MaxSpeedKmh
end

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

    -- Disable collision for the vehicle
    SetEntityCollision(Skateboard.vehicle, false, false)

    -- Disable collision between the vehicle and the dummy
    SetEntityNoCollisionEntity(Skateboard.vehicle, Skateboard.driverDummy, false)

    -- Disable collision between the vehicle and the player
    SetEntityNoCollisionEntity(Skateboard.vehicle, Skateboard.playerPed, false)
end

function initializeBoard(playerForwardCoords)
    -- Create the skateboard prop
    Skateboard.board = createEntity(EntityType.Object, BoardModel, playerForwardCoords, 0, true)

    -- Attach the skateboard prop to the vehicle
    AttachEntityToEntity(Skateboard.board, Skateboard.vehicle, GetPedBoneIndex(Skateboard.playerPed, PH_R_Hand),
        0.0, 0.0, -0.40,
        0.0, 0.0, 90.0,
        false, true, true, true, 2, true)
end

function initializeDummyDriver(playerForwardCoords, playerHeading)
    -- Create the dummy driver
    -- Should the dummy driver be local only?
    Skateboard.driverDummy = createEntity(EntityType.Ped, DriverDummyModel, playerForwardCoords, playerHeading, true)

    SetEntityVisible(Skateboard.driverDummy, false, false)
    SetEntityCollision(Skateboard.driverDummy, false, false)
    SetEnableHandcuffs(Skateboard.driverDummy, true)
    SetEntityInvincible(Skateboard.driverDummy, true)
    FreezeEntityPosition(Skateboard.driverDummy, true)
    TaskWarpPedIntoVehicle(Skateboard.driverDummy, Skateboard.vehicle, -1)

    -- Stop ped from talking
    StopPedSpeaking(Skateboard.driverDummy, true)
    DisablePedPainAudio(Skateboard.driverDummy, true)
    SetAmbientVoiceName(Skateboard.driverDummy, 'kerry')
end

function putDownBoard()
    -- Attach the vehicle to the player's right hand
    local PH_R_Hand = 28422
    AttachEntityToEntity(Skateboard.vehicle, Skateboard.playerPed, GetPedBoneIndex(Skateboard.playerPed, PH_R_Hand),
        -0.1, -0.1, -0.4,
        90.0, 0.0, 270.0,
        true, true, false, false, 2, true)

    -- Play the animation to put down the skateboard
    local animationTime = executeAnimation(Skateboard.playerPed, Animations.skateboard.pickup1)
    Wait(animationTime * 200)

    -- Detach the vehicle from the player's hand and place it on the ground
    DetachEntity(Skateboard.vehicle, false, true)
    PlaceObjectOnGroundProperly(Skateboard.vehicle)
end

function pickUpBoard()
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
end

--- ============================
---      Skateboard Class
--- ============================

--- Create the skateboard if it doesn't already exist
function Skateboard:start()
    if DoesEntityExist(Skateboard.vehicle) then
        TriggerEvent('QBCore:Notify', 'Skateboard already exists', 'error', 2500)

        -- Detach player and delete all entities
        Skateboard:detachPlayer()
        Skateboard:deleteEntities()
        -- return
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
                TriggerEvent('QBCore:Notify', 'Player is too far, removing skateboard', 'error', 2500)

                -- Detach player and delete all entities
                Skateboard:detachPlayer()
                Skateboard:deleteEntities()
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

            -- Force the vehicle to make no sound
            ForceVehicleEngineAudio(Skateboard.vehicle, '')

            Wait(Skateboard.waitTime)
        end
    end)
end

--- Spawn the skateboard
function Skateboard:spawn()
    -- Load animations
    loadAnimations(Animations.skateboard)

    -- Get the player forward coords
    local playerForwardCoords = getForwardCoordinates(Skateboard.playerPed, 1.0)

    -- Get the player heading
    local playerHeading = GetEntityHeading(Skateboard.playerPed)

    -- Make the vehicle
    initializeVehicle(playerForwardCoords, playerHeading)

    -- Make the board
    initializeBoard(playerForwardCoords)

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
        -- When "E" is pressed
        if IsControlJustPressed(0, Keys.E) then
            -- Check if player is riding the skateboard
            if Skateboard.isMounted then
                TriggerEvent('QBCore:Notify', 'Can\'t remove skateboard while riding it', 'error', 2500)
            else
                Skateboard:clear()
            end
        end

        -- When "G" is pressed
        if IsControlJustPressed(0, Keys.G) then
            -- Mount or dismount the skateboard
            Skateboard:mount()
        end

        -- Movement controls
        if Skateboard.isMounted then
            -- Get the current speed
            Skateboard.speed = GetEntitySpeed(Skateboard.vehicle) * 3.6

            -- Check if player must ragdoll
            if Skateboard:mustRagdoll() then
                -- local rotation = GetEntityRotation(Skateboard.vehicle)

                -- local msg = string.format("Ragdolling: x = %.2f, y = %.2f, z = %.2f, speed = %.2f",
                --     rotation.x, rotation.y, rotation.z, Skateboard.speed)
                -- TriggerEvent('QBCore:Notify', msg, 'error', 2500)

                Skateboard:detachPlayer()
                SetPedToRagdoll(Skateboard.playerPed, 3000, 2000, 0, true, true, false)
            end

            if not IsEntityInAir(Skateboard.vehicle) then
                -- Spacebar = Jump
                if IsControlPressed(0, Keys.Spacebar) then
                    -- Start the crouch animation
                    TaskPlayAnim(Skateboard.playerPed,
                        Animations.skateboard.jump.dictionary, Animations.skateboard.jump.name,
                        5.0, 8.0, -1, AnimationFlags.ANIM_FLAG_REPEAT, 0.0, false, false,
                        false)

                    -- Get the total duration the player is crouched
                    local duration = 0
                    while IsControlPressed(0, Keys.Spacebar) do
                        Wait(Skateboard.waitTime)
                        duration = duration + 5.0
                    end

                    -- Calculate the jump boost
                    local boost = Config.MaxJumpHeight * duration / 250.0
                    if boost > Config.MaxJumpHeight then boost = Config.MaxJumpHeight end

                    StopAnimTask(Skateboard.playerPed, Animations.skateboard.jump.dictionary,
                        Animations.skateboard.jump.name, 1.0)

                    -- Set the new velocity with the added jump boost
                    local velocity = GetEntityVelocity(Skateboard.vehicle)
                    SetEntityVelocity(Skateboard.vehicle, velocity.x, velocity.y, velocity.z + boost)

                    -- Go back to the lean animation
                    TaskPlayAnim(Skateboard.playerPed,
                        Animations.skateboard.lean.dictionary, Animations.skateboard.lean.name,
                        8.0, 8.0, -1, AnimationFlags.ANIM_FLAG_REPEAT,
                        0.0, false, false, false)

                    -- Initialize z rotation
                    Skateboard.airRotation = Skateboard.airRotationMin
                end

                -- W + LeftShift = Strong acceleration
                if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.LeftShift) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 23, 1.0)

                    -- Start the sprint animation
                    TaskPlayAnim(Skateboard.playerPed,
                        Animations.skateboard.sprint.dictionary, Animations.skateboard.sprint.name,
                        5.0, 8.0, -1, AnimationFlags.ANIM_FLAG_REPEAT, 0.0, false, false,
                        false)

                    -- Hold the animation until left shift is released
                    while IsControlPressed(0, Keys.LeftShift) do
                        Wait(Skateboard.waitTime)
                    end

                    StopAnimTask(Skateboard.playerPed, Animations.skateboard.sprint.dictionary,
                        Animations.skateboard.sprint.name, 1.0)

                    -- Go back to the lean animation
                    TaskPlayAnim(Skateboard.playerPed,
                        Animations.skateboard.lean.dictionary, Animations.skateboard.lean.name,
                        8.0, 8.0, -1, AnimationFlags.ANIM_FLAG_REPEAT,
                        0.0, false, false, false)
                end

                -- If no keys are pressed
                if IsControlReleased(0, Keys.W) or IsControlReleased(0, Keys.S)
                    or IsControlReleased(0, Keys.A) or IsControlReleased(0, Keys.D) then
                    local pitch = GetEntityPitch(Skateboard.vehicle)

                    -- If vehicle is downhill or there's momentum, keep going
                    if pitch < Skateboard.downHillPitch
                        or ((Skateboard.speed / Skateboard.momentumBase) + Skateboard.downHillPitch >= pitch) then
                        if IsControlPressed(0, Keys.A) then
                            -- A = Turn left and accelerate
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 7, 1.0)
                        elseif IsControlPressed(0, Keys.D) then
                            -- D = Turn right and accelerate
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 8, 1.0)
                        else
                            -- Accelerate
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 9, 1.0)
                        end

                        if pitch >= Skateboard.downHillPitch then
                            Skateboard.momentumBase = Skateboard.momentumBase + Skateboard.momentumIncrement
                        else
                            Skateboard.momentumBase = 10.0
                        end

                        -- Vehicle is uphill, reverse
                    elseif pitch >= Skateboard.upHillPitch then
                        if IsControlPressed(0, Keys.A) then
                            -- A = Turn left and reverse
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 13, 1.0)
                        elseif IsControlPressed(0, Keys.D) then
                            -- D = Turn right and reverse
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 14, 1.0)
                        else
                            -- Reverse
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 3, 1.0)
                        end
                    else
                        if IsControlPressed(0, Keys.A) then
                            -- A = Turn left
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 10, 1.0)
                        elseif IsControlPressed(0, Keys.D) then
                            -- D = Turn right
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 11, 1.0)
                        else
                            -- Stop moving
                            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 1, 1.0)
                        end
                    end
                end

                -- If W is just released
                if IsControlJustReleased(0, Keys.W) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 9, 1.0)
                end

                Skateboard.isMaxSpeed = isMaxSpeed()

                -- W = Accelerate
                if IsControlPressed(0, Keys.W) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 9, 1.0)
                end

                -- S = Brake and reverse
                if IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.W)
                    and not IsControlPressed(0, Keys.A) and not IsControlPressed(0, Keys.D) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 3, 1.0)
                end

                -- W + S = Brake
                if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.S)
                    and not IsControlPressed(0, Keys.A) and not IsControlPressed(0, Keys.D) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 1, 1.0)
                end

                -- W + A = Accelerate and turn left
                if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.A)
                    and not IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.D) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 7, 1.0)
                end

                -- S + A = Reverse and turn left
                if IsControlPressed(0, Keys.S) and IsControlPressed(0, Keys.A)
                    and not IsControlPressed(0, Keys.W) and not IsControlPressed(0, Keys.D) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 13, 1.0)
                end

                -- W + D = Accelerate and turn right
                if IsControlPressed(0, Keys.W) and IsControlPressed(0, Keys.D)
                    and not IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.A) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 8, 1.0)
                end

                -- S + D = Reverse and turn right
                if IsControlPressed(0, Keys.S) and IsControlPressed(0, Keys.D) and not
                    IsControlPressed(0, Keys.W) and not IsControlPressed(0, Keys.A) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 14, 1.0)
                end

                -- W + S + A = Brake while turning left
                if IsControlPressed(0, Keys.A) and IsControlPressed(0, Keys.W)
                    and IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.D) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 25, 1.0)
                end

                -- W + S + D = Brake while turning right
                if IsControlPressed(0, Keys.D) and IsControlPressed(0, Keys.W)
                    and IsControlPressed(0, Keys.S) and not IsControlPressed(0, Keys.A) then
                    TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 26, 1.0)
                end
            else
                -- Increase the z rotation value until it reaches max
                if Skateboard.airRotation < Skateboard.airRotationMax then
                    Skateboard.airRotation = Skateboard.airRotation + Skateboard.zTick
                end

                -- A = Rotate left
                if IsControlPressed(0, Keys.A) then
                    SetEntityAngularVelocity(Skateboard.vehicle, 0.0, 0.0, Skateboard.airRotation)
                end

                -- D = Rotate right
                if IsControlPressed(0, Keys.D) then
                    SetEntityAngularVelocity(Skateboard.vehicle, 0.0, 0.0, -Skateboard.airRotation)
                end
            end
        else
            -- Stop the vehicle from moving when not mounted
            TaskVehicleTempAction(Skateboard.driverDummy, Skateboard.vehicle, 1, 1)
        end
    end
end

--- Detach the player from the board
function Skateboard:detachPlayer()
    DetachEntity(Skateboard.playerPed, false, false)
    SetPedRagdollOnCollision(Skateboard.playerPed, false)
    StopAnimTask(Skateboard.playerPed, 'move_strafe@stealth', 'idle', 1.0)
    StopAnimTask(Skateboard.playerPed, 'move_crouch_proto', 'idle_intro', 1.0)

    Skateboard.isMounted = false
end

--- Mount/dismount the skateboard
function Skateboard:mount()
    -- If already mounted then dismount
    if Skateboard.isMounted then
        Skateboard:detachPlayer()
    else
        -- Mount the skateboard
        executeAnimation(Skateboard.playerPed, Animations.skateboard.lean)

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

--- Controls the rotation the makes the player ragdoll
function Skateboard:mustRagdoll()
    local rotation = GetEntityRotation(Skateboard.vehicle)
    local x = rotation.x
    local y = rotation.y
    if (x > 60.0 or y > 60.0 or x < -60.0 or y < -60.0) and Skateboard.speed < 5.0 then
        return true
    end
    if (HasEntityCollidedWithAnything(Skateboard.playerPed) and Skateboard.speed > 30.0) then return true end
    if IsPedDeadOrDying(Skateboard.playerPed, false) then return true end
    return false
end

--- Deletes all the skateboard-related entities
function Skateboard:deleteEntities()
    -- Delete the vehicle
    deleteEntity(Skateboard.vehicle)

    -- Delete the skateboard prop
    deleteEntity(Skateboard.board)

    -- Delete the driver dummy
    deleteEntity(Skateboard.driverDummy)
end

--- Make all skateboard-related values nil
function Skateboard:resetValues()
    Skateboard.vehicle = nil
    Skateboard.board = nil
    Skateboard.driverDummy = nil
end

--- Remove the skateboard
function Skateboard:clear()
    -- Do the pick up skateboard animation
    pickUpBoard()

    -- Delete the entities
    Skateboard:deleteEntities()

    -- Reset skateboard values
    Skateboard:resetValues()

    -- Unload animations
    unloadAnimations(Animations.skateboard)
end

--- ============================
---          NetEvents
--- ============================
RegisterNetEvent('skateboard:start', function()
    Skateboard.playerPed = PlayerPedId()
    Skateboard:start()
end)

AddEventHandler('baseevents:onPlayerDied', function()
    if Skateboard.vehicle then
        TriggerEvent('QBCore:Notify', 'Player died, removing skateboard', 'error', 2500)
        Skateboard:detachPlayer()
        Skateboard:deleteEntities()
    end
end)
