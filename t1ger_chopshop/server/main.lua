-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports[Config.CoreResource]:GetCoreObject()

local carList = {}
local scrapCooldown = {}
local thiefCooldown = {}
local activeThiefJobs = {}
local processedScrapPlates = {}
local rateLimits = {}

local function rateLimit(src, key, cooldownMs)
    local now = GetGameTimer()
    rateLimits[src] = rateLimits[src] or {}
    local last = rateLimits[src][key] or 0
    if now - last < cooldownMs then
        return false
    end
    rateLimits[src][key] = now
    return true
end

local function logSecurityEvent(src, player, reason, details)
    local identifier = 'unknown'
    local name = ('src:%s'):format(src or 'n/a')

    if player and player.PlayerData then
        identifier = player.PlayerData.citizenid or identifier
        if player.PlayerData.name and player.PlayerData.name ~= '' then
            name = player.PlayerData.name
        end
    end

    local suffix = ''
    if details and details ~= '' then
        suffix = (' (%s)'):format(details)
    end

    print(('[t1ger_chopshop] %s [%s] %s%s'):format(name, identifier, reason, suffix))
end

local function cleanupProcessedPlates()
    local now = os.time()
    for plate, expires in pairs(processedScrapPlates) do
        if expires <= now then
            processedScrapPlates[plate] = nil
        end
    end
end

local function getAccount(dirty)
    if dirty and Config.BlackMoney and Config.BlackMoney.account then
        return Config.BlackMoney.account
    end
    return 'cash'
end

local function canAfford(player, amount, dirty)
    return player.Functions.GetMoney(getAccount(dirty)) >= amount
end

local function removeMoney(player, amount, dirty, reason)
    return player.Functions.RemoveMoney(getAccount(dirty), amount, reason or 't1ger-chopshop')
end

local function addMoney(player, amount, dirty, reason)
    player.Functions.AddMoney(getAccount(dirty), amount, reason or 't1ger-chopshop')
end

local function GenerateCarList()
    carList = {}
    local shuffled = {}
    for index, data in ipairs(Config.ScrapVehicles) do
        shuffled[index] = data
    end

    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local totalCount = math.min(Config.ChopShop.Settings.carListAmount, #shuffled)
    for i = 1, totalCount do
        local car = shuffled[i]
        carList[#carList + 1] = { label = car.label, hash = car.hash, price = car.price }
    end

    return carList
end

local function notify(source, message, messageType)
    if not source or not message then return end
    TriggerClientEvent('ox_lib:notify', source, {
        title = Lang and Lang['notify_title'] or 'Chop Shop',
        description = message,
        type = messageType or 'inform'
    })
end

local function InitializeChopShop()
    Wait(1000)
    while true do
        GenerateCarList()
        TriggerClientEvent('t1ger_chopshop:intializeChopShop', -1, carList)
        Wait(Config.ChopShop.Settings.newCarListTimer * 60000)
    end
end

CreateThread(InitializeChopShop)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
    if not player then return end
    TriggerClientEvent('t1ger_chopshop:intializeChopShop', player.PlayerData.source, carList)
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeThiefJobs[src] = nil
end)

QBCore.Functions.CreateCallback('t1ger_chopshop:isVehicleOwned', function(source, cb, plate)
    if not plate then
        cb(false)
        return
    end
    local result = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate })
    cb(result ~= nil)
end)

QBCore.Functions.CreateCallback('t1ger_chopshop:getCopsCount', function(source, cb)
    cb(GetCopsCount())
end)

