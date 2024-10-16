dofile("$CONTENT_DATA/Scripts/managers/ForceManager.lua")

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
end

function World.client_onCreate(self)
  print("World.client_onCreate")

  if self.forceManager == nil then
		assert(not sm.isHost)
		self.forceManager = ForceManager()
	end
	self.forceManager:client_onCreate()
end

function World.server_onCellCreated(self, x, y)
  self.forceManager:server_onCellLoaded(x, y)
end

function World.client_onCellLoaded(self, x, y)
  self.forceManager:client_onCellLoaded(x, y)
end

function World.server_onCellLoaded(self, x, y)
  self.forceManager:server_onCellReloaded(x, y)
end

function World.server_onCellUnloaded(self, x, y)
  self.forceManager:server_onCellUnloaded(x, y)
end

function World.client_onCellUnloaded(self, x, y)
  self.forceManager:client_onCellUnloaded(x, y)
end
