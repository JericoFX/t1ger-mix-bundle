-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports["qb-core"]:GetCoreObject()
PlayerData 	= {}

-- Police Notify:
isCop = false
local streetName
local _

CreateThread(function()
	PlayerData = QBCore.Functions.GetPlayerData()
	isCop = IsPlayerJobCop()
	-- Create Blip:
	CreateTruckRobberyMapBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	PlayerData =  QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
	PlayerData.job = job
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(val)
	PlayerData = val
end)


-- [[ ESX SHOW ADVANCED NOTIFICATION ]] --
RegisterNetEvent('t1ger_truckrobbery:ShowAdvancedNotifyESX', function(title, subject, msg, icon, iconType)
	ESX.ShowAdvancedNotification(title, subject, msg, icon, iconType)
	-- If you want to switch ESX.ShowNotification with something else:
	-- 1) Comment out the function
	-- 2) add your own
	
end)

-- [[ ESX SHOW NOTIFICATION ]] --
RegisterNetEvent('t1ger_truckrobbery:ShowNotifyESX', function(msg)
	ShowNotifyESX(msg)
end)

function ShowNotifyESX(msg)
	ESX.ShowNotification(msg)
	-- If you want to switch ESX.ShowNotification with something else:
	-- 1) Comment out the function
	-- 2) add your own
end

function NotifyPoliceFunction()
	TriggerServerEvent('t1ger_truckrobbery:PoliceNotifySV', GetEntityCoords(cache.ped), streetName)
	-- If you want to use your own alert:
	-- 1) Comment out the 'TriggerServerEvent('t1ger_carthief:OutlawNotifySV',GetEntityCoords(PlayerPedId()),streetName)'
	-- 2) replace whatever even you use to trigger your alert.
	
end

RegisterNetEvent('t1ger_truckrobbery:PoliceNotifyCL', function(alert)
	if isCop then
		TriggerEvent('chat:addMessage', { args = {(Lang['dispatch_name']).. alert}})
	end
end)

-- Thread for Police Notify
CreateThread(function()
	while true do
		Wait(3000)
		local pos = GetEntityCoords(GetPlayerPed(-1), false)
		streetName,_ = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
		streetName = GetStreetNameFromHashKey(streetName)
	end
end)

RegisterNetEvent('t1ger_truckrobbery:PoliceNotifyBlip', function(targetCoords)
	local cfg = Config.TruckRobbery.police
	if isCop and cfg.blip.show then 
		local alpha = cfg.blip.alpha
		local alertBlip = AddBlipForRadius(targetCoords.x, targetCoords.y, targetCoords.z, cfg.blip.radius)

		SetBlipHighDetail(alertBlip, true)
		SetBlipColour(alertBlip, cfg.blip.color)
		SetBlipAlpha(alertBlip, alpha)
		SetBlipAsShortRange(alertBlip, true)

		while alpha ~= 0 do
			Wait(cfg.blip.time * 4)
			alpha = alpha - 1
			SetBlipAlpha(alertBlip, alpha)

			if alpha == 0 then
				RemoveBlip(alertBlip)
				return
			end
		end
	end
end)

-- Is Player A cop?
function IsPlayerJobCop()	
	if not PlayerData then return false end
	if not PlayerData.job then return false end
	for k,v in pairs(Config.TruckRobbery.police.jobs) do
		if PlayerData.job.name == v then return true end
	end
	return false
end

-- Function for 3D text:
function DrawText3Ds(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 500
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 0, 0, 0, 80)
end

-- Function for Mission text:
function DrawMissionText(text)
    SetTextScale(0.5, 0.5)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextEntry("STRING")
    SetTextCentre(1)
    SetTextOutline()
    AddTextComponentString(text)
    DrawText(0.5,0.955)
end

-- Round Fnction:
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Load Anim
function LoadAnim(animDict)
	RequestAnimDict(animDict)
	while not HasAnimDictLoaded(animDict) do Wait(10) end
end

-- Load Model
function LoadModel(model)
	RequestModel(model)
	while not HasModelLoaded(model) do
		Wait(10)
	end
end

-- Instructional Buttons:
function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

-- Button:
function Button(ControlButton)
    N_0xe83a3e3557a56640(ControlButton)
end