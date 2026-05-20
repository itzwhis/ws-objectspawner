local RSGCore = exports['rsg-core']:GetCoreObject()

local spawnedObjects = {}   -- id -> entity handle (saved DB objects rendered)
local placementMode = false

-- ============================================================
-- Utility: load model
-- ============================================================
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

-- ============================================================
-- Render saved objects
-- ============================================================
local function spawnSaved(row)
    if spawnedObjects[row.id] and DoesEntityExist(spawnedObjects[row.id]) then
        DeleteObject(spawnedObjects[row.id])
    end
    local hash = loadModel(row.model)
    if not hash then return end
    local obj = CreateObject(hash, row.x + 0.0, row.y + 0.0, row.z + 0.0, false, false, false, false, true)
    SetEntityHeading(obj, row.heading + 0.0)
    FreezeEntityPosition(obj, row.frozen == 1 or row.frozen == true)
    SetModelAsNoLongerNeeded(hash)
    spawnedObjects[row.id] = obj
end

local function clearSpawned()
    for id, obj in pairs(spawnedObjects) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
        spawnedObjects[id] = nil
    end
end

local function refreshAll()
    clearSpawned()
    RSGCore.Functions.TriggerCallback('rsg-objectspawner:server:getObjects', function(rows)
        if not rows then return end
        for _, r in ipairs(rows) do spawnSaved(r) end
    end)
end

RegisterNetEvent('rsg-objectspawner:client:refresh', function()
    refreshAll()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)
    refreshAll()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearSpawned()
end)

-- ============================================================
-- Raycast helper (laser)
-- ============================================================
local function raycastFromCamera(distance)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx = math.rad(rot.x)
    local rz = math.rad(rot.z)
    local cosX = math.abs(math.cos(rx))
    local dir = vector3(-math.sin(rz) * cosX, math.cos(rz) * cosX, math.sin(rx))
    local dest = cam + dir * distance

    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    if hit == 1 then return endCoords end
    return dest
end

