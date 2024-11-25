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
  else
    for _, obstacle in pairs(self.obstacleSpawners) do
      obstacle.loaded = false
    end
  end
end

-- Refresh data on loading
function ServerObstacleManager:onCellLoaded(x, y)
	local nodes = sm.cell.getNodesByTag(x, y, "OBSTACLES")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = getNodeId(node)

      if not self.obstacleSpawners[id] then
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
          mudRotation = node.params.mudRotation,
          noRotation = node.params.noRotation,
          rotate90Y = node.params.rotate90Y,
          randomColor = node.params.randomColor,
          ticks = 0,
          obstacles = {},
          loaded = true
        }

        saveObstacleSpawners(self)
      else
        self.obstacleSpawners[id].loaded = true
      end
    end
	end
end

function ServerObstacleManager:onCellUnloaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "OBSTACLES")

	if #nodes > 0 then
    for _, node in ipairs(nodes) do
      local id = getNodeId(node)
      self.obstacleSpawners[id].loaded = false
    end
	end
end

function ServerObstacleManager:onFixedUpdate()
  for id, obstacleSpawner in pairs(self.obstacleSpawners) do
    if obstacleSpawner.loaded then
      -- Destruction
      ArrayRemove(self.obstacleSpawners[id].obstacles, function (t, i, j)
        local v = t[i];

        if not v.part then
          -- Should never happen
          return false
        end

        if not sm.exists(v.part) then
          -- SM appears not to offer a way to differentiate between unloaded and non-existant parts
          -- We assume the part got destroyed here, but tracked parts can be unloaded while the obstacle spawner is loaded so we can't destroy them (and sm.exists returns false for some reason)
          -- Obstacles have a self destruct timeout w/ keepAlive for this very reason
          return false
        end

        if v.ticks >= v.life then
          sm.event.sendToInteractable(v.part.interactable, "destroy")
        else
          v.ticks = v.ticks + 1
        end

        sm.event.sendToInteractable(v.part.interactable, "refreshKeepAlive")
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
          elseif self.obstacleSpawners[id].mudRotation then
            rotation = sm.quat.angleAxis(math.pi / 2, sm.vec3.new(1, 0, 0)) * sm.quat.angleAxis(math.pi * 2 * math.random(), sm.vec3.new(0, 1, 0))
          elseif self.obstacleSpawners[id].noRotation then
            rotation = sm.quat.angleAxis(math.pi / 2, sm.vec3.new(0, 0, 1))
          else
            rotation = sm.quat.fromEuler(sm.vec3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360)))
          end

          if self.obstacleSpawners[id].rotate90Y then
            rotation = sm.quat.fromEuler(sm.vec3.new(0, 0, 90)) * rotation
          end

          local part = sm.shape.createPart(
            obstacleSpawner.shapeUuid,
            spawnPos - rotation * (sm.item.getShapeSize(obstacleSpawner.shapeUuid) * 0.5 * 0.25),
            rotation,
            true,
            true
          )

          -- Fully saturated color generation
          if self.obstacleSpawners[id].randomColor then
            local color={[0] = 1, 1, 1}

            local start = math.floor(math.random() * 3 % 3)

            color[start % 3] = 0
            if math.random() < 0.5 then
              color[(start + 1) % 3] = math.random()
            else
              color[(start + 2) % 3] = math.random()
            end

            part:setColor(sm.color.new(color[0], color[1], color[2]))
          end

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
  end

  saveObstacleSpawners(self)
end
