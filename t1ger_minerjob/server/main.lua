local QBCore = exports['qb-core']:GetCoreObject()

local resourceName = GetCurrentResourceName()

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

    local inventoryItem = Player.Functions.GetItemByName(item)
    return inventoryItem and inventoryItem.amount >= requiredAmount
end)

lib.callback.register('t1ger_minerjob:removeItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'string' then return false end

    local requiredAmount = ensureAmount(amount)
    if requiredAmount <= 0 then return false end

    local inventoryItem = Player.Functions.GetItemByName(item)
    if not inventoryItem or inventoryItem.amount < requiredAmount then
        return false
    end

    return Player.Functions.RemoveItem(item, requiredAmount)
end)

RegisterNetEvent('t1ger_minerjob:mineSpotStateSV', function(id, state)
    if not Config.Mining[id] then return end

    Config.Mining[id].inUse = state and true or false
    TriggerClientEvent('t1ger_minerjob:mineSpotStateCL', -1, id, Config.Mining[id].inUse)
end)

RegisterNetEvent('t1ger_minerjob:miningReward', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(item) ~= 'string' then return end

    local rewardAmount = ensureAmount(amount)
    if rewardAmount <= 0 then return end

    if Player.Functions.AddItem(item, rewardAmount) then
        notifyWithItem(src, (Lang['stone_mined']):format(rewardAmount, getItemLabel(item)), 'success', item)
    else
        notify(src, Lang['inventory_full'], 'error')
    end
end)

RegisterNetEvent('t1ger_minerjob:washingReward', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(item) ~= 'string' then return end

    local rewardAmount = ensureAmount(amount)
    if rewardAmount <= 0 then return end

    if Player.Functions.AddItem(item, rewardAmount) then
        notifyWithItem(src, (Lang['stone_washed']):format(rewardAmount, getItemLabel(item)), 'success', item)
    else
        notify(src, Lang['inventory_full'], 'error')
    end
end)

RegisterNetEvent('t1ger_minerjob:smeltingReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

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
