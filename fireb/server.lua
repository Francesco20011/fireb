RegisterNetEvent("super_feuerball:throwFireball")
AddEventHandler("super_feuerball:throwFireball", function(start, target)
    local src = source
    TriggerClientEvent("super_feuerball:spawnFireball", -1, src, start, target)
end)

RegisterNetEvent("super_feuerball:applyDamage")
AddEventHandler("super_feuerball:applyDamage", function(impactPos)
    -- Applica danno agli NPC e ai giocatori
    local peds = GetPlayersInArea(impactPos, 6.0)
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then
            local currentHealth = GetEntityHealth(ped)
            if currentHealth > 0 then
                SetEntityHealth(ped, math.max(0, currentHealth - 200)) -- Danno di 200 per garantire morte
            end
        end
    end

    -- Applica danno ai veicoli con esplosione
    local vehicles = GetVehiclesInArea(impactPos, 6.0)
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            SetVehicleEngineHealth(vehicle, 0.0)
            SetVehiclePetrolTankHealth(vehicle, 0.0)
            local vehPos = GetEntityCoords(vehicle)
            TriggerClientEvent("super_feuerball:triggerExplosion", -1, vehPos.x, vehPos.y, vehPos.z) -- Esplosione sincronizzata
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and DoesEntityExist(driver) then
                local driverHealth = GetEntityHealth(driver)
                if driverHealth > 0 then
                    SetEntityHealth(driver, math.max(0, driverHealth - 200))
                end
            end
        end
    end

    -- Esplosione al punto di impatto
    TriggerClientEvent("super_feuerball:triggerExplosion", -1, impactPos.x, impactPos.y, impactPos.z)
end)

function GetPlayersInArea(coords, radius)
    local peds = {}
    local handle, ped = FindFirstPed()
    local success
    repeat
        local pedPos = GetEntityCoords(ped)
        if #(pedPos - coords) < radius then
            table.insert(peds, ped)
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)
    return peds
end

function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        local vehPos = GetEntityCoords(vehicle)
        if #(vehPos - coords) < radius then
            table.insert(vehicles, vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return vehicles
end