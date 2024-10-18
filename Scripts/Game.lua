dofile("$CONTENT_DATA/Scripts/game/blocks.lua")

Game = class( nil )

Game.enableLimitedInventory = true
Game.enableRestrictions = true
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = true

function Game.server_onCreate(self)
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save(self.sv.saved)
	end
end

-- Assign plot, setup player, load previous build if host (other clients load through)
function Game.server_onPlayerJoined(self, player, isNewPlayer)
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end
end

function Game.sv_createPlayerCharacter(self, world, x, y, player, params)
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end

-- Update the server with a clients progress (client authoritative)
function Game.client_updateProgress(self, player)
end

-- Register a passed checkpoint to increase the players reward on death
function Game.server_passCheckPoint(self, player)
end

-- Award for reaching the end of the river, stops the timer, saves best time
function Game.server_winRun(self, player)
end

-- Awards gold based on how many checkpoints were passed, cancels the timer
function Game.server_failRun(self, player)
end

-- Enables checkpoint passing, destroys floor below players plot, disables building for player, 
function Game.server_startRun(self, player)
end

-- Starts timer for player if game is running, timer stops automatically
function Game.server_starTimer(self, player)
end

-- Clears the players plot, resetting the players inventory
function Game.server_clearBuild(self, player)
end

-- Clears build, then loads the building, updaing the players inventory
function Game.loadBuilding(self, player, building)
end
