-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
local company = Config.Insurance.company or {}
local brokerCount = 0
local companyPointHandles = {}

local function IsPlayerBroker()
        if not PlayerData or not PlayerData.job then return false end
        return PlayerData.job.name == Config.Insurance.job.name
end

local function IsBrokerBoss()
        if not IsPlayerBroker() then return false end
        if PlayerData.job.isboss then return true end
        if PlayerData.job.grade and PlayerData.job.grade.isboss then
                return true
        end
        return false
end

local function FormatCurrency(amount)
        return comma_value(math.floor(tonumber(amount) or 0))
end

local function openMainMenu()
        local options = {
                {
                        title = Lang['menu_manage_insurance'],
                        description = Lang['menu_manage_description'],
                        event = 't1ger_insurance:client:managePolicies'
                }
        }

        local canBuy = true
        if Config.BuyWithOnlineBrokers and brokerCount > 0 and not IsPlayerBroker() then
                canBuy = false
        end

        options[#options + 1] = {
                title = Lang['menu_buy_insurance'],
                description = canBuy and Lang['menu_buy_description'] or Lang['notify_broker_online'],
                event = canBuy and 't1ger_insurance:client:buyPolicy' or nil,
                disabled = not canBuy
        }

        if IsBrokerBoss() then
                options[#options + 1] = {
                        title = Lang['menu_boss'],
                        description = Lang['menu_boss_description'],
                        event = 't1ger_insurance:client:bossMenu'
                }
        end

        lib.registerContext({
                id = 't1ger_insurance:main',
                title = Lang['menu_main_title'],
                options = options
        })
        lib.showContext('t1ger_insurance:main')
end

local function BuildVehicleLabel(data)
        if data.label then return data.label end
        if data.model then
                local modelHash = data.model
                if type(modelHash) == 'string' then
                        modelHash = joaat(modelHash)
                end
                local display = GetDisplayNameFromVehicleModel(modelHash)
                local label = GetLabelText(display)
                if label ~= 'CARNOTFOUND' then
                        return label
                end
        end
        return data.plate
end

RegisterNetEvent('t1ger_insurance:client:buyPolicy', function()
        local vehicles = lib.callback.await('t1ger_insurance:server:getVehicles', false)
        if not vehicles or #vehicles == 0 then
                Notify(Lang['notify_no_vehicle'], 'error')
                return
        end

        local options = {}
        for _, vehicle in ipairs(vehicles) do
                if not vehicle.insured then
                        local label = BuildVehicleLabel(vehicle)
                        options[#options + 1] = {
                                title = ('%s [%s]'):format(label, vehicle.plate),
                                description = ('Upfront: $%s | Subscription: $%s'):format(FormatCurrency(vehicle.costs.upfront), FormatCurrency(vehicle.costs.subscription)),
                                event = 't1ger_insurance:client:confirmPurchase',
                                args = { plate = vehicle.plate, costs = vehicle.costs }
                        }
                end
        end

        if #options == 0 then
                Notify(Lang['notify_no_vehicle'], 'error')
                return
        end

        lib.registerContext({
                id = 't1ger_insurance:buy',
                title = Lang['menu_buy_insurance'],
                menu = 't1ger_insurance:main',
                options = options
        })
        lib.showContext('t1ger_insurance:buy')
end)

RegisterNetEvent('t1ger_insurance:client:confirmPurchase', function(data)
        local response = lib.alertDialog({
                header = Lang['menu_buy_insurance'],
                content = ('Upfront: $%s\nSubscription: $%s'):format(FormatCurrency(data.costs.upfront), FormatCurrency(data.costs.subscription)),
                centered = true,
                cancel = true,
                labels = {
                        cancel = Lang['menu_decline'],
                        confirm = Lang['menu_confirm']
                }
        })

        if response == 'confirm' then
                TriggerServerEvent('t1ger_insurance:server:buyInsurance', data.plate)
        end
end)

