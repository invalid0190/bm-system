BMPropSystem = BMPropSystem or {}
BMPropSystem.tracked = BMPropSystem.tracked or {}

local function GetPropConfig()
    return Config.Props or {}
end

local function GetModelCandidates(modelNames)
    if type(modelNames) == 'table' then
        return modelNames
    end

    return { modelNames }
end

local function ShowPropLoadProgress(label)
    local propsConfig = GetPropConfig()
    local progress = type(propsConfig.progress) == 'table' and propsConfig.progress or {}

    if progress.enabled == false or type(lib) ~= 'table' or type(lib.progressBar) ~= 'function' then
        return
    end

    pcall(function()
        lib.progressBar({
            duration = BMInteger(progress.duration, 900),
            label = BMString(label, BMString(progress.label, 'Preparing props...')),
            canCancel = false,
            disable = {
                combat = true
            }
        })
    end)
end

-- Loads the first valid model from the supplied model name list.
function BMPropSystem.LoadModel(modelNames, label)
    local propsConfig = GetPropConfig()
    if propsConfig.enabled == false then
        return nil
    end

    for _, modelName in ipairs(GetModelCandidates(modelNames)) do
        if modelName then
            local modelHash = type(modelName) == 'number' and modelName or GetHashKey(BMString(modelName))

            if IsModelInCdimage(modelHash) and IsModelValid(modelHash) then
                RequestModel(modelHash)
                ShowPropLoadProgress(label)

                local startedAt = GetGameTimer()
                while not HasModelLoaded(modelHash) do
                    if GetGameTimer() - startedAt > BMInteger(propsConfig.loadTimeout, 5000) then
                        BMLog('ERROR', 'Timed out loading prop model: %s', BMString(modelName))
                        break
                    end

                    Wait(25)
                end

                if HasModelLoaded(modelHash) then
                    return modelHash
                end
            end
        end
    end

    BMLog('WARN', 'No valid prop model found for requested prop.')
    return nil
end

local function TrackProp(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        BMPropSystem.tracked[#BMPropSystem.tracked + 1] = entity
    end
end

-- Creates a local ground prop and places it properly on the nearest surface.
function BMPropSystem.CreateGroundProp(modelNames, coords, heading, label)
    if not coords then
        return nil
    end

    local modelHash = BMPropSystem.LoadModel(modelNames, label)
    if not modelHash then
        return nil
    end

    local entity = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        BMLog('ERROR', 'Failed to create ground prop.')
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityHeading(entity, BMNumber(heading, 0.0))
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    TrackProp(entity)
    SetModelAsNoLongerNeeded(modelHash)

    return entity
end

-- Attaches a prop to a ped bone, used by the P2P trade bag.
function BMPropSystem.AttachPropToPed(modelNames, ped, bone, offset, rotation, label)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end

    local modelHash = BMPropSystem.LoadModel(modelNames, label)
    if not modelHash then
        return nil
    end

    local entity = CreateObject(modelHash, 0.0, 0.0, 0.0, false, false, false)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        BMLog('ERROR', 'Failed to create attached prop.')
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    offset = offset or vector3(0.0, 0.0, 0.0)
    rotation = rotation or vector3(0.0, 0.0, 0.0)

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, false, false)

    AttachEntityToEntity(
        entity,
        ped,
        GetPedBoneIndex(ped, BMInteger(bone, 57005)),
        BMNumber(offset.x, 0.0),
        BMNumber(offset.y, 0.0),
        BMNumber(offset.z, 0.0),
        BMNumber(rotation.x, 0.0),
        BMNumber(rotation.y, 0.0),
        BMNumber(rotation.z, 0.0),
        true,
        true,
        false,
        true,
        1,
        true
    )

    TrackProp(entity)
    SetModelAsNoLongerNeeded(modelHash)

    return entity
end

local function PlayDropAnimation(duration)
    local ped = PlayerPedId()
    local dict = 'pickup_object'
    local anim = 'putdown_low'

    RequestAnimDict(dict)
    local startedAt = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - startedAt <= 1500 do
        Wait(25)
    end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, BMInteger(duration, 1200), 48, 0.0, false, false, false)
    end
end

-- Deletes a prop safely, optionally detaching and dropping it first.
function BMPropSystem.DeleteProp(entity, drop, dropDuration)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return
    end

    if drop then
        PlayDropAnimation(dropDuration)
        DetachEntity(entity, true, true)
        SetEntityCollision(entity, true, true)
        PlaceObjectOnGroundProperly(entity)
        Wait(BMInteger(dropDuration, 1200))
    end

    DeleteEntity(entity)
end

-- Removes every prop created through this helper on resource stop.
function BMPropSystem.Cleanup()
    for i = #BMPropSystem.tracked, 1, -1 do
        local entity = BMPropSystem.tracked[i]
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end

        BMPropSystem.tracked[i] = nil
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        BMPropSystem.Cleanup()
    end
end)
