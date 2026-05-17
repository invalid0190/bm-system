-- =============================================================================
-- SERVER DISPATCH GATING
-- =============================================================================

local LastDispatchAt = 0

local function GetDispatchConfig()
    return Config.Dispatch or {}
end

local function GetAlertConfig(alertType)
    local dispatchConfig = GetDispatchConfig()
    local alerts = type(dispatchConfig.alerts) == 'table' and dispatchConfig.alerts or {}

    return type(alerts[alertType]) == 'table' and alerts[alertType] or {}
end

local function GetPlayerCoords(playerId)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return nil end

    return GetEntityCoords(ped)
end

local function FuzzCoords(coords)
    local dispatchConfig = GetDispatchConfig()
    local radius = BMNumber(dispatchConfig.locationFuzzRadius, 0.0)

    if not coords or radius <= 0.0 then
        return coords
    end

    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius

    return vector3(
        coords.x + math.cos(angle) * distance,
        coords.y + math.sin(angle) * distance,
        coords.z
    )
end

function TryBlackMarketDispatch(playerId, alertType, extraData)
    local dispatchConfig = GetDispatchConfig()
    if not dispatchConfig.enabled or dispatchConfig.provider == 'none' then
        return false
    end

    local alertConfig = GetAlertConfig(alertType)
    local chance = BMInteger(alertConfig.chance, 0)
    local force = type(extraData) == 'table' and extraData.force == true

    if not force and (chance <= 0 or math.random(1, 100) > chance) then
        return false
    end

    local cooldown = BMInteger(dispatchConfig.cooldown, 120)
    if not force and cooldown > 0 and os.time() - BMInteger(LastDispatchAt, 0) < cooldown then
        return false
    end

    local coords = GetPlayerCoords(playerId)
    if not coords and type(GetCurrentDealerCoords) == 'function' then
        coords = GetCurrentDealerCoords()
    end
    if not coords then
        return false
    end

    LastDispatchAt = os.time()
    local alertCoords = FuzzCoords(coords)

    TriggerClientEvent('blackmarket:client:dispatchAlert', playerId, {
        provider = BMString(dispatchConfig.provider, 'auto'),
        type = BMString(alertType, 'purchase'),
        coords = {
            x = BMNumber(alertCoords.x, 0.0),
            y = BMNumber(alertCoords.y, 0.0),
            z = BMNumber(alertCoords.z, 0.0)
        },
        code = BMString(alertConfig.code, '10-66'),
        codeName = BMString(alertConfig.codeName, 'blackmarket_activity'),
        title = BMString(alertConfig.title, 'Suspicious Activity'),
        message = BMString(alertConfig.message, 'Possible underground market activity reported nearby.'),
        priority = BMInteger(alertConfig.priority, 2),
        jobs = dispatchConfig.jobs,
        jobTypes = dispatchConfig.jobTypes,
        blip = dispatchConfig.blip,
        customEvent = dispatchConfig.customEvent,
        customEventIsServer = dispatchConfig.customEventIsServer == true,
        extra = extraData or {}
    })

    return true
end

RegisterCommand('bm_testdispatch', function(source, args)
    if source == 0 then
        BMLog('INFO', 'Run bm_testdispatch in-game so the dispatch resource receives player context.')
        return
    end

    args = args or {}
    local alertType = BMString(args[1], 'purchase')
    TryBlackMarketDispatch(source, alertType, { test = true, force = true })
end, true)

exports('tryBlackMarketDispatch', TryBlackMarketDispatch)
