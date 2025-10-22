-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

local QBCore = exports['qb-core']:GetCoreObject()

local lib = lib or exports.ox_lib
local cache = lib.cache

local player = cache.ped
local coords = cache.coords
local vehicle = cache.vehicle

lib.onCache('ped', function(value)
    player = value or player
end)

lib.onCache('coords', function(value)
    coords = value or coords
end)

lib.onCache('vehicle', function(value)
    if value == false then value = nil end
    vehicle = value
end)

local callbackCache = {}

local function buildCallbackKey(name, ...)
    local key = name
    local args = select('#', ...)
    if args > 0 then
        for index = 1, args do
            local argument = select(index, ...)
            key = ('%s:%s'):format(key, tostring(argument))
        end
    end
    return key
end

local function awaitServerCallback(name, ...)
    if not lib or not lib.callback or not lib.callback.await then return end
    return lib.callback.await(name, false, ...)
end

local function awaitServerCallbackCached(name, ttl, ...)
    if not lib or not lib.callback or not lib.callback.await then return end

    local cacheKey = buildCallbackKey(name, ...)
    local entry = callbackCache[cacheKey]
    local now = GetGameTimer()

    if entry and now <= entry.expires then
        return table.unpack(entry.value)
    end

    local result = { lib.callback.await(name, false, ...) }
    local expiresAt = ttl and (now + ttl) or math.huge
    callbackCache[cacheKey] = { value = result, expires = expiresAt }

    return table.unpack(result)
end

