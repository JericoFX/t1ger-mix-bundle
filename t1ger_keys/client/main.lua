-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

local QBCore = exports['qb-core']:GetCoreObject()

local player, coords = nil, {}
Citizen.CreateThread(function()
    while true do player = PlayerPedId(); coords = GetEntityCoords(player); Citizen.Wait(500) end
end)

local job_keys = {}
local car_keys = {}

local online_cops = 0
RegisterNetEvent('t1ger_keys:updateCopsCount')
AddEventHandler('t1ger_keys:updateCopsCount', function(count)
	online_cops = count
end)

-- ## DECORS ## --

-- Lock Decor:
local lock_decor = "_VEH_DOOR_LOCK_STATUS"
DecorRegister(lock_decor, 2)
-- Hotwire Decor:
local hotwire_decor = "_VEH_REQUIRES_HOTWIRE"
DecorRegister(hotwire_decor, false)
-- Search Decor:
local search_decor = "_VEH_SEARCH_STATE"
DecorRegister(search_decor, false)
-- Engine Decor:
local engine_decor = "_ENGINE_RUNNING"
DecorRegister(engine_decor, false)

-- Event to update job keys table
RegisterNetEvent('t1ger_keys:updateJobKeys')
AddEventHandler('t1ger_keys:updateJobKeys', function(data)
	job_keys = data
end)

-- Event to update car keys table:
RegisterNetEvent('t1ger_keys:updateCarKeys')
AddEventHandler('t1ger_keys:updateCarKeys', function(data)
	car_keys = data
end)

-- Keybinds:
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)
		if Config.Lock.Key ~= 0 and IsControlJustPressed(0, Config.Lock.Key) then
			ToggleVehicleLock()
		end
		if Config.CarMenu.Key ~= 0 and IsControlJustPressed(0, Config.CarMenu.Key) then
			CarInteractionMenu()
		end
		if Config.Engine.Key ~= 0 and IsControlJustPressed(0, Config.Engine.Key) then
			ToggleVehicleEngine()
		end
	end
end)

-- Commands:
Citizen.CreateThread(function()
	-- lock/unlock:
        if Config.Lock.Command ~= nil and Config.Lock.Command ~= '' then
                RegisterCommand(Config.Lock.Command, function()
                        ToggleVehicleLock()
                end, false)
        end
        -- car menu:
        if Config.CarMenu.Command ~= nil and Config.CarMenu.Command ~= '' then
                RegisterCommand(Config.CarMenu.Command, function()
                        CarInteractionMenu()
                end, false)
        end
        -- open keys menu:
        if Config.Keys.Command ~= nil and Config.Keys.Command ~= '' then
                RegisterCommand(Config.Keys.Command, function()
                        KeysManagement()
                end, false)
        end
        -- engine toggle:
        if Config.Engine.Command ~= nil and Config.Engine.Command ~= '' then
                RegisterCommand(Config.Engine.Command, function()
                        ToggleVehicleEngine()
                end, false)
        end
        -- lockpick command:
        if Config.Lockpick.Command  ~= nil and Config.Lockpick.Command  ~= '' then
                RegisterCommand(Config.Lockpick.Command , function()
                        LockpickVehicle()
                end, false)
        end
        -- search command:
        if Config.Search.Command  ~= nil and Config.Search.Command  ~= '' then
                RegisterCommand(Config.Search.Command , function()
                        SearchVehicle()
                end, false)
        end
        -- hotwire command:
        if Config.Hotwire.Command  ~= nil and Config.Hotwire.Command  ~= '' then
                RegisterCommand(Config.Hotwire.Command , function()
                        HotwireVehicle()
                end, false)
        end
end)

local window_rolled = false
local currentContext = nil
local shopPoints = {}
local shopTextVisible = false

local function HideShopTextUI()
        if shopTextVisible and lib and lib.hideTextUI then
                lib.hideTextUI()
                shopTextVisible = false
        end
end

local function DrawShopMarker(config)
        if not config.marker or not config.marker.enable then return end
        local mk = config.marker
        DrawMarker(mk.type, config.pos.x, config.pos.y, config.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, false, false, false)
end

local function CreateShopPoint(config, openMenu)
        if not lib or not lib.points or not config then return nil end
        local distance = (config.marker and config.marker.drawDist) or 2.0
        local point = lib.points.new({
                coords = config.pos,
                distance = distance,
                onExit = function()
                        HideShopTextUI()
                        CloseCurrentContext()
                end,
                nearby = function(self)
                        if self.currentDistance <= distance then
                                if config.marker and config.marker.enable and self.currentDistance > 1.5 then
                                        DrawShopMarker(config)
                                        HideShopTextUI()
                                else
                                        if not shopTextVisible and lib and lib.showTextUI then
                                                lib.showTextUI(config.text)
                                                shopTextVisible = true
                                        end
                                        if IsControlJustPressed(0, config.key) then
                                                HideShopTextUI()
                                                openMenu(config)
                                        end
                                end
                        else
                                HideShopTextUI()
                        end
                end
        })
        return point
end

local function CloseCurrentContext()
        if currentContext then
                lib.hideContext()
                currentContext = nil
        end
end

