if Config.FrameWork == "auto" then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        FrameWork = 'esx'
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        FrameWork = 'qb'
    else
        print('^1===NO SUPPORTED FRAMEWORK FOUND===^0')
    end
elseif Config.FrameWork == "esx" then
    ESX = exports['es_extended']:getSharedObject()
    FrameWork = 'esx'
elseif Config.FrameWork == "qb" then
    QBCore = exports['qb-core']:GetCoreObject()
    FrameWork = 'qb'
else
    print('^1===NO SUPPORTED FRAMEWORK FOUND===^0')
end

lib.locale()

local function GetPlayer(source)
    if FrameWork == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    else
        return ESX.GetPlayerFromId(source)
    end
end

local function GetOnlineEMS()
    local online = 0

    if FrameWork == 'qb' then
        local Players = QBCore.Functions.GetQBPlayers()

        for _, Player in pairs(Players) do
            local jobName = Player.PlayerData.job.name

            if Config.EMSJobs[jobName] and Player.PlayerData.job.onduty then
                online = online + 1
            end
        end
    else
        for _, id in ipairs(ESX.GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(id)

            if xPlayer then
                local jobName = xPlayer.job.name

                if Config.EMSJobs[jobName] then
                    online = online + 1
                end
            end
        end
    end

    return online
end

local function GetFinalPrice(skillCheckPassed)
    local finalPrice = Config.Price
    if skillCheckPassed and Config.SkillCheck and Config.SkillCheck.enabled then
        finalPrice = math.floor(Config.Price * (1 - Config.SkillCheck.discount / 100))
    end
    return finalPrice
end

if FrameWork == 'esx' then
    ESX.RegisterServerCallback('muhaddil_aidoctor:checkConditions', function(src, cb)
        local xPlayer = GetPlayer(src)
        local hasMoney = false

        if xPlayer then
            local minPrice = GetFinalPrice(true)
            local cash = xPlayer.getMoney()
            local bank = xPlayer.getAccount('bank').money
            hasMoney = (cash >= minPrice) or (bank >= minPrice)
        end

        local emsOnline = GetOnlineEMS()

        cb(emsOnline, hasMoney)
    end)
elseif FrameWork == 'qb' then
    QBCore.Functions.CreateCallback('muhaddil_aidoctor:checkConditions', function(src, cb)
        local Player = GetPlayer(src)
        local hasMoney = false

        if Player then
            local minPrice = GetFinalPrice(true)
            local cash = Player.Functions.GetMoney('cash')
            local bank = Player.Functions.GetMoney('bank')
            hasMoney = (cash >= minPrice) or (bank >= minPrice)
        end

        local emsOnline = GetOnlineEMS()

        cb(emsOnline, hasMoney)
    end)
end

RegisterNetEvent('muhaddil_aidoctor:chargePlayer', function(skillCheckPassed)
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then
        print('^1[AI Doctor] Error: Jugador no encontrado^0')
        return
    end

    local finalPrice = GetFinalPrice(skillCheckPassed == true)
    local charged = false

    if FrameWork == 'qb' then
        local cash = xPlayer.Functions.GetMoney('cash')
        if cash >= finalPrice then
            xPlayer.Functions.RemoveMoney('cash', finalPrice, "ai-doctor-service")
            charged = true
        else
            local bank = xPlayer.Functions.GetMoney('bank')
            if bank >= finalPrice then
                xPlayer.Functions.RemoveMoney('bank', finalPrice, "ai-doctor-service")
                charged = true
            end
        end

        if charged then
            exports['qb-management']:AddMoney('ambulance', finalPrice)
        end
    else
        local cash = xPlayer.getMoney()
        if cash >= finalPrice then
            xPlayer.removeMoney(finalPrice)
            charged = true
        else
            local bank = xPlayer.getAccount('bank').money
            if bank >= finalPrice then
                xPlayer.removeAccountMoney('bank', finalPrice)
                charged = true
            end
        end

        if charged then
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_ambulance', function(account)
                if account then
                    account.addMoney(finalPrice)
                end
            end)
        end
    end

    if not charged then
        print(locale("server_print_error", src))
    else
        -- print('^2[AI Doctor] Cobrado $' .. finalPrice .. ' al jugador ' .. src .. (skillCheckPassed and ' (con descuento)' or '') .. '^0')
        if Config.RemoveItemsOnRevive then
            if FrameWork == 'qb' then
                for k, v in pairs(xPlayer.PlayerData.items) do
                    xPlayer.Functions.RemoveItem(v.name, v.amount)
                end
            else
                for i = 1, #xPlayer.inventory, 1 do
                    local item = xPlayer.inventory[i]
                    if item and item.count > 0 then
                        xPlayer.removeInventoryItem(item.name, item.count)
                    end
                end
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

RegisterCommand('aidoctorstats', function(source, args, rawCommand)
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then return end

    local isAdmin = false
    if FrameWork == 'qb' then
        isAdmin = QBCore.Functions.HasPermission(src, 'admin')
    else
        isAdmin = xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin'
    end

    if not isAdmin then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 0, 0 },
            args = { "Sistema", locale('no_permissions') }
        })
        return
    end

    local emsOnline = GetOnlineEMS()

    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 255, 0 },
        args = { "AI Doctor Stats", locale('stats_message', emsOnline, Config.Price) }
    })
end, false)

print(locale('server_print_1'))
print(locale('server_print_2', FrameWork or 'NINGUNO'))
print(locale('server_print_3', Config.Price))
