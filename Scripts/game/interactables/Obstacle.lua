Obstacle = class(nil)

function Obstacle.server_onCollision(self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal)

	if type(other) == "Shape" and sm.exists(other) then
    other:destroyShape()
    self.shape:destroyShape()
	end
end
