-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

-- shared state
towServices = towServices or {}

local jobToService = {}
local activeRewards = {}

for id, service in pairs(Config.TowServices) do
    local society = Config.Society[service.society]
    if society then
        jobToService[society.name] = id
    end
end

local function getJobDetails(Player)
    if not Player then return nil end
    local job = Player.PlayerData.job
    if not job then return nil end
    local grade = job.grade
    local gradeLevel = type(grade) == 'table' and (grade.level or grade.grade) or grade
    local isBoss = false
    if job.isBoss ~= nil then
        isBoss = job.isBoss
    elseif job.isboss ~= nil then
        isBoss = job.isboss
    elseif type(grade) == 'table' then
        if grade.isBoss ~= nil then
            isBoss = grade.isBoss
        elseif grade.isboss ~= nil then
            isBoss = grade.isboss
        end
    end
    return job.name, gradeLevel or 0, isBoss
end

local function getServiceForJob(jobName)
    return jobToService[jobName]
end

local function playerOwnsService(Player, serviceId)
    if not Player then return false end
    local service = towServices[serviceId]
    if not service then return false end
    return service.identifier == Player.PlayerData.citizenid
end

local function playerServiceInfo(Player)
    local jobName, grade, isBoss = getJobDetails(Player)
    if not jobName then return nil end
    local serviceId = getServiceForJob(jobName)
    if not serviceId then return nil end
    return serviceId, grade, isBoss
end

local function isServiceEmployee(Player, serviceId)
    if not Player then return false end
    if serviceId and playerOwnsService(Player, serviceId) then
        return true, serviceId
    end
    local jobServiceId = select(1, playerServiceInfo(Player))
    if not jobServiceId then return false end
    if serviceId and serviceId ~= jobServiceId then return false end
    return true, jobServiceId
end

local function hasServiceManageRights(Player, serviceId)
    if not Player then return false end
    if serviceId and playerOwnsService(Player, serviceId) then
        return true, serviceId
    end
    local jobServiceId, grade, isBoss = playerServiceInfo(Player)
    if not jobServiceId then return false end
    if serviceId and serviceId ~= jobServiceId then return false end
    local societyCfg = Config.Society[Config.TowServices[jobServiceId].society]
    local bossGrade = societyCfg and societyCfg.boss_grade or Config.BossGrade or 0
    if isBoss or grade >= bossGrade then
        return true, jobServiceId
    end
    return false, jobServiceId
end

local function SetupTowServices(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local ownedService = 0
    for id, data in pairs(towServices) do
        if data.identifier == Player.PlayerData.citizenid then
            ownedService = id
            break
        end
    end
    local serviceId = select(1, playerServiceInfo(Player)) or 0
    TriggerClientEvent('t1ger_towtrucker:loadTowServices', src, towServices, Config.TowServices, ownedService, serviceId)
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    while GetResourceState(GetCurrentResourceName()) ~= 'started' do Wait(100) end
    if GetResourceState(GetCurrentResourceName()) == 'started' then InitializeTowTrucker() end
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player)
    local src = source
    if type(player) == 'number' then
        src = player
    elseif type(player) == 'table' and player.PlayerData then
        src = player.PlayerData.source or src
    end
    SetupTowServices(src)
end)

RegisterNetEvent('QBCore:Server:OnJobUpdate', function(player)
    local src = source
    if type(player) == 'number' then
        src = player
    elseif type(player) == 'table' and player.PlayerData then
        src = player.PlayerData.source or src
    end
    SetupTowServices(src)
end)

AddEventHandler('playerDropped', function()
    activeRewards[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        SetupTowServices(Player.PlayerData.source)
    end
end)

QBCore.Functions.CreateCallback('t1ger_towtrucker:buyTowService', function(source, cb, id, val, name)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Config.TowServices[id] or Config.TowServices[id].owned then
        return cb(false)
    end
    local account = Config.BuyWithBank and 'bank' or 'cash'
    local balance = Player.PlayerData.money[account] or 0
    if balance < val.price then
        return cb(false)
    end
    Player.Functions.RemoveMoney(account, val.price, 'tow-service-purchase')
    MySQL.insert.await('INSERT INTO t1ger_towtrucker (id, identifier, name, impound) VALUES (?, ?, ?, ?)', {
        id,
        Player.PlayerData.citizenid,
        name,
        json.encode({})
    })
    local society = Config.Society[val.society]
    if society then
        Player.Functions.SetJob(society.name, society.boss_grade or Config.BossGrade or 0)
    end
    cb(true)
end)

RegisterNetEvent('t1ger_towtrucker:updateTowServices', function(num, val, state, name)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.TowServices[num] then return end
    local authorized = false
    local citizen = Player.PlayerData.citizenid
    if state == false then
        authorized = playerOwnsService(Player, num)
    elseif state == true then
        authorized = playerOwnsService(Player, num)
    else
        authorized = hasServiceManageRights(Player, num)
    end
    if not authorized then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['no_service_access'] or Lang['boss_menu_no_access'], 'error')
        return
    end
    UpdateTowServices(num, val, state, name, citizen)
end)