-- ============================================================
-- Placement mode (laser + keyboard fine-tune)
-- ============================================================
local function startPlacement(model, frozen, onConfirm, onCancel)
    local hash = loadModel(model)
    if not hash then
        lib.notify({ title = 'Object Spawner', description = 'Invalid model: ' .. tostring(model), type = 'error' })
        if onCancel then onCancel() end
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local previewObj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false, false, true)
    SetEntityAlpha(previewObj, 180, false)
    SetEntityCollision(previewObj, false, false)
    FreezeEntityPosition(previewObj, true)
    SetModelAsNoLongerNeeded(hash)

    placementMode = true
    local heading = 0.0
    local manualOffset = vector3(0.0, 0.0, 0.0)
    local useLaser = true

    CreateThread(function()
        while placementMode do
            Wait(0)

            -- Help text
            lib.showTextUI(
                '[LMB] Confirm  \n[RMB / BACKSPACE] Cancel  \n[SPACE] Toggle laser/manual  \n[ARROWS] Move X/Y  [PGUP/PGDN] Move Z  \n[Q/E] Rotate  \n[R] Reset offset',
                { position = 'right-center' }
            )

            local pos
            if useLaser then
                pos = raycastFromCamera(Config.LaserDistance) + manualOffset
            else
                pos = GetEntityCoords(ped) + manualOffset + vector3(0, 1.5, 0)
            end

            SetEntityCoordsNoOffset(previewObj, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(previewObj, heading)

            -- Controls (RedM control hashes)
            -- INPUT_MOVE_UP_ONLY (arrow up) / etc via keyboard codes through lib? Use IsControlPressed with hashes.
            if IsControlPressed(0, 0xE6F612E4) then manualOffset = manualOffset + vector3(0, Config.MoveStep, 0) end -- numpad 8 / arrow up
            if IsControlPressed(0, 0x1C1B81B4) then manualOffset = manualOffset - vector3(0, Config.MoveStep, 0) end -- arrow down
            if IsControlPressed(0, 0xA65EBAB4) then manualOffset = manualOffset - vector3(Config.MoveStep, 0, 0) end -- arrow left
            if IsControlPressed(0, 0xDEB34313) then manualOffset = manualOffset + vector3(Config.MoveStep, 0, 0) end -- arrow right
            if IsControlPressed(0, 0x446258B6) then manualOffset = manualOffset + vector3(0, 0, Config.MoveStep) end -- PgUp
            if IsControlPressed(0, 0x3C3DD371) then manualOffset = manualOffset - vector3(0, 0, Config.MoveStep) end -- PgDn

            if IsControlPressed(0, 0xDE794E3E) then heading = (heading + Config.RotateStep) % 360 end -- Q
            if IsControlPressed(0, 0x46BC5B1C) then heading = (heading - Config.RotateStep) % 360 end -- E

            if IsControlJustReleased(0, 0xE30CD707) then -- R
                manualOffset = vector3(0, 0, 0)
            end

            if IsControlJustReleased(0, 0xD9D0E1C0) then -- SPACE
                useLaser = not useLaser
                manualOffset = vector3(0, 0, 0)
            end

            -- Confirm: LMB / Enter
            if IsControlJustReleased(0, 0x07CE1E61) or IsControlJustReleased(0, 0xC7B5340A) then
                placementMode = false
                lib.hideTextUI()
                local finalCoords = GetEntityCoords(previewObj)
                local finalHeading = GetEntityHeading(previewObj)
                if DoesEntityExist(previewObj) then DeleteObject(previewObj) end
                if onConfirm then
                    onConfirm({
                        x = finalCoords.x,
                        y = finalCoords.y,
                        z = finalCoords.z,
                        heading = finalHeading,
                    })
                end
                return
            end

            -- Cancel: RMB / Backspace
            if IsControlJustReleased(0, 0x4CC0E2FE) or IsControlJustReleased(0, 0x156F7119) then
                placementMode = false
                lib.hideTextUI()
                if DoesEntityExist(previewObj) then DeleteObject(previewObj) end
                if onCancel then onCancel() end
                return
            end
        end
    end)
end

-- ============================================================
-- Menus
-- ============================================================

local function openMainMenu() end
local function openSavedMenu() end
local function openCreateMenu() end
local function openEditMenu(row) end

openMainMenu = function()
    lib.registerContext({
        id = 'objspawner_main',
        title = 'Object Spawner',
        options = {
            { title = '➕ Create new object', description = 'Spawn and save a new object', icon = 'plus', onSelect = openCreateMenu },
            { title = '📦 Saved objects', description = 'Edit or delete existing objects', icon = 'box', onSelect = openSavedMenu },
        },
    })
    lib.showContext('objspawner_main')
end

openCreateMenu = function()
    local input = lib.inputDialog('New Object', {
        { type = 'input', label = 'Model name', description = 'e.g. p_chair01x', required = true },
        { type = 'checkbox', label = 'Freeze object', checked = true },
    })
    if not input then return openMainMenu() end

    local model = input[1]
    local frozen = input[2] and true or false

    startPlacement(model, frozen,
        function(coords)
            RSGCore.Functions.TriggerCallback('rsg-objectspawner:server:saveObject', function(id)
                if id then
                    lib.notify({ title = 'Object Spawner', description = 'Object saved (#' .. id .. ')', type = 'success' })
                else
                    lib.notify({ title = 'Object Spawner', description = 'Failed to save', type = 'error' })
                end
            end, {
                model = model,
                x = coords.x, y = coords.y, z = coords.z,
                heading = coords.heading,
                frozen = frozen,
            })
        end,
        function()
            lib.notify({ title = 'Object Spawner', description = 'Placement cancelled', type = 'inform' })
        end
    )
end

openSavedMenu = function()
    RSGCore.Functions.TriggerCallback('rsg-objectspawner:server:getObjects', function(rows)
        local options = {
            { title = '⬅ Back', onSelect = openMainMenu },
        }
        if not rows or #rows == 0 then
            options[#options + 1] = { title = 'No saved objects', disabled = true }
        else
            for _, r in ipairs(rows) do
                options[#options + 1] = {
                    title = ('#%d  %s'):format(r.id, r.model),
                    description = ('x:%.2f y:%.2f z:%.2f  frozen:%s'):format(r.x, r.y, r.z, tostring(r.frozen == 1)),
                    onSelect = function() openEditMenu(r) end,
                }
            end
        end
        lib.registerContext({ id = 'objspawner_saved', title = 'Saved Objects', options = options })
        lib.showContext('objspawner_saved')
    end)
end

openEditMenu = function(row)
    lib.registerContext({
        id = 'objspawner_edit_' .. row.id,
        title = 'Edit #' .. row.id,
        menu = 'objspawner_saved',
        options = {
            {
                title = 'Teleport to object',
                icon = 'location-arrow',
                onSelect = function()
                    SetEntityCoords(PlayerPedId(), row.x, row.y, row.z + 1.0, false, false, false, false)
                end,
            },
            {
                title = 'Change model',
                icon = 'cube',
                onSelect = function()
                    local input = lib.inputDialog('Change Model', {
                        { type = 'input', label = 'Model name', default = row.model, required = true },
                    })
                    if not input then return openEditMenu(row) end
                    row.model = input[1]
                    TriggerServerEvent('rsg-objectspawner:server:updateObject', row)
                    lib.notify({ title = 'Object Spawner', description = 'Model updated', type = 'success' })
                end,
            },
            {
                title = 'Toggle frozen',
                icon = 'snowflake',
                description = 'Currently: ' .. tostring(row.frozen == 1),
                onSelect = function()
                    row.frozen = (row.frozen == 1) and 0 or 1
                    TriggerServerEvent('rsg-objectspawner:server:updateObject', row)
                    lib.notify({ title = 'Object Spawner', description = 'Freeze toggled', type = 'success' })
                end,
            },
            {
                title = 'Reposition (laser)',
                icon = 'crosshairs',
                onSelect = function()
                    startPlacement(row.model, row.frozen == 1,
                        function(coords)
                            row.x, row.y, row.z, row.heading = coords.x, coords.y, coords.z, coords.heading
                            TriggerServerEvent('rsg-objectspawner:server:updateObject', row)
                            lib.notify({ title = 'Object Spawner', description = 'Position updated', type = 'success' })
                        end,
                        function() end
                    )
                end,
            },
            {
                title = 'Manual coords',
                icon = 'pen',
                onSelect = function()
                    local input = lib.inputDialog('Edit Coords', {
                        { type = 'number', label = 'X', default = row.x, required = true },
                        { type = 'number', label = 'Y', default = row.y, required = true },
                        { type = 'number', label = 'Z', default = row.z, required = true },
                        { type = 'number', label = 'Heading', default = row.heading, required = true },
                    })
                    if not input then return openEditMenu(row) end
                    row.x, row.y, row.z, row.heading = input[1], input[2], input[3], input[4]
                    TriggerServerEvent('rsg-objectspawner:server:updateObject', row)
                    lib.notify({ title = 'Object Spawner', description = 'Coords updated', type = 'success' })
                end,
            },
            {
                title = '🗑 Delete object',
                icon = 'trash',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Delete object #' .. row.id,
                        content = 'Are you sure? This cannot be undone.',
                        centered = true,
                        cancel = true,
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('rsg-objectspawner:server:deleteObject', row.id)
                        lib.notify({ title = 'Object Spawner', description = 'Object deleted', type = 'success' })
                        openSavedMenu()
                    end
                end,
            },
        },
    })
    lib.showContext('objspawner_edit_' .. row.id)
end

-- ============================================================
-- Command
-- ============================================================
RegisterCommand(Config.Command, function()
    openMainMenu()
end, false)
