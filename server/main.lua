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

if FrameWork == 'esx' then
    ESX.RegisterServerCallback('muhaddil_aidoctor:checkConditions', function(src, cb)
        local xPlayer = GetPlayer(src)
        local hasMoney = false

        if xPlayer then
            local cash = xPlayer.getMoney()
            local bank = xPlayer.getAccount('bank').money
            hasMoney = (cash >= Config.Price) or (bank >= Config.Price)
        end

        local emsOnline = GetOnlineEMS()

        cb(emsOnline, hasMoney)
    end)
elseif FrameWork == 'qb' then
    QBCore.Functions.CreateCallback('muhaddil_aidoctor:checkConditions', function(src, cb)
        local Player = GetPlayer(src)
        local hasMoney = false

        if Player then
            local cash = Player.Functions.GetMoney('cash')
            local bank = Player.Functions.GetMoney('bank')
            hasMoney = (cash >= Config.Price) or (bank >= Config.Price)
        end

        local emsOnline = GetOnlineEMS()

        cb(emsOnline, hasMoney)
    end)
end

RegisterNetEvent('muhaddil_aidoctor:chargePlayer', function()
    local src = source
    local xPlayer = GetPlayer(src)

    if not xPlayer then
        print('^1[AI Doctor] Error: Jugador no encontrado^0')
        return
    end

    local charged = false

    if FrameWork == 'qb' then
        local cash = xPlayer.Functions.GetMoney('cash')
        if cash >= Config.Price then
            xPlayer.Functions.RemoveMoney('cash', Config.Price, "ai-doctor-service")
            charged = true
        else
            local bank = xPlayer.Functions.GetMoney('bank')
            if bank >= Config.Price then
                xPlayer.Functions.RemoveMoney('bank', Config.Price, "ai-doctor-service")
                charged = true
            end
        end

        if charged then
            exports['qb-management']:AddMoney('ambulance', Config.Price)
        end
    else
        local cash = xPlayer.getMoney()
        if cash >= Config.Price then
            xPlayer.removeMoney(Config.Price)
            charged = true
        else
            local bank = xPlayer.getAccount('bank').money
            if bank >= Config.Price then
                xPlayer.removeAccountMoney('bank', Config.Price)
                charged = true
            end
        end

        if charged then
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_ambulance', function(account)
                if account then
                    account.addMoney(Config.Price)
                end
            end)
        end
    end

    if not charged then
        print('^1[AI Doctor] Error: No se pudo cobrar al jugador ' .. src .. '^0')
    else
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
