ClientRewardManager = class(nil)

function ClientRewardManager:onCreate()
  self.offers = sm.json.open("$CONTENT_DATA/rewards.json")
  self.rewardGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/reward_real.layout", false, {
    isHud = false,
    isInteractive = true,
    needsCursor = true,
    hidesHotbar = false,
    isOverlapped = false,
    backgroundAlpha = 0.0,
  })

  self.rewardGui:setButtonCallback("TreasureButton", "client_takeTreasure")
  self.rewardGui:setButtonCallback("OfferButton", "client_takeOffer")

  self.rewardGui:setButtonCallback("ExitButton", "client_closeRewards")
end

-- Call when current offer changes to set the correct button and dialog images
function ClientRewardManager:refresh(offer)
  if offer > #self.offers then
    self.rewardGui:setColor("NoOfferDialog", sm.color.new(1, 1, 1, 1))
    self.rewardGui:setImage("OfferImage", "$CONTENT_DATA/Gui/Textures/offer_button_disabled.png")
  else
    self.rewardGui:setColor("NoOfferDialog", sm.color.new(1, 1, 1, 0))
    self.rewardGui:setImage("OfferImage", "$CONTENT_DATA/Gui/Textures/offer_button_"..offer..".png")
  end
end

function ClientRewardManager:openGui()
  local character = sm.localPlayer.getPlayer():getCharacter()
  sm.event.sendToWorld(character:getWorld(), "client_playsound", {position = character:getWorldPosition(), name = "GUI Backpack opened"})
  self.rewardGui:open()
end

function ClientRewardManager:closeGui()
  self.rewardGui:close()
end
