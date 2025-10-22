-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
local cfg = Config.TruckRobbery

local cooldowns = {}
local activeJobs = {}
local truckSpawns = {}

for index = 1, #Config.TruckSpawns do
    truckSpawns[index] = { inUse = false }
end

local function isPoliceJob(jobName)
    if not jobName then return false end
    for _, name in ipairs(cfg.police.jobs) do
        if name == jobName then
            return true
        end
    end
    return false
end

local function iteratePlayers(callback)
    if QBCore.Functions.GetQBPlayers then
        for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
            callback(player)
        end
    else
        for _, src in ipairs(QBCore.Functions.GetPlayers()) do
            local player = QBCore.Functions.GetPlayer(src)
            if player then
                callback(player)
            end
        end
    end
end

local function getDutyPolice()
    local total = 0
    iteratePlayers(function(player)
        local job = player.PlayerData.job
        if job and job.onduty and isPoliceJob(job.name) then
            total = total + 1
        end
    end)
    return total
end

local function getCooldownRemaining(citizenId)
    local expires = cooldowns[citizenId]
    if not expires then return 0 end
    local remaining = expires - os.time()
    if remaining <= 0 then
        cooldowns[citizenId] = nil
        return 0
    end
    return remaining
end

local function copySpawn(index)
    local spawn = Config.TruckSpawns[index]
    local data = {
        pos = { table.unpack(spawn.pos) },
        heading = spawn.heading,
        security = {}
    }
    if spawn.security then
        for i, guard in ipairs(spawn.security) do
            data.security[i] = {
                ped = guard.ped,
                seat = guard.seat,
                weapon = guard.weapon
            }
        end
    end
    return data
end

local function pickSpawn()
    local available = {}
    for index = 1, #Config.TruckSpawns do
        if not truckSpawns[index].inUse then
            available[#available + 1] = index
        end
    end
    if #available == 0 then return nil end
    return available[math.random(1, #available)]
end

lib.callback.register('t1ger_truckrobbery:requestJob', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return { success = false, reason = 'Player unavailable.' } end

    local citizenId = player.PlayerData.citizenid
    if activeJobs[citizenId] then
        return { success = false, reason = Lang.job_in_progress }
    end

    if isPoliceJob(player.PlayerData.job and player.PlayerData.job.name) then
        return { success = false, reason = Lang.not_for_police }
    end

    local cops = getDutyPolice()
    if cops < cfg.police.minCops then
        return { success = false, reason = Lang.not_enough_police }
    end

    local remaining = getCooldownRemaining(citizenId)
    if remaining > 0 then
        local minutes = math.ceil(remaining / 60)
        return { success = false, reason = Lang.cooldown_time_left:format(minutes) }
    end

    local fees = cfg.computer.fees
    local account = fees.account == 'cash' and 'cash' or 'bank'
    local balance = player.Functions.GetMoney(account)
    if balance < fees.amount then
        return { success = false, reason = Lang.not_enough_money }
    end

    local index = pickSpawn()
    if not index then
        return { success = false, reason = Lang.no_available_jobs }
    end

    truckSpawns[index].inUse = true
    player.Functions.RemoveMoney(account, fees.amount, 'truck-robbery-fee')

    local jobId = string.format('%s:%d:%d', citizenId, index, os.time())
    activeJobs[citizenId] = {
        id = jobId,
        index = index,
        stage = 'assigned',
        started = os.time()
    }

    cooldowns[citizenId] = os.time() + (cfg.cooldown * 60)

    local spawn = copySpawn(index)

    return {
        success = true,
        job = {
            id = jobId,
            index = index,
            spawn = spawn
        }
    }
end)

RegisterNetEvent('t1ger_truckrobbery:updateStage', function(jobId, stage)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local job = activeJobs[citizenId]
    if not job or job.id ~= jobId then return end

    job.stage = stage
end)

lib.callback.register('t1ger_truckrobbery:claimReward', function(source, jobId, index)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return { success = false, message = 'Player unavailable.' }
    end

    local citizenId = player.PlayerData.citizenid
    local job = activeJobs[citizenId]
    if not job or job.id ~= jobId or job.index ~= index then
        return { success = false, message = Lang.job_not_active }
    end

    if job.stage ~= 'truck_opened' then
        return { success = false, message = Lang.truck_not_breached }
    end

    local rewardCfg = cfg.reward
    local payout = math.random(rewardCfg.money.min, rewardCfg.money.max)

    if rewardCfg.money.dirty then
        exports.ox_inventory:AddItem(source, 'black_money', payout, { description = 'Truck Robbery' })
    else
        player.Functions.AddMoney('cash', payout, 'truck-robbery')
    end

    local itemMessages = {}
    if rewardCfg.items.enable and rewardCfg.items.list then
        for _, entry in ipairs(rewardCfg.items.list) do
            local chance = entry.chance or 0
            if math.random(100) <= chance then
                local amount = math.random(entry.min or 1, entry.max or 1)
                local success = exports.ox_inventory:AddItem(source, entry.item, amount)
                if success then
                    itemMessages[#itemMessages + 1] = Lang.you_received_item:format(amount, entry.item)
                end
            end
        end
    end

    activeJobs[citizenId] = nil
    if truckSpawns[job.index] then
        truckSpawns[job.index].inUse = false
    end

    return {
        success = true,
        message = Lang.reward_notify:format(payout),
        items = itemMessages
    }
end)

RegisterNetEvent('t1ger_truckrobbery:releaseJob', function(jobId, index, aborted)
    local source = source
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local job = activeJobs[citizenId]
    if not job or job.id ~= jobId then
        if index and truckSpawns[index] then
            truckSpawns[index].inUse = false
        end
        return
    end

    if truckSpawns[job.index] then
        truckSpawns[job.index].inUse = false
    end

    if aborted then
        cooldowns[citizenId] = os.time() + (cfg.cooldown * 60)
    end

    activeJobs[citizenId] = nil
end)

RegisterNetEvent('t1ger_truckrobbery:PoliceNotifySV', function(targetCoords, street)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local job = activeJobs[player.PlayerData.citizenid]
    if not job then return end

    TriggerClientEvent('t1ger_truckrobbery:PoliceNotifyCL', -1, Lang.police_notify:format(street))
    TriggerClientEvent('t1ger_truckrobbery:PoliceNotifyBlip', -1, targetCoords)
end)
