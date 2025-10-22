-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local interacting = false
local hacking, securing, grabbing, safe_drilling = false, false, false, false
local total_cash = 0
local trolley_obj, emptyTrolley_obj, vault_door
local goons, goons_spawned, heist_ply = {}, false, false
local activePrompt

local function toVec3(tbl)
        return vec3(tbl[1], tbl[2], tbl[3])
end

local function showPrompt(point, text)
        if activePrompt and activePrompt ~= point then
                lib.hideTextUI()
                activePrompt.textShown = false
        end
        if not point.textShown then
                lib.showTextUI(text)
                point.textShown = true
                activePrompt = point
        end
end

local function hidePrompt(point)
        if point and point.textShown then
                lib.hideTextUI()
                point.textShown = false
                if activePrompt == point then
                        activePrompt = nil
                end
        end
end

local function applyHeistState(state)
        if not state then return end
        Config.Yacht.cooldown = state.cooldown
        Config.Yacht.terminal.activated = state.terminal.activated
        Config.Yacht.keypad.hacked = state.keypad.hacked
        Config.Yacht.trolley.grabbing = state.trolley.grabbing
        Config.Yacht.trolley.taken = state.trolley.taken
        for i=1, #Config.Safes do
                if state.safes[i] then
                        Config.Safes[i].robbed = state.safes[i].robbed
                        Config.Safes[i].failed = state.safes[i].failed
                end
        end
end

CreateThread(function()
        while not LocalPlayer.state.isLoggedIn do
                Wait(100)
        end
        local state = lib.callback.await('t1ger_yachtheist:getState', false)
        applyHeistState(state)
end)

RegisterNetEvent('t1ger_yachtheist:updateState', function(state)
        applyHeistState(state)
end)

-- ## YACHT ## --
local function startHeist()
        if interacting or Config.Yacht.cooldown or Config.Yacht.terminal.activated or isCop then return end
        interacting = true
        local result = lib.callback.await('t1ger_yachtheist:startHeist', false)
        if result and result.success then
                Config.Yacht.terminal.activated = true
                if Config.ProgressBars then
                        lib.progressCircle({
                                duration = 1000,
                                label = Lang['pb_starting'],
                                position = 'bottom',
                                useWhileDead = false,
                                disable = {move = true, car = true, combat = true}
                        })
                else
                        Wait(1000)
                end
                PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
                PrepareYachtHeist()
        else
                local reason = result and result.reason or (Config.Yacht.cooldown and Lang['yacht_cooldown'] or Lang['yacht_activated'])
                ShowNotify(reason, 'error')
        end
        interacting = false
end

local terminalPoint = lib.points.new({
        coords = toVec3(Config.Yacht.terminal.pos),
        distance = 10.0,
        onEnter = function(self)
                self.textShown = false
        end,
        onExit = function(self)
                hidePrompt(self)
        end,
        nearby = function(self)
                if Config.Yacht.cooldown or Config.Yacht.terminal.activated or isCop then
                        hidePrompt(self)
                        return
                end
                if self.currentDistance <= 2.5 then
                        showPrompt(self, ('[E] %s'):format(Lang['yacht_heist_interact']))
                        if self.currentDistance <= 1.2 and IsControlJustReleased(0, 38) then
                                startHeist()
                        end
                else
                        hidePrompt(self)
                end
        end
})

-- Prepare The Yacht Heist:
local function cachePlayer()
        return cache.ped
end

trolley_obj = nil
emptyTrolley_obj = nil
function PrepareYachtHeist()
        local cfg = Config.Yacht
        local trolley = `hei_prop_hei_cash_trolly_01`
        LoadModel(trolley)
        local trolleyPos = cfg.trolley.pos
        local objCache = GetClosestObjectOfType(trolleyPos[1], trolleyPos[2], trolleyPos[3], 2.0, trolley, false, false, false)
        if objCache ~= 0 then
                SetEntityAsMissionEntity(objCache)
                TriggerServerEvent('t1ger_yachtheist:forceDeleteSV', ObjToNet(objCache))
        end
        Wait(200)
        local object = CreateObject(trolley, trolleyPos[1], trolleyPos[2], trolleyPos[3], true)
        SetEntityRotation(object, 0.0, 0.0, trolleyPos[4]+180.0)
        PlaceObjectOnGroundProperly(object)
        SetEntityAsMissionEntity(object, true, true)
        trolley_obj = ObjToNet(object)
        SetModelAsNoLongerNeeded(trolley)
        TriggerEvent('t1ger_yachtheist:goonsHandler')
