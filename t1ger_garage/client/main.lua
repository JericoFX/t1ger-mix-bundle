-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local normalGaragePoints, jobGaragePoints, extraPoints, impoundPoints = {}, {}, {}, {}
local activePromptId, activePromptText

local function formatPromptText(text)
    if not text then return '' end
    local cleaned = text:gsub('~.-~', '')
    cleaned = cleaned:gsub('%^%d', '')
    return cleaned
end

local function hidePrompt(id)
    if activePromptId == id then
        lib.hideTextUI()
        activePromptId = nil
        activePromptText = nil
    end
end

local function showPrompt(id, text)
    if activePromptId ~= id or activePromptText ~= text then
        lib.showTextUI(text)
        activePromptId = id
        activePromptText = text
    end
end

local function getVehicleFuel(vehicle)
    if Config.HasFuelScript and GetResourceState('LegacyFuel') == 'started' then
        return exports['LegacyFuel']:GetFuel(vehicle)
    end
    return GetVehicleFuelLevel(vehicle)
end

local function setVehicleFuel(vehicle, value)
    if Config.HasFuelScript and GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, value)
        return
    end
    SetVehicleFuelLevel(vehicle, value)
end

local function getVehicleFromSeat(vehicle)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    return nil
end

local function getNearbyVehicle(origin, radius)
    radius = radius or 3.0
    local vehicle = GetClosestVehicle(origin.x, origin.y, origin.z, radius, 0, 70)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    return nil
end

local function getVehicleProperties(vehicle)
    if lib and lib.getVehicleProperties then
        return lib.getVehicleProperties(vehicle)
    end
    return QBCore.Functions.GetVehicleProperties(vehicle)
end

local function setVehicleProperties(vehicle, props)
    if lib and lib.setVehicleProperties then
        lib.setVehicleProperties(vehicle, props)
        return
    end
    QBCore.Functions.SetVehicleProperties(vehicle, props)
end

local function ensureSpawnAreaClear(coords, radius)
    radius = radius or 3.0
    local handle, vehicle = FindFirstVehicle()
    local success
    local blocked = false
    repeat
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            if #(vehCoords - coords) <= radius then
                blocked = true
                break
            end
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return not blocked
end

local function isVehicleClassAllowed(vehicle, classes)
    if not classes or #classes == 0 then return true end
    local vehicleClass = GetVehicleClass(vehicle)
    for _, class in ipairs(classes) do
        if vehicleClass == class then
            return true
        end
    end
    return false
end

local function tryGiveKeys(plate, vehicle, context)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
    if GetResourceState('t1ger_keys') == 'started' then
        exports['t1ger_keys']:SetVehicleLocked(vehicle, 0)
        if context and context.job and context.job.keys then
            exports['t1ger_keys']:GiveJobKeys(plate, context.job.label, context.job.shared, context.job.jobs)
        end
    end
end

local function spawnVehicleFromGarage(garage, data)
    local spawn = garage.spawn
    local coords = vec3(spawn.x, spawn.y, spawn.z)
    if not ensureSpawnAreaClear(coords, 3.5) then
        TriggerEvent('t1ger_garage:notify', Lang['spawn_area_blocked'], 'error')
        return
    end

    local props = data.props
    local model = props.model
    T1GER_LoadModel(model)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, spawn.w, true, false)
    while not DoesEntityExist(vehicle) do
        Wait(10)
    end
    setVehicleProperties(vehicle, props)
    SetVehicleDirtLevel(vehicle, 1.0)
    setVehicleFuel(vehicle, data.fuel or 50.0)
    SetVehicleOnGroundProperly(vehicle)
    if data.teleport then
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    end
    tryGiveKeys(props.plate, vehicle, data.keyContext)
    TriggerEvent('t1ger_garage:notify', Lang['u_took_out_vehicle']:format(props.plate))
end

