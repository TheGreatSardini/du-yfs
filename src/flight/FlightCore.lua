local r = require("CommonRequire")
local AxisManager = require("flight/AxisManager")
local universe = r.universe
local vehicle = r.vehicle
local pub = require("util/PubSub").Instance()
local Stopwatch = require("system/Stopwatch")
local Current = vehicle.position.Current
local calc = r.calc
local Ternary = r.calc.Ternary
local Vec3 = r.Vec3
local nullVec = Vec3.New()
local Waypoint = require("flight/Waypoint")
local alignment = require("flight/AlignmentFunctions")
local PointOptions = require("flight/route/PointOptions")
require("flight/state/Require")

---@module "flight/route/RouteController"

---@class FlightCore
---@field ReceiveEvents fun()
---@field GetRouteController fun():RouteController
---@field NextWP fun()
---@field StartFlight fun()
---@field Turn fun(degrees:number, axis:Vec3):Vec3
---@field AlignTo fun(point:Vec3)
---@field StopEvents fun()
---@field CreateWPFromPoint fun(p:Point, lastInRoute:boolean):Waypoint
---@field GoIdle fun()


local FlightCore = {}
FlightCore.__index = FlightCore
local singleton

local defaultFinalSpeed = 0
local defaultMargin = 0.1 -- m

---Creates a waypoint from a point
---@param point Point
---@param lastInRoute boolean
---@return Waypoint
function FlightCore.CreateWPFromPoint(point, lastInRoute)
    local opt = point.Options()
    local dir = Vec3.New(opt.Get(PointOptions.LOCK_DIRECTION, nullVec))
    local margin = opt.Get(PointOptions.MARGIN, defaultMargin)
    local finalSpeed = Ternary(lastInRoute, 0, opt.Get(PointOptions.FINAL_SPEED, defaultFinalSpeed))
    local maxSpeed = opt.Get(PointOptions.MAX_SPEED, 0) -- 0 = ignored/max speed.

    local coordinate = universe.ParsePosition(point.Pos()).Coordinates()
    local wp = Waypoint.New(coordinate, finalSpeed, maxSpeed, margin,
        alignment.RollTopsideAwayFromVerticalReference,
        alignment.YawPitchKeepOrthogonalToVerticalReference)

    wp.SetPrecisionMode(opt.Get(PointOptions.PRECISION, false))

    if dir ~= nullVec then
        wp.LockDirection(dir, true)
    end

    return wp
end