end

RegisterNetEvent('t1ger_yachtheist:forceDeleteCL', function(objNet)
        if NetworkHasControlOfNetworkId(objNet) then
                DeleteObject(NetToObj(objNet))
        end
end)

-- Control Vault Door:
CreateThread(function()
        while true do
                Wait(1000)
                local cfg = Config.Yacht
                local doorPos = cfg.vault.pos
                if cachePlayer() ~= 0 then
                        local plyCoords = GetEntityCoords(cachePlayer())
                        local distance = #(plyCoords - vec3(doorPos[1], doorPos[2], doorPos[3]))
                        if distance < 20.0 then
                                if not vault_door or not DoesEntityExist(vault_door) then
                                        vault_door = GetClosestObjectOfType(doorPos[1], doorPos[2], doorPos[3], 1.5, cfg.vault.model, false, false, false)
                                end
                                if vault_door and DoesEntityExist(vault_door) then
                                        FreezeEntityPosition(vault_door, not Config.Yacht.keypad.hacked)
                                end
                                Wait(200)
                        end
                end
        end
end)

-- Event to handle goons
RegisterNetEvent('t1ger_yachtheist:goonsHandler', function()
        ShowNotify(Lang['find_vault_room'])
        local cfg = Config.Yacht
        goons = {}
        goons_spawned = false
        heist_ply = false
        CreateThread(function()
                while Config.Yacht.terminal.activated and not Config.Yacht.cooldown do
                        Wait(400)
                        local ped = cachePlayer()
                        if ped == 0 then goto continue end
                        local plyCoords = GetEntityCoords(ped)
                        local distance = #(plyCoords - toVec3(cfg.keypad.pos))
                        if distance < 100.0 then
                                if not goons_spawned and distance < 80.0 then
                                        ClearAreaOfPeds(cfg.keypad.pos[1], cfg.keypad.pos[2], cfg.keypad.pos[3], 10.0, 1)
                                        AddRelationshipGroup('JobNPCs')
                                        for i = 1, #cfg.goons do
                                                goons[i] = CreateJobPed(cfg.goons[i])
                                        end
                                        goons_spawned = true
                                end
                                if goons_spawned and not heist_ply and distance < 50.0 then
                                        AddRelationshipGroup('JobNPCs')
                                        for i = 1, #goons do
                                                ClearPedTasksImmediately(goons[i])
                                                TaskCombatPed(goons[i], ped, 0, 16)
                                                SetPedFleeAttributes(goons[i], 0, false)
                                                SetPedCombatAttributes(goons[i], 5, true)
                                                SetPedCombatAttributes(goons[i], 16, true)
                                                SetPedCombatAttributes(goons[i], 46, true)
                                                SetPedCombatAttributes(goons[i], 26, true)
                                                SetPedSeeingRange(goons[i], 75.0)
                                                SetPedHearingRange(goons[i], 50.0)
                                                SetPedEnableWeaponBlocking(goons[i], true)
                                        end
                                        SetRelationshipBetweenGroups(0, GetHashKey('JobNPCs'), GetHashKey('JobNPCs'))
                                        SetRelationshipBetweenGroups(5, GetHashKey('JobNPCs'), GetHashKey('PLAYER'))
                                        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('JobNPCs'))
                                        heist_ply = true
                                end
                        end
                        ::continue::
                end
        end)
end)

