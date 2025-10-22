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
    end
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
end)
