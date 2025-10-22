-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports['qb-core']:GetCoreObject()
local jobTimeouts = {}

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

function SyncJobState(type, num)
    TriggerClientEvent('t1ger_heistpreps:sendConfigCL', -1, type, num, Config.Jobs[type][num])
end

function SyncJobCache(type, num)
    TriggerClientEvent('t1ger_heistpreps:sendCacheCL', -1, Config.Jobs[type][num].cache, type, num)
end

function markJobActive(jobType, jobId)
    jobTimeouts[jobType] = jobTimeouts[jobType] or {}
    jobTimeouts[jobType][jobId] = os.time()
end

local function clearJobActive(jobType, jobId)
    if jobTimeouts[jobType] then
        jobTimeouts[jobType][jobId] = nil
    end
end

function ResetJob(jobType, jobId, reason)
    local job = Config.Jobs[jobType] and Config.Jobs[jobType][jobId]
    if not job then return end

    job.inUse = false
    job.cache = {}

    if jobType == 'drills' then
        for _, crate in pairs(job.crates) do
            if crate.netId then
                local entity = NetworkGetEntityFromNetworkId(crate.netId)
                if entity and DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
            end
            crate.netId = nil
            crate.searched = false
            crate.loot = false
            if crate.npc then
                for i = 1, #crate.npc do
                    if crate.npc[i] then
                        if crate.npc[i].netId then
                            local npcEntity = NetworkGetEntityFromNetworkId(crate.npc[i].netId)
                            if npcEntity and DoesEntityExist(npcEntity) then
                                DeleteEntity(npcEntity)
                            end
                        end
                        crate.npc[i].netId = nil
                    end
                end
            end
        end
        TriggerClientEvent('t1ger_heistpreps:drills:resetCurJob', -1, jobType, jobId)
        TriggerClientEvent('t1ger_heistpreps:drills:resetCurJob2', -1, jobId)
    elseif jobType == 'hacking' then
        job.cache = {}
    elseif jobType == 'thermite' then
        if job.cache then
            if job.cache.netId then
                local vehicle = NetworkGetEntityFromNetworkId(job.cache.netId)
                if vehicle and DoesEntityExist(vehicle) then
                    DeleteEntity(vehicle)
                end
            end
            if job.cache.agents then
                for _, agentId in pairs(job.cache.agents) do
                    local ped = NetworkGetEntityFromNetworkId(agentId)
                    if ped and DoesEntityExist(ped) then
                        DeleteEntity(ped)
                    end
                end
            end
        end
        TriggerClientEvent('t1ger_heistpreps:thermite:resetCL', -1, jobType, jobId)
    elseif jobType == 'explosives' then
        if job.cache and job.cache.netId then
            local prop = NetworkGetEntityFromNetworkId(job.cache.netId)
            if prop and DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
        TriggerClientEvent('t1ger_heistpreps:explosives:reset', -1, jobType, jobId)
    elseif jobType == 'keycard' then
        if job.cache and job.cache.netId then
            local ped = NetworkGetEntityFromNetworkId(job.cache.netId)
            if ped and DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
        for _, spawn in pairs(job.spawns) do
            if spawn.netId then
                local veh = NetworkGetEntityFromNetworkId(spawn.netId)
                if veh and DoesEntityExist(veh) then
                    DeleteEntity(veh)
                end
            end
            spawn.netId = nil
            spawn.searched = false
            spawn.loot = false
        end
        TriggerClientEvent('t1ger_heistpreps:keycard:resetCurJob', -1, jobType, jobId)
        TriggerClientEvent('t1ger_heistpreps:keycard:resetCurJob2', -1, jobId)
    end

    clearJobActive(jobType, jobId)
    SyncJobState(jobType, jobId)
    SyncJobCache(jobType, jobId)

    if reason == 'timeout' then
        print(('[t1ger_heistpreps] Reset %s prep %s due to timeout'):format(jobType, jobId))
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        if (Config.JobTimeout or 0) <= 0 then
            goto continue
        end
        local now = os.time()
        for jobType, jobs in pairs(jobTimeouts) do
            for jobId, started in pairs(jobs) do
                if Config.Jobs[jobType] and Config.Jobs[jobType][jobId] and Config.Jobs[jobType][jobId].inUse then
                    if now - started >= (Config.JobTimeout * 60) then
                        ResetJob(jobType, jobId, 'timeout')
                    end
                else
                    clearJobActive(jobType, jobId)
                end
            end
        end
        ::continue::
    end
