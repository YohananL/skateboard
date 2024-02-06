local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('skateboard', function(source, item)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player.Functions.GetItemByName(item.name) then
        TriggerClientEvent('skateboard:start', playerId)
    end
end)

--- Delete entity from server using net id from client
--- @param netId integer - The net id of the entity to delete
RegisterNetEvent('pet-companion:server:deleteEntity', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)
