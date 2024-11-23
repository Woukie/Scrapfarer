ClientShopManager = class(nil)

function ClientShopManager:reloadShopGrid()
  local i = 0
  local progress = g_clientGameManager:getShopProgress()
  for _, item in ipairs(self.shopItems) do
    if self.category == "All" or self.category == item.category then
      local unlocked = progress[item.name]
      local display = true

      -- Unlocked can be nil so we must use "== false"
      if (item.requireUnlock and not unlocked) or unlocked == false then
        display = false
      end

      if display then
        self.shopGui:setGridItem("CatalogueGrid", i, item)
        i = i + 1
      end
    end
  end

  for j = i, #self.shopItems - 1, 1 do
    self.shopGui:setGridItem("CatalogueGrid", j, nil)
  end

  self.shopGui:setImage("AllImage", "$CONTENT_DATA/Gui/Textures/all_button.png")
  self.shopGui:setImage("FloatImage", "$CONTENT_DATA/Gui/Textures/float_button.png")
  self.shopGui:setImage("ProtectImage", "$CONTENT_DATA/Gui/Textures/protect_button.png")
  self.shopGui:setImage("BalanceImage", "$CONTENT_DATA/Gui/Textures/balance_button.png")
  self.shopGui:setImage("PartsImage", "$CONTENT_DATA/Gui/Textures/parts_button.png")

  self.shopGui:setImage(self.category.."Image", "$CONTENT_DATA/Gui/Textures/"..self.category:lower().."_button_active.png")
end

function ClientShopManager:onCreate()
  self.category = "All"
  self.notificationTick = 0
  self.notifications = {}
  self.shopItems = sm.json.open("$CONTENT_DATA/shop.json")
  self.selectedShopItem = nil
  self.shopGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/shop_real.layout", false, {
    isHud = false,
    isInteractive = true,
    needsCursor = true,
    hidesHotbar = false,
    isOverlapped = false,
    backgroundAlpha = 0.0,
  })

  self.notificationGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/unlock_notification_real.layout", false, {
    isHud = true,
    isInteractive = false,
    needsCursor = false,
    hidesHotbar = false,
    isOverlapped = false,
    backgroundAlpha = 0.0,
  })

  self.shopGui:createGridFromJson("CatalogueGrid", {
    type = "materialGrid",
		layout = "$CONTENT_DATA/Gui/Layouts/shop_item.layout",
		itemWidth = 784/16,
		itemHeight = 784/16,
		itemCount = #self.shopItems,
	})

  self.shopGui:setButtonCallback("AllButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("FloatButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("ProtectButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("BalanceButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("PartsButton", "client_setShopCategory")

  self.shopGui:setButtonCallback("BuyButton", "client_buyShopItem")
  self.shopGui:setButtonCallback("ExitButton", "client_closeShop")

  self:reloadShopGrid()

  self.shopGui:setGridButtonCallback("SelectItem", "client_selectShopItem")
end

function ClientShopManager:onUpdate()
  if self.notificationTick <= 0 then
    if #self.notifications > 0 then
      self.notificationTick = 200
      self.notificationGui:setIconImage("Icon", self.notifications[1])
      self.notificationGui:open()
      sm.effect.playEffect("Loot - Logentryactivate", sm.localPlayer.getPlayer():getCharacter():getWorldPosition())
      table.remove(self.notifications, 1)
    else
      self.notificationGui:close()
    end

  else
    self.notificationTick = self.notificationTick - 1
  end
end

function ClientShopManager:showUnlock(itemName)
  self.notificationGui:open()

  local uuid = ""
  for _, shopItem in ipairs(self.shopItems) do
    if itemName == shopItem.name then
      uuid = shopItem.itemId
      break
    end
  end

  table.insert(self.notifications, sm.uuid.new(uuid))
end

function ClientShopManager:selectShopCategory(category)
  self.category = category
  self:reloadShopGrid()
end

function ClientShopManager:selectShopItem(item)
  self.selectedShopItem = item
  self:refreshShopBuyButton()

  if item then
    local itemId = sm.uuid.new(item.itemId)
    self.shopGui:setVisible("ItemImage", true)
    self.shopGui:setIconImage("ItemImage", itemId)
    self.shopGui:setText("ItemName", "x"..item.quantity.." "..sm.shape.getShapeTitle(itemId))
    self.shopGui:setText("ItemDescription", sm.shape.getShapeDescription(itemId))
    self.shopGui:setText("ItemCost", tostring(item.cost))
  else
    self.shopGui:setVisible("ItemImage", false)
    self.shopGui:setText("ItemName", "")
    self.shopGui:setText("ItemDescription", "")
    self.shopGui:setText("ItemCost", "")
  end
end

function ClientShopManager:getSelectedItem()
  return self.selectedShopItem
end

function ClientShopManager:refreshShopBuyButton()
  if not self.selectedShopItem then
    self.shopGui:setImage("BuyImage", "$CONTENT_DATA/Gui/Textures/buy_button_disabled.png")
    return
  end

  local coins = g_clientGameManager:getCoins()
  if self.selectedShopItem and coins and coins >= self.selectedShopItem.cost then
    self.shopGui:setImage("BuyImage", "$CONTENT_DATA/Gui/Textures/buy_button.png")
  else
    self.shopGui:setImage("BuyImage", "$CONTENT_DATA/Gui/Textures/buy_button_disabled.png")
  end
end

function ClientShopManager:openShop()
  local character = sm.localPlayer.getPlayer():getCharacter()
  sm.event.sendToWorld(character:getWorld(), "client_playsound", {position = character:getWorldPosition(), name = "GUI Backpack opened"})
self.shopGui:open()
end

function ClientShopManager:closeShop()
  self.shopGui:close()
end
