ClientRewardManager = class(nil)

function ClientRewardManager:onCreate()
  self.category = "All"
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
  else
    self.rewardGui:setColor("NoOfferDialog", sm.color.new(1, 1, 1, 0))
  end

  self.rewardGui:setImage("OfferImage", "$CONTENT_DATA/Gui/Textures/offer_button_"..offer..".png")
end

function ClientRewardManager:openGui()
  self.rewardGui:open()
end

function ClientRewardManager:closeGui()
  self.rewardGui:close()
end
