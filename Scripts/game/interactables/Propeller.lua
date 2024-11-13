Propeller = class(nil)

function Propeller:server_onCreate()
  if not self.areaTrigger then
    local size = sm.vec3.new(3, 1, 3) / 8
    local filter = sm.areaTrigger.filter.areaTrigger
    self.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, sm.vec3.new(0, 0, 0), sm.quat.identity(), filter)
  end
end

function Propeller:server_onFixedUpdate()
  local shape = self.interactable:getShape()
  local body = shape:getBody()
  local getAngularVelocity = body:getAngularVelocity()

  for _, result in ipairs(self.areaTrigger:getContents()) do
    if sm.exists( result ) then
      if type( result ) == "AreaTrigger" then
        local userData = result:getUserData()
        if userData and userData.water then
          local force = -(sm.quat.inverse(shape:getWorldRotation()) * getAngularVelocity).y * self.data.force

          sm.physics.applyImpulse(shape, shape:getZAxis() * force)
          return
        end
      end
    end
  end

  sm.physics.applyTorque(body, getAngularVelocity / -3)
end