local function GetClosestPlayerServerId(range)
        local playerId, distance = QBCore.Functions.GetClosestPlayer()
        if playerId ~= -1 and (not range or distance <= range) then
                return GetPlayerServerId(playerId), distance
        end
        return nil, distance
end

-- Car Interaction Menu:
function CarInteractionMenu()
        CloseCurrentContext()
        local vehicle = nil
        if IsPedInAnyVehicle(player, false) then
                vehicle = GetVehiclePedIsIn(player, false)
        else
                vehicle = T1GER_GetClosestVehicle(GetEntityCoords(player))
        end

        local options = {
                {
                        title = Lang['keys_mangement_label'],
                        description = '',
                        onSelect = function()
                                KeysManagement()
                        end
                }
        }

        if vehicle ~= nil and DoesEntityExist(vehicle) then
                local vehOptions = {
                        {
                                title = Lang['veh_windows_label'],
                                onSelect = function()
                                        ShowVehicleWindowsContext(vehicle)
                                end
                        },
                        {
                                title = Lang['veh_door_label'],
                                onSelect = function()
                                        ShowVehicleDoorsContext(vehicle)
                                end
                        },
                        {
                                title = Lang['veh_engine_label'],
                                onSelect = function()
                                        ToggleVehicleEngine()
                                end
                        },
                        {
                                title = Lang['veh_neon_label'],
                                onSelect = function()
                                        ToggleVehicleNeons(vehicle)
                                end
                        }
                }
                for i = 1, #vehOptions do
                        options[#options + 1] = vehOptions[i]
                end
        end

        lib.registerContext({
                id = 't1ger_car_interaction',
                title = Lang['car_interaction_title'],
                options = options
        })

        currentContext = 't1ger_car_interaction'
        lib.showContext(currentContext)
end

function ShowVehicleWindowsContext(vehicle)
        if vehicle == nil or not DoesEntityExist(vehicle) then return end
        T1GER_GetControlOfEntity(vehicle)
        local texts = {
                [0] = Lang['window_front_l'],
                [1] = Lang['window_front_r'],
                [2] = Lang['window_rear_l'],
                [3] = Lang['window_rear_r']
        }
        local options = {}
        for i = 0, 3 do
                local index = i
                options[#options + 1] = {
                        title = texts[i],
                        onSelect = function()
                                if window_rolled then
                                        window_rolled = false
                                        RollUpWindow(vehicle, index)
                                else
                                        window_rolled = true
                                        RollDownWindow(vehicle, index)
                                end
                        end
                }
        end

        lib.registerContext({
                id = 't1ger_vehicle_windows',
                title = Lang['windows_menu_title'],
                menu = 't1ger_car_interaction',
                options = options
        })

        currentContext = 't1ger_vehicle_windows'
        lib.showContext(currentContext)
end

function ShowVehicleDoorsContext(vehicle)
        if vehicle == nil or not DoesEntityExist(vehicle) then return end
        T1GER_GetControlOfEntity(vehicle)
        local texts = {
                [0] = Lang['door_front_l'],
                [1] = Lang['door_front_r'],
                [2] = Lang['door_rear_l'],
                [3] = Lang['door_rear_r'],
                [4] = Lang['door_hood'],
                [5] = Lang['door_trunk']
        }
        local options = {}
        for i = 0, GetNumberOfVehicleDoors(vehicle) do
                if GetIsDoorValid(vehicle, i) then
                        local index = i
                        options[#options + 1] = {
                                title = texts[i],
                                onSelect = function()
                                        if GetVehicleDoorAngleRatio(vehicle, index) > 0.0 then
                                                SetVehicleDoorShut(vehicle, index, false)
                                        else
                                                SetVehicleDoorOpen(vehicle, index, false, false)
                                        end
                                end
                        }
                end
        end

        lib.registerContext({
                id = 't1ger_vehicle_doors',
                title = Lang['doors_menu_title'],
                menu = 't1ger_car_interaction',
                options = options
        })

        currentContext = 't1ger_vehicle_doors'
        lib.showContext(currentContext)
end

function ToggleVehicleNeons(vehicle)
        if vehicle == nil or not DoesEntityExist(vehicle) then return end
        if DecorGetBool(vehicle, engine_decor) or GetIsVehicleEngineRunning(vehicle) then
                for i = 0, 3 do
                        SetVehicleNeonLightEnabled(vehicle, i, not IsVehicleNeonLightEnabled(vehicle, i))
                end
        else
                TriggerEvent('t1ger_keys:notify', Lang['engine_not_running'])
        end
end

-- Mange Keys:
function KeysManagement()
        CloseCurrentContext()
        local entries = {}
        local results = lib.callback.await('t1ger_keys:fetchOwnedVehicles', false) or {}
        if next(results) then
                for _, v in pairs(results) do
                        if v.t1ger_keys then
                                local props = json.decode(v.vehicle)
                                local veh_name = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
                                entries[#entries + 1] = {
                                        label = veh_name..' ['..v.plate..']',
                                        name = veh_name,
                                        value = v,
                                        type = 'owned'
                                }
                        end
                end
        end

        for _, v in pairs(car_keys) do
                if v.type ~= nil then
                        entries[#entries + 1] = {
                                label = v.name..' ['..v.plate..'] ['..string.upper(v.type)..']',
                                name = v.name,
                                value = v,
                                type = v.type
                        }
                end
        end

        if next(entries) == nil then
                return TriggerEvent('t1ger_keys:notify', Lang['no_registerd_keys'])
        end

        local options = {}
        for _, entry in ipairs(entries) do
                options[#options + 1] = {
                        title = entry.label,
                        onSelect = function()
                                OpenKeyActions(entry)
                        end
                }
        end

        lib.registerContext({
                id = 't1ger_keys_management',
                title = Lang['your_current_keys'],
                options = options
        })

        currentContext = 't1ger_keys_management'
        lib.showContext(currentContext)
end

function OpenKeyActions(entry)
        local give, remove, delete = false, false, false
        local targetServerId, distance = GetClosestPlayerServerId(2.0)

        if entry.type == 'owned' then
                if targetServerId then
                        give = true
                        remove = true
                else
                        TriggerEvent('t1ger_keys:notify', Lang['no_players_nearby'])
                        return
                end
        else
                if entry.type == 'copy' then
                        delete = true
                else
                        delete = true
                        if targetServerId then
                                give = true
                        end
                end
        end

        local options = {}
        if give then
                options[#options + 1] = {
                        title = Lang['give_key_menu'],
                        onSelect = function()
                                CloseCurrentContext()
                                GiveCopyKeys(entry.value.plate, entry.name, targetServerId)
                                KeysManagement()
                        end
                }
        end
        if remove then
                options[#options + 1] = {
                        title = Lang['remove_key_menu'],
                        onSelect = function()
                                CloseCurrentContext()
                                TriggerServerEvent('t1ger_keys:removeCarKeys', targetServerId, entry.value.plate, entry.name)
                                KeysManagement()
                        end
                }
        end
        if delete then
                options[#options + 1] = {
                        title = Lang['delete_key_menu'],
                        onSelect = function()
                                CloseCurrentContext()
                                TriggerServerEvent('t1ger_keys:deleteCarKeys', entry.value.plate, entry.name)
                                KeysManagement()
                        end
                }
        end

        if #options == 0 then
                TriggerEvent('t1ger_keys:notify', Lang['no_available_actions'])
                return
        end

        lib.registerContext({
                id = 't1ger_keys_actions',
                title = Lang['keys_actions_title']:format(entry.value.plate),
                menu = 't1ger_keys_management',
                options = options
        })

        currentContext = 't1ger_keys_actions'
        lib.showContext(currentContext)
end


-- function to toggle vehicle lock:
function ToggleVehicleLock()
	local vehicle = nil
	if IsPedInAnyVehicle(player,  false) then
		vehicle = GetVehiclePedIsIn(player, false)
	else
		vehicle = T1GER_GetClosestVehicle(GetEntityCoords(player))
	end
	if DoesEntityExist(vehicle) then
		local plate = tostring(GetVehicleNumberPlateText(vehicle))
		local props = QBCore.Functions.GetVehicleProperties(vehicle)
		local canToggleLock = false
		if HasOwnedVehicleKey(plate) then
			canToggleLock = true
		elseif HasAddedVehicleKey(plate, props.plate) then 
			canToggleLock = true
		elseif HasJobVehicleKey(plate) then 
			canToggleLock = true
		elseif HasWhitelistVehicleKey(GetEntityModel(vehicle)) then
			canToggleLock = true
		end
		Wait(5)
		if canToggleLock then 
			UpdateVehicleLocked(vehicle)
		else
			TriggerEvent('t1ger_keys:notify', Lang['has_key_false'])
		end
	else
		TriggerEvent('t1ger_keys:notify', Lang['no_veh_nearby'])
	end
end

-- function to set update vehicle lock state:
function UpdateVehicleLocked(vehicle)
	-- animation:
	local prop = GetHashKey(Config.Keys.Prop)
	T1GER_LoadModel(prop)
	T1GER_LoadAnim(Config.Keys.AnimDict)
	SetCurrentPedWeapon(player, GetHashKey("WEAPON_UNARMED")) 
	local keyFob = CreateObject(prop, coords.x, coords.y, coords.z, true, true, false)
	local pos, rot = Config.Keys.PropPosition, Config.Keys.PropRotation
	AttachEntityToEntity(keyFob, player, GetPedBoneIndex(player, 57005), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
	TaskPlayAnim(player, Config.Keys.AnimDict, Config.Keys.AnimLib, 15.0, -10.0, 1500, 49, 0, false, false, false)
	if Config.Keys.PlaySound then 
		PlaySoundFromEntity(-1, "Remote_Control_Fob", player, "PI_Menu_Sounds", 1, 0)
	end
	SetVehicleLights(vehicle,2)
	Citizen.Wait(200)
	SetVehicleLights(vehicle,1)
	Citizen.Wait(200)
	SetVehicleLights(vehicle,2)
	Citizen.Wait(200)
	-- Decors:
	T1GER_GetControlOfEntity(vehicle)
	if not DecorExistOn(vehicle, lock_decor) then
		SetVehicleLocked(vehicle, GetVehicleDoorLockStatus(vehicle))
	end
	if DecorGetInt(vehicle, lock_decor) == 1 or DecorGetInt(vehicle, lock_decor) == 0 then
		SetVehicleLocked(vehicle, Config.Lock.LockInt)
		TriggerEvent('t1ger_keys:notify', Lang['vehicle_locked'])
	elseif DecorGetInt(vehicle, lock_decor) == 2 or DecorGetInt(vehicle, lock_decor) == 10 then
		SetVehicleLocked(vehicle, Config.Lock.UnlockInt)
		TriggerEvent('t1ger_keys:notify', Lang['vehicle_unlocked'])
	end
	SetVehicleDoorsLocked(vehicle, DecorGetInt(vehicle, lock_decor))
	if Config.Keys.PlaySound then 
		PlaySoundFromEntity(-1, "Remote_Control_Close", vehicle, "PI_Menu_Sounds", 1, 0)
	end
	-- end animation:
	Citizen.Wait(200)
	SetVehicleLights(vehicle,1)
	SetVehicleLights(vehicle,0)
	Citizen.Wait(200)
	DeleteEntity(keyFob)
end

-- Check if has owned vehicle key:
function HasOwnedVehicleKey(plate)
        local state = lib.callback.await('t1ger_keys:fetchVehicleKey', false, plate)
        return state ~= nil and state == true
end

-- Check if has key from car_keys table:
function HasAddedVehicleKey(plate, plate2)
	local plate3 = T1GER_Trim(plate)
	if next(car_keys) then 
		for k,v in pairs(car_keys) do
			if plate == v.plate or plate2 == v.plate or plate3 == v.plate then
				return true
			end
		end
	end
end

-- Check if has job vehicle key:
function HasJobVehicleKey(plate)
	if next(job_keys) and next(job_keys[plate]) then
		if next(job_keys[plate].jobs) then
			for k,v in pairs(job_keys[plate].jobs) do
				if PlayerData.job and PlayerData.job.name == v then
					return true
				end
			end
		end
	end
end

-- Check if has whitelist job key:
function HasWhitelistVehicleKey(model)
	for k,v in pairs(Config.WhitelistCars) do
		if v.model == model then
			if T1GER_GetJob(v.job) then 
				return true
			end
			break
		end
	end
end

-- Thread to lock NPC Vehicles:
Citizen.CreateThread(function()
        while true do
                local wait = 500
                if DoesEntityExist(GetVehiclePedIsTryingToEnter(player)) then
                        wait = 0
                        local vehicle = GetVehiclePedIsTryingToEnter(player)
                        T1GER_GetControlOfEntity(vehicle)
			-- Lock NPC vehicles:
			local NPC = GetPedInVehicleSeat(vehicle, -1)
			if not DecorExistOn(vehicle, lock_decor) then
				if Config.Lock.NPC_Lock == true then 
					-- chance to unlock:
					local chance = Config.Lock.ChanceParked
					if NPC ~= 0 then
						chance = Config.Lock.Chance
					end
					-- apply lock:
					local generated = math.random(100)
					math.randomseed(GetGameTimer())
					if generated < chance then
						SetVehicleLocked(vehicle, Config.Lock.UnlockInt)
					else
						SetVehicleLocked(vehicle, Config.Lock.LockInt)
					end
				else
					SetVehicleLocked(vehicle, Config.Lock.UnlockInt)
				end
			else
				if DecorGetInt(vehicle, lock_decor) == Config.Lock.LockInt or DecorGetInt(vehicle, lock_decor) == 10 then
					Citizen.Wait(500)
					ClearPedTasks(player)
				end
			end
                        SetVehicleDoorsLocked(vehicle, DecorGetInt(vehicle, lock_decor))
                end
                Citizen.Wait(wait)
        end
end)

-- Thread to steal NPC vehicles:
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
		local sleep = true 
		local aiming, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
		if aiming and IsPedArmed(player, 6) then
			if IsPedAccepted(entity) then 
				local NPC_Vehicle = GetVehiclePedIsIn(entity, false)
				if #(coords - GetEntityCoords(entity)) < Config.Steal.AimDist then 
					if NPC_Vehicle ~= 0 then
						sleep = false
						if GetEntitySpeed(NPC_Vehicle) < Config.Steal.VehSpeed then
							entity = GetPedInVehicleSeat(NPC_Vehicle, -1)
							local task_sequence = CreateTaskSequence(NPC_Vehicle)
							TaskPerformSequence(entity, task_sequence)
							Wait(200)
							if Config.Steal.Locked then
								SetVehicleLocked(NPC_Vehicle, Config.Lock.LockInt)
							else
								SetVehicleLocked(NPC_Vehicle, Config.Lock.UnlockInt)
							end
							if Config.Steal.ShutEngineOff then
								DecorSetBool(NPC_Vehicle, engine_decor, false)
								SetVehicleEngineOn(NPC_Vehicle, DecorGetBool(NPC_Vehicle, engine_decor), true, true)
							end
							SetVehicleHotwire(NPC_Vehicle, Config.Steal.SetHotwire)
							local tick = Config.Steal.HandsUpTime
							while tick > 0 do
								Citizen.Wait(1000)
								tick = tick - 1000
								if not GetEntityPlayerIsFreeAimingAt(PlayerId(), entity) and tick > 0 then
									TriggerEvent('t1ger_keys:notify', Lang['npc_ran_away'])
									break
								else
									if tick <= 0 then
										math.randomseed(GetGameTimer())
										if math.random(0,100) <= Config.Steal.Chance then 
											SetVehicleLocked(NPC_Vehicle, Config.Lock.UnlockInt)
											SetVehicleHotwire(NPC_Vehicle, false)
											T1GER_LoadAnim(Config.Steal.AnimDict)
											TaskPlayAnim(entity, Config.Steal.AnimDict, Config.Steal.AnimLib, 1.0, 1.0, -1, 1, 0, 0, 0, 0 )
											Citizen.Wait(1400)
											-- add keys to player:
											local plate = tostring(GetVehicleNumberPlateText(NPC_Vehicle))
											local veh_name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(NPC_Vehicle)))
											GiveTemporaryKeys(plate, veh_name, 'stolen')
										else
											TriggerEvent('t1ger_keys:notify', Lang['npc_ran_away'])
										end
										break
									end
								end
							end
							if Config.Steal.ReportPlayer then ReportPlayer(NPC_Vehicle, 'steal') end
							SetVehicleCanSearch(NPC_Vehicle, Config.Steal.AllowSearch)
							ClearSequenceTask(task_sequence)
							ClearPedTasks(entity)
							TaskSetBlockingOfNonTemporaryEvents(entity, false)
							TaskSmartFleePed(entity, player, 40.0, 20000)
							aiming = false
						end
					end
				end
			end
		end
		if sleep then Citizen.Wait(500) end
    end
