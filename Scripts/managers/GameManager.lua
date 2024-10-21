-- Keeps track of game state for each player
GameManager = class(nil)

function GameManager.server_onCreate(self)
  self.gameStates = {}
end

function GameManager.server_onPlayerJoined(self, player)
  self.gameStates[player:getId()] = {
    playing = false,
    checkpoints = {}
  }
end

function GameManager.server_onPlayerLeft(self, player)
  self.gameStates[player:getId()] = nil
end

function GameManager.startRun(self, player)
  if self.gameStates[player:getId()]["playing"] then
    return
  end

  self.gameStates[player:getId()]["playing"] = true
  g_serverPlotManager:hideFloor(player)
end

function GameManager.endRun(self, player)
  local gamestate = self.gameStates[player:getId()]
  if not gamestate["playing"] then
    g_serverPlotManager:respawnPlayer(player)
    return
  end

  local totalReward = 0
  for _, reward in pairs(gamestate["checkpoints"]) do
    totalReward = totalReward + reward
  end
  print(player.name.." ended their run earning "..totalReward.." coins")

  gamestate["playing"] = false
  gamestate["checkpoints"] = {}
  g_serverPlotManager:showFloor(player)
  g_serverPlotManager:respawnPlayer(player)
end

function GameManager.passCheckpoint(self, player, checkpointId, reward)
  local gameState = self.gameStates[player:getId()]
  if not gameState["playing"] then
    return
  end

  if gameState["checkpoints"][checkpointId] then
    return
  end

  gameState["checkpoints"][checkpointId] = reward
  print(player.name.." passed checkpoint "..checkpointId.." valued at "..reward.." coins")
end
