-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports[Config.CoreResource]:GetCoreObject()
PlayerData = {}

CreateThread(function()
    PlayerData = QBCore.Functions.GetPlayerData()
    if Config.Debug then
        Wait(1000)
        TriggerServerEvent('t1ger_trafficpolicer:startDebug')
    end
    TriggerServerEvent('t1ger_trafficpolicer:playerReady')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    if Config.Debug then
        TriggerServerEvent('t1ger_trafficpolicer:startDebug')
    end
    TriggerServerEvent('t1ger_trafficpolicer:playerReady')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not PlayerData then
        PlayerData = {}
    end
    PlayerData.job = job
end)

local function fallbackNotify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(msg)
    DrawNotification(true, true)
end

local function showNotify(message, notifType)
    if lib and lib.notify then
        lib.notify({
            title = 'Traffic Policer',
            description = message,
            type = notifType or 'inform'
        })
    else
        fallbackNotify(message)
    end
end

RegisterNetEvent('t1ger_trafficpolicer:notifyAdvanced', function(title, subject, msg)
    local message = msg
    if subject and subject ~= '' then
        message = subject .. '\n' .. msg
    end
    if title and title ~= '' then
        message = title .. '\n' .. message
    end
    showNotify(message, 'inform')
end)

RegisterNetEvent('t1ger_trafficpolicer:notify', function(msg, notifType)
    showNotify(msg, notifType)
end)

function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
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

function LoadAnim(animDict)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
end

