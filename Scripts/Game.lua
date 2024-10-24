dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerCheckpointManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerGameManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerObstacleManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientGameManager.lua")

Game = class(nil)

Game.enableLimitedInventory = false
Game.enableRestrictions = true
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = true

function Game.server_onCreate(self)
	print("Game.server_onCreate")

  g_serverPlotManager = ServerPlotManager()
  g_serverPlotManager:onCreate(self)

  g_checkpointManager = ServerCheckpointManager()
  g_checkpointManager:onCreate()

  g_serverGameManager = ServerGameManager()
  g_serverGameManager:onCreate()

  g_serverObstacleManager = ServerObstacleManager()
  g_serverObstacleManager:onCreate()

  self.world = self.storage:load()

  if not self.world then
    self.world = sm.world.createWorld("$CONTENT_DATA/Scripts/World.lua", "World")
  end

  self.storage:save(self.world)
end

-- Event triggered by the plot manager to make sure a plots cell is loaded
function Game:loadPlotWhenReady(player)
  local position = player.character.worldPosition
  self.world:loadCell(math.floor(position.x / CELL_SIZE), math.floor(position.z / CELL_SIZE), player, "loadBuild", nil, self)
end

-- Soley used to pass on callback in loadPlotWhenReady
function Game.loadBuild(self, world, x, y, player, params)
  g_serverPlotManager:loadBuild(player, false)
end

function Game.server_onPlayerJoined(self, player, isNewPlayer)
  print("Game.server_onPlayerJoined")

  self.world:loadCell(0, 0, player)

  g_serverGameManager:onPlayerJoined(player)
end

function Game.client_onCreate()
  g_clientPlotManager = ClientPlotManager()
  g_clientPlotManager:onCreate()

  g_clientGameManager = ClientGameManager()
  g_clientGameManager:onCreate()

  sm.game.bindChatCommand("/respawn", {}, "client_onChatCommand", "Respawn")
  sm.game.bindChatCommand("/start", {}, "client_onChatCommand", "Starts the game")
  sm.game.bindChatCommand("/stop", {}, "client_onChatCommand", "Stops the game")
  sm.game.bindChatCommand("/load", {}, "client_onChatCommand", "Reloads the last build")
end

function Game.server_onPlayerLeft(self, player)
  g_serverPlotManager:onPlayerLeft(player)
  g_serverGameManager:onPlayerLeft(player)
end

function Game.client_onChatCommand(self, params)
  if params[1] == "/respawn" then
		self.network:sendToServer("server_respawn", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/start" then
		self.network:sendToServer("server_startRun", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/stop" then
		self.network:sendToServer("server_stopRun", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/load" then
		self.network:sendToServer("server_reloadBuild", {player = sm.localPlayer.getPlayer()})
  end
end

function Game.server_reloadBuild(self, params)
  g_serverPlotManager:loadBuild(params.player, true)
end

function Game.server_respawn(self, params)
  g_serverPlotManager:respawnPlayer(params.player)
end

function Game.server_startRun(self, params)
  g_serverGameManager:startRun(params.player)
end

function Game.server_stopRun(self, params)
  g_serverGameManager:stopRun(params.player)
end
