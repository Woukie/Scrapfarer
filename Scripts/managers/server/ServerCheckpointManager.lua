ServerCheckpointManager = class(nil)

function ServerCheckpointManager.onCreate(self)
	self.areaTriggers = {}
end

-- Generates an ID for a node that's consistent between cell reloads
-- TODO: test if this is actually consistent between cell reloads
function ServerCheckpointManager.getCheckpointId(self, position)
  return position.x.."|"..position.y.."|"..position.z
end

function ServerCheckpointManager.onCellLoaded(self, x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "CHECKPOINT")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getCheckpointId(node.position)

      local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, { reward = node.params.reward, checkpointId = id })
      areaTrigger:bindOnEnter("trigger_onEnter", self)

      self.areaTriggers[id] = areaTrigger
    end
	end
end

function ServerCheckpointManager.onCellUnloaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "CHECKPOINT")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = self:getCheckpointId(node.position)

      self.areaTriggers[id] = nil
    end
	end
end

function ServerCheckpointManager.trigger_onEnter(self, trigger, results)
  local params = trigger:getUserData()
	assert(params)

  for _, result in ipairs(results) do
    local type = type(result)

    if sm.exists(result) then
      if type == "Character" then
        g_serverGameManager:passCheckpoint(result:getPlayer(), params.checkpointId, params.reward)
      end
    end
  end
end
