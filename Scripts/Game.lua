dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerCheckpointManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerGameManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientGameManager.lua")

Game = class( nil )

Game.enableLimitedInventory = false
Game.enableRestrictions = true
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = true

function Game.server_onCreate(self)
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.world = self.storage:load()
    if self.sv.world == nil then
		self.sv.world = {}
		self.sv.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	end

  g_serverPlotManager = ServerPlotManager()
	g_serverPlotManager:onCreate(self)

  g_checkpointManager = ServerCheckpointManager()
	g_checkpointManager:onCreate()

  g_serverGameManager = ServerGameManager()
	g_serverGameManager:onCreate()
end

-- Let it play out as normal, we need to load plots before we can send players to them, which is handled by the world once it has loaded
function Game.server_onPlayerJoined(self, player, isNewPlayer)
  print("Game.server_onPlayerJoined")

  if isNewPlayer then
    if not sm.exists(self.sv.world) then
      sm.world.loadWorld(self.sv.world)
    end
    self.sv.world:loadCell( 0, 0, player, "server_createPlayerCharacter" )
  else
    g_serverPlotManager:respawnPlayer(player)
  end

  g_serverGameManager:onPlayerJoined(player)
end

function Game.server_createPlayerCharacter(self, world, x, y, player, params)
  g_serverPlotManager:respawnPlayer(player)
end

function Game.client_onCreate()
  g_clientPlotManager = ClientPlotManager()
  g_clientPlotManager:onCreate()

  g_clientGameManager = ClientGameManager()
  g_clientGameManager:onCreate()

  sm.game.bindChatCommand("/respawn", {}, "client_onChatCommand", "Respawn")
  sm.game.bindChatCommand("/start", {}, "client_onChatCommand", "Starts the game")
end

function Game.server_onPlayerLeft(self, player)
  g_serverPlotManager:onPlayerLeft(player)
  g_serverGameManager:onPlayerLeft(player)
end

function Game.client_onChatCommand(self, params)
  if params[1] == "/respawn" then
		self.network:sendToServer("server_respawn", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/start" then
		self.network:sendToServer("server_start", {player = sm.localPlayer.getPlayer()})
  end
end

function Game.server_respawn( self, params )
  g_serverGameManager:endRun(params.player)
end

function Game.server_start( self, params )
  g_serverGameManager:startRun(params.player)
end
