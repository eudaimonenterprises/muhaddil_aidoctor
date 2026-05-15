if Config.FrameWork == "auto" then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = "esx"
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = "qb"
    else
        print('===NO SUPPORTED FRAMEWORK FOUND===')
    end
elseif Config.FrameWork == "esx" and GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
    Framework = "esx"
elseif Config.FrameWork == "qb" and GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    Framework = "qb"
else
    print('===NO SUPPORTED FRAMEWORK FOUND===')
end

lib.locale()

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
            type = type2 or "info",
        })
    else
        if Framework == 'qb' then
            QBCore.Functions.Notify(msg, type2, time)
        elseif Framework == 'esx' then
            TriggerEvent('esx:showNotification', msg, type2, time)
        end
    end
end

local function TriggerFWCallback(name, cb, ...)
    if Framework == 'esx' then
        ESX.TriggerServerCallback(name, cb, ...)
    elseif Framework == 'qb' then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    end
end

local function RevivePlayer()
    local ped = PlayerPedId()

    if Framework == 'esx' then
        TriggerEvent('esx_ambulancejob:revive')
    elseif Framework == 'qb' then
        TriggerEvent('hospital:client:Revive')
        TriggerServerEvent('hospital:server:SetDeathStatus', false)
        TriggerServerEvent('hospital:server:SetLaststandStatus', false)
    end

    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end

local function IsPlayerDead()
    local playerPed = PlayerPedId()

    if IsEntityDead(playerPed) then
        return true
    end

    if Config.CustomAmbulanceEvent == 'osp' then
        isDead = exports["osp_ambulance"]:isDead()
        return isDead
    elseif Config.CustomAmbulanceEvent == 'wasabi' then
        isDead = exports["wasabi_ambulance"]:isPlayerDead()
        return isDead
    end

    if Framework == 'qb' then
        local data = QBCore.Functions.GetPlayerData()
        return data.metadata.isdead or data.metadata.inlaststand
    elseif Framework == 'esx' then
        return isDead
    end

    return false
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
    local tries = 30
    for i = 1, tries do
        local angle = math.random() * 2.0 * math.pi
        local distance = math.random(minDistance, maxDistance)
        local offset = vector3(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
            0.0
        )
        local testPos = origin + offset
        local found, nodePos, heading = GetClosestVehicleNodeWithHeading(testPos.x, testPos.y, testPos.z, 1, 3.0, 0)
        if found then
            return nodePos, heading
        end
    end
    return nil, nil
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

if Framework == 'esx' then
    RegisterNetEvent('esx:onPlayerDeath', function()
        isDead = true
    end)

    RegisterNetEvent('esx_ambulancejob:revive', function()
        isDead = false
    end)
elseif Framework == 'qb' then
    RegisterNetEvent('hospital:client:SetDeathStatus', function(status)
        isDead = status
    end)

    RegisterNetEvent('hospital:client:Revive', function()
        isDead = false
    end)
end

