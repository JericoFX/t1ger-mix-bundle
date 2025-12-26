-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local heistState = {
        cooldown = false,
        terminal = { activated = false },
        keypad = { hacked = false },
        trolley = { grabbing = false, taken = false },
        safes = {}
}

for i = 1, #Config.Safes do
        heistState.safes[i] = { robbed = false, failed = false, rewarded = false }
end

local participants = {}
local cooldown = { active = false, timer = 0 }
local useOxInventory = GetResourceState('ox_inventory') == 'started'
local pendingDrillRefund = {}
local actionRateLimits = {}

local function rateLimit(src, key, cooldownMs)
        local now = GetGameTimer()
        actionRateLimits[src] = actionRateLimits[src] or {}
        local last = actionRateLimits[src][key] or 0
        if now - last < cooldownMs then
                return false
        end
        actionRateLimits[src][key] = now
        return true
end

local function syncState(target)
        if target then
                TriggerClientEvent('t1ger_yachtheist:updateState', target, heistState)
        else
                TriggerClientEvent('t1ger_yachtheist:updateState', -1, heistState)
        end
end

local function resetSafes()
        for i = 1, #heistState.safes do
                heistState.safes[i].robbed = false
                heistState.safes[i].failed = false
                heistState.safes[i].rewarded = false
        end
end

local function resetHeist()
        heistState.terminal.activated = false
        heistState.keypad.hacked = false
        heistState.trolley.grabbing = false
        heistState.trolley.taken = false
        resetSafes()
        participants = {}
        pendingDrillRefund = {}
end

local function isParticipant(source)
        return participants[source] == true
end

local function registerParticipant(source)
        participants[source] = true
end

local function startCooldown()
        heistState.cooldown = true
        cooldown.active = true
        cooldown.timer = Config.CooldownTimer * 60000
end

local function stopCooldown()
        heistState.cooldown = false
        cooldown.active = false
        cooldown.timer = 0
end

CreateThread(function()
        while true do
                Wait(1000)
                if cooldown.active then
                        if cooldown.timer <= 0 then
                                stopCooldown()
                                syncState()
                        else
                                cooldown.timer = cooldown.timer - 1000
                        end
                else
                        Wait(4000)
                end
        end
end)

AddEventHandler('playerDropped', function()
        participants[source] = nil
end)

local function playerHasJob(source, jobs)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return false end
        for _, job in ipairs(jobs) do
                if xPlayer.PlayerData.job and xPlayer.PlayerData.job.name == job then
                        if xPlayer.PlayerData.job.onduty == false then
                                return false
                        end
                        return true
                end
        end
        return false
end

local function addDirtyMoney(src, amount)
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        if useOxInventory then
                exports.ox_inventory:AddItem(src, 'black_money', amount, false, false, false)
        else
                player.Functions.AddMoney('cash', amount, 't1ger_yachtheist_dirty')
        end
end

lib.callback.register('t1ger_yachtheist:getState', function(source)
        return heistState
end)

lib.callback.register('t1ger_yachtheist:startHeist', function(source)
        if heistState.cooldown then
                return { success = false, reason = Lang['yacht_cooldown'] }
        end
        if heistState.terminal.activated then
                return { success = false, reason = Lang['yacht_activated'] }
        end
        local cops = 0
        for _, job in ipairs(Config.PoliceSettings.jobs) do
                local playersOnDuty = QBCore.Functions.GetPlayersOnDuty(job)
                if type(playersOnDuty) == 'table' then
                        cops = cops + #playersOnDuty
                end
        end
        if cops < Config.PoliceSettings.requiredCops then
                return { success = false, reason = Lang['not_enough_cops'] }
        end
        heistState.terminal.activated = true
        heistState.keypad.hacked = false
        heistState.trolley.grabbing = false
        heistState.trolley.taken = false
        resetSafes()
        registerParticipant(source)
        syncState()
        return { success = true }
end)

lib.callback.register('t1ger_yachtheist:canHack', function(source, itemName)
        if not heistState.terminal.activated then
                return { success = false, reason = Lang['yacht_cooldown'] }
        end
        if heistState.keypad.hacked then
                return { success = false, reason = Lang['yacht_activated'] }
        end
        local player = QBCore.Functions.GetPlayer(source)
        if not player then
                return { success = false, reason = Lang['need_hacker_item'] }
        end
        registerParticipant(source)
        local item = player.Functions.GetItemByName(itemName)
        if item and item.amount and item.amount > 0 then
                return { success = true }
        end
        return { success = false, reason = Lang['need_hacker_item'] }
end)

lib.callback.register('t1ger_yachtheist:consumeItem', function(source, itemName, amount)
        amount = amount or 1
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        local item = player.Functions.GetItemByName(itemName)
        if item and item.amount and item.amount >= amount then
                player.Functions.RemoveItem(itemName, amount)
                return true
        end
        return false
end)