---Creates a new FlightCore
---@param routeController RouteController
---@param flightFSM FlightFSM
---@return FlightCore
function FlightCore.New(routeController, flightFSM)
    local brakes = require("flight/Brakes").Instance()
    local s = {}

    local flushHandlerId = 0
    local updateHandlerId = 0
    local axes = AxisManager.Instance()

    local routePublishTimer = Stopwatch.New()

    local function createDefaultWP()
        return Waypoint.New(vehicle.position.Current(), 0, 0, defaultMargin, alignment.NoAdjust, alignment.NoAdjust)
    end

    -- Setup start waypoints to prevent nil values
    local currentWaypoint = createDefaultWP() -- The positions we want to move to
    local previousWaypoint = currentWaypoint -- Previous waypoint
    local route = nil ---@type Route|nil

    ---Gets the route controller
    ---@return RouteController
    function s.GetRouteController()
        return routeController
    end

    ---Selects the next waypoint
    function s.NextWP()
        if route == nil then
            return
        end

        local nextPoint = route.Next()
        if nextPoint == nil then
            return
        end

        previousWaypoint = currentWaypoint
        currentWaypoint = FlightCore.CreateWPFromPoint(nextPoint, route.LastPointReached())
    end

    ---Starts the flight
    function s.StartFlight()
        route = routeController.CurrentRoute()
        routePublishTimer.Start()

        -- Setup waypoint that will be the previous waypoint
        currentWaypoint = createDefaultWP()
        s.NextWP()

        flightFSM.SetState(Travel.New(flightFSM))
    end

    function s.GoIdle()
        flightFSM.SetState(Idle.New(flightFSM))
    end

    ---Rotates all waypoints around the axis with the given angle
    ---@param degrees number The angle to turn
    ---@param axis Vec3
    function s.Turn(degrees, axis)
        local current = vehicle.position.Current()
        local forwardPointOnPlane = calc.ProjectPointOnPlane(axis, current,
            current + vehicle.orientation.Forward() * alignment.DirectionMargin)
        forwardPointOnPlane = calc.RotateAroundAxis(forwardPointOnPlane, current, degrees, axis)
        s.AlignTo(forwardPointOnPlane)
    end

    ---Aligns to the point
    ---@param point Vec3
    function s.AlignTo(point)
        if currentWaypoint then
            local current = vehicle.position.Current()
            local pointOnPlane = calc.ProjectPointOnPlane(-universe.VerticalReferenceVector(), current, point)
            local dir = (pointOnPlane - current):NormalizeInPlace()
            currentWaypoint.LockDirection(dir, true)
        end
    end

    ---Hooks up the events needed for flight
    function s.ReceiveEvents()
        ---@diagnostic disable-next-line: undefined-field
        flushHandlerId = system:onEvent("onFlush", s.fcFlush)
        ---@diagnostic disable-next-line: undefined-field
        updateHandlerId = system:onEvent("onUpdate", s.fcUpdate)
        axes.ReceiveEvents()
    end

    ---Disconnects events
    function s.StopEvents()
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("flush", flushHandlerId)
        ---@diagnostic disable-next-line: undefined-field
        system:clearEvent("update", updateHandlerId)
        axes.StopEvents()
    end

    local function align()
        local target = currentWaypoint.YawAndPitch(previousWaypoint)

        if target ~= nil then
            axes.SetYawTarget(target.yaw)
            axes.SetPitchTarget(target.pitch)
        else
            axes.SetYawTarget()
            axes.SetPitchTarget()
        end

        local topSideAlignment = currentWaypoint.Roll(previousWaypoint)
        axes.SetRollTarget(topSideAlignment)
    end

    function s.fcUpdate()
        local status, err, _ = xpcall(
            function()
                flightFSM.Update()
                brakes.BrakeUpdate()

                if route and routePublishTimer.Elapsed() > 0.5 then
                    routePublishTimer.Restart()
                    pub.Publish("RouteData", {
                        remaining = route.GetRemaining(Current()),
                        activeRouteName = routeController.ActiveRouteName()
                    })
                end

                local wp = currentWaypoint
                if wp ~= nil then
                    pub.Publish("WaypointData", wp)
                end
            end,
            traceback
        )

        if not status then
            system.print(err)
            unit.exit()
        end
    end

    function s.fcFlush()
        local status, err, _ = xpcall(
            function()
                if currentWaypoint and route then
                    align()
                    flightFSM.FsmFlush(currentWaypoint, previousWaypoint)

                    if currentWaypoint.WithinMargin(WPReachMode.ENTRY) then
                        flightFSM.AtWaypoint(route.LastPointReached(), currentWaypoint, previousWaypoint)

                        -- Lock direction when WP is reached, but don't override existing locks, such as is in place when strafing.
                        currentWaypoint.LockDirection(
                            alignment.DirectionBetweenWaypointsOrthogonalToVerticalRef(currentWaypoint,
                                previousWaypoint),
                            false)

                        -- Switch to next waypoint
                        s.NextWP()
                    end
                else
                    --- This is a workaround for engines remembering their states from a previous session; shut down all engines.
                    unit.setEngineCommand("all", { 0, 0, 0 }, { 0, 0, 0 }, true, true, "", "", "", 1)
                end

                axes.Flush()

                brakes:BrakeFlush()
            end,
            traceback
        )

        if not status then
            system.print(err)
            unit.exit()
        end
    end

    singleton = setmetatable(s, FlightCore)
    return singleton
end

-- The module
return FlightCore
