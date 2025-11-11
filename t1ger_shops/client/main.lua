-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
local targetEnabled = GetResourceState('ox_target') == 'started'

local shops = {}
local shopBlips = {}
local isOwner = 0
local shopID = 0
local bossPoints, cashierPoints = {}, {}
local bossTargetZones, cashierTargetZones = {}, {}
local basket = { bill = 0, items = {}, shopID = 0 }

local function resetBasket()
        basket = { bill = 0, items = {}, shopID = 0 }
end

local function findStockItem(shopId, itemName)
        local data = Config.Shops[shopId].data
        if not data or not data.stock then return nil end
        for index, stock in ipairs(data.stock) do
                if stock.item == itemName then
                        return stock, index
                end
        end
end

local function removeShopBlip(id)
        if shopBlips[id] then
                RemoveBlip(shopBlips[id])
                shopBlips[id] = nil
        end
end

local function updateShopBlip(id)
        local cfg = Config.Shops[id]
        if not cfg or not cfg.b_menu then
                removeShopBlip(id)
                return
        end

        local mk = Config.BlipSettings[cfg.type]
        if not mk or not mk.enable then
                removeShopBlip(id)
                return
        end

        local labelPrefix = ''
        if cfg.owned and isOwner == cfg.data.id then
                labelPrefix = Lang['blip_owned_prefix'] or 'Your '
        end

        local coords = cfg.b_menu
        removeShopBlip(id)
        local blip = AddBlipForCoord(coords[1], coords[2], coords[3])
        SetBlipSprite(blip, mk.sprite)
        SetBlipDisplay(blip, mk.display)
        SetBlipScale(blip, mk.scale)
        SetBlipColour(blip, mk.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(labelPrefix .. (mk.name or 'Shop'))
        EndTextCommandSetBlipName(blip)
        shopBlips[id] = blip
end

local function UpdateShopBlips(targetId)
        if targetId then
                updateShopBlip(targetId)
                return
        end

        for id = 1, #Config.Shops do
                updateShopBlip(id)
        end
end

local function removePoints(list)
        for _, point in pairs(list) do
                if point and point.remove then
                        point:remove()
                end
        end
end

local function removeTargets(list)
        for id, zone in pairs(list) do
                if zone then
                        exports.ox_target:removeZone(zone)
                        list[id] = nil
                end
        end
end

local function getBossLabel(shopId)
        local cfg = Config.Shops[shopId]
        if not cfg then return Lang['text_no_access'] end
        if not cfg.buyable and not cfg.owned then
                return Lang['text_no_access']
        end
        if cfg.owned then
                if isOwner == shopId then
                        return Lang['text_manage_shop']
                end
                local society = Config.Society[cfg.society]
                local job = PlayerData and PlayerData.job or nil
                local grade = job and job.grade and (job.grade.level or job.grade) or 0
                if society and job and job.name == society.job and grade >= society.boss_grade then
                        return Lang['text_manage_shop']
                end
                return Lang['text_no_access']
        end
        return Lang['text_buy_shop']:format(comma_value(math.floor(cfg.price)))
end

local function isPlayerAuthorized(shopId)
        if isOwner == shopId then return true end
        local cfg = Config.Shops[shopId]
        if not cfg then return false end
        local society = Config.Society[cfg.society]
        if not society then return false end
        local job = PlayerData and PlayerData.job or nil
        if not job or job.name ~= society.job then return false end
        local grade = job.grade and (job.grade.level or job.grade) or 0
        return grade >= society.boss_grade
end

local function clearInteractionPoints()
        removePoints(bossPoints)
        removePoints(cashierPoints)
        removeTargets(bossTargetZones)
        removeTargets(cashierTargetZones)
        bossPoints, cashierPoints = {}, {}
end

local function openBossMenu(shopId)
        lib.hideTextUI()
        local cfg = Config.Shops[shopId]
        if not cfg then return end
        local contextId = ('t1ger_shops:boss:%s'):format(shopId)
        local options = {}
        if not cfg.owned then
                if not cfg.buyable then
                        options[#options + 1] = { title = Lang['text_no_access'], disabled = true }
                else
                        options[#options + 1] = {
                                title = Lang['shop_purchase_title'],
                                description = ('%s - $%s'):format(cfg.label or ('Shop #' .. shopId), comma_value(cfg.price)),
                                icon = 'fa-solid fa-store',
                                onSelect = function()
                                        lib.registerContext({
                                                id = contextId .. ':confirm',
                                                title = Lang['shop_purchase_title'],
                                                options = {
                                                        {
                                                                title = Lang['option_confirm'],
                                                                description = Lang['shop_purchase_confirm']:format(comma_value(cfg.price)),
                                                                icon = 'fa-solid fa-circle-check',
                                                                onSelect = function()
                                                                        QBCore.Functions.TriggerCallback('t1ger_shops:purchaseShop', function(purchased, message)
                                                                                if purchased then
                                                                                        TriggerEvent('t1ger_shops:notify', Lang['shop_purchased']:format(comma_value(cfg.price)))
                                                                                        isOwner = shopId
                                                                                else
                                                                                        TriggerEvent('t1ger_shops:notify', message or Lang['not_enough_money'], { type = 'error' })
                                                                                end
                                                                        end, shopId)
                                                                end
                                                        },
                                                        { title = Lang['option_cancel'], icon = 'fa-solid fa-circle-xmark' }
                                                }
                                        })
                                        lib.showContext(contextId .. ':confirm')
                                end
                        }
                end
        else
                if not isPlayerAuthorized(shopId) then
                        options[#options + 1] = { title = Lang['boss_menu_no_access'], disabled = true }
                else
                        options[#options + 1] = {
                                title = Lang['owner_manage_stock'],
                                icon = 'fa-solid fa-boxes-stacked',
                                onSelect = function()
                                        lib.showContext(('t1ger_shops:stock:%s'):format(shopId))
                                end
                        }
                        options[#options + 1] = {
                                title = Lang['owner_view_account'],
                                icon = 'fa-solid fa-piggy-bank',
                                onSelect = function()
                                        QBCore.Functions.TriggerCallback('t1ger_shops:getAccountBalance', function(balance)
                                                if balance then
                                                        TriggerEvent('t1ger_shops:notify', Lang['get_account_balance']:format(comma_value(balance)))
                                                else
                                                        TriggerEvent('t1ger_shops:notify', Lang['invalid_amount'], { type = 'error' })
                                                end
                                        end, shopId)
                                end
                        }
                        options[#options + 1] = {
                                title = Lang['owner_sell_shop'],
                                icon = 'fa-solid fa-handshake-slash',
                                onSelect = function()
                                        local sellPrice = math.floor(cfg.price * Config.SalePercentage)
                                        lib.registerContext({
                                                id = contextId .. ':sell',
                                                title = Lang['owner_sell_shop'],
                                                options = {
                                                        {
                                                                title = Lang['option_confirm'],
                                                                description = Lang['shop_sell_desc']:format(comma_value(sellPrice)),
                                                                icon = 'fa-solid fa-circle-check',
                                                                onSelect = function()
                                                                        TriggerServerEvent('t1ger_shops:sellShop', shopId, sellPrice)
                                                                end
                                                        },
                                                        { title = Lang['option_cancel'], icon = 'fa-solid fa-circle-xmark' }
                                                }
                                        })
                                        lib.showContext(contextId .. ':sell')
                                end
                        }
                end
        end
        if #options == 0 then
                options[#options + 1] = { title = Lang['text_no_access'], disabled = true }
        end
        lib.registerContext({ id = contextId, title = cfg.label or ('Shop #' .. shopId), options = options })
        lib.showContext(contextId)
end

local function openBasketMenu()
        if basket.shopID == 0 or #basket.items == 0 then
                TriggerEvent('t1ger_shops:notify', Lang['basket_is_empty'], { type = 'error' })
                return
        end
        local contextId = 't1ger_shops:basket'
        local options = {}
        for index, item in ipairs(basket.items) do
                options[#options + 1] = {
                        title = ('%s x%s'):format(item.label, item.count),
                        description = Lang['basket_item_price']:format(comma_value(item.price), comma_value(item.price * item.count)),
                        icon = 'fa-solid fa-box',
                        metadata = { { label = Lang['metadata_item'], value = item.item } },
                        onSelect = function()
                                local stockItem = findStockItem(basket.shopID, item.item)
                                if stockItem then
                                        stockItem.qty = stockItem.qty + item.count
                                else
                                        local data = Config.Shops[basket.shopID].data
                                        data.stock = data.stock or {}
                                        data.stock[#data.stock + 1] = {
                                                item = item.item,
                                                label = item.label,
                                                price = item.price,
                                                qty = item.count,
                                                str_match = item.str_match
                                        }
                                end
                                basket.bill = basket.bill - (item.price * item.count)
                                TriggerEvent('t1ger_shops:notify', Lang['basket_item_removed']:format(item.count, item.label))
                                table.remove(basket.items, index)
                                if #basket.items == 0 then
                                        resetBasket()
                                        lib.hideContext()
                                else
                                        openBasketMenu()
                                end
                        end
                }
        end
        options[#options + 1] = { title = Lang['basket_total']:format(comma_value(basket.bill)), icon = 'fa-solid fa-dollar-sign', disabled = true }
        options[#options + 1] = {
                title = Lang['basket_checkout_cash'],
                icon = 'fa-solid fa-money-bill-wave',
                onSelect = function()
                        QBCore.Functions.TriggerCallback('t1ger_shops:checkoutBasket', function(success, message, stock)
                                if stock then
                                        Config.Shops[basket.shopID].data.stock = stock
                                end
                                if success then
                                        TriggerEvent('t1ger_shops:notify', Lang['basket_paid']:format(comma_value(basket.bill)))
                                        resetBasket()
                                        lib.hideContext()
                                else
                                        TriggerEvent('t1ger_shops:notify', message or Lang['item_not_available'], { type = 'error' })
                                end
                        end, basket, 'cash')
                end
        }
        options[#options + 1] = {
                title = Lang['basket_checkout_bank'],
                icon = 'fa-solid fa-credit-card',
                onSelect = function()
                        QBCore.Functions.TriggerCallback('t1ger_shops:checkoutBasket', function(success, message, stock)
                                if stock then
                                        Config.Shops[basket.shopID].data.stock = stock
                                end
                                if success then
                                        TriggerEvent('t1ger_shops:notify', Lang['basket_paid']:format(comma_value(basket.bill)))
                                        resetBasket()
                                        lib.hideContext()
                                else
                                        TriggerEvent('t1ger_shops:notify', message or Lang['item_not_available'], { type = 'error' })
                                end
                        end, basket, 'bank')
                end
        }
        options[#options + 1] = {
                title = Lang['basket_empty'],
                icon = 'fa-solid fa-trash',
                onSelect = function()
                        local data = Config.Shops[basket.shopID].data
                        data.stock = data.stock or {}
                        for _, item in ipairs(basket.items) do
                                local stockItem = findStockItem(basket.shopID, item.item)
                                if stockItem then
                                        stockItem.qty = stockItem.qty + item.count
                                else
                                        data.stock[#data.stock + 1] = {
                                                item = item.item,
                                                label = item.label,
                                                price = item.price,
                                                qty = item.count,
                                                str_match = item.str_match
                                        }
                                end
                        end
                        resetBasket()
                        TriggerEvent('t1ger_shops:notify', Lang['you_emptied_basket'])
                        lib.hideContext()
                end
        }
        lib.registerContext({ id = contextId, title = Lang['basket_menu_title'], options = options })
        lib.showContext(contextId)
end

local function setupStockContexts(shopId)
        local stockId = ('t1ger_shops:stock:%s'):format(shopId)
        local cfg = Config.Shops[shopId]
        local stock = cfg.data and cfg.data.stock or {}
        local options = {
                {
                        title = Lang['stock_deposit_item'],
                        icon = 'fa-solid fa-circle-plus',
                        onSelect = function()
                                QBCore.Functions.TriggerCallback('t1ger_shops:getUserInventory', function(items)
                                        if not items or #items == 0 then
                                                TriggerEvent('t1ger_shops:notify', Lang['not_enough_items'], { type = 'error' })
                                                return
                                        end
                                        local context = stockId .. ':deposit'
                                        local depositOptions = {}
                                        for _, inv in ipairs(items) do
                                                if inv.count and inv.count > 0 then
                                                        depositOptions[#depositOptions + 1] = {
                                                                title = ('%s (%s)'):format(inv.label, inv.count),
                                                                onSelect = function()
                                                                        local input = lib.inputDialog(Lang['stock_input_deposit'], {
                                                                                { type = 'number', label = Lang['input_amount'], default = 1, min = 1, max = inv.count },
                                                                                { type = 'number', label = Lang['input_price'], default = inv.price or 0, min = 0 }
                                                                        })
                                                                        if not input then return end
                                                                        local amount = tonumber(input[1]) or 0
                                                                        local price = tonumber(input[2]) or 0
                                                                        if amount < 1 then
                                                                                TriggerEvent('t1ger_shops:notify', Lang['invalid_amount'], { type = 'error' })
                                                                                return
                                                                        end
                                                                        TriggerServerEvent('t1ger_shops:itemDeposit', shopId, inv.name, inv.label, amount, price)
                                                                end
                                                        }
                                                end
                                        end
                                        if #depositOptions == 0 then
                                                depositOptions[#depositOptions + 1] = { title = Lang['not_enough_items'], disabled = true }
                                        end
                                        lib.registerContext({ id = context, title = Lang['stock_deposit_item'], options = depositOptions })
                                        lib.showContext(context)
                                end)
                        end
                }
        }
        if stock and #stock > 0 then
                for _, item in ipairs(stock) do
                        options[#options + 1] = {
                                title = ('%s x%s'):format(item.label, item.qty),
                                description = Lang['stock_item_price']:format(comma_value(item.price)),
                                icon = 'fa-solid fa-box',
                                onSelect = function()
                                        local itemContext = stockId .. ':item:' .. item.item
                                        lib.registerContext({
                                                id = itemContext,
                                                title = item.label,
                                                options = {
                                                        {
                                                                title = Lang['stock_change_price'],
                                                                icon = 'fa-solid fa-tag',
                                                                onSelect = function()
                                                                        local input = lib.inputDialog(Lang['stock_change_price'], {
                                                                                { type = 'number', label = Lang['input_price'], default = item.price, min = 0 }
                                                                        })
                                                                        if not input then return end
                                                                        local price = tonumber(input[1]) or 0
                                                                        if price < 0 then
                                                                                TriggerEvent('t1ger_shops:notify', Lang['invalid_amount'], { type = 'error' })
                                                                                return
                                                                        end
                                                                        TriggerServerEvent('t1ger_shops:updateItemPrice', shopId, item.item, price)
                                                                end
                                                        },
                                                        {
                                                                title = Lang['stock_withdraw_item'],
                                                                icon = 'fa-solid fa-box-open',
                                                                onSelect = function()
                                                                        local input = lib.inputDialog(Lang['stock_withdraw_item'], {
                                                                                { type = 'number', label = Lang['input_amount'], default = 1, min = 1, max = item.qty }
                                                                        })
                                                                        if not input then return end
                                                                        local amount = tonumber(input[1]) or 0
                                                                        if amount < 1 or amount > item.qty then
                                                                                TriggerEvent('t1ger_shops:notify', Lang['invalid_amount'], { type = 'error' })
                                                                                return
                                                                        end
                                                                        TriggerServerEvent('t1ger_shops:itemWithdraw', shopId, item.item, amount)
                                                                end
                                                        }
                                                }
                                        })
                                        lib.showContext(itemContext)
                                end
                        }
                end
        else
                options[#options + 1] = { title = Lang['no_items_to_display'], disabled = true }
        end
        lib.registerContext({ id = stockId, title = Lang['owner_manage_stock'], options = options })
end

local function openCashierMenu(shopId)
        lib.hideTextUI()
        local cfg = Config.Shops[shopId]
        if not cfg or not cfg.owned then
                TriggerEvent('t1ger_shops:notify', Lang['item_not_available'], { type = 'error' })
                return
        end
        if basket.shopID ~= 0 and basket.shopID ~= shopId and #basket.items > 0 then
                resetBasket()
        end
        local stock = cfg.data and cfg.data.stock or {}
        local options = {}
        local contextId = ('t1ger_shops:cashier:%s'):format(shopId)
        local hasStock = false
        for _, item in ipairs(stock) do
                if item.qty and item.qty > 0 then
                        hasStock = true
                        options[#options + 1] = {
                                title = ('%s - $%s'):format(item.label, comma_value(item.price)),
                                description = Lang['stock_available']:format(item.qty),
                                icon = 'fa-solid fa-cart-shopping',
                                onSelect = function()
                                        local input = lib.inputDialog(item.label, {
                                                { type = 'number', label = Lang['input_amount'], default = 1, min = 1, max = item.qty }
                                        })
                                        if not input then return end
                                        local amount = tonumber(input[1]) or 0
                                        if amount < 1 or amount > item.qty then
                                                TriggerEvent('t1ger_shops:notify', Lang['invalid_amount'], { type = 'error' })
                                                return
                                        end
                                        basket.shopID = shopId
                                        basket.items[#basket.items + 1] = {
                                                item = item.item,
                                                label = item.label,
                                                count = amount,
                                                price = item.price,
                                                str_match = item.str_match
                                        }
                                        basket.bill = basket.bill + (item.price * amount)
                                        item.qty = item.qty - amount
                                        TriggerEvent('t1ger_shops:notify', Lang['basket_item_added']:format(amount, item.label, comma_value(item.price * amount)))
                                end
                        }
                end
        end
        options[#options + 1] = {
                title = Lang['basket_menu_title'],
                icon = 'fa-solid fa-basket-shopping',
                disabled = (#basket.items == 0 or basket.shopID ~= shopId),
                onSelect = openBasketMenu
        }
        if not hasStock then
                options[#options + 1] = { title = Lang['no_stock_in_shelf'], disabled = true }
        end
        lib.registerContext({ id = contextId, title = cfg.label or ('Shop #' .. shopId), options = options })
        lib.showContext(contextId)
end

local function setupInteractionPoints()
        clearInteractionPoints()
        for id, cfg in ipairs(Config.Shops) do
                if cfg.b_menu then
                        bossPoints[id] = lib.points.new({
                                coords = vec3(cfg.b_menu[1], cfg.b_menu[2], cfg.b_menu[3]),
                                distance = 20,
                                onEnter = function(point)
                                        point.tick = point:onTick(function()
                                                local label = getBossLabel(id)
                                                local marker = Config.MarkerSettings['boss']
                                                if marker and marker.enable and point.distance <= marker.drawDist and point.distance >= 2.0 then
                                                        DrawMarker(marker.type, cfg.b_menu[1], cfg.b_menu[2], cfg.b_menu[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2)
                                                end
                                                if point.distance <= 2.0 then
                                                        if point.currentLabel ~= label then
                                                                lib.showTextUI(label)
                                                                point.currentLabel = label
                                                        end
                                                        if IsControlJustReleased(0, Config.KeyControls['boss_menu']) then
                                                                setupStockContexts(id)
                                                                openBossMenu(id)
                                                        end
                                                elseif point.currentLabel then
                                                        lib.hideTextUI()
                                                        point.currentLabel = nil
                                                end
                                        end)
                                end,
                                onExit = function(point)
                                        if point.tick then
                                                point:removeTick(point.tick)
                                                point.tick = nil
                                        end
                                        if point.currentLabel then
                                                lib.hideTextUI()
                                                point.currentLabel = nil
                                        end
                                end
                        })
                        if targetEnabled then
                                bossTargetZones[id] = exports.ox_target:addSphereZone({
                                        coords = vec3(cfg.b_menu[1], cfg.b_menu[2], cfg.b_menu[3]),
                                        radius = 1.5,
                                        options = {
                                                {
                                                        name = ('t1ger_shops:boss:%s'):format(id),
                                                        icon = 'fa-solid fa-store',
                                                        label = Lang['target_boss'] or 'Shop management',
                                                        onSelect = function()
                                                                setupStockContexts(id)
                                                                openBossMenu(id)
                                                        end,
                                                        canInteract = function()
                                                                local cfg = Config.Shops[id]
                                                                if not cfg then return false end
                                                                if not cfg.owned then
                                                                        return cfg.buyable ~= false
                                                                end
                                                                return isPlayerAuthorized(id)
                                                        end
                                                }
                                        }
                                })
                        end
                end
                if cfg.cashier then
                        cashierPoints[id] = lib.points.new({
                                coords = vec3(cfg.cashier[1], cfg.cashier[2], cfg.cashier[3]),
                                distance = 20,
                                onEnter = function(point)
                                        point.tick = point:onTick(function()
                                                local marker = Config.MarkerSettings['cashier']
                                                if marker and marker.enable and point.distance <= marker.drawDist and point.distance >= 2.0 then
                                                        DrawMarker(marker.type, cfg.cashier[1], cfg.cashier[2], cfg.cashier[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2)
                                                end
                                                if point.distance <= 2.0 then
                                                        local label = Lang['text_cashier']
                                                        if point.currentLabel ~= label then
                                                                lib.showTextUI(label)
                                                                point.currentLabel = label
                                                        end
                                                        if IsControlJustReleased(0, Config.KeyControls['cashier']) then
                                                                openCashierMenu(id)
                                                        end
                                                elseif point.currentLabel then
                                                        lib.hideTextUI()
                                                        point.currentLabel = nil
                                                        if basket.shopID == id and #basket.items > 0 then
                                                                TriggerEvent('t1ger_shops:notify', Lang['basket_emptied'])
                                                                resetBasket()
                                                        end
                                                end
                                        end)
                                end,
                                onExit = function(point)
                                        if point.tick then
                                                point:removeTick(point.tick)
                                                point.tick = nil
                                        end
                                        if point.currentLabel then
                                                lib.hideTextUI()
                                                point.currentLabel = nil
                                        end
                                end
                        })
                        if targetEnabled then
                                cashierTargetZones[id] = exports.ox_target:addSphereZone({
                                        coords = vec3(cfg.cashier[1], cfg.cashier[2], cfg.cashier[3]),
                                        radius = 1.5,
                                        options = {
                                                {
                                                        name = ('t1ger_shops:cashier:%s'):format(id),
                                                        icon = 'fa-solid fa-basket-shopping',
                                                        label = Lang['target_cashier'] or 'Open shop',
                                                        onSelect = function()
                                                                openCashierMenu(id)
                                                        end
                                                }
                                        }
                                })
                        end
                end
        end
end

RegisterNetEvent('t1ger_shops:loadShops', function(results, cfg, num, id)
        Config.Shops = cfg
        shops = results
        isOwner = num or 0
        shopID = id or 0
        UpdateShopBlips()
        setupInteractionPoints()
end)

RegisterNetEvent('t1ger_shops:syncShops', function(results, cfg)
        Config.Shops = cfg
        shops = results
        UpdateShopBlips()
        setupInteractionPoints()
end)

RegisterNetEvent('t1ger_shops:updateShopsDataCL', function(id, data, serverData)
        Config.Shops[id].data = data
        shops = serverData
        setupStockContexts(id)
end)

RegisterNetEvent('t1ger_shops:setShopID', function(id)
        shopID = id or 0
end)

RegisterCommand(Config.BasketCommand, function()
        openBasketMenu()
end, false)

RegisterCommand(Config.ShelfCommand, function()
        if shopID == 0 then
                                TriggerEvent('t1ger_shops:notify', Lang['not_inside_your_shop'], { type = 'error' })
                return
        end
        if not isPlayerAuthorized(shopID) then
                TriggerEvent('t1ger_shops:notify', Lang['boss_menu_no_access'], { type = 'error' })
                return
        end
        setupStockContexts(shopID)
        lib.showContext(('t1ger_shops:stock:%s'):format(shopID))
end, false)

AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        clearInteractionPoints()
        lib.hideTextUI()
end)
