dofile("$CONTENT_DATA/Scripts/game/util/Random.lua")

Obstacle = class(nil)

function Obstacle:client_onCreate()
  if self.data.uvFrames then
    self.frame = 0
  end
end

function Obstacle:server_onCollision(other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal)
  if not self.health then
    self.health = self.data.health
  end

	if type(other) == "Shape" and sm.exists(other) then
    if tostring(other:getShapeUuid()) == tostring(self.shape:getShapeUuid()) then
      return
    end

    local damage = math.floor(RandomNormal(self.data.damageMean, self.data.damageRange))
    if damage > 0 then
      if other.isBlock then
        other:destroyBlock(other:getClosestBlockLocalPosition(collisionPosition), sm.vec3.one(), damage)
      else
        other:destroyShape(damage)
      end
    end

    if self.data.damageEffect then
      sm.effect.playEffect(self.data.damageEffect, self.shape.worldPosition, sm.vec3.new(0, 0, 0), self.shape.worldRotation)
    end

    self.health = self.health - 1
    if self.health <= 0 then
      self:destroy()
    end
  elseif type(other) == "Character" then
    sm.event.sendToPlayer(other:getPlayer(), "server_tumble")
	end
end

function Obstacle:destroy()
  if self.data.destroyEffect then
    sm.effect.playEffect(self.data.destroyEffect, self.shape.worldPosition, sm.vec3.new(0, 0, 0), self.shape.worldRotation)
  end

  self.shape:destroyShape()
end

function Obstacle:client_onUpdate(dt)
  if self.data.uvFrames then
    self.frame = self.frame + dt * (self.data.uvSpeed or 1)
    if self.frame > self.data.uvFrames then
      self.frame = self.frame - self.data.uvFrames
    end
    self.interactable:setUvFrameIndex(math.floor(self.frame))
  end
end