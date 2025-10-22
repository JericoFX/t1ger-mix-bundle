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
