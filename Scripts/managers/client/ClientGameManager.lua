-- Keeps track of game state for each player
ClientGameManager = class(nil)

function ClientGameManager.onCreate(self)
  self.coins = 0
end

function ClientGameManager.earnCoins(self, coins)
  self.coins = self.coins + coins

  print(self.coins)
end
