-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local activeActions = {}
local miningOwners = {}

local function setMiningSpotState(index, state, owner)
    local miningSpot = Config.Mining[index]
    if not miningSpot then return false end

    miningSpot.inUse = state

    if state then
        miningOwners[index] = owner
    else
        miningOwners[index] = nil
    end

    TriggerClientEvent('t1ger_minerjob:mineSpotStateCL', -1, index, state)
    return true
end

local function clearActiveAction(source)
    activeActions[source] = nil
end

local function releaseMiningAction(source, index)
    local action = activeActions[source]
    if not action or action.type ~= 'mining' then return end

    if index and action.spot ~= index then
        return
    end

    if action.spot and miningOwners[action.spot] == source then
        setMiningSpotState(action.spot, false)
    end

    clearActiveAction(source)
end

local function getItemLabel(item)
    local itemInfo = QBCore.Shared.Items[item]
    if itemInfo and itemInfo.label then
        return itemInfo.label
    end

    return item
end

local function notifyPlayer(src, message, messageType)
    if not message or message == '' then return end

    TriggerClientEvent('t1ger_minerjob:client:notify', src, {
        description = message,
        type = messageType or 'inform'
    })
end

lib.callback.register('t1ger_minerjob:hasItem', function(source, item, amount)
    if type(item) ~= 'string' then
        return false
    end

    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return false
    end

    local required = math.max(tonumber(amount) or 1, 1)
    local inventoryItem = player.Functions.GetItemByName(item)
    local count = inventoryItem and (inventoryItem.amount or inventoryItem.count or 0) or 0

    return count >= required
end)

lib.callback.register('t1ger_minerjob:beginMining', function(source, id)
    local index = tonumber(id) and math.floor(id)
    if not index then
        return false, 'invalid_spot'
    end

    local miningSpot = Config.Mining[index]
    if not miningSpot then
        return false, 'invalid_spot'
    end

    if miningOwners[index] and miningOwners[index] ~= source then
        return false, 'spot_unavailable'
    end

    if miningSpot.inUse and miningOwners[index] ~= source then
        return false, 'spot_unavailable'
    end

    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return false, 'invalid_spot'
    end

    local pickaxe = Config.DatabaseItems['pickaxe']
    if pickaxe then
        local item = player.Functions.GetItemByName(pickaxe)
        if not item or (item.amount or item.count or 0) < 1 then
            return false, 'no_pickaxe'
        end
    end

    activeActions[source] = { type = 'mining', spot = index, started = os.time() }
    setMiningSpotState(index, true, source)

    return true
end)

RegisterNetEvent('t1ger_minerjob:miningReward', function(id)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    if type(id) ~= 'number' then
        return
    end

    local index = math.floor(id)
    if not Config.Mining[index] then
        return
    end

    local action = activeActions[src]
    if not action or action.type ~= 'mining' or action.spot ~= index then
        notifyPlayer(src, Lang['process_cancelled'], 'error')
        releaseMiningAction(src)
        return
    end

    local item = Config.DatabaseItems['stone']
    if not item then return end

    local amount = math.random(Config.MiningReward.min, Config.MiningReward.max)
    if amount <= 0 then amount = 1 end

    if player.Functions.AddItem(item, amount) then
        notifyPlayer(src, Lang['stone_mined']:format(amount, getItemLabel(item)), 'success')
    else
        notifyPlayer(src, Lang['inventory_full']:format(getItemLabel(item)), 'error')
    end

    releaseMiningAction(src, index)
end)

RegisterNetEvent('t1ger_minerjob:cancelMining', function(id)
    local src = source
    local index = tonumber(id) and math.floor(id)
    releaseMiningAction(src, index)
end)

RegisterNetEvent('t1ger_minerjob:washStone', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local inputItem = Config.DatabaseItems['stone']
    local outputItem = Config.DatabaseItems['washed_stone']
    if not inputItem or not outputItem then return end

    local required = math.max(tonumber(Config.WashSettings.input) or 0, 0)
    if required <= 0 then
        notifyPlayer(src, Lang['not_enough_stone'], 'error')
        return
    end

    if not player.Functions.RemoveItem(inputItem, required) then
        notifyPlayer(src, Lang['not_enough_stone'], 'error')
        return
    end

    local amount = math.random(Config.WashSettings.output.min, Config.WashSettings.output.max)
    if amount <= 0 then amount = required end

    if player.Functions.AddItem(outputItem, amount) then
        notifyPlayer(src, Lang['stone_washed']:format(amount, getItemLabel(outputItem)), 'success')
    else
        player.Functions.AddItem(inputItem, required)
        notifyPlayer(src, Lang['inventory_full']:format(getItemLabel(outputItem)), 'error')
    end
end)

RegisterNetEvent('t1ger_minerjob:smeltStone', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local inputItem = Config.DatabaseItems['washed_stone']
    if not inputItem then return end

    local required = math.max(tonumber(Config.SmeltingSettings.input) or 0, 0)
    if required <= 0 then
        notifyPlayer(src, Lang['not_enough_washed_stone'], 'error')
        return
    end

    if not player.Functions.RemoveItem(inputItem, required) then
        notifyPlayer(src, Lang['not_enough_washed_stone'], 'error')
        return
    end

    local granted, failed = {}, {}
    for _, reward in ipairs(Config.SmeltingSettings.reward) do
        local chance = tonumber(reward.chance) or 0
        if math.random(0, 100) <= chance then
            local minAmount = reward.amount and reward.amount.min or 1
            local maxAmount = reward.amount and reward.amount.max or minAmount
            local count = math.random(minAmount, maxAmount)
            local item = reward.item

            if count > 0 and type(item) == 'string' then
                if player.Functions.AddItem(item, count) then
                    granted[#granted + 1] = { item = item, amount = count }
                else
                    failed[#failed + 1] = { item = item, amount = count }
                end
            end
        end
    end

    if #granted > 0 then
        for _, reward in ipairs(granted) do
            notifyPlayer(src, Lang['smelt_reward']:format(reward.amount, getItemLabel(reward.item)), 'success')
        end
    else
        player.Functions.AddItem(inputItem, required)
        notifyPlayer(src, Lang['process_cancelled'], 'inform')
    end

    if #failed > 0 then
        for _, reward in ipairs(failed) do
            notifyPlayer(src, Lang['inventory_full']:format(getItemLabel(reward.item)), 'error')
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    releaseMiningAction(src)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    releaseMiningAction(src)
end)
