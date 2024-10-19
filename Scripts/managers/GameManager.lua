dofile("$CONTENT_DATA/Scripts/managers/PlotManager.lua")

-- Keeps track of game state for each player
GameManager = class(nil)

function GameManager.server_onCreate(self)
  self.gameStates = {}
end

function GameManager.getState(self, player)
  return self.gameStates[player.getId()]
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
  g_plotManager:server_hideFloor(player)
end

function GameManager.endRun(self, player)
  if not self.gameStates[player:getId()]["playing"] then
    return
  end
  
  self.gameStates[player:getId()]["playing"] = false
  g_plotManager:server_showFloor(player)
  g_plotManager:server_respawnPlayer(player)
end