local function openTransferMenu(garage, entry)
    local options = {}
    for _, target in ipairs(Config.Garage.Locations) do
        if target.type == garage.type and target.name ~= garage.name then
            options[#options + 1] = {
                title = ('%s %s'):format(target.blip and target.blip.name or 'Garage', target.name),
                onSelect = function()
                    local success, message = lib.callback.await('t1ger_garage:transferVehicle', false, {
                        plate = entry.plate,
                        sourceGarage = garage.name,
                        targetGarage = target.name
                    })
                    if success then
                        TriggerEvent('t1ger_garage:notify', Lang['u_transferred_vehicle'])
                    else
                        TriggerEvent('t1ger_garage:notify', message or Lang['check_f8_console'], 'error')
                    end
                end
            }
        end
    end
    if #options == 0 then
        TriggerEvent('t1ger_garage:notify', Lang['no_garage_to_transfer'], 'error')
        return
    end
    lib.registerContext({
        id = ('t1ger_garage_transfer_%s'):format(entry.plate),
        title = Lang['transfer_veh'],
        options = options
    })
    lib.showContext(('t1ger_garage_transfer_%s'):format(entry.plate))
end

local function spawnSelectedVehicle(garage, entry)
    local success, response, message = lib.callback.await('t1ger_garage:takeVehicle', false, {
        plate = entry.plate,
        garage = garage.name,
        type = garage.type
    })
    if not success then
        TriggerEvent('t1ger_garage:notify', message or Lang['check_f8_console'], 'error')
        return
    end
    response.teleport = Config.Garage.Teleport
    spawnVehicleFromGarage(garage, response)
end

