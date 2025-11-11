-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local pawnshopPoints = {}

local function showPrompt(point, shop)
    if point.promptVisible then return end
    local keyLabel = KeyString(shop.keyBind)
    local prompt = Lang[shop.prompt] or shop.prompt
    lib.showTextUI(prompt:format(keyLabel))
    point.promptVisible = true
end

local function hidePrompt(point)
    if not point.promptVisible then return end
    lib.hideTextUI()
    point.promptVisible = false
end

local function transactionDialog(action, itemName)
    local descriptions = {
        buy = Lang['input_amount_desc_buy'],
        sell = Lang['input_amount_desc_sell']
    }

    local response = lib.inputDialog(Lang['input_amount_title'], {
        {
            type = 'number',
            label = Lang['input_amount_label'],
            description = descriptions[action] or '',
            required = true,
            min = 1,
            default = 1
        }
    })

    if not response then return end

    local amount = tonumber(response[1])
    if not amount then
        TriggerEvent('t1ger_pawnshop:notify', Lang['invalid_amount'], 'error')
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        TriggerEvent('t1ger_pawnshop:notify', Lang['quantity_limit'], 'error')
        return
    end

    local result = lib.callback.await('t1ger_pawnshop:processTransaction', false, {
        action = action,
        item = itemName,
        amount = amount
    })

    if not result then
        TriggerEvent('t1ger_pawnshop:notify', Lang['transaction_failed'], 'error')
        return
    end

    if result.success then
        TriggerEvent('t1ger_pawnshop:notify', result.message, 'success')
    else
        TriggerEvent('t1ger_pawnshop:notify', result.message, 'error')
    end
end

local function openBuyMenu(shopId)
    local menuId = ('t1ger_pawnshop_%s_buy'):format(shopId)
    local mainMenu = ('t1ger_pawnshop_%s_main'):format(shopId)
    local options = {}

    for itemName, itemData in pairs(Config.Items) do
        if itemData.buy and itemData.buy.enabled then
            options[#options + 1] = {
                title = itemData.label,
                description = (Lang['buy_price']):format(itemData.buy.price),
                icon = 'fas fa-cart-shopping',
                onSelect = function()
                    transactionDialog('buy', itemName)
                end
            }
        end
    end

    if #options == 0 then
        options[#options + 1] = {
            title = Lang['item_disabled'],
            disabled = true
        }
    end

    options[#options + 1] = {
        title = Lang['return'],
        menu = mainMenu
    }

    lib.registerContext({
        id = menuId,
        title = Lang['buy_menu_title'],
        menu = mainMenu,
        options = options
    })

    lib.showContext(menuId)
end

local function openSellMenu(shopId)
    local menuId = ('t1ger_pawnshop_%s_sell'):format(shopId)
    local mainMenu = ('t1ger_pawnshop_%s_main'):format(shopId)
    local options = {}

    for itemName, itemData in pairs(Config.Items) do
        if itemData.sell and itemData.sell.enabled then
            options[#options + 1] = {
                title = itemData.label,
                description = (Lang['sell_price']):format(itemData.sell.price),
                icon = 'fas fa-dollar-sign',
                onSelect = function()
                    transactionDialog('sell', itemName)
                end
            }
        end
    end

    if #options == 0 then
        options[#options + 1] = {
            title = Lang['item_disabled'],
            disabled = true
        }
    end

    options[#options + 1] = {
        title = Lang['return'],
        menu = mainMenu
    }

    lib.registerContext({
        id = menuId,
        title = Lang['sell_menu_title'],
        menu = mainMenu,
        options = options
    })

    lib.showContext(menuId)
end

local function openPawnshopMenu(shopId)
    local menuId = ('t1ger_pawnshop_%s_main'):format(shopId)

    lib.registerContext({
        id = menuId,
        title = Lang['pawnshop_title'],
        options = {
            {
                title = Lang['buy'],
                icon = 'fas fa-cart-shopping',
                onSelect = function()
                    openBuyMenu(shopId)
                end
            },
            {
                title = Lang['sell'],
                icon = 'fas fa-hand-holding-dollar',
                onSelect = function()
                    openSellMenu(shopId)
                end
            }
        }
    })

    lib.showContext(menuId)
end

CreateThread(function()
    for id, shop in ipairs(Config.Pawnshops) do
        local point = lib.points.new({
            coords = shop.coords,
            distance = Config.MarkerDrawDistance
        })

        function point:onEnter()
            self.promptVisible = false
        end

        function point:onExit()
            hidePrompt(self)
        end

        function point:nearby()
            if shop.marker.enable and self.currentDistance <= Config.MarkerDrawDistance then
                DrawMarker(
                    shop.marker.type,
                    shop.coords.x, shop.coords.y, shop.coords.z - 0.975,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    shop.marker.scale.x, shop.marker.scale.y, shop.marker.scale.z,
                    shop.marker.color.r, shop.marker.color.g, shop.marker.color.b, shop.marker.color.a,
                    false, true, 2, false, false, false, false
                )
            end

            if self.currentDistance <= Config.InteractDistance then
                showPrompt(self, shop)

                if IsControlJustReleased(0, shop.keyBind) then
                    hidePrompt(self)
                    openPawnshopMenu(id)
                end
            else
                hidePrompt(self)
            end
        end

        pawnshopPoints[#pawnshopPoints + 1] = point
    end
end)

CreateThread(function()
    for _, shop in ipairs(Config.Pawnshops) do
        local blipConfig = shop.blip
        if blipConfig and blipConfig.enable then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, blipConfig.sprite)
            SetBlipDisplay(blip, blipConfig.display)
            SetBlipScale(blip, blipConfig.scale)
            SetBlipColour(blip, blipConfig.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipConfig.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)
