ClientPlotManager = class(nil)

function ClientPlotManager.onCreate(self, player)
  self.cl = {}
end

-- Triggered by the world
function ClientPlotManager.syncPlots(self, data)
  print("Plots synced")
  self.cl = data
end
