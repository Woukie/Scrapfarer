TreasureChest = class(nil)

function TreasureChest.client_onInteract(self, character, state)
  if state then
    g_clientRewardManager:openShop()
	end
end
