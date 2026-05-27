local busy = false
local rocks = {}
local processZones = {}
local sellingPed
local mineRock
local miningProp
local miningAnimation = false
local currentMiningRock

local function notify(message, type)
    if GetResourceState('Poud_notify') == 'started' then
        exports.Poud_notify:Notify(message, type or 'info', 4500)
        return
    end

    ESX.ShowNotification(message, type or 'info')
end

local function createBlip(coords, settings)
    if not Config.Blips.enabled then return end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, settings.sprite)
    SetBlipColour(blip, settings.color)
    SetBlipScale(blip, settings.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(settings.label)
    EndTextCommandSetBlipName(blip)
end

local function progress(label, duration, animation, cb)
    if GetResourceState('Poud_progress') == 'started' then
        busy = true

        exports.Poud_progress:Progressbar(label, duration, {
            FreezePlayer = true,
            animation = animation,
            onFinish = function()
                busy = false
                cb(true)
            end,
            onCancel = function()
                busy = false
                notify(Config.Text.cancelled, 'error')
                cb(false)
            end
        })

        return
    end

    busy = true
    ESX.Progressbar(label, duration, {
        FreezePlayer = true,
        animation = animation,
        onFinish = function()
            busy = false
            cb(true)
        end,
        onCancel = function()
            busy = false
            notify(Config.Text.cancelled, 'error')
            cb(false)
        end
    })
end

local function formatDuration(milliseconds)
    local seconds = milliseconds / 1000

    if seconds % 1 == 0 then
        return ('%s sekund'):format(seconds)
    end

    return ('%.1f sekund'):format(seconds)
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end

    RequestModel(model)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        Wait(10)

        if GetGameTimer() > timeout then
            return false
        end
    end

    return true
end

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)

        if GetGameTimer() > timeout then
            return false
        end
    end

    return true
end

local function stopMiningAnimation()
    local ped = PlayerPedId()

    miningAnimation = false
    currentMiningRock = nil
    ClearPedTasks(ped)

    if miningProp and DoesEntityExist(miningProp) then
        DeleteEntity(miningProp)
    end

    miningProp = nil
end

