ClientShopManager = class(nil)

function ClientShopManager:reloadShopGrid()
  local i = 0
  for _, item in ipairs(self.shopItems) do
    if self.category == "All" or self.category == item.category then
      self.shopGui:setGridItem("CatalogueGrid", i, item)

      i = i + 1
    end
  end

  for j = i, #self.shopItems - 1, 1 do
    self.shopGui:setGridItem("CatalogueGrid", j, nil)
  end

  self.shopGui:setImage("AllImage", "$CONTENT_DATA/Gui/Textures/all_button.png")
  self.shopGui:setImage("BlocksImage", "$CONTENT_DATA/Gui/Textures/blocks_button.png")
  self.shopGui:setImage("FunctionalImage", "$CONTENT_DATA/Gui/Textures/functional_button.png")

  if self.category == "All" then
    self.shopGui:setImage("AllImage", "$CONTENT_DATA/Gui/Textures/all_button_active.png")
  elseif self.category == "Blocks" then
    self.shopGui:setImage("BlocksImage", "$CONTENT_DATA/Gui/Textures/blocks_button_active.png")
  elseif self.category == "Functional" then
    self.shopGui:setImage("FunctionalImage", "$CONTENT_DATA/Gui/Textures/functional_button_active.png")
  end
end

function ClientShopManager:onCreate()
  self.category = "All"
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

  self.shopGui:createGridFromJson("CatalogueGrid", {
    type = "materialGrid",
		layout = "$CONTENT_DATA/Gui/Layouts/shop_item.layout",
		itemWidth = 784/16,
		itemHeight = 784/16,
		itemCount = #self.shopItems,
	})

  self.shopGui:setButtonCallback("AllButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("BlocksButton", "client_setShopCategory")
  self.shopGui:setButtonCallback("FunctionalButton", "client_setShopCategory")

  self.shopGui:setButtonCallback("BuyButton", "client_buyShopItem")
  self.shopGui:setButtonCallback("ExitButton", "client_closeShop")

  self:reloadShopGrid()

  self.shopGui:setGridButtonCallback("SelectItem", "client_selectShopItem")
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
    self.shopGui:setIconImage("ItemImage", itemId)
    self.shopGui:setText("ItemName", "x"..item.quantity.." "..sm.shape.getShapeTitle(itemId))
    self.shopGui:setText("ItemDescription", sm.shape.getShapeDescription(itemId))
    self.shopGui:setText("ItemCost", tostring(item.cost))
  else
    self.shopGui:setImage("ItemImage", "")
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
  self.shopGui:open()
end

function ClientShopManager:closeShop()
  self.shopGui:close()
end
