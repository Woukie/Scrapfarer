dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/tools.lua")
dofile("$CONTENT_DATA/Scripts/managers/EffectManager.lua" )
dofile("$CONTENT_DATA/Scripts/managers/server/ServerCheckpointManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerGameManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerObstacleManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerDestructionManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/server/ServerUnlockManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientPlotManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientRewardManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientDangerManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientShopManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/client/ClientGameManager.lua")

Game = class(nil)

Game.enableLimitedInventory = false
Game.enableRestrictions = true
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = true

function Game.server_onCreate(self)
  g_serverPlotManager = ServerPlotManager()
  g_serverPlotManager:onCreate(self)

  g_checkpointManager = ServerCheckpointManager()
  g_checkpointManager:onCreate()

  g_serverGameManager = ServerGameManager()
  g_serverGameManager:onCreate()

  g_serverObstacleManager = ServerObstacleManager()
  g_serverObstacleManager:onCreate()

  g_serverDestructionManager = ServerDestructionManager()
  g_serverDestructionManager:onCreate()

  g_serverUnlockManager = ServerUnlockManager()
  g_serverUnlockManager:onCreate()

  self.world = self.storage:load()

  if not self.world then
    self.world = sm.world.createWorld("$CONTENT_DATA/Scripts/World.lua", "World")
  end

  self.storage:save(self.world)
end

-- Event triggered by the plot manager to make sure a plots cell is loaded
function Game:loadPlotWhenReady(params)
  local character = params.character
  if not character then
    character = sm.character.createCharacter(params.player, self.world, sm.vec3.new( 32, 32, 5 ), 0, 0)
    params.player:setCharacter(character)
  end

  local position = params.character.worldPosition
  self.world:loadCell(math.floor(position.x / CELL_SIZE), math.floor(position.z / CELL_SIZE), params.player, "loadBuild", nil, self)
end

-- Soley used to pass on callback in loadPlotWhenReady
function Game.loadBuild(self, world, x, y, player, params)
  g_serverPlotManager:loadBuild(player, false)
end

function Game.server_onPlayerJoined(self, player)
  self.world:loadCell(0, 0, player, "server_joinWhenLoaded")
end

function Game:server_joinWhenLoaded(world, x, y, player, params, handle)
  g_serverGameManager:onPlayerJoined(player, self.world)
end

function Game:client_onCreate()
  g_clientPlotManager = ClientPlotManager()
  g_clientPlotManager:onCreate()

  g_clientGameManager = ClientGameManager()
  g_clientGameManager:onCreate()

  g_clientShopManager = ClientShopManager()
  g_clientShopManager:onCreate()

  g_clientRewardManager = ClientRewardManager()
  g_clientRewardManager:onCreate()

  g_clientDangerManager = ClientDangerManager()
  g_clientDangerManager:onCreate()

  g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()

  sm.game.bindChatCommand("/respawn", {}, "client_onChatCommand", "Respawn")
  sm.game.bindChatCommand("/start", {}, "client_onChatCommand", "Starts the game")
  sm.game.bindChatCommand("/stop", {}, "client_onChatCommand", "Stops the game")
  sm.game.bindChatCommand("/shop", {}, "client_onChatCommand", "Opens the shop")
  -- sm.game.bindChatCommand("/teleport", {{"number", "x", false}, {"number", "y", false}, {"number", "z", false}}, "client_onChatCommand", "Teleport")
  sm.game.bindChatCommand("/playaudio", {{"string", "name of sound", false}}, "client_onChatCommand", "Plays audio at the location of the player")
  sm.game.bindChatCommand("/playeffect", {{"string", "name of effect", false}}, "client_onChatCommand", "Plays effect at the location of the player")
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
  -- elseif params[1] == "/teleport" then
	-- 	self.network:sendToServer("server_teleport", {player = sm.localPlayer.getPlayer(), x = params[2], y = params[3], z = params[4]})
  elseif params[1] == "/stop" then
		self.network:sendToServer("server_stopRun", {player = sm.localPlayer.getPlayer()})
  elseif params[1] == "/playaudio" then
    local character = sm.localPlayer.getPlayer():getCharacter()
    sm.event.sendToWorld(character:getWorld(), "client_playsound", {position = character:getWorldPosition(), name = params[2]})
  elseif params[1] == "/playeffect" then
    local character = sm.localPlayer.getPlayer():getCharacter()
    sm.event.sendToWorld(character:getWorld(), "client_playeffect", {position = character:getWorldPosition(), name = params[2]})
  elseif params[1] == "/shop" then
		g_clientShopManager:openShop()
  end