end)

local lockpicking, hotwiring, searching = false, false, false

-- Event to lockpick vehicle:
RegisterNetEvent('t1ger_keys:lockpickCL')
AddEventHandler('t1ger_keys:lockpickCL',function()
	LockpickVehicle()
end)

-- function to lockpick vehicle:
function LockpickVehicle()
	if lockpicking then
		return TriggerEvent('t1ger_keys:notify', Lang['already_lockpicking'])
	end
	local vehicle = T1GER_GetVehicleInDirection()
	local veh_coords = GetEntityCoords(vehicle)
	if DoesEntityExist(vehicle) then
		if GetDistanceBetweenCoords(coords, veh_coords.x, veh_coords.y, veh_coords.z, true) < 2.0 then
			if DecorExistOn(vehicle, lock_decor) then 
				if DecorGetInt(vehicle, lock_decor) == 2 or DecorGetInt(vehicle, lock_decor) == 10 then
                                        local plate, alarm, identifier = tostring(GetVehicleNumberPlateText(vehicle)), false, nil
                                        lockpicking = true
                                        local alarmData = lib.callback.await('t1ger_keys:getVehicleAlarm', false, plate)
                                        if alarmData then
                                                alarm = alarmData.alarm
                                                identifier = alarmData.owner
                                        end
                                        if Config.Lockpick.Remove then
                                                TriggerServerEvent('t1ger_keys:removeLockpick')
                                        end
                                        if Config.Lockpick.Report then
                                                ReportPlayer(vehicle, 'lockpick')
                                        end
                                        T1GER_LoadAnim(Config.Lockpick.Anim.Dict)
                                        SetCurrentPedWeapon(player, GetHashKey("WEAPON_UNARMED"),true)
                                        FreezeEntityPosition(player, true)
                                        if Config.ProgressBars then
                                                exports['progressBars']:startUI((Config.Lockpick.Duration), Config.Lockpick.Text)
                                        end
                                        if Config.Lockpick.Alarm.Enable then
                                                SetVehicleAlarm(vehicle, true)
                                                SetVehicleAlarmTimeLeft(vehicle, (Config.Lockpick.Alarm.Time))
                                                StartVehicleAlarm(vehicle)
                                        end
                                        -- Get success state:
                                        local success = false
                                        math.randomseed(GetGameTimer())
                                        local chance = math.random(100)
                                        if alarm then
                                                if Config.Lockpick.Alarm.Report then ReportToVehicleOwner(plate, identifier) end
                                                if chance <= Config.Lockpick.Alarm.Chance then success = true end
                                        else
                                                if chance <= Config.Lockpick.Chance then success = true end
                                        end
                                        Citizen.Wait(Config.Lockpick.Duration)
                                        ClearPedTasks(player)
                                        FreezeEntityPosition(player, false)
                                        lockpicking = false
                                        if success then
                                                SetVehicleLocked(vehicle, Config.Lock.UnlockInt)
                                                SetVehicleHotwire(vehicle, Config.Lockpick.SetHotwire)
                                                SetVehicleNeedsToBeHotwired(vehicle, false)
                                                SetVehicleCanSearch(vehicle, Config.Lockpick.AllowSearch)
                                                TriggerEvent('t1ger_keys:notify', Lang['veh_lockpicked_success'])
                                                if Config.Lockpick.SetHotwire then
                                                        TriggerEvent('t1ger_keys:notify', Lang['hotwire_the_vehicle'])
                                                end
                                        else
                                                TriggerEvent('t1ger_keys:notify', Lang['veh_lockpicked_fail'])
                                        end
				else
					return TriggerEvent('t1ger_keys:notify', Lang['deny_lockpick_unlocked'])
				end
			else
				return TriggerEvent('t1ger_keys:notify', Lang['first_check_if_locked'])
			end
		else
			return TriggerEvent('t1ger_keys:notify', Lang['move_closer_to_lockpick'])
		end
	else
		return TriggerEvent('t1ger_keys:notify', Lang['no_veh_in_direction'])
	end
