-- Variables

local QBCore = exports['qb-core']:GetCoreObject()
local fuelSynced = false
local inBlacklisted = false
local inGasStation = false
local isFueling = false
local Stations = {}
local props = {
	'prop_gas_pump_1d',
	'prop_gas_pump_1a',
	'prop_gas_pump_1b',
	'prop_gas_pump_1c',
	'prop_vintage_pump',
	'prop_gas_pump_old2',
	'prop_gas_pump_old3',
	'486135101',
	'-2007231801',
	'1339433404',
	'1694452750',
	'1933174915',
	'-462817101',
	'-469694731',
	'-164877493',
}
local CurrentWeaponData = {}

-- Functions

local function isHoldingWeapon(weaponHash)
    return GetSelectedPedWeapon(PlayerPedId()) == weaponHash
end

local function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))
		fuelSynced = true
	end
	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
		SetVehicleEngineOn(veh, true, true, true)
	else
		SetVehicleEngineOn(veh, true, true, true)
	end
end

-- Threads

local bones = {
	"petroltank",
	"petroltank_l",
	"petroltank_r",
	"wheel_rf",
	"wheel_rr",
	"petrolcap ",
	"seat_dside_r",
	"engine",
}

exports['qb-target']:AddTargetBone(bones, {
	options = {
		{
			type = "client",
			event = "ps-fuel:client:refilcarfrompump",
			icon = "fas fa-gas-pump",
			label = "Refuel Vehicle From Pump",
			canInteract = function()
				return inGasStation
			end,
		},
		{
			type = "client",
			event = "ps-fuel:client:refilcarfromjerrycan",
			icon = "fas fa-gas-pump",
			label = "Refuel Vehicle From Jerry Can",
			canInteract = function()
				return HasPedGotWeapon(PlayerPedId(), GetHashKey("WEAPON_PETROLCAN"))
			end,
		}
	},
	distance = 2.0
})


if Config.LeaveEngineRunning then
	CreateThread(function()
		while true do
			Wait(100)
			local ped = GetPlayerPed(-1)
			if DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) and IsControlPressed(2, 75) and not IsEntityDead(ped) and not IsPauseMenuActive() then
				local engineWasRunning = GetIsVehicleEngineRunning(GetVehiclePedIsIn(ped, true))
				Wait(1000)
				if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) and not IsPauseMenuActive() then
					local veh = GetVehiclePedIsIn(ped, true)
					if engineWasRunning then
						SetVehicleEngineOn(veh, true, true, true)
					end
				end
			end
		end
	end)
end

if Config.ShowNearestGasStationOnly then
    CreateThread(function()
	local currentGasBlip = 0
	while true do
		local coords = GetEntityCoords(PlayerPedId())
		local closest = 1000
		local closestCoords

		for _, gasStationCoords in pairs(Config.GasStationsBlips) do
			local dstcheck = #(coords - gasStationCoords)
			if dstcheck < closest then
				closest = dstcheck
				closestCoords = gasStationCoords
			end
		end
		if DoesBlipExist(currentGasBlip) then
			RemoveBlip(currentGasBlip)
		end
		currentGasBlip = CreateBlip(closestCoords)
		Wait(10000)
	end
end)

elseif Config.ShowAllGasStations then
    CreateThread(function()
        for _, gasStationCoords in pairs(Config.GasStationsBlips) do
            CreateBlip(gasStationCoords)
        end
    end)
end

CreateThread(function() 
    for k=1, #Config.GasStations do
		Stations[k] = PolyZone:Create(Config.GasStations[k].zones, {
			name="GasStation"..k,
			minZ = 	Config.GasStations[k].minz,
			maxZ = Config.GasStations[k].maxz,
			debugPoly = false
		})
		Stations[k]:onPlayerInOut(function(isPointInside)
			if isPointInside then
				inGasStation = true
			else
				inGasStation = false
			end
		end)
    end
end)

CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)
	for index = 1, #Config.Blacklist do
		if type(Config.Blacklist[index]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[index])] = true
		else
			Config.Blacklist[Config.Blacklist[index]] = true
		end
	end
	for index = #Config.Blacklist, 1, -1 do
		Config.Blacklist[index] = nil
	end
	while true do
		Wait(1000)
		local ped = PlayerPedId()
		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)
			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end
			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end
			if inBlacklisted then
				inBlacklisted = false
			end
		end
	end
end)

-- Client Events

