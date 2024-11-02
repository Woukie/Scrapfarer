Obstacle = class(nil)

function Obstacle.server_onCollision(self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal)
  if not self.health then
    self.health = self.data.health
  end

	if type(other) == "Shape" and sm.exists(other) then
    if tostring(other:getShapeUuid()) == tostring(self.shape:getShapeUuid()) then
      return
    end

    local damage = math.random(self.data.attackLevelMin, self.data.attackLevelMax)
    if other.isBlock then
      other:destroyBlock(other:getClosestBlockLocalPosition(collisionPosition), sm.vec3.one(), damage)
    else
      other:destroyShape(damage)
    end

    if self.damageEffect then
      sm.effect.playEffect(self.damageEffect, self.shape.worldPosition, sm.vec3.new( 0, 0, 0 ), self.shape.worldRotation)
    end

    self.health = self.health - 1
    if self.health <= 0 then
      if self.destroyEffect then
        sm.effect.playEffect(self.destroyEffect, self.shape.worldPosition, sm.vec3.new( 0, 0, 0 ), self.shape.worldRotation)
      end
      self.shape:destroyShape()
    end
  elseif type(other) == "Character" then
    sm.event.sendToPlayer(other:getPlayer(), "server_tumble")
	end
end