end)

-- ## HACKING DEVICE PREPARATION JOB ## --

RegisterServerEvent('t1ger_heistpreps:hacking:startDecryption')
AddEventHandler('t1ger_heistpreps:hacking:startDecryption', function(type, num, coords)
    local player = getPlayer(source)
    if not player then return end
    Config.Jobs[type][num].cache.decryption = {
        timer = Config.Jobs[type][num].decrypt.time * 60000,
        player = source,
        notifyPolice = false,
        done = false,
        collected = false
    }
    markJobActive(type, num)
    SyncJobCache(type, num)
    local alertMSG = Lang['hack_police_alert']
    AlertCops(alertMSG, coords)
end)

RegisterServerEvent('t1ger_heistpreps:hacking:collected')
AddEventHandler('t1ger_heistpreps:hacking:collected', function(type, num)
    local player = getPlayer(source)
    if not player then return end
    if Config.Jobs[type][num].cache.decryption.collected == false then
        Config.Jobs[type][num].cache.decryption.collected = true
        Wait(1000)
        TriggerEvent('t1ger_heistpreps:giveItem', Config.Jobs[type][num].item[2].name, Config.Jobs[type][num].item[2].amount, player.PlayerData.source)
        TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['got_decrypted_device'])
        ResetJob(type, num)
    else
        TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['device_already_collect'], 'error')
    end
end)

CreateThread(function()
        while true do
        Wait(1000)
        for k,v in pairs(Config.Jobs['hacking']) do
            if next(v.cache) and (v.cache.decryption ~= nil and next(v.cache.decryption)) then
                if v.cache.decryption.done == false then
                    if v.cache.decryption.notifyPolice == false then
                        v.cache.decryption.notifyPolice = true
                    end
                    if v.cache.decryption.timer <= 0 then
                        DecryptionComplete('hacking', k)
                    else
                        v.cache.decryption.timer = v.cache.decryption.timer - 1000
                    end
                end
            end
        end
        end
end)

function DecryptionComplete(type, id)
    local player = getPlayer(Config.Jobs[type][id].cache.decryption.player)
    if player then
        local sender, subject = 'Decryption Software', '~r~3ncrypt3d m3ss4g3~s~'
        local msg = '~b~Decyption Software Completed!~s~\n\nGrab the ~y~device~s~ and yeet!'
        local textureDict, iconType = 'CHAR_LESTER_DEATHWISH', 7
        TriggerClientEvent('t1ger_heistpreps:notifyAdvanced', player.PlayerData.source, sender, subject, msg, textureDict, iconType)
        Config.Jobs[type][id].cache.decryption.done = true
        SyncJobCache(type, id)
    end
end

function AlertCops(alertMSG, coords)
    local players = QBCore.Functions.GetQBPlayers()
    for _, qbPlayer in pairs(players) do
        local jobName = qbPlayer.PlayerData.job and qbPlayer.PlayerData.job.name or ''
        if CanReceiveAlerts(jobName) then
            TriggerClientEvent('t1ger_heistpreps:notifyCops', qbPlayer.PlayerData.source, coords, alertMSG)
        end
    end
end

-- ## DRILLS PREPARATION JOB ## --

