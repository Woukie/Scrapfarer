dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

-- Keeps track of game state for each player, a lot of data is stored on the client so this is mainly for game logic like respawning and keeping track of checkpoints
ServerGameManager = class(nil)

function ServerGameManager.onCreate(self)
  self.gameStates = {}
  self.sendToClientQueue = Queue()
end

local function loadPlayer(self, player)
  local playerId = player:getId()
  local playerData = sm.storage.load(playerId)

  if playerData then
    assert(playerData.coins)
    self.gameStates[playerId].coins = playerData.coins
    print("Loaded "..player.name.."'s player data from storage")
    return true
  end

  return false
end

local function savePlayer(self, player)
  local playerId = player:getId()
  sm.storage.save(playerId, {coins = self.gameStates[playerId].coins})
  print("Saved "..player.name.."'s player data to storage")
end

function ServerGameManager.onPlayerJoined(self, player)
  local playerId = player:getId()

  self.gameStates[playerId] = {
    playing = false,
    checkpoints = {},
    coins = 0
  }

  if not loadPlayer(self, player) then
    savePlayer(self, player)
  end

  g_serverPlotManager:respawnPlayer(player)

  self.sendToClientQueue:push({client = player, callback = "client_syncGameData", data = {coins = self.gameStates[playerId].coins}})
end

function ServerGameManager.onPlayerLeft(self, player)
  self.gameStates[player:getId()] = nil
end

function ServerGameManager.startRun(self, player)
  if self.gameStates[player:getId()]["playing"] then
    print(player.name.." cannot start their run as they are already in one")
    return
  end

  print(player.name.." is starting a run")
  g_serverPlotManager:exitBuildMode(player)

  self.gameStates[player:getId()]["playing"] = true
end

function ServerGameManager.stopRun(self, player)
  local gamestate = self.gameStates[player:getId()]
  if not gamestate["playing"] then
    print(player.name.." cannot stop their run as they are not in one")
    return
  end

  local totalReward = 0
  for _, reward in pairs(gamestate["checkpoints"]) do
    totalReward = totalReward + reward
  end
  print(player.name.." ended their run earning "..totalReward.." coins")
  gamestate.coins = gamestate.coins + totalReward

  gamestate["playing"] = false
  gamestate["checkpoints"] = {}
  g_serverPlotManager:respawnPlayer(player)
  g_serverPlotManager:loadBuild(player)

  savePlayer(self, player)
  self.sendToClientQueue:push({client = player, callback = "client_syncGameData", data = {coins = gamestate.coins}})
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