-- Keypad Hacking
local function SecureHeistFunction(cfg)
        local ped = cachePlayer()
        FreezeEntityPosition(ped, true)
        if Config.ProgressBars then
                lib.progressCircle({
                        duration = 1000,
                        label = Lang['pb_securing'],
                        position = 'bottom',
                        useWhileDead = false,
                        disable = {move = true, car = true, combat = true}
                })
        else
                Wait(1000)
        end
        TriggerServerEvent('t1ger_yachtheist:resetHeistSV')
        Wait(1000)
        TriggerServerEvent('t1ger_yachtheist:PoliceNotifySV', "secure")
        FreezeEntityPosition(ped, false)
        Wait(1000)
        if trolley_obj and NetworkDoesEntityExistWithNetworkId(trolley_obj) then
                local trollyObj_cache = NetToObj(trolley_obj)
                Wait(250)
                while not NetworkHasControlOfEntity(trollyObj_cache) do
                        Wait(10)
                        NetworkRequestControlOfEntity(trollyObj_cache)
                end
                Wait(250)
                DeleteObject(trollyObj_cache)
        end
        Wait(1000)
        if emptyTrolley_obj and NetworkDoesEntityExistWithNetworkId(emptyTrolley_obj) then
                local emptyTrollyObj_cache = NetToObj(emptyTrolley_obj)
                Wait(250)
                while not NetworkHasControlOfEntity(emptyTrollyObj_cache) do
                        Wait(0)
                        NetworkRequestControlOfEntity(emptyTrollyObj_cache)
                end
                Wait(250)
                DeleteObject(emptyTrollyObj_cache)
        end
end

local function KeypadHackFunction(cfg)
        local result = lib.callback.await('t1ger_yachtheist:canHack', false, Config.DatabaseItems['hackerDevice'])
        if not result or not result.success then
                ShowNotify(result and result.reason or Lang['need_hacker_item'], 'error')
                hacking = false
                return
        end
        local ped = cachePlayer()
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        Wait(200)
        FreezeEntityPosition(ped, true)
        local anim = {dict = 'anim@heists@keypad@', lib = 'idle_a'}
        LoadAnim(anim.dict)
        if Config.ProgressBars then
                lib.progressCircle({
                        duration = 8500,
                        label = Lang['pb_hacking'],
                        position = 'bottom',
                        useWhileDead = false,
                        disable = {car = true, move = true, combat = true}
                })
        else
                        TaskPlayAnim(ped, anim.dict, anim.lib, 2.0, -2.0, -1, 1, 0, 0, 0, 0 )
                        Wait(3500)
                        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', -1, true)
                        Wait(5000)
                        TriggerEvent("mhacking:show")
                        TriggerEvent("mhacking:start", 7, 25, HackingCallback)
                        return
        end
        TaskPlayAnim(ped, anim.dict, anim.lib, 2.0, -2.0, -1, 1, 0, 0, 0, 0 )
        Wait(3500)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', -1, true)
        Wait(5000)
        TriggerEvent("mhacking:show")
        TriggerEvent("mhacking:start", 7, 25, HackingCallback)
end

function HackingCallback(success)
        TriggerEvent('mhacking:hide')
        Config.Yacht.keypad.hacked = success
        if success then
                TriggerServerEvent('t1ger_yachtheist:setKeypadState', true)
                PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
        else
                TriggerServerEvent('t1ger_yachtheist:setKeypadState', false)
        end
        TriggerServerEvent('t1ger_yachtheist:PoliceNotifySV', "alert")
        Wait(1000)
        hacking = false
        local ped = cachePlayer()
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
end

local keypadPoint = lib.points.new({
        coords = toVec3(Config.Yacht.keypad.pos),
        distance = 5.0,
        onEnter = function(self)
                self.textShown = false
        end,
        onExit = function(self)
                hidePrompt(self)
        end,
        nearby = function(self)
                if not Config.Yacht.terminal.activated then
                        hidePrompt(self)
                        return
                end
                local ped = cachePlayer()
                if self.currentDistance <= 1.25 then
                        if Config.Yacht.keypad.hacked then
                                if isCop and not securing then
                                        showPrompt(self, ('[G] %s'):format(Lang['secure_vault']))
                                        if IsControlJustReleased(0, 47) then
                                                securing = true
                                                SecureHeistFunction(Config.Yacht)
                                                securing = false
                                        end
                                else
                                        hidePrompt(self)
                                end
                        else
                                if not isCop and not hacking then
                                        showPrompt(self, ('[E] %s'):format(Lang['hack_keypad']))
                                        if IsControlJustReleased(0, 38) then
                                                hacking = true
                                                KeypadHackFunction(Config.Yacht)
                                        end
                                else
                                        hidePrompt(self)
                                end
                        end
                else
                        hidePrompt(self)
                end
        end
})

