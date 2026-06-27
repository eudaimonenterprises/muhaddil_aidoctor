lib.locale()

QBXCore = exports.qbx_core
Framework = "qbx"

local isServiceActive = false
local isDead = false
local currentAmbulance = nil
local currentDoctor = nil

local function Notify(msgtitle, msg, time, type2)
    if Config.UseOXNotifications then
        lib.notify({
            title = msgtitle,
            description = msg,
            duration = time or 5000,
            type = type2 or "info"
        })
    else
        QBXCore.Functions.Notify(msg, type2, time)
    end
end
local function TriggerFWCallback(name, cb, ...)
    lib.callback(name, false, cb, ...)
end
local function RevivePlayer()
    local ped = PlayerPedId()

    TriggerEvent('hospital:client:Revive')
    TriggerServerEvent('hospital:server:SetDeathStatus', false)
    TriggerServerEvent('hospital:server:SetLaststandStatus', false)

    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end
local function IsPlayerDead()
    local data = exports.qbx_core:GetPlayerData()
    return data.metadata.isdead or data.metadata.inlaststand
end
function GetClosestHospital()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closest = nil
    local dist = math.huge

    for name, spot in pairs(Config.DropOffSpots) do
        local d = #(playerCoords - vector3(spot.dropOff.x, spot.dropOff.y, spot.dropOff.z))
        if d < dist then
            dist = d
            closest = { name = name, dropOff = spot.dropOff, respawnSpot = spot.respawnSpot }
        end
    end
    return closest
end
local function GetDistantRoadPoint(origin, minDistance, maxDistance)
    -- 1. Locate the nearest configured medical center or standby fire station
    local hospital = GetClosestHospital()
    
    -- Fallback: If no hospital configuration data is found, run your original random search near the player
    if not hospital or not hospital.dropOff then
        local tries = 30
        for i = 1, tries do
            local angle = math.random() * 2.0 * math.pi
            local distance = math.random(minDistance, maxDistance)
            local offset = vector3(math.cos(angle) * distance, math.sin(angle) * distance, 0.0)
            local testPos = origin + offset
            
            -- Keeps your strict vehicle road node filter (0) to ignore sidewalks
            local found, nodePos, heading = GetClosestVehicleNodeWithHeading(testPos.x, testPos.y, testPos.z, 0, 3.0, 0)
            if found then return nodePos, heading end
        end
        return nil, nil
    end

    -- 2. Extract the driveway coordinates from the closest location
    local hospCoords = hospital.dropOff
    
    -- 3. Locate the main vehicular street node (0) closest to that driveway
    -- This guarantees it spawns smoothly on the asphalt directly outside the station doors
    local found, nodePos, heading = GetClosestVehicleNodeWithHeading(hospCoords.x, hospCoords.y, hospCoords.z, 0, 3.0, 0)
    
    if found and nodePos then
        return nodePos, heading
    end

    -- Ultimate safety gate fallback if pathfinding nodes fail
    return vector3(hospCoords.x, hospCoords.y, hospCoords.z), hospCoords.w or 0.0
end


local function CleanupService()
    if currentDoctor and DoesEntityExist(currentDoctor) then
        DeletePed(currentDoctor)
        currentDoctor = nil
    end

    if currentAmbulance and DoesEntityExist(currentAmbulance) then
        DeleteVehicle(currentAmbulance)
        currentAmbulance = nil
    end
    isServiceActive = false
end
local function LoadAnimDicts(dicts)
    for _, dict in ipairs(dicts) do
        RequestAnimDict(dict)
    end
    for _, dict in ipairs(dicts) do
        while not HasAnimDictLoaded(dict) do Wait(10) end
    end
            end
local function GetCPRPosition(patientPed)
    local patientCoords = GetEntityCoords(patientPed)
    local patientHeading = GetEntityHeading(patientPed)
    local headingRad = math.rad(patientHeading)

    local rightX = math.cos(headingRad)
    local rightY = math.sin(headingRad)

    local cprPos = vector3(
        patientCoords.x - rightX * 0.45,
        patientCoords.y - rightY * 0.45,
        patientCoords.z
    )

    local doctorHeading = (patientHeading - 90.0 + 360.0) % 360.0

    return cprPos, doctorHeading
    end

RegisterNetEvent('hospital:client:SetDeathStatus', function(status)
    isDead = status
end)

RegisterNetEvent('hospital:client:Revive', function()
    isDead = false
end)