end

-- Function to hotwire vehicle:
function HotwireVehicle()
	if hotwiring then 
		return TriggerEvent('t1ger_keys:notify', Lang['already_hotwiring'])
	end
	local vehicle = GetVehiclePedIsIn(player, false)
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		if GetPedInVehicleSeat(vehicle, -1) == player then
			if DecorGetBool(vehicle, hotwire_decor) then
				hotwiring = true
				T1GER_LoadAnim(Config.Hotwire.AnimDict)
				FreezeEntityPosition(player, true)
				TaskPlayAnim(player, Config.Hotwire.AnimDict, Config.Hotwire.AnimLib, 8.0, -8.0, -1, 49, 0, 0, 0)
				if Config.ProgressBars then 
					exports['progressBars']:startUI(Config.Hotwire.Duration,Config.Hotwire.Text)
				end
				Citizen.Wait(Config.Hotwire.Duration)
				ClearPedTasks(player)
				FreezeEntityPosition(player, false)
				math.randomseed(GetGameTimer())
				local chance, success = math.random(100), false
				if chance < Config.Hotwire.Chance then
					success = true
				end
				if success then 
					TriggerEvent('t1ger_keys:notify', Lang['veh_hotwire_success'])
					SetVehicleHotwire(vehicle, false)
					DecorSetBool(vehicle, engine_decor, true)
					SetVehicleEngineOn(vehicle, true, true, true)
					SetVehicleUndriveable(vehicle, false)
				else
					TriggerEvent('t1ger_keys:notify', Lang['veh_hotwire_fail'])
				end
				hotwiring = false
			else
				return TriggerEvent('t1ger_keys:notify', Lang['deny_hotwire'])
			end
		else
			return TriggerEvent('t1ger_keys:notify', Lang['must_be_driver_of_veh'])
		end
	else
		return TriggerEvent('t1ger_keys:notify', Lang['must_be_inside_veh'])
	end
