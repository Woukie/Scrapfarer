ClientDangerManager = class(nil)

-- Danger refers to the ui responsible for reverting and deleting builds
function ClientDangerManager:onCreate()
  self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/danger_real.layout", false, {
    isHud = false,
    isInteractive = true,
    needsCursor = true,
    hidesHotbar = false,
    isOverlapped = false,
    backgroundAlpha = 0.0,
  })

  self.gui:setButtonCallback("RevertButton", "client_revertBuild")
  self.gui:setButtonCallback("DeleteButton", "client_deleteBuild")
  self.gui:setButtonCallback("ExitButton", "client_closeDangerScreen")
end

function ClientDangerManager:openGui()
  self.gui:open()
end

function ClientDangerManager:closeGui()
  self.gui:close()
end
