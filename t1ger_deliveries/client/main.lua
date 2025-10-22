local ClientUtils = ClientUtils
local SharedUtils = SharedUtils
local QBCore = exports['qb-core']:GetCoreObject()

local companyState = {}
local ownedCompanyId = 0
local assignedCompanyId = 0
local companyBlips = {}
local companyZones = {}
local activeDelivery = nil

local function removeCompanyBlips()
    for _, blip in ipairs(companyBlips) do
        RemoveBlip(blip)
    end

    companyBlips = {}
end

local function createCompanyBlips()
    removeCompanyBlips()

    local settings = Config.BlipSettings and Config.BlipSettings.company

    if not settings or not settings.enable then
        return
    end

    for id, company in pairs(Config.Companies) do
        local blip = AddBlipForCoord(company.menu.x, company.menu.y, company.menu.z)
        SetBlipSprite(blip, settings.sprite or 477)
        SetBlipDisplay(blip, settings.display or 4)
        SetBlipScale(blip, settings.scale or 0.65)
        SetBlipColour(blip, settings.color or 0)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')

        local displayName = company.name
        local state = companyState[id]
        if state and state.data and state.data.name then
            displayName = state.data.name
        end

        AddTextComponentString(displayName)
        EndTextCommandSetBlipName(blip)

        companyBlips[#companyBlips + 1] = blip
    end
end

local function destroyCompanyZones()
    for _, zone in pairs(companyZones) do
        zone:remove()
    end

    companyZones = {}
end

local function openBossMenu(company)
    if GetResourceState('qb-bossmenu') == 'started' then
        TriggerEvent('qb-bossmenu:client:OpenMenu')
        return
    end

    if GetResourceState('qb-management') == 'started' then
        TriggerEvent('qb-management:client:OpenMenu')
        return
    end

    ClientUtils.Notify(Lang['company_locked'], 'error')
end

local function buildContextOptions(companyId, company)
    local state = companyState[companyId]
    local ownedByPlayer = ownedCompanyId == companyId
    local options = {}

    if not state or not state.owned then
        options[#options + 1] = {
            title = Lang['menu_purchase_company'],
            icon = 'fa-solid fa-cash-register',
            description = string.format(Lang['company_purchase_confirm'], SharedUtils.FormatCurrency(company.price)),
            onSelect = function()
                TriggerEvent('t1ger_deliveries:client:purchaseCompany', companyId)
            end
        }

        return options
    end

    if not ownedByPlayer and not ClientUtils.HasJob(company.jobName) then
        options[#options + 1] = {
            title = Lang['company_locked'],
            disabled = true
        }

        return options
    end

    options[#options + 1] = {
        title = Lang['menu_request_job'],
        icon = 'fa-solid fa-truck-ramp-box',
        onSelect = function()
            TriggerEvent('t1ger_deliveries:client:requestJobMenu', companyId)
        end
    }

    if activeDelivery and activeDelivery.companyId == companyId then
        options[#options + 1] = {
            title = Lang['menu_cancel_job'],
            icon = 'fa-solid fa-ban',
            onSelect = function()
                TriggerEvent('t1ger_deliveries:client:cancelDelivery')
            end
        }
    end

    if ownedByPlayer then
        options[#options + 1] = {
            title = Lang['menu_rename_company'],
            icon = 'fa-solid fa-pen-to-square',
            onSelect = function()
                TriggerEvent('t1ger_deliveries:client:renameCompany', companyId)
            end
        }

        options[#options + 1] = {
            title = Lang['menu_sell_company'],
            icon = 'fa-solid fa-money-bill-transfer',
            onSelect = function()
                TriggerEvent('t1ger_deliveries:client:sellCompany', companyId)
            end
        }

        if state.data and not state.data.certificate then
            options[#options + 1] = {
                title = Lang['menu_certificate'],
                icon = 'fa-solid fa-id-card',
                onSelect = function()
                    TriggerEvent('t1ger_deliveries:client:buyCertificate', companyId)
                end
            }
        end
    end

    if state and state.data then
        options[#options + 1] = {
            title = string.format(Lang['menu_level'], state.data.level or 0),
            disabled = true
        }
    end

    if ClientUtils.IsPlayerBoss(company.jobName) then
        options[#options + 1] = {
            title = Lang['menu_boss_actions'],
            icon = 'fa-solid fa-briefcase',
            onSelect = function()
                openBossMenu(company)
            end
        }
    end

    return options
end

local function openCompanyMenu(companyId)
    local company = Config.Companies[companyId]

    if not company then
        return
    end

    local options = buildContextOptions(companyId, company)

    ClientUtils.OpenContext(('t1ger:deliveries:company:%s'):format(companyId), company.name, options)
end

local function createCompanyZones()
    destroyCompanyZones()

    for id, company in pairs(Config.Companies) do
        companyZones[id] = lib.zones.sphere({
            coords = company.menu,
            radius = 2.5,
            debug = Config.Debug,
            inside = function(zone)
                if not ClientUtils.HasJob(company.jobName) and ownedCompanyId ~= id and companyState[id] and companyState[id].owned then
                    ClientUtils.ShowText(Lang['draw_company_locked'])
                else
                    ClientUtils.ShowText(Lang['draw_company_menu'])
                end

                if IsControlJustReleased(0, Config.Keybinds.interact) then
                    openCompanyMenu(id)
                end
            end,
            onExit = function(zone)
                ClientUtils.HideText()
            end
        })
    end
end

local function resetActiveDelivery()
    if not activeDelivery then
        return
    end

    if activeDelivery.point then
        activeDelivery.point:remove()
        activeDelivery.point = nil
    end

    if activeDelivery.timer then
        activeDelivery.timer:forceEnd(false)
        activeDelivery.timer = nil
    end

    activeDelivery = nil
end

local function nextDeliveryPoint()
    if not activeDelivery then
        return
    end

    local index = activeDelivery.index
    local coords = activeDelivery.route[index]

    if not coords then
        return
    end

    if activeDelivery.point then
        activeDelivery.point:remove()
    end

    activeDelivery.point = lib.points.new({
        coords = coords,
        distance = 35.0,
        debug = Config.Debug,
        onEnter = function(self)
            ClientUtils.ShowText(Lang['delivery_interact'])
        end,
        onExit = function(self)
            ClientUtils.HideText()
        end,
        nearby = function(self)
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.2, 255, 50, 50, 160, false, false, 2, false, nil, nil, false)

            if self.currentDistance <= 2.5 and IsControlJustReleased(0, Config.Keybinds.interact) then
                TriggerEvent('t1ger_deliveries:client:completeStop', index)
            end
        end
    })