end

-- Function to Search NPC Vehicles:
function SearchVehicle()
	if searching then 
		return TriggerEvent('t1ger_keys:notify', Lang['already_searching'])
	end
	local vehicle = GetVehiclePedIsIn(player, false)
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		if GetPedInVehicleSeat(vehicle, -1) == player then
			if GetEntitySpeed(vehicle) < 2.0 then 
				if DecorGetBool(vehicle, search_decor) then
					searching = true
					SetVehicleCanSearch(vehicle, false)
					T1GER_LoadAnim(Config.Search.AnimDict)
					FreezeEntityPosition(vehicle, true)
					FreezeEntityPosition(player, true)
					TaskPlayAnim(player, Config.Search.AnimDict, Config.Search.AnimLib, 8.0, -8.0, -1, 49, 0, 0, 0)
					if Config.ProgressBars then
						exports['progressBars']:startUI(Config.Search.Duration, Config.Search.Text)
					end
					Citizen.Wait(Config.Search.Duration)
					ClearPedTasks(player)
					FreezeEntityPosition(vehicle, false)
					FreezeEntityPosition(player, false)
					TriggerServerEvent('t1ger_keys:searchVehicleReward')
					searching = false
				else
					return TriggerEvent('t1ger_keys:notify', Lang['cannot_search_car'])
				end
			else
				return TriggerEvent('t1ger_keys:notify', Lang['stop_the_vehicle'])
			end
		else
			return TriggerEvent('t1ger_keys:notify', Lang['must_be_driver_of_veh'])
		end
	else
		return TriggerEvent('t1ger_keys:notify', Lang['must_be_inside_veh'])
	end
