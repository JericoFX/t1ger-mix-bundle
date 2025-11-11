local QBCore = exports['qb-core']:GetCoreObject()
local onlineCops = 0
local alertTime = 0
local copJobs = {}
local useOxInventory = GetResourceState('ox_inventory') == 'started'

local function serialiseBankState(id)
    local bank = Config.Banks[id]
    if not bank then return nil end

    local state = {
        inUse = bank.inUse or false,
        keypads = {},
        doors = {},
        safes = {},
        pettyCash = {},
    }

    if bank.powerBox then
        state.powerBox = { disabled = bank.powerBox.disabled or false }
    end

    if bank.crackSafe then
        state.crackSafe = {
            cracked = bank.crackSafe.cracked or false,
            rewarded = bank.crackSafe.rewarded or false,
        }
    end

    for key, keypad in pairs(bank.keypads or {}) do
        state.keypads[key] = { hacked = keypad.hacked or false }
    end

    for key, door in pairs(bank.doors or {}) do
        state.doors[key] = {
            freeze = door.freeze ~= false,
            setHeading = door.setHeading or door.heading,
        }
    end

    for key, safe in pairs(bank.safes or {}) do
        state.safes[key] = {
            robbed = safe.robbed or false,
            failed = safe.failed or false,
            rewarded = safe.rewarded or false,
        }
    end

    for key, petty in pairs(bank.pettyCash or {}) do
        state.pettyCash[key] = {
            robbed = petty.robbed or false,
            paid = petty.paid or false,
        }
    end

    return state
end

local function setBankState(id)
    local state = serialiseBankState(id)
    if not state then return end
    GlobalState[('t1ger_bankrobbery:%s'):format(id)] = state
end

local function refreshAllBankStates()
    for id = 1, #Config.Banks do
        setBankState(id)
    end
end

local function updateOnlineCopsState()
    GlobalState['t1ger_bankrobbery:onlineCops'] = onlineCops
end

for _, job in ipairs(Config.PoliceJobs) do
    copJobs[job] = true
end

local function isPolice(player)
    if not player then return false end
    local job = player.PlayerData.job
    if not job then return false end
    if not copJobs[job.name] then return false end
    if job.onduty == nil then return true end
    return job.onduty
end

local function getBank(id)
    id = tonumber(id)
    if not id then return nil end
    local bank = Config.Banks[id]
    if not bank then
        print(('[t1ger_bankrobbery] invalid bank id %s received'):format(id))
    end
    return bank
end

local function getItemLabel(item)
    local itemData = QBCore.Shared.Items[item]
    if itemData then
        return itemData.label or itemData.description or itemData.name
    end
    return item
end

local function getItemCount(player, item)
    if useOxInventory then
        local count = exports.ox_inventory:GetItemCount(player.PlayerData.source, item, nil, true)
        local label = exports.ox_inventory:Items(item) and exports.ox_inventory:Items(item).label or getItemLabel(item)
        return count, label
    end

    local invItem = player.Functions.GetItemByName(item)
    if invItem then
        local count = invItem.amount or invItem.count or invItem.quantity or 0
        local label = invItem.label or getItemLabel(item)
        return count, label
    end

    return 0, getItemLabel(item)
end

local function removeItem(player, item, amount)
    if useOxInventory then
        return exports.ox_inventory:RemoveItem(player.PlayerData.source, item, amount, nil, nil, false)
    end
    return player.Functions.RemoveItem(item, amount)
end

local function addItem(player, item, amount, metadata)
    if useOxInventory then
        return exports.ox_inventory:AddItem(player.PlayerData.source, item, amount, metadata)
    end
    return player.Functions.AddItem(item, amount, false, metadata)
end

local function giveMoney(player, amount, dirty)
    if dirty and Config.DirtyMoneyItem then
        local metadata = nil
        if type(Config.DirtyMoneyMetadataKey) == 'string' then
            metadata = {[Config.DirtyMoneyMetadataKey] = amount}
        end
        if not addItem(player, Config.DirtyMoneyItem, 1, metadata) then
            player.Functions.AddMoney('cash', amount, 'bankrobbery-fallback')
        end
    else
        player.Functions.AddMoney('cash', amount, dirty and 'bankrobbery-dirty' or 'bankrobbery')
    end
end

local function notifyPlayer(player, message, type)
    TriggerClientEvent('t1ger_bankrobbery:notify', player.PlayerData.source, message, type)
end

