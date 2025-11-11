-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local job_keys = {}
local keys_cache = {}

local function EnsureCache(citizenid)
        if not citizenid then return {} end
        keys_cache[citizenid] = keys_cache[citizenid] or {}
        return keys_cache[citizenid]
end

local function CacheHasPlate(citizenid, plate)
        local cache = EnsureCache(citizenid)
        local trimmed = T1GER_Trim(plate)
        for _, data in ipairs(cache) do
                if T1GER_Trim(data.plate) == trimmed then
                        return true
                end
        end
        return false
end

local function AddKeyToCache(citizenid, data)
        if not CacheHasPlate(citizenid, data.plate) then
                local cache = EnsureCache(citizenid)
                cache[#cache + 1] = data
                return true
        end
        return false
end

local function RemoveKeyFromCache(citizenid, plate)
        local cache = EnsureCache(citizenid)
        local trimmed = T1GER_Trim(plate)
        for i = #cache, 1, -1 do
                if T1GER_Trim(cache[i].plate) == trimmed then
                        table.remove(cache, i)
                        return true
                end
        end
        return false
end

local function PlayerOwnsVehicle(citizenid, plate)
        local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND (plate = ? OR plate = ?) LIMIT 1', {
                citizenid,
                plate,
                T1GER_Trim(plate)
        })
        return result ~= nil
end

local function PlayerHasRegisteredKey(citizenid, plate)
        local result = MySQL.scalar.await('SELECT t1ger_keys FROM player_vehicles WHERE citizenid = ? AND (plate = ? OR plate = ?)', {
                citizenid,
                plate,
                T1GER_Trim(plate)
        })
        return result ~= nil and result ~= 0
end

local function getDutyCount(jobName)
        if QBCore.Functions.GetDutyCount then
                local count = QBCore.Functions.GetDutyCount(jobName)
                return count or 0
        end

        local _, count = QBCore.Functions.GetPlayersByJob(jobName, true)
        return count or 0
end

local function countOnlineCops()
        local total = 0
        for _, jobName in pairs(Config.Police.Jobs) do
                total = total + getDutyCount(jobName)
        end
        return total
end

QBCore.Functions.CreateCallback('t1ger_keys:getOnlineCops', function(_, cb)
        cb(countOnlineCops())
end)

if lib and lib.callback and lib.callback.register then
        lib.callback.register('t1ger_keys:getOnlineCops', function()
                return countOnlineCops()
        end)
end

local function SyncPlayerKeys(src, citizenid)
        keys_cache[citizenid] = EnsureCache(citizenid)
        TriggerClientEvent('t1ger_keys:updateJobKeys', src, job_keys)
        TriggerClientEvent('t1ger_keys:updateCarKeys', src, keys_cache[citizenid])
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        SyncPlayerKeys(src, Player.PlayerData.citizenid)
end)

-- Police Alerts:
RegisterNetEvent('t1ger_keys:sendPoliceAlert', function(coords, street_name, msg)
        TriggerClientEvent('t1ger_keys:sendPoliceAlertCL', -1, coords, msg)
end)

-- Player Alerts:
RegisterNetEvent('t1ger_keys:sendPlayerAlert', function(coords, street_name, msg, plate, citizenid)
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
                TriggerClientEvent('t1ger_keys:sendPlayerAlertCL', Player.PlayerData.source, coords, msg, plate)
        end
end)

local function FetchVehicleKeyState(source, plate)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        local citizenid = Player.PlayerData.citizenid
        local result = MySQL.scalar.await('SELECT t1ger_keys FROM player_vehicles WHERE citizenid = ? AND (plate = ? OR plate = ?)', {
                citizenid,
                plate,
                T1GER_Trim(plate)
        })
        return result ~= nil and result ~= 0
end

local function FetchOwnedVehicles(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return {} end
        local citizenid = Player.PlayerData.citizenid
        local results = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { citizenid })
        return results or {}
end

local function FetchVehicleAlarmData(plate)
        local result = MySQL.query.await('SELECT t1ger_alarm, citizenid FROM player_vehicles WHERE plate = ? OR plate = ?', {
                plate,
                T1GER_Trim(plate)
        })
        if result and result[1] then
            return {
                    alarm = result[1].t1ger_alarm,
                    owner = result[1].citizenid
            }
        end
        return { alarm = false, owner = nil }
end

local function FetchVehiclePrice(model)
        local result = MySQL.query.await('SELECT * FROM vehicles WHERE model = ?', { model })
        if result and result[1] then
                return result[1]
        end
        return nil
end

-- Fetch User Car Key:
QBCore.Functions.CreateCallback('t1ger_keys:fetchVehicleKey', function(source, cb, plate)
        cb(FetchVehicleKeyState(source, plate))
end)

if lib and lib.callback and lib.callback.register then
        lib.callback.register('t1ger_keys:fetchVehicleKey', function(source, plate)
                return FetchVehicleKeyState(source, plate)
        end)
