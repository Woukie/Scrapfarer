Shop = class(nil)

function Shop.client_onInteract(self, character, state)
  if state then
    g_clientInventoryManager:openShop()
	end
end