-- Trolley Thread:
local function TrolleyGrabCash(cfg)
        local ped = cachePlayer()
        local obj_cache = trolley_obj and NetToObj(trolley_obj)
        if not obj_cache or obj_cache == 0 then
                grabbing = false
                TriggerServerEvent('t1ger_yachtheist:setTrolleyState', 'grabbing', false)
                return
        end
        if IsEntityPlayingAnim(obj_cache, 'anim@heists@ornate_bank@grab_cash', 'cart_cash_dissapear', 3) then
                ShowNotify(Lang['cash_arleady_grabbing'], 'error')
                grabbing = false
                TriggerServerEvent('t1ger_yachtheist:setTrolleyState', 'grabbing', false)
                return
        end
        local animDict = 'anim@heists@ornate_bank@grab_cash'
        LoadAnim(animDict)
        while not NetworkHasControlOfEntity(obj_cache) do
                Wait(5)
                NetworkRequestControlOfEntity(obj_cache)
        end
        local bag_prop = `hei_p_m_bag_var22_arm_s`
        LoadModel(bag_prop)
        local bag_obj = CreateObject(bag_prop, GetEntityCoords(ped), true, false, false)
        SetPedComponentVariation(ped, 5, 0, 0, 0)
        local scene1 = NetworkCreateSynchronisedScene(GetEntityCoords(obj_cache), GetEntityRotation(obj_cache), 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene1, animDict, "intro", 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag_obj, scene1, animDict, "bag_intro", 4.0, -8.0, 1)
        NetworkStartSynchronisedScene(scene1)
        Wait(1500)
        local cash_prop = `hei_prop_heist_cash_pile`
        LoadModel(cash_prop)
        local cashPile = CreateObject(cash_prop, GetEntityCoords(ped), true)
        FreezeEntityPosition(cashPile, true)
        SetEntityInvincible(cashPile, true)
        SetEntityNoCollisionEntity(cashPile, ped)
        SetEntityVisible(cashPile, false, false)
        AttachEntityToEntity(cashPile, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true)
        local takingCashTime = GetGameTimer()
        CreateThread(function()
                while GetGameTimer() - takingCashTime < 37000 do
                        Wait(0)
                        if HasAnimEventFired(ped, `CASH_APPEAR`) then
                                if not IsEntityVisible(cashPile) then
                                        SetEntityVisible(cashPile, true, false)
                                end
                        end
                        if HasAnimEventFired(ped, `RELEASE_CASH_DESTROY`) then
                                if IsEntityVisible(cashPile) then
                                        SetEntityVisible(cashPile, false, false)
                                        local amount = lib.callback.await('t1ger_yachtheist:addGrabbedCash', false)
                                        if amount then
                                                total_cash = total_cash + amount
                                        end
                                end
                        end
                end
                DeleteObject(cashPile)
        end)
        local scene2 = NetworkCreateSynchronisedScene(GetEntityCoords(obj_cache), GetEntityRotation(obj_cache), 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene2, animDict, "grab", 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag_obj, scene2, animDict, "bag_grab", 4.0, -8.0, 1)
        NetworkAddEntityToSynchronisedScene(obj_cache, scene2, animDict, "cart_cash_dissapear", 4.0, -8.0, 1)
        NetworkStartSynchronisedScene(scene2)
        Wait(37000)
        local scene3 = NetworkCreateSynchronisedScene(GetEntityCoords(obj_cache), GetEntityRotation(obj_cache), 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene3, animDict, "exit", 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag_obj, scene3, animDict, "bag_exit", 4.0, -8.0, 1)
        NetworkStartSynchronisedScene(scene3)
        local empty_trolleyProp = `hei_prop_hei_cash_trolly_03`
        LoadModel(empty_trolleyProp)
        local empty_trolleyObj = CreateObject(empty_trolleyProp, GetEntityCoords(obj_cache) + vec3(0.0, 0.0, -0.985), true)
        SetEntityRotation(empty_trolleyObj, GetEntityRotation(obj_cache))
        while not NetworkHasControlOfEntity(obj_cache) do
                Wait(5)
                NetworkRequestControlOfEntity(obj_cache)
        end
        DeleteObject(obj_cache)
        PlaceObjectOnGroundProperly(empty_trolleyObj)
        SetEntityAsMissionEntity(empty_trolleyObj, true, true)
        emptyTrolley_obj = ObjToNet(empty_trolleyObj)
        Wait(1900)
        DeleteObject(bag_obj)
        if Config.EnablePlayerMoneyBag then
                SetPedComponentVariation(ped, 5, 45, 0, 2)
        end
        RemoveAnimDict(animDict)
        SetModelAsNoLongerNeeded(empty_trolleyProp)
        SetModelAsNoLongerNeeded(bag_prop)
        Wait(2000)
        Config.Yacht.trolley.taken = true
        Config.Yacht.trolley.grabbing = false
        TriggerServerEvent('t1ger_yachtheist:setTrolleyState', 'taken', true)
        TriggerServerEvent('t1ger_yachtheist:setTrolleyState', 'grabbing', false)
        Wait(2000)
        grabbing = false
