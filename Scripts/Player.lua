dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )

Player = class( nil )

function Player.server_onCreate( self )
	print("Player.server_onCreate")
  self.sv = {}
  self.sv.waterDamageCooldown = 0
  self.sv.stats = {
    hp = 100, maxhp = 100,
  }
  self.network:setClientData(self.sv.stats)
end

function Player.server_onFixedUpdate( self, dt )
  local character = self.player:getCharacter()
  self.sv.waterDamageCooldown = math.max(self.sv.waterDamageCooldown - 1, 0)

  if character and character:isSwimming() and self.sv.waterDamageCooldown == 0 then
    self.sv.waterDamageCooldown = 45
    self:server_takeDamage(10)
  end

  self.sv.stats.hp = math.min(self.sv.stats.hp + 0.03, self.sv.stats.maxhp)
  self.network:setClientData(self.sv.stats)
end

function Player.server_takeDamage( self, damage, source )
	if damage <= 0 then
    return
  end

  local character = self.player:getCharacter()
  local lockingInteractable = character:getLockingInteractable()
  if lockingInteractable and lockingInteractable:hasSeat() then
    lockingInteractable:setSeatCharacter(character)
  end

  self.sv.stats.hp = math.max(self.sv.stats.hp - damage, 0)

  if self.sv.stats.hp <= 0 then
    g_serverGameManager:endRun(self.player)
    self.sv.stats.hp = self.sv.stats.maxhp
  end

  self.storage:save(self.sv.stats)
  self.network:setClientData(self.sv.stats)
end

function Player.client_onCreate( self )
	self.cl = self.cl or {}

  g_hud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Hud.layout", false, {
    isHud = true,
    isInteractive = false,
    needsCursor = false,
    hidesHotbar = false,
    isOverlapped = false,
    backgroundAlpha = 0.0,
  })

	if self.player == sm.localPlayer.getPlayer() then
		if g_hud then
			g_hud:open()
		end
	end
end

function Player.client_onFixedUpdate(self)
  if not self.cl.lastThrob then
    self.cl.throbDuration = 10
    self.cl.lastThrob = self.cl.throbDuration
  end

  self.cl.lastThrob = math.min( self.cl.lastThrob + 1, self.cl.throbDuration)

  if g_hud then
    local alpha = self.cl.lastThrob / self.cl.throbDuration
    alpha = math.sin((math.pi * alpha) / 2)
    g_hud:setColor("Throb", sm.color.new(1, 1, 1, 1 - self.cl.lastThrob / self.cl.throbDuration))
  end
end

function Player.client_onClientDataUpdate( self, data )
	if data and sm.localPlayer.getPlayer() == self.player then
    if self.cl.stats and data.hp < self.cl.stats.hp then
      self.cl.lastThrob = 0
    end

    self.cl.stats = data

		if g_hud then
      g_hud:setColor("Health", sm.color.new(1, 1, 1, 1 - data.hp / data.maxhp))
		end
	end
end