RegisterCommand("aidoctor", function()
    if isServiceActive then
        Notify(locale('notification_title'), locale('service_active'), 5000, "error")
        return
    end

    if not IsPlayerDead() then
        Notify(locale('notification_title'), locale('no_assistance_needed'), 5000, "error")
        return
    end

    TriggerFWCallback('muhaddil_aidoctor:checkConditions', function(EMSOnline, hasMoney)
        if EMSOnline > Config.EMS then
            isServiceActive = false
            Notify(locale('notification_title'), locale('too_many_ems'), 5000, "error")
        elseif not hasMoney then
            isServiceActive = false
            Notify(locale('notification_title'), locale('not_enough_money', Config.Price), 5000, "error")
        else
            if isServiceActive then return end
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
    currentDoctor = CreatePedInsideVehicle(currentAmbulance, 4, pedHash, -1, true, false)

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

    TaskVehicleDriveToCoord(currentDoctor, currentAmbulance, playerCoords.x, playerCoords.y, playerCoords.z,
        Config.DriveSpeedLevel, 0, vehicleHash, Config.AmbulanceDriveFlag, 2.0, true)

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

            if distance < 20.0 then
                TaskVehicleTempAction(currentDoctor, currentAmbulance, 27, 2000)
                Wait(2000)

                TaskLeaveVehicle(currentDoctor, currentAmbulance, 0)
                Wait(3000)

                ClearPedTasksImmediately(currentDoctor)
                SetPedCanBeKnockedOffVehicle(currentDoctor, 1)

                local cprPos, doctorHeading = GetCPRPosition(playerPed)
                TaskGoToCoordAnyMeans(currentDoctor, cprPos.x, cprPos.y, cprPos.z, 1.5, 0, 0, 786603, 0xbf800000)

                local docArrived = false
                while not docArrived and isServiceActive do
                    Wait(250)
                    local docCoords = GetEntityCoords(currentDoctor)
                    local docDist = #(docCoords - cprPos)

                    if docDist < 2.0 then
                        docArrived = true
                        ClearPedTasksImmediately(currentDoctor)

                        SetEntityCoords(currentDoctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
                        SetEntityHeading(currentDoctor, doctorHeading)
                        Wait(300)

                        ReviveSequence(currentDoctor, currentAmbulance)
                    end
                end
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
        disable = { move = true, car = true, combat = true, mouse = true },
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
        disable = { move = true, car = true, combat = true, mouse = true },
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
        disable = { move = true, car = true, combat = true, mouse = true },
    })

    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    Wait(100)

    -- TaskPlayAnimAdvanced(doctor,
    --     "amb@medic@standing@tendtodead@base", "base",
    --     cprPos.x, cprPos.y, cprPos.z,
    --     0.0, 0.0, doctorHeading,
    --     8.0, 8.0, -1, 49, 0.0, 2, 0
    -- )

    -- lib.progressBar({
    --     duration = 4000,
    --     label = locale('applying_defibrillator'),
    --     useWhileDead = true,
    --     canCancel = false,
    --     disable = { move = true, car = true, combat = true, mouse = true },
    -- })

    ClearPedTasks(doctor)
    SetEntityCoords(doctor, cprPos.x, cprPos.y, cprPos.z, false, false, false, false)
    SetEntityHeading(doctor, doctorHeading)
    TaskTurnPedToFaceEntity(doctor, playerPed, 1000)

    Wait(500)

    DoScreenFadeOut(800)
    Wait(1000)

    RevivePlayer()
    SetEntityHealth(playerPed, 140)
    isDead = false

    RequestAnimDict("get_up@directional@movement@from_knees@action")
    while not HasAnimDictLoaded("get_up@directional@movement@from_knees@action") do Wait(10) end
    TaskPlayAnim(playerPed, "get_up@directional@movement@from_knees@action", "getup_l_0", 2.0, 2.0, -1, 0, 0, false,
        false, false)

    Wait(1000)
    DoScreenFadeIn(1000)
    Wait(2500)

    ClearPedTasks(playerPed)

    Notify(locale('notification_title'), locale('stabilized_transferring'), 5000, "success")

    local seatCoords = GetWorldPositionOfEntityBone(ambulance, GetEntityBoneIndexByName(ambulance, "door_pside_r"))
    local seatCoordsD = GetWorldPositionOfEntityBone(ambulance, GetEntityBoneIndexByName(ambulance, "door_pside_f"))

    TaskGoToCoordAnyMeans(doctor, seatCoordsD.x, seatCoordsD.y, seatCoordsD.z, 1.5, 0, 0, 786603, 0xbf800000)

    RequestAnimSet("move_m@injured")
    while not HasAnimSetLoaded("move_m@injured") do Wait(10) end
    SetPedMovementClipset(playerPed, "move_m@injured", 0.2)

    TaskGoToCoordAnyMeans(playerPed, seatCoords.x, seatCoords.y, seatCoords.z, 1.0, 0, 0, 786603, 0xbf800000)

    CreateThread(function()
        local reached = false
        local timeout = 0

        while not reached and timeout < 200 do
            Wait(50)
            timeout = timeout + 1
            local playerPos = GetEntityCoords(playerPed)
            local dist = #(playerPos - seatCoords)

            if dist < 5.0 then
                reached = true
                ClearPedTasksImmediately(playerPed)
                ResetPedMovementClipset(playerPed, 0)

                TaskWarpPedIntoVehicle(playerPed, ambulance, 2)
                Wait(500)

                TaskWarpPedIntoVehicle(doctor, ambulance, -1)
                Wait(1000)

                SetEntityInvincible(playerPed, true)
                FreezeEntityPosition(playerPed, true)

                CreateThread(function()
                    while GetVehiclePedIsIn(playerPed, false) == ambulance and isServiceActive do
                        Wait(0)
                        DisableControlAction(0, 24, true)  -- Atacar
                        DisableControlAction(0, 25, true)  -- Apuntar
                        DisableControlAction(0, 21, true)  -- Correr
                        DisableControlAction(0, 22, true)  -- Saltar
                        DisableControlAction(0, 23, true)  -- Entrar vehículo
                        DisableControlAction(0, 73, true)  -- Salir vehículo
                        DisableControlAction(0, 75, true)  -- Salir vehículo
                        DisableControlAction(0, 105, true) -- Acelerar
                        DisableControlAction(0, 32, true)  -- W
                        DisableControlAction(0, 33, true)  -- S
                        DisableControlAction(0, 34, true)  -- A
                        DisableControlAction(0, 35, true)  -- D
                    end
                end)

                local destination = GetClosestHospital()
                if not destination then
                    Notify(locale('notification_title'), locale('no_hospital_configured'), 5000, "error")
                    CleanupService()
                    return
                end

                Notify(locale('notification_title'), locale('en_route_hospital', destination.name), 5000, "info")

                TaskVehicleDriveToCoord(doctor, ambulance, destination.dropOff.x, destination.dropOff.y,
                    destination.dropOff.z,
                    Config.DriveSpeedLevel, 0, GetEntityModel(ambulance), Config.AmbulanceDriveFlag, 2.0, true)

                CreateThread(function()
                    local arrived = false
                    while not arrived and isServiceActive do
                        Wait(500)
                        if not DoesEntityExist(ambulance) then
                            CleanupService()
                            return
                        end

                        local ambPos = GetEntityCoords(ambulance)
                        if #(ambPos - vector3(destination.dropOff.x, destination.dropOff.y, destination.dropOff.z)) < 20.0 then
                            arrived = true

                            TaskVehicleTempAction(doctor, ambulance, 27, 2000)
                            Wait(2000)

                            DoScreenFadeOut(1000)
                            Wait(1500)

                            TaskLeaveVehicle(playerPed, ambulance, 0)
                            TaskLeaveVehicle(doctor, ambulance, 0)
                            Wait(2000)

                            SetEntityInvincible(playerPed, false)
                            FreezeEntityPosition(playerPed, false)

                            if DoesEntityExist(doctor) then
                                DeletePed(doctor)
                            end
                            if DoesEntityExist(ambulance) then
                                DeleteVehicle(ambulance)
                            end

                            SetEntityCoords(playerPed, destination.respawnSpot.x, destination.respawnSpot.y,
                                destination.respawnSpot.z)
                            SetEntityHeading(playerPed, destination.respawnSpot.w)
                            Wait(500)

                            DoScreenFadeIn(1500)
                            Notify(locale('notification_title'), locale('admitted_hospital', destination.name), 5000,
                                "success")

                            RequestAnimDict("missfam4")
                            while not HasAnimDictLoaded("missfam4") do Wait(10) end
                            TaskPlayAnim(playerPed, "missfam4", "base", 1.0, -1.0, 3000, 0, 0, false, false, false)

                            RevivePlayer()
                            SetEntityHealth(playerPed, 200)

                            CleanupService()
                        end
                    end
                end)
            end
        end

        if timeout >= 200 then
            Notify(locale('notification_title'), locale('transfer_failed'), 5000, "error")
            CleanupService()
        end
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