end

local trolleyPoint = lib.points.new({
        coords = toVec3(Config.Yacht.trolley.pos),
        distance = 7.0,
        onEnter = function(self)
                self.textShown = false
        end,
        onExit = function(self)
                hidePrompt(self)
        end,
        nearby = function(self)
                if Config.Yacht.keypad.hacked and not Config.Yacht.trolley.taken and not Config.Yacht.trolley.grabbing and not grabbing and not isCop then
                        if self.currentDistance <= 1.0 and trolley_obj then
                                showPrompt(self, ('[E] %s'):format(Lang['grab_cash']))
                                if IsControlJustReleased(0,38) then
                                        Config.Yacht.trolley.grabbing = true
                                        TriggerServerEvent('t1ger_yachtheist:setTrolleyState', 'grabbing', true)
                                        grabbing = true
                                        hidePrompt(self)
                                        TrolleyGrabCash(Config.Yacht)
                                end
                        else
                                hidePrompt(self)
                        end
                else
                        hidePrompt(self)
                end
        end
})

CreateThread(function()
        while true do
                Wait(0)
                if Config.Yacht.trolley.grabbing and grabbing then
                        drawRct(0.91, 0.95, 0.1430, 0.035, 0, 0, 0, 80)
                        SetTextScale(0.4, 0.4)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 255, 255, 255)
                        SetTextEdge(2, 0, 0, 0, 150)
                        SetTextEntry("STRING")
                        SetTextCentre(1)
                        AddTextComponentString("TAKE:")
                        DrawText(0.925,0.9535)
                else
                        Wait(1500)
                end
        end
end)

CreateThread(function()
        while true do
                Wait(0)
                if Config.Yacht.trolley.grabbing and grabbing then
                        SetTextScale(0.45, 0.45)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 255, 255, 255)
                        SetTextEdge(2, 0, 0, 0, 150)
                        SetTextEntry("STRING")
                        SetTextCentre(1)
                        AddTextComponentString(comma_value("$"..total_cash..""))
                        DrawText(0.97,0.9523)
                else
                        Wait(1500)
                end
        end
end)

function CreateJobPed(goon)
        LoadModel(goon.ped)
        local goonNPC = CreatePed(4, GetHashKey(goon.ped), goon.pos[1], goon.pos[2], goon.pos[3], goon.pos[4], false, true)
        NetworkRegisterEntityAsNetworked(goonNPC)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(goonNPC), true)
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(goonNPC), true)
        SetPedCanSwitchWeapon(goonNPC, true)
        SetEntityInvincible(goonNPC, false)
        SetEntityVisible(goonNPC, true)
        SetEntityAsMissionEntity(goonNPC)
        LoadAnim(goon.anim.dict)
        TaskPlayAnim(goonNPC, goon.anim.dict, goon.anim.lib, 8.0, -8, -1, 49, 0, 0, 0, 0)
        GiveWeaponToPed(goonNPC, GetHashKey(goon.weapon), 255, false, false)
        SetPedDropsWeaponsWhenDead(goonNPC, false)
        SetPedCombatAttributes(goonNPC, false)
        SetPedFleeAttributes(goonNPC, 0, false)
        SetPedEnableWeaponBlocking(goonNPC, true)
        SetPedRelationshipGroupHash(goonNPC, GetHashKey('JobNPCs'))
        TaskGuardCurrentPosition(goonNPC, 15.0, 15.0, 1)
        return goonNPC
