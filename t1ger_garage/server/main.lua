-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
local VEHICLE_TABLE = 'owned_vehicles'

local function trim(value)
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

local function getPlayerIdentifier(player)
    return player.PlayerData.citizenid
end

local function fetchVehicleByPlate(plate)
    if not plate then return nil end
    return MySQL.single.await(('SELECT * FROM %s WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), { plate, trim(plate) })
end

local function decodeVehicle(row)
    if not row then return nil end
    local props = nil
    if row.vehicle then
        local ok, decoded = pcall(json.decode, row.vehicle)
        if ok then
            props = decoded
        end
    end
    return props
end

CreateThread(function()
    MySQL.update.await(('UPDATE %s SET state = 1 WHERE state = 0'):format(VEHICLE_TABLE))
end)

local function buildVehicleResponse(row)
    local props = decodeVehicle(row) or {}
    return {
        plate = row.plate,
        props = props,
        fuel = row.fuel or 0,
        seized = row.seized == 1 or row.seized == true,
        garage = row.garage,
        state = row.state
    }
end

lib.callback.register('t1ger_garage:getOwnedVehicles', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return {} end
    local identifier = getPlayerIdentifier(player)
    local typeFilter = data.type or 'car'
    local garage = data.garage

    local rows = MySQL.query.await(('SELECT plate, vehicle, fuel, seized, state, garage FROM %s WHERE owner = ? AND type = ?'):format(VEHICLE_TABLE), {
        identifier,
        typeFilter
    }) or {}

    local response = {}
    for _, row in ipairs(rows) do
        if (row.garage == garage or row.garage == nil) and row.state == 1 and row.seized ~= 1 then
            response[#response + 1] = buildVehicleResponse(row)
        end
    end
    return response
end)

local function validateGarageType(row, expectedType)
    if not Config.UseTypeCheck then return true end
    if not row.type then return true end
    return row.type == expectedType
end

lib.callback.register('t1ger_garage:storeVehicle', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, Lang['check_f8_console'] end
    local props = data.props or {}
    local plate = props.plate and trim(props.plate) or nil
    if not plate then
        return false, Lang['veh_plate_not_exist']:format('unknown')
    end

    local row = fetchVehicleByPlate(plate)
    if not row then
        return false, Lang['veh_plate_not_exist']:format(plate)
    end

    local identifier = getPlayerIdentifier(player)
    if row.owner ~= identifier and not Config.Garage.StoreAnotherVehicle then
        return false, Lang['you_dont_own_vehicle']
    end

    if not validateGarageType(row, data.type) then
        return false, Lang['you_dont_own_vehicle']
    end

    local updateCount = MySQL.update.await(('UPDATE %s SET vehicle = ?, fuel = ?, state = 1, garage = ?, seized = 0 WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), {
        json.encode(props),
        data.fuel or row.fuel or 0,
        data.garage,
        plate,
        trim(plate)
    })

    if updateCount and updateCount > 0 then
        return true, Lang['u_stored_vehicle']:format(plate)
    end
    return false, Lang['check_f8_console']
end)

lib.callback.register('t1ger_garage:takeVehicle', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, nil, Lang['check_f8_console'] end
    local plate = data.plate and trim(data.plate)
    if not plate then return false, nil, Lang['veh_plate_not_exist']:format('unknown') end

    local row = fetchVehicleByPlate(plate)
    if not row then
        return false, nil, Lang['veh_plate_not_exist']:format(plate)
    end

    if row.owner ~= getPlayerIdentifier(player) then
        return false, nil, Lang['you_dont_own_vehicle']
    end

    if row.seized == 1 then
        return false, nil, Lang['veh_seized_contact_pol']
    end

    if row.state == 0 then
        return false, nil, Lang['vehicle_deleted']:format(plate)
    end

    if data.garage and row.garage ~= data.garage then
        return false, nil, Lang['veh_plate_not_exist']:format(plate)
    end

    local props = decodeVehicle(row)
    if not props then
        return false, nil, Lang['vehicle_deleted']:format(plate)
    end

    local updated = MySQL.update.await(('UPDATE %s SET state = 0 WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), {
        plate,
        trim(plate)
    })

    if not updated or updated == 0 then
        return false, nil, Lang['check_f8_console']
    end

    return true, {
        props = props,
        fuel = row.fuel or 0
    }
end)

lib.callback.register('t1ger_garage:transferVehicle', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, Lang['check_f8_console'] end
    local plate = data.plate and trim(data.plate)
    if not plate then return false, Lang['veh_plate_not_exist']:format('unknown') end
    local row = fetchVehicleByPlate(plate)
    if not row then
        return false, Lang['veh_plate_not_exist']:format(plate)
    end
    if row.owner ~= getPlayerIdentifier(player) then
        return false, Lang['you_dont_own_vehicle']
    end
    if row.seized == 1 then
        return false, Lang['veh_seized_contact_pol']
    end
    if row.state == 0 then
        return false, Lang['vehicle_deleted']:format(plate)
    end

    local updateCount = MySQL.update.await(('UPDATE %s SET garage = ? WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), {
        data.targetGarage,
        plate,
        trim(plate)
    })
    if updateCount and updateCount > 0 then
        return true, Lang['u_transferred_vehicle']
    end
    return false, Lang['check_f8_console']
end)

RegisterNetEvent('t1ger_garage:setVehicleImpounded', function(plate, props, fuel, garage, seized)
    if not plate or not props then return end
    local update = MySQL.update.await(('UPDATE %s SET vehicle = ?, garage = ?, fuel = ?, state = 1, seized = ? WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), {
        json.encode(props),
        garage or 'impound',
        fuel or 0,
        seized and 1 or 0,
        plate,
        trim(plate)
    })
    if not update or update == 0 then
        print(('[t1ger_garage] failed to update impound for %s'):format(plate))
    end
end)

lib.callback.register('t1ger_garage:getImpoundedVehicles', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return {} end
    local identifier = getPlayerIdentifier(player)
    local typeFilter = data.type or 'car'
    local rows = MySQL.query.await(('SELECT plate, vehicle, fuel, seized, state, garage FROM %s WHERE owner = ? AND garage = ? AND type = ?'):format(VEHICLE_TABLE), {
        identifier,
        'impound',
        typeFilter
    }) or {}

    local response = {}
    for _, row in ipairs(rows) do
        response[#response + 1] = buildVehicleResponse(row)
    end
    return response
end)

local function chargeImpoundFee(player)
    local fee = Config.Impound.Fees or 0
    if fee <= 0 then return true end
    if Config.Impound.Bank then
        if player.PlayerData.money.bank >= fee then
            player.Functions.RemoveMoney('bank', fee, 't1ger-impound')
            return true
        end
    else
        if player.PlayerData.money.cash >= fee then
            player.Functions.RemoveMoney('cash', fee, 't1ger-impound')
            return true
        end
    end
    return false
end

lib.callback.register('t1ger_garage:releaseImpoundedVehicle', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, nil, Lang['check_f8_console'] end
    local plate = data.plate and trim(data.plate)
    if not plate then return false, nil, Lang['veh_plate_not_exist']:format('unknown') end

    local row = fetchVehicleByPlate(plate)
    if not row then
        return false, nil, Lang['veh_plate_not_exist']:format(plate)
    end
    if row.owner ~= getPlayerIdentifier(player) then
        return false, nil, Lang['you_dont_own_vehicle']
    end
    if row.garage ~= 'impound' then
        return false, nil, Lang['veh_plate_not_exist']:format(plate)
    end
    if row.seized == 1 then
        return false, nil, Lang['veh_seized_contact_pol']
    end

    if not chargeImpoundFee(player) then
        return false, nil, Lang['not_enough_money']
    end

    local props = decodeVehicle(row)
    if not props then
        return false, nil, Lang['vehicle_deleted']:format(plate)
    end

    local update = MySQL.update.await(('UPDATE %s SET state = 0, garage = ? WHERE plate = ? OR plate = ?'):format(VEHICLE_TABLE), {
        data.targetGarage or 'garage',
        plate,
        trim(plate)
    })

    if not update or update == 0 then
        return false, nil, Lang['check_f8_console']
    end

    return true, {
        props = props,
        fuel = row.fuel or 0
    }
end)

