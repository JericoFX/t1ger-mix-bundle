local QBCore = exports['qb-core']:GetCoreObject()

local resourceName = GetCurrentResourceName()
local useOxInventory = GetResourceState('ox_inventory') == 'started'

local itemIcons = {
    pickaxe = 'pickaxe.png',
    stone = 'stone.png',
    washpan = 'washpan.png',
    washed_stone = 'washed_stone.png',
    uncut_diamond = 'diamond.png',
    uncut_rubbies = 'jewels.png',
    gold = 'gold.png',
    silver = 'silver.png',
    copper = 'copper.png',
    iron_ore = 'iron.png',
    goldbar = 'goldbar.png',
    goldwatch = 'goldwatch.png'
}

local activeMiningSpots = {}
local pendingRewards = {}
local rewardRateLimits = {}

local function shouldProcessReward(src, key, cooldownMs)
    local now = GetGameTimer()
    rewardRateLimits[src] = rewardRateLimits[src] or {}
    local last = rewardRateLimits[src][key] or 0
    if now - last < cooldownMs then
        return false
    end
    rewardRateLimits[src][key] = now
    return true
end

local function releaseMiningSpot(playerId)
    if not playerId then return end

    local spotId = activeMiningSpots[playerId]
    if not spotId then return end

    activeMiningSpots[playerId] = nil
    pendingRewards[playerId] = nil

    if not Config.Mining[spotId] then return end

    if Config.Mining[spotId].inUse then
        Config.Mining[spotId].inUse = false
        TriggerClientEvent('t1ger_minerjob:mineSpotStateCL', -1, spotId, false)
    end
end

local function ensureAmount(value)
    local amount = tonumber(value) or 0
    amount = math.floor(amount)
    if amount < 0 then amount = 0 end
    return amount
end

local function getItemLabel(item)
    if type(item) ~= 'string' then return tostring(item) end

    local itemData = QBCore.Shared.Items[item]
    if not itemData then
        itemData = QBCore.Shared.Items[item:lower()]
    end

    return itemData and itemData.label or item
end

local function notify(source, message, type)
    local payload = {
        type = type or 'inform',
        description = message
    }

    if type == 'success' or type == 'error' then
        payload.iconColor = type == 'success' and '#2ecc71' or '#e74c3c'
    end

    TriggerClientEvent('t1ger_minerjob:clientNotify', source, payload)
end

local function notifyWithItem(source, message, type, item)
    local payloadIcon
    if type(item) == 'string' then
        local icon = itemIcons[item] or itemIcons[item:lower()]
        if icon then
            payloadIcon = ('nui://%s/pictures/%s'):format(resourceName, icon)
        end
    end

    local payload = {
        type = type or 'inform',
        description = message
    }

    if payloadIcon then
        payload.icon = payloadIcon
        payload.iconColor = type == 'success' and '#2ecc71' or '#e74c3c'
    elseif type == 'success' or type == 'error' then
        payload.iconColor = type == 'success' and '#2ecc71' or '#e74c3c'
    end

    TriggerClientEvent('t1ger_minerjob:clientNotify', source, payload)
end

lib.callback.register('t1ger_minerjob:getInventoryItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'string' then return false end

    local requiredAmount = ensureAmount(amount)
    if requiredAmount <= 0 then return false end

    if useOxInventory then
        return exports.ox_inventory:GetItemCount(source, item, nil, true) >= requiredAmount
    end

    local inventoryItem = Player.Functions.GetItemByName(item)
    return inventoryItem and (inventoryItem.amount or 0) >= requiredAmount
end)

lib.callback.register('t1ger_minerjob:removeItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'string' then return false end

    local requiredAmount = ensureAmount(amount)
    if requiredAmount <= 0 then return false end

    if useOxInventory then
        local removed = exports.ox_inventory:RemoveItem(source, item, requiredAmount, nil, nil, false)
        if removed then
            if item == Config.DatabaseItems['stone'] and requiredAmount == Config.WashSettings.input then
                pendingRewards[source] = { type = 'wash' }
            elseif item == Config.DatabaseItems['washed_stone'] and requiredAmount == Config.SmeltingSettings.input then
                pendingRewards[source] = { type = 'smelt' }
            end
        end
        return removed
    end

    local inventoryItem = Player.Functions.GetItemByName(item)
    if not inventoryItem or (inventoryItem.amount or 0) < requiredAmount then
        return false
    end

    local removed = Player.Functions.RemoveItem(item, requiredAmount)
    if removed then
        if item == Config.DatabaseItems['stone'] and requiredAmount == Config.WashSettings.input then
            pendingRewards[source] = { type = 'wash' }
        elseif item == Config.DatabaseItems['washed_stone'] and requiredAmount == Config.SmeltingSettings.input then
            pendingRewards[source] = { type = 'smelt' }
        end
    end
    return removed
end)