local function openVehicleOptions(garage, entry)
    local metadata = {
        { label = 'Fuel', value = ('%s%%'):format(round(entry.fuel or 0, 1)) }
    }
    if entry.props and entry.props.engineHealth then
        metadata[#metadata + 1] = { label = 'Engine', value = round((entry.props.engineHealth or 0) / 10, 1) }
    end

    local options = {
        {
            title = Lang['spawn_vehicle'],
            icon = 'car',
            onSelect = function()
                spawnSelectedVehicle(garage, entry)
            end
        }
    }

    if Config.Garage.Transfer then
        options[#options + 1] = {
            title = Lang['transfer_veh'],
            icon = 'right-left',
            onSelect = function()
                openTransferMenu(garage, entry)
            end
        }
    end

    local modelLabel = 'Vehicle'
    if entry.props and entry.props.model then
        local displayName = GetDisplayNameFromVehicleModel(entry.props.model)
        if displayName then
            local labelText = GetLabelText(displayName)
            if labelText and labelText ~= 'NULL' then
                modelLabel = labelText
            else
                modelLabel = displayName
            end
        end
    end

    lib.registerContext({
        id = ('t1ger_garage_vehicle_%s'):format(entry.plate),
        title = ('%s [%s]'):format(modelLabel, entry.plate),
        options = options,
        metadata = metadata
    })
    lib.showContext(('t1ger_garage_vehicle_%s'):format(entry.plate))
end

local function openGarageMenu(garage)
    local vehicles = lib.callback.await('t1ger_garage:getOwnedVehicles', false, {
        garage = garage.name,
        type = garage.type
    })
    if not vehicles or #vehicles == 0 then
        TriggerEvent('t1ger_garage:notify', Lang['no_owned_veh_in_garage'], 'error')
        return
    end

    local options = {}
    for _, vehicle in ipairs(vehicles) do
        local display = 'Vehicle'
        if vehicle.props and vehicle.props.model then
            local displayName = GetDisplayNameFromVehicleModel(vehicle.props.model)
            if displayName then
                local labelText = GetLabelText(displayName)
                if labelText and labelText ~= 'NULL' then
                    display = labelText
                else
                    display = displayName
                end
            end
        end
        local label = ('%s [%s]'):format(display, vehicle.plate)
        options[#options + 1] = {
            title = label,
            metadata = {
                { label = 'Fuel', value = ('%s%%'):format(round(vehicle.fuel or 0, 1)) }
            },
            onSelect = function()
                openVehicleOptions(garage, vehicle)
            end
        }
    end

    local contextId = ('t1ger_garage_%s_%s'):format(garage.type, garage.name)
    lib.registerContext({
        id = contextId,
        title = Lang['select_vehicle'],
        options = options
    })
    lib.showContext(contextId)
end

local function storeVehicleInGarage(garage, vehicle)
    if not DoesEntityExist(vehicle) then return end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver ~= cache.ped and not Config.Garage.StoreAnotherVehicle then
        TriggerEvent('t1ger_garage:notify', Lang['you_dont_own_vehicle'], 'error')
        return
    end

    local props = getVehicleProperties(vehicle)
    props.plate = props.plate or GetVehicleNumberPlateText(vehicle)
    local fuel = getVehicleFuel(vehicle)

    local success, message = lib.callback.await('t1ger_garage:storeVehicle', false, {
        garage = garage.name,
        type = garage.type,
        props = props,
        fuel = fuel
    })

    if success then
        T1GER_DeleteVehicle(vehicle)
        TriggerEvent('t1ger_garage:notify', Lang['u_stored_vehicle']:format(props.plate))
    else
        TriggerEvent('t1ger_garage:notify', message or Lang['check_f8_console'], 'error')
    end
end

local function handleGarageInteraction(garage)
    local playerVehicle = getVehicleFromSeat(cache.vehicle)
    if playerVehicle then
        storeVehicleInGarage(garage, playerVehicle)
        return
    end

    local spawn = garage.spawn
    local nearbyVehicle = spawn and getNearbyVehicle(vec3(spawn.x, spawn.y, spawn.z), 3.0) or nil
    if nearbyVehicle and DoesEntityExist(nearbyVehicle) then
        storeVehicleInGarage(garage, nearbyVehicle)
        return
    end

    openGarageMenu(garage)
end

local function registerNormalGarage(index, garage)
    local entry = normalGaragePoints[index] or {}
    if garage.blip then
        entry.blip = T1GER_CreateBlip(garage.pos, garage.blip, Config.Garage.UseNames and garage.name or nil)
    end

    local id = ('normal_garage_%s_%s'):format(garage.type, index)
    local marker = garage.marker

    entry.point = lib.points.new({
        coords = garage.pos,
        distance = marker and marker.drawDist or 10.0,
        onExit = function()
            hidePrompt(id)
        end,
        nearby = function(self)
            if marker and marker.enable then
                DrawMarker(marker.type, garage.pos.x, garage.pos.y, garage.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2, false, nil, nil, false)
            end

            if cache.vehicle == 0 and self.currentDistance <= garage.dist then
                showPrompt(id, formatPromptText(garage.text))
                if IsControlJustPressed(0, 38) then
                    handleGarageInteraction(garage)
                end
            else
                hidePrompt(id)
            end
        end
    })

    local storePromptId = id .. '_store'
    entry.storeZone = lib.zones.sphere({
        coords = garage.pos,
        radius = garage.dist or 2.5,
        debug = Config.Debug or false,
        inside = function()
            if cache.vehicle ~= 0 then
                showPrompt(storePromptId, formatPromptText(garage.text2))
                if IsControlJustPressed(0, 38) then
                    handleGarageInteraction(garage)
                end
            else
                hidePrompt(storePromptId)
            end
        end,
        onExit = function()
            hidePrompt(storePromptId)
        end
    })

    normalGaragePoints[index] = entry
end

local function setupNormalGarages()
    for index, garage in ipairs(Config.Garage.Locations) do
        registerNormalGarage(index, garage)
    end
end

local function openExtraOptions(vehicle)
    local options = {}
    for extraId = 0, 12 do
        if DoesExtraExist(vehicle, extraId) then
            local enabled = IsVehicleExtraTurnedOn(vehicle, extraId)
            local title = ('Extra %s'):format(extraId)
            options[#options + 1] = {
                title = title,
                description = enabled and 'Disable' or 'Enable',
                onSelect = function()
                    SetVehicleExtra(vehicle, extraId, enabled and 1 or 0)
                end
            }
        end
    end

    if #options == 0 then
        TriggerEvent('t1ger_garage:notify', Lang['veh_no_extras'], 'error')
        return
    end

    lib.registerContext({
        id = 't1ger_garage_extra_options',
        title = Lang['select_extra'] or 'Extras',
        options = options
    })
    lib.showContext('t1ger_garage_extra_options')
end

local function openLiveryOptions(vehicle)
    local total = GetVehicleLiveryCount(vehicle)
    if not total or total <= 0 then
        TriggerEvent('t1ger_garage:notify', Lang['veh_no_liveries'], 'error')
        return
    end

    local options = {}
    for index = 0, total - 1 do
        options[#options + 1] = {
            title = ('Livery %s'):format(index),
            onSelect = function()
                SetVehicleLivery(vehicle, index)
            end
        }
    end

    lib.registerContext({
        id = 't1ger_garage_livery_options',
        title = Lang['select_livery'],
        options = options
    })
    lib.showContext('t1ger_garage_livery_options')
end

local function openExtrasMenu(cfg)
    local vehicle = getVehicleFromSeat(cache.vehicle)
    if not vehicle then
        TriggerEvent('t1ger_garage:notify', Lang['inside_veh_error'], 'error')
        return
    end
    if not isVehicleClassAllowed(vehicle, cfg.classes or {}) then
        TriggerEvent('t1ger_garage:notify', Lang['veh_no_extras'], 'error')
        return
    end

    lib.registerContext({
        id = 't1ger_garage_extras_menu',
        title = Lang['veh_extra_menu'],
        options = {
            {
                title = Lang['select_extra'],
                icon = 'screwdriver-wrench',
                onSelect = function()
                    openExtraOptions(vehicle)
                end
            },
            {
                title = Lang['select_livery'],
                icon = 'palette',
                onSelect = function()
                    openLiveryOptions(vehicle)
                end
            }
        }
    })
    lib.showContext('t1ger_garage_extras_menu')
end

local function registerExtraLocation(index, cfg)
    local entry = extraPoints[index] or {}
    if cfg.blip then
        entry.blip = T1GER_CreateBlip(cfg.pos, cfg.blip)
    end

    local id = ('extra_location_%s'):format(index)
    local marker = cfg.marker

    entry.point = lib.points.new({
        coords = cfg.pos,
        distance = marker and marker.drawDist or 10.0,
        nearby = function()
            if marker and marker.enable then
                DrawMarker(marker.type, cfg.pos.x, cfg.pos.y, cfg.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2, false, nil, nil, false)
            end
        end
    })

    entry.zone = lib.zones.sphere({
        coords = cfg.pos,
        radius = (cfg.dist or 2.5),
        debug = Config.Debug or false,
        inside = function()
            if cache.vehicle ~= 0 then
                showPrompt(id, formatPromptText(cfg.text))
                if IsControlJustPressed(0, Config.Extras.Keybind or 38) then
                    openExtrasMenu(cfg)
                end
            else
                hidePrompt(id)
            end
        end,
        onExit = function()
            hidePrompt(id)
        end
    })

    extraPoints[index] = entry
end

local function setupExtras()
    for index, cfg in ipairs(Config.Extras.Locations or {}) do
        registerExtraLocation(index, cfg)
    end
end

local function listGarages()
    local options = {}
    for _, garage in ipairs(Config.Garage.Locations) do
        local label = Config.Garage.UseNames and ('Garage %s'):format(garage.name) or garage.blip and garage.blip.name or 'Garage'
        options[#options + 1] = {
            title = label,
            description = ('Type: %s'):format(garage.type)
        }
    end
    lib.registerContext({
        id = 't1ger_garage_list',
        title = 'Garages',
        options = options
    })
    lib.showContext('t1ger_garage_list')
end

RegisterCommand(Config.Garage.Command, function()
    listGarages()
end)

setupNormalGarages()
setupExtras()

local function spawnImpoundVehicle(cfg, data)
    local spawn = cfg.spawn
    local garageData = {
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }
    }
    data.teleport = cfg.teleport
    spawnVehicleFromGarage(garageData, data)
