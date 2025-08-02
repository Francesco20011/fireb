local isFireballMode = false
local markerActive = false
local handEffects = { left = nil, right = nil, sound = nil }
local cooldown = false
local markerColor = { r = 255, g = 80, b = 0, a = 200 }
local markerType = 28
local fireballSpeed = 30.0
local fireballMaxDist = 40.0
local fireballTimeout = 20000 -- 20 secondi
local fireballCooldown = 10000 -- 10 secondi
local timeoutThread = nil

-- Effetti particellari
local handDict = "scr_carrier_heist"
local handName1 = "scr_heist_carrier_elec_fire" -- Effetto base
local handName2 = "scr_heist_carrier_flare"     -- Effetto aggiuntivo per dinamismo
local handScale = 0.7
local flyDict = "core"
local flyName = "fire_wrecked_plane_cockpit"
local flyScale = 1.5
local impactDict = "core"
local impactName = "exp_grd_petrol_pump"
local impactScale = 2.0

-- Suoni
local handSound = "FIRE_LOOP_1"
local impactSound = "FIRE_WOODCRACKLE" -- Suono da fuoco

function RotToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

function ScreenToWorld()
    local camRot = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local forward = RotToDirection(camRot)
    local rayLength = fireballMaxDist

    local dest = camCoord + forward * rayLength
    local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, 1, PlayerPedId(), 0)
    local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit == 1 then
        return endCoords
    else
        return dest
    end
end

local function loadPtfx(dict)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = 0
        while not HasNamedPtfxAssetLoaded(dict) and timeout < 10000 do
            Wait(50)
            timeout = timeout + 50
        end
        if timeout >= 10000 then
            return false
        end
    end
    return true
end

local function stopHandEffect()
    if handEffects.sound then
        StopSound(handEffects.sound)
        handEffects.sound = nil
    end
    if handEffects.left then
        StopParticleFxLooped(handEffects.left, false)
        handEffects.left = nil
    end
    if handEffects.right then
        StopParticleFxLooped(handEffects.right, false)
        handEffects.right = nil
    end
end

local function startHandEffect()
    stopHandEffect()
    
    if loadPtfx(handDict) then
        local playerPed = PlayerPedId()
        
        -- Effetto sulla mano sinistra (base + aggiuntivo)
        UseParticleFxAssetNextCall(handDict)
        local leftFx1 = StartParticleFxLoopedOnPedBone(
            handName1, playerPed, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, GetPedBoneIndex(playerPed, 18905), handScale, false, false, false
        )
        SetParticleFxLoopedColour(leftFx1, 1.0, 0.5, 0.0, false) -- Arancione intenso
        SetParticleFxLoopedAlpha(leftFx1, 1.0)
        
        UseParticleFxAssetNextCall(handDict)
        local leftFx2 = StartParticleFxLoopedOnPedBone(
            handName2, playerPed, 0.1, 0.0, -0.1, 0.0, 0.0, 0.0, GetPedBoneIndex(playerPed, 18905), handScale * 0.8, false, false, false
        )
        SetParticleFxLoopedColour(leftFx2, 1.0, 0.3, 0.0, false) -- Rosso scuro
        SetParticleFxLoopedAlpha(leftFx2, 0.8)
        
        -- Effetto sulla mano destra (base + aggiuntivo)
        UseParticleFxAssetNextCall(handDict)
        local rightFx1 = StartParticleFxLoopedOnPedBone(
            handName1, playerPed, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, GetPedBoneIndex(playerPed, 57005), handScale, false, false, false
        )
        SetParticleFxLoopedColour(rightFx1, 1.0, 0.5, 0.0, false) -- Arancione intenso
        SetParticleFxLoopedAlpha(rightFx1, 1.0)
        
        UseParticleFxAssetNextCall(handDict)
        local rightFx2 = StartParticleFxLoopedOnPedBone(
            handName2, playerPed, 0.1, 0.0, -0.1, 0.0, 0.0, 0.0, GetPedBoneIndex(playerPed, 57005), handScale * 0.8, false, false, false
        )
        SetParticleFxLoopedColour(rightFx2, 1.0, 0.3, 0.0, false) -- Rosso scuro
        SetParticleFxLoopedAlpha(rightFx2, 0.8)
        
        -- Suono di attivazione (falò)
        local soundId = GetSoundId()
        PlaySoundFromEntity(soundId, handSound, playerPed, 0, false, 0)
        
        if leftFx1 and leftFx2 and rightFx1 and rightFx2 and soundId then
            handEffects.left = leftFx1
            handEffects.right = rightFx1
            handEffects.sound = soundId
        else
            -- Fallback: effetto fisso davanti al giocatore
            local playerPos = GetEntityCoords(playerPed)
            UseParticleFxAssetNextCall(handDict)
            local fallbackFx = StartParticleFxLoopedAtCoord(
                handName1, playerPos.x, playerPos.y, playerPos.z + 1.0, 0.0, 0.0, 0.0, handScale, false, false, false
            )
            SetParticleFxLoopedColour(fallbackFx, 1.0, 0.5, 0.0, false)
            SetParticleFxLoopedAlpha(fallbackFx, 1.0)
            if fallbackFx then
                handEffects.left = fallbackFx
            end
            -- Suono di fallback
            PlaySoundFromEntity(soundId, handSound, playerPed, 0, false, 0)
            handEffects.sound = soundId
        end
    end