local function startMiningAnimation()
    local ped = PlayerPedId()
    local attach = Config.PickaxeAttach

    if not loadModel(Config.PickaxeModel) or not loadAnimDict('melee@large_wpn@streamed_core') then
        return false
    end

    miningProp = CreateObject(Config.PickaxeModel, 0.0, 0.0, 0.0, false, false, false)
    AttachEntityToEntity(
        miningProp,
        ped,
        GetPedBoneIndex(ped, attach.bone),
        attach.pos.x, attach.pos.y, attach.pos.z,
        attach.rot.x, attach.rot.y, attach.rot.z,
        true, true, false, true, 1, true
    )

    miningAnimation = true

    CreateThread(function()
        while miningAnimation do
            if not IsEntityPlayingAnim(ped, 'melee@large_wpn@streamed_core', 'ground_attack_on_spot', 3) then
                TaskPlayAnim(ped, 'melee@large_wpn@streamed_core', 'ground_attack_on_spot', 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end

            Wait(750)
        end
    end)

    CreateThread(function()
        while miningAnimation and Config.MiningHitSound.enabled do
            Wait(Config.MiningHitSound.interval)

            if miningAnimation then
                local soundCoords = currentMiningRock or GetEntityCoords(ped)

                PlaySoundFromCoord(
                    -1,
                    Config.MiningHitSound.name,
                    soundCoords.x, soundCoords.y, soundCoords.z,
                    Config.MiningHitSound.soundSet,
                    false,
                    Config.MiningHitSound.range,
                    false
                )
            end
        end
    end)

    return true
end

local function runMiningSkillCheck()
    if not Config.MiningSkillCheck.enabled then
        return true
    end

    local passed = lib.skillCheck(Config.MiningSkillCheck.difficulty, Config.MiningSkillCheck.inputs)

    if not passed then
        notify(Config.Text.failedSkill, 'error')
    end

    return passed
end

local function openWashingMenu()
    if busy then
        notify(Config.Text.busy, 'error')
        return
    end

    ESX.TriggerServerCallback('Poud_mining:getProcessCount', function(maxBatches, message)
        if not maxBatches or maxBatches < 1 then
            notify(message or Config.Text.noItems, 'error')
            return
        end

        local washing = Config.Processes.washing
        local input = washing.input
        local durationPerBatch = Config.WashingDurationPerBatch or Config.WashingDuration

        local dialog = lib.inputDialog(Config.Text.washMenuTitle, {
            {
                type = 'textarea',
                label = Config.Text.washMenuInfoLabel,
                default = Config.Text.washMenuDescription:format(input.count, input.item, formatDuration(durationPerBatch)),
                disabled = true,
                autosize = true
            },
            {
                type = 'slider',
                label = Config.Text.washMenuSlider,
                description = Config.Text.washTimeInfo:format(formatDuration(durationPerBatch)),
                min = 1,
                max = maxBatches,
                step = 1,
                default = 1,
                required = true
            }
        }, {
            allowCancel = true,
            size = 'md'
        })

        if not dialog then return end

        local selected = tonumber(dialog[2]) or tonumber(dialog[1]) or 1
        local batches = math.max(1, math.floor(selected))
        local duration = batches * durationPerBatch

        notify(Config.Text.washTimeInfo:format(formatDuration(duration)), 'info')

        ESX.TriggerServerCallback('Poud_mining:canProcess', function(canProcess, processMessage)
            if not canProcess then
                notify(processMessage or Config.Text.noItems, 'error')
                return
            end

            progress(Config.Text.wash, duration, {
                type = 'Scenario',
                Scenario = 'WORLD_HUMAN_BUM_WASH'
            }, function(success)
                if success then
                    TriggerServerEvent('Poud_mining:process', 'washing', batches)
                end
            end)
        end, 'washing', batches)
    end, 'washing')
end

local function openSmeltingMenu()
    if busy then
        notify(Config.Text.busy, 'error')
        return
    end

    ESX.TriggerServerCallback('Poud_mining:getProcessCount', function(maxBatches, message)
        if not maxBatches or maxBatches < 1 then
            notify(message or Config.Text.noItems, 'error')
            return
        end

        local smelting = Config.Processes.smelting
        local input = smelting.input
        local durationPerBatch = Config.SmeltingDurationPerBatch or Config.SmeltingDuration

        local dialog = lib.inputDialog(Config.Text.smeltMenuTitle, {
            {
                type = 'textarea',
                label = Config.Text.smeltMenuInfoLabel,
                default = Config.Text.smeltMenuDescription:format(input.count, input.item, formatDuration(durationPerBatch)),
                disabled = true,
                autosize = true
            },
            {
                type = 'slider',
                label = Config.Text.smeltMenuSlider,
                description = Config.Text.smeltTimeInfo:format(formatDuration(durationPerBatch)),
                min = 1,
                max = maxBatches,
                step = 1,
                default = 1,
                required = true
            }
        }, {
            allowCancel = true,
            size = 'md'
        })

        if not dialog then return end

        local selected = tonumber(dialog[2]) or tonumber(dialog[1]) or 1
        local batches = math.max(1, math.floor(selected))
        local duration = batches * durationPerBatch

        notify(Config.Text.smeltTimeInfo:format(formatDuration(duration)), 'info')

        ESX.TriggerServerCallback('Poud_mining:canProcess', function(canProcess, processMessage)
            if not canProcess then
                notify(processMessage or Config.Text.noItems, 'error')
                return
            end

            progress(Config.Text.smelt, duration, {
                type = 'Scenario',
                Scenario = 'WORLD_HUMAN_WELDING'
            }, function(success)
                if success then
                    TriggerServerEvent('Poud_mining:process', 'smelting', batches)
                end
            end)
        end, 'smelting', batches)
    end, 'smelting')
end

local function openSellAmountMenu(data)
    local dialog = lib.inputDialog(Config.Text.sellAmountTitle:format(data.label), {
        {
            type = 'textarea',
            label = Config.Text.sellAmountInfoLabel,
            default = Config.Text.sellAmountDescription:format(data.price),
            disabled = true,
            autosize = true
        },
        {
            type = 'slider',
            label = Config.Text.sellAmountSlider,
            description = Config.Text.sellTotalInfo:format(data.price),
            min = 1,
            max = data.count,
            step = 1,
            default = 1,
            required = true
        }
    }, {
        allowCancel = true,
        size = 'md'
    })

    if not dialog then return end

    local selected = tonumber(dialog[2]) or tonumber(dialog[1]) or 1
    local amount = math.max(1, math.floor(selected))
    local total = amount * data.price

    notify(Config.Text.sellTotalInfo:format(total), 'info')

    progress(Config.Text.sell, Config.SellDuration, {
        type = 'anim',
        dict = 'mp_common',
        lib = 'givetake1_a'
    }, function(success)
        if success then
            TriggerServerEvent('Poud_mining:sellItem', data.item, amount)
        end
    end)
end

local function openSellingMenu()
    if busy then
        notify(Config.Text.busy, 'error')
        return
    end

    ESX.TriggerServerCallback('Poud_mining:getSellItems', function(items, message)
        if not items or #items < 1 then
            notify(message or Config.Text.nothingToSell, 'error')
            return
        end

        local options = {}

        for _, itemData in ipairs(items) do
            local sellData = itemData

            options[#options + 1] = {
                title = sellData.label,
                description = Config.Text.sellMenuDescription:format(sellData.price, sellData.count),
                icon = 'gem',
                arrow = true,
                onSelect = function()
                    openSellAmountMenu(sellData)
                end
            }
        end

        lib.registerContext({
            id = 'Poud_mining_sell_menu',
            title = Config.Text.sellMenuTitle,
            options = options
        })

        lib.showContext('Poud_mining_sell_menu')
    end)
end

local function deleteRock(index)
    local rock = rocks[index]
    if not rock or not rock.entity then return end

    if DoesEntityExist(rock.entity) then
        exports.ox_target:removeLocalEntity(rock.entity, ('Poud_mining_rock_%s'):format(index))
        DeleteEntity(rock.entity)
    end

    rocks[index] = nil
end

local function spawnRock(index)
    local coords = Config.MiningRocks[index]
    if not coords or rocks[index] then return end

    if not loadModel(Config.RockModel) then
        return
    end

    local entity = CreateObject(Config.RockModel, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)

    local optionName = ('Poud_mining_rock_%s'):format(index)

    exports.ox_target:addLocalEntity(entity, {
        {
            name = optionName,
            icon = 'fa-solid fa-hammer',
            label = Config.Text.mine,
            distance = Config.InteractionDistance,
            onSelect = function()
                mineRock(index)
            end
        }
    })

    rocks[index] = {
        entity = entity
    }
end

local function deleteSellingPed()
    if not sellingPed or not DoesEntityExist(sellingPed) then
        sellingPed = nil
        return
    end

    exports.ox_target:removeLocalEntity(sellingPed, 'Poud_mining_selling')
    DeleteEntity(sellingPed)
    sellingPed = nil
end

local function spawnSellingPed()
    local selling = Config.Processes.selling

    if sellingPed or not selling or not selling.ped then return end

    if not loadModel(selling.ped) then
        return
    end

    sellingPed = CreatePed(4, selling.ped, selling.coords.x, selling.coords.y, selling.coords.z - 1.0, selling.heading or 0.0, false, false)

    SetEntityAsMissionEntity(sellingPed, true, true)
    FreezeEntityPosition(sellingPed, true)
    SetEntityInvincible(sellingPed, true)
    SetBlockingOfNonTemporaryEvents(sellingPed, true)

    if selling.scenario then
        TaskStartScenarioInPlace(sellingPed, selling.scenario, 0, true)
    end

    exports.ox_target:addLocalEntity(sellingPed, {
        {
            name = 'Poud_mining_selling',
            icon = 'fa-solid fa-dollar-sign',
            label = Config.Text.sell,
            distance = Config.InteractionDistance,
            onSelect = function()
                openSellingMenu()
            end
        }
    })
end

local function respawnRock(index)
    CreateThread(function()
        Wait(Config.RockRespawnTime * 1000)
        spawnRock(index)
    end)
end

function mineRock(index)
    if busy then
        notify(Config.Text.busy, 'error')
        return
    end

    if not rocks[index] or not DoesEntityExist(rocks[index].entity) then
        notify(Config.Text.cooldown, 'error')
        return
    end

    ESX.TriggerServerCallback('Poud_mining:canMine', function(canMine, message)
        if not canMine then
            notify(message or Config.Text.noPickaxe, 'error')
            return
        end

        busy = true
        currentMiningRock = Config.MiningRocks[index]

        if not startMiningAnimation() then
            busy = false
            return
        end

        if not runMiningSkillCheck() then
            stopMiningAnimation()
            busy = false
            return
        end

        stopMiningAnimation()
        busy = false
        TriggerServerEvent('Poud_mining:mineRock', index)
    end, index)
end

local function runProcess(processName)
    if busy then
        notify(Config.Text.busy, 'error')
        return
    end

    local labels = {
        washing = Config.Text.wash,
        smelting = Config.Text.smelt,
        selling = Config.Text.sell
    }

    local durations = {
        washing = Config.WashingDuration,
        smelting = Config.SmeltingDuration,
        selling = Config.SellDuration
    }

    local animations = {
        washing = { type = 'Scenario', Scenario = 'WORLD_HUMAN_BUM_WASH' },
        smelting = { type = 'Scenario', Scenario = 'WORLD_HUMAN_WELDING' },
        selling = {
            type = 'anim',
            dict = 'mp_common',
            lib = 'givetake1_a'
        }
    }

    ESX.TriggerServerCallback('Poud_mining:canProcess', function(canProcess, message)
        if not canProcess then
            notify(message or Config.Text.noItems, 'error')
            return
        end

        progress(labels[processName], durations[processName], animations[processName], function(success)
            if success then
                TriggerServerEvent('Poud_mining:process', processName)
            end
        end)
    end, processName, 1)
end

RegisterNetEvent('Poud_mining:notify', function(message, type)
    notify(message, type)
end)

RegisterNetEvent('Poud_mining:hideRock', function(index)
    deleteRock(index)
    respawnRock(index)
end)

CreateThread(function()
    for index in ipairs(Config.MiningRocks) do
        spawnRock(index)
    end

    spawnSellingPed()

    processZones[#processZones + 1] = exports.ox_target:addSphereZone({
        name = 'Poud_mining_washing',
        coords = Config.Processes.washing.coords,
        radius = Config.Processes.washing.radius,
        debug = Config.Debug,
        options = {
            {
                name = 'Poud_mining_washing',
                icon = 'fa-solid fa-water',
                label = Config.Text.wash,
                distance = Config.InteractionDistance,
                onSelect = function()
                    openWashingMenu()
                end
            }
        }
    })

    processZones[#processZones + 1] = exports.ox_target:addSphereZone({
        name = 'Poud_mining_smelting',
        coords = Config.Processes.smelting.coords,
        radius = Config.Processes.smelting.radius,
        debug = Config.Debug,
        options = {
            {
                name = 'Poud_mining_smelting',
                icon = 'fa-solid fa-fire',
                label = Config.Text.smelt,
                distance = Config.InteractionDistance,
                onSelect = function()
                    openSmeltingMenu()
                end
            }
        }
    })

    createBlip(Config.MiningRocks[1], Config.Blips.mining)
    createBlip(Config.Processes.washing.coords, Config.Blips.washing)
    createBlip(Config.Processes.smelting.coords, Config.Blips.smelting)
    createBlip(Config.Processes.selling.coords, Config.Blips.selling)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for index in pairs(rocks) do
        deleteRock(index)
    end

    deleteSellingPed()

    for _, zoneId in ipairs(processZones) do
        exports.ox_target:removeZone(zoneId)
    end
end)
