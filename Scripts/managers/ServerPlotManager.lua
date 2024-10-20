dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

-- Keeps track of who owns what plots
-- Plots ownership is needed for respawning players
-- Plot state is synced with the client without prediction
ServerPlotManager = class(nil)

-- We need worldself to use networking so we can sync plots with clients
function ServerPlotManager.onCreate(self)
  self.plots = {}
  self.createFloorQueue = Queue()
  self.respawnPlayerQueue = Queue()
  self.initialised = false
end

-- Respawns a player at a known plot location, assigning them if necessary, skipping if plots are not loaded (once plots are loaded, players are automatically assigned to them with this method)
function ServerPlotManager.respawnPlayer(self, player)
  print("Respawning player "..player.name)

  -- Ensure this is run in a world environment
  if not pcall(sm.world.getCurrentWorld) then
    -- Sometimes this is reached before onCreate
    if not self.respawnPlayerQueue then
      self.respawnPlayerQueue = Queue()
    end

    self.respawnPlayerQueue:push({self = self, player = player})
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
  for plotID, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then
      print(player.name.." owns plot "..plotID..", teleporting")
      character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      return
    end
  end

  print(player.name.." has no plot, assigning plot")
  for plotID, plot in pairs(self.plots) do
    if not plot["playerId"] then
      plot["playerId"] = player:getId()
      print("Assigned plot "..plotID.." to "..player.name..", teleporting")
      character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      return
    end
  end

  print("Player could not be assigned to plot. Either something is wrong, or all plots are full!!")
end

local function destroyFloor(self, plotId)
  if self.plots[plotId]["floorAsset"] then
    self.plots[plotId]["floorAsset"]:destroyShape()
    self.plots[plotId]["floorAsset"] = nil

    self.syncClient = true
  end
end

local function createFloor(self, plotId)
  if not self.plots[plotId]["floorAsset"] then
    -- Kind of jank. Makes sure createFloor is always called within in a world environment, pushes the call to a queue, and executes in fixedUpdate
    if not pcall(sm.world.getCurrentWorld) then
      self.createFloorQueue:push({self = self, plotId = plotId})
      return
    end

    -- Spawn at approx center (off by .625 to align to grid)
    self.plots[plotId]["floorAsset"] = sm.shape.createPart(obj_plot_floor, self.plots[plotId]["position"] + (self.plots[plotId]["rotation"] * sm.vec3.new(-20, -20, -0.25)), self.plots[plotId]["rotation"], false)
    self.syncClient = true
  end
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

  self.syncClient = true
end

-- 
function ServerPlotManager.onCellLoaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    -- Register new plots
    if not self.plots[plotId] then
      print("Registering plot "..plotId)

      self.plots[plotId] = {}
      self.plots[plotId]["position"] = node.position
      self.plots[plotId]["rotation"] = node.rotation
      self.plots[plotId]["floorHidden"] = false

      if not self.initialised then
        local players = sm.player.getAllPlayers()

        if #self.plots >= #players then
          print("Enough plots registered, respawning players")

          self.initialised = true;
          for _, player in ipairs(players) do
            self:respawnPlayer(player)
          end
        end
      end
    end

    -- load in floor
    if not self.plots[plotId]["floorHidden"] then
      createFloor(self, plotId)
    end
  end

  if #nodes > 0 then
    self.syncClient = true
  end
end

function ServerPlotManager.onCellUnloaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

    if self.plots[plotId] then
      destroyFloor(self, plotId)
    end
  end
end

function ServerPlotManager.onFixedUpdate(self, worldSelf)
  while self.createFloorQueue:size() > 0 do
    local params = self.createFloorQueue:pop()
    createFloor(params.self, params.plotId)
  end

  while self.respawnPlayerQueue:size() > 0 do
    local params = self.respawnPlayerQueue:pop()
    self.respawnPlayer(params.self, params.player)
  end

  -- We need a reference to the game or world to use network like this, and we can't just store a reference to the world on create as that triggers a sandbox violation
  -- This is caught by the clients world, which passes it to the clients plot manager
  if self.syncClient then
    worldSelf.network:sendToClients('client_syncPlots', self.plots)
    self.syncClient = false
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