-- RegisterNetEvent('ps-fuel:client:buyCanMenu', function()
--     exports['qb-menu']:openMenu({
--         {
--             header = "Gas Station",
--             txt = 'The total cost is going to be: £'..Config.canCost..' including taxes.',
--             params = {
--                 event = "ps-fuel:client:buyCan",
--             }
--         },
--     })
-- end)

RegisterNetEvent('ps-fuel:client:buyCan', function()
	local ped = PlayerPedId()
    if not HasPedGotWeapon(ped, 883325847) then
		if QBCore.Functions.GetPlayerData().money['cash'] >= Config.canCost then
			-- TriggerServerEvent('QBCore:Server:AddItem', "weapon_petrolcan", 1)
			-- TriggerEvent("inventory:client:ItemBox", QBCore.Shared.Items["weapon_petrolcan"], "add")
			TriggerServerEvent('ps-fuel:server:PayForFuel', Config.canCost, true, false)
		else
			QBCore.Functions.Notify(Lang:t("notify.no_money"), "error")
		end
    end
end)

RegisterNetEvent('jackofuel:client:forcefuel', function(amount)
	local ped = PlayerPedId()
    local fuellevel = amount
	local vehicle = GetVehiclePedIsIn(ped, false)
	SetFuel(vehicle, fuellevel)
	
end)

RegisterNetEvent('ps-fuel:client:refuelCan', function()
	local vehicle = QBCore.Functions.GetClosestVehicle()
	local ped = PlayerPedId()
	local CurFuel = GetVehicleFuelLevel(vehicle)
	if HasPedGotWeapon(ped, 883325847) then
		if GetAmmoInPedWeapon(ped, 883325847) < 2500 then
			QBCore.Functions.Progressbar("refuel-car", "Refueling", 10000, false, true, {
				disableMovement = true,
				disableCarMovement = true,
				disableMouse = false,
				disableCombat = true,
			},
			{
				animDict = "weapon@w_sp_jerrycan",
				anim = "fire",
				flags = 49,
			},
			{},
			{},
			function() -- Done
				SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
				Wait(1000)
				QBCore.Functions.Notify("Successfully Filled Can", "primary")
				TriggerServerEvent('ps-fuel:server:PayForFuel', Config.refuelCanCost, false, true)
				StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
			end,
			function() -- Cancel
				QBCore.Functions.Notify(Lang:t("notify.refuel_cancel"), "error")
				StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
			end)
		else
			QBCore.Functions.Notify("Jerry Can Full", "error")
		end
	end
end)

-- RegisterNetEvent('ps-fuel:client:SendMenuToServer', function()
-- 	local vehicle = QBCore.Functions.GetClosestVehicle()
-- 	local CurFuel = GetVehicleFuelLevel(vehicle)
-- 	local refillCost = Round(Config.RefillCost - CurFuel) * Config.CostMultiplier
-- 	local ped = PlayerPedId()
-- 	if HasPedGotWeapon(ped, 883325847) then
-- 		if GetAmmoInPedWeapon(ped, 883325847) ~= 0 then
-- 			if CurFuel < 95 then
-- 				TriggerServerEvent('ps-fuel:server:OpenMenu', 0, inGasStation, true)
-- 			else
-- 				QBCore.Functions.Notify(Lang:t("notify.vehicle_full"), "error")
-- 			end
-- 		else
-- 			QBCore.Functions.Notify(Lang:t("notify.jerrycan_empty"), "error")
-- 		end
-- 	else
-- 		if CurFuel < 95 then
-- 			TriggerServerEvent('ps-fuel:server:OpenMenu', refillCost, inGasStation, false)
-- 		else
-- 			QBCore.Functions.Notify(Lang:t("notify.vehicle_full"), "error")
-- 		end
-- 	end
-- end)

AddEventHandler('weapons:client:SetCurrentWeapon', function(data, bool)
    if bool ~= false then
        CurrentWeaponData = data
    else
        CurrentWeaponData = {}
    end
    CanShoot = bool
end)

