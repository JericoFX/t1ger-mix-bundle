-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local shops = {}

local function dbFetch(query, params)
        local p = promise.new()
        MySQL.Async.fetchAll(query, params or {}, function(result)
                p:resolve(result or {})
        end)
        return Citizen.Await(p)
end

local function dbExecute(query, params)
        local p = promise.new()
        MySQL.Async.execute(query, params or {}, function(result)
                p:resolve(result)
        end)
        return Citizen.Await(p)
end

local function comma_value(n)
        local left, num, right = tostring(n):match('^([^%d]*%d)(%d*)(.-)$')
        return left .. (num:reverse():gsub('(%d%d%d)','%1,'):reverse()) .. right
end

local function resetShopConfig()
        for id, cfg in pairs(Config.Shops) do
                cfg.owned = false
                cfg.data = cfg.data or { id = id, stock = {}, shelves = {} }
                cfg.data.stock = cfg.data.stock or {}
                cfg.data.shelves = cfg.data.shelves or {}
        end
end

local function loadShops()
        resetShopConfig()
        local results = dbFetch('SELECT * FROM t1ger_shops', {})
        for _, row in ipairs(results) do
                local stock = row.stock and json.decode(row.stock) or {}
                local shelves = row.shelves and json.decode(row.shelves) or {}
                shops[row.id] = {
                        id = row.id,
                        citizenid = row.citizenid or row.identifier,
                        stock = stock,
                        shelves = shelves
                }
                if Config.Shops[row.id] then
                        Config.Shops[row.id].owned = true
                        Config.Shops[row.id].data = shops[row.id]
                end
        end
end

local function saveShop(id)
        local data = shops[id]
        if not data then return end
        dbExecute('UPDATE t1ger_shops SET stock = ?, shelves = ? WHERE id = ?', {
                json.encode(data.stock or {}),
                json.encode(data.shelves or {}),
                id
        })
end

local function broadcastShop(id)
        if not Config.Shops[id] then return end
        TriggerClientEvent('t1ger_shops:updateShopsDataCL', -1, id, Config.Shops[id].data, shops)
end

local function sendShopsToPlayer(src)
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local job = Player.PlayerData.job
        local ownedId, jobId = 0, 0
        for id, data in pairs(shops) do
                if data.citizenid == citizenid then
                        ownedId = id
                end
                local cfg = Config.Shops[id]
                if cfg then
                        local society = Config.Society[cfg.society]
                        if society and job and job.name == society.job then
                                jobId = id
                        end
                end
        end
        TriggerClientEvent('t1ger_shops:loadShops', src, shops, Config.Shops, ownedId, jobId)
end

local function getSociety(jobName)
        for key, data in pairs(Config.Society) do
                if data.job == jobName or key == jobName then
                        return data
                end
        end
end

local function addSocietyMoney(jobName, amount)
        if amount <= 0 then return end
        if GetResourceState('qb-management') == 'started' then
                TriggerEvent('qb-management:server:addAccountMoney', jobName, amount)
        end
end

local function removeSocietyMoney(jobName, amount)
        if amount <= 0 then return end
        if GetResourceState('qb-management') == 'started' then
                TriggerEvent('qb-management:server:removeAccountMoney', jobName, amount)
        end
end

local function getSocietyBalance(jobName, cb)
        if GetResourceState('qb-management') ~= 'started' then
                cb(0)
                return
        end
        TriggerEvent('qb-management:server:getAccountBalance', jobName, function(balance)
                cb(balance or 0)
        end)
end

local function getItemDefinition(itemName)
        for _, def in ipairs(Config.Items) do
                if def.item == itemName then
                        return def
                end
        end
end

local function isItemAllowed(shopId, itemName)
        if not Config.ItemCompatibility then return true end
        local cfg = Config.Shops[shopId]
        if not cfg then return false end
        local item = getItemDefinition(itemName)
        if not item or not item.type then return true end
        for _, shopType in ipairs(item.type) do
                if shopType == cfg.type then
                        return true
                end
        end
        return false
end

