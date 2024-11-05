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

function ClientGameManager.onCreatePlayer(self)
  if g_hud then
    g_hud:setText("Coin Text", ""..self.coins)
  end
end

function ClientGameManager.syncData(self, data)
  self.coins = data.coins
  self.offer = data.offer
  self.shopProgress = data.shopProgress

  if g_hud then
    g_hud:setText("Coin Text", ""..self.coins)
  end

  g_clientShopManager:refreshShopBuyButton()
  g_clientRewardManager:refresh(self.offer)
end