local function invalidateCallbackCache(name)
    for key in pairs(callbackCache) do
        if key:sub(1, #name) == name then
            callbackCache[key] = nil
        end
    end
end

local deliveryCompanies = {}
local companyBlips = {}
local isOwner = 0
local deliveryID = 0

local interactionPoints = {
    highValue = {},
    parcel = {},
    refill = {},
    hud = {}
}

local function removePointEntry(entry)
    if not entry then return end
    if type(entry) == 'table' and entry.remove then
        entry:remove()
        return
    end

    if type(entry) == 'table' then
        for key, value in pairs(entry) do
            removePointEntry(value)
            entry[key] = nil
        end
    end
end

local function clearInteractionGroup(group)
    local bucket = interactionPoints[group]
    if not bucket then return end
    for key, point in pairs(bucket) do
        removePointEntry(point)
        bucket[key] = nil
    end
end

local function clearAllInteractionPoints()
    for group in pairs(interactionPoints) do
        clearInteractionGroup(group)
    end
end

local function resetHighValueRoutes()
    if not deliveryCache.num then return end
    if not Config.HighValueJobs or not Config.HighValueJobs[deliveryCache.num] then return end
    local routes = Config.HighValueJobs[deliveryCache.num].route
    if not routes then return end
    for _, entry in ipairs(routes) do
        entry.done = false
    end
end

local function startHighValueDeliveryHandlers(val, jobValue, shopOrder, trailerModel)
    if not lib or not lib.points then return end

    local baseMarker = val.refill.marker
    local baseCoords = vec3(val.refill.pos.x, val.refill.pos.y, val.refill.pos.z)

    local function spawnTrailerIfNeeded()
        if DoesEntityExist(jobVehicle) and not deliveryCache.trailerSpawned then
            SpawnTruckTrailer(trailerModel, val.trailerSpawn, val.trailerSpawn.w)
            deliveryCache.trailerSpawned = true
        end
    end

    local function spawnBaseForklift()
        if deliveryCache.forkliftSpawned then return end

        local spawn = val.forklift
        spawnVehicle(spawn.model, vector3(spawn.pos.x, spawn.pos.y, spawn.pos.z), spawn.pos.w, nil, function(veh)
            SetEntityCoordsNoOffset(veh, spawn.pos.x, spawn.pos.y, spawn.pos.z)
            SetEntityHeading(veh, spawn.pos.w)
            SetVehicleOnGroundProperly(veh)
            SetEntityAsMissionEntity(veh, true, true)
            jobForklift = veh
            if Config.T1GER_Keys then
                local vehicle_plate = tostring(GetVehicleNumberPlateText(veh))
                local vehicle_name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                exports['t1ger_keys']:SetVehicleLocked(veh, 0)
                exports['t1ger_keys']:GiveJobKeys(vehicle_plate, vehicle_name, true)
            end
        end)

        deliveryCache.forkliftSpawned = true
    end

    interactionPoints.highValue.base = lib.points.new({
        coords = baseCoords,
        distance = math.max(baseMarker.dist, 25.0),
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('highValue')
                return
            end

            spawnTrailerIfNeeded()
            spawnBaseForklift()

            if not DoesEntityExist(jobForklift) then
                return
            end

            if not deliveryCache.traillerFilledUp then
                DrawMarker(baseMarker.type, baseCoords.x, baseCoords.y, baseCoords.z-0.965, 0, 0, 0, 180.0, 0, 0, baseMarker.scale.x, baseMarker.scale.y, baseMarker.scale.z, baseMarker.color.r, baseMarker.color.g, baseMarker.color.b, baseMarker.color.a, false, true, 2)
                local distance = point.currentDistance or #(coords - baseCoords)
                if distance < 3.5 then
                    T1GER_DrawTxt(baseCoords.x, baseCoords.y, baseCoords.z+0.8, Lang['draw_fill_up_trailer'])
                    if IsControlJustPressed(0, Config.KeyControls['fill_up_trailer']) then
                        local ped = player
                        local curVeh = vehicle or GetVehiclePedIsIn(ped, false)
                        if curVeh ~= 0 then
                            if GetEntityModel(curVeh) == GetEntityModel(jobForklift) then
                                ForkliftIntoTruck(val.cargo.pos, val.cargo.marker, Config.HighValueJobs[deliveryCache.num].prop, deliveryCache.jobValue)
                            else
                                TriggerEvent('t1ger_deliveries:notify', Lang['forklift_mismatch'])
                            end
                        else
                            TriggerEvent('t1ger_deliveries:notify', Lang['not_inside_forklift'])
                        end
                    end
                end
                return
            end

            if deliveryCache.truckingStarted then
                removePointEntry(interactionPoints.highValue.base)
                interactionPoints.highValue.base = nil
                return
            end

            local trailer = jobTrailer
            if not DoesEntityExist(trailer) then return end

            local dimensions = GetModelDimensions(GetEntityModel(trailer))
            local trunk = GetOffsetFromEntityInWorldCoords(trailer, 0.0, dimensions['y']-2.0, -0.9)
            local trunkDistance = #(coords - trunk)

            if trunkDistance > 5.0 then
                DrawMissionText(Lang['forklift_into_trailer'])
                return
            end

            T1GER_DrawTxt(trunk.x, trunk.y, trunk.z, Lang['draw_park_forklift'])
            if IsControlJustPressed(0, Config.KeyControls['park_forklift']) then
                DoScreenFadeOut(1000)
                while not IsScreenFadedOut() do
                    Wait(0)
                end
                Wait(150)
                DeleteVehicle(jobForklift)
                jobForklift = nil
                SetVehicleDoorShut(trailer, 5, true)
                SetVehicleDoorShut(trailer, 6, true)
                SetVehicleDoorShut(trailer, 7, true)
                deliveryCache.truckingStarted = true
                DoScreenFadeIn(1000)
                Wait(100)
                TriggerEvent('t1ger_deliveries:notify', Lang['trailer_filled_up'])
                SetTruckingRoute()
            end
        end
    })

    interactionPoints.highValue.dropoff = lib.points.new({
        coords = vec3(val.menu.x, val.menu.y, val.menu.z),
        distance = 35.0,
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('highValue')
                return
            end

            if not deliveryCache.truckingStarted then
                return
            end

            if deliveryCache.dropOffPos and deliveryCache.dropOffPos.x then
                point:setCoords(vec3(deliveryCache.dropOffPos.x, deliveryCache.dropOffPos.y, deliveryCache.dropOffPos.z))
            end

            local playerPed = player
            local playerCoords = coords
            local dropOff = deliveryCache.dropOffPos
            if not dropOff or not dropOff.x then
                return
            end

            local dropVector = vector3(dropOff.x, dropOff.y, dropOff.z)

            if deliveryCache.deliveredPallets < deliveryCache.maxPallets and not deliveryCache.forkliftTaken and not deliveryCache.onGoingDelivery then
                local mk = val.refill.marker
                if #(playerCoords - dropVector) < 25.0 then
                    if IsPedInAnyVehicle(playerPed) then
                        DrawMissionText(Lang['park_instrunctions'])
                        DrawMarker(30, dropVector.x, dropVector.y, dropVector.z, 0, 0, 0, dropOff.w, 0, 0, mk.scale.x+1.0, mk.scale.y+1.0, mk.scale.z+1.0, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, false, 2)
                    else
                        DrawMissionText(Lang['forklift_out_trailer'])
                        local mk5 = val.forklift.marker
                        DrawMarker(mk5.type, dropVector.x, dropVector.y, dropVector.z, 0, 0, 0, dropOff.w, 0, 0, mk5.scale.x, mk5.scale.y, mk5.scale.z, mk5.color.r, mk5.color.g, mk5.color.b, mk5.color.a, false, false, 2)
                        if #(playerCoords - dropVector) < 3.5 then
                            T1GER_DrawTxt(dropVector.x, dropVector.y, dropVector.z, Lang['draw_take_forklift'])
                            if IsControlJustPressed(0, Config.KeyControls['take_forklift']) then
                                deliveryCache.forkliftTaken = true
                                deliveryCache.onGoingDelivery = true
                                local trailer = jobTrailer
                                if DoesEntityExist(trailer) then
                                    SetVehicleDoorOpen(trailer, 5, false, false)
                                    SetVehicleDoorOpen(trailer, 6, false, false)
                                    SetVehicleDoorOpen(trailer, 7, false, false)
                                end
                                spawnVehicle(val.forklift.model, vector3(dropVector.x, dropVector.y, dropVector.z), dropOff.w, nil, function(veh)
                                    SetEntityAsMissionEntity(veh, true, true)
                                    jobForklift = veh
                                    if Config.T1GER_Keys then
                                        local vehicle_plate = tostring(GetVehicleNumberPlateText(veh))
                                        local vehicle_name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                                        exports['t1ger_keys']:SetVehicleLocked(veh, 0)
                                        exports['t1ger_keys']:GiveJobKeys(vehicle_plate, vehicle_name, true)
                                    end
                                end)
                            end
                        end
                    end
                end
            end

            if deliveryCache.onGoingDelivery and DoesEntityExist(jobForklift) and deliveryCache.forkliftTaken then
                local mk = val.forklift.marker
                local pallet = deliveryCache.dropOffPallet
                if pallet and pallet.x then
                    local palletCoords = vector3(pallet.x, pallet.y, pallet.z)
                    if #(playerCoords - palletCoords) < 30.0 then
                        DrawMarker(mk.type, palletCoords.x, palletCoords.y, palletCoords.z+0.2, 0, 0, 0, pallet.w, 0, 0, mk.scale.x+1.0, mk.scale.y+1.0, mk.scale.z+1.0, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, false, 2)
                        DrawMissionText(Lang['pick_up_pallet'])
                        if #(playerCoords - palletCoords) < 3.5 then
                            local curVeh = vehicle or GetVehiclePedIsIn(playerPed, false)
                            if curVeh ~= 0 then
                                if GetEntityModel(curVeh) == GetEntityModel(jobForklift) then
                                    if not deliveryCache.curPallet_state then
                                        T1GER_DrawTxt(palletCoords.x, palletCoords.y, palletCoords.z, Lang['draw_pick_up_pallet'])
                                        if IsControlJustPressed(0, Config.KeyControls['take_forklift']) then
                                            deliveryCache.curPallet_state = true
                                            ForkliftPalletDelivery(pallet.prop, pallet)
                                        end
                                    end
                                else
                                    TriggerEvent('t1ger_deliveries:notify', Lang['forklift_mismatch'])
                                end
                            else
                                TriggerEvent('t1ger_deliveries:notify', Lang['not_inside_forklift'])
                            end
                        end
                    end
                end
            end

            if deliveryCache.palletDelivered then
                local mk = val.forklift.marker
                local pallet = deliveryCache.dropOffPallet
                if pallet and pallet.x then
                    local palletCoords = vector3(pallet.x, pallet.y, pallet.z)
                    if #(playerCoords - palletCoords) < 30.0 then
                        DrawMarker(mk.type, palletCoords.x, palletCoords.y, palletCoords.z+0.2, 0, 0, 0, pallet.w, 0, 0, mk.scale.x+1.0, mk.scale.y+1.0, mk.scale.z+1.0, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, false, 2)
                        DrawMissionText(Lang['forklift_back_truck'])
                        if #(playerCoords - palletCoords) < 5.0 and not IsPedInAnyVehicle(playerPed) then
                            T1GER_DrawTxt(palletCoords.x, palletCoords.y, palletCoords.z, Lang['draw_return_forklift'])
                            if IsControlJustPressed(0, Config.KeyControls['take_forklift']) then
                                deliveryCache.onGoingDelivery = false
                                deliveryCache.forkliftTaken = false
                                deliveryCache.palletDelivered = false
                                if DoesEntityExist(jobForklift) then
                                    DeleteVehicle(jobForklift)
                                end
                                jobForklift = nil
                                local trailer = jobTrailer
                                if DoesEntityExist(trailer) then
                                    SetVehicleDoorShut(trailer, 5, true)
                                    SetVehicleDoorShut(trailer, 6, true)
                                    SetVehicleDoorShut(trailer, 7, true)
                                end
                                PalletDeliveryPay()
                                if deliveryCache.currentRoute and Config.HighValueJobs and Config.HighValueJobs[deliveryCache.num] and Config.HighValueJobs[deliveryCache.num].route then
                                    local current = Config.HighValueJobs[deliveryCache.num].route[deliveryCache.currentRoute]
                                    if current then current.done = true end
                                end
                                deliveryCache.deliveredPallets = deliveryCache.deliveredPallets + 1
                                if deliveryCache.deliveredPallets == deliveryCache.maxPallets then
                                    TriggerEvent('t1ger_deliveries:notify', Lang['all_pallet_delivered'])
                                    SetReturnBlip(val.menu.x, val.menu.y, val.menu.z)
                                    SetBlipRoute(deliveryCache.blip, true)
                                    deliveryCache.complete = true
                                else
                                    TriggerEvent('t1ger_deliveries:notify', Lang['pallet_delivered'])
                                    SetTruckingRoute()
                                end
                            end
                        end
                    end
                end
            end
        end
    })
end
local function startParcelDeliveryHandlers(val, jobValue, shopOrder)
    if not lib or not lib.points then return end

    local refillMarker = val.refill.marker
    local refillCoords = vec3(val.refill.pos.x, val.refill.pos.y, val.refill.pos.z)
    local deliveryMarker = Config.MarkerSettings['delivery']
    local returnCoords = vec3(val.spawn.x, val.spawn.y, val.spawn.z)

    interactionPoints.parcel.refill = lib.points.new({
        coords = refillCoords,
        distance = refillMarker.dist,
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('parcel')
                return
            end

            if deliveryCache.started then
                removePointEntry(interactionPoints.parcel.refill)
                interactionPoints.parcel.refill = nil
                return
            end

            if not DoesEntityExist(jobVehicle) then return end

            DrawMarker(refillMarker.type, refillCoords.x, refillCoords.y, refillCoords.z-0.965, 0, 0, 0, 180.0, 0, 0, refillMarker.scale.x, refillMarker.scale.y, refillMarker.scale.z, refillMarker.color.r, refillMarker.color.g, refillMarker.color.b, refillMarker.color.a, false, true, 2)

            local distance = point.currentDistance or #(coords - refillCoords)
            if distance >= 3.5 then
                return
            end

            T1GER_DrawTxt(refillCoords.x, refillCoords.y, refillCoords.z+0.8, Lang['draw_fill_up_vehicle'])
            if IsControlJustPressed(0, Config.KeyControls['fill_up_vehicle']) then
                local ped = player
                local curVeh = vehicle or GetVehiclePedIsIn(ped, false)
                if curVeh ~= 0 then
                    if GetEntityModel(curVeh) == GetEntityModel(jobVehicle) then
                        if deliveryCache.jobValue == 1 or deliveryCache.jobValue == 4 then
                            deliveryCache.objProp = Config.ParcelProp
                        elseif deliveryCache.jobValue == 2 then
                            deliveryCache.commerical = math.random(1,#Config.MedValueJobs)
                            deliveryCache.objProp = Config.MedValueJobs[deliveryCache.commerical].prop
                        end
                        RefillJobVehicle(val.cargo.pos, val.cargo.marker, deliveryCache.jobValue, shopOrder)
                    else
                        TriggerEvent('t1ger_deliveries:notify', Lang['job_veh_mismatch'])
                    end
                else
                    TriggerEvent('t1ger_deliveries:notify', Lang['sit_in_job_veh'])
                end
            end
        end
    })

    interactionPoints.parcel.trunk = lib.points.new({
        coords = refillCoords,
        distance = 25.0,
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('parcel')
                return
            end

            if not deliveryCache.started or deliveryCache.parcel ~= nil then
                return
            end

            if not DoesEntityExist(jobVehicle) then return end
            if IsPedInAnyVehicle(player) then return end
            if deliveryCache.deliveredParcels and deliveryCache.deliveredParcels >= deliveryCache.maxDeliveries then return end

            point:setCoords(GetEntityCoords(jobVehicle))
            local dims = GetModelDimensions(GetEntityModel(jobVehicle))
            local trunk = GetOffsetFromEntityInWorldCoords(jobVehicle, 0.0, dims['y']+0.60, 0.0)
            if #(coords - trunk) >= 2.0 then
                return
            end

            T1GER_DrawTxt(trunk.x, trunk.y, trunk.z, Lang['draw_take_parcel'])
            if IsControlJustPressed(0, Config.KeyControls['take_parcel']) then
                SetVehicleDoorOpen(jobVehicle, 2 , false, false)
                SetVehicleDoorOpen(jobVehicle, 3 , false, false)
                Wait(250)
                T1GER_LoadModel(deliveryCache.objProp)
                deliveryCache.parcel = CreateObject(GetHashKey(deliveryCache.objProp), coords.x, coords.y, coords.z, true, true, true)
                AttachEntityToEntity(deliveryCache.parcel, player, GetPedBoneIndex(player, 28422), 0.0, -0.03, 0.0, 5.0, 0.0, 0.0, 1, 1, 0, 1, 0, 1)
                T1GER_LoadAnim('anim@heists@box_carry@')
                TaskPlayAnim(player, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
                Wait(300)
                SetVehicleDoorShut(jobVehicle, 2 , false, true)
                SetVehicleDoorShut(jobVehicle, 3 , false, true)
            end
        end
    })

    interactionPoints.parcel.dropoff = lib.points.new({
        coords = refillCoords,
        distance = 25.0,
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('parcel')
                return
            end

            if not deliveryCache.started or not deliveryCache.parcel then
                return
            end

            local target = deliveryCache.pos
            if not target or not target.x then return end

            point:setCoords(vector3(target.x, target.y, target.z))
            local distance = point.currentDistance or #(coords - vector3(target.x, target.y, target.z))
            if distance >= 20.0 then
                return
            end

            DrawMarker(deliveryMarker.type, target.x, target.y, target.z, 0, 0, 0, 180.0, 0, 0, deliveryMarker.scale.x, deliveryMarker.scale.y, deliveryMarker.scale.z, deliveryMarker.color.r, deliveryMarker.color.g, deliveryMarker.color.b, deliveryMarker.color.a, false, true, 2)

            if distance >= 2.0 then
                return
            end

            T1GER_DrawTxt(target.x, target.y, target.z, Lang['draw_deliver_parcel'])
            if IsControlJustPressed(0, Config.KeyControls['deliver_parcel']) then
                if deliveryCache.deliveredParcels < deliveryCache.maxDeliveries then
                    if IsEntityAttachedToAnyPed(deliveryCache.parcel) then
                        DeleteObject(deliveryCache.parcel)
                        ClearPedTasks(player)
                        deliveryCache.deliveredParcels = (deliveryCache.deliveredParcels or 0) + 1
                        if deliveryCache.jobValue == 1 and deliveryCache.num then
                            Config.LowValueJobs[deliveryCache.num].done = true
                        elseif deliveryCache.jobValue == 2 and deliveryCache.num then
                            Config.MedValueJobs[deliveryCache.commerical].deliveries[deliveryCache.num].done = true
                        end
                        ParcelDeliveryPay()
                        if deliveryCache.deliveredParcels < deliveryCache.maxDeliveries then
                            SetDeliveryRoute(deliveryCache.jobValue)
                            TriggerEvent('t1ger_deliveries:notify', Lang['set_delivery_route'])
                        elseif deliveryCache.deliveredParcels == deliveryCache.maxDeliveries then
                            if DoesBlipExist(deliveryCache.blip) then RemoveBlip(deliveryCache.blip) end
                            TriggerEvent('t1ger_deliveries:notify', Lang['delivery_complete'])
                            if deliveryCache.jobValue == 4 then
                                TriggerServerEvent('t1ger_deliveries:orderDeliveryDone', shopOrder)
                            end
                            SetReturnBlip(returnCoords.x, returnCoords.y, returnCoords.z)
                        end
                        deliveryCache.parcel = nil
                    else
                        TriggerEvent('t1ger_deliveries:notify', Lang['parcel_not_ind_hand'])
                    end
                end
            end
        end
    })

    interactionPoints.parcel.returnPoint = lib.points.new({
        coords = returnCoords,
        distance = refillMarker.dist,
        nearby = function(point)
            if not deliveryCache.started or deliveryCache.parcel ~= nil then
                return
            end

            if deliveryCache.deliveredParcels ~= deliveryCache.maxDeliveries then
                return
            end

            if deliveryCache.complete then
                clearInteractionGroup('parcel')
                return
            end

            if not DoesEntityExist(jobVehicle) then return end

            DrawMarker(refillMarker.type, returnCoords.x, returnCoords.y, returnCoords.z-0.965, 0, 0, 0, 180.0, 0, 0, refillMarker.scale.x, refillMarker.scale.y, refillMarker.scale.z, refillMarker.color.r, refillMarker.color.g, refillMarker.color.b, refillMarker.color.a, false, true, 2)

            local distance = point.currentDistance or #(coords - returnCoords)
            if distance >= 4.0 then
                return
            end

            T1GER_DrawTxt(returnCoords.x, returnCoords.y, returnCoords.z+0.8, Lang['draw_return_vehicle'])
            if IsControlJustPressed(0, Config.KeyControls['return_vehicle']) then
                local ped = player
                local curVeh = vehicle or GetVehiclePedIsIn(ped, false)
                if curVeh > 0 then
                    if GetEntityModel(curVeh) == GetEntityModel(jobVehicle) then
                        ReturnVehAndGetPaycheck()
                    else
                        TriggerEvent('t1ger_deliveries:notify', Lang['job_veh_mismatch'])
                    end
                else
                    TriggerEvent('t1ger_deliveries:notify', Lang['sit_in_job_veh'])
                end
            end
        end
    })

    interactionPoints.hud.parcel = lib.points.new({
        coords = coords,
        distance = 5.0,
        nearby = function(point)
            if not deliveryCache.started or deliveryCache.complete then
                return
            end

            point:setCoords(coords)
            drawRct(0.865, 0.95, 0.1430, 0.035, 0, 0, 0, 80)
            SetTextScale(0.40, 0.40)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 255, 255, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextEntry('STRING')
            SetTextCentre(1)
            local delivered = deliveryCache.deliveredParcels or 0
            local maxDeliveries = tonumber(deliveryCache.maxDeliveries) or 0
            local remaining = math.max(maxDeliveries - delivered, 0)
            AddTextComponentString(('Parcels [%s/%s] | Paycheck [$%s]'):format(comma_value(remaining), maxDeliveries, comma_value(deliveryCache.paycheck or 0)))
            DrawText(0.933,0.9523)
        end
    })
end
local function startRefillObjectHandlers(objCache, objMarker, jobValue, shopOrder, state)
    if not lib or not lib.points then return end

    clearInteractionGroup('refill')

    local currentObj = state.currentObj
    local totalObjects = state.totalObjects
    local drawObjText = state.drawText

    local function finalizeRefill()
        clearInteractionGroup('refill')
        if interactionPoints.hud.refill then
            removePointEntry(interactionPoints.hud.refill)
            interactionPoints.hud.refill = nil
        end
        SetVehicleDoorsLockedForAllPlayers(jobVehicle, false)
        FreezeEntityPosition(jobVehicle, false)
        SetVehicleEngineOn(jobVehicle, true, false, false)
        SetVehicleDoorShut(jobVehicle, 2 , false, true)
        SetVehicleDoorShut(jobVehicle, 3 , false, true)
        deliveryCache.started = true
        deliveryCache.deliveredParcels = 0
        TriggerEvent('t1ger_deliveries:notify', Lang['vehicle_filled_up'])
        if jobValue == 4 then
            SetShopRoute(jobValue, shopOrder)
        else
            SetDeliveryRoute(jobValue)
        end
    end

    for num, data in pairs(objCache) do
        interactionPoints.refill['object_' .. num] = lib.points.new({
            coords = vec3(data.pos.x, data.pos.y, data.pos.z),
            distance = objMarker.dist,
            nearby = function(point)
                if deliveryCache.complete then
                    clearInteractionGroup('refill')
                    return
                end

                local cacheEntry = objCache[num]
                if not cacheEntry then
                    removePointEntry(point)
                    interactionPoints.refill['object_' .. num] = nil
                    return
                end

                if currentObj.state then
                    return
                end

                local entity = cacheEntry.entity
                if not DoesEntityExist(entity) then
                    objCache[num] = nil
                    removePointEntry(point)
                    interactionPoints.refill['object_' .. num] = nil
                    return
                end

                local entityCoords = GetEntityCoords(entity)
                point:setCoords(entityCoords)
                local distance = point.currentDistance or #(coords - entityCoords)

                if distance < objMarker.dist then
                    DrawMarker(objMarker.type, entityCoords.x, entityCoords.y, entityCoords.z, 0, 0, 0, 180.0, 0, 0, objMarker.scale.x, objMarker.scale.y, objMarker.scale.z, objMarker.color.r, objMarker.color.g, objMarker.color.b, objMarker.color.a, false, true, 2)
                    if distance < 1.0 then
                        T1GER_DrawTxt(entityCoords.x, entityCoords.y, entityCoords.z, Lang['draw_pick_up_parcel'])
                        if IsControlJustPressed(0, Config.KeyControls['pick_up_parcel']) then
                            AttachEntityToEntity(entity, player, GetPedBoneIndex(player, 28422), 0.0, -0.03, 0.0, 5.0, 0.0, 0.0, 1, 1, 0, 1, 0, 1)
                            T1GER_LoadAnim('anim@heists@box_carry@')
                            TaskPlayAnim(player, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
                            currentObj.state = true
                            currentObj.num = num
                        end
                    end
                end
            end
        })
    end

    interactionPoints.refill.trunk = lib.points.new({
        coords = GetEntityCoords(jobVehicle),
        distance = 5.0,
        nearby = function(point)
            if deliveryCache.complete then
                clearInteractionGroup('refill')
                return
            end

            if not currentObj.state then
                return
            end

            if not DoesEntityExist(jobVehicle) then
                return
            end

            point:setCoords(GetEntityCoords(jobVehicle))
            local dims = GetModelDimensions(GetEntityModel(jobVehicle))
            local trunk = GetOffsetFromEntityInWorldCoords(jobVehicle, 0.0, dims['y']+0.60, 0.0)
            if #(coords - trunk) >= 2.0 then
                return
            end

            T1GER_DrawTxt(trunk.x, trunk.y, trunk.z, Lang['draw_parcel_in_veh'])
            if IsControlJustPressed(0, Config.KeyControls['parcel_in_veh']) then
                local entry = objCache[currentObj.num]
                if entry and entry.entity and DoesEntityExist(entry.entity) then
                    DeleteObject(entry.entity)
                end
                ClearPedTasks(player)
                objCache[currentObj.num] = nil
                currentObj.state = false
                totalObjects = totalObjects - 1
                if totalObjects <= 0 then
                    finalizeRefill()
                end
            end
        end
    })

    if drawObjText then
        interactionPoints.hud.refill = lib.points.new({
            coords = coords,
            distance = 5.0,
            nearby = function(point)
                if deliveryCache.complete then
                    removePointEntry(interactionPoints.hud.refill)
                    interactionPoints.hud.refill = nil
                    return
                end

                point:setCoords(coords)
                drawRct(0.91, 0.95, 0.07, 0.035, 0, 0, 0, 80)
                SetTextScale(0.40, 0.40)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(255, 255, 255, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextEntry('STRING')
                SetTextCentre(1)
                local maxDeliveries = tonumber(deliveryCache.maxDeliveries) or 0
                local packed = math.max(maxDeliveries - (totalObjects or 0), 0)
                AddTextComponentString(('Parcels [%s/%s]'):format(math.floor(packed), maxDeliveries))
                DrawText(0.945,0.9523)
            end
        })
    end
end

CreateThread(function()
    if not lib or not lib.callback then return end

    local results, cfg, state, id = awaitServerCallbackCached('t1ger_deliveries:setup')
    if results and cfg then
        Config.Companies = cfg
        deliveryCompanies = results
        isOwner = state or 0
        TriggerEvent('t1ger_deliveries:deliveryID', id or 0)
        UpdateCompanyBlips()
        refreshCompanyPoints()
    end
end)

-- Load Companies:
RegisterNetEvent('t1ger_deliveries:loadCompanies')
AddEventHandler('t1ger_deliveries:loadCompanies', function(results, cfg, state, id)
        invalidateCallbackCache('t1ger_deliveries:setup')
        Config.Companies = cfg
        deliveryCompanies = results
        isOwner = state
        TriggerEvent('t1ger_deliveries:deliveryID', id)
        Citizen.Wait(200)
        UpdateCompanyBlips()
        refreshCompanyPoints()
end)

-- Update Companies:
RegisterNetEvent('t1ger_deliveries:syncServices')
AddEventHandler('t1ger_deliveries:syncServices', function(results, cfg)
        invalidateCallbackCache('t1ger_deliveries:setup')
        Config.Companies = cfg
        deliveryCompanies = results
        Citizen.Wait(200)
        UpdateCompanyBlips()
        refreshCompanyPoints()
end)

RegisterNetEvent('t1ger_deliveries:deliveryID')
AddEventHandler('t1ger_deliveries:deliveryID', function(id)
	deliveryID = id
end)

-- function to update blips on map:
function UpdateCompanyBlips()
	for k,v in pairs(companyBlips) do RemoveBlip(v) end
	for i = 1, #Config.Companies do
		if Config.Companies[i].owned then
            CreateCompanyBlip(Config.Companies[i], deliveryCompanies[i])
		else
			CreateCompanyBlip(Config.Companies[i], nil)
		end
	end
end

-- Create Map Blips for Tow Services:
function CreateCompanyBlip(cfg, data)
	local mk = Config.BlipSettings['company']
	local bName = mk.name; if data ~= nil then bName = data.name end
	if mk.enable then
		local blip = AddBlipForCoord(cfg.menu.x, cfg.menu.y, cfg.menu.z)
		SetBlipSprite (blip, mk.sprite)
		SetBlipDisplay(blip, mk.display)
		SetBlipScale  (blip, mk.scale)
		SetBlipColour (blip, mk.color)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(bName)
		EndTextCommandSetBlipName(blip)
		table.insert(companyBlips, blip)
	end
end

local currentMenu, activeContext = nil, nil
local suppressContextClose = false
local menuPoints = {}
local textUIActive = false
local textUIMessage = nil

local function hideMenuTextUI()
    if textUIActive and lib and lib.hideTextUI then
        lib.hideTextUI()
        textUIActive = false
        textUIMessage = nil
    end
end

local function removeCompanyPoints()
    for index, point in pairs(menuPoints) do
        if point and point.remove then
            point:remove()
        end
        menuPoints[index] = nil
    end
end

local function ensureMenuPoint(index, company)
    if not lib or not lib.points or not company or not company.menu then return end

    local coords = vec3(company.menu.x, company.menu.y, company.menu.z)
    menuPoints[index] = lib.points.new({
        coords = coords,
        distance = 20.0,
        onLeave = function()
            hideMenuTextUI()
            if currentMenu and currentMenu == company then
                currentMenu = nil
                closeContext()
            end
        end,
        nearby = function(point)
            local mk = Config.MarkerSettings['menu']
            local distance = point.currentDistance

            if mk and mk.enable and distance >= 2.0 then
                DrawMarker(mk.type, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, nil, nil, false)
            end

            if distance < 1.5 then
                local prompt
                if company.owned == true then
                    if (T1GER_isJob(Config.Society[company.society].name)) or (isOwner == index) then
                        prompt = Lang['draw_company_menu']
                        if IsControlJustPressed(0, Config.KeyControls['company_menu']) then
                            currentMenu = company
                            OpenCompanyMenu(index, company)
                        end
                    else
                        prompt = Lang['draw_company_no_access']
                    end
                else
                    if PlayerData.job and ((T1GER_isJob(Config.Society[company.society].name) and PlayerData.job.isboss ~= true) or (isOwner == 0)) then
                        prompt = Lang['draw_buy_company']:format(comma_value(math.floor(company.price)))
                        if IsControlJustPressed(0, Config.KeyControls['buy_company']) then
                            currentMenu = company
                            PurchaseCompany(index, company)
                        end
                    else
                        prompt = Lang['draw_company_own_one']
                    end
                end

                if prompt then
                    if lib and lib.showTextUI then
                        if not textUIActive or prompt ~= textUIMessage then
                            lib.showTextUI(prompt)
                            textUIActive = true
                            textUIMessage = prompt
                        end
                    else
                        T1GER_DrawTxt(coords.x, coords.y, coords.z, prompt)
                    end
                end
            else
                hideMenuTextUI()
                if currentMenu and currentMenu == company and distance > 2.0 then
                    currentMenu = nil
                    closeContext()
                end
            end
        end
    })
end

local function refreshCompanyPoints()
    removeCompanyPoints()
    if not Config or not Config.Companies then return end
    for index, company in ipairs(Config.Companies) do
        ensureMenuPoint(index, company)
    end
end

local function closeContext(skipCallback)
    if activeContext then
        suppressContextClose = skipCallback or false
        lib.hideContext()
        activeContext = nil
        hideMenuTextUI()
    end
end

local function openContextMenu(id, title, elements, onSelect, onClose)
    local options = {}
    for _, element in ipairs(elements) do
        local option = {
            title = element.label or element.title or 'Option',
            description = element.description,
            icon = element.icon,
            metadata = element.metadata,
            disabled = element.disabled or false,
            arrow = element.arrow ~= false,
            onSelect = function()
                closeContext(true)
                if onSelect then
                    onSelect(element)
                end
            end
        }
        table.insert(options, option)
    end

    lib.registerContext({
        id = id,
        title = title,
        options = options,
        onExit = function()
            if onClose and not suppressContextClose then onClose() end
            suppressContextClose = false
            if activeContext == id then
                activeContext = nil
            end
        end
    })

    lib.showContext(id)
    activeContext = id
end

local function spawnVehicle(model, coords, heading, props, cb)
    if lib and lib.requestModel then
        if not lib.requestModel(model) then return end
    else
        T1GER_LoadModel(model)
    end
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, heading or coords.w or 0.0, true, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    if props then
        QBCore.Functions.SetVehicleProperties(veh, props)
    end
    if cb then cb(veh) end
    SetModelAsNoLongerNeeded(model)
end

local function spawnObject(model, coords, cb)
    if lib and lib.requestModel then
        if not lib.requestModel(model) then return end
    else
        T1GER_LoadModel(model)
    end
    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityAsMissionEntity(object, true, true)
    if cb then cb(object) end
    SetModelAsNoLongerNeeded(model)
end

function PurchaseCompany(id, val)
    closeContext()

    local confirm = lib.alertDialog({
        header = Lang['confirm_purchase_title'] and Lang['confirm_purchase_title']:format(comma_value(math.floor(val.price))) or ('Confirm | Price: $' .. comma_value(math.floor(val.price))),
        content = Lang['confirm_purchase_content'] or Lang['company_purchase_confirm'] or Lang['draw_buy_company']:format(comma_value(math.floor(val.price))),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then
        currentMenu = nil
        return
    end

    local input = lib.inputDialog(Lang['enter_company_name_title'] or 'Enter Company Name', {
        { type = 'input', label = Lang['enter_company_name'] or 'Company Name', required = true, min = 3, max = 32 }
    })

    if not input then
        currentMenu = nil
        return
    end

    local name = tostring(input[1] or '')

    if name == '' then
        TriggerEvent('t1ger_deliveries:notify', Lang['invalid_string'])
        return PurchaseCompany(id, val)
    end

    local purchased = awaitServerCallback('t1ger_deliveries:buyCompany', id, val, name)
    if purchased then
        TriggerEvent('t1ger_deliveries:notify', (Lang['company_purchased']):format(comma_value(math.floor(val.price))))
        isOwner = tonumber(id)
        TriggerServerEvent('t1ger_deliveries:updateCompany', id, val, true, name)
        invalidateCallbackCache('t1ger_deliveries:setup')
        invalidateCallbackCache('t1ger_deliveries:hasCompany')
    else
        TriggerEvent('t1ger_deliveries:notify', Lang['not_enough_money'])
    end

    currentMenu = nil
end

function OpenCompanyMenu(id, val)
    closeContext()
    local elements = {}
    if (T1GER_isJob(Config.Society[val.society].name) and PlayerData.job and PlayerData.job.isboss) or isOwner == id then
        table.insert(elements, { label = Lang['menu_rename_company'] or 'Rename Company', value = 'rename_company' })
        table.insert(elements, { label = Lang['menu_sell_company'] or 'Sell Company', value = 'sell_company' })
        table.insert(elements, { label = Lang['menu_boss'] or 'Boss Menu', value = 'boss_menu' })
        table.insert(elements, { label = Lang['menu_company_level'] or 'Company Level', value = 'company_level' })
    end
    table.insert(elements, { label = Lang['menu_request_job'] or 'Request Job', value = 'request_job' })
    if Config.T1GER_Shops then
        table.insert(elements, { label = Lang['menu_shop_orders'] or 'Shop Orders', value = 'shop_orders' })
    end

    openContextMenu(('t1ger_company_%s'):format(id), (Lang['menu_company_title'] or 'Company [%s]'):format(tostring(id)), elements, function(element)
        local action = element.value

        if action == 'rename_company' then
            RenameCompany(id, val)
        elseif action == 'sell_company' then
            SellCompany(id, val)
        elseif action == 'boss_menu' then
            BossMenu(id, val)
        elseif action == 'company_level' then
            CompanyLevel(id, val)
        elseif action == 'request_job' then
            RequestJob(id, val)
        elseif action == 'shop_orders' then
            ShopDeliveries(id, val)
        end
    end, function()
        currentMenu = nil
    end)
end

function RenameCompany(id, val)
    closeContext()
    local input = lib.inputDialog(Lang['rename_company_title'] or 'Enter Company Name', {
        { type = 'input', label = Lang['enter_company_name'] or 'Company Name', required = true, min = 3, max = 32 }
    })

    if not input then
        OpenCompanyMenu(id, val)
        return
    end

    local name = tostring(input[1] or '')

    if name == '' then
        TriggerEvent('t1ger_deliveries:notify', Lang['invalid_string'])
        return RenameCompany(id, val)
    end

    TriggerServerEvent('t1ger_deliveries:updateCompany', id, val, nil, name)
    TriggerEvent('t1ger_deliveries:notify', Lang['company_renamed'])
    OpenCompanyMenu(id, val)
end

function SellCompany(id, val)
    closeContext()
    local sellPrice = (val.price * Config.SalePercentage)
    local confirm = lib.alertDialog({
        header = (Lang['confirm_sale_title'] or 'Confirm Sale | Price: $%s'):format(comma_value(math.floor(sellPrice))),
        content = Lang['confirm_sale_content'] or Lang['company_sell_confirm'] or '',
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('t1ger_deliveries:sellCompany', id, val, math.floor(sellPrice))
        TriggerServerEvent('t1ger_deliveries:updateCompany', id, val, false, nil)
        isOwner = 0
        TriggerEvent('t1ger_deliveries:notify', (Lang['company_sold']):format(comma_value(math.floor(sellPrice))))
        invalidateCallbackCache('t1ger_deliveries:setup')
        invalidateCallbackCache('t1ger_deliveries:hasCompany')
        currentMenu = nil
    else
        OpenCompanyMenu(id, val)
    end
end

function BossMenu(id, val)
    closeContext()
    local cfg = Config.Society[val.society]
    local menuId = ('t1ger_boss_%s'):format(cfg.name)
    local elements = {
        { label = Lang['boss_actions'] or 'Boss Actions', value = 'boss_actions', job = cfg.name },
        { label = Lang['boss_account_balance'] or 'Account Balance', value = 'get_balance', job = cfg.name }
    }

    openContextMenu(menuId, cfg.label, elements, function(element)
        if element.value == 'boss_actions' then
            if cfg.bossMenuEvent then
                TriggerEvent(cfg.bossMenuEvent, element.job)
            else
                TriggerEvent('qb-bossmenu:client:OpenMenu')
            end
        elseif element.value == 'get_balance' then
            local amount = awaitServerCallbackCached('t1ger_deliveries:getSocietyBalance', 5000, element.job)
            if amount then
                TriggerEvent('t1ger_deliveries:notify', Lang['get_account_balance']:format(comma_value(amount)))
            else
                TriggerEvent('t1ger_deliveries:notify', Lang['society_balance_unavailable'] or 'Unable to fetch balance')
            end
        end
    end, function()
        OpenCompanyMenu(id, val)
    end)
end

function CompanyLevel(id, val)
    closeContext()
    local cfg = val.data
    local state = cfg.certificate and (Lang['state_yes'] or 'Yes') or (Lang['state_no'] or 'No')
    local elements = {
        { label = (Lang['has_certificate'] or 'Has Certificate: %s'):format(state), value = 'view_certificate_state' }
    }
    if not cfg.certificate then
        table.insert(elements, { label = Lang['buy_certificate'] or 'Buy Certificate', value = 'buy_certificate' })
    end

    openContextMenu(('t1ger_company_level_%s'):format(id), (Lang['company_level_title'] or 'Company Level: %s'):format(math.floor(cfg.level)), elements, function(element)
        if element.value == 'buy_certificate' then
            local status = awaitServerCallback('t1ger_deliveries:buyCertifcate', id)
            if status == true then
                Config.Companies[id].data.certificate = true
                TriggerEvent('t1ger_deliveries:notify', Lang['certificate_acquired'])
                TriggerServerEvent('t1ger_deliveries:updateCompanyDataSV', id, Config.Companies[id].data)
                invalidateCallbackCache('t1ger_deliveries:setup')
            else
                TriggerEvent('t1ger_deliveries:notify', Lang['not_enough_money'])
            end
            OpenCompanyMenu(id, val)
        end
    end, function()
        OpenCompanyMenu(id, val)
    end)
end

function RequestJob(id, val)
    closeContext()
    local elements = {}
    for k, v in ipairs(Config.JobValues) do
        if k ~= 4 then
            table.insert(elements, {
                label = v.label,
                value = 'job_value',
                jobValue = k,
                level = v.level,
                certificate = v.certificate,
                vehicles = v.vehicles,
                description = (Lang['job_value_description'] or 'Required Level: %s'):format(v.level)
            })
        end
    end

    openContextMenu('t1ger_request_job', Lang['select_job_value'] or 'Select Job Value', elements, function(element)
        if val.data.level >= element.level then
            if not element.certificate or val.data.certificate then
                SelectJobVehicle(element.jobValue, element.label, element.level, element.certificate, element.vehicles, nil, id, val)
            else
                TriggerEvent('t1ger_deliveries:notify', Lang['job_needs_certificate'])
            end
        else
            TriggerEvent('t1ger_deliveries:notify', Lang['job_level_mismatch'])
        end
    end, function()
        OpenCompanyMenu(id, val)
    end)
end

function ShopDeliveries(id, val)
    closeContext()
    local elements = {}
    local orders = awaitServerCallbackCached('t1ger_deliveries:getShopOrders', 7500) or {}
    local job = Config.JobValues[4]
    if next(orders) then
        for _, v in pairs(orders) do
            if v.taken == false then
                table.insert(elements, {
                    label = (Lang['shop_order_label'] or 'Order to Shop [%s]'):format(v.shopID),
                    shopOrder = v,
                    jobValue = 4,
                    jobName = job.label,
                    level = job.level,
                    certificate = job.certificate,
                    vehicles = job.vehicles,
                    description = (Lang['job_value_description'] or 'Required Level: %s'):format(job.level)
                })
            end
        end
    end

    if not next(elements) then
        TriggerEvent('t1ger_deliveries:notify', Lang['no_available_orders'])
        OpenCompanyMenu(id, val)
        return
    end

    openContextMenu('t1ger_shop_orders', Lang['available_orders'] or 'Available Orders', elements, function(element)
        if val.data.level >= element.level then
            if not element.certificate or val.data.certificate then
                SelectJobVehicle(element.jobValue, element.jobName, element.level, element.certificate, element.vehicles, element.shopOrder, id, val)
            else
                TriggerEvent('t1ger_deliveries:notify', Lang['job_needs_certificate'])
            end
        else
            TriggerEvent('t1ger_deliveries:notify', Lang['job_level_mismatch'])
        end
    end, function()
        OpenCompanyMenu(id, val)
    end)
end

local jobVehicle = nil
local jobTrailer, jobForklift = nil, nil
local vehicle_deposit = 0
local deliveryCache = {}

function SelectJobVehicle(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
    closeContext()
    local elements = {
        { label = Lang['society_vehicles'] or 'Society Vehicles', value = 'society_vehicles' },
        { label = Lang['rent_vehicles'] or 'Rent Vehicles', value = 'rent_vehicles' }
    }

    openContextMenu('t1ger_select_job_vehicle', Lang['select_job_vehicle'] or 'Select Job Vehicle', elements, function(element)
        if element.value == 'society_vehicles' then
            SocietyVehicles(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
        elseif element.value == 'rent_vehicles' then
            RentVehicle(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
        end
    end, function()
        RequestJob(id, val)
    end)
end

function SocietyVehicles(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
    closeContext()
    local elements = {}
    local results = awaitServerCallbackCached('t1ger_deliveries:getSocietyVehicles', 10000, Config.Society[val.society].name) or {}
    if next(results) then
        local storage = Config.SocietyVehicleStorage or {}
        local propsColumn = storage.propsColumn or 'vehicle'
        for _, v in pairs(results) do
            local storedProps = v[propsColumn] or v.vehicle
            local props = storedProps and json.decode(storedProps) or nil
            local available = v.state == true or v.state == 1 or v[storage.stateColumn] == storage.availableState or storage.stateColumn == nil
            if props and available then
                local vehName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
                table.insert(elements, {
                    label = ('%s [%s]'):format(vehName, v.plate or (props.plate or 'UNKNOWN')),
                    name = vehName,
                    model = props.model,
                    props = props
                })
            end
        end
    end

    if not next(elements) then
        TriggerEvent('t1ger_deliveries:notify', Lang['no_society_vehicles'] or 'No Owned Society Vehicles.')
        RequestJob(id, val)
        return
    end

    openContextMenu('t1ger_society_vehicle', Lang['select_society_vehicle'] or 'Select Society Vehicle', elements, function(element)
        vehicle_deposit = nil
        TriggerEvent('t1ger_deliveries:notify', Lang['society_vehicle_taken'] or 'Society Owned Vehicle Taken Out')
        SpawnJobVehicle(element.model, val.spawn, val.spawn.w, element.props)
        invalidateCallbackCache('t1ger_deliveries:getSocietyVehicles')
        Wait(500)
        if jobValue == 1 or jobValue == 2 then
            TriggerEvent('t1ger_deliveries:parcelDelivery', id, val, jobValue, nil)
        elseif jobValue == 3 then
            TriggerEvent('t1ger_deliveries:highValueDelivery', id, val, jobValue)
        elseif jobValue == 4 then
            TriggerServerEvent('t1ger_deliveries:updateOrderState', shopOrder, true)
            invalidateCallbackCache('t1ger_deliveries:getShopOrders')
            TriggerEvent('t1ger_deliveries:parcelDelivery', id, val, jobValue, shopOrder)
        end
    end, function()
        SelectJobVehicle(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
    end)
end

function RentVehicle(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
    closeContext()
    local elements = {}
    for _, v in ipairs(vehicles) do
        table.insert(elements, {
            label = ('%s [%s $%s]'):format(v.name, Lang['deposit_short'] or 'Deposit', comma_value(v.deposit)),
            name = v.name,
            model = v.model,
            deposit = v.deposit
        })
    end

    openContextMenu('t1ger_rent_vehicle', Lang['select_rental_vehicle'] or 'Select Rental Vehicle', elements, function(element)
        local paid = awaitServerCallback('t1ger_deliveries:payVehicleDeposit', element.deposit)
        if paid then
            vehicle_deposit = element.deposit
            TriggerEvent('t1ger_deliveries:notify', Lang['deposit_veh_paid']:format(element.deposit))
            SpawnJobVehicle(element.model, val.spawn, val.spawn.w)
            invalidateCallbackCache('t1ger_deliveries:getSocietyVehicles')
            Wait(500)
            if jobValue == 1 or jobValue == 2 then
                TriggerEvent('t1ger_deliveries:parcelDelivery', id, val, jobValue, nil)
            elseif jobValue == 3 then
                TriggerEvent('t1ger_deliveries:highValueDelivery', id, val, jobValue)
            elseif jobValue == 4 then
                TriggerServerEvent('t1ger_deliveries:updateOrderState', shopOrder, true)
                invalidateCallbackCache('t1ger_deliveries:getShopOrders')
                TriggerEvent('t1ger_deliveries:parcelDelivery', id, val, jobValue, shopOrder)
            end
        else
            TriggerEvent('t1ger_deliveries:notify', Lang['not_enough_to_deposit'])
        end
    end, function()
        SelectJobVehicle(jobValue, label, level, certificate, vehicles, shopOrder, id, val)
    end)
end

-- ## HIGH VALUE JOBS ## --
RegisterNetEvent('t1ger_deliveries:highValueDelivery')
AddEventHandler('t1ger_deliveries:highValueDelivery', function(id, val, jobValue, shopOrder)
	deliveryCache.complete = false
	deliveryCache.paycheck = 0
	deliveryCache.id = id
	deliveryCache.val = val
	deliveryCache.num = math.random(1,#Config.HighValueJobs)
	local trailerModel = Config.HighValueJobs[deliveryCache.num].trailer
	deliveryCache.jobValue = jobValue
	deliveryCache.forkliftTaken = false
	deliveryCache.palletDelivered = false
	deliveryCache.curPallet_state = false
	deliveryCache.onGoingDelivery = false
	deliveryCache.dropOffPos = {}
	deliveryCache.dropOffPallet = {}
	deliveryCache.currentRoute = 0
	deliveryCache.truckHealth = 0
	deliveryCache.palletPrice = 0
	deliveryCache.deliveredPallets = 0
	deliveryCache.palletObjEntity = nil
	deliveryCache.isHighValue = true
	resetHighValueRoutes()

	clearInteractionGroup('highValue')
	clearInteractionGroup('refill')

	startHighValueDeliveryHandlers(val, jobValue, shopOrder, trailerModel)
end)

-- ## LOW & MEDIUM VALUE JOBS ## --
RegisterNetEvent('t1ger_deliveries:parcelDelivery')
AddEventHandler('t1ger_deliveries:parcelDelivery', function(id, val, jobValue, shopOrder)
	deliveryCache.complete = false
	deliveryCache.started = false
	deliveryCache.jobValue = jobValue
	deliveryCache.paycheck = 0
	deliveryCache.id = id
	deliveryCache.val = val

	clearInteractionGroup('parcel')
	clearInteractionGroup('refill')

	startParcelDeliveryHandlers(val, jobValue, shopOrder)
end)



function RefillJobVehicle(objSpots, objMarker, jobValue, shopOrder)
	local objCache = {}
	SetVehicleEngineOn(jobVehicle, false, false, false)
	SetVehicleDoorOpen(jobVehicle, 2 , false, false)
	SetVehicleDoorOpen(jobVehicle, 3 , false, false)
	if IsPedInAnyVehicle(player, true) then
		TaskLeaveVehicle(player, jobVehicle, 4160)
		SetVehicleDoorsLockedForAllPlayers(jobVehicle, true)
	end
	Wait(500)
	FreezeEntityPosition(jobVehicle, true)
	if jobValue == 4 then
		deliveryCache.maxDeliveries = 1
	else
		deliveryCache.maxDeliveries = #objSpots
	end
	local currentObj = { state = false, num = nil }
	local totalObjects = jobValue == 4 and 1 or #objSpots
	for num, v in pairs(objSpots) do
		local entity = CreateObject(GetHashKey(deliveryCache.objProp), v.x, v.y, v.z-0.965, true, true, true)
		objCache[num] = { entity = entity, pos = v }
		PlaceObjectOnGroundProperly(entity)
		if jobValue == 4 then break end
	end
	startRefillObjectHandlers(objCache, objMarker, jobValue, shopOrder, {
		currentObj = currentObj,
		totalObjects = totalObjects,
		drawText = true
	})
end



function SetShopRoute(jobValue, shopOrder)
	deliveryCache.pos = vector3(shopOrder.pos[1], shopOrder.pos[2], shopOrder.pos[3])
	SetDeliveryBlip(deliveryCache.pos.x, deliveryCache.pos.y, deliveryCache.pos.z)
	deliveryCache.vehHealth = GetVehicleBodyHealth(jobVehicle)
	deliveryCache.parcelPrice = CalculatePrice(jobValue)
end

function SetDeliveryRoute(jobValue)
	local id = 0
	if jobValue == 1 then 
		id = math.random(#Config.LowValueJobs)
		while Config.LowValueJobs[id].done do 
			id = math.random(#Config.LowValueJobs)
		end
		deliveryCache.pos = Config.LowValueJobs[id].pos
	elseif jobValue == 2 then 
		id = math.random(#Config.MedValueJobs[deliveryCache.commerical].deliveries)
		while Config.MedValueJobs[deliveryCache.commerical].deliveries[id].done do 
			id = math.random(#Config.MedValueJobs[deliveryCache.commerical].deliveries)
		end
		deliveryCache.pos = Config.MedValueJobs[deliveryCache.commerical].deliveries[id].pos
	end
	deliveryCache.num = id
	SetDeliveryBlip(deliveryCache.pos.x, deliveryCache.pos.y, deliveryCache.pos.z)
	deliveryCache.vehHealth = GetVehicleBodyHealth(jobVehicle)
	deliveryCache.parcelPrice = CalculatePrice(jobValue)
end

function SetDeliveryBlip(x,y,z)
	if DoesBlipExist(deliveryCache.blip) then RemoveBlip(deliveryCache.blip) end
	deliveryCache.blip = AddBlipForCoord(x,y,z)
	SetBlipSprite(deliveryCache.blip, 501)
	SetBlipColour(deliveryCache.blip, 5)
	SetBlipRoute(deliveryCache.blip, true)
	SetBlipScale(deliveryCache.blip, 0.7)
	SetBlipAsShortRange(deliveryCache.blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(Lang['delivery_blip'])
	EndTextCommandSetBlipName(deliveryCache.blip)
end

-- Adjust pricing here:
function CalculatePrice(level)
	local reward = Config.Reward
	math.randomseed(GetGameTimer())
	local random = math.random(reward.min,reward.max)
	local packagePrice = (random * (((reward.valueAddition[level])/100) + 1)) 
	return math.floor(packagePrice)
end

function ParcelDeliveryPay()
	local newVehBody = GetVehicleBodyHealth(jobVehicle)
	local dmgPercent = (1-(Config.DamagePercent/100))
	if newVehBody < (deliveryCache.vehHealth*dmgPercent) then 
		TriggerEvent('t1ger_deliveries:notify', Lang['parcel_damaged_transit'])
		deliveryCache.paycheck = deliveryCache.paycheck
	else
		deliveryCache.paycheck = deliveryCache.paycheck + deliveryCache.parcelPrice
		TriggerEvent('t1ger_deliveries:notify', Lang['paycheck_add_amount']:format(deliveryCache.parcelPrice))
	end
end

function ReturnVehAndGetPaycheck()
        if DoesBlipExist(deliveryCache.blip) then RemoveBlip(deliveryCache.blip) end
        SetVehicleEngineOn(jobVehicle, false, false, false)
        if IsPedInAnyVehicle(player, true) then
                TaskLeaveVehicle(player, jobVehicle, 4160)
		SetVehicleDoorsLockedForAllPlayers(jobVehicle, true)
	end
	local newVehBody = GetVehicleBodyHealth(jobVehicle)
	Citizen.Wait(500)
	FreezeEntityPosition(jobVehicle, true)
	local giveDeposit = false
	local dmgDeposit = (1-(Config.DepositDamage/100))
	if newVehBody < (1000*dmgDeposit) then 
		giveDeposit = false
		TriggerEvent('t1ger_deliveries:notify', Lang['deposit_not_returned'])
	else
		giveDeposit = true
	end
	if vehicle_deposit == nil then 
		giveDeposit = false
	end
        DeleteVehicle(jobVehicle)
        if DoesEntityExist(jobTrailer) then DeleteVehicle(jobTrailer) end
        TriggerServerEvent('t1ger_deliveries:retrievePaycheck', deliveryCache.paycheck, vehicle_deposit, giveDeposit, deliveryCache.id, deliveryCache.val)
        invalidateCallbackCache('t1ger_deliveries:getSocietyVehicles')
        if deliveryCache.isHighValue then
            resetHighValueRoutes()
            deliveryCache.isHighValue = nil
        end
        clearAllInteractionPoints()
        deliveryCache.complete = true
end

function SpawnJobVehicle(model, pos, heading, props)
        spawnVehicle(model, vector3(pos.x, pos.y, pos.z), heading, props, function(veh)
                SetEntityCoordsNoOffset(veh, pos.x, pos.y, pos.z)
                SetEntityHeading(veh, heading)
                SetVehicleOnGroundProperly(veh)
                SetEntityAsMissionEntity(veh, true, true)
                jobVehicle = veh
                if Config.T1GER_Keys then
                        local vehicle_plate = GetVehicleNumberPlateText(jobVehicle)
                        local vehicle_name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(jobVehicle)))
                        exports['t1ger_keys']:SetVehicleLocked(jobVehicle, 0)
                        exports['t1ger_keys']:GiveJobKeys(vehicle_plate, vehicle_name, true)
                end
        end)
        TriggerEvent('t1ger_deliveries:notify', Lang['job_veh_spawned'])
end

function SetReturnBlip(x,y,z)
	if DoesBlipExist(deliveryCache.blip) then RemoveBlip(deliveryCache.blip) end
	deliveryCache.blip = AddBlipForCoord(x,y,z)
	SetBlipSprite(deliveryCache.blip, 164)
	SetBlipColour(deliveryCache.blip, 2)
	SetBlipRoute(deliveryCache.blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(Lang['return_blip'])
	EndTextCommandSetBlipName(deliveryCache.blip)
end

-- Update Companies CFG Data:
RegisterNetEvent('t1ger_deliveries:updateCompanyDataCL')
AddEventHandler('t1ger_deliveries:updateCompanyDataCL', function(id, data)
	Config.Companies[id].data = data
end)

RegisterCommand('canceldelivery', function(source, args)
        deliveryCache.complete = true
        if DoesEntityExist(jobTrailer) then DeleteVehicle(jobTrailer) end
        if DoesEntityExist(jobVehicle) then DeleteVehicle(jobVehicle) end
        if DoesBlipExist(deliveryCache.blip) then RemoveBlip(deliveryCache.blip) end
        clearAllInteractionPoints()
        if deliveryCache.isHighValue then
            resetHighValueRoutes()
            deliveryCache.isHighValue = nil
        end
end, false)

RegisterCommand('deliveryDuty', function(source, args)
        local isBoss = awaitServerCallbackCached('t1ger_deliveries:hasCompany', 10000)
        if isBoss then
                TriggerEvent('t1ger_deliveries:notify', Lang['delivery_duty_boss'] or 'Your job has been set to boss for delivery')
        else
                TriggerEvent('t1ger_deliveries:notify', Lang['delivery_duty_missing'] or 'You do not own any delivery companies to use this function.')
        end
end, false)