end

-- Check if vehicle needs to be hotwired:
Citizen.CreateThread(function()
	local sleep = 1000
	while true do
		Wait(sleep)
		local vehicle = GetVehiclePedIsIn(player, false)
		if vehicle ~= 0 and DoesEntityExist(vehicle) and DecorGetBool(vehicle, hotwire_decor) then
			sleep = 100
			SetVehicleEngineOn(vehicle, false, true, true)
			SetVehicleUndriveable(vehicle, true)
		end
	end
end)

-- Lockpick Animation:
Citizen.CreateThread(function()
	local sleep = 1000
	while true do
		Wait(sleep)
		if lockpicking then 
			sleep = 1500
			TaskPlayAnim(player, Config.Lockpick.Anim.Dict, Config.Lockpick.Anim.Lib, 1.0, 1.0, -1, 16, 0, 0, 0)
		end
	end
end)

-- Exported function to set vehicle locked state using decors
function SetVehicleLocked(vehicle, int)
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		T1GER_GetControlOfEntity(vehicle)
		local integer = 0
		if type(int) == 'number' then
			if int == 0 or int == 1 then
				integer = Config.Lock.UnlockInt
			elseif int == 2 or int == 10 then 
				integer = Config.Lock.LockInt
			else
				integer = int
			end
		elseif type(int) == 'boolean' then
			if int then
				integer = Config.Lock.LockInt
			else
				integer = Config.Lock.UnlockInt
			end
		else
			return print("[SetVehicleLocked] variable must be a type of integer or boolean")
		end
		DecorSetInt(vehicle, lock_decor, integer)
		while not DecorExistOn(vehicle, lock_decor) do
			Citizen.Wait(1)
		end
		SetVehicleDoorsLocked(vehicle, DecorGetInt(vehicle, lock_decor))
	else
		return print("[SetVehicleLocked] vehicle does not exist")
	end
