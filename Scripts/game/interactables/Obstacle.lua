Obstacle = class(nil)

function Obstacle.server_onCollision(self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal)
	if type(other) == "Shape" and sm.exists(other) then
    other:destroyBlock(other:getClosestBlockLocalPosition(collisionPosition), sm.vec3.new(self.data.sizeX, self.data.sizeY, self.data.sizeZ))
    self.shape:destroyShape()
	end
end
