dofile("$CONTENT_DATA/Scripts/managers/ForceManager.lua")
dofile("$CONTENT_DATA/Scripts/managers/WaterManager.lua")

World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

World.groundMaterialSet = "$CONTENT_DATA/Terrain/Materials/cool_materialset.json"

function World.server_onCreate(self)
  print("World.server_onCreate")

  self.forceManager = ForceManager()
	self.forceManager:server_onCreate(self)

  self.waterManager = WaterManager()
	self.waterManager:sv_onCreate(self)
end

function World.client_onCreate(self)
  print("World.client_onCreate")

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
	self.waterManager:sv_onFixedUpdate()
end

function World.client_onFixedUpdate(self)
  self.waterManager:cl_onFixedUpdate()
end

function World.server_onCellCreated(self, x, y)
  self.forceManager:server_onCellLoaded(x, y)
  self.waterManager:sv_onCellLoaded(x, y)
  g_plotManager:server_onCellLoaded(x, y)
end

function World.client_onCellLoaded(self, x, y)
  self.forceManager:client_onCellLoaded(x, y)
  self.waterManager:cl_onCellLoaded(x, y)
end

function World.server_onCellLoaded(self, x, y)
  self.forceManager:server_onCellReloaded(x, y)
  self.waterManager:sv_onCellReloaded(x, y)
  g_plotManager:server_onCellLoaded(x, y)
end

function World.server_onCellUnloaded(self, x, y)
  self.forceManager:server_onCellUnloaded(x, y)
  self.waterManager:sv_onCellUnloaded(x, y)
end

function World.client_onCellUnloaded(self, x, y)
  self.forceManager:client_onCellUnloaded(x, y)
  self.waterManager:cl_onCellUnloaded(x, y)
end
