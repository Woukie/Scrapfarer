Propeller = class(nil)

function Propeller:server_onCreate()
  if not self.areaTrigger then
    local size = sm.vec3.new(3, 1, 3) / 8
    local filter = sm.areaTrigger.filter.areaTrigger
    self.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, sm.vec3.new(0, 0, 0), sm.quat.identity(), filter)
  end
end

function Propeller:server_onFixedUpdate()
  for _, result in ipairs(self.areaTrigger:getContents()) do
    if sm.exists( result ) then
      if type( result ) == "AreaTrigger" then
        local userData = result:getUserData()
        if userData and userData.water then
          local shape = self.interactable:getShape()
          local body = shape:getBody()
          local angularVelocity = (sm.quat.inverse(shape:getWorldRotation()) * body:getAngularVelocity()).y
          local force = angularVelocity * self.data.force
          sm.physics.applyImpulse(shape, sm.vec3.new(0, 1, 0) * force)

          local resistance = body:getAngularVelocity() / -2
          resistance = sm.vec3.new(
            math.min(20, math.max(-20, resistance.x)),
            math.min(20, math.max(-20, resistance.y)),
            math.min(20, math.max(-20, resistance.z))
          )
          sm.physics.applyTorque(body, resistance, true)
          break
        end
      end
    end
  end
end
