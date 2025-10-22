-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

local exchangeCooldown = {}
local jobCooldown = {}

local function getCitizenId(Player)
    return Player and Player.PlayerData and Player.PlayerData.citizenid
end

local function getItemLabel(name)
    local item = QBCore.Shared.Items[name]
    return item and item.label or name
end

local function hasFunds(Player, fees)
    if not Player or type(fees) ~= 'table' then return false end
    local account = fees.account or 'cash'
    local amount = tonumber(fees.amount) or 0
    if amount <= 0 then return true end
    if account == 'cash' or account == 'bank' then
        local balance = Player.Functions.GetMoney(account)
        return (balance or 0) >= amount
    end

    local item = Player.Functions.GetItemByName(account)
    return item and (item.amount or item.count or 0) >= amount
end

local function removeFunds(Player, fees)
    if not Player or type(fees) ~= 'table' then return end
    local account = fees.account or 'cash'
    local amount = tonumber(fees.amount) or 0
    if amount <= 0 then return end
    if account == 'cash' or account == 'bank' then
        Player.Functions.RemoveMoney(account, amount, 'gold-currency-fee')
    else
        Player.Functions.RemoveItem(account, amount)
    end
end

local function giveFunds(Player, account, amount, reason)
    if not Player then return end
    local value = tonumber(amount) or 0
    if value <= 0 then return end
    if account == 'cash' or account == 'bank' then
        Player.Functions.AddMoney(account, value, reason)
    else
        Player.Functions.AddItem(account, value)
    end
end

local function notifyPlayer(source, message, messageType)
    if not source or not message then return end
    TriggerClientEvent('t1ger_goldcurrency:notify', source, { description = message, type = messageType or 'inform' })
end

local function setCooldown(store, identifier, minutes)
    if not identifier then return end
    local duration = tonumber(minutes) or 0
    if duration <= 0 then
        store[identifier] = nil
        return
    end
    store[identifier] = os.time() + (duration * 60)
end

local function isOnCooldown(store, identifier)
    local expires = identifier and store[identifier]
    if not expires then return false end
    if expires <= os.time() then
        store[identifier] = nil
        return false
    end
    return true
end

local function getCooldownMinutes(store, identifier)
    local expires = identifier and store[identifier]
    if not expires then return 0 end
    local remaining = expires - os.time()
    if remaining <= 0 then
        store[identifier] = nil
        return 0
    end
    return math.ceil(remaining / 60)
end

local function countPolice()
    local total = 0
    local seen = {}
    for _, jobName in ipairs(Config.PoliceSettings.jobs) do
        local dutyPlayers = QBCore.Functions.GetPlayersOnDuty(jobName)
        if type(dutyPlayers) == 'table' then
            for _, src in ipairs(dutyPlayers) do
                if not seen[src] then
                    total = total + 1
                    seen[src] = true
                end
            end
        end
        if not Config.PoliceSettings.onDutyOnly then
            for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
                if Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name == jobName then
                    local src = Player.PlayerData.source
                    if not seen[src] then
                        total = total + 1
                        seen[src] = true
                    end
                end
            end
        end
    end
    return total
end

lib.cron.new('*/30 * * * * *', function()
    local now = os.time()
    for identifier, expires in pairs(jobCooldown) do
        if expires <= now then
            jobCooldown[identifier] = nil
        end
    end
    for identifier, expires in pairs(exchangeCooldown) do
        if expires <= now then
            exchangeCooldown[identifier] = nil
        end
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerClientEvent('t1ger_goldcurrency:createNPC', -1, Config.JobNPC)
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source or source
    TriggerClientEvent('t1ger_goldcurrency:createNPC', src, Config.JobNPC)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function(src)
    TriggerClientEvent('t1ger_goldcurrency:createNPC', src or source, Config.JobNPC)
end)

lib.callback.register('t1ger_goldcurrency:getJobCooldown', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return true end
    local identifier = getCitizenId(Player)
    if not identifier then return true end
    if isOnCooldown(jobCooldown, identifier) then
        notifyPlayer(source, (Lang['job_timer']):format(getCooldownMinutes(jobCooldown, identifier)), 'error')
        return true
    end
    return false
end)

lib.callback.register('t1ger_goldcurrency:getJobFees', function(source, fees)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    return hasFunds(Player, fees)
end)

