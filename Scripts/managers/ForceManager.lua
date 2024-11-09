dofile "$CONTENT_DATA/Scripts/game/obstacles.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

ForceManager = class(nil)

local exclusions = {}
exclusions[tostring(obj_obstacle_small_rock)] = true
exclusions[tostring(obj_obstacle_large_rock)] = true
exclusions[tostring(obj_obstacle_mud)] = true
exclusions[tostring(obj_obstacle_log)] = true
exclusions[tostring(obj_obstacle_rock_spiky)] = true
exclusions[tostring(obj_obstacle_gem)] = true
exclusions[tostring(obj_obstacle_fish)] = true
exclusions[tostring(obj_obstacle_log_dead)] = true
exclusions[tostring(obj_obstacle_fireball)] = true
exclusions[tostring(obj_obstacle_ice_cube)] = true
exclusions[tostring(obj_obstacle_ice_sheet)] = true
exclusions[tostring(obj_obstacle_gumball)] = true
exclusions[tostring(obj_obstacle_rock_candy)] = true
exclusions[tostring(obj_obstacle_coin)] = true
exclusions[tostring(obj_obstacle_wave)] = true

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
	for _, request in pairs(self.forceRequests) do
    local target = request.instance
    local type = type(target)

    if sm.exists(target) then
      local force = sm.vec3.zero()
      for _, forceRequest in ipairs(request.forces) do
        force = force + forceRequest
      end
      force = force / #request.forces

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
    local force

    local type = type(result)
    if type == "Character" then
      if result:isTumbling() then
        force = params.force / 6
      else
        -- Only apply force if fully in force field (matches behaviour of water)
        local characterFloatOffset = 0.2 + ( result:isCrouching() and 0.4 or 0.0 )
        local characterFloatHeight = result.worldPosition.z + characterFloatOffset

        if trigger:getWorldMax().z > characterFloatHeight then
          force = params.force
        end
      end
    elseif type == "Body" then
      force = params.force
    end

    if force then
      -- Two of the same results do not equate, so we index by Id and type
      local requestId = type..result:getId()
      if self.forceRequests[requestId] then
        table.insert(self.forceRequests[requestId].forces, force)
      else
        self.forceRequests[requestId] = {
          instance = result,
          forces = {force}
        }
      end
    end
  end
end
