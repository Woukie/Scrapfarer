dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

unpack = table.unpack or unpack

-- Keeps track of who owns what plots
-- Plots ownership is needed for respawning players
-- Plot state is synced with the client without prediction
ServerPlotManager = class(nil)

function ServerPlotManager.onCreate(self)
  print("ServerPlotManager.onCreate")

  self.plots = sm.storage.load("plots")
  self.plotAreaTriggers = {}
  self.currentShips = sm.storage.load("currentShips")
  self.worldFunctionQueue = Queue()
  self.initialised = false

  if not self.plots then
    self.plots = {}
    print("Creating plots for the first time")
  else
    print("Loaded plots from storage")
    for _, plot in pairs(self.plots) do
      plot["floorHidden"] = false
      plot["playerId"] = nil
    end
  end

  if not self.currentShips then
    self.currentShips = {}
    print("Initialised ships")
  else
    print("Loaded ships from storage")
  end

  self.plotsUpdated = true
end

local function destroyFloor(self, plotId)
  if sm.exists(self.plots[plotId]["floorAsset"]) then
    self.plots[plotId]["floorAsset"]:destroyShape()
  end
  self.plots[plotId]["floorAsset"] = nil
  self.plotsUpdated = true
end

local function createFloor(self, plotId)
  if not pcall(sm.world.getCurrentWorld) then
    self.worldFunctionQueue:push({destination = "createFloor", params = {self, plotId}})
    return
  end

  destroyFloor(self, plotId)

  -- Spawn at approx center (off by .625 to align to grid)
  self.plots[plotId]["floorAsset"] = sm.shape.createPart(obj_plot_floor, self.plots[plotId]["position"] + (self.plots[plotId]["rotation"] * sm.vec3.new(-20, -20, -0.25)), self.plots[plotId]["rotation"], false)
  self.plotsUpdated = true
end

-- Saves all shapes within the plot as the players current ship
function ServerPlotManager.saveCurrentShip(self, player)
  print("Saving "..player.name.."'s current ship")

  for plotId, plot in pairs(self.plots) do
    local trigger = self.plotAreaTriggers[plotId]
    if plot["playerId"] == player:getId() and trigger then
      local bodies = {}
      local idx = 1
      for _, body in pairs(trigger:getContents()) do
        if type(body) == "Body" then
          bodies[idx] = body
          idx = idx + 1
        end
      end

      local creations = sm.body.getCreationsFromBodies(bodies)
      local newCurrentShip = {}
      for i, creation in ipairs(creations) do
        newCurrentShip[i] = sm.creation.exportToString(creation[1], true, true)
      end

      self.currentShips[player:getId()] = newCurrentShip
      sm.storage.save("currentShips", self.currentShips)
      print("Saved "..player.name.."'s progress")

      return
    end
  end

  print("Could not save "..player.name"'s progress")
end

-- Loads players current ship in the plot
function ServerPlotManager.loadCurrentShip(self, player)
  if not pcall(sm.world.getCurrentWorld) then
    self.worldFunctionQueue:push({destination = "loadCurrentShip", params = {self, player}})
    return
  end

  print("Loading "..player.name.."'s current ship")
  for plotID, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then

      for _, creation in ipairs(self.currentShips[player:getId()]) do
        sm.creation.importFromString(self.world, creation, plot.position, plot.rotation, true, true)
      end
    end
  end
end

-- Respawns a player at a known plot location, assigning them if necessary, skipping if plots are not loaded (once plots are loaded, players are automatically assigned to them with this method)
function ServerPlotManager.respawnPlayer(self, player)
  print("Respawning player "..player.name)

  -- Ensure this is run in a world environment
  if not pcall(sm.world.getCurrentWorld) then
    -- Sometimes this is reached before onCreate
    if not self.worldFunctionQueue then
      self.worldFunctionQueue = Queue()
    end

    self.worldFunctionQueue:push({destination = "respawnPlayer", params = {self, player}})
    return
  end

  if not self.initialised then
    print("Skipping assigning player for now, plots not loaded yet")
    return
  end

  local character = player:getCharacter()
  if not character then
    print("Player has no character yet, creating one")

    character = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new( 32, 32, 5 ), 0, 0)
    player:setCharacter(character)
  end

  print("Checking for plots owned by "..player.name)
  for plotId, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then
      print(player.name.." owns plot "..plotId..", teleporting")
      character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      self:showFloor(player)
      return
    end
  end

  print(player.name.." has no plot, assigning plot")
  for plotId, plot in pairs(self.plots) do
    if not plot["playerId"] then
      plot["playerId"] = player:getId()
      print("Assigned plot "..plotId.." to "..player.name..", teleporting")
      character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      self:showFloor(player)
      return
    end
  end

  print("Player could not be assigned to plot. Either something is wrong, or all plots are full!!")
end

-- 
function ServerPlotManager.onPlayerLeft(self, player)
  print("Removing "..player.name.." from owned plots")
  for plotID, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then
      plot["playerId"] = nil
      self:showFloor(player)
    end
  end

  self.plotsUpdated = true
end

-- 
function ServerPlotManager.onCellLoaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    self.plotAreaTriggers[plotId] = sm.areaTrigger.createBox(node.scale * 0.5, node.position, node.rotation, nil, { plotId = plotId })

    -- Register new plots
    if not self.plots[plotId] then
      print("Registering plot "..plotId)  

      self.plots[plotId] = {}
      self.plots[plotId]["position"] = node.position
      self.plots[plotId]["rotation"] = node.rotation
      self.plots[plotId]["floorHidden"] = false
    end

    if not self.initialised then
      local players = sm.player.getAllPlayers()

      if #self.plots >= #players then
        print("Enough plots loaded, respawning players")

        self.initialised = true;
        for _, player in ipairs(players) do
          self:respawnPlayer(player)
        end
      end
    end

    if not self.plots[plotId]["floorHidden"] then
      createFloor(self, plotId)
    end
  end

  if #nodes > 0 then
    self.plotsUpdated = true
  end
end

function ServerPlotManager.onCellUnloaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    sm.areaTrigger.destroy(self.plotAreaTriggers[plotId])
    self.plotAreaTriggers[plotId] = nil
  end
end

function ServerPlotManager.onFixedUpdate(self, worldSelf)
  while self.worldFunctionQueue:size() > 0 do
    local request = self.worldFunctionQueue:pop()
    self[request.destination](unpack(request.params))
  end

  -- We need a reference to the game or world to use network like this, and we can't just store a reference to the world on create as that triggers a sandbox violation
  -- This is caught by the clients world, which passes it to the clients plot manager
  if self.plotsUpdated then
    worldSelf.network:sendToClients('client_syncPlots', self.plots)
    sm.storage.save("plots", self.plots)
    self.plotsUpdated = false
  end
end

function ServerPlotManager.showFloor(self, player)
  for plotId, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() and plot["floorHidden"] then
      plot["floorHidden"] = false
      createFloor(self, plotId)
      return
    end
  end
end

function ServerPlotManager.hideFloor(self, player)
  for plotId, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() and not plot["floorHidden"] then
      plot["floorHidden"] = true
      destroyFloor(self, plotId)
      return
    end
  end
end
