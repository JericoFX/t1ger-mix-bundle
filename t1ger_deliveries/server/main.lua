local QBCore = exports['qb-core']:GetCoreObject()
local SharedUtils = SharedUtils

local companyState = {}
local activeDeliveries = {}
local routeCache = {}

local function loadCompanies()
    local results = MySQL.query.await('SELECT * FROM t1ger_deliveries') or {}

    for _, row in ipairs(results) do
        local id = tonumber(row.id)
        local company = Config.Companies[id]

        if company then
            companyState[id] = {
                owned = true,
                data = {
                    id = id,
                    citizenid = row.citizenid,
                    name = row.name,
                    level = tonumber(row.level) or 0,
                    certificate = row.certificate == 1 or row.certificate == true
                }
            }
        end
    end
end

local function getOwnedCompanyId(citizenid)
    for id, state in pairs(companyState) do
        if state.owned and state.data and state.data.citizenid == citizenid then
            return id
        end
    end

    return 0
end

local function getAssignedCompanyId(jobName)
    for id, company in pairs(Config.Companies) do
        if company.jobName == jobName then
            return id
        end
    end

    return 0
end

local function sendCompanyState(src)
    local player = QBCore.Functions.GetPlayer(src)

    if not player then
        return
    end

    local citizenid = player.PlayerData.citizenid
    local jobName = player.PlayerData.job and player.PlayerData.job.name or nil

    TriggerClientEvent('t1ger_deliveries:client:syncCompanies', src, companyState, getOwnedCompanyId(citizenid), getAssignedCompanyId(jobName))
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    loadCompanies()

    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        sendCompanyState(playerId)
-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
local deliveryCompanies = {}
local rewardCooldowns = {}

local function getTimer()
    if type(GetGameTimer) == 'function' then
        return GetGameTimer()
    end
    return os.time() * 1000
end

local function addSocietyMoney(job, amount)
    if not amount or amount <= 0 then return end
    local success, err = pcall(function()
        exports['qb-management']:AddMoney(job, amount)
    end)
    if not success and err then
        print(('^1[t1ger_deliveries] Failed adding money to %s: %s^0'):format(job, err))
    end
end

local function getSocietyBalance(job)
    local success, balance = pcall(function()
        return exports['qb-management']:GetAccountBalance(job)
    end)
    if success then
        return balance
    end
    return nil
end

CreateThread(function()
    while GetResourceState('mysql-async') ~= 'started' do
        Wait(0)
    end
    while GetResourceState(GetCurrentResourceName()) ~= 'started' do
        Wait(0)
    end
    if GetResourceState(GetCurrentResourceName()) == 'started' then
        CreateThread(function()
            Wait(1000)
            MySQL.Async.fetchAll('SELECT * FROM t1ger_deliveries', {}, function(results)
                if next(results) then
                    for i = 1, #results do
                        local data = {
                            identifier = results[i].identifier,
                            id = results[i].id,
                            name = results[i].name,
                            level = results[i].level,
                            certificate = results[i].certificate == 1 or results[i].certificate == true
                        }
                        deliveryCompanies[data.id] = data
                        if Config.Companies[data.id] then
                            Config.Companies[data.id].owned = true
                            Config.Companies[data.id].data = data
                        end
                        Wait(5)
                    end
                end
            end)
        end)
    end
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    SetupDeliveryCompanies(Player.PlayerData.source)
end)

RegisterNetEvent('t1ger_deliveries:debugSV', function()
    SetupDeliveryCompanies(source)
end)

local function getPlayerCompanyState(Player)
    local isOwner, deliveryID = 0, 0
    if next(deliveryCompanies) then
        for k, v in pairs(deliveryCompanies) do
            if v.identifier == Player.PlayerData.citizenid then
                isOwner = v.id
            end
            local company = Config.Companies[v.id]
            if company then
                local targetJob = Config.Society[company.society].name
                if Player.PlayerData.job.name == targetJob then
                    deliveryID = v.id
                end
            end
        end
    end

    return isOwner, deliveryID