RegisterNetEvent('t1ger_insurance:client:managePolicies', function()
        local vehicles = lib.callback.await('t1ger_insurance:server:getVehicles', false)
        if not vehicles or #vehicles == 0 then
                Notify(Lang['notify_no_insured'], 'error')
                return
        end

        local options = {}
        for _, vehicle in ipairs(vehicles) do
                if vehicle.insured then
                        local label = BuildVehicleLabel(vehicle)
                        options[#options + 1] = {
                                title = ('%s [%s]'):format(label, vehicle.plate),
                                description = ('Subscription: $%s'):format(FormatCurrency(vehicle.costs.subscription)),
                                event = 't1ger_insurance:client:confirmCancel',
                                args = { plate = vehicle.plate }
                        }
                end
        end

        if #options == 0 then
                Notify(Lang['notify_no_insured'], 'error')
                return
        end

        lib.registerContext({
                id = 't1ger_insurance:manage',
                title = Lang['menu_manage_insurance'],
                menu = 't1ger_insurance:main',
                options = options
        })
        lib.showContext('t1ger_insurance:manage')
end)

RegisterNetEvent('t1ger_insurance:client:confirmCancel', function(data)
        local response = lib.alertDialog({
                header = Lang['menu_cancel'],
                content = data.plate,
                centered = true,
                cancel = true,
                labels = {
                        cancel = Lang['menu_return'],
                        confirm = Lang['menu_cancel']
                }
        })

        if response == 'confirm' then
                TriggerServerEvent('t1ger_insurance:server:cancelInsurance', data.plate)
        end
end)

RegisterNetEvent('t1ger_insurance:client:bossMenu', function()
        if not IsBrokerBoss() then
                Notify(Lang['notify_not_broker'], 'error')
                return
        end

        lib.registerContext({
                id = 't1ger_insurance:boss',
                title = Lang['menu_boss'],
                menu = 't1ger_insurance:main',
                options = {
                        {
                                title = Lang['menu_boss_actions'],
                                description = Lang['menu_boss_description'],
                                event = 't1ger_insurance:client:bossActions'
                        },
                        {
                                title = Lang['menu_account_balance'],
                                description = Lang['menu_boss_description'],
                                event = 't1ger_insurance:client:bossBalance'
                        }
                }
        })
        lib.showContext('t1ger_insurance:boss')
end)

RegisterNetEvent('t1ger_insurance:client:bossActions', function()
        if not IsBrokerBoss() then
                Notify(Lang['notify_not_broker'], 'error')
                return
        end

        local opened = false
        if GetResourceState('qb-management') == 'started' then
                local ok = pcall(function()
                        exports['qb-management']:OpenBossMenu(Config.Insurance.job.name, function(data, menu)
                                if menu then menu.close() end
                        end)
                end)
                opened = ok and true or false
        end

        if not opened and GetResourceState('qb-bossmenu') == 'started' then
                TriggerEvent('qb-bossmenu:client:OpenMenu')
                opened = true
        end

        if not opened then
                Notify(Lang['notify_boss_unavailable'], 'error')
        end
end)

RegisterNetEvent('t1ger_insurance:client:bossBalance', function()
        if not IsBrokerBoss() then
                Notify(Lang['notify_not_broker'], 'error')
                return
        end
        local amount = lib.callback.await('t1ger_insurance:server:getAccountBalance', false)
        if amount then
                Notify(Lang['notify_account_balance']:format(FormatCurrency(amount)), 'inform')
        else
                Notify(Lang['notify_boss_unavailable'], 'error')
        end
end)

local function OpenPlateDialog()
        local input = lib.inputDialog(Lang['menu_view'], {
                { type = 'input', label = 'Plate', description = Lang['menu_view'], required = true, min = 1, max = 12 }
        })
        if not input or not input[1] then
                Notify(Lang['notify_plate_missing'], 'error')
                return nil
        end
        local value = tostring(input[1])
        value = value:gsub('^%s*(.-)%s*$', '%1')
        if value == '' then
                Notify(Lang['notify_plate_missing'], 'error')
                return nil
        end
        return string.upper(value)
