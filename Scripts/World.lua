dofile("$CONTENT_DATA/Scripts/managers/ForceManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/WaterManager.lua")

local worldSize = 1024

World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -worldSize
World.cellMaxX = worldSize - 1
World.cellMinY = -worldSize
World.cellMaxY = worldSize - 1
World.worldBorder = true

World.groundMaterialSet = "$CONTENT_DATA/Terrain/Materials/cool_materialset.json"

function World.server_onCreate(self)
  self.forceManager = ForceManager()
	self.forceManager:server_onCreate(self)

  self.waterManager = WaterManager()
	self.waterManager:sv_onCreate(self)
end

function World:client_playeffect(params)
  sm.effect.playEffect(params.name, params.position)
end

function World:client_playsound(params)
  sm.audio.play(params.name, params.position)
end

function World.client_onCreate(self)
  if self.forceManager == nil then
		assert(not sm.isHost)
		self.forceManager = ForceManager()
	end
	self.forceManager:client_onCreate()

  if self.waterManager == nil then
		assert(not sm.isHost)
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()
end

function World.server_onFixedUpdate(self)
  g_serverPlotManager:onFixedUpdate()
  g_serverGameManager:onFixedUpdate(self)
  g_serverObstacleManager:onFixedUpdate()
  self.forceManager:server_onFixedUpdate()
	self.waterManager:sv_onFixedUpdate()
end

function World.client_onFixedUpdate(self)
  self.waterManager:cl_onFixedUpdate()
end

function World.client_onUpdate(self, _)
	g_effectManager:cl_onWorldUpdate(self)
end

function World.server_onCellCreated(self, x, y)
  g_checkpointManager:onCellLoaded(x, y)
  g_serverPlotManager:onCellLoaded(x, y)
  g_serverDestructionManager:onCellLoaded(x, y)
  g_serverObstacleManager:onCellLoaded(x, y)
  g_serverUnlockManager:onCellLoaded(x, y)
  self.forceManager:server_onCellLoaded(x, y)
  self.waterManager:sv_onCellLoaded(x, y)
end

function World.client_onCellLoaded(self, x, y)
  g_clientPlotManager:onCellLoaded(x, y)
  self.forceManager:client_onCellLoaded(x, y)
  self.waterManager:cl_onCellLoaded(x, y)
  g_effectManager:cl_onWorldCellLoaded(self, x, y)
end

function World.server_onCellLoaded(self, x, y)
  g_checkpointManager:onCellLoaded(x, y)
  g_serverPlotManager:onCellLoaded(x, y)
  g_serverObstacleManager:onCellLoaded(x, y)
  g_serverDestructionManager:onCellLoaded(x, y)
  g_serverUnlockManager:onCellLoaded(x, y)
  self.forceManager:server_onCellReloaded(x, y)
  self.waterManager:sv_onCellReloaded(x, y)
end

function World.server_onCellUnloaded(self, x, y)
  g_checkpointManager:onCellUnloaded(x, y)
  g_serverDestructionManager:onCellUnloaded(x, y)
  g_serverUnlockManager:onCellUnloaded(x, y)
  self.forceManager:server_onCellUnloaded(x, y)
  self.waterManager:sv_onCellUnloaded(x, y)
end

function World.client_onCellUnloaded(self, x, y)
  g_clientPlotManager:onCellUnloaded(x, y)
  self.forceManager:client_onCellUnloaded(x, y)
  self.waterManager:cl_onCellUnloaded(x, y)
  g_effectManager:cl_onWorldCellUnloaded(self, x, y)
end

function World.client_syncPlots(self, data)
  if g_clientPlotManager then
    g_clientPlotManager:syncPlots(data)
    return
  end
end

function World.client_syncGameData(self, data)
  if g_clientGameManager then
    g_clientGameManager:syncData(data)
    return
  end
end