end

local function releaseImpoundedVehicle(cfg, entry)
    if entry.seized then
        return TriggerEvent('t1ger_garage:notify', Lang['veh_seized_contact_pol'], 'error')
    end
    local success, response, message = lib.callback.await('t1ger_garage:releaseImpoundedVehicle', false, {
        plate = entry.plate
    })
    if not success then
        TriggerEvent('t1ger_garage:notify', message or Lang['check_f8_console'], 'error')
        return
    end
    spawnImpoundVehicle(cfg, response)
    TriggerEvent('t1ger_garage:notify', Lang['u_paid_impound_fees']:format(Config.Impound.Fees, entry.plate))
end

local function openImpoundMenu(cfg)
    local vehicles = lib.callback.await('t1ger_garage:getImpoundedVehicles', false, {
        type = cfg.type
    })
    if not vehicles or #vehicles == 0 then
        TriggerEvent('t1ger_garage:notify', Lang['no_impounded_vehicles'], 'error')
        return
    end

    local options = {}
    for _, vehicle in ipairs(vehicles) do
        local display = 'Vehicle'
        if vehicle.props and vehicle.props.model then
            local displayName = GetDisplayNameFromVehicleModel(vehicle.props.model)
            if displayName then
                local labelText = GetLabelText(displayName)
                if labelText and labelText ~= 'NULL' then
                    display = labelText
                else
                    display = displayName
                end
            end
        end
        local label = ('%s [%s]'):format(display, vehicle.plate)
        if vehicle.seized then
            label = label .. ' [SEIZED]'
        end

        options[#options + 1] = {
            title = label,
            metadata = {
                { label = 'Fuel', value = ('%s%%'):format(round(vehicle.fuel or 0, 1)) }
            },
            onSelect = function()
                releaseImpoundedVehicle(cfg, vehicle)
            end
        }
    end

    local contextId = ('t1ger_impound_%s'):format(cfg.type)
    lib.registerContext({
        id = contextId,
        title = Lang['pay_impound_fees']:format(Config.Impound.Fees),
        options = options
    })
    lib.showContext(contextId)