local function ensureShopData(id)
        shops[id] = shops[id] or { id = id, citizenid = nil, stock = {}, shelves = {} }
        Config.Shops[id].data = shops[id]
        return shops[id]
end

AddEventHandler('onResourceStart', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        loadShops()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        if not Player then return end
        sendShopsToPlayer(Player.PlayerData.source)
end)

RegisterNetEvent('t1ger_shops:debugSV', function()
        sendShopsToPlayer(source)
end)

QBCore.Functions.CreateCallback('t1ger_shops:purchaseShop', function(source, cb, shopId)
        local Player = QBCore.Functions.GetPlayer(source)
        local cfg = Config.Shops[shopId]
        if not Player or not cfg then
                cb(false, Lang['invalid_amount'])
                return
        end
        if cfg.owned then
                lib.logger(source, 'warn', ('Attempted to buy already owned shop %s'):format(shopId))
                cb(false, Lang['boss_menu_no_access'])
                return
        end
        if not cfg.buyable then
                lib.logger(source, 'warn', ('Attempted to buy non-buyable shop %s'):format(shopId))
                cb(false, Lang['boss_menu_no_access'])
                return
        end
        local price = math.floor(cfg.price)
        if price <= 0 then
                cb(false, Lang['invalid_amount'])
                return
        end
        local accountType = Config.BuyShopWithBank and 'bank' or 'cash'
        if Player.Functions.GetMoney(accountType) < price then
                cb(false, Lang['not_enough_money'])
                return
        end
        Player.Functions.RemoveMoney(accountType, price, 't1ger-shop-purchase')
        local data = ensureShopData(shopId)
        data.citizenid = Player.PlayerData.citizenid
        data.stock = {}
        data.shelves = {}
        cfg.owned = true
        dbExecute('INSERT INTO t1ger_shops (id, citizenid, stock, shelves) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), stock = VALUES(stock), shelves = VALUES(shelves)', {
                shopId,
                data.citizenid,
                json.encode(data.stock),
                json.encode(data.shelves)
        })
        local society = Config.Society[cfg.society]
        if society and society.job then
                Player.Functions.SetJob(society.job, society.boss_grade or 0)
        end
        TriggerClientEvent('t1ger_shops:syncShops', -1, shops, Config.Shops)
        cb(true)
        lib.logger(source, 'info', ('Purchased shop %s for %s'):format(shopId, price))
end)

RegisterNetEvent('t1ger_shops:sellShop', function(shopId, sellPrice)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local cfg = Config.Shops[shopId]
        local data = shops[shopId]
        if not Player or not cfg or not data then return end
        if data.citizenid ~= Player.PlayerData.citizenid then
                lib.logger(src, 'warn', ('Attempted to sell shop %s without ownership'):format(shopId))
                return
        end
        local amount = math.floor(sellPrice or 0)
        if amount < 0 then
                lib.logger(src, 'warn', ('Invalid sell amount for shop %s: %s'):format(shopId, amount))
                return
        end
        local accountType = Config.BuyShopWithBank and 'bank' or 'cash'
        Player.Functions.AddMoney(accountType, amount, 't1ger-shop-sell')
        shops[shopId] = nil
        cfg.owned = false
        cfg.data = { id = shopId, stock = {}, shelves = {} }
        dbExecute('DELETE FROM t1ger_shops WHERE id = ?', { shopId })
        Player.Functions.SetJob('unemployed', 0)
        TriggerClientEvent('t1ger_shops:syncShops', -1, shops, Config.Shops)
        TriggerClientEvent('t1ger_shops:notify', src, Lang['shop_sold']:format(comma_value(amount)))
        lib.logger(src, 'info', ('Sold shop %s for %s'):format(shopId, amount))
end)

QBCore.Functions.CreateCallback('t1ger_shops:getAccountBalance', function(source, cb, shopId)
        local cfg = Config.Shops[shopId]
        if not cfg then
                cb(0)
                return
        end
        local society = Config.Society[cfg.society]
        if not society then
                cb(0)
                return
        end
        getSocietyBalance(society.job, cb)
end)

