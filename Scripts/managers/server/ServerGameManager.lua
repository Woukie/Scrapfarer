dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

-- Keeps track of game state for each player, a lot of data is stored on the client so this is mainly for game logic like respawning and keeping track of checkpoints
ServerGameManager = class(nil)

function ServerGameManager.onCreate(self)
  self.gameStates = {}
  self.sendToClientQueue = Queue()
end

function ServerGameManager.onPlayerJoined(self, player)
  self.gameStates[player:getId()] = {
    playing = false,
    checkpoints = {}
  }
end

function ServerGameManager.onPlayerLeft(self, player)
  self.gameStates[player:getId()] = nil
end

function ServerGameManager.startRun(self, player)
  if self.gameStates[player:getId()]["playing"] then
    return
  end

  self.gameStates[player:getId()]["playing"] = true
  g_serverPlotManager:hideFloor(player)
end

function ServerGameManager.endRun(self, player)
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

  self.sendToClientQueue:push({client = player, callback = "client_syncGameData", data = totalReward})
end

function ServerGameManager.passCheckpoint(self, player, checkpointId, reward)
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

function ServerGameManager.onFixedUpdate(self, worldSelf)
  if (not self.sendToClientQueue) then
    return
  end

  while self.sendToClientQueue:size() > 0 do
    local request = self.sendToClientQueue:pop()
    worldSelf.network:sendToClient(request.client, request.callback, request.data)
  end
end
