dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

-- Literally taken straight from survival, but with oil and chemicals removed
-- Some comments removed

WaterManager = class( nil )

function WaterManager.onCreate( self )
	self.cells = {}

	self.triggeredCharacters = {}
	self.submergedBodies = {}
end

function WaterManager.sv_onCreate( self )
	if sm.isHost then
		self:onCreate()
	end
end

function WaterManager.cl_onCreate( self )
	if not sm.isHost then
		self:onCreate()
	end
end

function WaterManager.onCellLoaded( self, x, y )
	local cellKey = CellKey(x, y)
	local waterNodes = sm.cell.getNodesByTag( x, y, "WATER" )

	if #waterNodes > 0 then
		self.cells[cellKey] = {}

    local idx = 1
    for _, node in ipairs( waterNodes ) do
      -- Keep water in area userdata in case we need it
      local areaTrigger = sm.areaTrigger.createBoxWater( node.scale * 0.5, node.position, node.rotation, sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.areaTrigger, { water = true } )
      areaTrigger:bindOnEnter( "trigger_onEnterWater", self )
      areaTrigger:bindOnExit( "trigger_onExitWater", self )
      areaTrigger:bindOnStay( "trigger_onStayWater", self )
      areaTrigger:bindOnProjectile( "trigger_onProjectile", self )
      self.cells[cellKey][idx] = areaTrigger
      idx = idx + 1
    end
	end
end

function WaterManager.sv_onCellLoaded( self, x, y )
	if sm.isHost then
		self:onCellLoaded( x, y )
	end
end

function WaterManager.sv_onCellReloaded( self, x, y )
	if sm.isHost then
		self:onCellLoaded( x, y )
	end
end

function WaterManager.cl_onCellLoaded( self, x, y )
	if not sm.isHost then
		self:onCellLoaded( x, y )
	end
end

function WaterManager.onCellUnloaded( self, x, y )
	--print("--- unloading water objs on cell " .. x .. ":" .. y .. " ---")
	local cellKey = CellKey(x, y)

	if self.cells[cellKey] then
		for _, trigger in ipairs( self.cells[cellKey] ) do
			sm.areaTrigger.destroy( trigger )
		end
		self.cells[cellKey] = nil
	end
end

function WaterManager.sv_onCellUnloaded( self, x, y )
	if sm.isHost then
		self:onCellUnloaded( x, y )
	end
end

function WaterManager.cl_onCellUnloaded( self, x, y )
	if not sm.isHost then
		self:onCellUnloaded( x, y )
	end
end

function WaterManager.onFixedUpdate( self )
	-- Reset tracking of triggered objects during previous tick
	self.triggeredCharacters = {}
end

function WaterManager.sv_onFixedUpdate( self )
	if sm.isHost then
		self:onFixedUpdate()
	end
end

function WaterManager.cl_onFixedUpdate( self )
	if not sm.isHost then
		self:onFixedUpdate()
	end
end

local function PlaySplashEffect( pos, velocity, mass )
	local energy = 0.5*velocity:length()*velocity:length()*mass

  local params = {
		["Size"] = min( 1.0, mass / 76800.0 ),
		["Velocity_max_50"] = velocity:length(),
		["Phys_energy"] = energy / 1000.0
	}

	if energy > 8000 then
		sm.effect.playEffect( "Water - HitWaterMassive", pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), params )
	elseif energy > 4000 then
		sm.effect.playEffect( "Water - HitWaterBig", pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), params )
	elseif energy > 150 then
		sm.effect.playEffect( "Water - HitWaterSmall", pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), params )
	elseif energy > 1 then
		sm.effect.playEffect( "Water - HitWaterTiny", pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), params )
	end
  
end