end

local function startDelivery(job)
    resetActiveDelivery()

    activeDelivery = {
        companyId = job.companyId,
        tier = job.tier,
        vehicle = job.vehicle,
        route = SharedUtils.DeepCopy(job.route or {}),
        index = 1,
        timer = ClientUtils.CreateTimer(Config.RouteTimeout * 1000, function()
            TriggerServerEvent('t1ger_deliveries:server:timeoutDelivery')
        end)
    }

    ClientUtils.Notify(Lang['job_started'], 'success')
    nextDeliveryPoint()
end

RegisterNetEvent('t1ger_deliveries:client:completeStop', function(index)
    if not activeDelivery or activeDelivery.index ~= index then
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        ClientUtils.Notify(Lang['job_vehicle_invalid'], 'error')
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        ClientUtils.Notify(Lang['job_vehicle_invalid'], 'error')
        return
    end

    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

    if not SharedUtils.IsVehicleAllowed(activeDelivery.companyId, modelName) then
        ClientUtils.Notify(Lang['job_vehicle_invalid'], 'error')
        return
    end

    local coords = activeDelivery.route[index]

    local success = lib.callback.await('t1ger_deliveries:server:advanceDelivery', false, {
        companyId = activeDelivery.companyId,
        tier = activeDelivery.tier,
        index = index,
        coords = coords,
        vehicle = modelName
    })

    if not success then
        ClientUtils.Notify(Lang['job_location_invalid'], 'error')
        return
    end

    activeDelivery.index = index + 1

    if activeDelivery.timer then
        activeDelivery.timer:restart(true)
    end

    if activeDelivery.index > #activeDelivery.route then
        resetActiveDelivery()
        ClientUtils.Notify(Lang['job_completed'], 'success')
    else
        nextDeliveryPoint()
    end
end)