lib.callback.register('t1ger_yachtheist:addGrabbedCash', function(source)
        if not heistState.terminal.activated or heistState.trolley.taken then
                return 0
        end
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return 0 end
        registerParticipant(source)
        local cfg = Config.VaultRewards.trolley
        local amount = math.random(cfg.min, cfg.max)
        if cfg.dirtyCash then
                addDirtyMoney(source, amount)
        else
                player.Functions.AddMoney('cash', amount, 't1ger_yachtheist_trolley')
        end
        return amount
end)

RegisterNetEvent('t1ger_yachtheist:setKeypadState', function(state)
        local src = source
        if not heistState.terminal.activated then return end
        if not isParticipant(src) then return end
        if not rateLimit(src, 'keypad', 750) then return end
        if state ~= true or heistState.keypad.hacked then return end
        heistState.keypad.hacked = state and true or false
        registerParticipant(src)
        syncState()
end)

RegisterNetEvent('t1ger_yachtheist:setTrolleyState', function(field, value)
        if field ~= 'grabbing' and field ~= 'taken' then return end
        if not heistState.terminal.activated then return end
        if not isParticipant(source) then return end
        if not rateLimit(source, 'trolley', 750) then return end
        heistState.trolley[field] = value and true or false
        registerParticipant(source)
        syncState()
end)

RegisterNetEvent('t1ger_yachtheist:SafeDataSV', function(type, id, state)
        local src = source
        local safe = heistState.safes[id]
        if not safe then return end
        if not isParticipant(src) then return end
        if not rateLimit(src, ('safe:%s'):format(id), 750) then return end
        if type == 'robbed' and not safe.robbed then
                if state ~= true then return end
                safe.robbed = state and true or false
                safe.rewarded = false
                registerParticipant(src)
                TriggerClientEvent('t1ger_yachtheist:SafeDataCL', -1, 'robbed', id, safe.robbed)
                syncState()
        elseif type == 'failed' and not safe.failed then
                if state ~= true then return end
                safe.failed = state and true or false
                pendingDrillRefund[src] = true
                TriggerClientEvent('t1ger_yachtheist:SafeDataCL', -1, 'failed', id, safe.failed)
                syncState()
        end
end)

RegisterNetEvent('t1ger_yachtheist:vaultReward', function(id)
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return end
        if not isParticipant(src) then return end
        if not rateLimit(src, 'vaultReward', 1000) then return end
        local safe = heistState.safes[id]
        if not safe or not safe.robbed or safe.rewarded then return end
        registerParticipant(src)
        safe.rewarded = true
        local cfg = Config.VaultRewards
        local amount = math.random(cfg.money.min, cfg.money.max) * 1000
        if cfg.money.dirtyCash then
                addDirtyMoney(src, amount)
        else
                player.Functions.AddMoney('cash', amount, 't1ger_yachtheist_safe')
        end
        TriggerClientEvent('t1ger_yachtheist:client:notify', src, (Lang['safe_money_reward']):format(amount), 'success')
        for _, v in pairs(cfg.items) do
                if math.random(0, 100) <= v.chance then
                        local count = math.random(v.min, v.max)
                        player.Functions.AddItem(v.item, count)
                        local itemInfo = QBCore.Shared.Items[v.item:lower()] or QBCore.Shared.Items[v.item]
                        local label = itemInfo and itemInfo.label or v.item
                        TriggerClientEvent('t1ger_yachtheist:client:notify', src, (Lang['safe_item_reward']):format(count, label), 'success')
                end
        end
end)

RegisterNetEvent('t1ger_yachtheist:giveItem', function(item, amount)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return end
        if not isParticipant(source) then return end
        if not rateLimit(source, 'giveItem', 1000) then return end
        local expectedItem = Config.DatabaseItems and Config.DatabaseItems['drill']
        if item ~= expectedItem or (amount or 1) ~= 1 then return end
        if not pendingDrillRefund[source] then return end
        pendingDrillRefund[source] = nil
        player.Functions.AddItem(item, 1)
end)

RegisterNetEvent('t1ger_yachtheist:resetHeistSV', function()
        local src = source
        local allowed = playerHasJob(src, Config.PoliceSettings.jobs) or isParticipant(src)
        if not allowed then return end
        resetHeist()
        startCooldown()
        syncState()
        TriggerClientEvent('t1ger_yachtheist:resetHeistCL', -1)
end)

RegisterNetEvent('t1ger_yachtheist:forceDeleteSV', function(objNet)
        TriggerClientEvent('t1ger_yachtheist:forceDeleteCL', -1, objNet)
end)

RegisterNetEvent('t1ger_yachtheist:PoliceNotifySV', function(type)
        if not Config.PoliceSettings.enableAlert then return end
        if not isParticipant(source) and not playerHasJob(source, Config.PoliceSettings.jobs) then return end
        if type == 'alert' then
                TriggerClientEvent('t1ger_yachtheist:PoliceNotifyCL', -1, Lang['police_notify'])
        elseif type == 'secure' then
                TriggerClientEvent('t1ger_yachtheist:PoliceNotifyCL', -1, Lang['police_notify_2'])
        end
end)
