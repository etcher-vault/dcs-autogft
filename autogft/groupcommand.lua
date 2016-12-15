---
-- @type autogft_GroupCommand
-- @field #string commandName
-- @field #string groupName
-- @field #number groupId
-- @field #function func
-- @field #number timerId
-- @field #boolean enabled
autogft_GroupCommand = {}
autogft_GroupCommand.__index = autogft_GroupCommand

---
-- @param #autogft_GroupCommand self
-- @param #string commandName
-- @param #string groupName
-- @param #function func
-- @return #autogft_GroupCommand
function autogft_GroupCommand:new(commandName, groupName, func)
  self = setmetatable({}, autogft_GroupCommand)
  self.commandName = commandName
  self.groupName = groupName
  self.groupId = Group.getByName(groupName):getID()
  self.func = func
  return self
end

---
-- @param #autogft_GroupCommand self
function autogft_GroupCommand:enable()
  self.enabled = true

  local flagName = "groupCommandFlag"..self.groupId
  trigger.action.setUserFlag(flagName, 0)
  trigger.action.addOtherCommandForGroup(self.groupId, self.commandName, flagName, 1)

  local function checkTrigger()
    if self.enabled == true then
      if (trigger.misc.getUserFlag(flagName) == 1) then
        trigger.action.setUserFlag(flagName, 0)
        self.func()
      end
      autogft.scheduleFunction(checkTrigger, 1)
    else
    end
  end
  checkTrigger()
end

---
-- @param #autogft_GroupCommand self
function autogft_GroupCommand:disable()
  -- Remove group command from mission
  trigger.action.removeOtherCommandForGroup(self.groupId, self.commandName)
  self.enabled = false
end