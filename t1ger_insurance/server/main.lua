-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local brokers = 0
local cooldowns = {
        buy = {},
        cancel = {},
        claim = {}
}
local vehicleCache = {
        owners = {},
        plates = {}
}

local function NormalizePlate(plate)
        if type(plate) ~= 'string' then return nil end
        local trimmed = plate:gsub('^%s*(.-)%s*$', '%1')
        if trimmed == '' then return nil end
        return string.upper(trimmed)
end

local function CopyTable(value)
        if type(value) ~= 'table' then return value end
        local result = {}
        for key, data in pairs(value) do
                result[key] = CopyTable(data)
        end
        return result
end

local function CloneVehicleData(vehicle)
        if not vehicle then return nil end
        local costs = vehicle.costs or {}
        return {
                plate = vehicle.plate,
                owner = vehicle.owner,
                model = vehicle.model,
                insured = vehicle.insured,
                price = vehicle.price,
                costs = {
                        upfront = costs.upfront or 0,
                        subscription = costs.subscription or 0
                },
                props = CopyTable(vehicle.props or {})
        }
end

local function GetCacheDuration(key)
        local cacheConfig = Config.Insurance.cache or {}
        local minutes = cacheConfig[key] or cacheConfig.default
        if not minutes or minutes <= 0 then return nil end
        return math.floor(minutes * 60)
end

local function GetOwnerCache(owner)
        if not owner then return nil end
        local entry = vehicleCache.owners[owner]
        if not entry then return nil end
        if entry.expires and entry.expires <= os.time() then
                vehicleCache.owners[owner] = nil
                return nil
        end
        return entry.data
end

local function SetOwnerCache(owner, vehicles)
        if not owner then return end
        vehicles = vehicles or {}
        local duration = GetCacheDuration('owners')
        if not duration then
                vehicleCache.owners[owner] = nil
                return
        end
        local cached = {}
        for index, vehicle in ipairs(vehicles) do
                cached[index] = CloneVehicleData(vehicle)
        end
        vehicleCache.owners[owner] = {
                data = cached,
                expires = os.time() + duration
        }
        for _, vehicle in ipairs(vehicles) do
                SetPlateCache(vehicle)
        end
end

local function GetPlateCache(plate)
        if not plate then return nil end
        local entry = vehicleCache.plates[plate]
        if not entry then return nil end
        if entry.expires and entry.expires <= os.time() then
                vehicleCache.plates[plate] = nil
                return nil
        end
        return entry.data
end

local function SetPlateCache(vehicle)
        if not vehicle or not vehicle.plate then return end
        local duration = GetCacheDuration('plates')
        if not duration then
                vehicleCache.plates[vehicle.plate] = nil
                return
        end
        vehicleCache.plates[vehicle.plate] = {
                data = CloneVehicleData(vehicle),
                expires = os.time() + duration
        }
end

