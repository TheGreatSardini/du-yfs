local alignment = require("flight/AlignmentFunctions")
local r = require("CommonRequire")
local Ternary = r.calc.Ternary
local vehicle = r.vehicle

---@class Waypoint
---@field New fun():Waypoint
---@field FinalSpeed fun():number
---@field MaxSpeed fun():number
---@field Margin fun():number
---@field Reached fun():boolean
---@field Destination fun():vec3
---@field DistanceTo fun():number
---@field DirectionTo fun():vec3
---@field GetPrecisionMode fun():boolean
---@field SetPrecisionMode fun(v:boolean)
---@field LockDirection fun(direction:vec3, forced:boolean)
---@field DirectionLocked fun():boolean
---@field Roll fun(previouss.Waypoint):vec3
---@field YawAndPitch fun(previous:Waypoint):vec3
---@field YawPitchDirection fun():vec3

local Waypoint = {}
Waypoint.__index = Waypoint

---Creates a new Waypoint
---@param destination vec3 The destination
---@param finalSpeed number The final speed to reach when at the waypoint (0 if stopping is intended).
---@param maxSpeed number The maximum speed to to travel at. Less than or equal to finalSpeed.
---@param margin number The number of meters to be within for the waypoint to be considered reached
---@param rollFunc AlignmentFunction Function that determines how the constrol aligns its topside (rolls)
---@param yawPitchFunc AlignmentFunction
---@return Waypoint
function Waypoint.New(destination, finalSpeed, maxSpeed, margin, rollFunc, yawPitchFunc)
    local s = {
        destination = destination,
        finalSpeed = finalSpeed,
        maxSpeed = Ternary(finalSpeed > maxSpeed, finalSpeed, maxSpeed), ---@type number -- Guard against bad settings.
        margin = margin,
        rollFunc = rollFunc,
        yawPitchFunc = yawPitchFunc,
        yawPitchDirection = nil, ---@type vec3 -- Fixed target direction
        precisionMode = false
    }

    ---Gets the destination
    ---@return vec3
    function s.Destination()
        return s.destination
    end

    ---Gets the yaw/pitch direction
    ---@return vec3
    function s.YawPitchDirection()
        return s.yawPitchDirection
    end

    ---Gets the final speed for the waypoint
    ---@return number
    function s.FinalSpeed()
        return s.finalSpeed
    end

    ---Gets the max speed for the waypoint
    ---@return number
    function s.MaxSpeed()
        return s.maxSpeed
    end

    ---Gets the margin for the waypoint
    ---@return number
    function s.Margin()
        return s.margin
    end

    ---Indicates if the waypoint has been reached.
    ---@return boolean
    function s.Reached()
        return s.DistanceTo() <= s.margin
    end

    ---Gets the distance to the waypoint
    ---@return number
    function s.DistanceTo()
        return (s.destination - vehicle.position.Current()):len()
    end

    ---Gets the direction to the waypoint
    ---@return vec3
    function s.DirectionTo()
        return (s.destination - vehicle.position.Current()):normalize_inplace()
    end

    ---Indicates of precision mode is active
    ---@return boolean
    function s.GetPrecisionMode()
        return s.precisionMode
    end

    ---Sets precision modde
    ---@param value boolean
    function s.SetPrecisionMode(value)
        s.precisionMode = value
    end

    ---Locks the direction
    ---@param direction vec3 The direction to lock towards
    ---@param forced boolean If true, overrides existing lock
    function s.LockDirection(direction, forced)
        if s.yawPitchDirection == nil or forced then
            s.yawPitchDirection = direction
            s.yawPitchFunc = alignment.YawPitchKeepWaypointDirectionOrthogonalToVerticalReference
        end
    end

    ---Indicates of the direction is locked
    ---@return boolean
    function s.DirectionLocked()
        return s.yawPitchDirection ~= nil
    end

    ---Performs the roll applicable for this waypoint
    ---@param previousWaypoint Waypoint
    ---@return vec3|nil
    function s.Roll(previousWaypoint)
        if s.rollFunc ~= nil then
            return s.rollFunc(s, previousWaypoint)
        end

        return nil
    end

    ---Performs the way and pitch applicable for this waypoint
    ---@param previousWaypoint Waypoint
    ---@return vec3|nil
    function s.YawAndPitch(previousWaypoint)
        if s.yawPitchFunc ~= nil then
            return s.yawPitchFunc(s, previousWaypoint)
        end

        return nil
    end

    return setmetatable(s, Waypoint)
end

return Waypoint
