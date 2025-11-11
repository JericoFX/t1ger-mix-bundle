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

local function processBuy(player, itemName, itemConfig, amount)
    if not itemConfig.buy or not itemConfig.buy.enabled then
        return false, Lang['item_disabled']
    end

    if not QBCore.Shared.Items[itemName] then
        return false, Lang['item_invalid']
    end

    local totalPrice = calculatePrice(itemConfig, 'buy', amount)
    if not totalPrice then
        return false, Lang['item_invalid']
    end

    local account = Config.UseCashForPurchases and 'cash' or 'bank'
    if player.Functions.GetMoney(account) < totalPrice then
        return false, Lang['not_enough_money']
    end

    if not player.Functions.RemoveMoney(account, totalPrice, 't1ger_pawnshop_purchase') then
        return false, Lang['not_enough_money']
    end

    if not player.Functions.AddItem(itemName, amount) then
        player.Functions.AddMoney(account, totalPrice, 't1ger_pawnshop_refund')
        return false, (Lang['inventory_full']):format(amount, itemConfig.label)
    end

    return true, (Lang['item_bought']):format(amount, itemConfig.label, formatCurrency(totalPrice))
end

local function processSell(player, itemName, itemConfig, amount)
    if not itemConfig.sell or not itemConfig.sell.enabled then
        return false, Lang['item_disabled']
    end

    if not QBCore.Shared.Items[itemName] then
        return false, Lang['item_invalid']
    end

    local inventoryItem = player.Functions.GetItemByName(itemName)
    if not inventoryItem or inventoryItem.amount < amount then
        return false, Lang['not_enough_items']
    end

    if not player.Functions.RemoveItem(itemName, amount) then
        return false, Lang['not_enough_items']
    end

    local totalPrice = calculatePrice(itemConfig, 'sell', amount)
    if not totalPrice then
        return false, Lang['item_invalid']
    end

    local account = Config.ReceiveCashOnSale and 'cash' or 'bank'
    player.Functions.AddMoney(account, totalPrice, 't1ger_pawnshop_sale')

    return true, (Lang['item_sold']):format(amount, itemConfig.label, formatCurrency(totalPrice))
end

lib.callback.register('t1ger_pawnshop:processTransaction', function(source, data)
    if type(data) ~= 'table' then return nil end

    local action = data.action
    local itemName = data.item
    local amount = tonumber(data.amount)

    if type(action) ~= 'string' or type(itemName) ~= 'string' or not amount then
        return { success = false, message = Lang['invalid_amount'] }
    end

    amount = math.floor(amount)
    if amount <= 0 then
        return { success = false, message = Lang['quantity_limit'] }
    end

    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return { success = false, message = Lang['transaction_failed'] }
    end

    if isOnCooldown(source) then
        return { success = false, message = Lang['cooldown_active'] }
    end

    local itemConfig = getItemConfig(itemName)
    if not itemConfig then
        return { success = false, message = Lang['item_missing'] }
    end

    local handlers = {
        buy = processBuy,
        sell = processSell
    }

    local handler = handlers[action]
    if not handler then
        return { success = false, message = Lang['transaction_failed'] }
    end

    local success, message = handler(player, itemName, itemConfig, amount)
    if success then
        startCooldown(source)
        return { success = true, message = message }
    end

    return { success = false, message = message or Lang['transaction_failed'] }
end)
