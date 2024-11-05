SaveMonitor = class(nil)

function SaveMonitor:server_setState(params)
  if params.state then
    sm.effect.playEffect("Part - Upgrade", self.shape:getWorldPosition(), nil, sm.quat.fromEuler(sm.vec3.new(90, 0, 0)))
    g_serverGameManager:saveBuild(params.character:getPlayer())
  end
end


function SaveMonitor.client_onInteract(self, character, state)
  self.network:sendToServer("server_setState", {state = state, character = character})
end
