lib.locale()

-- QBXCore = exports.qbx_core
FrameWork = 'qbx'

local function GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function GetOnlineEMS()
    local online = 0
    local Players = exports.qbx_core:GetQBPlayers()

    for _, v in pairs(Players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
            online = online + 1
        end
    end
    return online
end

local function GetFinalPrice(skillCheckPassed)
    local minPrice = 1000
    local maxPrice = 2500

    if skillCheckPassed then
        minPrice = minPrice * 0.75
        maxPrice = maxPrice * 0.75
    end

    local randomPrice = math.random(minPrice, maxPrice)
    local finalPrice = math.ceil(randomPrice / 100) * 100 -- Round to nearest hundred

    return finalPrice
end

lib.callback.register('muhaddil_aidoctor:checkConditions', function(source)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)

    if not xPlayer then return { status = false, reason = "player_not_found" } end
        local emsOnline = GetOnlineEMS()
    local cashBalance = xPlayer.PlayerData.money.cash
    local bankBalance = xPlayer.PlayerData.money.bank
    local finalPrice = Config.Price

    if emsOnline > Config.EMS then -- Assuming Config.EMS is your MaxEMS
        return { status = false, reason = "too_many_ems" }
    end

    if cashBalance < finalPrice and bankBalance < finalPrice then
        return { status = false, reason = "no_money" }
        end

    return { status = true, price = finalPrice }
end)

RegisterNetEvent('muhaddil_aidoctor:chargePlayer', function(skillCheckPassed)
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then
        print('^1[AI Doctor] Error: Jugador no encontrado^0')
        return
    end

    local finalPrice = GetFinalPrice(skillCheckPassed == true)
    local charged = false

    local cash = xPlayer.PlayerData.money.cash
    if cash >= finalPrice then
        xPlayer.Functions.RemoveMoney('cash', finalPrice, "ai-doctor-service")
        charged = true
    else
        local bank = xPlayer.PlayerData.money.bank
        if bank >= finalPrice then
            xPlayer.Functions.RemoveMoney('bank', finalPrice, "ai-doctor-service")
            charged = true
        end
    end

    if charged then
        TriggerClientEvent('QBXCore:Notify', src, 'Has sido atendido por el Dr. AI. Se te ha cobrado ' .. string.format("%d", finalPrice) .. '.', 'success')
    else
        TriggerClientEvent('QBXCore:Notify', src, 'No tienes suficiente dinero para ser atendido por el Dr. AI.', 'error')
    end
end)

RegisterNetEvent('muhaddil_aidoctor:setDoctorLocation', function(coords)
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then return end

    local isAdmin = exports.qbx_core:HasPermission(src, 'admin')

    if isAdmin then
        local configFilePath = 'resources/[qb]/muhaddil_aidoctor/config.lua'
        local fileContent = LoadResourceFile(GetCurrentResourceName(), configFilePath)

        if fileContent then
            local newContent = string.gsub(fileContent, 'Config.DoctorLocation = vector3%(-?%d+%.?%d*, -?%d+%.?%d*, -?%d+%.?%d*%)', 'Config.DoctorLocation = vector3(' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z .. ')')
            SaveResourceFile(GetCurrentResourceName(), configFilePath, newContent, -1)
            TriggerClientEvent('QBXCore:Notify', src, '¡Ubicación del Dr. AI actualizada en la configuración!', 'success')
            -- This is a server-side change, usually requires a resource restart to take effect on the server.
            -- For client-side, you might want to send an update.
        else
            TriggerClientEvent('QBXCore:Notify', src, 'Error: No se pudo leer el archivo de configuración.', 'error')
        end
    else
        TriggerClientEvent('QBXCore:Notify', src, 'No tienes permiso para hacer esto.', 'error')
    end
end)

RegisterNetEvent('muhaddil_aidoctor:chargePlayer', function(skillCheckPassed)
    local src = source
    local xPlayer = GetPlayer(src)
    if not xPlayer then
        print('^1[AI Doctor] Error: Jugador no encontrado^0')
        return
    end

    local finalPrice = GetFinalPrice(skillCheckPassed == true)
    local charged = false

    local cash = xPlayer.PlayerData.money.cash
    if cash >= finalPrice then
        xPlayer.Functions.RemoveMoney('cash', finalPrice, "ai-doctor-service")
        charged = true
    else
        local bank = xPlayer.PlayerData.money.bank
        if bank >= finalPrice then
            xPlayer.Functions.RemoveMoney('bank', finalPrice, "ai-doctor-service")
            charged = true
        end
    end

    if charged then
        exports['qb-management']:AddMoney('ambulance', finalPrice)
    end

    if not charged then
        print(locale("server_print_error", src))
    else
        -- print('^2[AI Doctor] Cobrado $' .. finalPrice .. ' al jugador ' .. src .. (skillCheckPassed and ' (con descuento)' or '') .. '^0')
        if Config.RemoveItemsOnRevive then
            for k, v in pairs(xPlayer.PlayerData.items) do
                exports.ox_inventory:RemoveItem(src, v.name, v.amount)
            end
        end
    end
end)

--[[
local DiscordWebhook = "TU_WEBHOOK_AQUI"

RegisterNetEvent('muhaddil_aidoctor:logService', function(playerName)
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then return end

    local identifier = FrameWork == 'qb' and xPlayer.PlayerData.citizenid or xPlayer.identifier

    local embed = {
        {
            ["title"] = "AI Doctor - Servicio Utilizado",
            ["description"] = "Un jugador ha usado el servicio de AI Doctor",
            ["color"] = 3447003,
            ["fields"] = {
                {
                    ["name"] = "Jugador",
                    ["value"] = playerName or "Desconocido",
                    ["inline"] = true
                },
                {
                    ["name"] = "ID",
                    ["value"] = src,
                    ["inline"] = true
                },
                {
                    ["name"] = "Identifier",
                    ["value"] = identifier,
                    ["inline"] = true
                },
                {
                    ["name"] = "Costo",
                    ["value"] = "$" .. Config.Price,
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(DiscordWebhook, function(err, text, headers) end, 'POST',
        json.encode({embeds = embed}), {['Content-Type'] = 'application/json'})
end)
]] --

lib.addCommand('aidoctor', {
    help = 'Call the AI Doctor for assistance',
    description = 'Summons an AI Doctor to your location if you are incapacitated.',
    params = {},
}, function(source, args, rawCommand)
    TriggerClientEvent('muhaddil_aidoctor:triggerClientCommand', source)
end)

lib.addCommand('aidoctorstats', {
    help = 'Check AI Doctor metrics & prices',
    restricted = 'group.admin' -- Natively blocks anyone who isn't a txAdmin/server administrator
}, function(source, args, rawCommand)
    local src = source          
    -- In Qbox, players are fetched directly via exports if you need their state data
    local xPlayer = exports.qbx_core:GetPlayer(src)
    if not xPlayer then return end

    -- Safe execution loop for your medical script functions
    local emsOnline = GetOnlineEMS()

    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 255, 0 },
        args = { "AI Doctor Stats", locale('stats_message', emsOnline, Config.Price) }
    })
end)

print(locale('server_print_1'))
print(locale('server_print_2', FrameWork or 'NINGUNO'))
print(locale('server_print_3', Config.Price))