RegisterNetEvent('muhaddil_aidoctor:triggerClientCommand', function()
    if isServiceActive then
        Notify(locale('notification_title'), locale('service_active'), 5000, "error")
        return
    end

    if not IsPlayerDead() then
        Notify(locale('notification_title'), locale('no_assistance_needed'), 5000, "error")
        return
    end

    -- Use ox_lib's callback system for a structured response
    local response = lib.callback.await('muhaddil_aidoctor:checkConditions', false)

    if not response or not response.status then
        isServiceActive = false
        if response and response.reason == "too_many_ems" then
        Notify(locale('notification_title'), locale('too_many_ems'), 5000, "error")
        elseif response and response.reason == "no_money" then
        Notify(locale('notification_title'), locale('not_enough_money', Config.Price), 5000, "error")
        elseif response and response.reason == "player_not_found" then
            Notify(locale('notification_title'), "Error: Player data not found on server.", 5000, "error")
    else
            Notify(locale('notification_title'), "Error: Unknown condition check issue.", 5000, "error")
            end
    else
        -- If status is true, proceed with the service
        if isServiceActive then return end -- Double check in case of race condition
        isServiceActive = true
        local skillCheckPassed = false
        if Config.SkillCheck and Config.SkillCheck.enabled then
            Notify(locale('notification_title'), locale('skill_check_prompt'), 5000, "info")
            Wait(1000)

            local success = lib.skillCheck(Config.SkillCheck.difficulty, Config.SkillCheck.inputs)

            if success then
                skillCheckPassed = true
                local discountedPrice = math.floor(Config.Price * (1 - Config.SkillCheck.discount / 100))
                Notify(locale('notification_title'),
                    locale('skill_check_success', Config.SkillCheck.discount, discountedPrice), 5000,
                    "success")
            else
                Notify(locale('notification_title'), locale('skill_check_fail', Config.Price), 5000, "error")
                        end

            Wait(1500)
        end

        TriggerServerEvent("muhaddil_aidoctor:chargePlayer", skillCheckPassed)
        TriggerEvent("muhaddil_aidoctor:reviveNPC")
    end
end)