RegisterNetEvent('ps-fuel:client:refilcarfrompump', function()
	local vehicle = QBCore.Functions.GetClosestVehicle()
	local CurFuel = GetVehicleFuelLevel(vehicle)
	local refillCost = Round(Config.RefillCost - CurFuel) * Config.CostMultiplier
	local ped = PlayerPedId()
	local time = (100 - CurFuel) * 400
	local pedcoords = GetEntityCoords(ped)
	local vehiclepos = GetEntityCoords(vehicle)
	local lastvehicle = GetVehiclePedIsIn(ped, true)

	if vehicle ~= lastvehicle then
		QBCore.Functions.Notify("No vehicle Found! / Not last vehicle entered", "error")
	else
		if #(pedcoords - vehiclepos) > 3 then
			return QBCore.Functions.Notify("Vehicle too far away, Bring it closer!", "error")
		end
		exports['qb-target']:AllowTargeting(false)
		TaskTurnPedToFaceEntity(ped, vehicle, time)
		QBCore.Functions.Progressbar("refuel-car", "Refueling", time, false, true, {
			disableMovement = true,
			disableCarMovement = true,
			disableMouse = false,
			disableCombat = true,
		},
		{
			animDict = "weapon@w_sp_jerrycan",
			anim = "fire",
			flags = 49,
		},
		{},
		{},
		function() -- Done
			TriggerServerEvent('ps-fuel:server:PayForFuel', refillCost, false, false)
			SetFuel(vehicle, 100)
			StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
			ClearPedTasks(ped)
			QBCore.Functions.Notify("Vehicle Refuelled!", "success")
			exports['qb-target']:AllowTargeting(true)
		end,
		function() -- Cancel
			QBCore.Functions.Notify(Lang:t("notify.refuel_cancel"), "error")
			StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
			ClearPedTasks(ped)
			exports['qb-target']:AllowTargeting(true)
		end)
	end
end)

RegisterNetEvent('ps-fuel:client:refilcarfromjerrycan', function()
	local vehicle = QBCore.Functions.GetClosestVehicle()
	local CurFuel = GetVehicleFuelLevel(vehicle)
	local ped = PlayerPedId()
	local time = (100 - CurFuel) * 400
	local pedcoords = GetEntityCoords(ped)
	local vehiclepos = GetEntityCoords(vehicle)
	local lastvehicle = GetVehiclePedIsIn(ped, true)

	local fuelToAdd = tonumber((100 - CurFuel) * 45)
	local weapon = GetSelectedPedWeapon(ped)
	local ammo = GetAmmoInPedWeapon(ped, weapon)

	if fuelToAdd == 0 then
		return QBCore.Functions.Notify("Vehicle already full", "error")
	end
	if ammo <= 40 then
		QBCore.Functions.Notify("No fuel in gas can", "error")
	else
		if vehicle ~= lastvehicle then
			QBCore.Functions.Notify("No vehicle Found! / Not last vehicle entered", "error")
		else
			if #(pedcoords - vehiclepos) > 3 then
				return QBCore.Functions.Notify("Vehicle too far away, Bring it closer!", "error")
			end

			exports['qb-target']:AllowTargeting(false)
			TaskTurnPedToFaceEntity(ped, vehicle, time)
			
			QBCore.Functions.Progressbar("refuel-car", "Refueling", time, false, true, {
				disableMovement = true,
				disableCarMovement = true,
				disableMouse = false,
				disableCombat = true,
			},
			{
				animDict = "weapon@w_sp_jerrycan",
				anim = "fire",
				flags = 49,
			},
			{},
			{},
			function() -- Done
				SetFuel(vehicle, 100)
				local totalAmmo = math.floor(math.abs(ammo - fuelToAdd))
				if totalAmmo < 0 then
					totalAmmo = 0
				end
				TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, totalAmmo)
				PlaySound(-1, "5_SEC_WARNING", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
				StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
				ClearPedTasks(ped)
				exports['qb-target']:AllowTargeting(true)
			end,
			function() -- Cancel
				QBCore.Functions.Notify(Lang:t("notify.refuel_cancel"), "error")
				StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
				ClearPedTasks(ped)
				exports['qb-target']:AllowTargeting(true)
			end)
		end
	end
end)


