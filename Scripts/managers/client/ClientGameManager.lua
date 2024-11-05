-- Keeps track of game state for each player
ClientGameManager = class(nil)

function ClientGameManager.onCreate(self)
  self.coins = 0
  self.offer = 1
  self.shopProgress = {}
end

function ClientGameManager:getCoins()
  return self.coins
end

function ClientGameManager:getShopProgress()
  return self.shopProgress
end

function ClientGameManager.onCreatePlayer(self)
  if g_hud then
    g_hud:setText("Coin Text", ""..self.coins)
  end
end

function ClientGameManager.syncData(self, data)
  self.coins = data.coins
  self.offer = data.offer

  local shopProgressChanged = false
  if not (self.shopProgress == data.shopProgress) then
    shopProgressChanged = true
  end

  self.shopProgress = data.shopProgress

  if shopProgressChanged then
    local selectedItem = g_clientShopManager:getSelectedItem()
    if selectedItem and data.shopProgress[selectedItem.name] == false then
      g_clientShopManager:selectShopItem(nil)
    end

    g_clientShopManager:reloadShopGrid()
  end

  if g_hud then
    g_hud:setText("Coin Text", ""..self.coins)
  end

  g_clientShopManager:refreshShopBuyButton()
  g_clientRewardManager:refresh(self.offer)
end