QBCore.Functions.CreateCallback('t1ger_shops:getUserInventory', function(source, cb)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then
                cb({})
                return
        end
        local items = {}
        for _, item in pairs(Player.PlayerData.items or {}) do
                if item and item.name then
                        items[#items + 1] = {
                                name = item.name,
                                label = item.label or (QBCore.Shared.Items[item.name] and QBCore.Shared.Items[item.name].label) or item.name,
                                count = item.amount or item.count or 0
                        }
                end
        end
        cb(items)
end)

local function updateShopStock(shopId, itemName, amount, price)
        local data = ensureShopData(shopId)
        data.stock = data.stock or {}
        local definition = getItemDefinition(itemName)
        for _, entry in ipairs(data.stock) do
                if entry.item == itemName then
                        entry.qty = (entry.qty or 0) + amount
                        if price and price >= 0 then
                                entry.price = price
                        end
                        if definition and definition.str_match then
                                entry.str_match = definition.str_match
                        end
                        return entry
                end
        end
        local label = (definition and definition.label) or (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
        local newEntry = { item = itemName, label = label, qty = amount, price = price or (definition and definition.price) or 0, str_match = definition and definition.str_match }
        table.insert(data.stock, newEntry)
        return newEntry
end

RegisterNetEvent('t1ger_shops:itemDeposit', function(shopId, itemName, label, amount, price)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local cfg = Config.Shops[shopId]
        local data = shops[shopId]
        if not Player or not cfg or not data then return end
        if data.citizenid ~= Player.PlayerData.citizenid then
                lib.logger(src, 'warn', ('Player tried to deposit item without ownership in shop %s'):format(shopId))
                return
        end
        amount = math.floor(amount or 0)
        price = math.floor(price or 0)
        if amount < 1 or price < 0 then
                lib.logger(src, 'warn', ('Invalid deposit data for shop %s: %s %s'):format(shopId, amount, price))
                return
        end
        if not isItemAllowed(shopId, itemName) then
                TriggerClientEvent('t1ger_shops:notify', src, Lang['item_not_available'], { type = 'error' })
                return
        end
        local invItem = Player.Functions.GetItemByName(itemName)
        if not invItem or (invItem.amount or invItem.count or 0) < amount then
                TriggerClientEvent('t1ger_shops:notify', src, Lang['not_enough_items'], { type = 'error' })
                return
        end
        Player.Functions.RemoveItem(itemName, amount)
        local entry = updateShopStock(shopId, itemName, amount, price)
        entry.label = label or entry.label
        saveShop(shopId)
        broadcastShop(shopId)
        TriggerClientEvent('t1ger_shops:notify', src, Lang['shelf_item_deposit']:format(amount, entry.label))
        lib.logger(src, 'info', ('Deposited %s x%s into shop %s'):format(itemName, amount, shopId))
end)

RegisterNetEvent('t1ger_shops:itemWithdraw', function(shopId, itemName, amount)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local cfg = Config.Shops[shopId]
        local data = shops[shopId]
        if not Player or not cfg or not data then return end
        if data.citizenid ~= Player.PlayerData.citizenid then
                lib.logger(src, 'warn', ('Player tried to withdraw item without ownership in shop %s'):format(shopId))
                return
        end
        amount = math.floor(amount or 0)
        if amount < 1 then
                lib.logger(src, 'warn', ('Invalid withdraw amount for shop %s'):format(shopId))
                return
        end
        local entryIndex
        local entry
        for i, stock in ipairs(data.stock or {}) do
                if stock.item == itemName then
                        entryIndex = i
                        entry = stock
                        break
                end
        end
        if not entry or (entry.qty or 0) < amount then
                TriggerClientEvent('t1ger_shops:notify', src, Lang['no_stock_in_shelf'], { type = 'error' })
                return
        end
        entry.qty = (entry.qty or 0) - amount
        if entry.qty <= 0 then
                table.remove(data.stock, entryIndex)
        end
        Player.Functions.AddItem(itemName, amount)
        saveShop(shopId)
        broadcastShop(shopId)
        TriggerClientEvent('t1ger_shops:notify', src, Lang['shelf_item_withdraw']:format(amount, entry.label))
        lib.logger(src, 'info', ('Withdrew %s x%s from shop %s'):format(itemName, amount, shopId))
end)

RegisterNetEvent('t1ger_shops:updateItemPrice', function(shopId, itemName, price)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local cfg = Config.Shops[shopId]
        local data = shops[shopId]
        if not Player or not cfg or not data then return end
        if data.citizenid ~= Player.PlayerData.citizenid then
                        lib.logger(src, 'warn', ('Player tried to update price without ownership in shop %s'):format(shopId))
                        return
        end
        price = math.floor(price or 0)
        if price < 0 then
                lib.logger(src, 'warn', ('Invalid price update for shop %s: %s'):format(shopId, price))
                return
        end
        for _, entry in ipairs(data.stock or {}) do
                if entry.item == itemName then
                        local oldPrice = entry.price or 0
                        entry.price = price
                        saveShop(shopId)
                        broadcastShop(shopId)
                        TriggerClientEvent('t1ger_shops:notify', src, Lang['shelf_item_price_change']:format(entry.label, comma_value(oldPrice), comma_value(price)))
                        lib.logger(src, 'info', ('Updated price for %s in shop %s to %s'):format(itemName, shopId, price))
                        return
                end
        end
end)

QBCore.Functions.CreateCallback('t1ger_shops:checkoutBasket', function(source, cb, basket, paymentType)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player or type(basket) ~= 'table' then
                cb(false, Lang['invalid_amount'])
                return
        end
        local shopId = basket.shopID or basket.shopId
        local cfg = Config.Shops[shopId]
        local data = shops[shopId]
        if not cfg or not cfg.owned or not data then
                cb(false, Lang['item_not_available'])
                return
        end
        if not basket.items or #basket.items == 0 then
                cb(false, Lang['basket_is_empty'])
                return
        end
        local total = 0
        local stockSnapshot = {}
        for _, entry in ipairs(data.stock or {}) do
                stockSnapshot[entry.item] = entry
        end
        for _, item in ipairs(basket.items) do
                local count = math.floor(item.count or 0)
                if count < 1 then
                        lib.logger(source, 'warn', ('Invalid basket entry for shop %s: %s'):format(shopId, item.item))
                        cb(false, Lang['invalid_amount'], data.stock)
                        return
                end
                local stockEntry = stockSnapshot[item.item]
                if not stockEntry or (stockEntry.qty or 0) < count then
                        cb(false, Lang['item_not_available'], data.stock)
                        return
                end
                total = total + (stockEntry.price or 0) * count
        end
        local accountType = paymentType == 'bank' and 'bank' or 'cash'
        if Player.Functions.GetMoney(accountType) < total then
                cb(false, Lang['not_enough_money'], data.stock)
                return
        end
        local addedItems = {}
        for _, item in ipairs(basket.items) do
                local count = math.floor(item.count or 0)
                if not Player.Functions.AddItem(item.item, count) then
                        for _, added in ipairs(addedItems) do
                                Player.Functions.RemoveItem(added.item, added.count)
                        end
                        cb(false, Lang['inventory_full'], data.stock)
                        return
                end
                addedItems[#addedItems + 1] = { item = item.item, count = count }
        end
        Player.Functions.RemoveMoney(accountType, total, 't1ger-shop-purchase-items')
        local updatedStock = {}
        for _, entry in ipairs(data.stock or {}) do
                updatedStock[#updatedStock + 1] = entry
        end
        for _, item in ipairs(basket.items) do
                local count = math.floor(item.count or 0)
                for idx, entry in ipairs(updatedStock) do
                        if entry.item == item.item then
                                entry.qty = (entry.qty or 0) - count
                                if entry.qty <= 0 then
                                        table.remove(updatedStock, idx)
                                end
                                break
                        end
                end
        end
        data.stock = updatedStock
        cfg.data = data
        saveShop(shopId)
        broadcastShop(shopId)
        local society = Config.Society[cfg.society]
        if society and society.job then
                addSocietyMoney(society.job, total)
        end
        cb(true, nil, updatedStock)
        lib.logger(source, 'info', ('Processed basket worth %s for shop %s'):format(total, shopId))
end)
