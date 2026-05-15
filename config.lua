Config = {}

Config.FrameWork = "auto"           -- "auto", "esx", "qb"
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
}
