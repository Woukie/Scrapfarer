dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

unpack = table.unpack or unpack

ServerPlotManager = class(nil)

local floorShape = obj_plot_floor

-- Checks if the script is running in the world environment
local function inWorldEnvironment(self)
  return pcall(sm.world.getCurrentWorld)
end

-- Saves plots to storage, call this whenever 'self.plots' changes
local function savePlots(self)
  sm.storage.save("plots", self.plots)
end

local function getBuildBodies(self, plotId)
  local plot = self.plots[plotId]
  if plot.build and sm.exists(plot.build) then
    return plot.build:getBody():getCreationBodies()
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

-- Destroys the build owned by the player. Everything attached to the base plate is destroyed and
local function destroyBuild(self, plotId)
  local bodies = getBuildBodies(self, plotId)
  if bodies then
    for _, body in pairs(bodies) do
      for _, shape in pairs(body:getShapes()) do
        shape:destroyShape(0)
      end
    end
  end

  self.plots[plotId].build = nil
  savePlots(self)
end

local function tryInitialize(self)
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
end

-- Saves the players build
function ServerPlotManager:saveBuild(player)

end

-- Destroys the players currently active build, loads their previously saved build (or the default one), and updates the plot build property to point to the new floor part
function ServerPlotManager:loadBuild(player)
  if not inWorldEnvironment(self) then
    self.worldFunctionQueue:push({destination = "loadBuild", params = {self, player}})
    return
  end

  local plotId = getPlotId(self, player)
  destroyBuild(self, plotId)

  -- If player has a previously saved build, load that (finding the floor piece and setting that as the build), ELSE:
  local plot = self.plots[plotId]
  plot.build = sm.shape.createPart(
    floorShape,
    plot.position + (plot.rotation * sm.vec3.new(-20, -20, -0.25)),
    plot.rotation,
    false,
    true
  )
  savePlots(self)
end

-- Saves the players build and destroys the root part
function ServerPlotManager:exitBuildMode(player)
  self:saveBuild(player)
  local plot = self.plots[getPlotId(self, player)]
  if sm.exists(plot.build) then
    plot.build:destroyShape()
    plot.build = nil
  end
  savePlots(self)
end

-- Teleports the player to their plot, assigning one if needed, and creating a character if Loads the players latest build if they are being assigned a plot
function ServerPlotManager:respawnPlayer(player)
  if not inWorldEnvironment(self) then
    self.worldFunctionQueue:push({destination = "respawnPlayer", params = {self, player}})
    return
  end

  if not self.initialised then
    print("Skipping respawning player, plots not loaded")
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
  else
    print(player.name.." has no plot, assigning plot")
    for plotId, plot in pairs(self.plots) do
      if not plot.playerId then
        plot.playerId = player:getId()
        print("Assigned plot "..plotId.." to "..player.name..", teleporting")
        character:setWorldPosition(plot.position + sm.vec3.new(0, 0, 3))
        self:loadBuild(player)
        return
      end
    end
  end
end

function ServerPlotManager:onCreate()
  self.worldFunctionQueue = Queue()
  self.plots = sm.storage.load("plots")
  self.initialised = false

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

function ServerPlotManager:onPlayerLeft(player)
  print("Removing "..player.name.." plot")

  local plotId = getPlotId(self, player)
  destroyBuild(self, plotId)
  self.plots[plotId].playerId = nil
end

-- Registers new plots, tries triggering initialization
function ServerPlotManager:onCellLoaded(x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

  for _, node in ipairs(nodes) do
    local plotId = node.params["Plot ID"]

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

    tryInitialize(self)
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
