dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

unpack = table.unpack or unpack

ServerPlotManager = class(nil)

local floorShape = obj_plot_floor

-- Checks if the script is running in the world environment
local function inWorldEnvironment()
  return pcall(sm.world.getCurrentWorld)
end

-- Saves plots to storage, call this whenever 'self.plots' changes
local function savePlots(self)
  sm.storage.save("plots", self.plots)
  print("Saved plot state")
end

-- Gets a list of creations currently in the plot, each creation is a list of bodies
local function getCreationsInPlot(self, plotId)
  local bodies = {}
  if not self.areaTriggers[plotId] then
    return
  end

  for _, body in ipairs(self.areaTriggers[plotId]:getContents()) do
    if type(body) == "Body" and body:isBuildable() then
      bodies[#bodies + 1] = body
    end
  end

  local creations = sm.body.getCreationsFromBodies(bodies)
  return creations
end

local function getFloorInCreation(creation)
  if not creation then
    return
  end
  for _, body in ipairs(creation) do
    for _, shape in pairs(body:getShapes()) do
      if shape:getShapeUuid() == floorShape then
        return shape
      end
    end
  end
end

-- Get plotId for a specific player
local function getPlotId(self, player)
  for plotId, plot in pairs(self.plots) do
    if plot.playerId == player:getId() then
      return plotId
    end
  end
end

-- Destroys the build owned by the player
local function destroyBuild(self, plotId)
  local creations = getCreationsInPlot(self, plotId)
  if creations and #creations > 0 then
    for _, creation in ipairs(creations) do
      for _, body in pairs(creation) do
        for _, shape in pairs(body:getShapes()) do
          shape:destroyShape(0)
        end
      end
    end
    print("Build at plot "..plotId.." destroyed")
    self.plots[plotId].build = nil
    savePlots(self)
  else
    print("Could not destroy plot "..plotId..", no bodies found")
  end
end

-- Saves the players build
function ServerPlotManager:saveBuild(player)
  local plotId = getPlotId(self, player)
  if not self.plots[plotId].build then
    print("Refusing to save "..player.name.."'s build as it doesn't exist")
    return
  end

  local creations = getCreationsInPlot(self, plotId)

  local blueprints = {}
  for _, creation in ipairs(creations) do
    local blueprintString = sm.creation.exportToString(creation[1], true)
    local blueprint = sm.json.parseJsonString(blueprintString)
    blueprints[#blueprints+1] = blueprint
  end

  self.savedBuilds[player:getId()] = {position = self.plots[plotId].position, rotation = self.plots[plotId].rotation, blueprints = blueprints}

  sm.storage.save("builds", self.savedBuilds)
  print("Saved "..player.name.."'s build")
end

-- Destroys the players currently active build, loads their previously saved build (or the default one), and updates the plot build property to point to the new floor part
function ServerPlotManager:loadBuild(player, waitForCellLoad)
  if waitForCellLoad then
    sm.event.sendToGame("loadPlotWhenReady", player)
    return
  end

  if not inWorldEnvironment() then
    self.worldFunctionQueue:push({destination = "loadBuild", params = {self, player, waitForCellLoad}})
    return
  end

  if not player then
    print("Can't load build, no player specified")
    return
  end

  local plotId = getPlotId(self, player)
  if not plotId then
    print("Can't load build, player has not plot")
    return
  end
  local plot = self.plots[plotId]

  destroyBuild(self, plotId)

  local saveData = self.savedBuilds[player:getId()]
  if saveData then
    for _, blueprint in ipairs(saveData.blueprints) do
      if blueprint then
        local rotation = plot.rotation * sm.quat.inverse(saveData.rotation)
        local offset = plot.position - (rotation * saveData.position)

        local creation = sm.creation.importFromString(
          self.world,
          sm.json.writeJsonString(blueprint),
          offset,
          rotation,
          true
        )

        local floor = getFloorInCreation(creation)
        if floor then
          self.plots[plotId].build = floor
        end
      end
    end

    print("Loaded "..player.name.."'s latest build")
  else
    plot.build = sm.shape.createPart(
      floorShape,
      plot.position + (plot.rotation * sm.vec3.new(-20.625, -20.625, -0.25)),
      plot.rotation,
      false,
      true
    )
    local body = plot.build:getBody()
    print("Loaded default build for "..player.name)
  end

  g_serverGameManager:recalculateInventory(player)

  savePlots(self)
end

-- Saves the players build and destroys the root part
function ServerPlotManager:exitBuildMode(player)
  self:saveBuild(player)
  print("Exiting build mode")
  local plotId = getPlotId(self, player)
  local plot = self.plots[plotId]
  if sm.exists(plot.build) then
    for _, creation in ipairs(getCreationsInPlot(self, plotId)) do
      for _, body in ipairs(creation) do
        body:setConnectable(false)
        body:setDestructable(false)
        body:setErasable(false)
        body:setLiftable(false)
        body:setPaintable(false)
      end
    end

    plot.build:destroyShape()
    plot.build = nil
  end
  savePlots(self)
end

function ServerPlotManager:getBuildCost(player)
  local savedBuild = self.savedBuilds[player:getId()]
  if not savedBuild then
    return {}
  end

  local cost = {}
  for _, blueprint in ipairs(savedBuild.blueprints) do
    for _, joint in ipairs(blueprint.joints) do
      local id = joint.shapeId
      cost[id] = (cost[id] or 0) + 1
    end
    for _, body in ipairs(blueprint.bodies) do
      for _, child in ipairs(body.childs) do
        local id = child.shapeId
        local count = 1
        local bounds = child.bounds
        if bounds then
          count = bounds.x * bounds.y * bounds.z
        end
        cost[id] = (cost[id] or 0) + count
      end
    end
  end

  return cost
end

-- Teleports the player to their plot, assigning one if needed, and creating a character if neede. 
-- DOES NOT LOAD BUILDS FOR YOU, ensure the cell is properly loaded before loading a build, loading build will not delete old builds if the old build hasn't loaded yet, load builds with the loadCell callback!
function ServerPlotManager:respawnPlayer(player)
  if not inWorldEnvironment() then
    self.worldFunctionQueue:push({destination = "respawnPlayer", params = {self, player}})
    return
  end

  local character = player:getCharacter()
  if not character then
    print("Player has no character yet, creating one")

    character = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new( 32, 32, 5 ), 0, 0)
    player:setCharacter(character)
  end

  print("Respawning player "..player.name)
  local plotId = getPlotId(self, player)
  if plotId then
    print(player.name.." owns plot "..plotId..", teleporting")
    local plot = self.plots[plotId]
    character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
    return plotId
  else
    print(player.name.." has no plot, assigning plot")
    for plotId, plot in pairs(self.plots) do
      if not plot.playerId then
        plot.playerId = player:getId()
        print("Assigned plot "..plotId.." to "..player.name..", teleporting")
        character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
        return plotId
      end
    end
  end
  print(player.name.." was not assigned a plot because not enough plots exist yet")
end

function ServerPlotManager:onCreate()
  self.worldFunctionQueue = Queue()
  self.areaTriggers = {}
  self.plots = sm.storage.load("plots")
  self.savedBuilds = sm.storage.load("builds")

  if not self.savedBuilds then
    self.savedBuilds = {}
    print("No saved builds found")
  else
    print("Loaded saved builds from storage")
  end

  if not self.plots then
    self.plots = {}
    print("Creating plots for the first time")
  else
    print("Loaded plots from storage")
    for _, plot in pairs(self.plots) do
      plot.playerId = nil
    end
  end

  savePlots(self)
end

-- Does not actually change the world if the host is the one leaving, I guess the world has been saved by then? Really frustrating, means I can't save and destroy plots when a player leaves
function ServerPlotManager:onPlayerLeft(player)
  local plotId = getPlotId(self, player)
  self.plots[plotId].playerId = nil
  print("Removed "..player.name.."'s plot")
end

-- Registers new plots, creates areaTriggers, tries triggering initialization
function ServerPlotManager:onCellLoaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    local areaTrigger = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, { plotId = plotId })
    areaTrigger:bindOnExit("plot_onExit", self)
    areaTrigger:bindOnEnter("plot_onEnter", self)

    self.areaTriggers[plotId] = areaTrigger

    if not self.plots[plotId] then
      self.plots[plotId] = {
        position = node.position,
        scale = node.scale,
        rotation = node.rotation,
        playerId = nil,
        build = nil -- The root shape (floor) contained within the boat creation
      }
      print("Registered plot "..plotId)

      savePlots(self)
    end
  end

  if not self.initialised then
    local players = sm.player.getAllPlayers()
    if #self.plots >= #players then
      print("Enough plots loaded, respawning players")
      self.initialised = true;
      for _, player in ipairs(players) do
        self:respawnPlayer(player) -- We know this triggers immediately since we are in the world environment
        self:loadBuild(player, true)
      end
    end
  end