RegisterNetEvent("muhaddil_aidoctor:reviveNPC", function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local vehicleHash = `ambulance`
    local pedHash = `s_m_m_paramedic_01`

    RequestModel(vehicleHash)
    RequestModel(pedHash)
    while not HasModelLoaded(vehicleHash) or not HasModelLoaded(pedHash) do
        Wait(10)
    end

    local minSpawnDistance = 120.0
    local maxSpawnDistance = 200.0

    local spawnPos, heading = GetDistantRoadPoint(playerCoords, minSpawnDistance, maxSpawnDistance)

    if not spawnPos then
        Notify(locale('notification_title'), locale('road_not_found'), 5000, "error")
        isServiceActive = false
        return
    end

    currentAmbulance = CreateVehicle(vehicleHash, spawnPos, heading, true, false)

    if not DoesEntityExist(currentAmbulance) then
        Notify(locale('notification_title'), locale('vehicle_spawn_failed'), 5000, "error")
        isServiceActive = false
        return
    end

    currentDoctor = CreatePedInsideVehicle(currentAmbulance, 4, pedHash, -1, true, false)
    Wait(10) -- Give game time to spawn ped
    if not DoesEntityExist(currentDoctor) then
        -- Fallback: create ped first, then warp
        local tempPed = CreatePed(4, pedHash, playerCoords.x, playerCoords.y, playerCoords.z - 1.0, false, false)
        TaskWarpPedIntoVehicle(tempPed, currentAmbulance, -1)
        currentDoctor = tempPed
    end

    SetEntityInvincible(currentDoctor, true)
    SetPedCanRagdoll(currentDoctor, false)
    SetPedCanRagdollFromPlayerImpact(currentDoctor, false)
    SetPedDiesWhenInjured(currentDoctor, false)
    SetPedSuffersCriticalHits(currentDoctor, false)
    SetPedKeepTask(currentDoctor, true)
    SetBlockingOfNonTemporaryEvents(currentDoctor, true)
    SetPedFleeAttributes(currentDoctor, 0, false)
    SetPedCombatAttributes(currentDoctor, 17, true)
    SetPedCombatAttributes(currentDoctor, 5, false)
    SetPedCombatAttributes(currentDoctor, 46, true)
    SetPedCanBeDraggedOut(currentDoctor, false)
    SetPedCanBeKnockedOffVehicle(currentDoctor, 1)
    SetEntityProofs(currentDoctor, true, true, true, true, true, true, true, true)
    SetPedConfigFlag(currentDoctor, 32, false)
    SetPedConfigFlag(currentDoctor, 281, true)

    SetVehicleSiren(currentAmbulance, true)
    SetSirenWithNoDriver(currentAmbulance, true)
    SetVehicleOnGroundProperly(currentAmbulance)
    SetVehicleHasBeenOwnedByPlayer(currentAmbulance, true)
    SetEntityAsMissionEntity(currentAmbulance, true, true)
    SetEntityAsMissionEntity(currentDoctor, true, true)
    SetPedKeepTask(currentDoctor, true)
    SetBlockingOfNonTemporaryEvents(currentDoctor, true)
    SetPedFleeAttributes(currentDoctor, 0, false)
    SetPedCombatAttributes(currentDoctor, 17, true)

    local ambuBlip = AddBlipForEntity(currentAmbulance)
    SetBlipSprite(ambuBlip, 56)
    SetBlipScale(ambuBlip, 0.9)
    SetBlipColour(ambuBlip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(locale('blip_name'))
    EndTextCommandSetBlipName(ambuBlip)

    CreateThread(function()
        while DoesEntityExist(currentAmbulance) do
            local coords = GetEntityCoords(currentAmbulance)
            SetBlipCoords(ambuBlip, coords)
            Wait(500)
        end
        RemoveBlip(ambuBlip)
    end)

    Notify(locale('notification_title'), locale('ambulance_en_route'), 5000, "success")

    -- === FORCE ALL-TERRAIN EMERGENCY PATHFINDING ===
    SetDriverAbility(currentDoctor, 1.0)        -- 100% Driving skill
    SetDriverAggressiveness(currentDoctor, 0.5) -- Full aggression to push other vehicles
    SetPedConfigFlag(currentDoctor, 281, true)  -- Allowed to drive completely off-road / sidewalks

    -- Flag 786603 tells the AI to navigate wide asphalt streets normally, 
    -- but ignores red lights and stop signs safely.
    local driveAnywhereFlag = 786603 

    TaskVehicleDriveToCoord(
        currentDoctor, 
        currentAmbulance, 
        playerCoords.x, 
        playerCoords.y, 
        playerCoords.z, 
        Config.DriveSpeedLevel or 25.0, -- Safe but fast emergency speed
        0, 
        vehicleHash, 
        smoothEmergencyFlag, 
        4.0, -- Cushioned stop radius
        true
    )

    local meetPos = vector3(playerCoords.x, playerCoords.y, playerCoords.z)

    CreateThread(function()
        while isServiceActive do
            Wait(500)
            if not DoesEntityExist(currentAmbulance) then
                CleanupService()
                Notify(locale('notification_title'), locale('service_interrupted'), 5000, "error")
                return
            end

            local ambCoords = GetEntityCoords(currentAmbulance)
            local distance = #(ambCoords - meetPos)
            
            -- Calculate precise vertical height separation
            local heightDifference = math.abs(ambCoords.z - meetPos.z)
            local currentVehicleSpeed = GetEntitySpeed(currentAmbulance)

            -- === 1. SAME LEVEL ARRIVAL CONDITION ===
            -- Triggers if within 20 meters, or within 45 meters and stopped on the same vertical grid layer
            local arrivedOnSameLevel = (distance < 20.0) or (distance < 45.0 and currentVehicleSpeed < 1.0 and heightDifference <= 7.0)
            
            -- === 2. STRICT UNDERGROUND TUNNEL STOP GATE ===
            -- ONLY flags a tunnel trap if the ambulance is directly below/above you (2D distance < 25.0),
            -- on a completely different level (Z difference > 7.0), AND has come to a COMPLETE STOP (speed < 1.0).
            -- This completely stops the script from triggering prematurely while the driver is passing through mid-route.
            local caughtInTunnelAndStopped = (#(vector2(ambCoords.x, ambCoords.y) - vector2(meetPos.x, meetPos.y)) < 25.0) and (heightDifference > 7.0) and (currentVehicleSpeed < 1.0)

            if arrivedOnSameLevel or caughtInTunnelAndStopped then
                
                SetVehicleSiren(currentAmbulance, false)
                SetSirenWithNoDriver(currentAmbulance, false)

                if caughtInTunnelAndStopped then
                    -- Cleanly delete the underground vehicle asset so it doesn't leave a ghost car block
                    DeleteVehicle(currentAmbulance)
                    currentAmbulance = nil
                    
                    -- Teleport the medic to your surface level, but safely 10 meters away on the plaza tiles 
                    -- to give the AI engine a buffer before executing movement commands
                    SetEntityCoords(currentDoctor, meetPos.x + 10.0, meetPos.y + 10.0, meetPos.z, false, false, false, false)
                    Wait(500) -- Increased wait time to let the physics matrix finalize the surface coordinates
                else
                    -- Normal roadside exit if arrived on the correct street level
                    TaskLeaveVehicle(currentDoctor, currentAmbulance, 0)
                    Wait(2500)
                end

                ClearPedTasksImmediately(currentDoctor)

                -- Force the paramedic to physically route over to your exact body position on foot
                TaskGoToCoordAnyMeans(currentDoctor, meetPos.x, meetPos.y, meetPos.z, 3.0, 0, 0, 786603, 0xbf800000)

                -- LOCK CHECKPOINT: Keep the revival locked until the running medic is right next to you
                local reachedPlayer = false
                local timeout = 0
                while not reachedPlayer and timeout < 400 do 
                    Wait(50)
                    timeout = timeout + 1
                    local docCoords = GetEntityCoords(currentDoctor)
                    if #(docCoords - meetPos) < 3.5 then
                        reachedPlayer = true
                    end
                end
                
                -- Fire the roadside progress bars only after they have safely arrived on foot
                ReviveSequence(currentDoctor, currentAmbulance) 
                break
            end
        end
    end)
end)

function ReviveSequence(doctor, ambulance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local cprPos, doctorHeading = GetCPRPosition(playerPed)

    LoadAnimDicts({
        "amb@medic@standing@kneel@base",
        "amb@medic@standing@kneel@idle_a",
        "amb@medic@standing@tendtodead@base",
        "amb@medic@standing@tendtodead@idle_a",
        "mini@cpr@char_a@cpr_str",
        "get_up@directional@movement@from_knees@action",
    })

    Notify(locale('notification_title'), locale('doctor_arrived'), 3000, "info")

    TaskPlayAnimAdvanced(doctor,
        "amb@medic@standing@kneel@base", "base",
        cprPos.x, cprPos.y, cprPos.z,
        0.0, 0.0, doctorHeading,
        8.0, 8.0, -1, 1, 0.0, 2, 0
    )
    Wait(1500)

    TaskPlayAnimAdvanced(doctor,
        "amb@medic@standing@tendtodead@idle_a", "idle_a",
        cprPos.x, cprPos.y, cprPos.z,
        0.0, 0.0, doctorHeading,
        8.0, 8.0, 4000, 49, 0.0, 2, 0
    )

    lib.progressBar({
        duration = 4000,
        label = locale('examining_patient'),
        useWhileDead = true,
        canCancel = false,
        disable = { move = true, car = true, combat = true, mouse = true }
    })

    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    Wait(200)

    TaskPlayAnimAdvanced(doctor,
        "mini@cpr@char_a@cpr_str", "cpr_pumpchest",
        cprPos.x, cprPos.y, cprPos.z,
        0.0, 0.0, doctorHeading,
        8.0, 8.0, -1, 1, 0.0, 2, 0
    )

    lib.progressBar({
        duration = 6000,
        label = locale('receiving_cpr'),
        useWhileDead = true,
        canCancel = false,
        disable = { move = true, car = true, combat = true, mouse = true }
    })

    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    Wait(100)

    TaskPlayAnim(doctor, "amb@medic@standing@tendtodead@idle_a", "idle_a", 8.0, 8.0, 3000, 49, 0, false, false, false)

    lib.progressBar({
        duration = 3000,
        label = locale('checking_vitals'),
        useWhileDead = true,
        canCancel = false,
        disable = { move = true, car = true, combat = true, mouse = true }
    })

    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    Wait(100)

    ClearPedTasks(doctor)
    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    TaskTurnPedToFaceEntity(doctor, playerPed, 1000)

    Wait(500)

    DoScreenFadeOut(800)
    Wait(1000)

    RevivePlayer()


    TriggerEvent('qbx_medical:client:playerRevived')
    TriggerServerEvent('qbx_medical:server:allHeal')

    SetEntityHealth(playerPed, 200) -- CHANGE THIS to 200 so you are at full health right here
    isDead = false
    isServiceActive = false

    RequestAnimDict("get_up@directional@movement@from_knees@action")
    while not HasAnimDictLoaded("get_up@directional@movement@from_knees@action") do Wait(10) end
    TaskPlayAnim(playerPed, "get_up@directional@movement@from_knees@action", "getup_l_0", 2.0, 2.0, -1, 0, 0, false,
        false, false)

    Wait(1000)
    DoScreenFadeIn(1000)
    Wait(2500)

    ClearPedTasks(playerPed)

    -- 1. Completely break the paramedic out of the healing animation loop
    ClearPedTasks(doctor)
    Wait(500) -- Crucial: gives the game engine a moment to clear the bones assignment

        Notify(locale('notification_title'), "You have been fully treated and revived on the scene!", 5000, "success")

    -- 2. Command the doctor to walk back to the driver's side and get in
    TaskEnterVehicle(doctor, ambulance, -1, -1, 1.5, 1, 0)

    -- 3. Run a background thread to wait until they are driving, then dismiss them
    CreateThread(function()
        local timeout = 0
        
        -- === CHANGE THIS CONDITION ===
        -- Safety first: Make sure the vehicle and doctor exist.
        -- Use "not IsPedInAnyVehicle" so it waits until the door physically clicks shut and they are fully seated.
        while DoesEntityExist(ambulance) and DoesEntityExist(doctor) and not IsPedInAnyVehicle(doctor, false) and timeout < 300 do
            Wait(50)
            timeout = timeout + 1
        end

        -- === ADD THIS SHORT CUSHION ===
        -- Gives the game engine 1 second to load the AI driving brain after the door shuts.
        Wait(1000) 

        -- Stop the thread gracefully if someone deleted the vehicle externally during the walk
        if not DoesEntityExist(ambulance) or not DoesEntityExist(doctor) then return end

        -- Turn off emergency lights/sirens so they look like they are returning to base
        SetVehicleSiren(ambulance, false)
        SetSirenWithNoDriver(ambulance, false)
        
        -- === FIXED BACK-TO-BASE ROUTE (REPLACES WANDER) ===
        -- 1. Grab the closest hospital coordinates again 
        local destination = GetClosestHospital()
        
        -- 2. Turn off the passive event block so they can accept a vehicular routing task smoothly
        SetBlockingOfNonTemporaryEvents(doctor, false)

        -- 3. Command the paramedic to physically shift into gear and drive back to the hospital drop-off point
        -- Flag 786603 tells them to drive like a normal, safe civilian driver returning to base
        if destination and destination.dropOff then
            TaskVehicleDriveToCoord(
                doctor, 
                ambulance, 
                destination.dropOff.x, 
                destination.dropOff.y, 
                destination.dropOff.z, 
                15.0, -- Normal cruising speed (approx 35 MPH)
                0, 
                GetEntityModel(ambulance), 
                786603, 
                5.0, 
                true
            )
        else
            -- Absolute fallback if no config spots exist: wander normally with the event block dropped
            TaskVehicleDriveWander(doctor, ambulance, 15.0, 786603)
        end

        -- === FORCEFUL DISTANCE DESPAWN BACKUP TRACKER ===
        local vehicleToClean = ambulance
        local pedToClean = doctor
        currentAmbulance = nil
        currentDoctor = nil

        SetEntityAsNoLongerNeeded(pedToClean)
        SetEntityAsNoLongerNeeded(vehicleToClean)

        local totalWanderTime = 0
        while DoesEntityExist(vehicleToClean) and totalWanderTime < 60 do 
            Wait(500)
            totalWanderTime = totalWanderTime + 1
            
            local playerPos = GetEntityCoords(PlayerPedId())
            local ambPos = GetEntityCoords(vehicleToClean)
            local currentDistance = #(playerPos - ambPos)

            -- The second they clear 120 meters on their route back to the firehouse/hospital, wipe them cleanly
            if currentDistance > 120.0 then
                if DoesEntityExist(pedToClean) then DeletePed(pedToClean) end
                if DoesEntityExist(vehicleToClean) then DeleteVehicle(vehicleToClean) end
                break
            end
        end

        -- Absolute timeout fallback (e.g., caught at a local red light for 30 seconds right next to you)
        if DoesEntityExist(pedToClean) then DeletePed(pedToClean) end
        if DoesEntityExist(vehicleToClean) then DeleteVehicle(vehicleToClean) end
    end)
end

exports('CallAIDoctor', function()
    ExecuteCommand("aidoctor")
end)

exports('IsServiceActive', function()
    return isServiceActive
end)

exports('IsPlayerDead', function()
    return IsPlayerDead()
end)

exports('CancelService', function()
    if isServiceActive then
        CleanupService()
        Notify(locale('notification_title'), locale('service_cancelled'), 5000, "info")
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupService()
    end
end)


