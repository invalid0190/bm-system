-- =============================================================================
-- CLIENT BLACK MARKET - NPC & Shop
-- =============================================================================

local blackMarketPed = nil
local blackMarketTargetAdded = false
local dealerState = nil
local shopCrate = nil
local purchaseProp = nil
local crateMonitorActive = false
local DeleteShopCrate
local DeletePurchaseProp
local IsNearBlackMarket

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

local function Notify(title, description, type, duration)
    local defaultDuration = Config.Notify and Config.Notify.durations and Config.Notify.durations.default or 5000

    lib.notify({
        title = BMString(title, 'Black Market'),
        description = BMString(description),
        type = type or 'inform',
        duration = duration or defaultDuration
    })
end

local function GetStreetCred()
    local cred = lib.callback.await('blackmarket:server:getCred', false)
    return BMInteger(cred, 0)
end

local function NormalizeDealerLocation(location)
    if not location or not location.x or not location.y or not location.z then
        return nil
    end

    return {
        index = BMInteger(location.index, 0),
        label = BMString(location.label, 'Unknown'),
        x = BMNumber(location.x, 0.0),
        y = BMNumber(location.y, 0.0),
        z = BMNumber(location.z, 0.0),
        w = BMNumber(location.w, 0.0)
    }
end

local function IsSameDealerLocation(a, b)
    if not a or not b then
        return a == b
    end

    if BMInteger(a.index, 0) > 0 and BMInteger(b.index, 0) > 0 then
        return BMInteger(a.index, 0) == BMInteger(b.index, 0)
    end

    return math.abs(BMNumber(a.x, 0.0) - BMNumber(b.x, 0.0)) < 0.1
        and math.abs(BMNumber(a.y, 0.0) - BMNumber(b.y, 0.0)) < 0.1
        and math.abs(BMNumber(a.z, 0.0) - BMNumber(b.z, 0.0)) < 0.1
end

local function LoadPedModel(model, timeout)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        BMLog('ERROR', 'Invalid black market ped model: %s', BMString(model))
        return false
    end

    RequestModel(model)

    local startedAt = GetGameTimer()
    while not HasModelLoaded(model) do
        if GetGameTimer() - startedAt > BMInteger(timeout, 5000) then
            BMLog('ERROR', 'Timed out loading black market ped model: %s', BMString(model))
            return false
        end

        Wait(50)
    end

    return true
end

local function GetSafeSpawnCoords(coords, attempts)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    return coords.x, coords.y, coords.z, coords.w or 0.0
end

local function DeleteBlackMarketPed()
    if DeleteShopCrate then
        DeleteShopCrate()
    end

    if blackMarketPed and DoesEntityExist(blackMarketPed) then
        if blackMarketTargetAdded then
            pcall(function()
                exports.ox_target:removeLocalEntity(blackMarketPed, { 'blackmarket_open', 'blackmarket_checkcred' })
            end)
        end

        DeleteEntity(blackMarketPed)
    end

    blackMarketPed = nil
    blackMarketTargetAdded = false
end

