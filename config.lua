Config = {}

Config.Locale = 'en'
Config.Debug = false

Config.RequiredItem = 'pickaxe'
Config.RawOreItem = 'raw_ore'
Config.WashedOreItem = 'washed_ore'

Config.MiningDuration = 8500
Config.WashingDuration = 1500
Config.WashingDurationPerBatch = Config.WashingDuration
Config.SmeltingDuration = 1000
Config.SmeltingDurationPerBatch = Config.SmeltingDuration
Config.SellDuration = 3000

Config.RockModel = `prop_rock_2_f`
Config.PickaxeModel = `prop_tool_pickaxe`
Config.PickaxeAttach = {
    bone = 57005,
    pos = vec3(0.09, 0.03, -0.02),
    rot = vec3(-78.0, 13.0, 28.0)
}

Config.MiningHitSound = {
    enabled = true,
    name = 'Drill_Pin_Break',
    soundSet = 'DLC_HEIST_FLEECA_SOUNDSET',
    interval = 1150,
    range = 8.0
}

Config.RockRespawnTime = 7
Config.RockCooldown = Config.RockRespawnTime
Config.InteractionDistance = 2.2
Config.ServerDistanceLimit = 8.0

Config.MiningSkillCheck = {
    enabled = true,
    difficulty = { 'easy', 'easy', 'medium' },
    inputs = { 'e' }
}

Config.SellLabels = {
    iron = 'Iron',
    copper = 'Copper',
    gold = 'Gold',
    diamond = 'Diamond'
}

Config.SellOrder = {
    'iron',
    'copper',
    'gold',
    'diamond'
}

Config.Blips = {
    enabled = true,
    mining = { sprite = 618, color = 46, scale = 0.8, label = 'Mining' },
    washing = { sprite = 365, color = 3, scale = 0.75, label = 'Washing ore' },
    smelting = { sprite = 436, color = 47, scale = 0.75, label = 'Ore Smelting' },
    selling = { sprite = 617, color = 5, scale = 0.75, label = 'Ore Selling' }
}

Config.MiningRocks = {
    vec3(2944.21, 2797.74, 40.63),
    vec3(2947.82, 2795.39, 40.68),
    vec3(2950.33, 2791.89, 40.57),
    vec3(2970.65, 2777.52, 38.33),
    vec3(2973.33, 2775.48, 38.13),
    vec3(2976.49, 2772.96, 38.06),
    vec3(2982.24, 2768.36, 37.22),
    vec3(2986.72, 2764.31, 37.18),
    vec3(2990.75, 2759.46, 37.03)
}

Config.Processes = {
    washing = {
        coords = vec3(1894.25, 3715.06, 32.76),
        radius = 1.5,
        input = { item = 'raw_ore', count = 2 },
        outputs = {
            { item = 'washed_ore', min = 1, max = 2 }
        }
    },
    smelting = {
        coords = vec3(1109.84, -2007.61, 31.05),
        radius = 1.5,
        input = { item = 'washed_ore', count = 3 },
        outputs = {
            { item = 'iron', min = 1, max = 3, chance = 75 },
            { item = 'copper', min = 1, max = 2, chance = 55 },
            { item = 'gold', min = 1, max = 1, chance = 12 },
            { item = 'diamond', min = 1, max = 1, chance = 4 }
        }
    },
    selling = {
        coords = vec3(283.68, 2849.23, 43.64),
        heading = 95.0,
        ped = `s_m_m_gardener_01`,
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        radius = 1.5,
        prices = {
            iron = 35,
            copper = 45,
            gold = 180,
            diamond = 550
        }
    }
}

Config.MiningRewards = {
    { item = 'raw_ore', min = 1, max = 3, chance = 100 },
    { item = 'stone', min = 1, max = 2, chance = 65 }
}

Config.Text = {
    mine = 'Mine ore',
    wash = 'Wash ore',
    washMenuTitle = 'Ore Washing',
    washMenuInfoLabel = 'MATERIAL WASHING INFORMATION',
    washMenuDescription = 'Washing material consumes %s x raw ore and takes 1.5 seconds.',
    washMenuSlider = 'AMOUNT TO WASH',
    washTimeInfo = 'Washing will take %s.',
    smelt = 'Smelt ore',
    smeltMenuTitle = 'Ore Smelting',
    smeltMenuInfoLabel = 'MATERIAL SMELTING INFORMATION',
    smeltMenuDescription = 'Smelting material consumes %s x washed ore and takes %s.',
    smeltMenuSlider = 'AMOUNT TO SMELT',
    smeltTimeInfo = 'Smelting will take %s.',
    sell = 'Sell material',
    sellMenuTitle = 'Ore Buyer',
    sellMenuDescription = 'Price: $%s / pcs | You have: %s pcs',
    sellAmountTitle = 'Sell %s',
    sellAmountInfoLabel = 'SALE INFORMATION',
    sellAmountDescription = 'Choose how many pieces you want to sell. Price per piece is $%s.',
    sellAmountSlider = 'AMOUNT TO SELL',
    sellTotalInfo = 'Sale will be for $%s.',
    noPickaxe = 'You need a pickaxe.',
    busy = 'You are already doing something.',
    cooldown = 'This rock has already been mined.',
    tooFar = 'You are too far away.',
    noItems = 'You do not have the required items.',
    failedSkill = 'You missed.',
    mined = 'You mined ore.',
    washed = 'You washed ore.',
    smelted = 'You smelted ore.',
    sold = 'You sold material for $%s.',
    nothingToSell = 'You have nothing to sell.',
    inventoryFull = 'You do not have enough inventory space.',
    cancelled = 'Action cancelled.'
}
