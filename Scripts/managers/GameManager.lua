-- Keeps track of game state for each player
GameManager = class(nil)

function GameManager.server_onCreate(self)
  self.gameStates = {}
end

function GameManager.server_onPlayerJoined(self, player)
  self.gameStates[player:getId()] = {}
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
  if not self.gameStates[player:getId()]["playing"] then
    g_serverPlotManager:respawnPlayer(player)
    return
  end

  self.gameStates[player:getId()]["playing"] = false
  g_serverPlotManager:showFloor(player)
  g_serverPlotManager:respawnPlayer(player)
end