local function GetFallbackDealerLocation()
    local marketConfig = Config.BlackMarket or {}
    local locations = marketConfig.locations
    
    if marketConfig.locationMode ~= 'static' and type(locations) == 'table' and #locations > 0 then
        local randIndex = math.random(1, #locations)
        local loc = locations[randIndex]
        local coords = loc.coords or loc
        return {
            index = randIndex,
            label = BMString(loc.label, 'Fallback dealer'),
            x = coords.x,
            y = coords.y,
            z = coords.z,
            w = coords.w or 0.0
        }
    end

    local fallback = marketConfig.coords
    if fallback then
        return {
            index = 1,
            label = 'Fallback dealer',
            x = fallback.x,
            y = fallback.y,
            z = fallback.z,
            w = fallback.w or 0.0
        }
    end

    return nil
end

local function RefreshDealerState()
    local previousLocation = dealerState and dealerState.location or nil
    local ok, state = pcall(function()
        return lib.callback.await('blackmarket:server:getDealerState', false)
    end)

    if not ok or type(state) ~= 'table' then
        local fallbackLoc = GetFallbackDealerLocation()
        state = {
            open = true,
            location = fallbackLoc,
            closedMessage = 'Dealer is not available right now.'
        }
    end

    state.location = NormalizeDealerLocation(state.location)
    dealerState = state

    if not state.open or not state.location or not IsSameDealerLocation(previousLocation, state.location) then
        DeleteBlackMarketPed()
    end

    return dealerState
end

local function GetActiveDealerLocation()
    if not dealerState or not dealerState.open then
        return nil
    end

    return dealerState.location
end

-- Selects a short dealer line based on the player's current street cred.
local function GetDealerDialogue(cred, availableItemCount)
    local dialogueConfig = Config.DealerDialogue or {}
    if not dialogueConfig.enabled then
        return nil
    end

    if BMInteger(availableItemCount, 0) <= 0 and dialogueConfig.noStockLine then
        return BMString(dialogueConfig.noStockLine)
    end

    local selectedLevel = nil
    local levels = type(dialogueConfig.levels) == 'table' and dialogueConfig.levels or {}
    for _, level in ipairs(levels) do
        if cred >= BMInteger(level.minCred, 0) then
            selectedLevel = level
        end
    end

    local lines = selectedLevel and type(selectedLevel.lines) == 'table' and selectedLevel.lines or {}
    if #lines > 0 then
        return BMString(lines[math.random(1, #lines)], dialogueConfig.fallbackLine)
    end

    return BMString(dialogueConfig.fallbackLine)
end

local function GetDealerPropCoords(forwardOffset, sideOffset)
    local coords = GetActiveDealerLocation()
    if not coords then
        return nil, 0.0
    end

    local baseCoords = blackMarketPed and DoesEntityExist(blackMarketPed)
        and GetEntityCoords(blackMarketPed)
        or vector3(coords.x, coords.y, coords.z)
    local heading = blackMarketPed and DoesEntityExist(blackMarketPed)
        and GetEntityHeading(blackMarketPed)
        or BMNumber(coords.w, 0.0)

    local radians = math.rad(heading)
    local forward = vector3(-math.sin(radians), math.cos(radians), 0.0)
    local right = vector3(math.cos(radians), math.sin(radians), 0.0)

    return baseCoords
        + (forward * BMNumber(forwardOffset, 0.0))
        + (right * BMNumber(sideOffset, 0.0)), heading
end

DeleteShopCrate = function()
    if shopCrate and DoesEntityExist(shopCrate) then
        if type(BMPropSystem) == 'table' and type(BMPropSystem.DeleteProp) == 'function' then
            BMPropSystem.DeleteProp(shopCrate, false)
        else
            DeleteEntity(shopCrate)
        end
    end

    shopCrate = nil
end

DeletePurchaseProp = function()
    if purchaseProp and DoesEntityExist(purchaseProp) then
        if type(BMPropSystem) == 'table' and type(BMPropSystem.DeleteProp) == 'function' then
            BMPropSystem.DeleteProp(purchaseProp, false)
        else
            DeleteEntity(purchaseProp)
        end
    end

    purchaseProp = nil
end

local function StartShopCrateMonitor()
    if crateMonitorActive then
        return
    end

    crateMonitorActive = true
    CreateThread(function()
        while shopCrate and DoesEntityExist(shopCrate) do
            local propsConfig = Config.Props or {}
            local crateConfig = type(propsConfig.shopCrate) == 'table' and propsConfig.shopCrate or {}
            local removeDistance = BMNumber(crateConfig.removeDistance, 8.0)

            if not IsNearBlackMarket(removeDistance) then
                DeleteShopCrate()
                break
            end

            Wait(1000)
        end

        crateMonitorActive = false
    end)
end

local function SpawnShopCrate()
    local propsConfig = Config.Props or {}
    local crateConfig = type(propsConfig.shopCrate) == 'table' and propsConfig.shopCrate or {}

    if propsConfig.enabled == false or crateConfig.enabled == false or shopCrate and DoesEntityExist(shopCrate) then
        return
    end

    local coords, heading = GetDealerPropCoords(crateConfig.forwardOffset, crateConfig.sideOffset)
    if not coords or type(BMPropSystem) ~= 'table' or type(BMPropSystem.CreateGroundProp) ~= 'function' then
        return
    end

    shopCrate = BMPropSystem.CreateGroundProp(crateConfig.model, coords, heading, 'Loading shop crate...', BMNumber(crateConfig.zOffset, 0.0))
    StartShopCrateMonitor()
end

local function GetPurchasePropModel(category)
    local propsConfig = Config.Props or {}
    local purchaseConfig = type(propsConfig.purchase) == 'table' and propsConfig.purchase or {}
    category = BMString(category, '')

    if category == 'weapons' then
        return purchaseConfig.weaponModel
    end

    local stashCategories = type(purchaseConfig.stashCategories) == 'table' and purchaseConfig.stashCategories or {}
    if stashCategories[category] == true then
        return purchaseConfig.stashModel
    end

    return nil
end

local function SpawnPurchaseProp(category)
    local propsConfig = Config.Props or {}
    local purchaseConfig = type(propsConfig.purchase) == 'table' and propsConfig.purchase or {}

    if propsConfig.enabled == false
        or purchaseConfig.enabled == false
        or type(BMPropSystem) ~= 'table'
        or type(BMPropSystem.CreateGroundProp) ~= 'function' then
        return
    end

    DeletePurchaseProp()

    local model = GetPurchasePropModel(category)
    if not model then
        return
    end

    local coords, heading = GetDealerPropCoords(purchaseConfig.forwardOffset, purchaseConfig.sideOffset)
    if not coords then
        return
    end

    purchaseProp = BMPropSystem.CreateGroundProp(model, coords, heading, 'Loading purchase prop...', BMNumber(purchaseConfig.zOffset, 0.0))
end

local function PlayPurchaseAnimation(duration)
    local dict = 'mp_common'
    local anim = 'givetake1_a'

    RequestAnimDict(dict)
    local startedAt = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - startedAt <= 1500 do
        Wait(25)
    end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, BMInteger(duration, 2500), 48, 0.0, false, false, false)
    end
end

local function RunPurchaseSequence(item, quantity)
    quantity = BMInteger(quantity, 1)
    if not item or not item.name or quantity <= 0 then
        Notify('Black Market', 'Invalid purchase.', 'error')
        return
    end

    local propsConfig = Config.Props or {}
    local purchaseConfig = type(propsConfig.purchase) == 'table' and propsConfig.purchase or {}
    local duration = BMInteger(purchaseConfig.duration, 2500)

    SpawnPurchaseProp(item.category)
    PlayPurchaseAnimation(duration)

    local completed = true
    if type(lib) == 'table' and type(lib.progressBar) == 'function' and duration > 0 then
        completed = lib.progressBar({
            duration = duration,
            label = BMString(purchaseConfig.label, 'Completing the exchange...'),
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })
    elseif duration > 0 then
        Wait(duration)
    end

    ClearPedTasks(PlayerPedId())
    DeletePurchaseProp()

    if completed == false then
        Notify('Black Market', 'Exchange cancelled.', 'error')
        return
    end

    TriggerServerEvent('blackmarket:server:buyItem', item.name, quantity)
end

-- =============================================================================
-- BLACK MARKET NPC SPAWNING
-- =============================================================================

local function CreateBlackMarketPed()
    if blackMarketPed and DoesEntityExist(blackMarketPed) then
        return
    end

    local marketConfig = Config.BlackMarket or {}
    if not dealerState or not dealerState.open then
        RefreshDealerState()
    end

    local coords = GetActiveDealerLocation()
    local model = marketConfig.npcModel
    local npcSettings = type(marketConfig.npc) == 'table' and marketConfig.npc or {}

    if not coords or not model then
        BMLog('ERROR', 'Black market NPC cannot spawn; missing coords or npcModel in config.')
        return
    end

    if not LoadPedModel(model, npcSettings.spawnTimeout) then
        return
    end

    local x, y, z, heading = GetSafeSpawnCoords(coords, npcSettings.groundCheckAttempts)
    blackMarketPed = CreatePed(4, model, x, y, z, heading, false, true)

    if not blackMarketPed or blackMarketPed == 0 or not DoesEntityExist(blackMarketPed) then
        BMLog('ERROR', 'Failed to create black market dealer ped.')
        SetModelAsNoLongerNeeded(model)
        blackMarketPed = nil
        return
    end
    
    SetEntityInvincible(blackMarketPed, true)
    SetBlockingOfNonTemporaryEvents(blackMarketPed, true)
    SetPedFleeAttributes(blackMarketPed, 0, false)
    SetPedDiesWhenInjured(blackMarketPed, false)
    SetPedCanRagdoll(blackMarketPed, false)
    SetEntityHeading(blackMarketPed, heading)
    SetEntityCoordsNoOffset(blackMarketPed, x, y, z, false, false, false)

    -- Let the ped settle on the ground for 200ms before freezing
    local tempPed = blackMarketPed
    CreateThread(function()
        Wait(200)
        if tempPed and DoesEntityExist(tempPed) then
            FreezeEntityPosition(tempPed, true)
        end
    end)

    local alpha = BMInteger(npcSettings.alpha, 255)
    if alpha >= 0 and alpha < 255 then
        SetEntityAlpha(blackMarketPed, alpha, false)
    end

    if npcSettings.scenario then
        TaskStartScenarioInPlace(blackMarketPed, BMString(npcSettings.scenario), 0, true)
    end
    
    -- Configure ox_target for the ped
    exports.ox_target:addLocalEntity(blackMarketPed, {
        {
            name = 'blackmarket_open',
            icon = 'fa-solid fa-user-secret',
            label = 'Speak to Dealer',
            distance = BMNumber(marketConfig.targetDistance, 2.5),
            onSelect = function()
                OpenBlackMarketMenu()
            end
        },
        {
            name = 'blackmarket_checkcred',
            icon = 'fa-solid fa-star',
            label = 'Check Street Cred',
            distance = BMNumber(marketConfig.targetDistance, 2.5),
            onSelect = function()
                local cred = GetStreetCred()
                Notify('Street Cred', string.format('Your reputation: %d/100', cred), 'inform')
            end
        }
    })
    blackMarketTargetAdded = true
    SetModelAsNoLongerNeeded(model)
    
    DebugPrint(('NPC spawned at %.2f %.2f %.2f heading %.2f'):format(x, y, z, heading))
end

-- Tracks whether this client is close enough for the server to apply a fake visible job.
local disguiseActive = false

local function SetDisguiseState(active)
    if disguiseActive == active then
        return
    end

    disguiseActive = active
    TriggerServerEvent('blackmarket:server:setDisguise', active)
end

IsNearBlackMarket = function(radius)
    local coords = GetActiveDealerLocation()
    if not coords then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(playerCoords - vector3(coords.x, coords.y, coords.z)) <= BMNumber(radius, 35.0)
end

-- =============================================================================
-- BLACK MARKET SHOP MENU
-- =============================================================================

function OpenBlackMarketMenu()
    local state = RefreshDealerState()
    if not state.open then
        Notify('Black Market', BMString(state.closedMessage, 'Dealer is not available right now.'), 'error')
        return
    end

    local cred = GetStreetCred()
    local items = lib.callback.await('blackmarket:server:getItems', false)
    
    if type(items) ~= 'table' then
        Notify('Black Market', 'Unable to connect to supplier.', 'error')
        return
    end

    SpawnShopCrate()
    
    -- Build category menus
    local categories = {
        weapons = { label = 'Weapons', icon = 'gun', items = {} },
        drugs = { label = 'Drugs', icon = 'pills', items = {} },
        stolen = { label = 'Stolen Goods', icon = 'mask', items = {} },
        contraband = { label = 'Contraband', icon = 'box', items = {} }
    }
    local availableItemCount = 0
    
    for _, item in ipairs(items) do
        local stock = BMInteger(item.stock, 0)
        local requiredCred = BMInteger(item.requiredCred, 0)
        local currentPrice = BMInteger(item.currentPrice or item.basePrice, 0)
        local category = BMString(item.category, 'contraband')

        if stock > 0 then
            local cat = categories[category]
            if cat then
                local menuItem = {
                    name = item.name,
                    label = BMString(item.label, BMString(item.name, 'Unknown Item')),
                    category = category,
                    stock = stock,
                    currentPrice = currentPrice,
                    requiredCred = requiredCred
                }
                local desc = string.format('Stock: %d | Price: $%d', stock, currentPrice)
                
                if requiredCred > cred then
                    desc = string.format('LOCKED - Need %d cred', requiredCred)
                end
                
                table.insert(cat.items, {
                    title = menuItem.label,
                    description = desc,
                    icon = category == 'weapons' and 'gun' or (category == 'drugs' and 'pills' or 'box'),
                    disabled = requiredCred > cred,
                    onSelect = function()
                        OpenPurchaseMenu(menuItem)
                    end
                })
                availableItemCount = availableItemCount + 1
            end
        end
    end
    
    -- Main menu
    local mainMenu = {
        id = 'blackmarket_main',
        title = 'Black Market',
        options = {}
    }

    local dialogueConfig = Config.DealerDialogue or {}
    if dialogueConfig.showInMainMenu ~= false then
        local dealerLine = GetDealerDialogue(cred, availableItemCount)
        if dealerLine and dealerLine ~= '' then
            table.insert(mainMenu.options, {
                title = 'Dealer',
                description = dealerLine,
                icon = 'comment-dots',
                disabled = true
            })
        end
    end
    
    local categoryCount = 0
    for catName, catData in pairs(categories) do
        if #catData.items > 0 then
            categoryCount = categoryCount + 1
            table.insert(mainMenu.options, {
                title = catData.label,
                icon = catData.icon,
                description = string.format('%d items available', #catData.items),
                menu = 'blackmarket_' .. catName
            })
        end
    end

    if categoryCount == 0 then
        table.insert(mainMenu.options, {
            title = 'No stock available',
            description = 'The supplier has nothing for sale right now.',
            icon = 'box-open',
            disabled = true
        })
    end
    
    -- Register submenus
    for catName, catData in pairs(categories) do
        if #catData.items > 0 then
            lib.registerContext({
                id = 'blackmarket_' .. catName,
                title = catData.label,
                menu = 'blackmarket_main',
                options = catData.items
            })
        end
    end
    
    lib.registerContext(mainMenu)
    lib.showContext('blackmarket_main')
end

function OpenPurchaseMenu(item)
    local cred = GetStreetCred()
    local stock = BMInteger(item.stock, 0)
    local price = BMInteger(item.currentPrice, 0)

    if not item.name or stock <= 0 then
        Notify('Black Market', 'This item is no longer available.', 'error')
        OpenBlackMarketMenu()
        return
    end
    
    -- Apply reputation discount
    local modifiers = Config.Reputation and type(Config.Reputation.priceModifiers) == 'table' and Config.Reputation.priceModifiers or {}
    for _, mod in ipairs(modifiers) do
        if cred >= BMInteger(mod.minCred, 0) then
            price = math.floor(BMNumber(item.currentPrice, 0) * BMNumber(mod.modifier, 1.0))
        end
    end
    
    lib.registerContext({
        id = 'blackmarket_purchase',
        title = BMString(item.label, 'Black Market Item'),
        options = {
            {
                title = 'Purchase',
                description = string.format('Buy 1 for $%d (Stock: %d)', price, stock),
                icon = 'cart-shopping',
                onSelect = function()
                    RunPurchaseSequence(item, 1)
                end
            },
            {
                title = 'Buy Multiple',
                description = 'Select quantity',
                icon = 'boxes-stacked',
                onSelect = function()
                    local input = lib.inputDialog('Purchase Quantity', {
                        { type = 'number', label = 'Quantity', default = 1, min = 1, max = stock }
                    })
                    
                    if input then
                        local qty = BMInteger(input[1], 1)
                        qty = math.max(1, math.min(qty, stock))
                        RunPurchaseSequence(item, qty)
                    end
                end
            },
            {
                title = 'Go Back',
                icon = 'arrow-left',
                onSelect = function()
                    OpenBlackMarketMenu()
                end
            }
        }
    })
    
    lib.showContext('blackmarket_purchase')
end

-- =============================================================================
-- COMMANDS
-- =============================================================================

RegisterCommand('blackmarket', function()
    OpenBlackMarketMenu()
end, false)

RegisterCommand('mycred', function()
    local cred = GetStreetCred()
    Notify('Street Cred', string.format('Your reputation: %d/100', cred), 'inform')
end, false)

RegisterCommand('blackmarket_closemenus', function()
    pcall(function() lib.hideContext() end)
    pcall(function() lib.closeInputDialog() end)
    pcall(function() lib.hideTextUI() end)
end, false)

RegisterKeyMapping('blackmarket_closemenus', 'Close black market menus', 'keyboard', 'ESCAPE')

-- =============================================================================
-- EVENTS
-- =============================================================================

RegisterNetEvent('blackmarket:client:notify', function(title, message, type)
    Notify(title, message, type)
end)

RegisterNetEvent('blackmarket:client:dealerStateChanged', function(state)
    local previousLocation = dealerState and dealerState.location or nil
    state = type(state) == 'table' and state or { open = false }
    state.location = NormalizeDealerLocation(state.location)
    dealerState = state

    if not state.open or not state.location or not IsSameDealerLocation(previousLocation, state.location) then
        DeleteBlackMarketPed()
    end
end)

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

-- Periodically refresh the dealer's state from the server
CreateThread(function()
    Wait(1000)
    while true do
        RefreshDealerState()
        Wait(15000)
    end
end)

-- Proximity-based spawning/despawning of the dealer NPC
CreateThread(function()
    Wait(2000)
    while true do
        local state = dealerState
        local location = state and state.open and state.location or nil

        if location then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - vector3(location.x, location.y, location.z))

            if dist <= 120.0 then
                if not blackMarketPed or not DoesEntityExist(blackMarketPed) then
                    blackMarketPed = nil
                    blackMarketTargetAdded = false
                    CreateBlackMarketPed()
                end
            else
                if blackMarketPed and DoesEntityExist(blackMarketPed) then
                    DeleteBlackMarketPed()
                end
            end
        else
            if blackMarketPed and DoesEntityExist(blackMarketPed) then
                DeleteBlackMarketPed()
            end
        end

        Wait(2000)
    end
end)

CreateThread(function()
    Wait(2000)

    while true do
        local disguiseConfig = Config.Disguise or {}

        if disguiseConfig.enabled then
            SetDisguiseState(IsNearBlackMarket(disguiseConfig.radius))
        elseif disguiseActive then
            SetDisguiseState(false)
        end

        Wait(disguiseActive and 2500 or 5000)
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DeleteBlackMarketPed()
        DeletePurchaseProp()

        if disguiseActive then
            TriggerServerEvent('blackmarket:server:setDisguise', false)
        end
    end
end)
