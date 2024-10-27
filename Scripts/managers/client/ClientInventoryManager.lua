ClientInventoryManager = class(nil)

local function reloadShopGrid(self)
  self.shopGui:clearGrid("CatalogueGrid")

  local i = 0
  for _, item in ipairs(self.shopItems) do
    if self.category == "All" or self.category == item.category then
      self.shopGui:setGridItem("CatalogueGrid", i, {quantity = item.quantity, itemId = item.itemId})
      i = i + 1
    end
  end

  for j = i, #self.shopItems, 1 do
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

function ClientInventoryManager:onCreate()
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

  reloadShopGrid(self)
end

function ClientInventoryManager:selectShopCategory(category)
  self.category = category
  reloadShopGrid(self)
end

function ClientInventoryManager:selectShopItem(uuid)
  self.shopGui:setIconImage("ItemImage", sm.uuid.new("8216e887-8758-48b4-afa1-eea78cbbc3b0"))
end

function ClientInventoryManager:openShop()
  self.shopGui:open()
end

function ClientInventoryManager:closeShop()
  self.shopGui:close()
end