QBCore.Functions.CreateCallback('t1ger_chopshop:hasCooldown', function(source, cb, cooldownType)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        cb(false)
        return
    end

    local cooldownCfg = Config.ChopShop.Settings.cooldown[cooldownType]
    if not cooldownCfg or not cooldownCfg.enable then
        cb(false)
        return
    end

    local bucket = cooldownType == 'scrap' and scrapCooldown or thiefCooldown
    local identifier = player.PlayerData.citizenid
    local expires = bucket[identifier]
    if not expires then
        cb(false)
        return
    end

    local now = os.time()
    if expires <= now then
        bucket[identifier] = nil
        cb(false)
        return
    end

    local remaining = expires - now
    local minutes = math.ceil(remaining / 60)
    logSecurityEvent(source, player, 'attempt blocked by cooldown', ('type=%s remaining=%s'):format(cooldownType, minutes))
    local messages = {
        scrap = Lang['scrap_cooldown'],
        thief = Lang['job_cooldown']
    }
    notify(source, (messages[cooldownType] or Lang['scrap_cooldown']):format(minutes), 'error')
    cb(true)
end)

local function addCooldown(src, cooldownType)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local cfg = Config.ChopShop.Settings.cooldown[cooldownType]
    if not cfg or not cfg.enable then return end
    local bucket = cooldownType == 'scrap' and scrapCooldown or thiefCooldown
    bucket[player.PlayerData.citizenid] = os.time() + (cfg.timer * 60)
end

RegisterNetEvent('t1ger_chopshop:deleteOwnedVehicle', function(plate)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not plate then return end
    local result = MySQL.single.await('SELECT citizenid FROM owned_vehicles WHERE plate = ?', { plate })
    if result and result.citizenid == player.PlayerData.citizenid then
        MySQL.update.await('DELETE FROM owned_vehicles WHERE plate = ?', { plate })
        processedScrapPlates[plate] = nil
    end
end)

