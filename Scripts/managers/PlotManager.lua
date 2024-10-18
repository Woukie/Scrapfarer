dofile "$SURVIVAL_DATA/Scripts/util.lua"

-- Keeps track of who owns what plots
-- Plots ownership is needed for respawning players
PlotManager = class(nil)

function PlotManager.server_onCreate(self)
  self.plots = {}
  self.initialised = false
end

-- Respawns a player at a known plot location, assigning them if necessary, skipping if plots are not loaded (once plots are loaded, players are automatically assigned to them with this method)
function PlotManager.server_respawnPlayer(self, player)
  if not self.initialised then
    print("Skipping assigning player for now, plots not loaded yet")
    return
  end

  print("Checking for plots owned by "..player.name)
  for plotID, plot in pairs(self.plots) do
    if plot.playerId == player:getId() then
      print(player.name.." owns plot "..plotID..", teleporting")

      player.character:setWorldPosition(plot.position)
    end
  end
  
  print(player.name.." has no plot, assigning plot")
  for plotID, plot in pairs(self.plots) do
    if not plot.playerId then
      plot.playerId = player:getId()
      print("Assigned plot "..plotID.." to "..player.name..", teleporting")

      player.character:setWorldPosition(plot.position)
      return
    end
  end

  print("Player could not be assigned to plot. Either something is wrong, or all plots are full!!")
end

function PlotManager.server_onPlayerLeft(self, player)
  print("Removing "..player.name.." from owned plots")
  for plotID, plot in pairs(self.plots) do
    if plot.playerId == player:getId() then
      plot.playerId = nil
    end
  end
end

function PlotManager.server_onCellLoaded(self, x, y)
  local nodes = sm.cell.getNodesByTag(x, y, "PLOT")

	if #nodes > 0 then
    local idx = 1
    for _, node in ipairs( nodes ) do
      local plotID = node.params["Plot ID"]
      if not self.plots[plotID] then
        self.plots[plotID] = {}
        self.plots[plotID]["position"] = node.position

        if not self.initialised then
          local players = sm.player.getAllPlayers()
  
          if #self.plots >= #players then
            print("Enough plots loaded, respawning players")
  
            self.initialised = true;
            for _, player in ipairs(players) do
              self:server_respawnPlayer(player)
            end
          end
        end
      end

      idx = idx + 1
    end
	end
end