lib.callback.register('t1ger_goldcurrency:checkCops', function()
    return countPolice() >= Config.PoliceSettings.requiredCops
end)

RegisterNetEvent('t1ger_goldcurrency:prepareJobSV', function(id, fees, vehModel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jobConfig = id and Config.GoldJobs and Config.GoldJobs[id]
    if not jobConfig then
        notifyPlayer(src, Lang['no_jobs_available'], 'error')
        return
    end

    if not hasFunds(Player, fees) then
        notifyPlayer(src, Lang['not_enough_money'], 'error')
        return
    end

    removeFunds(Player, fees)
    setCooldown(jobCooldown, getCitizenId(Player), Config.JobNPC.cooldown or 0)
    TriggerClientEvent('t1ger_goldcurrency:startTheGoldJob', src, id, vehModel)
end)

RegisterNetEvent('t1ger_goldcurrency:updateConfigSV', function(data)
    TriggerClientEvent('t1ger_goldcurrency:updateConfigCL', -1, data)
end)

RegisterNetEvent('t1ger_goldcurrency:PoliceNotifySV', function(targetCoords, streetName, label)
    TriggerClientEvent('t1ger_goldcurrency:PoliceNotifyCL', -1, (label):format(streetName))
    TriggerClientEvent('t1ger_goldcurrency:PoliceNotifyBlip', -1, targetCoords)
end)

RegisterNetEvent('t1ger_goldcurrency:giveJobReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    for _, reward in ipairs(Config.JobReward) do
        if math.random(0, 100) <= reward.chance then
            Wait(250)
            local count = math.random(reward.amount.min, reward.amount.max)
            local success = Player.Functions.AddItem(reward.item, count)
            local label = getItemLabel(reward.item)
            if success then
                notifyPlayer(src, (Lang['items_added']):format(count, label), 'success')
            else
                notifyPlayer(src, (Lang['item_limit_exceed']):format(label), 'error')
            end
        end
        Wait(250)
    end
end)

lib.callback.register('t1ger_goldcurrency:getInventoryItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    if type(item) ~= 'string' then return false end
    local required = tonumber(amount) or 0
    if required <= 0 then return false end
    local invItem = Player.Functions.GetItemByName(item)
    if invItem and (invItem.amount or invItem.count or 0) >= required then
        return true
    end
    return false
end)

lib.callback.register('t1ger_goldcurrency:removeItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    if type(item) ~= 'string' then return false end
    local quantity = tonumber(amount) or 0
    if quantity <= 0 then return false end

    local invItem = Player.Functions.GetItemByName(item)
    if invItem and (invItem.amount or invItem.count or 0) >= quantity then
        Player.Functions.RemoveItem(item, quantity)
        return true
    end
    return false
end)

lib.callback.register('t1ger_goldcurrency:addItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    if type(item) ~= 'string' then return false end
    local quantity = tonumber(amount) or 0
    if quantity <= 0 then return false end

    local success = Player.Functions.AddItem(item, quantity)
    local label = getItemLabel(item)
    if success then
        notifyPlayer(source, (Lang['items_added']):format(quantity, label), 'success')
        return true
    end

    notifyPlayer(source, (Lang['item_limit_exceed']):format(label), 'error')
    return false
end)

RegisterNetEvent('t1ger_goldcurrency:giveItem', function(item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if type(item) ~= 'string' then return end
    local quantity = tonumber(amount) or 0
    if quantity <= 0 then return end
    Player.Functions.AddItem(item, quantity)
end)

RegisterNetEvent('t1ger_goldcurrency:giveExchangeReward', function(amount, account)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local payout = tonumber(amount) or 0
    if payout <= 0 then return end
    giveFunds(Player, account or 'cash', payout, 'gold-currency-exchange')
    notifyPlayer(source, (Lang['money_received']):format(payout), 'success')
end)

RegisterNetEvent('t1ger_goldcurrency:addExchangeCooldown', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    setCooldown(exchangeCooldown, getCitizenId(Player), Config.ExchangeSettings.cooldown or 0)
end)

lib.callback.register('t1ger_goldcurrency:getExchangeCooldown', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return true end
    local identifier = getCitizenId(Player)
    if not identifier then return true end
    if isOnCooldown(exchangeCooldown, identifier) then
        notifyPlayer(source, (Lang['exchange_timer']):format(getCooldownMinutes(exchangeCooldown, identifier)), 'error')
        return true
    end
    return false
end)
