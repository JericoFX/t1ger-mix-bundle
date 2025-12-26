-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

local exchangeCooldown = {}
local jobCooldown = {}
local jobStates = {}
local activePlayerJobs = {}
local pendingRefunds = {}
local eventRateLimits = {}
local eventCooldownMs = 750

local function shouldProcessEvent(src, key)
    if not src then return false end
    local now = GetGameTimer()
    eventRateLimits[src] = eventRateLimits[src] or {}
    local last = eventRateLimits[src][key] or 0
    if now - last < eventCooldownMs then
        return false
    end
    eventRateLimits[src][key] = now
    return true
end

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

local function broadcastJobState(id, state)
    if not id then return end
    jobStates[id] = jobStates[id] or { inUse = false }
    jobStates[id].inUse = state and true or false
    GlobalState[('t1ger_goldcurrency:job:%s'):format(id)] = jobStates[id]
    TriggerClientEvent('t1ger_goldcurrency:setJobInUse', -1, id, jobStates[id].inUse)
end

local function reserveJobForPlayer(identifier, jobId)
    if not identifier or not jobId then return false end
    activePlayerJobs[identifier] = jobId
    broadcastJobState(jobId, true)
    return true
end

local function releaseJobForPlayer(identifier)
    local jobId = identifier and activePlayerJobs[identifier]
    if not jobId then return end
    activePlayerJobs[identifier] = nil
    broadcastJobState(jobId, false)
end

local function getFreeJobs()
    local available = {}
    for id = 1, #Config.GoldJobs do
        local state = jobStates[id]
        if not state or not state.inUse then
            available[#available + 1] = id
        end
    end
    return available
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
    for id = 1, #Config.GoldJobs do
        broadcastJobState(id, false)
    end
    TriggerClientEvent('t1ger_goldcurrency:createNPC', -1, Config.JobNPC)
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source or source
    TriggerClientEvent('t1ger_goldcurrency:createNPC', src, Config.JobNPC)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function(src)
    TriggerClientEvent('t1ger_goldcurrency:createNPC', src or source, Config.JobNPC)
end)

AddEventHandler('playerDropped', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local identifier = getCitizenId(Player)
    if identifier then
        pendingRefunds[identifier] = nil
    end
    releaseJobForPlayer(identifier)
end)

lib.callback.register('t1ger_goldcurrency:assignJob', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return { success = false, message = Lang['no_jobs_available'] }
    end

    local identifier = getCitizenId(Player)
    if not identifier then
        return { success = false, message = Lang['no_jobs_available'] }
    end

    if isOnCooldown(jobCooldown, identifier) then
        return { success = false, message = (Lang['job_timer']):format(getCooldownMinutes(jobCooldown, identifier)) }
    end

    if not hasFunds(Player, Config.JobNPC.jobFees) then
        return { success = false, message = Lang['not_enough_money'] }
    end

    if countPolice() < Config.PoliceSettings.requiredCops then
        return { success = false, message = Lang['not_enough_cops'] }
    end

    local available = getFreeJobs()
    if #available == 0 then
        return { success = false, message = Lang['no_jobs_available'] }
    end

    local jobIndex = available[math.random(1, #available)]
    reserveJobForPlayer(identifier, jobIndex)

    removeFunds(Player, Config.JobNPC.jobFees)
    setCooldown(jobCooldown, identifier, Config.JobNPC.cooldown or 0)

    local vehicleIndex = math.random(1, #Config.JobVehicles)
    local vehModel = Config.JobVehicles[vehicleIndex]

    TriggerClientEvent('t1ger_goldcurrency:startTheGoldJob', source, jobIndex, vehModel)

    return { success = true, job = jobIndex, vehicle = vehModel }
end)

RegisterNetEvent('t1ger_goldcurrency:releaseJob', function(jobId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local identifier = getCitizenId(Player)
    if not identifier then return end

    if jobId and jobStates[jobId] and jobStates[jobId].inUse then
        releaseJobForPlayer(identifier)
        return
    end

    releaseJobForPlayer(identifier)
end)

RegisterNetEvent('t1ger_goldcurrency:PoliceNotifySV', function(targetCoords, streetName, label)
    TriggerClientEvent('t1ger_goldcurrency:PoliceNotifyCL', -1, (label):format(streetName))
    TriggerClientEvent('t1ger_goldcurrency:PoliceNotifyBlip', -1, targetCoords)
end)

RegisterNetEvent('t1ger_goldcurrency:giveJobReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local identifier = getCitizenId(Player)
    if not identifier or not activePlayerJobs[identifier] then return end
    if not shouldProcessEvent(src, 'jobReward') then return end

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

    releaseJobForPlayer(getCitizenId(Player))
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
        local identifier = getCitizenId(Player)
        if identifier then
            if item == Config.DatabaseItems['goldwatch'] and quantity == Config.SmelterySettings.input then
                pendingRefunds[identifier] = { item = item, amount = quantity, type = 'smelt' }
            elseif item == Config.DatabaseItems['goldbar'] and quantity == Config.ExchangeSettings.input then
                pendingRefunds[identifier] = { item = item, amount = quantity, type = 'exchange' }
            end
        end
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
    local identifier = getCitizenId(Player)
    local pending = identifier and pendingRefunds[identifier]
    if item == Config.DatabaseItems['goldbar'] and quantity == Config.SmelterySettings.output then
        if not pending or pending.type ~= 'smelt' or pending.item ~= Config.DatabaseItems['goldwatch'] or pending.amount ~= Config.SmelterySettings.input then
            return false
        end
    end

    local success = Player.Functions.AddItem(item, quantity)
    local label = getItemLabel(item)
    if success then
        notifyPlayer(source, (Lang['items_added']):format(quantity, label), 'success')
        if identifier and pending and pending.type == 'smelt' then
            pendingRefunds[identifier] = nil
        end
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
    if not shouldProcessEvent(source, 'refundItem') then return end
    local identifier = getCitizenId(Player)
    local pending = identifier and pendingRefunds[identifier]
    if not pending or pending.item ~= item or pending.amount ~= quantity then return end
    pendingRefunds[identifier] = nil
    Player.Functions.AddItem(item, quantity)
end)

RegisterNetEvent('t1ger_goldcurrency:giveExchangeReward', function(amount, account)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not shouldProcessEvent(source, 'exchangeReward') then return end
    local identifier = getCitizenId(Player)
    local pending = identifier and pendingRefunds[identifier]
    if not pending or pending.type ~= 'exchange' then return end
    local payout = Config.ExchangeSettings.money.amount
    if type(payout) ~= 'number' or payout <= 0 then return end
    local accountType = Config.ExchangeSettings.money.account or 'cash'
    giveFunds(Player, accountType, payout, 'gold-currency-exchange')
    notifyPlayer(source, (Lang['money_received']):format(payout), 'success')
    pendingRefunds[identifier] = nil
    setCooldown(exchangeCooldown, identifier, Config.ExchangeSettings.cooldown or 0)
end)

RegisterNetEvent('t1ger_goldcurrency:addExchangeCooldown', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local identifier = getCitizenId(Player)
    if not identifier then return end
    local pending = pendingRefunds[identifier]
    if not pending or pending.type ~= 'exchange' then return end
    setCooldown(exchangeCooldown, identifier, Config.ExchangeSettings.cooldown or 0)
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