end

local function registerImpoundLocation(index, cfg)
    local entry = impoundPoints[index] or {}
    if cfg.blip then
        entry.blip = T1GER_CreateBlip(cfg.pos, cfg.blip)
    end

    local id = ('impound_%s'):format(index)
    local marker = cfg.marker

    entry.point = lib.points.new({
        coords = cfg.pos,
        distance = marker and marker.drawDist or 10.0,
        nearby = function()
            if marker and marker.enable then
                DrawMarker(marker.type, cfg.pos.x, cfg.pos.y, cfg.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2, false, nil, nil, false)
            end
        end
    })

    entry.zone = lib.zones.sphere({
        coords = cfg.pos,
        radius = cfg.dist or 2.5,
        debug = Config.Debug or false,
        inside = function()
            showPrompt(id, formatPromptText(cfg.text))
            if IsControlJustPressed(0, cfg.keybind or 38) then
                openImpoundMenu(cfg)
            end
        end,
        onExit = function()
            hidePrompt(id)
        end
    })

    impoundPoints[index] = entry
end

local function setupImpounds()
    for index, cfg in ipairs(Config.Impound.Locations or {}) do
        registerImpoundLocation(index, cfg)
    end
end

setupImpounds()

local function SetVehicleImpounded(vehicle, seized)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local props = getVehicleProperties(vehicle) or {}
    props.plate = props.plate or GetVehicleNumberPlateText(vehicle)
    local fuel = getVehicleFuel(vehicle)
    TriggerServerEvent('t1ger_garage:setVehicleImpounded', props.plate, props, fuel, 'impound', seized)
    T1GER_DeleteVehicle(vehicle)
end

exports('SetVehicleImpounded', SetVehicleImpounded)