end

local function PlayerHasKey(citizenid, plate)
        if CacheHasPlate(citizenid, plate) then
                return true
        end
        return PlayerHasRegisteredKey(citizenid, plate)
end

-- Event to add temporary copy keys:
RegisterNetEvent('t1ger_keys:giveCopyKeys', function(plate, name, target)
        local src = source
        local giver = QBCore.Functions.GetPlayer(src)
        local receiver = QBCore.Functions.GetPlayer(target)
        if not giver then return end
        if not receiver then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['no_players_nearby'])
                return
        end

        local trimmedPlate = T1GER_Trim(plate)
        local giverCitizen = giver.PlayerData.citizenid
        if not PlayerHasKey(giverCitizen, trimmedPlate) then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['has_key_false'])
                return
        end
        local receiverCitizen = receiver.PlayerData.citizenid
        if CacheHasPlate(receiverCitizen, trimmedPlate) then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['target_has_key_copy']:format(GetPlayerName(receiver.PlayerData.source)))
                return
        end
        local data = {identifier = receiverCitizen, plate = trimmedPlate, name = name, type = 'copy'}
        AddKeyToCache(receiverCitizen, data)
        TriggerClientEvent('t1ger_keys:updateCarKeys', receiver.PlayerData.source, keys_cache[receiverCitizen])
        TriggerClientEvent('t1ger_keys:notify', src, Lang['u_gave_keys']:format(trimmedPlate, GetPlayerName(receiver.PlayerData.source)))
        TriggerClientEvent('t1ger_keys:notify', receiver.PlayerData.source, Lang['keys_received2']:format(trimmedPlate, GetPlayerName(giver.PlayerData.source)))
end)

-- Event to add temporary keys for source player:
RegisterNetEvent('t1ger_keys:giveTemporaryKeys', function(plate, name, keyType)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local trimmedPlate = T1GER_Trim(plate)
        local data = {identifier = citizenid, plate = trimmedPlate, name = name, type = keyType}
        if AddKeyToCache(citizenid, data) then
                TriggerClientEvent('t1ger_keys:updateCarKeys', src, keys_cache[citizenid])
                TriggerClientEvent('t1ger_keys:notify', src, Lang['keys_received1']:format(trimmedPlate))
        end
end)

-- Event to add job vehicle keys:
RegisterNetEvent('t1ger_keys:giveJobKeys', function(plate, name, state, jobs)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        if jobs ~= nil and next(jobs) then
                job_keys[plate] = {plate = plate, jobs = jobs, type = 'job'}
                TriggerClientEvent('t1ger_keys:updateJobKeys', -1, job_keys)
        end
        if state then
                local citizenid = Player.PlayerData.citizenid
                local data = {identifier = citizenid, plate = plate, name = name, type = 'job'}
                if AddKeyToCache(citizenid, data) then
                        TriggerClientEvent('t1ger_keys:updateCarKeys', src, keys_cache[citizenid])
                        TriggerClientEvent('t1ger_keys:notify', src, Lang['keys_received1']:format(plate))
                end
        end
end)

RegisterNetEvent('t1ger_keys:updateOwnedKeys', function(plate, state)
        UpdateKeysToDatabase(plate, state)
end)

-- Export function to update keys state in database:
function UpdateKeysToDatabase(plate, state)
        MySQL.update('UPDATE player_vehicles SET t1ger_keys = ? WHERE plate = ? OR plate = ?', {
                state and 1 or 0,
                plate,
                T1GER_Trim(plate)
        }, function(affected)
                if affected and affected > 0 then
                        print("[T1GER KEYS] - Updated vehicle ["..plate.."] keys state to "..tostring(state))
                else
                        print("[T1GER KEYS] - COULD NOT FIND PLATE - Received plate: "..plate)
                end
        end)
end

-- Remove Car Keys Server Event:
RegisterNetEvent('t1ger_keys:removeCarKeys', function(target, plate, name)
        local src = source
        local giver = QBCore.Functions.GetPlayer(src)
        local receiver = QBCore.Functions.GetPlayer(target)
        if not giver then return end
        if not receiver then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['no_players_nearby'])
                return
        end
        local receiverCitizen = receiver.PlayerData.citizenid
        if RemoveKeyFromCache(receiverCitizen, plate) then
                        TriggerClientEvent('t1ger_keys:updateCarKeys', receiver.PlayerData.source, keys_cache[receiverCitizen])
                        TriggerClientEvent('t1ger_keys:notify', src, Lang['u_removed_a_key']:format(plate, GetPlayerName(receiver.PlayerData.source)))
                        TriggerClientEvent('t1ger_keys:notify', receiver.PlayerData.source, Lang['u_had_a_key_removed']:format(plate, GetPlayerName(giver.PlayerData.source)))
        else
                        TriggerClientEvent('t1ger_keys:notify', src, Lang['target_has_no_key_copy']:format(GetPlayerName(receiver.PlayerData.source)))
        end
