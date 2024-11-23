StartButton = class(nil)

StartButton.poseWeightCount = 1

function StartButton:server_setState(params)
  if params.state then
    sm.effect.playEffect("Elevator Button", self.shape:getWorldPosition())
    g_serverGameManager:startRun(params.character:getPlayer())
  end
end

function StartButton.client_onInteract(self, character, state)
  self.network:sendToServer("server_setState", {state = state, character = character})
  if state then
    self.interactable:setPoseWeight(0, 1)
  else
    sm.gui.chatMessage("Next time use /start to start from anywhere!")
    self.interactable:setPoseWeight(0, 0)
  end
end