end

local function GetClosestActivePlayer()
        local players = GetActivePlayers()
        local closestPlayer, closestDistance = -1, -1
        local plyCoords = GetEntityCoords(cachePlayer())
        for i = 1, #players do
                local target = players[i]
                if target ~= PlayerId() then
                        local targetPed = GetPlayerPed(target)
                        local targetCoords = GetEntityCoords(targetPed)
                        local dist = #(plyCoords - targetCoords)
                        if closestDistance == -1 or dist < closestDistance then
                                closestPlayer = target
                                closestDistance = dist
                        end
                end
        end
        return closestPlayer, closestDistance
end

local function DrillClosestSafe(id, val)
        local anim = {dict = "anim@heists@fleeca_bank@drilling", lib = "drill_straight_idle"}
        local closestPlayer, dist = GetClosestActivePlayer()
        if closestPlayer ~= -1 and dist <= 1.0 then
                if IsEntityPlayingAnim(GetPlayerPed(closestPlayer), anim.dict, anim.lib, 3) then
                        ShowNotify(Lang['safe_drilled_by_ply'], 'error')
                        return
                end
        end
        safe_drilling = true
        local ped = cachePlayer()
        FreezeEntityPosition(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        Wait(250)
        LoadAnim(anim.dict)
        local drill_prop = `hei_prop_heist_drill`
        local boneIndex = GetPedBoneIndex(ped, 28422)
        LoadModel(drill_prop)
        SetEntityCoords(ped, val.anim_pos[1], val.anim_pos[2], val.anim_pos[3]-0.95)
        SetEntityHeading(ped, val.anim_pos[4])
        TaskPlayAnimAdvanced(ped, anim.dict, anim.lib, val.anim_pos[1], val.anim_pos[2], val.anim_pos[3], 0.0, 0.0, val.anim_pos[4], 1.0, -1.0, -1, 2, 0, 0, 0 )
        local drill_obj = CreateObject(drill_prop, 1.0, 1.0, 1.0, 1, 1, 0)
        AttachEntityToEntity(drill_obj, ped, boneIndex, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0, 0, 2, 1)
        SetEntityAsMissionEntity(drill_obj, true, true)
        RequestAmbientAudioBank("DLC_HEIST_FLEECA_SOUNDSET", 0)
        RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL", 0)
        RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL_2", 0)
        local drill_sound = GetSoundId()
        Wait(100)
        PlaySoundFromEntity(drill_sound, "Drill", drill_obj, "DLC_HEIST_FLEECA_SOUNDSET", 1, 0)
        Wait(100)
        local particle_dict = "scr_fbi5a"
        local particle_lib = "scr_bio_grille_cutting"
        RequestNamedPtfxAsset(particle_dict)
        while not HasNamedPtfxAssetLoaded(particle_dict) do
                Wait(0)
        end
        SetPtfxAssetNextCall(particle_dict)
        local effect = StartParticleFxLoopedOnEntity(particle_lib, drill_obj, 0.0, -0.6, 0.0, 0.0, 0.0, 0.0, 2.0, 0, 0, 0)
        ShakeGameplayCam("ROAD_VIBRATION_SHAKE", 1.0)
        Wait(100)
        TriggerEvent("Drilling:Start", function(drill_status)
                if drill_status == 1 then
                        Config.Safes[id].robbed = true
                        TriggerServerEvent('t1ger_yachtheist:SafeDataSV', "robbed", id, true)
                        TriggerServerEvent('t1ger_yachtheist:vaultReward', id)
                        safe_drilling = false
                elseif drill_status == 3 then
                        ShowNotify(Lang['drilling_paused'], 'inform')
                        TriggerServerEvent('t1ger_yachtheist:giveItem', Config.DatabaseItems['drill'], 1)
                        safe_drilling = false
                elseif drill_status == 2 then
                        Config.Safes[id].failed = true
                        TriggerServerEvent('t1ger_yachtheist:SafeDataSV', "failed", id, true)
                        ShowNotify(Lang['you_destroyed_safe'], 'error')
                        safe_drilling = false
                end
                ClearPedTasksImmediately(ped)
                StopSound(drill_sound)
                ReleaseSoundId(drill_sound)
                DeleteObject(drill_obj)
                DeleteEntity(drill_obj)
                FreezeEntityPosition(ped, false)
                StopParticleFxLooped(effect, 0)
                StopGameplayCamShaking(true)
        end)
end

for id, safe in pairs(Config.Safes) do
        lib.points.new({
                coords = toVec3(safe.pos),
                distance = 4.5,
                onEnter = function(point)
                        point.textShown = false
                end,
                onExit = function(point)
                        hidePrompt(point)
                end,
                nearby = function(point)
                        if not Config.Yacht.terminal.activated or not Config.Yacht.keypad.hacked then
                                hidePrompt(point)
                                return
                        end
                        if safe.robbed then
                                if point.currentDistance <= 1.5 then
                                        showPrompt(point, Lang['safe_drilled'])
                                else
                                        hidePrompt(point)
                                end
                                return
                        end
                        if safe.failed then
                                if point.currentDistance <= 1.5 then
                                        showPrompt(point, Lang['safe_destroyed'])
                                else
                                        hidePrompt(point)
                                end
                                return
                        end
                        if point.currentDistance <= 1.25 and not safe_drilling and not isCop then
                                showPrompt(point, ('[E] %s'):format(Lang['drill_close_safe']))
                                if IsControlJustReleased(0, 38) then
                                        local hasItem = lib.callback.await('t1ger_yachtheist:consumeItem', false, Config.DatabaseItems['drill'], 1)
                                        if hasItem then
                                                DrillClosestSafe(id, safe)
                                        else
                                                ShowNotify(Lang['no_drill_item'], 'error')
                                        end
                                end
                                if IsControlJustPressed(2, 178) then
                                        TriggerEvent("Drilling:Stop")
                                end
                        else
                                hidePrompt(point)
                        end
                end
        })
end

RegisterNetEvent('t1ger_yachtheist:SafeDataCL', function(type, id, state)
        if type == "robbed" then
                Config.Safes[id].robbed = state
        elseif type == "failed" then
                Config.Safes[id].failed = state
        end
end)

CreateThread(function()
        CreateYachtBlip(Config.Yacht)
end)

function CreateYachtBlip(data)
        local bp = data.blip
        if bp.enable then
                local blip = AddBlipForCoord(data.terminal.pos[1], data.terminal.pos[2], data.terminal.pos[3])
                SetBlipSprite (blip, bp.sprite)
                SetBlipDisplay(blip, bp.display)
                SetBlipScale  (blip, bp.scale)
                SetBlipColour (blip, bp.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(bp.str)
                EndTextCommandSetBlipName(blip)
        end
end

RegisterNetEvent('t1ger_yachtheist:resetHeistCL', function()
        Config.Yacht.terminal.activated = false
        Config.Yacht.keypad.hacked = false
        Config.Yacht.trolley.grabbing = false
        Config.Yacht.trolley.taken = false
        Config.Yacht.cooldown = true
        for i = 1, #Config.Safes do
                Config.Safes[i].robbed = false
                Config.Safes[i].failed = false
        end
        interacting = false
        trolley_obj = nil
        emptyTrolley_obj = nil
        vault_door = nil
        goons = {}
        goons_spawned = false
        heist_ply = false
        hacking = false
        securing = false
        grabbing = false
        total_cash = 0
        safe_drilling = false
        if activePrompt then
                lib.hideTextUI()
                activePrompt.textShown = false
                activePrompt = nil
        end
end)