RegisterNetEvent('t1ger_towtrucker:sellTowService', function(id, val, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not playerOwnsService(Player, id) then return end
    MySQL.update.await('DELETE FROM t1ger_towtrucker WHERE id = ?', { id })
    local account = Config.BuyWithBank and 'bank' or 'cash'
    Player.Functions.AddMoney(account, amount, 'tow-service-sale')
    Player.Functions.SetJob('unemployed', 0)
end)

local function fetchImpound(id)
    local result = MySQL.single.await('SELECT impound FROM t1ger_towtrucker WHERE id = ?', { id })
    if result and result.impound then
        local decoded = json.decode(result.impound)
        if type(decoded) == 'table' then
            return decoded
        end
    end
    return {}
end

QBCore.Functions.CreateCallback('t1ger_towtrucker:GetImpoundVehicles', function(source, cb, id)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not isServiceEmployee(Player, id) then
        return cb(nil)
    end
    local list = fetchImpound(id)
    cb(list)
end)

RegisterNetEvent('t1ger_towtrucker:releaseImpound', function(id, plate, props, owner)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not isServiceEmployee(Player, id) then return end
    local impoundList = fetchImpound(id)
    for index, data in ipairs(impoundList) do
        if data.plate == plate then
            table.remove(impoundList, index)
            MySQL.update.await('UPDATE t1ger_towtrucker SET impound = ? WHERE id = ?', { json.encode(impoundList), id })
            MySQL.update.await('UPDATE owned_vehicles SET vehicle = ?, tow_impound = 0 WHERE plate = ? AND owner = ?', {
                json.encode(props),
                plate,
                owner
            })
            TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['veh_impound_released']:format(plate), 'success')
            return
        end
    end
end)

QBCore.Functions.CreateCallback('t1ger_towtrucker:impoundVehicle', function(source, cb, id, plate, vehProps)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not isServiceEmployee(Player, id) then
        return cb(false, Lang['no_service_access'] or Lang['boss_menu_no_access'])
    end
    if type(vehProps) ~= 'table' or not plate or plate == '' then
        return cb(false, Lang['vehicle_impounded'])
    end
    local record = MySQL.single.await('SELECT * FROM owned_vehicles WHERE plate = ? OR plate = ?', { plate, T1GER_Trim(plate) })
    if not record then
        return cb(false, Lang['impound_veh_not_owned'])
    end
    local impoundList = fetchImpound(id)
    for _, data in ipairs(impoundList) do
        if data.plate == record.plate then
            return cb(false, Lang['veh_already_in_impound'])
        end
    end
    MySQL.update.await('UPDATE owned_vehicles SET tow_impound = ? WHERE plate = ?', { id, record.plate })
    table.insert(impoundList, { plate = record.plate, owner = record.owner, props = json.encode(vehProps) })
    MySQL.update.await('UPDATE t1ger_towtrucker SET impound = ? WHERE id = ?', { json.encode(impoundList), id })
    cb(true, Lang['vehicle_impounded2'])
end)

QBCore.Functions.CreateCallback('t1ger_towtrucker:isVehicleInTowImpound', function(source, cb, plate)
    local record = MySQL.single.await('SELECT tow_impound FROM owned_vehicles WHERE plate = ? OR plate = ?', { plate, T1GER_Trim(plate) })
    if record and record.tow_impound and record.tow_impound > 0 then
        cb(true, record.tow_impound)
    else
        cb(false, 0)
    end
end)

RegisterNetEvent('t1ger_towtrucker:forceDelete', function(objNet)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not isServiceEmployee(Player) then return end
    TriggerClientEvent('t1ger_towtrucker:forceDeleteCL', -1, objNet)
end)