end

-- Exported function to get vehicle locked state using decors
function GetVehicleLockedStatus(vehicle)
	if DecorExistOn(vehicle, lock_decor) then 
		return DecorGetInt(vehicle, lock_decor)
	else
		return GetVehicleDoorLockStatus(vehicle)
	end
end

-- Exported function to set vehicle require hotwire state using decors
function SetVehicleHotwire(vehicle, boolean)
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		if boolean ~= nil then
			DecorSetBool(vehicle, hotwire_decor, boolean)
		else
			return print("[SetVehicleHotwire] boolean nil, set boolean true/false")
		end
	else
		return print("[SetVehicleHotwire] vehicle does not exist")
	end
end

-- Exported function to set vehicle can be searched state using decors
function SetVehicleCanSearch(vehicle, boolean)
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		if boolean ~= nil then
			DecorSetBool(vehicle, search_decor, boolean)
		else
			return print("[SetVehicleCanSearch] boolean nil, set boolean true/false")
		end
	else
		return print("[SetVehicleCanSearch] vehicle does not exist")
	end
end

-- Exported function to toggle vehicle engine using decors:
function ToggleVehicleEngine()
	local vehicle = GetVehiclePedIsIn(player, false)
	T1GER_GetControlOfEntity(vehicle)
	if vehicle == nil or vehicle == 0 then
		return TriggerEvent('t1ger_keys:notify', Lang['must_be_inside_veh'])
	end
	if not DecorExistOn(vehicle, engine_decor) then
		DecorSetBool(vehicle, engine_decor, GetIsVehicleEngineRunning(vehicle))
	end
	if DecorGetBool(vehicle, engine_decor) then
		DecorSetBool(vehicle, engine_decor, false)
		TriggerEvent('t1ger_keys:notify', Lang['engine_toggled_off'])
	else
		DecorSetBool(vehicle, engine_decor, true)
		TriggerEvent('t1ger_keys:notify', Lang['engine_toggled_on'])
	end
	SetVehicleEngineOn(vehicle, DecorGetBool(vehicle, engine_decor), true, true)
end

-- Function to give temporary copy keys
function GiveCopyKeys(plate, name, target)
	TriggerServerEvent('t1ger_keys:giveCopyKeys', plate, name, tonumber(target))
end

-- Exported function to add temporary keys to a vehicle /w type:
function GiveTemporaryKeys(plate, name, type)
	TriggerServerEvent('t1ger_keys:giveTemporaryKeys', plate, name, type)
end

-- Exported function to add job keys for whole job:
function GiveJobKeys(plate, name, boolean, jobs)
	TriggerServerEvent('t1ger_keys:giveJobKeys', plate, name, boolean, jobs)
end

-- Function to create task sequence:
function CreateTaskSequence(vehicle) 
	local task = OpenSequenceTask()
	TaskSetBlockingOfNonTemporaryEvents(0, true)
	TaskLeaveVehicle(0, vehicle, 256)
	SetPedDropsWeaponsWhenDead(0, false)
	SetPedFleeAttributes(0, 0, false)
	SetPedCombatAttributes(0, 17, true)
	SetPedHearingRange(0, 3.0)
	SetPedSeeingRange(0, 0.0)
	SetPedAlertness(0, 0)
	SetPedKeepTask(0, true)
	TaskHandsUp(0, -1, player, -1, false)
	CloseSequenceTask(task)
	return task
end

-- Function to check PED for gun point stealing:
function IsPedAccepted(entity)
	local accepted = true
	local ped_type = GetPedType(entity)
	if ped_type == 6 or ped_type == 27 or ped_type == 29 or ped_type == 28 then accepted = false end
	if not DoesEntityExist(entity) then accepted = false end
	if not IsEntityAPed(entity) then accepted = false end
	if IsPedAPlayer(entity) then accepted = false end
    if IsEntityDead(entity) then accepted = false end
    if IsPedDeadOrDying(entity, true) then accepted = false end
	if not IsPedInAnyVehicle(entity, false) then accepted = false end
	return accepted
end

-- Function to report player to cops:
function ReportPlayer(vehicle, msg)
	if Config.Police.EnableAlerts then
		TriggerEvent('t1ger_keys:police_notify', msg, vehicle)
	end
end

-- Function to report vehicle theft to owner:
function ReportToVehicleOwner(plate, identifier)
        TriggerEvent('t1ger_keys:player_notify', plate, identifier)
end

local blips = {}