-- RegisterNetEvent('ps-fuel:client:RefuelVehicle', function(refillCost)
-- 	local vehicle = QBCore.Functions.GetClosestVehicle()
-- 	local ped = PlayerPedId()
-- 	local CurFuel = GetFuel(vehicle)
-- 	local time = (100 - CurFuel) * 400
-- 	local vehicleCoords = GetEntityCoords(vehicle)
-- 	if inGasStation == false and not HasPedGotWeapon(ped, 883325847) then
-- 	elseif inGasStation == false and GetAmmoInPedWeapon(ped, 883325847) == 0 then
-- 		return
-- 	end
	-- if HasPedGotWeapon(ped, 883325847) then
	-- 	local fuelToAdd = tonumber((100 - CurFuel) * 45)
	-- 	local weapon = GetSelectedPedWeapon(PlayerPedId())
	-- 	local ammo = GetAmmoInPedWeapon(PlayerPedId(), weapon)
	-- 	if fuelToAdd == 0 then
	-- 		QBCore.Functions.Notify("Vehicle already full", "error")
	-- 		return
	-- 	end
	-- 	if ammo <= 40 then
	-- 		QBCore.Functions.Notify("No fuel in gas can", "error")
	-- 	else
	-- 		if GetIsVehicleEngineRunning(vehicle) and Config.VehicleBlowUp then
	-- 			local Chance = math.random(1, 100)
	-- 		if Chance <= Config.BlowUpChance then
	-- 			AddExplosion(vehicleCoords, 5, 50.0, true, false, true)
	-- 				return
	-- 			end
	-- 		end
	-- 		TriggerEvent("ps-fuel:client:fuelTick", vehicle)
	-- 		QBCore.Functions.Progressbar("refuel-car", "Refueling", time, false, true, {
	-- 			disableMovement = true,
	-- 			disableCarMovement = true,
	-- 			disableMouse = false,
	-- 			disableCombat = true,
	-- 		},
	-- 		{
	-- 			animDict = "weapon@w_sp_jerrycan",
	-- 			anim = "fire",
	-- 			flags = 49,
	-- 		},
	-- 		{},
	-- 		{},
	-- 		function() -- Done
	-- 			SetFuel(vehicle, 100)
	-- 			local totalAmmo = math.floor(math.abs(ammo - fuelToAdd))
	-- 			if totalAmmo < 0 then
	-- 				totalAmmo = 0
	-- 			end
	-- 			TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, totalAmmo)
	-- 			PlaySound(-1, "5_SEC_WARNING", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
	-- 			StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
	-- 			isFueling = false
	-- 		end,
	-- 		function() -- Cancel
	-- 			QBCore.Functions.Notify(Lang:t("notify.refuel_cancel"), "error")
	-- 			StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
	-- 		end)
	-- 	end
	-- else
-- 		if inGasStation then
-- 			if isCloseVeh() then
-- 				if QBCore.Functions.GetPlayerData().money['cash'] <= refillCost then 
-- 					QBCore.Functions.Notify(Lang:t("notify.no_money"), "error")
-- 				else
-- 				RequestAnimDict("weapon@w_sp_jerrycan")
-- 				while not HasAnimDictLoaded('weapon@w_sp_jerrycan') do Wait(100) end
-- 				TaskPlayAnim(ped, "weapon@w_sp_jerrycan", "fire", 8.0, 1.0, -1, 1, 0, 0, 0, 0 )
-- 				if GetIsVehicleEngineRunning(vehicle) and Config.VehicleBlowUp then
-- 					local Chance = math.random(1, 100)
-- 				if Chance <= Config.BlowUpChance then
-- 					AddExplosion(vehicleCoords, 5, 50.0, true, false, true)
-- 						return
-- 					end
-- 				end
-- 				QBCore.Functions.Progressbar("refuel-car", "Refueling", time, false, true, {
-- 					disableMovement = true,
-- 					disableCarMovement = true,
-- 					disableMouse = false,
-- 					disableCombat = true,
-- 				}, {}, {}, {}, function() -- Done
-- 					TriggerServerEvent('ps-fuel:server:PayForFuel', refillCost, GetPlayerServerId(PlayerId()))
-- 					SetFuel(vehicle, 100)
-- 					PlaySound(-1, "5_SEC_WARNING", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
-- 					StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
-- 				end, function() -- Cancel
-- 					QBCore.Functions.Notify(Lang:t("notify.refuel_cancel"), "error")
-- 					StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
-- 					end)
-- 				end
-- 			end
-- 		end
-- 	end
-- end)

-- Target Export

exports['qb-target']:AddTargetModel(props, {
	options = {
		{
			type = "client",
			event = "ps-fuel:client:buyCan",
			icon = "fas fa-burn",
			label = "Buy Jerry Can",
			canInteract = function(entity)
				if isHoldingWeapon(GetHashKey("weapon_petrolcan")) then
					return false
				end
				return true
			end,
			
		},
		{
			type = "client",
			event = "ps-fuel:client:refilcarfrompump",
			icon = "fas fa-burn",
			label = "Refuel Car from Pump",
			canInteract = function(entity)
				if isHoldingWeapon(GetHashKey("weapon_petrolcan")) then
					return false
				end
				return true
			end,
			
		},
		{
			type = "client",
			event = "ps-fuel:client:refuelCan",
			icon = "fas fa-gas-pump",
			label = "Refuel Jerry Can",
			canInteract = function(entity)
				return isHoldingWeapon(GetHashKey("weapon_petrolcan"))
			end,
		},
	},
	distance = 2.0
})