RegisterNetEvent('t1ger_chopshop:getPayment', function(scrapCar, percent, plate)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or type(scrapCar) ~= 'table' or type(scrapCar.hash) ~= 'number' then return end
    if not rateLimit(src, 'scrapPayment', 1000) then return end

    local scrapPos = Config.ChopShop.ScrapNPC and Config.ChopShop.ScrapNPC.pos and Config.ChopShop.ScrapNPC.pos.veh
    if scrapPos then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local playerCoords = GetEntityCoords(ped)
        local targetCoords = vector3(scrapPos[1], scrapPos[2], scrapPos[3])
        if #(playerCoords - targetCoords) > 8.0 then
            logSecurityEvent(src, player, 'scrap payment blocked (distance)', nil)
            return
        end
    end

    percent = tonumber(percent) or 0
    percent = math.min(math.max(percent, 0), 100)

    cleanupProcessedPlates()
    if plate then
        plate = plate:gsub('%s+', ''):upper()
        if processedScrapPlates[plate] then
            logSecurityEvent(src, player, 'duplicate scrap attempt blocked', ('plate=%s'):format(plate))
            return
        end
    end

    local valid = false
    local price = 0
    for _, car in ipairs(carList) do
        if car.hash == scrapCar.hash then
            valid = true
            price = car.price or 0
            break
        end
    end
    if not valid then
        for _, car in ipairs(Config.ScrapVehicles) do
            if car.hash == scrapCar.hash then
                valid = true
                price = car.price or 0
                break
            end
        end
    end
    if not valid then return end

    local cfg = Config.ChopShop.Settings.scrap_rewards
    local money = math.floor(price * (percent / 100))
    if cfg.cash.enable and money > 0 then
        addMoney(player, money, cfg.cash.dirty, 't1ger-chopshop-scrap')
        notify(src, Lang['cash_reward']:format(money), 'success')
    end

    if cfg.items.enable then
        local delivered = 0
        for _, item in pairs(Config.Materials) do
            if delivered >= cfg.items.maxItems then break end
            if math.random(0, 100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                if player.Functions.AddItem(item.item, amount) then
                    delivered = delivered + 1
                end
                Wait(50)
            end
        end
    end

    if plate then
        processedScrapPlates[plate] = os.time() + 1800
    end

    if Config.ChopShop.Settings.cooldown.scrap.enable then
        addCooldown(src, 'scrap')
    end
end)

RegisterNetEvent('t1ger_chopshop:selectRiskGrade', function(grade)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local selectedGrade
    for _, data in pairs(Config.RiskGrades) do
        if data.grade == grade then
            selectedGrade = data
            break
        end
    end
    if not selectedGrade or not selectedGrade.enable then return end

    if not Config.ChopShop.Police.allowCops then
        for _, jobName in pairs(Config.ChopShop.Police.jobs) do
            if player.PlayerData.job.name == jobName then
                notify(src, Lang['police_not_allowed'], 'error')
                return
            end
        end
    end

    if GetCopsCount() < selectedGrade.cops then
        notify(src, Lang['not_enough_police'], 'error')
        return
    end

    local jobFee = selectedGrade.job_fees
    if jobFee > 0 and not canAfford(player, jobFee, Config.ChopShop.Settings.jobFeesDirty) then
        notify(src, Lang['not_enough_money'], 'error')
        return
    end

    if jobFee > 0 then
        removeMoney(player, jobFee, Config.ChopShop.Settings.jobFeesDirty, 't1ger-chopshop-fee')
    end

    local vehicles = selectedGrade.vehicles
    local veh = vehicles[math.random(1, #vehicles)]
    activeThiefJobs[src] = { payout = veh.payout, hash = veh.hash }

    TriggerClientEvent('t1ger_chopshop:BrowseAvailableJobs', src, 0, selectedGrade.grade, veh)
    notify(src, Lang['paid_for_job']:format(jobFee, selectedGrade.label), 'success')
end)

function GetCopsCount()
    local cops = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        for _, jobName in pairs(Config.ChopShop.Police.jobs) do
            if player.PlayerData.job and player.PlayerData.job.name == jobName and (player.PlayerData.job.onduty ~= false) then
                cops = cops + 1
                break
            end
        end
    end
    return cops
end

RegisterNetEvent('t1ger_chopshop:syncDataSV', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    if not rateLimit(src, 'syncData', 1000) then return end
    if not activeThiefJobs[src] then return end
    if type(data) ~= 'table' then return end

    for id, job in pairs(Config.ThiefJobs) do
        local incoming = data[id]
        if type(incoming) == 'table' then
            job.inUse = incoming.inUse == true
            job.goons_spawned = incoming.goons_spawned == true
            job.veh_spawned = incoming.veh_spawned == true
            job.player = incoming.player == true
        end
    end

    TriggerClientEvent('t1ger_chopshop:syncDataCL', -1, Config.ThiefJobs)
end)

RegisterNetEvent('t1ger_chopshop:JobCompleteSV', function(payout, percent)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local jobData = activeThiefJobs[src]
    if not jobData then
        return
    end

    percent = tonumber(percent) or 0
    percent = math.min(math.max(percent, 0), 100)

    local basePayout = jobData.payout or payout or 0
    local money = math.floor(basePayout * (percent / 100))
    local cfg = Config.ChopShop.Settings.thiefjob

    if money > 0 then
        addMoney(player, money, cfg.dirty, 't1ger-chopshop-thief')
    end

    if cfg.items.enable then
        local delivered = 0
        for _, item in pairs(Config.Materials) do
            if delivered >= cfg.items.maxItems then break end
            if math.random(0, 100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                if player.Functions.AddItem(item.item, amount) then
                    delivered = delivered + 1
                end
                Wait(50)
            end
        end
    end

    if Config.ChopShop.Settings.cooldown.thiefjob.enable then
        addCooldown(src, 'thief')
    end

    notify(src, Lang['reward_msg']:format(money), 'success')
    activeThiefJobs[src] = nil
end)

RegisterNetEvent('t1ger_chopshop:PoliceNotifySV', function(targetCoords, streetName)
    TriggerClientEvent('t1ger_chopshop:PoliceNotifyCL', -1, (Lang['police_notify']):format(streetName))
    TriggerClientEvent('t1ger_chopshop:PoliceNotifyBlip', -1, targetCoords)
end)
