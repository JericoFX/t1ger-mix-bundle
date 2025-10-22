-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local cache = lib.cache
local player = cache.ped or PlayerPedId()
local coords = cache.coords or GetEntityCoords(player)

lib.onCache('ped', function(value)
    player = value
end)

lib.onCache('coords', function(value)
    coords = value
end)

local function ensurePlayerPed()
    if not player or not DoesEntityExist(player) then
        player = PlayerPedId()
    end
    if not coords then
        coords = GetEntityCoords(player)
    end
    return player
end

local function runProgress(label, duration)
    return lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        }
    })
end

local function playLoopedAnim(ped, dict, anim)
    local keepPlaying = true
    CreateThread(function()
        while keepPlaying do
            TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, 31, 0, false, false, false)
            Wait(2000)
        end
    end)

    return function()
        keepPlaying = false
        ClearPedTasks(ped)
    end
end

local plyMining, plyWashing, plySmelting = false, false, false

local function drawMarker(marker, pos)
    if not marker or not marker.enable then return end

    DrawMarker(
        marker.type,
        pos.x,
        pos.y,
        pos.z - (marker.zOffset or 0.975),
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        marker.scale.x,
        marker.scale.y,
        marker.scale.z,
        marker.color.r,
        marker.color.g,
        marker.color.b,
        marker.color.a,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function playerHasItem(item, amount)
    if not item then return false end

    return lib.callback.await('t1ger_minerjob:hasItem', false, item, amount or 1)
end

local function OpenMiningFunction(id)
    local ped = ensurePlayerPed()
    local success, reason = lib.callback.await('t1ger_minerjob:beginMining', false, id)
    if not success then
        ShowNotify({ description = Lang[reason] or Lang['spot_unavailable'], type = 'error' })
        plyMining = false
        return
    end

    if not playerHasItem(Config.DatabaseItems['pickaxe'], 1) then
        TriggerServerEvent('t1ger_minerjob:cancelMining', id)
        ShowNotify({ description = Lang['no_pickaxe'], type = 'error' })
        plyMining = false
        return
    end

    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`)
    Wait(100)

    local pickaxeModel = `prop_tool_pickaxe`
    RequestModel(pickaxeModel)

    local anim = { dict = 'melee@hatchet@streamed_core_fps', lib = 'plyr_front_takedown' }
    RequestAnim(anim.dict)

    local pedCoords = coords or GetEntityCoords(ped)
    local object = CreateObject(pickaxeModel, pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, 57005), 0.1, 0.0, 0.0, -90.0, 25.0, 35.0, true, true, false, true, 1, true)

    local stopAnim = playLoopedAnim(ped, anim.dict, anim.lib)
    local successProgress = runProgress(Lang['pb_mining'], 10000)

    stopAnim()
    DeleteObject(object)
    SetModelAsNoLongerNeeded(pickaxeModel)
    FreezeEntityPosition(ped, false)

    if successProgress then
        TriggerServerEvent('t1ger_minerjob:miningReward', id)
    else
        TriggerServerEvent('t1ger_minerjob:cancelMining', id)
        ShowNotify({ description = Lang['process_cancelled'], type = 'inform' })
    end

    plyMining = false
end

local function OpenWashingFunction()
    if not playerHasItem(Config.DatabaseItems['washpan'], 1) then
        ShowNotify({ description = Lang['no_washpan'], type = 'error' })
        plyWashing = false
        return
    end

    if not playerHasItem(Config.DatabaseItems['stone'], Config.WashSettings.input) then
        ShowNotify({ description = Lang['not_enough_stone'], type = 'error' })
        plyWashing = false
        return
    end

    local ped = ensurePlayerPed()
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`)
    Wait(100)

    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)
    local success = runProgress(Lang['pb_washing'], 10000)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if success then
        TriggerServerEvent('t1ger_minerjob:washStone')
    else
        ShowNotify({ description = Lang['process_cancelled'], type = 'inform' })
    end

    plyWashing = false
end