end)

-- Delete Car Keys Server Event:
RegisterNetEvent('t1ger_keys:deleteCarKeys', function(plate, name)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        if RemoveKeyFromCache(citizenid, plate) then
                TriggerClientEvent('t1ger_keys:updateCarKeys', src, keys_cache[citizenid])
                TriggerClientEvent('t1ger_keys:notify', src, Lang['keys_deleted']:format(name, plate))
        else
                TriggerClientEvent('t1ger_keys:notify', src, Lang['couldnt_find_keys']:format(plate))
        end
end)

function GetUserKeysCache(citizenid)
        return EnsureCache(citizenid)
end

-- Fetch all owned vehicles:
QBCore.Functions.CreateCallback('t1ger_keys:fetchOwnedVehicles', function(source, cb)
        cb(FetchOwnedVehicles(source))
end)

if lib and lib.callback and lib.callback.register then
        lib.callback.register('t1ger_keys:fetchOwnedVehicles', function(source)
                return FetchOwnedVehicles(source)
        end)
end

-- Give Search Vehicle Reward:
RegisterNetEvent('t1ger_keys:searchVehicleReward', function()
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local cfg = Config.Search
        math.randomseed(GetGameTimer())
        if math.random(0,100) <= cfg.Money.Chance then
                local amount = math.random(cfg.Money.MinAmount, cfg.Money.MaxAmount)
                local account = cfg.Money.BlackMoney and 'cash' or 'cash'
                Player.Functions.AddMoney(account, amount, 't1ger-keys-search')
                TriggerClientEvent('t1ger_keys:notify', src, Lang['cash_found_x']:format(amount))
        end
        for i = 1, #cfg.Items do
                math.randomseed(GetGameTimer())
                local itemCfg = cfg.Items[i]
                if math.random(0,100) <= itemCfg.chance then
                        local amount = math.random(itemCfg.amount.min, itemCfg.amount.max)
                        if Player.Functions.AddItem(itemCfg.item, amount) then
                                TriggerClientEvent('t1ger_keys:notify', src, Lang['item_found_x']:format(amount, itemCfg.name))
                        end
                end
                Wait(50)
        end
end)

-- Lockpick Item:
QBCore.Functions.CreateUseableItem(Config.Lockpick.Item, function(source)
        TriggerClientEvent('t1ger_keys:lockpickCL', source)
end)

RegisterNetEvent('t1ger_keys:removeLockpick', function()
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        Player.Functions.RemoveItem(Config.Lockpick.Item, 1)
end)

-- Get Vehicle Alarm:
QBCore.Functions.CreateCallback('t1ger_keys:getVehicleAlarm', function(source, cb, plate)
        local data = FetchVehicleAlarmData(plate)
        cb(data.alarm, data.owner)
end)

if lib and lib.callback and lib.callback.register then
        lib.callback.register('t1ger_keys:getVehicleAlarm', function(_, plate)
                return FetchVehicleAlarmData(plate)
        end)
end

-- Get vehicle price:
QBCore.Functions.CreateCallback('t1ger_keys:getVehiclePrice', function(source, cb, model)
        cb(FetchVehiclePrice(model))
end)

if lib and lib.callback and lib.callback.register then
        lib.callback.register('t1ger_keys:getVehiclePrice', function(_, model)
                return FetchVehiclePrice(model)
        end)
end

RegisterNetEvent('t1ger_keys:registerKey', function(plate, state)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        if not PlayerOwnsVehicle(citizenid, plate) then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['couldnt_find_keys']:format(plate))
                return
        end
        local price = Config.LockSmith.price
        local account = Config.LockSmith.bank and 'bank' or 'cash'
        if Player.Functions.GetMoney(account) >= price then
                Player.Functions.RemoveMoney(account, price, 't1ger-keys-register')
                UpdateKeysToDatabase(plate, state)
        else
                TriggerClientEvent('t1ger_keys:notify', src, Lang['not_enough_money'])
        end
end)

RegisterNetEvent('t1ger_keys:registerAlarm', function(plate, state, price)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        if not PlayerOwnsVehicle(citizenid, plate) then
                TriggerClientEvent('t1ger_keys:notify', src, Lang['couldnt_find_keys']:format(plate))
                return
        end
        local account = Config.AlarmShop.bank and 'bank' or 'cash'
        if Player.Functions.GetMoney(account) >= price then
                Player.Functions.RemoveMoney(account, price, 't1ger-keys-alarm')
                MySQL.update('UPDATE player_vehicles SET t1ger_alarm = ? WHERE plate = ? OR plate = ?', {
                        state and 1 or 0,
                        plate,
                        T1GER_Trim(plate)
                })
        else
                TriggerClientEvent('t1ger_keys:notify', src, Lang['not_enough_money'])
        end
end)

-- Function to trim plates:
function T1GER_Trim(value)
        return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end
