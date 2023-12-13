local component = require("component")
local sides = require("sides")
local keyboard = require("keyboard")


local reactor1 = {
    name = "Reactor 01",
    core = component.proxy(""),
    transposer = component.proxy(""),
    redstone = component.proxy(""),
    expectedEUOutput = 42800, -- 42.800
    maximumAllowedHeat = 2000, -- 20%
    fuelRodsIndex = {1, 2, 4, 5, 6, 8, 9, 11, 12, 13, 15, 16, 17, 19, 20, 22, 23, 24, 26, 27, 28, 29, 31, 32, 33, 35, 36, 38, 39, 40, 42, 43, 44, 46, 47, 49, 50, 51, 53, 54},
    coolantCellsIndex = {3, 7, 10, 14, 18, 21, 25, 30, 34, 37, 41, 45, 48, 52}
}


local battery1 = {
    name = "Battery 01",
    battery = component.proxy(""),
    batterySlots = 16,
    maximumBattery = 1600000000 -- 1.600.000.000
}


local reactors = {reactor1}
local batteries = {battery1}

local allReactorsOn = false


local function turnReactorOn(reactor)
    print("Turning ".. reactor.name .. " ON")
    reactor.redstone.setOutput(sides.north, 15)
    reactor.redstone.setOutput(sides.west, 15)
    print("Finished Turning ".. reactor.name .. " ON")
end


local function turnAllReactorsOn()
    print("Turning all Reactors ON")
    for _, reactor in ipairs(reactors) do
        turnReactorOn(reactor)
    end
    allReactorsOn = true
    print("Finished Turning all Reactors ON")
end


local function turnReactorOff(reactor)
    print("Turning ".. reactor.name .. " OFF")
    reactor.redstone.setOutput(sides.north, 0)
    reactor.redstone.setOutput(sides.west, 0)
    print("Finished Turning ".. reactor.name .. " OFF")
end


local function turnAllReactorsOff()
    print("Turning all Reactors OFF")
    for _, reactor in ipairs(reactors) do
        turnReactorOff(reactor)
    end
    allReactorsOn = false
    print("Finished Turning all Reactors OFF")
end


local function shutDownProgram()
    print("Shutting Down Program")
    turnAllReactorsOff()
    print("Finished Shutting Down Program")
    os.exit()
end


local function storeCoolantInChest(reactor)
    for index, value in ipairs(reactor.coolantCellsIndex) do
        reactor.transposer.transferItem(sides.down, sides.up, 1, value, index)
    end
end


local function placeVentsInReactor(reactor)
    for index, value in ipairs(reactor.coolantCellsIndex) do
        reactor.transposer.transferItem(sides.east, sides.down, 1, index, value)
    end
end


local function removeVentsFromReactor(reactor)
    for index, value in ipairs(reactor.coolantCellsIndex) do
        reactor.transposer.transferItem(sides.down, sides.east, 1, value, index)
    end
end


local function placeCoolantInReactor(reactor)
    for index, value in ipairs(reactor.coolantCellsIndex) do
        reactor.transposer.transferItem(sides.up, sides.down, 1, index, value)
    end
end


local function coolReactor(reactor)
    print("Started Cooling " .. reactor.name)

    storeCoolantInChest(reactor)
    placeVentsInReactor(reactor)

    while reactor.core.getHeat() > 0 do
        os.sleep(1)
    end

    removeVentsFromReactor(reactor)
    placeCoolantInReactor(reactor)

    print("Finished Cooling " .. reactor.name)
end


local function removeDepletedRods(reactor)
    for _, value in ipairs(reactor.fuelRodsIndex) do
        reactor.transposer.transferItem(sides.down, sides.west, 1, value, 2)
    end
end


local function addNewRods(reactor)
    for _, value in ipairs(reactor.fuelRodsIndex) do
        reactor.transposer.transferItem(sides.west, sides.down, 1, 1, value)
    end
end


local function replaceFuelRods(reactor)
    print("Replacing " .. reactor.name .. " Fuel Rods")

    removeDepletedRods(reactor)
    addNewRods(reactor)

    print("Finished Replacing " .. reactor.name .. " Fuel Rods")
end


local function getCurrentBatteryEnergy(battery)
    local currentEnergy = 0
    for index = 1, battery.batterySlots do
        local currentBatteryCellEnergy = battery.battery.getBatteryCharge(index)
        currentEnergy = currentEnergy +  currentBatteryCellEnergy
    end
    return currentEnergy
end


local function getCurrentBatteriesEnergy()
    local currentBatteriesEnergy = 0
    for _, battery in ipairs(batteries) do
        currentBatteriesEnergy = currentBatteriesEnergy + getCurrentBatteryEnergy(battery)
    end
    return currentBatteriesEnergy
end


local function getMaximumBatteriesEnergy()
    local maximumBatteriesEnergy = 0
    for _, battery in ipairs(batteries) do
        maximumBatteriesEnergy = maximumBatteriesEnergy + battery.maximumBattery
    end
    return maximumBatteriesEnergy
end


local function checkReactorStatus(reactor)
    local currentEUOutput = reactor.core.getReactorEUOutput()
    local currentHeat = reactor.core.getHeat()
    local reactorProducesEnergy = reactor.core.producesEnergy()

    if currentHeat > reactor.maximumAllowedHeat then
        turnReactorOff(reactor)
        coolReactor(reactor)
        turnReactorOn(reactor)
        return
    end

    if reactorProducesEnergy and currentEUOutput == 0 then
        turnReactorOff(reactor)
        replaceFuelRods(reactor)
        turnReactorOn(reactor)
        return
    end

    if reactorProducesEnergy and currentEUOutput ~= reactor.expectedEUOutput then
        print("Something is wrong with reactor " .. reactor.name .. " Current EU Output: " .. currentEUOutput .. " Expected: " .. reactor.expectedEUOutput)
        shutDownProgram()
        return
    end
end


local function checkAllReactorsStatus()
    for _, reactor in ipairs(reactors) do
        checkReactorStatus(reactor)
    end
end


local function checkEnergyStatus()
    local currentEnergy = getCurrentBatteriesEnergy()
    local maximumEnergy = getMaximumBatteriesEnergy()

    if allReactorsOn and currentEnergy > maximumEnergy * 0.95 then
        print("Battery Full")
        turnAllReactorsOff()
    end

    if not allReactorsOn and currentEnergy < maximumEnergy * 0.80 then
        print("Battery Low")
        turnAllReactorsOn()
    end
end


local function main()
    checkAllReactorsStatus()
    checkEnergyStatus()
end


print("Starting Reactors Program")

while true do
    if keyboard.isKeyDown(keyboard.keys.n) then
        print("N Key pressed")
        shutDownProgram()
    end

    local success, result = pcall(main)

    if not success then
        print("Program failed. Error message:", result)
        shutDownProgram()
    end

    os.sleep(1)
end
