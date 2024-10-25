TreasureChest = class(nil)

function TreasureChest.client_onInteract(self, character, state)
  if state then
		self.network:sendToServer("server_onInteract", character)
	end
end

function TreasureChest:server_onInteract(params)
	g_serverGameManager:stopRun(params:getPlayer())
end