if Config.RepairKit and Config.RepairKit.itemName then
    QBCore.Functions.CreateUseableItem(Config.RepairKit.itemName, function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        TriggerClientEvent('t1ger_towtrucker:useRepairKit', source, Config.RepairKit)
    end)
end

RegisterNetEvent('t1ger_towtrucker:JobDataSV', function(jobType, num, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not isServiceEmployee(Player) then return end
    TriggerClientEvent('t1ger_towtrucker:JobDataCL', -1, jobType, num, data)
end)

RegisterNetEvent('t1ger_towtrucker:getJobReward', function(payout)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not isServiceEmployee(Player) then return end
    if type(payout) ~= 'table' or type(payout.min) ~= 'number' or type(payout.max) ~= 'number' then return end
    local limits = Config.RewardLimits or {}
    local minReward = math.max(math.floor(payout.min), limits.min or 0)
    local maxReward = math.min(math.floor(payout.max), limits.max or math.floor(payout.max))
    if maxReward < minReward then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['job_reward_invalid'] or Lang['invalid_amount'], 'error')
        return
    end
    local cooldown = limits.cooldown or 0
    local now = os.time()
    if cooldown > 0 and activeRewards[src] and (now - activeRewards[src]) < cooldown then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['job_reward_cooldown'] or Lang['action_not_possible'], 'error')
        return
    end
    local cash = math.random(minReward, maxReward)
    Player.Functions.AddMoney('cash', cash, 'tow-job-reward')
    activeRewards[src] = now
    TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['job_cash_reward']:format(cash), 'success')
end)

RegisterNetEvent('t1ger_towtrucker:server:issueInvoice', function(targetId, account, label, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Player or not Target then return end
    local hasAccess, serviceId = isServiceEmployee(Player)
    if not hasAccess or not Config.TowServices[serviceId] then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['no_service_access'] or Lang['boss_menu_no_access'], 'error')
        return
    end
    amount = tonumber(amount) or 0
    local limits = Config.InvoiceLimits or {}
    local minAmount = limits.min or 0
    local maxAmount = limits.max or amount
    if amount < minAmount or (maxAmount > 0 and amount > maxAmount) then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['invoice_invalid'] or Lang['invalid_amount'], 'error')
        return
    end
    local societyCfg = Config.Society[Config.TowServices[serviceId].society]
    local jobName = societyCfg and societyCfg.name or 'towtrucker'
    local invoiceLabel = type(label) == 'string' and label ~= '' and label or societyCfg.label or 'Tow Service'
    if GetResourceState('qb-billing') == 'started' then
        TriggerEvent('qb-billing:server:sendBill', targetId, src, jobName, invoiceLabel, amount)
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['invoice_sent'], 'success')
        return
    end
    local payAccount = Config.PayBillsWithBank and 'bank' or 'cash'
    if (Target.PlayerData.money[payAccount] or 0) < amount then
        TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['invoice_failed'], 'error')
        TriggerClientEvent('t1ger_towtrucker:notify', targetId, Lang['insufficient_money'], 'error')
        return
    end
    Target.Functions.RemoveMoney(payAccount, amount, 'tow-invoice')
    local percent = Config.BillPercentToService or 0
    local societyAmount = math.floor(amount * (percent / 100))
    local playerAmount = amount - societyAmount
    if societyAmount > 0 and GetResourceState('qb-management') == 'started' then
        pcall(function()
            exports['qb-management']:AddMoney(jobName, societyAmount)
        end)
    else
        playerAmount = amount
    end
    if playerAmount > 0 then
        Player.Functions.AddMoney('bank', playerAmount, 'tow-invoice-payment')
    end
    TriggerClientEvent('t1ger_towtrucker:notify', src, Lang['invoice_sent'], 'success')
    TriggerClientEvent('t1ger_towtrucker:notify', targetId, Lang['invoice_paid']:format(amount), 'inform')
end)

QBCore.Functions.CreateCallback('t1ger_towtrucker:getSocietyFunds', function(source, cb, jobName)
    local balance = 0
    if jobName and GetResourceState('qb-management') == 'started' then
        local ok, result = pcall(function()
            return exports['qb-management']:GetAccount(jobName)
        end)
        if ok and result then
            if type(result) == 'table' then
                balance = result.balance or result.money or result[1] or 0
            elseif type(result) == 'number' then
                balance = result
            end
        end
    end
    cb(balance)
end)
