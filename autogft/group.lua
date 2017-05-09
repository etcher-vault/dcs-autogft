---
-- @module Group

---
-- @type Group
-- @extends class#Class
-- @field #list<unitspec#UnitSpec> unitSpecs
-- @field tasksequence#TaskSequence taskSequence
-- @field DCSGroup#Group dcsGroup
-- @field DCSUnit#Unit groupLead
-- @field #number destination
-- @field #boolean progressing
-- @field #number routeOvershootM
-- @field #number maxDistanceM
-- @field #number usingRoadDistanceThresholdM
autogft_Group = autogft_Class:create()

---
-- @param #Group self
-- @param tasksequence#TaskSequence taskSequence
-- @return #Group
function autogft_Group:new(taskSequence)
  self = self:createInstance()
  self.unitSpecs = {}
  self.taskSequence = taskSequence
  self.progressing = true
  self.routeOvershootM = 500
  self.maxDistanceM = 10000
  self.usingRoadDistanceThresholdM = 3000
  self:setDCSGroup(nil)
  return self
end

---
-- @param #Group self
function autogft_Group:updateGroupLead()
  self.groupLead = nil
  if self.dcsGroup then
    local unitIndex = 1
    local units = self.dcsGroup:getUnits()
    while unitIndex <= #units and not self.groupLead do
      if units[unitIndex]:isExist() then self.groupLead = units[unitIndex] end
      unitIndex = unitIndex + 1
    end
    if not self.dcsGroup then
      self.dcsGroup = nil
    end
  end
end

---
-- @param #Group self
-- @return #Group
function autogft_Group:exists()
  self:updateGroupLead()
  if self.groupLead then
    return true
  end
  return false
end

---
-- @param #Group self
-- @param DCSUnit#Unit unit
-- @return #boolean
function autogft_Group:containsUnit(unit)
  if self.dcsGroup then
    local units = self.dcsGroup:getUnits()
    for unitIndex = 1, #units do
      if units[unitIndex]:getID() == unit:getID() then return true end
    end
  end
  return false
end

---
-- @param #Group self
-- @param unitspec#UnitSpec unitSpec
function autogft_Group:addUnitSpec(unitSpec)
  self.unitSpecs[#self.unitSpecs + 1] = unitSpec
  return self
end

---
-- @param #Group self
-- @return #Group
function autogft_Group:advance()

  self:updateGroupLead()
  if self.groupLead then

    local currentDestination = self.destinationIndex
    local destinationZone = self.taskSequence.tasks[self.destinationIndex].zone
    if autogft.unitIsWithinZone(self.groupLead, destinationZone) then
      -- If destination reached, update target
      if self.destinationIndex < self.taskSequence.currentTaskIndex then
        self.destinationIndex = self.destinationIndex + 1
        self.progressing = true
      elseif self.destinationIndex > self.taskSequence.currentTaskIndex then
        self.destinationIndex = self.destinationIndex - 1
        self.progressing = false
      end
    end

    if currentDestination ~= self.destinationIndex then
      self:forceAdvance()
    else
      local prevPos = self.groupLead:getPosition().p
      local prevPosX = prevPos.x
      local prevPosZ = prevPos.z
      local function checkPosAdvance()
        if self.groupLead then
          local currentPos = self.groupLead:getPosition().p
          if currentPos.x == prevPosX and currentPos.z == prevPosZ then
            self:forceAdvance()
          end
        end
      end
      autogft.scheduleFunction(checkPosAdvance, 2)
    end
  end
end

---
-- @param #Group self
-- @return #Group
function autogft_Group:forceAdvance()

  local destinationTask = self.taskSequence.tasks[self.destinationIndex]
  local destination = destinationTask:getLocation()
  local groupLeadPosDCS = self.groupLead:getPosition().p
  local groupPos = autogft_Vector2:new(groupLeadPosDCS.x, groupLeadPosDCS.z)
  local groupToDestination = destination:minus(groupPos)
  local groupToDestinationMag = groupToDestination:getMagnitude()
  local shortened = false

  -- If the task force has a "max distance" specified
  if self.maxDistanceM > 0 then
    local units = self.dcsGroup:getUnits()

    -- If distance to destination is greater than max distance
    if groupToDestinationMag > self.maxDistanceM then
      local destinationX = groupPos.x + groupToDestination.x / groupToDestinationMag * self.maxDistanceM
      local destinationY = groupPos.y + groupToDestination.y / groupToDestinationMag * self.maxDistanceM
      destination = autogft_Vector2:new(destinationX, destinationY)
      shortened = true
    end
  end

  -- (Whether to use roads or not, depends on the next task)
  local nextTask = destinationTask
  if not self.progressing then
    nextTask = self.taskSequence.tasks[self.destinationIndex + 1]
  end
  local useRoads = nextTask.useRoads

  local waypoints = {}
  local function addWaypoint(x, y, useRoad)
    local wp = autogft_Waypoint:new(x, y)
    wp.speed = nextTask.speed
    if useRoad then
      wp.action = autogft_Waypoint.Action.ON_ROAD
    end
    waypoints[#waypoints + 1] = wp
  end

  addWaypoint(groupPos.x, groupPos.y)

  -- Only use roads if group is at a certain distance away from destination
  if useRoads and groupToDestinationMag > self.usingRoadDistanceThresholdM then
    addWaypoint(groupPos.x + 1, groupPos.y + 1, true)
    addWaypoint(destination.x, destination.y, true)
  end

  if not shortened then
    local overshoot = destination:plus(groupPos:times(-1)):normalize():scale(self.routeOvershootM):add(destination)
    addWaypoint(overshoot.x, overshoot.y)
  end

  if not shortened or not useRoads then
    addWaypoint(destination.x + 1, destination.y + 1, useRoads)
  end

  self:setRoute(waypoints)

  return self
end

---
-- @param #Group self
-- @param DCSGroup#Group newGroup
-- @return #Group
function autogft_Group:setDCSGroup(newGroup)
  self.dcsGroup = newGroup
  self.destinationIndex = 1
  return self
end

---
-- @param #Group self
-- @param #list<waypoint#Waypoint> waypoints
function autogft_Group:setRoute(waypoints)
  if self:exists() then
    local dcsTask = {
      id = "Mission",
      params = {
        route = {
          points = waypoints
        }
      }
    }
    self.dcsGroup:getController():setTask(dcsTask)
  end
end
