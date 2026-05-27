local ESX = exports.es_extended:getSharedObject()
local rockCooldowns = {}

local function notify(source, message, type)
    TriggerClientEvent('Poud_mining:notify', source, message, type or 'info')
end

local function getItemCount(xPlayer, item)
    local inventoryItem = xPlayer.getInventoryItem(item)
    return inventoryItem and inventoryItem.count or 0
end

local function canCarry(xPlayer, item, count)
    if xPlayer.canCarryItem then
        return xPlayer.canCarryItem(item, count)
    end

    return true
end

local function addItem(xPlayer, item, count)
    if count <= 0 then return true end

    if not canCarry(xPlayer, item, count) then
        return false
    end

    xPlayer.addInventoryItem(item, count)
    return true
end

local function rollRewards(rewards)
    local rolled = {}

    for _, reward in ipairs(rewards) do
        local chance = reward.chance or 100
        if math.random(100) <= chance then
            rolled[#rolled + 1] = {
                item = reward.item,
                count = math.random(reward.min, reward.max)
            }
        end
    end

    return rolled
end

local function isNear(source, coords)
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= Config.ServerDistanceLimit
end

local function isNearRock(source, index)
    local coords = Config.MiningRocks[index]
    if not coords then return false end

    return isNear(source, coords)
end

local function isRockReady(source, index)
    local playerCooldowns = rockCooldowns[source]
    if not playerCooldowns then return true end

    return (playerCooldowns[index] or 0) <= os.time()
end

local function setRockCooldown(source, index)
    rockCooldowns[source] = rockCooldowns[source] or {}
    rockCooldowns[source][index] = os.time() + Config.RockRespawnTime
end

AddEventHandler('playerDropped', function()
    rockCooldowns[source] = nil
end)

ESX.RegisterServerCallback('Poud_mining:canMine', function(source, cb, index)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, Config.Text.noItems)
        return
    end

    if not isNearRock(source, index) then
        cb(false, Config.Text.tooFar)
        return
    end

    if not isRockReady(source, index) then
        cb(false, Config.Text.cooldown)
        return
    end

    if getItemCount(xPlayer, Config.RequiredItem) < 1 then
        cb(false, Config.Text.noPickaxe)
        return
    end

    cb(true)
end)

ESX.RegisterServerCallback('Poud_mining:getProcessCount', function(source, cb, processName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local process = Config.Processes[processName]

    if not xPlayer or not process or not process.input then
        cb(0, Config.Text.noItems)
        return
    end

    if not isNear(source, process.coords) then
        cb(0, Config.Text.tooFar)
        return
    end

    cb(math.floor(getItemCount(xPlayer, process.input.item) / process.input.count))
end)

ESX.RegisterServerCallback('Poud_mining:getSellItems', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local process = Config.Processes.selling

    if not xPlayer or not process then
        cb({}, Config.Text.noItems)
        return
    end

    if not isNear(source, process.coords) then
        cb({}, Config.Text.tooFar)
        return
    end

    local items = {}

    for _, item in ipairs(Config.SellOrder) do
        local price = process.prices[item]
        local count = getItemCount(xPlayer, item)

        if price and count > 0 then
            items[#items + 1] = {
                item = item,
                label = Config.SellLabels[item] or item,
                count = count,
                price = price
            }
        end
    end

    if #items < 1 then
        cb({}, Config.Text.nothingToSell)
        return
    end

    cb(items)
end)

ESX.RegisterServerCallback('Poud_mining:canProcess', function(source, cb, processName, batches)
    local xPlayer = ESX.GetPlayerFromId(source)
    local process = Config.Processes[processName]
    batches = math.max(1, math.floor(tonumber(batches) or 1))

    if not xPlayer or not process then
        cb(false, Config.Text.noItems)
        return
    end

    if not isNear(source, process.coords) then
        cb(false, Config.Text.tooFar)
        return
    end

    if processName == 'selling' then
        for item in pairs(process.prices) do
            if getItemCount(xPlayer, item) > 0 then
                cb(true)
                return
            end
        end

        cb(false, Config.Text.nothingToSell)
        return
    end

    if getItemCount(xPlayer, process.input.item) < (process.input.count * batches) then
        cb(false, Config.Text.noItems)
        return
    end

    cb(true)
end)

RegisterNetEvent('Poud_mining:mineRock', function(index)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if not isNearRock(source, index) then
        notify(source, Config.Text.tooFar, 'error')
        return
    end

    if not isRockReady(source, index) then
        notify(source, Config.Text.cooldown, 'error')
        return
    end

    if getItemCount(xPlayer, Config.RequiredItem) < 1 then
        notify(source, Config.Text.noPickaxe, 'error')
        return
    end

    local rewards = rollRewards(Config.MiningRewards)

    for _, reward in ipairs(rewards) do
        if not canCarry(xPlayer, reward.item, reward.count) then
            notify(source, Config.Text.inventoryFull, 'error')
            return
        end
    end

    for _, reward in ipairs(rewards) do
        xPlayer.addInventoryItem(reward.item, reward.count)
    end

    setRockCooldown(source, index)
    TriggerClientEvent('Poud_mining:hideRock', source, index)
    notify(source, Config.Text.mined, 'success')
end)

RegisterNetEvent('Poud_mining:process', function(processName, batches)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local process = Config.Processes[processName]
    batches = math.max(1, math.floor(tonumber(batches) or 1))

    if not xPlayer or not process then return end

    if not isNear(source, process.coords) then
        notify(source, Config.Text.tooFar, 'error')
        return
    end

    if processName == 'selling' then
        local total = 0

        for item, price in pairs(process.prices) do
            local count = getItemCount(xPlayer, item)
            if count > 0 then
                xPlayer.removeInventoryItem(item, count)
                total = total + (count * price)
            end
        end

        if total <= 0 then
            notify(source, Config.Text.nothingToSell, 'error')
            return
        end

        xPlayer.addMoney(total)
        notify(source, Config.Text.sold:format(total), 'success')
        return
    end

    local inputCount = process.input.count * batches

    if getItemCount(xPlayer, process.input.item) < inputCount then
        notify(source, Config.Text.noItems, 'error')
        return
    end

    local rewards = {}

    for _ = 1, batches do
        local rolled = rollRewards(process.outputs)

        for _, reward in ipairs(rolled) do
            rewards[reward.item] = (rewards[reward.item] or 0) + reward.count
        end
    end

    for item, count in pairs(rewards) do
        if not canCarry(xPlayer, item, count) then
            notify(source, Config.Text.inventoryFull, 'error')
            return
        end
    end

    xPlayer.removeInventoryItem(process.input.item, inputCount)

    for item, count in pairs(rewards) do
        addItem(xPlayer, item, count)
    end

    if processName == 'washing' then
        notify(source, Config.Text.washed, 'success')
    elseif processName == 'smelting' then
        notify(source, Config.Text.smelted, 'success')
    end
end)

RegisterNetEvent('Poud_mining:sellItem', function(item, amount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local process = Config.Processes.selling
    amount = math.max(1, math.floor(tonumber(amount) or 1))

    if not xPlayer or not process then return end

    if not isNear(source, process.coords) then
        notify(source, Config.Text.tooFar, 'error')
        return
    end

    local price = process.prices[item]

    if not price then
        notify(source, Config.Text.nothingToSell, 'error')
        return
    end

    if getItemCount(xPlayer, item) < amount then
        notify(source, Config.Text.noItems, 'error')
        return
    end

    local total = amount * price

    xPlayer.removeInventoryItem(item, amount)
    xPlayer.addMoney(total)
    notify(source, Config.Text.sold:format(total), 'success')
end)
