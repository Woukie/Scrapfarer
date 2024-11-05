DangerMonitor = class(nil)

function DangerMonitor.client_onInteract(self, character, state)
  if state then
    g_clientDangerManager:openGui()
	end
end
