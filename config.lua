Config = {}

Config.FrameWork = "qbx"           -- "qbx"
Config.AutoVersionChecker = true    -- Auto check for updates

Config.UseOXNotifications = true    -- Use ox_lib notifications or framework notifications

Config.CustomAmbulanceEvent = 'osp' -- 'osp', 'wasabi'

Config.EMS = 2                      -- Amount of EMS online

Config.EMSJobs = {                  -- Jobs that are counted as EMS
    ambulance = true,
    -- job = true, -- Example: If you have a job named 'doctor' you can add it here
}

Config.Price = 2000 -- Price of the service

Config.SkillCheck = {
    enabled = false,                         -- Enable skill check to reduce price
    difficulty = { 'easy', 'easy', 'medium' }, -- ox_lib skill check difficulty sequence
    inputs = { 'w', 'a', 's', 'd' },         -- Keys for the skill check
    discount = 40,                           -- Percentage discount if skill check is passed (40 = 40% off)
}

-- 787004 = emergency driving (ignore traffic lights)
-- 786603 = Normal driving with traffic lights
Config.AmbulanceDriveFlag = 787004

-- 30.0 = ~108 km/h
-- 40.0 = ~144 km/h
-- 55.0 = ~198 km/h
Config.DriveSpeedLevel = 55.0

Config.RemoveItemsOnRevive = false -- Remove items on revive

-- dropOff = Where the ambulance stops
-- respawnSpot = Where the player respawns after the fade
Config.DropOffSpots = {
    -- === YOUR ORIGINAL HOSPITALS ===
    ['Centro Médico Ocean'] = {
        dropOff = vector4(-1808.7, -326.16, 43.3, 51.79),
        respawnSpot = vector4(-1863.86, -332.91, 49.44, 337.99)
    },
    ['Hospital Sandy Shores'] = {
        dropOff = vector4(1752.8639, 3619.6001, 33.8761, 304.3448),
        respawnSpot = vector4(1760.18, 3635.23, 35.14, 31.79)
    },
    ['Hospital Paleto Bay'] = {
        dropOff = vector4(-247.01, 6331.24, 32.43, 222.88),
        respawnSpot = vector4(-254.88, 6324.50, 32.58, 315.00)
    },

    -- === NEW REALISTIC STANDBY LOCATIONS (SPAWN AT DRIVWAYS) ===

    -- Downtown Hub: Spawns the ambulance right outside the main city center fire station doors.
    ['Estación Central de Bomberos'] = {
        dropOff = vector4(211.23, -1648.51, 29.35, 320.0), 
        respawnSpot = vector4(-1863.86, -332.91, 49.44, 337.99) -- Respawns at Ocean hospital fallback
    },

    -- North City Hub: Spawns the ambulance in the driveway of the prominent 3-bay Rockford Hills firehouse.
    ['Estación de Bomberos Rockford Hills'] = {
        dropOff = vector4(-641.53, -121.72, 38.0, 115.0), 
        respawnSpot = vector4(-1863.86, -332.91, 49.44, 337.99) -- Respawns at Ocean hospital fallback
    },

    -- South City Hub: Spawns right outside the Davis Fire Station complex on Macdonald Street.
    ['Estación de Bomberos Davis'] = {
        dropOff = vector4(346.24, -1451.32, 29.28, 45.0), 
        respawnSpot = vector4(-1863.86, -332.91, 49.44, 337.99) -- Respawns at Ocean hospital fallback
    },

    -- East City Hub: Spawns on Capital Boulevard right next to Fire Station 7 in El Burro Heights.
    ['Estación de Bomberos El Burro'] = {
        dropOff = vector4(1194.27, -1464.01, 34.84, 0.0), 
        respawnSpot = vector4(-1863.86, -332.91, 49.44, 337.99) -- Respawns at Ocean hospital fallback
    }
}