local function OpenSmeltingFunction()
    local ped = ensurePlayerPed()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance < 0.7 then
        ShowNotify({ description = Lang['player_too_close'], type = 'error' })
        plySmelting = false
        return
    end

    if not playerHasItem(Config.DatabaseItems['washed_stone'], Config.SmeltingSettings.input) then
        ShowNotify({ description = Lang['not_enough_washed_stone'], type = 'error' })
        plySmelting = false
        return
    end

    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`)
    Wait(100)

    local success = runProgress(Lang['pb_smelting'], 10000)
    FreezeEntityPosition(ped, false)

    if success then
        TriggerServerEvent('t1ger_minerjob:smeltStone')
    else
        ShowNotify({ description = Lang['process_cancelled'], type = 'inform' })
    end

    plySmelting = false
end

local function handleMiningPoint(id, data, point)
    if plyMining then return end
    if data.inUse then
        HideInteraction('mining')
        return
    end

    local distance = point.currentDistance or point.distance

    if distance >= 1.5 then
        if data.marker.enable and distance <= data.marker.drawDist then
            drawMarker(data.marker, point.coords)
        end
        if currentOwner == 'mining' then
            HideInteraction('mining')
        end
        return
    end

    ShowInteraction((Lang['ui_mine']):format(KeyString(data.keybind)), 'mining')
    if IsControlJustPressed(0, data.keybind) then
        HideInteraction('mining')
        plyMining = true
        OpenMiningFunction(id)
    end
end

local function handleWashingPoint(data, point)
    if plyWashing then return end

    local distance = point.currentDistance or point.distance

    if distance >= 1.25 then
        if data.marker.enable and distance <= data.marker.drawDist then
            drawMarker(data.marker, point.coords)
        end
        if currentOwner == 'washing' then
            HideInteraction('washing')
        end
        return
    end

    ShowInteraction((Lang['ui_wash']):format(KeyString(data.keybind)), 'washing')
    if IsControlJustPressed(0, data.keybind) then
        HideInteraction('washing')
        plyWashing = true
        OpenWashingFunction()
    end
end

local function handleSmeltingPoint(data, point)
    if plySmelting then return end

    local distance = point.currentDistance or point.distance

    if distance >= 1.25 then
        if data.marker.enable and distance <= data.marker.drawDist then
            drawMarker(data.marker, point.coords)
        end
        if currentOwner == 'smelting' then
            HideInteraction('smelting')
        end
        return
    end

    ShowInteraction((Lang['ui_smelt']):format(KeyString(data.keybind)), 'smelting')
    if IsControlJustPressed(0, data.keybind) then
        HideInteraction('smelting')
        plySmelting = true
        OpenSmeltingFunction()
    end
end

local function createInteractionPoints()
    for id, data in pairs(Config.Mining) do
        lib.points.new({
            coords = vector3(data.pos[1], data.pos[2], data.pos[3]),
            distance = data.marker.drawDist,
            onExit = function()
                HideInteraction('mining')
            end,
            nearby = function(point)
                local info = Config.Mining[id]
                if not info then return end
                handleMiningPoint(id, info, point)
            end
        })
    end

    for index, data in pairs(Config.Washing) do
        lib.points.new({
            coords = vector3(data.pos[1], data.pos[2], data.pos[3]),
            distance = data.marker.drawDist,
            onExit = function()
                HideInteraction('washing')
            end,
            nearby = function(point)
                local info = Config.Washing[index]
                if not info then return end
                handleWashingPoint(info, point)
            end
        })
    end

    for index, data in pairs(Config.Smelting) do
        lib.points.new({
            coords = vector3(data.pos[1], data.pos[2], data.pos[3]),
            distance = data.marker.drawDist,
            onExit = function()
                HideInteraction('smelting')
            end,
            nearby = function(point)
                local info = Config.Smelting[index]
                if not info then return end
                handleSmeltingPoint(info, point)
            end
        })
    end
end

CreateThread(createInteractionPoints)

RegisterNetEvent('t1ger_minerjob:mineSpotStateCL', function(id, state)
    if Config.Mining[id] then
        Config.Mining[id].inUse = state
    end
end)

CreateThread(function()
    for _, data in pairs(Config.Mining) do
        local bp = data.blip
        if bp.enable then
            local blip = AddBlipForCoord(data.pos[1], data.pos[2], data.pos[3])
            SetBlipSprite(blip, bp.sprite)
            SetBlipDisplay(blip, bp.display)
            SetBlipScale(blip, bp.scale)
            SetBlipColour(blip, bp.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(bp.str)
            EndTextCommandSetBlipName(blip)
        end
    end

    for _, data in pairs(Config.Washing) do
        local bp = data.blip
        if bp.enable then
            local blip = AddBlipForCoord(data.pos[1], data.pos[2], data.pos[3])
            SetBlipSprite(blip, bp.sprite)
            SetBlipDisplay(blip, bp.display)
            SetBlipScale(blip, bp.scale)
            SetBlipColour(blip, bp.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(bp.str)
            EndTextCommandSetBlipName(blip)
        end
    end

    for _, data in pairs(Config.Smelting) do
        local bp = data.blip
        if bp.enable then
            local blip = AddBlipForCoord(data.pos[1], data.pos[2], data.pos[3])
            SetBlipSprite(blip, bp.sprite)
            SetBlipDisplay(blip, bp.display)
            SetBlipScale(blip, bp.scale)
            SetBlipColour(blip, bp.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(bp.str)
            EndTextCommandSetBlipName(blip)
        end
    end
end)