local function CalulateForce( waterHeightPos, worldPosition, worldRotation, velocity, halfExtent, mass )
	-- Setup all the corners of the shape's bounding box
	local volume = ( halfExtent.x * 2.0 * halfExtent.y * 2.0 * halfExtent.z * 2.0 )

	local corners = {}
	corners[1] = worldPosition + worldRotation * sm.vec3.new( halfExtent.x, halfExtent.y, halfExtent.z )
	corners[2] = worldPosition + worldRotation * sm.vec3.new( halfExtent.x, halfExtent.y, -halfExtent.z )
	corners[3] = worldPosition + worldRotation * sm.vec3.new( halfExtent.x, -halfExtent.y, halfExtent.z )
	corners[4] = worldPosition + worldRotation * sm.vec3.new( halfExtent.x, -halfExtent.y, -halfExtent.z )
	corners[5] = worldPosition + worldRotation * sm.vec3.new( -halfExtent.x, halfExtent.y, halfExtent.z )
	corners[6] = worldPosition + worldRotation * sm.vec3.new( -halfExtent.x, halfExtent.y, -halfExtent.z )
	corners[7] = worldPosition + worldRotation * sm.vec3.new( -halfExtent.x, -halfExtent.y, halfExtent.z )
	corners[8] = worldPosition + worldRotation * sm.vec3.new( -halfExtent.x, -halfExtent.y, -halfExtent.z )
	-- Sort so the lowest corners go first
	table.sort( corners, function ( c1, c2 ) return c1.z < c2.z end )

	-- Check which of the lowest corners are under water and calculate their total depth
	local submergedPoints = {}
	local totalDepth = 0
	local avgDepth = 0
	for _, corner in pairs( { corners[1], corners[2], corners[3], corners[4] } ) do
		if corner.z < waterHeightPos then
			totalDepth = totalDepth + ( waterHeightPos - corner.z )
			submergedPoints[#submergedPoints+1] = corner
		end
	end
	avgDepth = totalDepth * 0.25

	-- Approximate how much of the shape is submerged to calculate the displaced volume
	local bottomArea = 0.5 * ( ( corners[1] - corners[2] ):cross( corners[1] - corners[3] ):length() + ( corners[4] - corners[2] ):cross( corners[4] - corners[3] ):length() )
	local displacedVolume = math.min( ( bottomArea * avgDepth ), volume )

	-- Buoyancy force formula
	local fluidDensity = 500 -- density level 4
	local buoyancyForce = fluidDensity * displacedVolume * GRAVITY

	-- Apply buoyancy force to the shape's body using the shape's CoM as an offset
	local force = sm.vec3.new( 0, 0, buoyancyForce )
	local result = force * 0.025;

	-- Diminishing force in water, acts as water resistance
	if velocity:length() >= FLT_EPSILON then
		local direction = velocity:normalize()
		local magnitude = velocity:length()

		local antiVelocity = -direction * ( magnitude * 0.15 )
		if velocity.z > 0 then
			antiVelocity = -direction * ( magnitude * 0.15 ) --Ascending
		end
		local antiForceVector = ( antiVelocity / 0.025 ) * mass

		local horizontalDiminishScale = 0.1
		antiForceVector.x = antiForceVector.x * horizontalDiminishScale
		antiForceVector.y = antiForceVector.y * horizontalDiminishScale
		result = result + ( antiForceVector * 0.025 )
	end

	return result
end

local function UpdateCharacterInWater( trigger, character )
	-- Update swim state
	local waterHeightPos = trigger:getWorldMax().z
	--local characterFloatHeight = character.worldPosition.z + character:getHeight() * 0.15
	--local characterDiveHeight = character.worldPosition.z + character:getHeight() * 0.5
	local characterFloatOffset = 0.2 + ( character:isCrouching() and 0.4 or 0.0 )
	local characterFloatHeight = character.worldPosition.z + characterFloatOffset
	local characterDiveOffset = 0.7 + ( character:isCrouching() and 0.4 or 0.0 )
	local characterDiveHeight = character.worldPosition.z + characterDiveOffset
	if sm.isHost and character:getCanSwim() then
		-- Update swimming state
		if not character:isSwimming() then
			if waterHeightPos > characterFloatHeight then
				character:setSwimming( true )
			end
		else
			if waterHeightPos <= characterFloatHeight then
				character:setSwimming( false )
			end
		end
		-- Update diving state
		if not character:isDiving() then
			if waterHeightPos > characterDiveHeight then
				character:setDiving( true )
			end
		else
			if waterHeightPos <= characterDiveHeight then
				character:setDiving( false )
			end
		end
	end

	-- Scaled movement slowdown when walking through water
	local waterMovementSpeedFraction = 1.0
	if not character:isSwimming() then
		local depthScale = 1 - math.max( math.min( ( ( character.worldPosition.z + characterDiveOffset ) - waterHeightPos ) / ( characterDiveOffset * 2 ), 1.0 ), 0.0 )
		waterMovementSpeedFraction = math.max( math.min( 1 - ( depthScale + 0.1 ), 1.0 ), 0.3 )
	end
	if sm.isHost then
		if character.publicData then
			character.publicData.waterMovementSpeedFraction = waterMovementSpeedFraction
		end
	else
		if character.clientPublicData then
			character.clientPublicData.waterMovementSpeedFraction = waterMovementSpeedFraction
		end
	end

	if character:isTumbling() then
		local worldPosition = character:getTumblingWorldPosition()
		local worldRotation = character:getTumblingWorldRotation()
		local velocity = character:getTumblingLinearVelocity()
		local halfExtent = character:getTumblingExtent() * 0.5
		local mass = character:getMass()
		-- local mass = 10.0
		local force = CalulateForce( waterHeightPos, worldPosition, worldRotation, velocity, halfExtent, mass )
		character:applyTumblingImpulse( force )
	else
		-- Push up if under surface
		local waterHeightFloatThreshold = waterHeightPos - character:getHeight() * 0.5
		if not character:getCanSwim()  then
			local characterForce = sm.vec3.new( 0, 0, character:getMass() * 15 )
			sm.physics.applyImpulse( character, characterForce * 0.025, true )
		elseif ( characterFloatHeight < waterHeightPos and characterFloatHeight > waterHeightFloatThreshold ) then
			-- Buoyancy force formula
			local fluidDensity = 1000
			local displacedVolume = 0.0664
			local buoyancyForce = fluidDensity * displacedVolume * GRAVITY
			local diveDepthScale = 1 - math.max( math.min( ( characterFloatHeight - waterHeightFloatThreshold ) / ( waterHeightPos - waterHeightFloatThreshold ) , 1.0 ), 0.0 )
			local characterForce = sm.vec3.new( 0, 0, buoyancyForce * diveDepthScale )
			sm.physics.applyImpulse( character, characterForce * 0.025, true )
		end
	end
end

----------------------------------------------------------------------------------------------------

function WaterManager.trigger_onEnterWater( self, trigger, results )

	local ud = trigger:getUserData()
	assert(ud)
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				local triggerMax = trigger:getWorldMax()
				local characterPos = result:getWorldPosition()
				local splashPosition = sm.vec3.new( characterPos.x, characterPos.y, triggerMax.z )

				if not result:isSwimming() then
					PlaySplashEffect( splashPosition, result:getVelocity(), result:getMass() )
				end

				-- Only trigger once per tick
				if self.triggeredCharacters[result.id] == nil then
					self.triggeredCharacters[result.id] = true

					UpdateCharacterInWater( trigger, result )
				end

			elseif type( result ) == "Body" then
        if not self.submergedBodies[result.id] then
          local triggerMax = trigger:getWorldMax()
          local centerPos = result:getCenterOfMassPosition()
          local splashPosition = sm.vec3.new( centerPos.x, centerPos.y, triggerMax.z )
          PlaySplashEffect( splashPosition, result:getVelocity(), result:getMass() )
				end

        self.submergedBodies[result.id] = true
			end
		end
	end
end

function WaterManager.trigger_onExitWater( self, trigger, results )

	local ud = trigger:getUserData()
	assert(ud)
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				if sm.isHost then
					if result:isSwimming() then
						result:setSwimming( false )
					end
					if result:isDiving() then
						result:setDiving( false )
					end

					if sm.isHost then
						if result.publicData then
							result.publicData.waterMovementSpeedFraction = 1.0
						end
					else
						if result.clientPublicData then
							result.clientPublicData.waterMovementSpeedFraction = 1.0
						end
					end
				end
      elseif type(result) == "Body" then
        self.submergedBodies[result.id] = false
			end
		end
	end
end

function WaterManager.trigger_onStayWater( self, trigger, results )

	local ud = trigger:getUserData()
	assert(ud)
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then

				-- Only trigger once per tick
				if self.triggeredCharacters[result.id] == nil then
					self.triggeredCharacters[result.id] = true

					UpdateCharacterInWater( trigger, result )
				end
			end
		end
	end

end

function WaterManager.trigger_onProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )

	sm.effect.playEffect( "Projectile - HitWater", hitPos )
	return false
end