RegisterNetEvent('t1ger_deliveries:client:purchaseCompany', function(companyId)
    local company = Config.Companies[companyId]
    if not company then return end

    if ownedCompanyId ~= 0 then
        ClientUtils.Notify(Lang['company_owned'], 'error')
        return
    end

    local input = ClientUtils.OpenInput({
        title = Lang['company_name_prompt'],
        fields = {
            { type = 'input', label = Lang['company_name_placeholder'], required = true, min = 3, max = 40 }
        }
    })

    if not input then
        return
    end

    local name = tostring(input[1])

    if name == '' then
        ClientUtils.Notify(Lang['invalid_string'], 'error')
        return
    end

    local purchased = lib.callback.await('t1ger_deliveries:server:purchaseCompany', false, companyId, name)

    if not purchased then
        ClientUtils.Notify(Lang['not_enough_money'], 'error')
        return
    end

    ClientUtils.Notify(string.format(Lang['company_purchased'], SharedUtils.FormatCurrency(company.price)), 'success')
end)

RegisterNetEvent('t1ger_deliveries:client:renameCompany', function(companyId)
    if ownedCompanyId ~= companyId then
        ClientUtils.Notify(Lang['company_locked'], 'error')
        return
    end

    local input = ClientUtils.OpenInput({
        title = Lang['company_name_prompt'],
        fields = {
            { type = 'input', label = Lang['company_name_placeholder'], required = true, min = 3, max = 40 }
        }
    })

    if not input then
        return
    end

    local name = tostring(input[1])

    if name == '' then
        ClientUtils.Notify(Lang['invalid_string'], 'error')
        return
    end

    TriggerServerEvent('t1ger_deliveries:server:renameCompany', companyId, name)
end)

RegisterNetEvent('t1ger_deliveries:client:sellCompany', function(companyId)
    local state = companyState[companyId]
    local company = Config.Companies[companyId]

    if ownedCompanyId ~= companyId or not state or not state.owned then
        ClientUtils.Notify(Lang['company_locked'], 'error')
        return
    end

    local sellPrice = math.floor(company.price * Config.SalePercentage)

    local alert = lib.alertDialog({
        header = company.name,
        content = string.format(Lang['company_sell_confirm'], SharedUtils.FormatCurrency(sellPrice)),
        centered = true,
        cancel = true
    })

    if alert ~= 'confirm' then
        return
    end

    TriggerServerEvent('t1ger_deliveries:server:sellCompany', companyId)
end)

RegisterNetEvent('t1ger_deliveries:client:buyCertificate', function(companyId)
    if ownedCompanyId ~= companyId then
        ClientUtils.Notify(Lang['company_locked'], 'error')
        return
    end

    local purchased = lib.callback.await('t1ger_deliveries:server:buyCertificate', false, companyId)

    if not purchased then
        ClientUtils.Notify(Lang['company_certificate_missing_funds'], 'error')
        return
    end

    ClientUtils.Notify(Lang['company_certificate_bought'], 'success')
end)

RegisterNetEvent('t1ger_deliveries:client:requestJobMenu', function(companyId)
    if activeDelivery then
        ClientUtils.Notify(Lang['job_in_progress'], 'error')
        return
    end

    local state = companyState[companyId]

    if not state or not state.owned then
        ClientUtils.Notify(Lang['company_locked'], 'error')
        return
    end

    local options = {}

    for tierId, tier in pairs(Config.JobValues) do
        local description = ('Level %s'):format(tier.level)
        if tier.certificate then
            description = description .. ' | Certificate'
        end

        options[#options + 1] = {
            title = tier.label,
            description = description,
            onSelect = function()
                TriggerEvent('t1ger_deliveries:client:selectVehicle', companyId, tierId)
            end
        }
    end

    ClientUtils.OpenContext(('t1ger:deliveries:tier:%s'):format(companyId), Lang['menu_choose_tier'], options)
end)