end

local function InsuranceInteractionMenu()
        local options = {
                { title = Lang['menu_view'], event = 't1ger_insurance:client:viewSelf' },
                { title = Lang['menu_show'], event = 't1ger_insurance:client:showPlayer' }
        }

        if PlayerData.job and (PlayerData.job.name == 'police' or IsPlayerBroker()) then
                options[#options + 1] = { title = Lang['menu_check'], event = 't1ger_insurance:client:checkVehicle' }
        end

        if IsPlayerBroker() then
                options[#options + 1] = { title = Lang['menu_sell'], event = 't1ger_insurance:client:sellInsurance' }
                options[#options + 1] = { title = Lang['menu_cancel'], event = 't1ger_insurance:client:brokerCancel' }
        end

        lib.registerContext({
                id = 't1ger_insurance:interaction',
                title = Lang['menu_title_interaction'],
                options = options
        })
        lib.showContext('t1ger_insurance:interaction')
end

RegisterNetEvent('t1ger_insurance:client:viewSelf', function()
        local plate = OpenPlateDialog()
        if not plate then return end
        TriggerServerEvent('t1ger_insurance:server:openPaper', plate, GetPlayerServerId(PlayerId()))
end)

RegisterNetEvent('t1ger_insurance:client:showPlayer', function()
        local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
        if closestPlayer == -1 or closestDistance > 2.0 then
                Notify(Lang['notify_no_players'], 'error')
                return
        end
        local plate = OpenPlateDialog()
        if not plate then return end
        TriggerServerEvent('t1ger_insurance:server:openPaper', plate, GetPlayerServerId(closestPlayer))
end)

RegisterNetEvent('t1ger_insurance:client:checkVehicle', function()
        local plate = OpenPlateDialog()
        if not plate then return end
        local result = lib.callback.await('t1ger_insurance:server:getVehicleByPlate', false, plate)
        if not result then
                Notify(Lang['notify_plate_not_found'], 'error')
                return
        end
        local status = result.insured and Lang['paper_status_active'] or Lang['paper_status_inactive']
        Notify(('%s - %s'):format(plate, status), result.insured and 'success' or 'error')
end)

RegisterNetEvent('t1ger_insurance:client:sellInsurance', function()
        if not IsPlayerBroker() then
                Notify(Lang['notify_not_broker'], 'error')
                return
        end
        local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
        if closestPlayer == -1 or closestDistance > 2.0 then
                Notify(Lang['notify_no_players'], 'error')
                return
        end
        local plate = OpenPlateDialog()
        if not plate then return end
        TriggerServerEvent('t1ger_insurance:server:offerSale', plate, GetPlayerServerId(closestPlayer))
        Notify(Lang['notify_wait_confirmation'], 'inform')
end)

RegisterNetEvent('t1ger_insurance:client:brokerCancel', function()
        if not IsPlayerBroker() then
                Notify(Lang['notify_not_broker'], 'error')
                return
        end
        local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
        if closestPlayer == -1 or closestDistance > 2.0 then
                Notify(Lang['notify_no_players'], 'error')
                return
        end
        local plate = OpenPlateDialog()
        if not plate then return end
        TriggerServerEvent('t1ger_insurance:server:offerCancel', plate, GetPlayerServerId(closestPlayer))
        Notify(Lang['notify_wait_confirmation'], 'inform')
end)

RegisterNetEvent('t1ger_insurance:client:offerConfirmation', function(data)
        local message = data.type == 'sale' and Lang['menu_buy_insurance'] or Lang['menu_cancel']
        local content = data.type == 'sale' and ('Upfront: $%s\nSubscription: $%s'):format(FormatCurrency(data.costs.upfront), FormatCurrency(data.costs.subscription)) or data.plate
        local response = lib.alertDialog({
                header = message,
                content = content,
                centered = true,
                cancel = true,
                labels = {
                        cancel = Lang['menu_decline'],
                        confirm = Lang['menu_confirm']
                }
        })
        local accepted = response == 'confirm'
        TriggerServerEvent('t1ger_insurance:server:confirmOffer', data.type, data.plate, data.broker, accepted)
end)

RegisterNetEvent('t1ger_insurance:client:openPaper', function(info)
        local options = {
                { title = Lang['paper_owner']:format(info.firstname or '-', info.lastname or '-'), disabled = true },
                { title = Lang['paper_birthdate']:format(info.dateofbirth or '-'), disabled = true },
                { title = Lang['paper_gender']:format(info.sex or '-'), disabled = true },
                { title = Lang['paper_plate']:format(info.plate or '-'), disabled = true },
                { title = Lang['paper_model']:format(info.model or '-'), disabled = true },
                { title = Lang['paper_status']:format(info.insured and Lang['paper_status_active'] or Lang['paper_status_inactive']), disabled = true },
                { title = Lang['paper_close'], event = 't1ger_insurance:client:closePaper' }
        }

        lib.registerContext({
                id = 't1ger_insurance:paper',
                title = Lang['paper_title']:format(info.plate or 'N/A'),
                options = options
        })
        lib.showContext('t1ger_insurance:paper')
end)

RegisterNetEvent('t1ger_insurance:client:closePaper', function()
        lib.hideContext()
end)

RegisterNetEvent('t1ger_insurance:client:updateBrokerCount', function(count)
        brokerCount = count
end)

RegisterNetEvent('t1ger_insurance:client:notify', function(message, notifType)
        Notify(message, notifType)
end)

RegisterNetEvent('t1ger_insurance:client:payInsuranceBill', function()
        TriggerServerEvent('t1ger_insurance:server:payInsuranceBill')
end)

RegisterCommand(Config.Insurance.job.menu.command, function()
        InsuranceInteractionMenu()
end, false)

CreateThread(function()
        while true do
                Wait(1)
                if IsControlJustReleased(0, Config.Insurance.job.menu.keybind) then
                        InsuranceInteractionMenu()
                end
        end
end)

RegisterNetEvent('t1ger_insurance:client:openMenu', function()
        openMainMenu()
end)

local function CreateCompanyPoint(point)
        return lib.points.new({
                coords = point.coords,
                distance = point.loadDist or 10.0,
                onEnter = function(self)
                        self.point = point
                end,
                nearby = function(self)
                        local ped = PlayerPedId()
                        local coords = GetEntityCoords(ped)
                        local distance = #(coords - self.coords)
                        local marker = self.point.marker or {}
                        if marker.enable and distance <= (marker.drawDist or self.point.loadDist or 10.0) then
                                DrawMarker(marker.type or 1, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                        marker.scale and marker.scale.x or 0.5,
                                        marker.scale and marker.scale.y or 0.5,
                                        marker.scale and marker.scale.z or 0.5,
                                        marker.color and marker.color.r or 255,
                                        marker.color and marker.color.g or 255,
                                        marker.color and marker.color.b or 255,
                                        marker.color and marker.color.a or 150,
                                        false, true, 2, false, nil, nil, false)
                        end
                        if distance <= (self.point.interactDist or 1.5) then
                                DrawText3Ds(self.coords.x, self.coords.y, self.coords.z, Lang['draw_menu'])
                                if IsControlJustReleased(0, self.point.menuKey or company.menuKey or 38) then
                                        openMainMenu()
                                end
                        end
                        Wait(0)
                end
        })
end

CreateThread(function()
        local points = GetInsurancePoints()
        for _, point in ipairs(points) do
                local handle = CreateCompanyPoint(point)
                companyPointHandles[#companyPointHandles + 1] = handle
        end
end)

AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        for _, handle in ipairs(companyPointHandles) do
                if handle and handle.remove then
                        handle:remove()
                end
        end
end)