local function getDutyCount(job)
    if QBCore.Functions.GetDutyCount then
        local count = QBCore.Functions.GetDutyCount(job)
        return count or 0
    end

    local _, count = QBCore.Functions.GetPlayersByJob(job, true)
    return count or 0
end

local function getOnlinePoliceCount()
    local count = 0
    for jobName in pairs(copJobs) do
        count += getDutyCount(jobName)
    end
    return count
end

local function refreshOnlinePolice()
    local count = getOnlinePoliceCount()
    if count ~= onlineCops then
        onlineCops = count
        updateOnlineCopsState()
    end
end

CreateThread(function()
    Wait(1000)
    refreshAllBankStates()
    refreshOnlinePolice()
    print('^2[T1GER Bank Robbery]^0 Initialized')
end)

local function resolvePlayerFromEvent(data)
    if type(data) == 'table' and data.PlayerData then
        return data
    end
    local src = tonumber(data) or source
    if not src then return nil end
    return QBCore.Functions.GetPlayer(src)
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
    if not resolvePlayerFromEvent(player) then return end
    refreshOnlinePolice()
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if not resolvePlayerFromEvent(src) then return end
    refreshOnlinePolice()
end)

AddEventHandler('playerDropped', function()
    refreshOnlinePolice()
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(player, job)
    local qbPlayer = resolvePlayerFromEvent(player)
    if not qbPlayer then return end
    qbPlayer.PlayerData.job = job or (qbPlayer.PlayerData and qbPlayer.PlayerData.job)
    refreshOnlinePolice()
end)

AddEventHandler('QBCore:Server:SetPlayerJob', function(player, job)
    local qbPlayer = resolvePlayerFromEvent(player)
    if not qbPlayer then return end
    qbPlayer.PlayerData.job = job or (qbPlayer.PlayerData and qbPlayer.PlayerData.job)
    refreshOnlinePolice()
end)

RegisterNetEvent('t1ger_bankrobbery:inUseSV', function(id, state)
    local bank = getBank(id)
    if not bank then return end
    bank.inUse = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:keypadHackedSV', function(id, num, state)
    local bank = getBank(id)
    if not bank then return end
    if not bank.keypads[num] then return end
    bank.keypads[num].hacked = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:doorFreezeSV', function(id, num, state)
    local bank = getBank(id)
    if not bank then return end
    if not bank.doors[num] then return end
    bank.doors[num].freeze = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:safeRobbedSV', function(id, num, state)
    local bank = getBank(id)
    if not bank then return end
    if not bank.safes[num] then return end
    bank.safes[num].robbed = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:safeFailedSV', function(id, num, state)
    local bank = getBank(id)
    if not bank then return end
    if not bank.safes[num] then return end
    bank.safes[num].failed = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:powerBoxDisabledSV', function(id, state)
    local bank = getBank(id)
    if not bank or not bank.powerBox then return end
    bank.powerBox.disabled = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:pettyCashRobbedSV', function(id, num, state)
    local bank = getBank(id)
    if not bank then return end
    local petty = bank.pettyCash[num]
    if not petty then return end
    petty.robbed = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:safeCrackedSV', function(id, state)
    local bank = getBank(id)
    if not bank or not bank.crackSafe then return end
    bank.crackSafe.cracked = state
    setBankState(id)
end)

RegisterNetEvent('t1ger_bankrobbery:openVaultSV', function(open, id)
    TriggerClientEvent('t1ger_bankrobbery:openVaultCL', -1, open, id)
end)

RegisterNetEvent('t1ger_bankrobbery:setHeadingSV', function(id, type, heading)
    local bank = getBank(id)
    if not bank or not bank.doors[type] then return end
    bank.doors[type].setHeading = heading
    setBankState(id)
    TriggerClientEvent('t1ger_bankrobbery:setHeadingCL', -1, id, type, heading)
end)

RegisterNetEvent('t1ger_bankrobbery:particleFxSV', function(pos, dict, lib)
    TriggerClientEvent('t1ger_bankrobbery:particleFxCL', -1, pos, dict, lib)
end)

RegisterNetEvent('t1ger_bankrobbery:modelSwapSV', function(pos, radius, oldModel, newModel)
    TriggerClientEvent('t1ger_bankrobbery:modelSwapCL', -1, pos, radius, oldModel, newModel)
end)

lib.callback.register('t1ger_bankrobbery:getInventoryItem', function(source, item, amount)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false, getItemLabel(item) end
    local count, label = getItemCount(player, item)
    return count >= amount, label
end)

