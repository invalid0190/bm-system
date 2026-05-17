-- =============================================================================
-- CLIENT DISPATCH INTEGRATION
-- =============================================================================

local function GetDispatchConfig()
    return Config.Dispatch or {}
end

local function ResolveDispatchProvider(provider)
    provider = BMString(provider, 'auto')

    if provider ~= 'auto' then
        return provider
    end

    if GetResourceState('ps-dispatch') == 'started' then
        return 'ps-dispatch'
    end

    if GetResourceState('cd_dispatch') == 'started' then
        return 'cd_dispatch'
    end

    if GetResourceState('core_dispatch') == 'started' then
        return 'core_dispatch'
    end

    if GetResourceState('core_dispach') == 'started' then
        return 'core_dispach'
    end

    return 'none'
end

local function VectorFromPayload(coords)
    if not coords or not coords.x or not coords.y or not coords.z then
        return GetEntityCoords(PlayerPedId())
    end

    return vector3(BMNumber(coords.x, 0.0), BMNumber(coords.y, 0.0), BMNumber(coords.z, 0.0))
end

local function GetStreetLabel(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash and GetStreetNameFromHashKey(streetHash) or ''
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

    if crossing ~= '' then
        return street .. ' / ' .. crossing
    end

    return street ~= '' and street or 'Unknown area'
end

local function GetJobs(payload)
    local dispatchConfig = GetDispatchConfig()
    local jobs = type(payload.jobs) == 'table' and payload.jobs or dispatchConfig.jobs

    return type(jobs) == 'table' and jobs or { 'police' }
end

local function GetJobTypes(payload)
    local dispatchConfig = GetDispatchConfig()
    local jobs = type(payload.jobTypes) == 'table' and payload.jobTypes or dispatchConfig.jobTypes

    return type(jobs) == 'table' and jobs or { 'leo' }
end

local function GetBlip(payload)
    local dispatchConfig = GetDispatchConfig()

    return type(payload.blip) == 'table' and payload.blip or dispatchConfig.blip or {}
end

local function SendPsDispatch(payload, coords)
    TriggerServerEvent('ps-dispatch:server:notify', {
        message = BMString(payload.message, 'Suspicious activity reported nearby.'),
        codeName = BMString(payload.codeName, 'blackmarket_activity'),
        code = BMString(payload.code, '10-66'),
        icon = 'fas fa-user-secret',
        priority = BMInteger(payload.priority, 2),
        coords = coords,
        street = GetStreetLabel(coords),
        heading = GetEntityHeading(PlayerPedId()),
        jobs = GetJobTypes(payload)
    })
end

local function SendCdDispatch(payload, coords)
    local blip = GetBlip(payload)
    local uniqueId = tostring(math.random(1000000, 9999999))

    pcall(function()
        local data = exports['cd_dispatch']:GetPlayerInfo()
        if type(data) == 'table' and data.unique_id then
            uniqueId = data.unique_id
        end
    end)

    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table = GetJobs(payload),
        coords = coords,
        title = string.format('%s - %s', BMString(payload.code, '10-66'), BMString(payload.title, 'Suspicious Activity')),
        message = BMString(payload.message, 'Suspicious activity reported nearby.'),
        flash = 0,
        unique_id = uniqueId,
        sound = 1,
        blip = {
            sprite = BMInteger(blip.sprite, 66),
            scale = BMNumber(blip.scale, 1.2),
            colour = BMInteger(blip.colour or blip.color, 1),
            flashes = blip.flashes == true,
            text = BMString(payload.title, 'Suspicious Activity'),
            time = BMInteger(blip.time, 5),
            radius = BMInteger(blip.radius, 80)
        }
    })
end

local function SendCoreDispatch(payload, coords, provider)
    local blip = GetBlip(payload)
    local jobs = GetJobs(payload)
    local job = BMString(jobs[1], 'police')
    local info = {
        { icon = 'fa-solid fa-user-secret', info = BMString(payload.message, 'Suspicious activity reported nearby.') },
        { icon = 'fa-solid fa-map-location-dot', info = GetStreetLabel(coords) }
    }
    local coordsTable = { coords.x, coords.y, coords.z }
    local resourceName = provider == 'core_dispach' and 'core_dispach' or 'core_dispatch'

    exports[resourceName]:addCall(
        BMString(payload.code, '10-66'),
        BMString(payload.title, 'Suspicious Activity'),
        info,
        coordsTable,
        job,
        BMInteger(blip.time, 5) * 60000,
        BMInteger(blip.sprite, 66),
        BMInteger(blip.colour or blip.color, 1)
    )
end

local function SendCustomDispatch(payload, coords)
    local eventName = payload.customEvent or (Config.Dispatch and Config.Dispatch.customEvent)
    if not eventName then
        return false
    end

    if payload.customEventIsServer then
        TriggerServerEvent(eventName, payload, coords)
    else
        TriggerEvent(eventName, payload, coords)
    end

    return true
end

RegisterNetEvent('blackmarket:client:dispatchAlert', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local dispatchConfig = GetDispatchConfig()
    if not dispatchConfig.enabled then
        return
    end

    local provider = ResolveDispatchProvider(payload.provider)
    if provider == 'none' then
        DebugPrint('No dispatch provider running for black market alert')
        return
    end

    local coords = VectorFromPayload(payload.coords)
    local ok, err = pcall(function()
        if provider == 'ps-dispatch' then
            SendPsDispatch(payload, coords)
        elseif provider == 'cd_dispatch' then
            SendCdDispatch(payload, coords)
        elseif provider == 'core_dispatch' or provider == 'core_dispach' then
            SendCoreDispatch(payload, coords, provider)
        elseif provider == 'custom' then
            SendCustomDispatch(payload, coords)
        end
    end)

    if not ok then
        BMLog('WARN', 'Dispatch alert failed for provider %s: %s', provider, BMString(err))
    end
end)
