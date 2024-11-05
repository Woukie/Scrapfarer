ServerDestructionManager = class(nil)

function ServerDestructionManager.onCreate(self)
	self.areaTriggers = {}
end

function ServerDestructionManager:getAreaId(position)
  return position.x.."|"..position.y.."|"..position.z
end

function ServerDestructionManager:onCellLoaded(x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "DESTRUCTON")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getAreaId(node.position)

      local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation)
      areaTrigger:bindOnStay("trigger_onStay", self)

      self.areaTriggers[id] = areaTrigger
    end
	end
end

function ServerDestructionManager:onCellUnloaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "DESTRUCTON")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getAreaId(node.position)

      self.areaTriggers[id] = nil
    end
	end
end

function ServerDestructionManager:trigger_onStay(trigger, results)
  for _, result in ipairs(results) do
    local type = type(result)

    if sm.exists(result) then
      if type == "Body" then
        for _, shape in ipairs(result:getShapes()) do
          if math.random(0, 1000) == 3 and shape.buildable then
            shape:destroyPart()
          end
        end
      end
    end
  end
end