end

function SetupDeliveryCompanies(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local isOwner, deliveryID = getPlayerCompanyState(Player)
    TriggerClientEvent('t1ger_deliveries:loadCompanies', src, deliveryCompanies, Config.Companies, isOwner, deliveryID)
end

lib.callback.register('t1ger_deliveries:setup', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return deliveryCompanies, Config.Companies, 0, 0
    end

    local isOwner, deliveryID = getPlayerCompanyState(Player)
    return deliveryCompanies, Config.Companies, isOwner, deliveryID
end)

RegisterNetEvent('t1ger_deliveries:updateCompanyDataSV', function(id, data)
    if not Config.Companies[id] then return end
    Config.Companies[id].data = data
    TriggerClientEvent('t1ger_deliveries:updateCompanyDataCL', -1, id, Config.Companies[id].data)
end)

lib.callback.register('t1ger_deliveries:buyCompany', function(source, id, val, name)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local account = Config.BuyWithBank and 'bank' or 'cash'
    local balance = Player.Functions.GetMoney(account)
    if balance < val.price then
        return false
    end

    Player.Functions.RemoveMoney(account, val.price, 't1ger-deliveries-company-purchase')

    MySQL.Async.execute('INSERT INTO t1ger_deliveries (id, identifier, name) VALUES (@id, @identifier, @name)', {
        ['@id'] = id,
        ['@identifier'] = Player.PlayerData.citizenid,
        ['@name'] = name
    })

    local data = {
        identifier = Player.PlayerData.citizenid,
        id = id,
        name = name,
        level = 0,
        certificate = false
    }
    deliveryCompanies[id] = data

    if Config.Companies[id] then
        Config.Companies[id].owned = true
        Config.Companies[id].data = data
    end

    local society = Config.Society[val.society]
    if society then
        Player.Functions.SetJob(society.name, society.boss_grade or 0)
    end

    TriggerClientEvent('t1ger_deliveries:syncServices', -1, deliveryCompanies, Config.Companies)
    return true
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(playerId)
    sendCompanyState(playerId)
end)

RegisterNetEvent('QBCore:Server:OnJobUpdate', function(src)
    sendCompanyState(src)
end)

RegisterNetEvent('QBCore:Server:PlayerDropped', function(src)
    activeDeliveries[src] = nil
end)

lib.callback.register('t1ger_deliveries:server:initialize', function(source)
    local player = QBCore.Functions.GetPlayer(source)

    if not player then
        return companyState, 0, 0
    end

    local citizenid = player.PlayerData.citizenid
    local jobName = player.PlayerData.job and player.PlayerData.job.name or nil

    return companyState, getOwnedCompanyId(citizenid), getAssignedCompanyId(jobName)
end)

local function playerOwnsCompany(player, companyId)
    local state = companyState[companyId]

    return state and state.owned and state.data and state.data.citizenid == player.PlayerData.citizenid
end

lib.callback.register('t1ger_deliveries:server:purchaseCompany', function(source, companyId, name)
    local player = QBCore.Functions.GetPlayer(source)
    local company = Config.Companies[companyId]

    if not player or not company or not name or name == '' then
        return false
    end

    if companyState[companyId] and companyState[companyId].owned then
        return false
    end

    if getOwnedCompanyId(player.PlayerData.citizenid) ~= 0 then
        return false
    end

    local account = Config.BuyWithBank and 'bank' or 'cash'
    local balance = player.PlayerData.money[account] or 0

    if balance < company.price then
        return false
    end

    player.Functions.RemoveMoney(account, company.price, 't1ger-deliveries-purchase')

    local data = {
        id = companyId,
        citizenid = player.PlayerData.citizenid,
        name = name,
        level = 0,
        certificate = false
    }

    companyState[companyId] = { owned = true, data = data }

    MySQL.insert.await('REPLACE INTO t1ger_deliveries (id, citizenid, name, level, certificate) VALUES (?, ?, ?, ?, ?)', {
        companyId,
        data.citizenid,
        data.name,
        data.level,
        data.certificate and 1 or 0
    })

    player.Functions.SetJob(company.jobName, Config.JobBossGrade or 4)

    TriggerClientEvent('t1ger_deliveries:client:updateCompany', -1, companyId, data)

    return true
end)

RegisterNetEvent('t1ger_deliveries:server:renameCompany', function(companyId, name)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    if not player or not name or name == '' then
        return
    end

    if not playerOwnsCompany(player, companyId) then
        return
    end

    local state = companyState[companyId]
    state.data.name = name

    MySQL.update.await('UPDATE t1ger_deliveries SET name = ? WHERE id = ?', { name, companyId })

    TriggerClientEvent('t1ger_deliveries:client:updateCompany', -1, companyId, state.data)
end)

RegisterNetEvent('t1ger_deliveries:server:sellCompany', function(companyId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local company = Config.Companies[companyId]
    local state = companyState[companyId]

    if not player or not company or not state or not state.owned then
        return
    end

    if not playerOwnsCompany(player, companyId) then
        return
    end

    local sellPrice = math.floor(company.price * Config.SalePercentage)

    player.Functions.AddMoney(Config.BuyWithBank and 'bank' or 'cash', sellPrice, 't1ger-deliveries-sell')
    player.Functions.SetJob('unemployed', 0)

    companyState[companyId] = { owned = false }

    MySQL.query.await('DELETE FROM t1ger_deliveries WHERE id = ?', { companyId })

    TriggerClientEvent('t1ger_deliveries:client:updateCompany', -1, companyId, nil)
end)

lib.callback.register('t1ger_deliveries:server:buyCertificate', function(source, companyId)
    local player = QBCore.Functions.GetPlayer(source)
    local state = companyState[companyId]

    if not player or not state or not state.owned then
        return false
    end

    if not playerOwnsCompany(player, companyId) then
        return false
    end

    if state.data.certificate then
        return true
    end

    local account = Config.BuyWithBank and 'bank' or 'cash'
    local balance = player.PlayerData.money[account] or 0

    if balance < Config.CertificatePrice then
        return false
    end

    player.Functions.RemoveMoney(account, Config.CertificatePrice, 't1ger-deliveries-certificate')

    state.data.certificate = true

    MySQL.update.await('UPDATE t1ger_deliveries SET certificate = ? WHERE id = ?', { 1, companyId })

    TriggerClientEvent('t1ger_deliveries:client:updateCompany', -1, companyId, state.data)

    return true
end)

local function getVehicleData(tier, model)
    for _, vehicle in ipairs(tier.vehicles or {}) do
        if string.lower(vehicle.model) == string.lower(model) then
            return vehicle
        end
    end
end

lib.callback.register('t1ger_deliveries:server:startDelivery', function(source, payload)
    local player = QBCore.Functions.GetPlayer(source)

    if not player then
        return nil
    end

    local companyId = payload.companyId
    local tierId = payload.tier
    local vehicleModel = payload.vehicle

    local companyConfig = Config.Companies[companyId]
    local state = companyState[companyId]
    local tier = Config.JobValues[tierId]

    if not companyConfig or not tier or not state or not state.owned then
        return nil
    end

    local isOwner = playerOwnsCompany(player, companyId)
    local hasJob = player.PlayerData.job and player.PlayerData.job.name == companyConfig.jobName

    if not isOwner and not hasJob then
        return nil
    end

    if activeDeliveries[source] then
        return nil
    end

    if tier.certificate and not state.data.certificate then
        return nil
    end

    if (state.data.level or 0) < (tier.level or 0) then
        return nil
    end

    if not SharedUtils.IsVehicleAllowed(companyId, vehicleModel) then
        return nil
    end

    local vehicleData = getVehicleData(tier, vehicleModel)
    if not vehicleData then
        return nil
    end

    local route = SharedUtils.GetCachedValue(routeCache, string.format('%s:%s', companyId, tierId), Config.RouteCacheTTL, function()
        local available = companyConfig.deliveries and companyConfig.deliveries[tierId] or nil

        if not available or #available == 0 then
            return nil
        end

        local index = math.random(#available)
        return SharedUtils.DeepCopy(available[index])
    end)

    if not route then
        return nil
    end

    local deposit = vehicleData.deposit or 0

    if deposit > 0 then
        local account = Config.DepositInBank and 'bank' or 'cash'
        local balance = player.PlayerData.money[account] or 0

        if balance < deposit then
            return nil
        end

        player.Functions.RemoveMoney(account, deposit, 't1ger-deliveries-deposit')
        TriggerClientEvent('t1ger_deliveries:client:depositUpdate', source, 'paid', deposit)
    end

    local payout = 0
    if tier.payout then
        local base = tier.payout.base or 0
        local perStop = tier.payout.perStop or 0
        payout = base + (#route * perStop)
    end

    activeDeliveries[source] = {
        companyId = companyId,
        tier = tierId,
        vehicle = string.lower(vehicleModel),
        route = SharedUtils.DeepCopy(route),
        progress = {},
        deposit = deposit,
        payout = payout
    }

    return {
        companyId = companyId,
        tier = tierId,
        vehicle = string.lower(vehicleModel),
        route = route,
        payout = payout,
        deposit = deposit
    }
end)

lib.callback.register('t1ger_deliveries:server:advanceDelivery', function(source, payload)
    local job = activeDeliveries[source]

    if not job then
        return false
    end

    if job.companyId ~= payload.companyId or job.tier ~= payload.tier then
        return false
    end

    if job.progress[payload.index] then
        return false
    end

    if string.lower(payload.vehicle or '') ~= job.vehicle then
        return false
    end

    local expected = job.route[payload.index]

    if not expected or not SharedUtils.VectorEquals(expected, payload.coords, Config.CoordinateTolerance or 4.0) then
        return false
    end

    job.progress[payload.index] = true

    if payload.index >= #job.route then
        local player = QBCore.Functions.GetPlayer(source)

        if player then
            if job.payout > 0 then
                player.Functions.AddMoney('bank', job.payout, 't1ger-deliveries-payment')
            end

            if job.deposit and job.deposit > 0 then
                local account = Config.DepositInBank and 'bank' or 'cash'
                player.Functions.AddMoney(account, job.deposit, 't1ger-deliveries-deposit-return')
                TriggerClientEvent('t1ger_deliveries:client:depositUpdate', source, 'returned', job.deposit)
            end
        end

        local state = companyState[job.companyId]
        if state and state.data then
            state.data.level = (state.data.level or 0) + (Config.AddLevelAmount or 1)
            MySQL.update.await('UPDATE t1ger_deliveries SET level = ? WHERE id = ?', { state.data.level, job.companyId })
            TriggerClientEvent('t1ger_deliveries:client:updateCompany', -1, job.companyId, state.data)
        end

        activeDeliveries[source] = nil
    end

    return true
end)

RegisterNetEvent('t1ger_deliveries:server:cancelDelivery', function()
    local src = source
    local job = activeDeliveries[src]

    if not job then
        return
    end

    local player = QBCore.Functions.GetPlayer(src)

    if player and job.deposit and job.deposit > 0 then
        local account = Config.DepositInBank and 'bank' or 'cash'
        player.Functions.AddMoney(account, job.deposit, 't1ger-deliveries-deposit-cancel')
        TriggerClientEvent('t1ger_deliveries:client:depositUpdate', src, 'returned', job.deposit)
    end

    activeDeliveries[src] = nil
end)

RegisterNetEvent('t1ger_deliveries:server:timeoutDelivery', function()
    local src = source
    local job = activeDeliveries[src]
    activeDeliveries[src] = nil
    TriggerClientEvent('t1ger_deliveries:client:deliveryTimeout', src)

    if job and job.deposit and job.deposit > 0 then
        TriggerClientEvent('t1ger_deliveries:client:depositUpdate', src, 'withheld', job.deposit)
    end
RegisterNetEvent('t1ger_deliveries:sellCompany', function(id, val, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.Async.execute('DELETE FROM t1ger_deliveries WHERE id = @id', { ['@id'] = id })

    if Config.Companies[id] then
        Config.Companies[id].owned = false
        Config.Companies[id].data = nil
    end
    deliveryCompanies[id] = nil

    local account = Config.BuyWithBank and 'bank' or 'cash'
    Player.Functions.AddMoney(account, amount, 't1ger-deliveries-company-sold')
    Player.Functions.SetJob('unemployed', 0)

    TriggerClientEvent('t1ger_deliveries:syncServices', -1, deliveryCompanies, Config.Companies)
end)

RegisterNetEvent('t1ger_deliveries:updateCompany', function(num, val, state, name)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if state ~= nil then
        if state then
            local data = {
                identifier = Player.PlayerData.citizenid,
                id = num,
                name = name,
                level = 0,
                certificate = false
            }
            deliveryCompanies[num] = data
            if Config.Companies[num] then
                Config.Companies[num].owned = true
                Config.Companies[num].data = data
            end
        else
            deliveryCompanies[num] = nil
            if Config.Companies[num] then
                Config.Companies[num].owned = false
                Config.Companies[num].data = nil
            end
            MySQL.Async.execute('DELETE FROM t1ger_deliveries WHERE id = @id', { ['@id'] = num })
        end
    elseif name ~= nil then
        local company = deliveryCompanies[num]
        if company then
            company.name = name
            MySQL.Async.execute('UPDATE t1ger_deliveries SET name = @name WHERE id = @id', {
                ['@name'] = name,
                ['@id'] = num
            })
        end
        if Config.Companies[num] then
            Config.Companies[num].data = Config.Companies[num].data or {}
            Config.Companies[num].data.name = name
        end
    end

    TriggerClientEvent('t1ger_deliveries:syncServices', -1, deliveryCompanies, Config.Companies)
end)

lib.callback.register('t1ger_deliveries:buyCertifcate', function(source, id)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local account = Config.BuyWithBank and 'bank' or 'cash'
    local balance = Player.Functions.GetMoney(account)
    if balance < Config.CertificatePrice then
        return false
    end

    Player.Functions.RemoveMoney(account, Config.CertificatePrice, 't1ger-deliveries-certificate')

    MySQL.Async.execute('UPDATE t1ger_deliveries SET certificate = @certificate WHERE id = @id', {
        ['@certificate'] = true,
        ['@id'] = id
    })

    if deliveryCompanies[id] then
        deliveryCompanies[id].certificate = true
    end
    if Config.Companies[id] and Config.Companies[id].data then
        Config.Companies[id].data.certificate = true
    end

    TriggerClientEvent('t1ger_deliveries:updateCompanyDataCL', -1, id, Config.Companies[id].data)
    return true
end)

lib.callback.register('t1ger_deliveries:payVehicleDeposit', function(source, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local account = Config.DepositInBank and 'bank' or 'cash'
    local balance = Player.Functions.GetMoney(account)
    if balance < amount then
        return false
    end

    Player.Functions.RemoveMoney(account, amount, 't1ger-deliveries-vehicle-deposit')
    return true
end)

RegisterNetEvent('t1ger_deliveries:retrievePaycheck', function(paycheck, vehDeposit, giveDeposit, id, val)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if rewardCooldowns[src] and rewardCooldowns[src] > getTimer() then
        print(('^1[t1ger_deliveries] Paycheck cooldown triggered by %s^0'):format(src))
        return
    end
    rewardCooldowns[src] = getTimer() + 3000

    paycheck = tonumber(paycheck) or 0
    vehDeposit = tonumber(vehDeposit) or 0
    giveDeposit = giveDeposit and vehDeposit > 0

    if giveDeposit then
        local account = Config.DepositInBank and 'bank' or 'cash'
        Player.Functions.AddMoney(account, vehDeposit, 't1ger-deliveries-deposit-return')
        TriggerClientEvent('t1ger_deliveries:notify', src, (Lang['deposit_returned']):format(vehDeposit))
    end

    if paycheck > 0 then
        addSocietyMoney(Player.PlayerData.job.name, paycheck)
        TriggerClientEvent('t1ger_deliveries:notify', src, (Lang['paycheck_received']):format(paycheck))
    end

    local newLevel = (Config.Companies[id] and Config.Companies[id].data and Config.Companies[id].data.level or 0) + Config.AddLevelAmount
    MySQL.Async.execute('UPDATE t1ger_deliveries SET level = @level WHERE id = @id', {
        ['@level'] = newLevel,
        ['@id'] = id
    })

    if Config.Companies[id] then
        Config.Companies[id].data = Config.Companies[id].data or {}
        Config.Companies[id].data.level = newLevel
        TriggerClientEvent('t1ger_deliveries:updateCompanyDataCL', -1, id, Config.Companies[id].data)
    end
end)

lib.callback.register('t1ger_deliveries:getShopOrders', function()
    local orders = exports['t1ger_shops'] and exports['t1ger_shops']:GetShopOrders()
    return orders or {}
end)

RegisterNetEvent('t1ger_deliveries:updateOrderState', function(data, state)
    if exports['t1ger_shops'] then
        exports['t1ger_shops']:UpdateOrderTakenStatus(data.id, data.shopID, state)
    end
end)

RegisterNetEvent('t1ger_deliveries:orderDeliveryDone', function(data)
    if exports['t1ger_shops'] then
        exports['t1ger_shops']:AddShopOrder(data)
    end
end)

lib.callback.register('t1ger_deliveries:getInventoryItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local invItem = Player.Functions.GetItemByName(item)
    if not invItem then
        print(('^1[ITEM ERROR] - [%s] DOES NOT EXIST IN DATABASE^0'):format(string.upper(item)))
        return false
    end

    return invItem.amount and invItem.amount >= amount
end)

RegisterNetEvent('t1ger_deliveries:removeItem', function(item, count)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, count)
end)

lib.callback.register('t1ger_deliveries:hasCompany', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local p = promise.new()
    MySQL.Async.fetchAll('SELECT * FROM t1ger_deliveries WHERE identifier = @identifier', {
        ['@identifier'] = Player.PlayerData.citizenid
    }, function(results)
        if next(results) then
            local company = results[1]
            local societyIndex = Config.Companies[company.id] and Config.Companies[company.id].society
            if societyIndex and Config.Society[societyIndex] then
                local jobName = Config.Society[societyIndex].name
                Player.Functions.SetJob(jobName, Config.Society[societyIndex].boss_grade or 0)
            end
            p:resolve({ true, company.id })
        else
            p:resolve({ false })
        end
    end)

    local result = Citizen.Await(p)
    return table.unpack(result)
end)

lib.callback.register('t1ger_deliveries:getSocietyVehicles', function(source, jobName)
    local storage = Config.SocietyVehicleStorage
    if not storage then
        return {}
    end

    local query = ('SELECT * FROM %s WHERE %s = @job'):format(storage.table, storage.jobColumn)
    local parameters = {
        ['@job'] = jobName
    }

    if storage.stateColumn and storage.availableState ~= nil then
        query = query .. (' AND %s = @state'):format(storage.stateColumn)
        parameters['@state'] = storage.availableState
    end

    local p = promise.new()
    MySQL.Async.fetchAll(query, parameters, function(results)
        p:resolve(results or {})
    end)

    return Citizen.Await(p)
end)

lib.callback.register('t1ger_deliveries:getSocietyBalance', function(source, job)
    return getSocietyBalance(job)
end)