end

function Game.server_respawn(self, params)
  g_serverPlotManager:respawnPlayer(params.player)
end

function Game.server_startRun(self, params)
  g_serverGameManager:startRun(params.player)
end

-- function Game.server_teleport(self, params)
--   params.player.character:setWorldPosition(sm.vec3.new(params.x, params.y, params.z))
-- end

function Game.server_stopRun(self, params)
  g_serverGameManager:stopRun(params.player)
end

-- Shop gui callbacks

function Game:server_buyShopItem(params)
  g_serverGameManager:buyItem(params.player, params.name)
end

function Game:client_closeShop(_)
  g_clientShopManager:closeShop()
end

function Game:client_buyShopItem(_)
  local item = g_clientShopManager:getSelectedItem()
  if not item or item.cost > g_clientGameManager:getCoins() then
    return
  end

  local character = sm.localPlayer.getPlayer():getCharacter()
  sm.event.sendToWorld(character:getWorld(), "client_playeffect", {position = character:getWorldPosition(), name = "Gui - DressbotCollect"})

  self.network:sendToServer("server_buyShopItem", {name = item.name, player = sm.localPlayer.getPlayer()})
end

function Game:client_setShopCategory(name)
  local category, _ = name:gsub("Button", "")
  g_clientShopManager:selectShopCategory(category)
end

function Game:client_selectShopItem(_, _, item, _)
  g_clientShopManager:selectShopItem(item)
end

-- Reward gui callbacks

function Game:client_closeRewards(_)
  g_clientRewardManager:closeGui()
end

function Game:server_takeOffer(params)
  g_serverGameManager:takeOffer(params.player)
end

function Game:server_takeTreasure(params)
  g_serverGameManager:takeTreasure(params.player)
end

function Game:client_takeOffer(_)
  g_clientRewardManager:closeGui()

  local character = sm.localPlayer.getPlayer():getCharacter()
  sm.event.sendToWorld(character:getWorld(), "client_playeffect", {position = character:getWorldPosition(), name = "Gui - DressbotCollect"})

  self.network:sendToServer("server_takeOffer", {player = sm.localPlayer.getPlayer()})
end

function Game:client_takeTreasure(_)
  g_clientRewardManager:closeGui()

  local character = sm.localPlayer.getPlayer():getCharacter()
  sm.event.sendToWorld(character:getWorld(), "client_playeffect", {position = character:getWorldPosition(), name = "Gui - DressbotCollect"})

  self.network:sendToServer("server_takeTreasure", {player = sm.localPlayer.getPlayer()})
end

function Game:client_closeDangerScreen(params)
  g_clientDangerManager:closeGui()
end

function Game:server_deleteBuild(params)
  g_serverGameManager:deleteBuild(params.player)
end

function Game:server_revertBuild(params)
  g_serverGameManager:revertBuild(params.player)
end

function Game:client_deleteBuild(_)
  g_clientDangerManager:closeGui()
  local player = sm.localPlayer.getPlayer()
  local character = player:getCharacter()
  self.network:sendToServer("server_deleteBuild", {player = player})
  sm.event.sendToWorld(
    character:getWorld(),
    "client_playeffect",
    {
      position = character:getWorldPosition(),
      name = "PropaneTank - ExplosionBig"
    }
  )
end

function Game:client_revertBuild(_)
  g_clientDangerManager:closeGui()
  local player = sm.localPlayer.getPlayer()
  local character = player:getCharacter()
  self.network:sendToServer("server_revertBuild", {player = sm.localPlayer.getPlayer()})
  sm.event.sendToWorld(
    character:getWorld(),
    "client_playeffect",
    {
      position = character:getWorldPosition(),
      name = "PropaneTank - ExplosionSmall"
    }
  )
end