end

local function disableFireballMode(msg)
    isFireballMode = false
    markerActive = false
    stopHandEffect()
    local playerPed = PlayerPedId()
    ClearPedTasksImmediately(playerPed) -- Interrompe l'emote quando si esce dalla modalità
    if msg then
        TriggerEvent("chat:addMessage", { args = { "[Palla di Fuoco]", msg } })
    end
end

-- Registra il comando
RegisterCommand("fireb", function()
    if cooldown then
        TriggerEvent("chat:addMessage", { args = { "[Palla di Fuoco]", "Ricarica in corso! Aspetta un momento..." } })
        return
    end
    if not isFireballMode then
        isFireballMode = true
        markerActive = true
        startHandEffect()
        local playerPed = PlayerPedId()
        TaskStartScenarioInPlace(playerPed, "mood_mindcontrol_2", 0, true) -- Avvia l'emote mindcontrol2
        TriggerEvent("chat:addMessage", { args = { "[Palla di Fuoco]", "Sei ora in modalità Palla di Fuoco! Clic sinistro per lanciare." } })

        -- Avvia il thread di timeout
        if timeoutThread then TerminateThread(timeoutThread) end
        timeoutThread = Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while isFireballMode do
                Citizen.Wait(250)
                if GetGameTimer() - startTime > fireballTimeout then
                    disableFireballMode("Troppo lento! Effetto rimosso. (Ricarica 10s)")
                    cooldown = true
                    Citizen.SetTimeout(fireballCooldown, function()
                        cooldown = false
                    end)
                    break
                end
            end
        end)
    else
        disableFireballMode("Modalità Palla di Fuoco disattivata.")
    end
end)

-- Mostra il mirino (con raycast)
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if markerActive then
            local markerPos = ScreenToWorld()
            DrawMarker(markerType, markerPos.x, markerPos.y, markerPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, markerColor.r, markerColor.g, markerColor.b, markerColor.a, false, true, 2, nil, nil, false)
        else
            Wait(250)
        end
    end
end)

-- Lancia la palla di fuoco
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if isFireballMode and not cooldown then
            DisableControlAction(0, 24, true) -- Disabilita l'attacco (clic sinistro)
            if IsDisabledControlJustPressed(0, 24) then -- Clic sinistro
                local playerPed = PlayerPedId()
                local start = GetEntityCoords(playerPed)
                local target = ScreenToWorld()
                TriggerServerEvent("super_feuerball:throwFireball", start, target)
                stopHandEffect()
                disableFireballMode("Palla di fuoco lanciata! (Ricarica 10s)")
                cooldown = true
                Citizen.SetTimeout(fireballCooldown, function()
                    cooldown = false
                end)
            end
        else
            Wait(100)
        end
    end
