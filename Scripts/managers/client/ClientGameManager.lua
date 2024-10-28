-- Keeps track of game state for each player
ClientGameManager = class(nil)

function ClientGameManager.onCreate(self)
  self.coins = 0
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

  if g_hud then
    g_hud:setText("Coin Text", ""..self.coins)
  end

  g_clientInventoryManager:refreshShopBuyButton()
end
