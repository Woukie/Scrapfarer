SaveMonitor = class(nil)

function SaveMonitor.client_onInteract(self, character, state)
  if state then
    g_clientShopManager:openShop()
	end
end
