-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

local cachedInsurancePoints
local insuranceBlips = {}

CreateThread(function()
        PlayerData = QBCore.Functions.GetPlayerData()
        CreateInsuranceBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = QBCore.Functions.GetPlayerData()
        CreateInsuranceBlip()
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(data)
        PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
end)

local function BuildPointEntry(company, data)
        local pos = data.pos or data.coords
        if not pos then return nil end
        local coords
        if type(pos) == 'vector3' then
                coords = pos
        elseif type(pos) == 'table' then
                coords = vector3(pos[1], pos[2], pos[3])
        end
        if not coords then return nil end
        local marker = data.marker or company.marker or {}
        local menuKey = data.menuKey or company.menuKey or 38
        local loadDist = data.loadDist or company.loadDist or 10.0
        local interactDist = data.interactDist or company.interactDist or 1.5
        return {
                coords = coords,
                marker = marker,
                menuKey = menuKey,
                loadDist = loadDist,
                interactDist = interactDist
        }
end

function GetInsurancePoints(forceRefresh)
        if cachedInsurancePoints and not forceRefresh then
                return cachedInsurancePoints
        end

        cachedInsurancePoints = {}
        local company = Config.Insurance.company or {}

        if company.points and #company.points > 0 then
                for _, point in ipairs(company.points) do
                        local entry = BuildPointEntry(company, point)
                        if entry then
                                cachedInsurancePoints[#cachedInsurancePoints + 1] = entry
                        end
                end
        end

        if #cachedInsurancePoints == 0 and company.pos then
                local entry = BuildPointEntry(company, { pos = company.pos })
                if entry then
                        cachedInsurancePoints[1] = entry
                end
        end

        return cachedInsurancePoints
end

local function ClearInsuranceBlips()
        if #insuranceBlips == 0 then return end
        for _, blip in ipairs(insuranceBlips) do
                RemoveBlip(blip)
        end
        insuranceBlips = {}
end

function CreateInsuranceBlip()
        ClearInsuranceBlips()
        local company = Config.Insurance.company or {}
        local blipSettings = company.blip or {}
        if not blipSettings.enable then return end

        local points = GetInsurancePoints(true)
        for _, point in ipairs(points) do
                local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
                SetBlipSprite(blip, blipSettings.sprite or 1)
                SetBlipDisplay(blip, blipSettings.display or 4)
                SetBlipScale(blip, blipSettings.scale or 0.75)
                SetBlipColour(blip, blipSettings.color or 0)
                SetBlipAsShortRange(blip, blipSettings.shortRange ~= false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(blipSettings.label or 'Insurance')
                EndTextCommandSetBlipName(blip)
                insuranceBlips[#insuranceBlips + 1] = blip
        end
end

function Notify(message, notifType)
        lib.notify({
                description = message,
                type = notifType or 'inform'
        })
end

-- Function for 3D text
function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    if not onScreen then return end

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 500
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 80)
end

-- Load Anim
function LoadAnim(animDict)
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
end

-- Load Model
function LoadModel(model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
end

-- Round Function
function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Comma Function
function comma_value(n)
        local str = tostring(n)
        local left, num, right = str:match('^(%d?%d?%d)(%d*)(.-)$')
        if not left then return str end
        return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

-- Get Vehicle Name
function GetVehName(entity)
    local hashKey = GetEntityModel(entity)
    local display = GetDisplayNameFromVehicleModel(hashKey)
    local label = GetLabelText(display)
    if label == 'CARNOTFOUND' then label = 'Unknown' end
    return label
end
