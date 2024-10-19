dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

-- Keeps track of who owns what plots
-- Plots ownership is needed for respawning players
-- Entire plot state stored on the server, it works the same either way and I cba to do the client
PlotManager = class(nil)

function PlotManager.server_onCreate(self)
  self.plots = {}
  self.createFloorQueue = Queue()
  self.initialised = false
end

-- Respawns a player at a known plot location, assigning them if necessary, skipping if plots are not loaded (once plots are loaded, players are automatically assigned to them with this method)
function PlotManager.server_respawnPlayer(self, player)
  if not self.initialised then
    print("Skipping assigning player for now, plots not loaded yet")
    return
  end

  print("Checking for plots owned by "..player.name)
  for plotID, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then
      print(player.name.." owns plot "..plotID..", teleporting")
      player.character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      return
    end
  end

  print(player.name.." has no plot, assigning plot")
  for plotID, plot in pairs(self.plots) do
    if not plot["playerId"] then
      plot["playerId"] = player:getId()
      print("Assigned plot "..plotID.." to "..player.name..", teleporting")

      player.character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
      return
    end
  end

  print("Player could not be assigned to plot. Either something is wrong, or all plots are full!!")
end

local function destroyFloor(plot)
  if plot["floorAsset"] then
    plot["floorAsset"]:destroyPart()
    plot["floorAsset"] = nil
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
  end
end

-- 
function PlotManager.server_onPlayerLeft(self, player)
  print("Removing "..player.name.." from owned plots")
  for plotID, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() then
      plot["playerId"] = nil
      self:server_showFloor(player)
    end
  end
end

-- 
function PlotManager.server_onCellLoaded(self, x, y)
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
            self:server_respawnPlayer(player)
          end
        end
      end
    end

    -- load in floor
    if not self.plots[plotId]["floorHidden"] then
      createFloor(self, plotId)
    end
  end
end

function PlotManager.server_oncellUnloaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs( nodes ) do
    local plotId = node.params["Plot ID"]

    if self.plots[plotId] then
      destroyFloor(self.plots[plotId])
    end
  end
end

function PlotManager.server_onFixedUpdate(self)
  while self.createFloorQueue:size() > 0 do
    local params = self.createFloorQueue:pop()
    createFloor(params.self, params.plotId)
  end
end

function PlotManager.server_showFloor(self, player)
  for plotId, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() and plot["floorHidden"] then
      plot["floorHidden"] = false
      createFloor(self, plotId)
      return
    end
  end
end

function PlotManager.server_hideFloor(self, player)
  for plotId, plot in pairs(self.plots) do
    if plot["playerId"] == player:getId() and not plot["floorHidden"] then
      plot["floorHidden"] = true
      destroyFloor(plot)
      return
    end
  end
end
