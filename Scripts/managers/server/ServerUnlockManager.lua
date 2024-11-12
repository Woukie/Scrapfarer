ServerUnlockManager = class(nil)

function ServerUnlockManager.onCreate(self)
	self.areaTriggers = {}
end

function ServerUnlockManager:getAreaId(node)
  local position = node.position
  return position.x.."|"..position.y.."|"..position.z.."||"..node.params.unlocks
end

function ServerUnlockManager:onCellLoaded(x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "UNLOCK")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getAreaId(node)


      local unlocks = {}
      for str in string.gmatch(node.params.unlocks, "([^,]+)") do
        table.insert(unlocks, str)
      end

      print(unlocks)

      local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, {unlocks = unlocks})
      areaTrigger:bindOnEnter("trigger_onEnter", self)

      self.areaTriggers[id] = areaTrigger
    end
	end
end

function ServerUnlockManager:onCellUnloaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "UNLOCK")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getAreaId(node)

      self.areaTriggers[id] = nil
    end
	end
end

function ServerUnlockManager:trigger_onEnter(trigger, results)
  for _, result in ipairs(results) do
    local type = type(result)

    if type == "Character" then
      g_serverGameManager:unlockShopItems(result:getPlayer(), trigger:getUserData().unlocks)
    end
  end
end