RegisterNetEvent('t1ger_bankrobbery:removeRequiredItems', function(bankId, action)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local bank = getBank(bankId)
    if not player or not bank then return end
    local requirements = bank.reqItems[action]
    if not requirements then return end

    for _, data in ipairs(requirements) do
        if data.remove then
            if math.random(0, 100) <= data.chance then
                removeItem(player, data.name, data.amount)
            end
        end
    end
end)

RegisterNetEvent('t1ger_bankrobbery:safeReward', function(id, num)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local bank = getBank(id)
    if not player or not bank then return end
    local safe = bank.safes[tonumber(num)]
    if not safe then return end
    if not safe.robbed or safe.failed then return end
    if safe.rewarded then
        print(('[t1ger_bankrobbery] %s attempted duplicate safe reward'):format(src))
        return
    end
    safe.rewarded = true
    setBankState(id)

    if safe.cash and safe.cash.enable then
        local amount = math.random(safe.cash.min, safe.cash.max)
        giveMoney(player, amount, Config.CashInDirty)
        notifyPlayer(player, Lang['cash_reward']:format(amount), 'success')
    end

    if safe.items then
        for _, item in pairs(safe.items) do
            if math.random(0, 100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                if addItem(player, item.name, amount) then
                    notifyPlayer(player, Lang['item_reward']:format(amount, getItemLabel(item.name)), 'success')
                end
            end
        end
    end
end)

RegisterNetEvent('t1ger_bankrobbery:crackSafeReward', function(id)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local bank = getBank(id)
    if not player or not bank or not bank.crackSafe then return end
    local data = bank.crackSafe
    if not data.cracked or data.rewarded then return end
    data.rewarded = true
    setBankState(id)

    if data.reward.cash and data.reward.cash.enable then
        local amount = math.random(data.reward.cash.min, data.reward.cash.max)
        giveMoney(player, amount, Config.CashInDirty)
        notifyPlayer(player, Lang['cash_reward']:format(amount), 'success')
    end

    if data.reward.items then
        for _, item in pairs(data.reward.items) do
            if math.random(0, 100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                if addItem(player, item.name, amount) then
                    notifyPlayer(player, Lang['item_reward']:format(amount, getItemLabel(item.name)), 'success')
                end
            end
        end
    end
end)

RegisterNetEvent('t1ger_bankrobbery:pettyCashReward', function(id, num)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local bank = getBank(id)
    if not player or not bank then return end
    local petty = bank.pettyCash[tonumber(num)]
    if not petty or petty.robbed == nil then return end
    if petty.paid then return end
    petty.paid = true
    setBankState(id)

    local cfg = petty.reward
    local amount = math.random(cfg.min, cfg.max)
    giveMoney(player, amount, cfg.dirty)
    notifyPlayer(player, Lang['cash_reward']:format(amount), 'success')
end)

RegisterNetEvent('t1ger_bankrobbery:syncPowerBoxSV', function(timer)
    alertTime = timer
    TriggerClientEvent('t1ger_bankrobbery:syncPowerBoxCL', -1, alertTime)
end)

RegisterNetEvent('t1ger_bankrobbery:sendPoliceAlertSV', function(coords, message)
    TriggerClientEvent('t1ger_bankrobbery:sendPoliceAlertCL', -1, coords, message)
end)

RegisterNetEvent('t1ger_bankrobbery:ResetCurrentBankSV', function(id)
    local bank = getBank(id)
    if not bank then return end
    bank.inUse = false
    for _, keypad in pairs(bank.keypads) do
        keypad.hacked = false
    end
    for doorId, door in pairs(bank.doors) do
        door.freeze = true
        door.setHeading = door.heading
        if doorId == 'cell' or doorId == 'cell2' then
            TriggerClientEvent('t1ger_bankrobbery:modelSwapCL', -1, door.pos, 5.0, GetHashKey('hei_v_ilev_bk_safegate_molten'), door.model)
        end
    end
    for _, safe in pairs(bank.safes) do
        safe.robbed = false
        safe.failed = false
        safe.rewarded = nil
    end
    for _, petty in pairs(bank.pettyCash) do
        petty.robbed = false
        petty.paid = nil
    end
    if bank.powerBox then
        bank.powerBox.disabled = false
    end
    if bank.crackSafe then
        bank.crackSafe.cracked = false
        bank.crackSafe.rewarded = nil
    end
    alertTime = 0
    setBankState(id)

    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        if isPolice(player) then
            TriggerClientEvent('chatMessage', player.PlayerData.source, '^2News: | ^7', {128, 128, 128}, 'The bank has been secured. All banks are now open again!')
        end
    end
end)