end

-- Removes areaTriggers
function ServerPlotManager:onCellUnloaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    sm.areaTrigger.destroy(self.areaTriggers[plotId])
    self.areaTriggers[plotId] = nil
  end
end

-- Mega jank way of simplifying sending an event to the world to trigger functions with in a world environment, don't expect immediate execution
function ServerPlotManager:onFixedUpdate()
  if not self.worldFunctionQueue then
    self.worldFunctionQueue = Queue()
  end
  while self.worldFunctionQueue:size() > 0 do
    local request = self.worldFunctionQueue:pop()
    self[request.destination](unpack(request.params))
  end
end

function ServerPlotManager:plot_onEnter(trigger, results)
  local ud = trigger:getUserData()
	assert(ud)

  local plot = self.plots[ud.plotId]
  for _, result in ipairs(results) do
    if (type(result) == "Character") then
      local player = result:getPlayer()
      if plot and plot.playerId == player:getId() then
        g_serverGameManager:enableInventory(player)
        -- May be expensive
        g_serverGameManager:recalculateInventory(player)
      end
    end
  end
end

function ServerPlotManager:plot_onExit(trigger, results)
  local ud = trigger:getUserData()
	assert(ud)

  local plot = self.plots[ud.plotId]
  for _, result in ipairs(results) do
    if (type(result) == "Character") then
      local player = result:getPlayer()
      if plot and plot.playerId == player:getId() then
        g_serverGameManager:disableInventory(player)
      end
    end
  end
end