RegisterNetEvent('t1ger_minerjob:mineSpotStateSV', function(id, state)
    if not Config.Mining[id] then return end

    local src = source
    local isActive = state and true or false

    Config.Mining[id].inUse = isActive

    if isActive then
        if activeMiningSpots[src] and activeMiningSpots[src] ~= id then
            releaseMiningSpot(src)
        end

        activeMiningSpots[src] = id
    elseif activeMiningSpots[src] == id then
        activeMiningSpots[src] = nil
    end

    TriggerClientEvent('t1ger_minerjob:mineSpotStateCL', -1, id, Config.Mining[id].inUse)
end)

AddEventHandler('playerDropped', function()
    releaseMiningSpot(source)
    pendingRewards[source] = nil
end)

RegisterNetEvent('QBCore:Server:OnPlayerDropped', function(playerId)
    releaseMiningSpot(playerId)
    pendingRewards[playerId] = nil
end)

RegisterNetEvent('t1ger_minerjob:miningReward', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(item) ~= 'string' then return end
    if not shouldProcessReward(src, 'mining', 1500) then return end
    if item ~= Config.DatabaseItems['stone'] then return end
    local spotId = activeMiningSpots[src]
    local spot = spotId and Config.Mining[spotId]
    if not spot then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local playerCoords = GetEntityCoords(ped)
    local spotCoords = vector3(spot.pos[1], spot.pos[2], spot.pos[3])
    if #(playerCoords - spotCoords) > 7.5 then return end

    local rewardAmount = ensureAmount(amount)
    if rewardAmount <= 0 then return end
    if rewardAmount < Config.MiningReward.min or rewardAmount > Config.MiningReward.max then return end

    local success
    if useOxInventory then
        success = exports.ox_inventory:AddItem(src, item, rewardAmount)
    else
        success = Player.Functions.AddItem(item, rewardAmount)
    end

    if success then
        notifyWithItem(src, (Lang['stone_mined']):format(rewardAmount, getItemLabel(item)), 'success', item)
    else
        notify(src, Lang['inventory_full'], 'error')
    end
end)

RegisterNetEvent('t1ger_minerjob:washingReward', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(item) ~= 'string' then return end
    if not shouldProcessReward(src, 'washing', 1500) then return end
    if item ~= Config.DatabaseItems['washed_stone'] then return end
    local pending = pendingRewards[src]
    if not pending or pending.type ~= 'wash' then return end

    local rewardAmount = ensureAmount(amount)
    if rewardAmount <= 0 then return end
    if rewardAmount < Config.WashSettings.output.min or rewardAmount > Config.WashSettings.output.max then return end

    local success
    if useOxInventory then
        success = exports.ox_inventory:AddItem(src, item, rewardAmount)
    else
        success = Player.Functions.AddItem(item, rewardAmount)
    end

    if success then
        pendingRewards[src] = nil
        notifyWithItem(src, (Lang['stone_washed']):format(rewardAmount, getItemLabel(item)), 'success', item)
    else
        notify(src, Lang['inventory_full'], 'error')
    end
end)

RegisterNetEvent('t1ger_minerjob:smeltingReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not shouldProcessReward(src, 'smelting', 1500) then return end
    local pending = pendingRewards[src]
    if not pending or pending.type ~= 'smelt' then return end
    pendingRewards[src] = nil

    for _, reward in pairs(Config.SmeltingSettings.reward) do
        if type(reward) ~= 'table' then goto continue end
        if type(reward.item) ~= 'string' then goto continue end

        local chance = ensureAmount(reward.chance)
        if chance <= 0 then goto continue end

        if math.random(0, 100) <= chance then
            Wait(250)
            local minAmount = ensureAmount(reward.amount and reward.amount.min)
            local maxAmount = ensureAmount(reward.amount and reward.amount.max)
            if maxAmount <= 0 then goto continue end
            if minAmount <= 0 then minAmount = 1 end
            if minAmount > maxAmount then
                minAmount, maxAmount = maxAmount, minAmount
            end

            local count = math.random(minAmount, maxAmount)

            if Player.Functions.AddItem(reward.item, count) then
                notifyWithItem(src, (Lang['smelt_reward']):format(count, getItemLabel(reward.item)), 'success', reward.item)
            else
                notify(src, Lang['inventory_full'], 'error')
                break
            end
        end

        ::continue::
        Wait(250)
    end
end)