-- Lock Smith Menu:
function LocksmithMenu(val)
        CloseCurrentContext()
        local results = lib.callback.await('t1ger_keys:fetchOwnedVehicles', false) or {}
        local options = {}

        if next(results) then
                for _, v in pairs(results) do
                        if not v.t1ger_keys then
                                local props = json.decode(v.vehicle)
                                local veh_name = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
                                local plate = v.plate
                                options[#options + 1] = {
                                        title = veh_name..' ['..plate..']',
                                        onSelect = function()
                                                local response = lib.alertDialog({
                                                        header = Lang['reg_key_title']:format(val.price),
                                                        content = Lang['confirm_register_key'],
                                                        centered = true,
                                                        cancel = true
                                                })
                                                if response == 'confirm' then
                                                        CloseCurrentContext()
                                                        TriggerServerEvent('t1ger_keys:registerKey', plate, true)
                                                        TriggerEvent('t1ger_keys:notify', Lang['key_reg_accepted'])
                                                end
                                        end
                                }
                        end
                end
        end

        if #options == 0 then
                if next(results) then
                        TriggerEvent('t1ger_keys:notify', Lang['all_veh_has_keys'])
                else
                        TriggerEvent('t1ger_keys:notify', Lang['no_owned_vehicles'])
                end
                return
        end

        lib.registerContext({
                id = 't1ger_locksmith',
                title = Lang['shop_main_title'],
                options = options
        })

        currentContext = 't1ger_locksmith'
        lib.showContext(currentContext)
end

-- Alarm Shop Menu:
function AlarmShopMenu(val)
        CloseCurrentContext()
        local results = lib.callback.await('t1ger_keys:fetchOwnedVehicles', false) or {}
        local options = {}

        if next(results) then
                for _, v in pairs(results) do
                        if not v.t1ger_alarm then
                                local props = json.decode(v.vehicle)
                                local veh_name = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
                                local plate = v.plate
                                options[#options + 1] = {
                                        title = veh_name..' ['..plate..']',
                                        onSelect = function()
                                                local vehicleName = GetDisplayNameFromVehicleModel(props.model):lower()
                                                local priceInfo = lib.callback.await('t1ger_keys:getVehiclePrice', false, vehicleName)
                                                local price = priceInfo and priceInfo.price or 0
                                                if price <= 0 then
                                                        print('Vehicle Price Error ['..plate..']\ngameName property in vehicles.meta for this vehicle does not match spawn code name from database.\nPlease let developers know - take screenshot of this!')
                                                        TriggerEvent('t1ger_keys:notify', Lang['check_f8_console'])
                                                        return
                                                end
                                                price = math.floor((val.price/100) * price)
                                                local response = lib.alertDialog({
                                                        header = Lang['reg_alarm_title']:format(price),
                                                        content = Lang['confirm_register_alarm'],
                                                        centered = true,
                                                        cancel = true
                                                })
                                                if response == 'confirm' then
                                                        CloseCurrentContext()
                                                        TriggerServerEvent('t1ger_keys:registerAlarm', plate, true, price)
                                                        TriggerEvent('t1ger_keys:notify', Lang['alarm_aquired'])
                                                end
                                        end
                                }
                        end
                end
        end

        if #options == 0 then
                if next(results) then
                        TriggerEvent('t1ger_keys:notify', Lang['all_veh_have_alarm'])
                else
                        TriggerEvent('t1ger_keys:notify', Lang['no_owned_vehicles'])
                end
                return
        end

        lib.registerContext({
                id = 't1ger_alarmshop',
                title = Lang['shop_main_title'],
                options = options
        })

        currentContext = 't1ger_alarmshop'
        lib.showContext(currentContext)
end

Citizen.CreateThread(function()
        if not lib or not lib.points then return end
        shopPoints.locksmith = CreateShopPoint(Config.LockSmith, LocksmithMenu)
        shopPoints.alarmshop = CreateShopPoint(Config.AlarmShop, AlarmShopMenu)
end)

AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        HideShopTextUI()
        for _, point in pairs(shopPoints) do
                if point and point.remove then
                        point:remove()
                end
        end
end)

-- Create Blips:
Citizen.CreateThread(function()
        blips.locksmith = T1GER_CreateBlip(Config.LockSmith.pos, Config.LockSmith.blip)
        blips.alarmshop = T1GER_CreateBlip(Config.AlarmShop.pos, Config.AlarmShop.blip)
end)

-- Function to get closest vehicle:
function T1GER_GetVehicleInDirection()
        local ped = PlayerPedId()
        local from = GetEntityCoords(ped)
        local to = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
        local rayHandle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 10, ped, 0)
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
        if hit == 1 and DoesEntityExist(entityHit) then
                return entityHit
        end
        return 0
end

function T1GER_GetClosestVehicle(pos)
    local closestVeh = StartShapeTestCapsule(pos.x, pos.y, pos.z, pos.x, pos.y, pos.z, 6.0, 10, player, 7)
    local a, b, c, d, entityHit = GetShapeTestResult(closestVeh)
	local tick = 100
	while entityHit == 0 and tick > 0 do 
		tick = tick - 1
		closestVeh = StartShapeTestCapsule(pos.x, pos.y, pos.z, pos.x, pos.y, pos.z, 6.0, 10, player, 7)
		local a1, b1, c1, d1, entityHit2 = GetShapeTestResult(closestVeh)
		if entityHit2 ~= 0 then 
			entityHit = entityHit2
			break
		end
		Citizen.Wait(10)
	end
    return entityHit
end