RegisterNetEvent('t1ger_deliveries:client:selectVehicle', function(companyId, tierId)
    local tier = Config.JobValues[tierId]
    local state = companyState[companyId]

    if not tier then
        return
    end

    if state and state.data then
        if tier.certificate and not state.data.certificate then
            ClientUtils.Notify(Lang['company_requires_certificate'], 'error')
            return
        end

        if (state.data.level or 0) < (tier.level or 0) then
            ClientUtils.Notify(string.format(Lang['company_requires_level'], tier.level), 'error')
            return
        end
    end

    local options = {}

    for _, vehicle in ipairs(tier.vehicles) do
        options[#options + 1] = {
            title = vehicle.name,
            description = string.format('$%s', SharedUtils.FormatCurrency(vehicle.deposit)),
            onSelect = function()
                local job = lib.callback.await('t1ger_deliveries:server:startDelivery', false, {
                    companyId = companyId,
                    tier = tierId,
                    vehicle = vehicle.model
                })

                if not job then
                    ClientUtils.Notify(Lang['job_no_routes'], 'error')
                    return
                end

                startDelivery(job)
            end
        }
    end

    ClientUtils.OpenContext(('t1ger:deliveries:vehicle:%s:%s'):format(companyId, tierId), Lang['menu_choose_vehicle'], options)
end)

RegisterNetEvent('t1ger_deliveries:client:cancelDelivery', function()
    if not activeDelivery then
        return
    end

    TriggerServerEvent('t1ger_deliveries:server:cancelDelivery')
    resetActiveDelivery()
    ClientUtils.Notify(Lang['job_cancelled'], 'inform')
end)

RegisterNetEvent('t1ger_deliveries:client:syncCompanies', function(state, ownedId, deliveryId)
    companyState = state or {}
    ownedCompanyId = ownedId or 0
    assignedCompanyId = deliveryId or 0

    createCompanyBlips()
    createCompanyZones()
end)

RegisterNetEvent('t1ger_deliveries:client:updateCompany', function(companyId, data)
    companyState[companyId] = companyState[companyId] or {}
    companyState[companyId].data = data
    companyState[companyId].owned = data ~= nil
    createCompanyBlips()
end)

RegisterNetEvent('t1ger_deliveries:client:deliveryTimeout', function()
    resetActiveDelivery()
    ClientUtils.Notify(Lang['job_timeout'], 'error')
end)

RegisterNetEvent('t1ger_deliveries:client:companyUpdated', function()
    ClientUtils.Notify(Lang['company_updated'], 'inform')
end)

RegisterNetEvent('t1ger_deliveries:client:depositUpdate', function(state, amount)
    if not amount or amount <= 0 then
        return
    end

    local formatted = SharedUtils.FormatCurrency(amount)

    if state == 'paid' then
        ClientUtils.Notify(string.format(Lang['job_deposit_paid'], formatted), 'inform')
    elseif state == 'returned' then
        ClientUtils.Notify(string.format(Lang['job_deposit_returned'], formatted), 'success')
    elseif state == 'withheld' then
        ClientUtils.Notify(Lang['job_deposit_withheld'], 'error')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    ClientUtils.HideText()
    removeCompanyBlips()
    destroyCompanyZones()
    resetActiveDelivery()
end)

CreateThread(function()
    Wait(1000)
    local state, ownedId, deliveryId = lib.callback.await('t1ger_deliveries:server:initialize', false)

    companyState = state or {}
    ownedCompanyId = ownedId or 0
    assignedCompanyId = deliveryId or 0

    createCompanyBlips()
    createCompanyZones()
end)
