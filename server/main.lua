local RSGCore = exports['rsg-core']:GetCoreObject()

-- ============================================================
-- Helpers
-- ============================================================

local function isAdmin(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    return RSGCore.Functions.HasPermission(src, Config.AdminGroup)
        or IsPlayerAceAllowed(src, 'command.' .. Config.Command)
end

-- ============================================================
-- Callbacks: list / get
-- ============================================================

RSGCore.Functions.CreateCallback('rsg-objectspawner:server:getObjects', function(source, cb)
    if not isAdmin(source) then return cb({}) end
    local rows = MySQL.query.await('SELECT * FROM objectspawner_objects ORDER BY id DESC', {})
    cb(rows or {})
end)

-- ============================================================
-- Save new object
-- ============================================================

RSGCore.Functions.CreateCallback('rsg-objectspawner:server:saveObject', function(source, cb, data)
    if not isAdmin(source) then return cb(nil) end
    if type(data) ~= 'table' or not data.model or not data.x then return cb(nil) end

    local Player = RSGCore.Functions.GetPlayer(source)
    local citizenid = Player and Player.PlayerData.citizenid or 'unknown'

    local id = MySQL.insert.await(
        'INSERT INTO objectspawner_objects (model, x, y, z, heading, frozen, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            tostring(data.model),
            tonumber(data.x) or 0.0,
            tonumber(data.y) or 0.0,
            tonumber(data.z) or 0.0,
            tonumber(data.heading) or 0.0,
            data.frozen and 1 or 0,
            citizenid,
        }
    )
    -- Notify all admins/clients to refresh
    TriggerClientEvent('rsg-objectspawner:client:refresh', -1)
    cb(id)
end)

-- ============================================================
-- Update object
-- ============================================================

RegisterNetEvent('rsg-objectspawner:server:updateObject', function(data)
    local src = source
    if not isAdmin(src) then return end
    if type(data) ~= 'table' or not data.id then return end

    MySQL.update.await(
        'UPDATE objectspawner_objects SET model = ?, x = ?, y = ?, z = ?, heading = ?, frozen = ? WHERE id = ?',
        {
            tostring(data.model),
            tonumber(data.x) or 0.0,
            tonumber(data.y) or 0.0,
            tonumber(data.z) or 0.0,
            tonumber(data.heading) or 0.0,
            data.frozen and 1 or 0,
            tonumber(data.id),
        }
    )
    TriggerClientEvent('rsg-objectspawner:client:refresh', -1)
end)

-- ============================================================
-- Delete object
-- ============================================================

RegisterNetEvent('rsg-objectspawner:server:deleteObject', function(id)
    local src = source
    if not isAdmin(src) then return end
    if not tonumber(id) then return end

    MySQL.query.await('DELETE FROM objectspawner_objects WHERE id = ?', { tonumber(id) })
    TriggerClientEvent('rsg-objectspawner:client:refresh', -1)
end)
