local FlightCore = require("FlightCore")
local universe = require("universe/Universe")()
local construct = require("abstraction/Construct")()
local calc = require("Calc")
local moveControl = require("movement/MoveControl")()
local MovementBehaviour = require("movement/MovementBehaviour")

local fc = FlightCore()

--local testPos = universe:ParsePosition("::pos{0,2,7.6926,78.1056,60}")

local upDirection = -construct.orientation.AlongGravity()
local startPos = construct.position.Current()
local parallelPathStart = startPos + calc.StraightForward(upDirection, construct.orientation.Right()) * 10 -- 10m infront

fc:ReceiveEvents()

local function AboveSelfAlignedToGravity()
    return construct.position.Current() + upDirection * 100
end

local function PointAlongParallelLine()
    local distanceFromStart = construct.position.Current() - startPos
    return parallelPathStart + distanceFromStart
end

function ActionStart(system, key)
    if key == "option1" then
        moveControl:Clear()
        moveControl:Append(MovementBehaviour(construct.position.Current(), startPos + upDirection * 5, PointAlongParallelLine, AboveSelfAlignedToGravity, 0.11, calc.Kph2Mps(3)))
    elseif key == "option2" then
        moveControl:Clear()
        moveControl:Append(MovementBehaviour(construct.position.Current(), startPos + upDirection * 10, PointAlongParallelLine, AboveSelfAlignedToGravity, 0.1, 5))
    elseif key == "option3" then
        moveControl:Clear()
        moveControl:Append(MovementBehaviour(construct.position.Current(), startPos + upDirection * 50, PointAlongParallelLine, AboveSelfAlignedToGravity, 0.1, calc.Kph2Mps(30)))
        moveControl:Append(MovementBehaviour(construct.position.Current(), startPos + upDirection * 75, PointAlongParallelLine, AboveSelfAlignedToGravity, 0.1, calc.Kph2Mps(5)))
        moveControl:Append(MovementBehaviour(construct.position.Current(), startPos + upDirection * 100, PointAlongParallelLine, AboveSelfAlignedToGravity, 0.1, calc.Kph2Mps(1)))
    end
end

system:onEvent("actionStart", ActionStart)
