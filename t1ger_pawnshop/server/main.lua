-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local playerCooldowns = {}

local function getItemConfig(itemName)
    if type(itemName) ~= 'string' then return nil end
    return Config.Items[itemName]
end

local function isOnCooldown(source)
    local expiry = playerCooldowns[source]
    if not expiry then return false end
    return expiry > GetGameTimer()
end

local function startCooldown(source)
    if Config.TransactionCooldown <= 0 then return end
    playerCooldowns[source] = GetGameTimer() + Config.TransactionCooldown
end

local function clearCooldown(source)
    playerCooldowns[source] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    clearCooldown(src)
end)

local function calculatePrice(itemConfig, action, amount)
    local data = itemConfig[action]
    if not data or not data.enabled or type(data.price) ~= 'number' then return nil end
    return data.price * amount
end

local function formatCurrency(amount)
    return tostring(math.floor(amount + 0.5))
end

local function handleInvalidItem(source, messageKey)
    TriggerClientEvent('t1ger_pawnshop:notify', source, Lang[messageKey] or messageKey, 'error')
end

RegisterNetEvent('t1ger_pawnshop:buyItem', function(itemName, amount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    if type(amount) ~= 'number' then
        handleInvalidItem(src, 'invalid_amount')
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        handleInvalidItem(src, 'quantity_limit')
        return
    end

    if isOnCooldown(src) then
        handleInvalidItem(src, 'cooldown_active')
        return
    end

    local itemConfig = getItemConfig(itemName)
    if not itemConfig then
        handleInvalidItem(src, 'item_missing')
        return
    end

    if not itemConfig.buy or not itemConfig.buy.enabled then
        handleInvalidItem(src, 'item_disabled')
        return
    end

    if not QBCore.Shared.Items[itemName] then
        handleInvalidItem(src, 'item_invalid')
        return
    end

    local totalPrice = calculatePrice(itemConfig, 'buy', amount)
    if not totalPrice then
        handleInvalidItem(src, 'item_invalid')
        return
    end

    local account = Config.UseCashForPurchases and 'cash' or 'bank'
    if player.Functions.GetMoney(account) < totalPrice then
        handleInvalidItem(src, 'not_enough_money')
        return
    end

    if not player.Functions.RemoveMoney(account, totalPrice, 't1ger_pawnshop_purchase') then
        handleInvalidItem(src, 'not_enough_money')
        return
    end

    if not player.Functions.AddItem(itemName, amount) then
        player.Functions.AddMoney(account, totalPrice, 't1ger_pawnshop_refund')
        TriggerClientEvent('t1ger_pawnshop:notify', src, (Lang['inventory_full']):format(amount, itemConfig.label), 'error')
        return
    end

    startCooldown(src)
    TriggerClientEvent('t1ger_pawnshop:notify', src, (Lang['item_bought']):format(amount, itemConfig.label, formatCurrency(totalPrice)), 'success')
end)

RegisterNetEvent('t1ger_pawnshop:sellItem', function(itemName, amount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    if type(amount) ~= 'number' then
        handleInvalidItem(src, 'invalid_amount')
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        handleInvalidItem(src, 'quantity_limit')
        return
    end

    if isOnCooldown(src) then
        handleInvalidItem(src, 'cooldown_active')
        return
    end

    local itemConfig = getItemConfig(itemName)
    if not itemConfig then
        handleInvalidItem(src, 'item_missing')
        return
    end

    if not itemConfig.sell or not itemConfig.sell.enabled then
        handleInvalidItem(src, 'item_disabled')
        return
    end

    if not QBCore.Shared.Items[itemName] then
        handleInvalidItem(src, 'item_invalid')
        return
    end

    local inventoryItem = player.Functions.GetItemByName(itemName)
    if not inventoryItem or inventoryItem.amount < amount then
        handleInvalidItem(src, 'not_enough_items')
        return
    end

    if not player.Functions.RemoveItem(itemName, amount) then
        handleInvalidItem(src, 'not_enough_items')
        return
    end

    local totalPrice = calculatePrice(itemConfig, 'sell', amount)
    if not totalPrice then
        handleInvalidItem(src, 'item_invalid')
        return
    end

    local account = Config.ReceiveCashOnSale and 'cash' or 'bank'
    player.Functions.AddMoney(account, totalPrice, 't1ger_pawnshop_sale')

    startCooldown(src)
    TriggerClientEvent('t1ger_pawnshop:notify', src, (Lang['item_sold']):format(amount, itemConfig.label, formatCurrency(totalPrice)), 'success')
end)
