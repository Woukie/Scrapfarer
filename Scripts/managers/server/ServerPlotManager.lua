dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

unpack = table.unpack or unpack

ServerPlotManager = class(nil)

local floorShape = obj_plot_floor

-- Checks if the script is running in the world environment
local function inWorldEnvironment()
  return pcall(sm.world.getCurrentWorld)
end

-- Saves plots to storage, intended to be called whenever 'self.plots' changes
local function savePlots(self)
  sm.storage.save("plots", self.plots)
  print("Saved plot state")
end

-- Gets a list of creations currently in the plot, where each creation is a list of bodies
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

-- Gets the shape representing the floor in the creation, returning nil if there isn't one
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
function ServerPlotManager:getPlotId(player)
  for plotId, plot in pairs(self.plots) do
    if plot.playerId == player:getId() then
      return plotId
    end
  end
end

-- Destroys the build owned by the player
function ServerPlotManager:destroyBuild(plotId)
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

-- Saves the players build. Everything in the plots areaTrigger is saved. Save takes the form of a table with a list of blueprints (with world coordinates), along with the world position and rotation of the floor tile
function ServerPlotManager:saveBuild(player)
  local plotId = self:getPlotId(player)
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

function ServerPlotManager:wipeBuild(player)
  if not inWorldEnvironment() then
    self.worldFunctionQueue:push({destination = "wipeBuild", params = {self, player}})
    return
  end

  local plotId = self:getPlotId(player)
  if not plotId then
    print("Can't wipe build, player has not plot")
    return
  end
  local plot = self.plots[plotId]

  self:destroyBuild(plotId)

  plot.build = sm.shape.createPart(
    floorShape,
    plot.position + (plot.rotation * sm.vec3.new(-20.625, -20.625, -0.25)),
    plot.rotation,
    false,
    true
  )

  local blueprintString = sm.creation.exportToString(plot.build:getBody(), true)
  local blueprints = {sm.json.parseJsonString(blueprintString)}

  self.savedBuilds[player:getId()] = {position = self.plots[plotId].position, rotation = self.plots[plotId].rotation, blueprints = blueprints}
  sm.storage.save("builds", self.savedBuilds)

  g_serverGameManager:recalculateInventory(player)
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

  local plotId = self:getPlotId(player)
  if not plotId then
    print("Can't load build, player has not plot")
    return
  end
  local plot = self.plots[plotId]

  self:destroyBuild(plotId)

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
    print("Loaded default build for "..player.name)
  end

  savePlots(self)

  g_serverGameManager:recalculateInventory(player)
end

-- Saves the players build and destroys the root part
function ServerPlotManager:exitBuildMode(player)
  self:saveBuild(player)
  print("Exiting build mode")
  local plotId = self:getPlotId(player)
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

-- Gets a table of string shape uuids against their count for the users saved build blueprints
function ServerPlotManager:getBuildCost(player)
  local savedBuild = self.savedBuilds[player:getId()]
  if not (savedBuild and savedBuild.blueprints) then
    return {}
  end

  local cost = {}
  for _, blueprint in ipairs(savedBuild.blueprints) do
    if blueprint.joints then
      for _, joint in ipairs(blueprint.joints) do
        local id = joint.shapeId
        cost[id] = (cost[id] or 0) + 1
      end
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

-- Teleports a player to their plot. Assigns plots to players and creates characters if needed, will re-call itself with world environment if not in one, loads builds for new players
function ServerPlotManager:respawnPlayer(player)
  if not inWorldEnvironment() then
    self.worldFunctionQueue:push({destination = "respawnPlayer", params = {self, player}})
    return
  end

  print("Creating new character for "..player.name)

  local character = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new( 32, 32, 5 ), 0, 0)
  player:setCharacter(character)

  print("Respawning player "..player.name)
  local plotId = self:getPlotId(player)
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
        self:loadBuild(player, true)
        return plotId
      end
    end
  end
  print(player.name.." was not assigned a plot because not enough plots exist yet")
end

-- Loads saved data from storage
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

-- Un-registers the plot
function ServerPlotManager:onPlayerLeft(player)
  local plotId = self:getPlotId(player)
  self.plots[plotId].playerId = nil
  print("Removed "..player.name.."'s plot")
end

-- Registers new plots, creates areaTriggers, triggers initialization when enough plots registered
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
        build = nil -- The floor contained within the boat creation
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
      end
    end
  end
end

function ServerPlotManager:plot_onExit(trigger, results)
  local ud = trigger:getUserData()
	assert(ud)

  local plot = self.plots[ud.plotId]
  for _, result in ipairs(results) do
    if (type(result) == "Character" and sm.exists(result)) then
      local player = result:getPlayer()
      if plot and plot.playerId == player:getId() then
        g_serverGameManager:disableInventory(player)
      end
    end
  end
end
