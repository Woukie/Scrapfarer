ClientPlotManager = class(nil)

function ClientPlotManager.onCreate(self, player)
  self.cl = {}
end

function ClientPlotManager.showHologram(self, plotId)

end

function ClientPlotManager.hideHologram(self, plotId)

end

function ClientPlotManager.onCellLoaded(self, x, y)
  if not self.cl or not self.cl.plots then
    return
  end

  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")
  for _, node in ipairs( nodes ) do
    local plot = self.cl.plots[node.params["Plot ID"]]
    if not plot then
      return
    end
  end
end

function ClientPlotManager.onCellUnloaded(self, x, y)
  if not self.cl or not self.cl.plots then
    return
  end

  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")
  for _, node in ipairs( nodes ) do
    local plot = self.cl.plots[node.params["Plot ID"]]
    if not plot then
      return
    end
  end
end

-- Triggered by the world
function ClientPlotManager.syncPlots(self, data)
  print("Plots synced")
  self.cl = data
end