function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
end

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function comma_value(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function GetVehColorName(entity)
    local color1, color2 = GetVehicleColours(entity)
    if color1 == 0 then color1 = 1 end
    if color2 == 0 then color2 = 2 end
    if color1 == -1 then color1 = 158 end
    if color2 == -1 then color2 = 158 end
    return colors[color1], colors[color2]
end

function GetVehName(entity)
    local hashKey = GetEntityModel(entity)
    local display = GetDisplayNameFromVehicleModel(hashKey)
    local label = GetLabelText(display)
    if label == 'CARNOTFOUND' then label = 'Unknown' end
    return label
end

function GetVehicleInDirection(coordFrom, coordTo, radius)
    radius = radius or 2.5
    local rayHandle = StartShapeTestCapsule(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, radius, 10, player, 7)
    local _, _, _, _, vehicle = GetShapeTestResult(rayHandle)
    return vehicle
end

function GetClosestPlayer()
    local playerId, distance = QBCore.Functions.GetClosestPlayer()
    if playerId ~= -1 and distance <= 2.0 then
        return playerId
    end
    TriggerEvent('t1ger_trafficpolicer:notify', Lang['no_players_nearby'], 'error')
    return nil
end

function GetControlOfEntity(entity)
    local netTime = 15
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and netTime > 0 do
        NetworkRequestControlOfEntity(entity)
        Wait(100)
        netTime = netTime - 1
    end
end

function IsPlayerJobCop(minGrade)
    if not PlayerData or not PlayerData.job then
        return false
    end
    local jobName = PlayerData.job.name
    local requiredGrade = minGrade or Config.Jobs[jobName]
    if requiredGrade == nil then
        return false
    end
    local gradeLevel = PlayerData.job.grade and (PlayerData.job.grade.level or PlayerData.job.grade) or 0
    return gradeLevel >= requiredGrade
end

function HasPlayerJob(jobName)
    if not PlayerData or not PlayerData.job then
        return false
    end
    return PlayerData.job.name == jobName
end

colors = {
    [0] = "Metallic Black",
    [1] = "Metallic Graphite Black",
    [2] = "Metallic Black Steal",
    [3] = "Metallic Dark Silver",
    [4] = "Metallic Silver",
    [5] = "Metallic Blue Silver",
    [6] = "Metallic Steel Gray",
    [7] = "Metallic Shadow Silver",
    [8] = "Metallic Stone Silver",
    [9] = "Metallic Midnight Silver",
    [10] = "Metallic Gun Metal",
    [11] = "Metallic Anthracite Grey",
    [12] = "Matte Black",
    [13] = "Matte Gray",
    [14] = "Matte Light Grey",
    [15] = "Util Black",
    [16] = "Util Black Poly",
    [17] = "Util Dark silver",
    [18] = "Util Silver",
    [19] = "Util Gun Metal",
    [20] = "Util Shadow Silver",
    [21] = "Worn Black",
    [22] = "Worn Graphite",
    [23] = "Worn Silver Grey",
    [24] = "Worn Silver",
    [25] = "Worn Blue Silver",
    [26] = "Worn Shadow Silver",
    [27] = "Metallic Red",
    [28] = "Metallic Torino Red",
    [29] = "Metallic Formula Red",
    [30] = "Metallic Blaze Red",
    [31] = "Metallic Graceful Red",
    [32] = "Metallic Garnet Red",
    [33] = "Metallic Desert Red",
    [34] = "Metallic Cabernet Red",
    [35] = "Metallic Candy Red",
    [36] = "Metallic Sunrise Orange",
    [37] = "Metallic Classic Gold",
    [38] = "Metallic Orange",
    [39] = "Matte Red",
    [40] = "Matte Dark Red",
    [41] = "Matte Orange",
    [42] = "Matte Yellow",
    [43] = "Util Red",
    [44] = "Util Bright Red",
    [45] = "Util Garnet Red",
    [46] = "Worn Red",
    [47] = "Worn Golden Red",
    [48] = "Worn Dark Red",
    [49] = "Metallic Dark Green",
    [50] = "Metallic Racing Green",
    [51] = "Metallic Sea Green",
    [52] = "Metallic Olive Green",
    [53] = "Metallic Green",
    [54] = "Metallic Gasoline Blue Green",
    [55] = "Matte Lime Green",
    [56] = "Util Dark Green",
    [57] = "Util Green",
    [58] = "Worn Dark Green",
    [59] = "Worn Green",
    [60] = "Worn Sea Wash",
    [61] = "Metallic Midnight Blue",
    [62] = "Metallic Dark Blue",
    [63] = "Metallic Saxony Blue",
    [64] = "Metallic Blue",
    [65] = "Metallic Mariner Blue",
    [66] = "Metallic Harbor Blue",
    [67] = "Metallic Diamond Blue",
    [68] = "Metallic Surf Blue",
    [69] = "Metallic Nautical Blue",
    [70] = "Metallic Bright Blue",
    [71] = "Metallic Purple Blue",
    [72] = "Metallic Spinnaker Blue",
    [73] = "Metallic Ultra Blue",
    [74] = "Metallic Bright Blue",
    [75] = "Util Dark Blue",
    [76] = "Util Midnight Blue",
    [77] = "Util Blue",
    [78] = "Util Sea Foam Blue",
    [79] = "Uil Lightning blue",
    [80] = "Util Maui Blue Poly",
    [81] = "Util Bright Blue",
    [82] = "Matte Dark Blue",
    [83] = "Matte Blue",
    [84] = "Matte Midnight Blue",
    [85] = "Worn Dark blue",
    [86] = "Worn Blue",
    [87] = "Worn Light blue",
	[88] = "Metallic Taxi Yellow",
	[89] = "Metallic Race Yellow",
	[90] = "Metallic Bronze",
	[91] = "Metallic Yellow Bird",
	[92] = "Metallic Lime",
	[93] = "Metallic Champagne",
	[94] = "Metallic Pueblo Beige",
	[95] = "Metallic Dark Ivory",
	[96] = "Metallic Choco Brown",
	[97] = "Metallic Golden Brown",
	[98] = "Metallic Light Brown",
	[99] = "Metallic Straw Beige",
	[100] = "Metallic Moss Brown",
	[101] = "Metallic Biston Brown",
	[102] = "Metallic Beechwood",
	[103] = "Metallic Dark Beechwood",
	[104] = "Metallic Choco Orange",
	[105] = "Metallic Beach Sand",
	[106] = "Metallic Sun Bleeched Sand",
	[107] = "Metallic Cream",
	[108] = "Util Brown",
	[109] = "Util Medium Brown",
	[110] = "Util Light Brown",
	[111] = "Metallic White",
	[112] = "Metallic Frost White",
	[113] = "Worn Honey Beige",
	[114] = "Worn Brown",
	[115] = "Worn Dark Brown",
	[116] = "Worn straw beige",
	[117] = "Brushed Steel",
	[118] = "Brushed Black steel",
	[119] = "Brushed Aluminium",
	[120] = "Chrome",
	[121] = "Worn Off White",
	[122] = "Util Off White",
	[123] = "Worn Orange",
	[124] = "Worn Light Orange",
	[125] = "Metallic Securicor Green",
	[126] = "Worn Taxi Yellow",
	[127] = "police car blue",
	[128] = "Matte Green",
	[129] = "Matte Brown",
	[130] = "Worn Orange",
	[131] = "Matte White",
	[132] = "Worn White",
	[133] = "Worn Olive Army Green",
	[134] = "Pure White",
	[135] = "Hot Pink",
	[136] = "Salmon pink",
	[137] = "Metallic Vermillion Pink",
	[138] = "Orange",
	[139] = "Green",
	[140] = "Blue",
	[141] = "Mettalic Black Blue",
	[142] = "Metallic Black Purple",
	[143] = "Metallic Black Red",
	[144] = "hunter green",
	[145] = "Metallic Purple",
	[146] = "Metaillic V Dark Blue",
	[147] = "MODSHOP BLACK1",
	[148] = "Matte Purple",
	[149] = "Matte Dark Purple",
	[150] = "Metallic Lava Red",
	[151] = "Matte Forest Green",
	[152] = "Matte Olive Drab",
	[153] = "Matte Desert Brown",
	[154] = "Matte Desert Tan",
	[155] = "Matte Foilage Green",
	[156] = "DEFAULT ALLOY COLOR",
	[157] = "Epsilon Blue",
	[158] = "Unknown",
}
