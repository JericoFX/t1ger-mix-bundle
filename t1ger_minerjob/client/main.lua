local QBCore = exports['qb-core']:GetCoreObject()

local miningState = { active = false }
local washingState = { active = false }
local smeltingState = { active = false }

local function sanitizePrompt(text)
    local sanitized = text:gsub('~.-~', '')
    sanitized = sanitized:gsub('%b[]', '')
    sanitized = sanitized:gsub('^%s+', '')
    return sanitized
end

local function showPrompt(point, prompt)
    if point.isShowing then return end
    lib.showTextUI(prompt, {
        position = 'right-center'
    })
    point.isShowing = true
end

local function hidePrompt(point)
    if not point.isShowing then return end
    lib.hideTextUI()
    point.isShowing = false
end

local function createBlips(entries)
    for _, data in pairs(entries) do
        local bp = data.blip
        if not bp or not bp.enable then goto continue end

        local blip = AddBlipForCoord(data.pos[1], data.pos[2], data.pos[3])
        SetBlipSprite(blip, bp.sprite)
        SetBlipDisplay(blip, bp.display)
        SetBlipScale(blip, bp.scale)
        SetBlipColour(blip, bp.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(bp.str)
        EndTextCommandSetBlipName(blip)

        ::continue::
    end
end

local registeredPoints = {}

local function cleanupPoints()
    for index = #registeredPoints, 1, -1 do
        local point = registeredPoints[index]
        hidePrompt(point)

        if point.remove then
            point:remove()
        end
        registeredPoints[index] = nil
    end
end

local function startMining(id, data)
    if miningState.active or data.inUse then return end

    if not lib.callback.await('t1ger_minerjob:getInventoryItem', false, Config.DatabaseItems['pickaxe'], 1) then
        ShowNotify(Lang['no_pickaxe'], 'error')
        return
    end

    miningState.active = true
    TriggerServerEvent('t1ger_minerjob:mineSpotStateSV', id, true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local model = `prop_tool_pickaxe`
    LoadModel(model)

    local animDict = 'melee@hatchet@streamed_core_fps'
    local animClip = 'plyr_front_takedown'
    LoadAnim(animDict)

    local pickaxe = CreateObject(model, 0.0, 0.0, 0.0, true, false, false)
    AttachEntityToEntity(pickaxe, ped, GetPedBoneIndex(ped, 57005), 0.1, 0.0, 0.0, -90.0, 25.0, 35.0, true, true, false, true, 1, true)

    local success = lib.progressCircle({
        duration = 10000,
        label = Lang['pb_mining'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = animDict,
            clip = animClip
        }
    })

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    DeleteObject(pickaxe)
    SetModelAsNoLongerNeeded(model)

    if success then
        local amount = math.random(Config.MiningReward.min, Config.MiningReward.max)
        TriggerServerEvent('t1ger_minerjob:miningReward', Config.DatabaseItems['stone'], amount)
    end

    TriggerServerEvent('t1ger_minerjob:mineSpotStateSV', id, false)
    miningState.active = false
end

local function startWashing(id, data)
    if washingState.active then return end

    if not lib.callback.await('t1ger_minerjob:getInventoryItem', false, Config.DatabaseItems['washpan'], 1) then
        ShowNotify(Lang['no_washpan'], 'error')
        return
    end

    if not lib.callback.await('t1ger_minerjob:removeItem', false, Config.DatabaseItems['stone'], Config.WashSettings.input) then
        ShowNotify(Lang['not_enough_stone'], 'error')
        return
    end

    washingState.active = true

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)

    local success = lib.progressCircle({
        duration = 10000,
        label = Lang['pb_washing'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if success then
        local amount = math.random(Config.WashSettings.output.min, Config.WashSettings.output.max)
        TriggerServerEvent('t1ger_minerjob:washingReward', Config.DatabaseItems['washed_stone'], amount)
    end

    washingState.active = false
end

local function startSmelting(id, data)
    if smeltingState.active then return end

    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance < 0.7 then
        ShowNotify(Lang['player_too_close'], 'error')
        return
    end

    if not lib.callback.await('t1ger_minerjob:removeItem', false, Config.DatabaseItems['washed_stone'], Config.SmeltingSettings.input) then
        ShowNotify(Lang['not_enough_washed_stone'], 'error')
        return
    end

    smeltingState.active = true

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local success = lib.progressCircle({
        duration = 10000,
        label = Lang['pb_smelting'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if success then
        TriggerServerEvent('t1ger_minerjob:smeltingReward')
    end

    smeltingState.active = false
end

local function registerInteraction(points, handler, state, config)
    for id, data in pairs(config) do
        local coords = vec3(data.pos[1], data.pos[2], data.pos[3])
        local point = lib.points.new({
            coords = coords,
            distance = data.marker and data.marker.drawDist or 5.0,
            onExit = function(self)
                hidePrompt(self)
            end,
            nearby = function(self)
                if data.marker and data.marker.enable then
                    DrawMarker(
                        data.marker.type,
                        coords.x,
                        coords.y,
                        coords.z - 0.975,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        data.marker.scale.x,
                        data.marker.scale.y,
                        data.marker.scale.z,
                        data.marker.color.r,
                        data.marker.color.g,
                        data.marker.color.b,
                        data.marker.color.a,
                        false,
                        true,
                        2,
                        false,
                        false,
                        false,
                        false
                    )
                end

                if self.currentDistance <= 1.5 and not state.active and not data.inUse then
                    local prompt = ('[%s] %s'):format(KeyString(data.keybind or 38), sanitizePrompt(data.drawText or 'Interact'))
                    showPrompt(self, prompt)

                    if IsControlJustReleased(0, data.keybind or 38) then
                        handler(id, data)
                    end
                else
                    hidePrompt(self)
                end
            end
        })

        points[#points + 1] = point
    end
end

CreateThread(function()
    createBlips(Config.Mining)
    createBlips(Config.Washing)
    createBlips(Config.Smelting)
end)

registerInteraction(registeredPoints, startMining, miningState, Config.Mining)
registerInteraction(registeredPoints, startWashing, washingState, Config.Washing)
registerInteraction(registeredPoints, startSmelting, smeltingState, Config.Smelting)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    cleanupPoints()
    lib.hideTextUI()
end)

RegisterNetEvent('t1ger_minerjob:mineSpotStateCL', function(id, state)
    if Config.Mining[id] then
        Config.Mining[id].inUse = state
    end
end)