local function UpdateVehicleCache(vehicle)
        if not vehicle or not vehicle.plate then return end
        SetPlateCache(vehicle)
        local ownerEntry = vehicleCache.owners[vehicle.owner]
        if not ownerEntry then return end
        local duration = GetCacheDuration('owners')
        if not duration then
                vehicleCache.owners[vehicle.owner] = nil
                return
        end
        if ownerEntry.expires and ownerEntry.expires <= os.time() then
                vehicleCache.owners[vehicle.owner] = nil
                return
        end
        local updated = false
        local clone = CloneVehicleData(vehicle)
        for index, cachedVehicle in ipairs(ownerEntry.data) do
                if cachedVehicle.plate == vehicle.plate then
                        ownerEntry.data[index] = clone
                        updated = true
                        break
                end
        end
        if not updated then
                ownerEntry.data[#ownerEntry.data + 1] = clone
        end
        ownerEntry.expires = os.time() + duration
end

local function FormatCurrency(amount)
        local formatted = tonumber(amount) or 0
        local left, num, right = tostring(formatted):match('^([^%d]*%d)(%d*)(.-)$')
        if not left then return tostring(formatted) end
        return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function Notify(source, message, notifType)
        TriggerClientEvent('t1ger_insurance:client:notify', source, message, notifType)
end

local function DepositToManagement(amount)
        if not amount or amount <= 0 then return end
        local account = Config.Insurance.job.managementAccount
        if not account then return end
        if GetResourceState('qb-management') == 'started' then
                pcall(function()
                        exports['qb-management']:AddMoney(account, amount)
                end)
        end
end

local function CalculateCosts(price)
        local cfg = Config.Insurance.price
        local upfront = cfg.upfront
        local subscription = cfg.payment
        if price and price > 0 then
                upfront = math.floor((cfg.establish / 100) * price)
                subscription = math.floor((cfg.subscription / 100) * price)
        end
        return {
                upfront = upfront,
                subscription = subscription
        }
end

local function SetCooldown(identifier, action)
        local duration = Config.Insurance.cooldowns[action]
        if not duration or duration <= 0 then return end
        cooldowns[action][identifier] = os.time() + (duration * 60)
end

local function HasCooldown(identifier, action)
        local expires = cooldowns[action][identifier]
        if not expires then return false end
        if expires <= os.time() then
                cooldowns[action][identifier] = nil
                return false
        end
        return true, math.ceil((expires - os.time()) / 60)
end

local function IsBroker(player)
        local job = player.PlayerData.job
        return job and job.name == Config.Insurance.job.name or false
end

local function IsBrokerBoss(player)
        if not IsBroker(player) then return false end
        local job = player.PlayerData.job
        if job.isboss then return true end
        if job.grade and job.grade.isboss then
                return true
        end
        if GetResourceState('qb-management') == 'started' then
                local ok, result = pcall(function()
                        return exports['qb-management']:IsPlayerBoss(player.PlayerData.source, job.name)
                end)
                if ok and result then
                        return true
                end
        end
        return false
end

local function HasLookupPermission(player)
        local job = player.PlayerData.job
        if not job then return false end
        if job.name == 'police' then return true end
        return job.name == Config.Insurance.job.name
end

local function BuildVehicleQuery(whereColumn)
        local db = Config.Database
        local select = {
                ('%s.%s AS plate'):format(db.table, db.plateColumn),
                ('%s.%s AS vehicle'):format(db.table, db.vehicleColumn),
                ('%s.%s AS insurance'):format(db.table, db.insuranceColumn),
                ('%s.%s AS owner'):format(db.table, db.ownerColumn)
        }
        if db.modelColumn then
                select[#select + 1] = ('%s.%s AS model'):format(db.table, db.modelColumn)
        end
        if db.priceLookup and db.modelColumn then
                select[#select + 1] = ('prices.%s AS price'):format(db.priceLookup.priceColumn)
        end
        local query = ('SELECT %s FROM %s'):format(table.concat(select, ', '), db.table)
        if db.priceLookup and db.modelColumn then
                query = query .. (' LEFT JOIN %s prices ON %s.%s = prices.%s')
                        :format(db.priceLookup.table, db.table, db.modelColumn, db.priceLookup.joinColumn)
        end
        query = query .. (' WHERE %s.%s = ?'):format(db.table, whereColumn)
        return query
end

local function ParseVehicleRow(row)
        if not row then return nil end
        local props = row.vehicle
        if type(props) == 'string' then
                local ok, decoded = pcall(json.decode, props)
                if ok and decoded then
                        props = decoded
                else
                        props = {}
                end
        end
        local model = row.model
        if not model and props and props.model then
                        model = props.model
        end
        local insured = row.insurance == true or row.insurance == 1 or row.insurance == '1'
        local price = row.price and tonumber(row.price) or nil
        local costs = CalculateCosts(price)
        return {
                plate = row.plate,
                owner = row.owner,
                model = model,
                insured = insured,
                price = price,
                costs = costs,
                props = props
        }
end

local function FetchVehiclesByOwner(owner)
        local cached = GetOwnerCache(owner)
        if cached then
                local vehicles = {}
                for index, vehicle in ipairs(cached) do
                        vehicles[index] = CloneVehicleData(vehicle)
                end
                return vehicles
        end

        local query = BuildVehicleQuery(Config.Database.ownerColumn)
        local results = MySQL.query.await(query, { owner }) or {}
        local vehicles = {}
        for _, row in ipairs(results) do
                local data = ParseVehicleRow(row)
                if data then
                        vehicles[#vehicles + 1] = data
                end
        end
        SetOwnerCache(owner, vehicles)
        return vehicles
end

local function FetchVehicleByPlate(plate)
        local cached = GetPlateCache(plate)
        if cached then
                return CloneVehicleData(cached)
        end

        local query = BuildVehicleQuery(Config.Database.plateColumn)
        local result = MySQL.single.await(query, { plate })
        if not result then return nil end
        local vehicle = ParseVehicleRow(result)
        if vehicle then
                UpdateVehicleCache(vehicle)
        end
        return vehicle
end

local function UpdateInsuranceState(vehicle, state)
        if not vehicle or not vehicle.plate then return end
        local db = Config.Database
        MySQL.update.await(('UPDATE %s SET %s = ? WHERE %s = ?'):format(db.table, db.insuranceColumn, db.plateColumn), {
                state and 1 or 0,
                vehicle.plate
        })
        vehicle.insured = state
        UpdateVehicleCache(vehicle)
end

local function UpdateBrokerCount()
        local players = QBCore.Functions.GetQBPlayers()
        local count = 0
        for _, player in pairs(players) do
                if IsBroker(player) then
                        if not Config.Insurance.job.requireDuty or player.PlayerData.job.onduty then
                                count = count + 1
                        end
                end
        end
        brokers = count
        TriggerClientEvent('t1ger_insurance:client:updateBrokerCount', -1, brokers)
end

UpdateBrokerCount()
lib.setInterval(math.max(Config.Insurance.job.sync_time, 1) * 60000, UpdateBrokerCount)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
        TriggerClientEvent('t1ger_insurance:client:updateBrokerCount', player.PlayerData.source, brokers)
end)

lib.callback.register('t1ger_insurance:server:getVehicles', function(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return {} end
        return FetchVehiclesByOwner(player.PlayerData.citizenid)
end)

lib.callback.register('t1ger_insurance:server:getVehicleByPlate', function(source, plate)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return nil end
        local normalized = NormalizePlate(plate)
        if not normalized then return nil end
        local vehicle = FetchVehicleByPlate(normalized)
        if not vehicle then return nil end
        local identifier = player.PlayerData.citizenid
        if vehicle.owner ~= identifier and not HasLookupPermission(player) then
                return nil
        end
        if vehicle.owner == identifier then
                local hasCooldown, minutes = HasCooldown(identifier, 'claim')
                if hasCooldown then
                        Notify(source, Lang['notify_cooldown']:format(minutes), 'error')
                        return nil
                end
                SetCooldown(identifier, 'claim')
        end
        return { insured = vehicle.insured }
end)

lib.callback.register('t1ger_insurance:server:getAccountBalance', function(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player or not IsBrokerBoss(player) then return nil end
        if GetResourceState('qb-management') ~= 'started' then return nil end
        local amount
        local ok, result = pcall(function()
                return exports['qb-management']:GetAccountBalance(Config.Insurance.job.managementAccount)
        end)
        if ok then
                amount = result
        end
        if not amount then
                amount = MySQL.scalar.await('SELECT amount FROM management_funds WHERE job_name = ?', { Config.Insurance.job.managementAccount })
        end
        return amount
end)

RegisterNetEvent('t1ger_insurance:server:buyInsurance', function(plate)
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local normalized = NormalizePlate(plate)
        if not normalized then
                Notify(src, Lang['notify_plate_missing'], 'error')
                return
        end
        plate = normalized
        local identifier = player.PlayerData.citizenid
        local hasCooldown, minutes = HasCooldown(identifier, 'buy')
        if hasCooldown then
                Notify(src, Lang['notify_cooldown']:format(minutes), 'error')
                return
        end
        if Config.BuyWithOnlineBrokers and brokers > 0 and not IsBroker(player) then
                Notify(src, Lang['notify_broker_online'], 'error')
                return
        end
        local vehicle = FetchVehicleByPlate(plate)
        if not vehicle or vehicle.owner ~= identifier then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        if vehicle.insured then
                Notify(src, Lang['notify_has_insurance'], 'error')
                return
        end
        local costs = vehicle.costs
        if player.PlayerData.money.bank < costs.upfront then
                Notify(src, Lang['notify_not_enough_money'], 'error')
                return
        end
        player.Functions.RemoveMoney('bank', costs.upfront, 't1ger-insurance-upfront')
        DepositToManagement(costs.upfront)
        UpdateInsuranceState(vehicle, true)
        SetCooldown(identifier, 'buy')
        Notify(src, Lang['notify_insurance_created']:format(FormatCurrency(costs.upfront)), 'success')
end)

RegisterNetEvent('t1ger_insurance:server:cancelInsurance', function(plate)
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local normalized = NormalizePlate(plate)
        if not normalized then
                Notify(src, Lang['notify_plate_missing'], 'error')
                return
        end
        plate = normalized
        local identifier = player.PlayerData.citizenid
        local hasCooldown, minutes = HasCooldown(identifier, 'cancel')
        if hasCooldown then
                Notify(src, Lang['notify_cooldown']:format(minutes), 'error')
                return
        end
        local vehicle = FetchVehicleByPlate(plate)
        if not vehicle or vehicle.owner ~= identifier then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        if not vehicle.insured then
                Notify(src, Lang['notify_no_insurance'], 'error')
                return
        end
        UpdateInsuranceState(vehicle, false)
        SetCooldown(identifier, 'cancel')
        Notify(src, Lang['notify_insurance_cancelled']:format(plate), 'inform')
end)

RegisterNetEvent('t1ger_insurance:server:offerSale', function(plate, targetSource)
        local src = source
        local broker = QBCore.Functions.GetPlayer(src)
        if not broker or not IsBroker(broker) then return end
        if type(targetSource) ~= 'number' or targetSource == src then return end
        local target = QBCore.Functions.GetPlayer(targetSource)
        if not target then return end
        local normalized = NormalizePlate(plate)
        if not normalized then
                Notify(src, Lang['notify_plate_missing'], 'error')
                return
        end
        local vehicle = FetchVehicleByPlate(normalized)
        if not vehicle or vehicle.owner ~= target.PlayerData.citizenid then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        if vehicle.insured then
                Notify(src, Lang['notify_has_insurance'], 'error')
                return
        end
        local data = {
                type = 'sale',
                plate = normalized,
                broker = broker.PlayerData.source,
                costs = vehicle.costs
        }
        TriggerClientEvent('t1ger_insurance:client:offerConfirmation', target.PlayerData.source, data)
        Notify(src, Lang['notify_wait_confirmation'], 'inform')
end)

RegisterNetEvent('t1ger_insurance:server:offerCancel', function(plate, targetSource)
        local src = source
        local broker = QBCore.Functions.GetPlayer(src)
        if not broker or not IsBroker(broker) then return end
        if type(targetSource) ~= 'number' or targetSource == src then return end
        local target = QBCore.Functions.GetPlayer(targetSource)
        if not target then return end
        local normalized = NormalizePlate(plate)
        if not normalized then
                Notify(src, Lang['notify_plate_missing'], 'error')
                return
        end
        local vehicle = FetchVehicleByPlate(normalized)
        if not vehicle or vehicle.owner ~= target.PlayerData.citizenid then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        if not vehicle.insured then
                Notify(src, Lang['notify_no_insurance'], 'error')
                return
        end
        local data = {
                type = 'cancel',
                plate = normalized,
                broker = broker.PlayerData.source,
                costs = vehicle.costs
        }
        TriggerClientEvent('t1ger_insurance:client:offerConfirmation', target.PlayerData.source, data)
        Notify(src, Lang['notify_wait_confirmation'], 'inform')
end)

RegisterNetEvent('t1ger_insurance:server:confirmOffer', function(offerType, plate, brokerSource, accepted)
        local src = source
        local target = QBCore.Functions.GetPlayer(src)
        if not target then return end
        if offerType ~= 'sale' and offerType ~= 'cancel' then return end
        if type(brokerSource) ~= 'number' or brokerSource == src then return end
        local broker = QBCore.Functions.GetPlayer(brokerSource)
        if not broker or not IsBroker(broker) then return end
        local normalized = NormalizePlate(plate)
        if not normalized then return end
        local vehicle = FetchVehicleByPlate(normalized)
        if not vehicle or vehicle.owner ~= target.PlayerData.citizenid then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        if offerType == 'sale' then
                if not accepted then
                        Notify(broker.PlayerData.source, Lang['notify_insurance_denied'], 'error')
                        return
                end
                if vehicle.insured then
                        Notify(src, Lang['notify_has_insurance'], 'error')
                        return
                end
                local identifier = target.PlayerData.citizenid
                local hasCooldown, minutes = HasCooldown(identifier, 'buy')
                if hasCooldown then
                        Notify(src, Lang['notify_cooldown']:format(minutes), 'error')
                        return
                end
                local costs = vehicle.costs
                if target.PlayerData.money.bank < costs.upfront then
                        Notify(src, Lang['notify_not_enough_money'], 'error')
                        return
                end
                target.Functions.RemoveMoney('bank', costs.upfront, 't1ger-insurance-broker-sale')
                DepositToManagement(costs.upfront)
                UpdateInsuranceState(vehicle, true)
                SetCooldown(identifier, 'buy')
                Notify(src, Lang['notify_insurance_created']:format(FormatCurrency(costs.upfront)), 'success')
                Notify(broker.PlayerData.source, Lang['notify_insurance_sold'], 'success')
        elseif offerType == 'cancel' then
                if not accepted then
                        Notify(broker.PlayerData.source, Lang['notify_insurance_denied'], 'error')
                        return
                end
                if not vehicle.insured then
                        Notify(src, Lang['notify_no_insurance'], 'error')
                        return
                end
                local identifier = target.PlayerData.citizenid
                local hasCooldown, minutes = HasCooldown(identifier, 'cancel')
                if hasCooldown then
                        Notify(src, Lang['notify_cooldown']:format(minutes), 'error')
                        return
                end
                UpdateInsuranceState(vehicle, false)
                SetCooldown(identifier, 'cancel')
                Notify(src, Lang['notify_insurance_removed'], 'success')
                Notify(broker.PlayerData.source, Lang['notify_insurance_cancelled']:format(normalized), 'inform')
        end
end)

RegisterNetEvent('t1ger_insurance:server:openPaper', function(plate, targetSource)
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local normalized = NormalizePlate(plate)
        if not normalized then
                Notify(src, Lang['notify_plate_missing'], 'error')
                return
        end
        local vehicle = FetchVehicleByPlate(normalized)
        if not vehicle or vehicle.owner ~= player.PlayerData.citizenid then
                Notify(src, Lang['notify_not_owner'], 'error')
                return
        end
        local charinfo = player.PlayerData.charinfo or {}
        local gender = charinfo.gender
        if type(gender) == 'number' then
                gender = gender == 0 and 'M' or gender == 1 and 'F' or tostring(gender)
        end
        local info = {
                firstname = charinfo.firstname or '',
                lastname = charinfo.lastname or '',
                dateofbirth = charinfo.birthdate or '',
                sex = gender or '',
                plate = normalized,
                model = vehicle.model,
                insured = vehicle.insured
        }
        local target = player
        if targetSource ~= nil then
                if type(targetSource) ~= 'number' then return end
                local forwarded = QBCore.Functions.GetPlayer(targetSource)
                if forwarded then
                        target = forwarded
                end
        end
        if not target then return end
        TriggerClientEvent('t1ger_insurance:client:openPaper', target.PlayerData.source, info)
end)

RegisterNetEvent('t1ger_insurance:server:payInsuranceBill', function()
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        local vehicles = FetchVehiclesByOwner(player.PlayerData.citizenid)
        local total = 0
        for _, vehicle in ipairs(vehicles) do
                if vehicle.insured then
                        total = total + vehicle.costs.subscription
                end
        end
        if total <= 0 then return end
        if player.PlayerData.money.bank < total then
                Notify(src, Lang['notify_not_enough_money'], 'error')
                return
        end
        player.Functions.RemoveMoney('bank', total, 't1ger-insurance-bill')
        DepositToManagement(total)
        Notify(src, Lang['notify_paid_bill']:format(FormatCurrency(total)), 'success')
end)
