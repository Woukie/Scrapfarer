dofile "$CONTENT_DATA/Scripts/game/shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

ForceManager = class(nil)

local exclusions = {}
exclusions[tostring(obj_rock_obstacle_01)] = true
exclusions[tostring(obj_rock_obstacle_02)] = true
exclusions[tostring(obj_log_obstacle_01)] = true

local function addRequestedForce(self, target, force)
  if not self.forceRequests[target] then
    self.forceRequests[target] = {}
  end

  table.insert(self.forceRequests[target], force)
end

function ForceManager:onCreate()
	self.cells = {}
  self.forceRequests = {}
end

function ForceManager:server_onCreate()
	if sm.isHost then
		self:onCreate()
	end
end

function ForceManager:client_onCreate()
	if not sm.isHost then
		self:onCreate()
	end
end

function ForceManager:server_onFixedUpdate()
	for target, forces in pairs(self.forceRequests) do
    local type = type(target)

    if sm.exists(target) then
      local force = sm.vec3.zero()
      for _, forceRequest in ipairs(forces) do
        force = force + forceRequest
      end

      force = force / #forces

      if type == "Character" then
        ApplyCharacterImpulse(target, force, force:length())
      elseif type == "Body" then
        if not exclusions[tostring(target:getShapes()[1].uuid)] then
          sm.physics.applyImpulse(target, force * target.mass * 0.0003, true)
        end
      end
    end
  end

  self.forceRequests = {}
end

function ForceManager:onCellLoaded(x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "FORCE")

	if #nodes > 0 then
    if not self.cells[x] then
      self.cells[x] = {}
    end

		self.cells[x][y] = {}

    local idx = 1
    for _, node in ipairs( nodes ) do
      local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, {force = sm.quat.getAt(node.rotation):normalize() * node.params.strength})
      areaTrigger:bindOnStay("trigger_onStay", self)

      self.cells[x][y][idx] = areaTrigger
      idx = idx + 1
    end
	end
end

function ForceManager:server_onCellLoaded(x, y)
	if sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager:server_onCellReloaded(x, y)
	if sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager:client_onCellLoaded(x, y)
	if not sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager:onCellUnloaded(x, y)
	if self.cells[x] and self.cells[x][y] then
		for _, trigger in ipairs(self.cells[x][y]) do
			sm.areaTrigger.destroy(trigger)
		end

		self.cells[x][y] = nil
	end
end

function ForceManager:server_onCellUnloaded(x, y)
	if sm.isHost then
		self:onCellUnloaded(x, y)
	end
end

function ForceManager:client_onCellUnloaded(x, y)
	if not sm.isHost then
		self:onCellUnloaded(x, y)
	end
end

function ForceManager:trigger_onStay(trigger, results)
  local params = trigger:getUserData()
	assert(params)

  for _, result in ipairs(results) do
    if type(result) == "Character" then
      if result:isTumbling() then
        addRequestedForce(self, result, params.force / 6)
      else
        -- Only apply force if fully in force field (matches behaviour of water)
        local characterFloatOffset = 0.2 + ( result:isCrouching() and 0.4 or 0.0 )
        local characterFloatHeight = result.worldPosition.z + characterFloatOffset

        if trigger:getWorldMax().z > characterFloatHeight then
          addRequestedForce(self, result, params.force)
        end
      end
    else
      addRequestedForce(self, result, params.force)
    end
  end
end
