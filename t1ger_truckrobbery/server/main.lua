-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

local QBCore = exports["qb-core"]:GetCoreObject()

local jobCooldown = {} 

RegisterServerEvent('t1ger_truckrobbery:jobCooldown',function(source)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	table.insert(jobCooldown,{cooldown = xPlayer.identifier, time = (Config.TruckRobbery.cooldown * 60000)}) -- cooldown timer for doing missions
end)

Citizen.CreateThread(function() -- do not touch this thread function!
	while true do
	Citizen.Wait(1000)
		for k,v in pairs(jobCooldown) do
			if v.time <= 0 then
				RemoveCooldownTimer(v.cooldown)
			else
				v.time = v.time - 1000
			end
		end
	end
end)

-- Callback to get cops count:
lib.callback.register("t1ger_truckrobbery:copCount",function(source) 
	local players,count= QBCore.Functions.GetPlayersOnDuty("police")
	return count
end)
-- Callback to get cooldown:
lib.callback.register("t1ger_truckrobbery:getCooldown",function(source) 
	local xPlayer = QBCore.Functions.GetPlayer(source)
	if not CheckCooldownTimer(xPlayer.PlayerData.citizenid) then
		return nil
	else
		return GetCooldownTimer(xPlayer.PlayerData.citizenid)
	end
end)
-- Callback to check if ply has job fees:

lib.callback.register("t1ger_truckrobbery:getCooldown",function(source) 
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local money = 0
	if Config.TruckRobbery.computer.fees.bankMoney then 
		money = xPlayer.PlayerData.money.bank
	else
		money = xPlayer.PlayerData.money.cash
	end
	if money >= Config.TruckRobbery.computer.fees.amount then
        return true
    else
        return false
    end
end)

-- server side function to accept the mission
RegisterServerEvent('t1ger_truckrobbery:startJobSV', function(item)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	TriggerEvent('t1ger_truckrobbery:jobCooldown', source)
	if Config.TruckRobbery.computer.fees.bankMoney then 
		xPlayer.Functions.RemoveMoney('bank', Config.TruckRobbery.computer.fees.amount,"T1ger")
	else
		xPlayer.Functions.RemoveMoney("cash",Config.TruckRobbery.computer.fees.amount,"T1ger")
	end
	TriggerClientEvent('t1ger_truckrobbery:startJobCL', source)
end)

-- Event to trigger job reward:
RegisterServerEvent('t1ger_truckrobbery:jobReward',function()
	local cfg = Config.TruckRobbery.reward
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local reward = math.random(cfg.money.min, cfg.money.max)
	
	if cfg.money.dirty then
		exports.ox_inventory:AddItem(source, 'black_money', reward, false, false, false)
		--xPlayer.Functions.AddItem('black_money', tonumber(reward))
	else
		xPlayer.Functions.AddMoney("cash",reward)
	end
	TriggerClientEvent('t1ger_truckrobbery:ShowNotifyESX', xPlayer.PlayerData.source, (Lang['reward_notify']:format(reward)))
	
	if cfg.items.enable then
		for k,v in pairs(cfg.items.list) do
			if math.random(0,100) <= v.chance then 
				local amount = math.random(v.min, v.max)
				local name = tostring(v.item)
				if Config.HasItemLabel then
					name = exports.ox_inventory:GetItem(source, v.item, false, false)
				end
				xPlayer.Function.AddItem(v.item, amount)
				TriggerClientEvent('t1ger_truckrobbery:ShowNotifyESX', xPlayer.playerData.source, (Lang['you_received_item']:format(amount,name.label)))
			end
		end
	end
end)

-- Event to trigger police notifications:
RegisterServerEvent('t1ger_truckrobbery:PoliceNotifySV', function(targetCoords, streetName)
	TriggerClientEvent('t1ger_truckrobbery:PoliceNotifyCL', -1, (Lang['police_notify']):format(streetName))
	TriggerClientEvent('t1ger_truckrobbery:PoliceNotifyBlip', -1, targetCoords)
end)

-- Event to update config.lua across all clients:
RegisterServerEvent('t1ger_truckrobbery:SyncDataSV',function(data)
	TriggerClientEvent("t1ger_truckrobbery:SyncJob",-1,data)
    TriggerClientEvent('t1ger_truckrobbery:SyncDataCL', -1, data)
end)

-- Do not touch these 3 functions:
function RemoveCooldownTimer(source)
    for k,v in pairs(jobCooldown) do
        if v.cooldown == source then
            table.remove(jobCooldown,k)
        end
    end
end
function GetCooldownTimer(source)
    for k,v in pairs(jobCooldown) do
        if v.cooldown == source then
            return math.ceil(v.time/60000)
        end
    end
end
function CheckCooldownTimer(source)
    for k,v in pairs(jobCooldown) do
        if v.cooldown == source then
            return true
        end
    end
    return false
end