RegisterServerEvent('t1ger_heistpreps:drills:spawnCrates')
AddEventHandler('t1ger_heistpreps:drills:spawnCrates', function(type, num)
    local cfg = Config.Jobs[type][num]

    local scrambler, got = GetScrambledStuff(cfg.crates, cfg.lootableCrates)
    while not got do
        Wait(100)
    end

    for k,v in pairs(cfg.crates) do
        local crate, netId = T1GER_CreateServerObject(cfg.model, v.pos[1], v.pos[2], v.pos[3], 10000.0, true)
        Config.Jobs[type][num].crates[k].netId = netId
        Config.Jobs[type][num].crates[k].searched = false
        if scrambler[k] == k then
            Config.Jobs[type][num].crates[k].loot = true
        end
        for i = 1, #v.npc do
            local weapon = {name = v.npc[i].weapon, ammo = 255}
            local NPC, networkID = T1GER_CreateServerPed(4, v.npc[i].model, v.npc[i].pos[1], v.npc[i].pos[2], v.npc[i].pos[3], v.npc[i].pos[4], 10000.0, weapon)
            Config.Jobs[type][num].crates[k].npc[i].netId = networkID
        end
    end
    Config.Jobs[type][num].inUse = true
    markJobActive(type, num)
    SyncJobState(type, num)
end)

RegisterServerEvent('t1ger_heistpreps:drills:searched')
AddEventHandler('t1ger_heistpreps:drills:searched', function(type, num, index)
    local player = getPlayer(source)
    if not player then return end
    if Config.Jobs[type][num].crates[index].searched == true then
        return TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['drills_alrdy_searched'], 'error')
    end
    Config.Jobs[type][num].crates[index].searched = true
    if Config.Jobs[type][num].crates[index].loot == true then
        player.Functions.AddItem(Config.Jobs[type][num].item.name, Config.Jobs[type][num].item.amount)
        TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['you_found_a_drill'])
        local trueCounts = 0
        for k,v in pairs(Config.Jobs[type][num].crates) do
            if v.loot ~= nil and v.searched == true and v.loot == true then
                trueCounts = trueCounts + 1
            end
        end
        if trueCounts == Config.Jobs[type][num].lootableCrates then
            ResetJob(type, num)
        end
    else
        TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['you_found_nothing'])
    end
    SyncJobState(type, num)
end)

-- ## THERMAL CHARGES PREPARATION JOB ## --

RegisterServerEvent('t1ger_heistpreps:thermite:spawnConvoy')
AddEventHandler('t1ger_heistpreps:thermite:spawnConvoy', function(type, num)
    local cfg = Config.Jobs[type][num]
    local vehicle, netId = T1GER_CreateServerVehicle(cfg.vehicle, cfg.location.x, cfg.location.y, cfg.location.z, cfg.location.w, 100000.0, 'THERMITE', false, nil)
    Config.Jobs[type][num].inUse = true
    Config.Jobs[type][num].cache.type = type
    Config.Jobs[type][num].cache.num = num
    Config.Jobs[type][num].cache.started = true
    Config.Jobs[type][num].cache.netId = netId
    Config.Jobs[type][num].cache.agents = {}
    for i = 1, #cfg.agents do
        local agent, networkId = T1GER_CreateServerVehiclePed(vehicle, 6, cfg.agents[i].model, cfg.agents[i].seat, 100000.0)
        Config.Jobs[type][num].cache.agents[i] = networkId
    end
    markJobActive(type, num)
    SyncJobState(type, num)
end)

RegisterServerEvent('t1ger_heistpreps:thermite:searching')
AddEventHandler('t1ger_heistpreps:thermite:searching', function(type, num, state)
    local player = getPlayer(source)
    if not player then return end
    local desiredState = state ~= false
    if desiredState and Config.Jobs[type][num].cache.searching == true then
        return TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['convoy_alrdy_searched'], 'error')
    end
    Config.Jobs[type][num].cache.searching = desiredState
    SyncJobState(type, num)
end)

-- ## EXPLOSIVES PREPARATION JOB ## --

