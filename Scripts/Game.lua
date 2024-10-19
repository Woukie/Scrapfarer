dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/managers/PlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/GameManager.lua")

Game = class( nil )

Game.enableLimitedInventory = false
Game.enableRestrictions = false
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = true

function Game.server_onCreate(self)
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save(self.sv.saved)
	end

  g_plotManager = PlotManager()
	g_plotManager:server_onCreate(self.sv.saved.world)

  g_gameManager = GameManager()
	g_gameManager:server_onCreate(self.sv.saved.world)
end

-- Let it play out as normal, we need to load plots before we can send players to them, which is handled by the world once it has loaded
function Game.server_onPlayerJoined(self, player, isNewPlayer)
  print("Game.server_onPlayerJoined")

  if isNewPlayer then
    if not sm.exists(self.sv.saved.world) then
      sm.world.loadWorld(self.sv.saved.world)
    end
    self.sv.saved.world:loadCell( 0, 0, player, "server_createPlayerCharacter" )
  end

  g_gameManager:server_onPlayerJoined(player)
end

function Game.server_createPlayerCharacter(self, world, x, y, player, params)
  local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter(character)
  
  g_plotManager:server_respawnPlayer()
end

function Game.client_onCreate()
  sm.game.bindChatCommand("/respawn", {}, "client_onChatCommand", "Respawn")
  sm.game.bindChatCommand("/start", {}, "client_onChatCommand", "Starts the game")
end

function Game.server_onPlayerLeft(self, player)
  g_plotManager:server_onPlayerLeft(player)
  g_gameManager:server_onPlayerLeft(player)
end

function Game.client_onClientDataUpdate(self, clientData, channel)
	if channel == 2 then
		self.cl.time = clientData.time
	elseif channel == 1 then
		g_survivalDev = clientData.dev
		self:bindChatCommands()
	end
end

function Game.client_onChatCommand(self, params)
  if params[1] == "/respawn" then
		self.network:sendToServer("server_respawn", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/start" then
		self.network:sendToServer("server_start", {player = sm.localPlayer.getPlayer()})
  end
end

function Game.server_respawn( self, params )
  g_gameManager:endRun(params.player)
end

function Game.server_start( self, params )
  g_gameManager:startRun(params.player)
end
