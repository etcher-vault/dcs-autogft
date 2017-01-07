---
-- @module taskforceunit

---
-- @type autogft_TaskForceUnit
-- @field #string type
-- @field #number x
-- @field #number y
-- @field #string name
-- @field #string skill
-- @field #number heading
autogft_TaskForceUnit = {}

---
-- @param #autogft_TaskForceUnit self
-- @return #autogft_TaskForceUnit
function autogft_TaskForceUnit:new()
  self = setmetatable({}, {__index = autogft_TaskForceUnit})
  self.heading = 0
  return self
end
