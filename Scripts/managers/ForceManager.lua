dofile "$CONTENT_DATA/Scripts/game/shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

ForceManager = class(nil)

local exclusions = {}
exclusions[tostring(obj_rock_obstacle_01)] = true
exclusions[tostring(obj_rock_obstacle_02)] = true
exclusions[tostring(obj_log_obstacle_01)] = true

function ForceManager.onCreate(self)
	self.cells = {}
end

function ForceManager.server_onCreate(self)
	if sm.isHost then
		self:onCreate()
	end
end

function ForceManager.client_onCreate(self)
	if not sm.isHost then
		self:onCreate()
	end
end

function ForceManager.onCellLoaded(self, x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "FORCE")

	if #nodes > 0 then
    if not self.cells[x] then
      self.cells[x] = {}
    end

		self.cells[x][y] = {}

    local idx = 1
    for _, node in ipairs( nodes ) do
      
      local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, { force = sm.quat.getAt(node.rotation):normalize() * node.params.strength })
      areaTrigger:bindOnStay("trigger_onStay", self)

      self.cells[x][y][idx] = areaTrigger
      idx = idx + 1
    end
	end
end

function ForceManager.server_onCellLoaded(self, x, y)
	if sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager.server_onCellReloaded(self, x, y)
	if sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager.client_onCellLoaded(self, x, y)
	if not sm.isHost then
		self:onCellLoaded(x, y)
	end
end

function ForceManager.onCellUnloaded(self, x, y)
	if self.cells[x] and self.cells[x][y] then
		for _, trigger in ipairs(self.cells[x][y]) do
			sm.areaTrigger.destroy(trigger)
		end

		self.cells[x][y] = nil
	end
end

function ForceManager.server_onCellUnloaded(self, x, y)
	if sm.isHost then
		self:onCellUnloaded(x, y)
	end
end

function ForceManager.client_onCellUnloaded(self, x, y)
	if not sm.isHost then
		self:onCellUnloaded(x, y)
	end
end

function ForceManager.trigger_onStay(self, trigger, results)
  local params = trigger:getUserData()
	assert(params)

  for _, result in ipairs(results) do
    local type = type(result)

    if sm.exists(result) then
      if type == "Character" then
        -- Only apply force if fully in force field (matches behaviour of water)
        local characterFloatOffset = 0.2 + ( result:isCrouching() and 0.4 or 0.0 )
        local characterFloatHeight = result.worldPosition.z + characterFloatOffset

        if trigger:getWorldMax().z > characterFloatHeight then
          ApplyCharacterImpulse(result, params.force, params.force:length())
        end
      elseif type == "Body" then
        if not exclusions[tostring(result:getShapes()[1].uuid)] then
          sm.physics.applyImpulse(result, params.force * result.mass * 0.0003, true)
        end
      end
    end
  end
end