RegisterServerEvent('t1ger_heistpreps:explosives:spawnCase')
AddEventHandler('t1ger_heistpreps:explosives:spawnCase', function(type, num)
    local cfg = Config.Jobs[type][num]
    math.randomseed(GetGameTimer())
    local coords = cfg.spawn[math.random(1, #cfg.spawn)]
    local case, netId = T1GER_CreateServerObject(cfg.model, coords.x, coords.y, coords.z, 10000.0, false)
    print("case coords: ", coords)
    Config.Jobs[type][num].inUse = true
    Config.Jobs[type][num].cache.netId = netId
    Config.Jobs[type][num].cache.type = type
    Config.Jobs[type][num].cache.num = num
    Config.Jobs[type][num].cache.started = true
    markJobActive(type, num)
    SyncJobState(type, num)
end)

RegisterServerEvent('t1ger_heistpreps:explosives:collected')
AddEventHandler('t1ger_heistpreps:explosives:collected', function(type, num)
    local player = getPlayer(source)
    if not player then return end
    if Config.Jobs[type][num].cache.collected == true then
        return TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['case_already_collected'], 'error')
    else
        Config.Jobs[type][num].cache.collected = true
        SyncJobState(type, num)
    end
end)

RegisterServerEvent('t1ger_heistpreps:explosives:lockpicking')
AddEventHandler('t1ger_heistpreps:explosives:lockpicking', function(type, num, state)
    local player = getPlayer(source)
    if not player then return end
    if state == true and Config.Jobs[type][num].cache.lockpicking == true then
        return TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['case_being_unlocked'], 'error')
    else
        Config.Jobs[type][num].cache.lockpicking = state
        SyncJobState(type, num)
    end
end)

RegisterServerEvent('t1ger_heistpreps:explosives:unlocked')
AddEventHandler('t1ger_heistpreps:explosives:unlocked', function(type, num)
    local player = getPlayer(source)
    if not player then return end
    TriggerEvent('t1ger_heistpreps:giveItem', Config.Jobs[type][num].item.name, Config.Jobs[type][num].item.amount, player.PlayerData.source)
    ResetJob(type, num)
end)

-- ## KEYCARD PREPARATION JOB ## --

RegisterServerEvent('t1ger_heistpreps:keycard:searchedKeys')
AddEventHandler('t1ger_heistpreps:keycard:searchedKeys', function(type, num)
    local player = getPlayer(source)
    if not player then return end
    TriggerEvent('t1ger_heistpreps:giveItem', Config.Jobs[type][num].item[1].name, Config.Jobs[type][num].item[1].amount, player.PlayerData.source)
    Config.Jobs[type][num].cache.searchedKeys = true
    SyncJobState(type, num)
    TriggerEvent('t1ger_heistpreps:keycard:createTrucks', type, num, player.PlayerData.source)
end)

RegisterServerEvent('t1ger_heistpreps:keycard:truckSearched')
AddEventHandler('t1ger_heistpreps:keycard:truckSearched', function(type, num, id)
    local player = getPlayer(source)
    if not player then return end
    if Config.Jobs[type][num].spawns[id].searched == true then
        return TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['truck_already_searched'], 'error')
    else
        Config.Jobs[type][num].spawns[id].searched = true
        if Config.Jobs[type][num].spawns[id].loot == true then
            TriggerEvent('t1ger_heistpreps:giveItem', Config.Jobs[type][num].item[2].name, Config.Jobs[type][num].item[2].amount, player.PlayerData.source)
            TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['found_keycard_in_truck'])
            -- check if got all keycards:
            local trueCounts = 0
            for k,v in pairs(Config.Jobs[type][num].spawns) do
                if (v.loot ~= nil and v.loot == true) and v.searched == true then
                    trueCounts = trueCounts + 1
                end
            end
            if trueCounts == Config.Jobs[type][num].keycards then
                ResetJob(type, num)
            end
        else
            TriggerClientEvent('t1ger_heistpreps:notify', player.PlayerData.source, Lang['found_nothing_in_truck'])
        end
        SyncJobState(type, num)
    end
end)

RegisterServerEvent('t1ger_heistpreps:giveItem')
AddEventHandler('t1ger_heistpreps:giveItem', function(item, amount, target)
    local player = getPlayer(source) or getPlayer(target)
    if player then
        player.Functions.AddItem(item, amount)
    end
end)

RegisterServerEvent('t1ger_heistpreps:removeItem')
AddEventHandler('t1ger_heistpreps:removeItem', function(item, amount)
    local player = getPlayer(source)
    if player then
        player.Functions.RemoveItem(item, amount)
    end
end)

function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end
