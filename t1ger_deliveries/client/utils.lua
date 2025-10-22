-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

CreateThread(function()
PlayerData = QBCore.Functions.GetPlayerData()
UpdateDeliveryIdentifier()

if Config.Debug then
Wait(3000)
TriggerServerEvent('t1ger_deliveries:debugSV')
end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
PlayerData = QBCore.Functions.GetPlayerData()
UpdateDeliveryIdentifier()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
PlayerData.job = job
UpdateDeliveryIdentifier()
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(val)
PlayerData = val
UpdateDeliveryIdentifier()
end)

function UpdateDeliveryIdentifier()
if not PlayerData or not PlayerData.job then return end
for i = 1, #Config.Companies do
local deliveryJob = Config.Society[Config.Companies[i].society].name
if PlayerData.job.name == deliveryJob then
TriggerEvent('t1ger_deliveries:deliveryID', i)
return
end
end
TriggerEvent('t1ger_deliveries:deliveryID', 0)
end

local function getNotifyType(msg)
if type(msg) ~= 'string' then return 'inform' end
msg = msg:lower()
if msg:find('success') or msg:find('completed') or msg:find('purchased') then
return 'success'
elseif msg:find('error') or msg:find('not enough') or msg:find('fail') or msg:find('mismatch') then
return 'error'
elseif msg:find('warning') or msg:find('alert') then
return 'warning'
end
return 'inform'
end

RegisterNetEvent('t1ger_deliveries:notify', function(msg)
lib.notify({
title = Lang['notify_title'] or 'Deliveries',
description = msg,
type = getNotifyType(msg)
})
end)

RegisterNetEvent('t1ger_deliveries:notifyAdvanced', function(sender, subject, msg, textureDict, iconType)
lib.notify({
title = sender or (Lang['notify_title'] or 'Deliveries'),
description = subject and (subject .. '\n' .. msg) or msg,
type = getNotifyType(msg)
})
end)

-- Draw 3D Text:
function T1GER_DrawTxt(x, y, z, text)
	local boolean, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING"); SetTextCentre(1); AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text) / 500)
    DrawRect(_x, (_y + 0.0125), (0.015 + factor), 0.03, 0, 0, 0, 80)
end

function T1GER_GetControlOfEntity(entity)
	local netTime = 15
	NetworkRequestControlOfEntity(entity)
	while not NetworkHasControlOfEntity(entity) and netTime > 0 do 
		NetworkRequestControlOfEntity(entity)
		Citizen.Wait(100)
		netTime = netTime -1
	end
end

-- Load Anim
function T1GER_LoadAnim(animDict)
        if lib and lib.requestAnimDict then
                lib.requestAnimDict(animDict)
                return
        end
        RequestAnimDict(animDict); while not HasAnimDictLoaded(animDict) do Citizen.Wait(1) end
end

-- Load Model
function T1GER_LoadModel(model)
        if lib and lib.requestModel then
                lib.requestModel(model)
                return
        end
        RequestModel(model); while not HasModelLoaded(model) do Citizen.Wait(1) end
end

-- Load Ptfx
function T1GER_LoadPtfxAsset(dict)
        if lib and lib.requestNamedPtfxAsset then
                lib.requestNamedPtfxAsset(dict)
                return
        end
        RequestNamedPtfxAsset(dict); while not HasNamedPtfxAssetLoaded(dict) do Citizen.Wait(1) end
end

function T1GER_isJob(name)
	if not PlayerData then return false end
	if not PlayerData.job then return false end
	if PlayerData.job.name == name then
		return true
	end
	return false
end

function T1GER_GetJob(table)
	if not PlayerData then return false end
	if not PlayerData.job then return false end
	for k,v in pairs(table) do
		if PlayerData.job.name == v then
			return true
		end
	end
	return false
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

-- Round function
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Comma function
function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

-- Draw Rect:
function drawRct(x, y, width, height, r, g, b, a)
	DrawRect(x + width/2, y + height/2, width, height, r, g, b, a)
end
