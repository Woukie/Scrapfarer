ServerObstacleManager = class(nil)

local function getNodeId(node)
  return node.position.x.."|"..node.position.y.."|"..node.position.z.."|"..node.params.shapeUuid
end

-- https://stackoverflow.com/a/53038524
-- Way to remove from a table and reindex all entries in one pass
local function ArrayRemove(t, fnKeep)
  local j, n = 1, #t;

  for i=1,n do
      if (fnKeep(t, i, j)) then
          -- Move i's kept value to j's position, if it's not already there.
          if (i ~= j) then
              t[j] = t[i];
              t[i] = nil;
          end
          j = j + 1; -- Increment position of where we'll place the next kept value.
      else
          t[i] = nil;
      end
  end

  return t;
end

local function saveObstacleSpawners(self)
  sm.storage.save("obstacleSpawners", self.obstacleSpawners)
end

function ServerObstacleManager:onCreate()
	self.obstacleSpawners = sm.storage.load("obstacleSpawners")
  if not self.obstacleSpawners then
    self.obstacleSpawners = {}
    saveObstacleSpawners(self)
  end
end

-- Refresh data on loading
function ServerObstacleManager:onCellLoaded(x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "OBSTACLES")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = getNodeId(node)

      -- Preserve references to shapes
      local obstacles = {}
      local ticks = 0
      if self.obstacleSpawners[id] then
        ticks = self.obstacleSpawners[id].ticks
        obstacles = self.obstacleSpawners[id].obstacles
      end

      self.obstacleSpawners[id] = {
        position = node.position,
        rotation = node.rotation,
        scale = node.scale,
        shapeUuid = sm.uuid.new(node.params.shapeUuid),
        spawnDelay = node.params.spawnDelay,
        maxObstacles = node.params.maxObstacles,
        maxObstacleLife = node.params.maxObstacleLife,
        minObstacleLife = node.params.minObstacleLife,
        logRotation = node.params.logRotation,
        noRotation = node.params.noRotation,
        ticks = ticks,
        obstacles = obstacles
      }

      saveObstacleSpawners(self)
    end
	end
end

function ServerObstacleManager:onFixedUpdate()
  for id, obstacleSpawner in pairs(self.obstacleSpawners) do
    -- Destruction
    ArrayRemove(self.obstacleSpawners[id].obstacles, function (t, i, j)
      local v = t[i];
      v.ticks = v.ticks + 1
      if not v.part then
        return false
      end

      if v.ticks >= v.life and sm.exists(v.part) then
        sm.event.sendToInteractable(v.part.interactable, "destroy")
        return false
      end
      return true
    end)

    -- Creation
    if #obstacleSpawner.obstacles <= obstacleSpawner.maxObstacles then
      obstacleSpawner.ticks = obstacleSpawner.ticks + 1
      if obstacleSpawner.ticks >= obstacleSpawner.spawnDelay then
        obstacleSpawner.ticks = 0

        local areaTrigger = sm.areaTrigger.createBox(obstacleSpawner.scale * 0.5, obstacleSpawner.position, obstacleSpawner.rotation, nil)
        local spawnPos = areaTrigger:getWorldMax() - areaTrigger:getWorldMin()
        spawnPos = areaTrigger:getWorldMin() + sm.vec3.new(spawnPos.x * math.random(), spawnPos.y * math.random(), spawnPos.z * math.random())
        sm.areaTrigger.destroy(areaTrigger)

        local rotation
        if self.obstacleSpawners[id].logRotation then
          rotation = sm.quat.angleAxis(math.random(-0.1, 0.1), sm.vec3.new(0, 0, 1)) * sm.quat.angleAxis(math.random(0, math.pi * 2), sm.vec3.new(1, 0, 0))
        elseif self.obstacleSpawners[id].noRotation then
          rotation = sm.quat.angleAxis(math.pi / 2, sm.vec3.new(1, 0, 0))
        else
          rotation = sm.quat.fromEuler(sm.vec3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360)))
        end

        local part = sm.shape.createPart(
          obstacleSpawner.shapeUuid,
          spawnPos - rotation * (sm.item.getShapeSize(obstacleSpawner.shapeUuid) * 0.5 * 0.25),
          rotation,
          true,
          true
        )
        local body = part:getBody()
        body:setBuildable(false)
        body:setErasable(false)
        body:setLiftable(false)
        table.insert(self.obstacleSpawners[id].obstacles, {
          part = part,
          life = math.random(obstacleSpawner.minObstacleLife, obstacleSpawner.maxObstacleLife),
          ticks = 0
        })
      end
    end
  end

  saveObstacleSpawners(self)
end