end)

-- Mostra la palla di fuoco (sincronizzata dal server)
RegisterNetEvent("super_feuerball:spawnFireball")
AddEventHandler("super_feuerball:spawnFireball", function(shooterId, start, target)
    -- Crea un oggetto invisibile per trasportare l'effetto
    local model = GetHashKey("prop_tennis_ball")
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do 
        Wait(10) 
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(model) then
        model = GetHashKey("prop_amb_beer_bottle")
        RequestModel(model)
        timeout = 0
        while not HasModelLoaded(model) and timeout < 5000 do 
            Wait(10) 
            timeout = timeout + 10
        end
        if not HasModelLoaded(model) then
            return
        end
    end
    
    local obj = CreateObject(model, start.x, start.y, start.z, true, true, true)
    SetEntityVisible(obj, false, 0)
    SetEntityAlpha(obj, 0, false)
    SetEntityCollision(obj, true, true)
    
    -- Carica e avvia l'effetto di volo
    local fx = nil
    if loadPtfx(flyDict) then
        UseParticleFxAssetNextCall(flyDict)
        fx = StartParticleFxLoopedOnEntity(
            flyName, obj, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, flyScale, false, false, false
        )
        if not fx then
            UseParticleFxAssetNextCall(flyDict)
            fx = StartParticleFxLoopedAtCoord(
                flyName, start.x, start.y, start.z, 0.0, 0.0, 0.0, flyScale, false, false, false
            )
        end
    end
    
    -- Simula il volo
    local dir = vector3(target.x, target.y, target.z) - vector3(start.x, start.y, start.z)
    local dist = #(dir)
    local norm = dir / dist
    local speed = fireballSpeed
    local t = 0.0
    local pos = vector3(start.x, start.y, start.z)
    local stepTime = 0.01 -- Ridotto per migliorare il rilevamento delle collisioni
    
    -- Thread per il movimento della palla di fuoco
    Citizen.CreateThread(function()
        while t < (dist / speed) do
            Wait(0)
            local step = norm * speed * stepTime
            pos = pos + step
            SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false)
            t = t + stepTime
            
            -- Controlla collisioni
            if HasEntityCollidedWithAnything(obj) then
                break
            end
        end
        
        -- Volo terminato o collisione, mostra l'impatto
        if fx then
            StopParticleFxLooped(fx, false)
        end
        
        -- Effetto e suono di impatto con esplosione
        if loadPtfx(impactDict) then
            UseParticleFxAssetNextCall(impactDict)
            local impactFx = StartParticleFxNonLoopedAtCoord(
                impactName, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, impactScale, false, false, false
            )
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, impactSound, pos.x, pos.y, pos.z, 0, false, 0)
            AddExplosion(pos.x, pos.y, pos.z, 1, 2.0, true, false, 1.0) -- Esplosione tipo granata
        else
            -- Suono di fallback con esplosione
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, impactSound, pos.x, pos.y, pos.z, 0, false, 0)
            AddExplosion(pos.x, pos.y, pos.z, 1, 2.0, true, false, 1.0) -- Esplosione tipo granata
        end
        
        -- Invia l'evento al server per il danno
        TriggerServerEvent("super_feuerball:applyDamage", pos)
        
        -- Pulisci l'oggetto
        DeleteObject(obj)
        SetModelAsNoLongerNeeded(model)
    end)
end)

RegisterNetEvent("super_feuerball:triggerExplosion")
AddEventHandler("super_feuerball:triggerExplosion", function(x, y, z)
    AddExplosion(x, y, z, 1, 2.0, true, false, 1.0) -- Esplosione sincronizzata
end)