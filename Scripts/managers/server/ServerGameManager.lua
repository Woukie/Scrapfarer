dofile("$CONTENT_DATA/Scripts/game/tools.lua")
dofile("$CONTENT_DATA/Scripts/game/shapes.lua")
dofile("$CONTENT_DATA/Scripts/game/util/Queue.lua")

-- Keeps track of game state for each player, also handles inventory
ServerGameManager = class(nil)

function ServerGameManager.onCreate(self)
  self.gameStates = {}
  self.sendToClientQueue = Queue()
  self.shopItems = sm.json.open("$CONTENT_DATA/shop.json")
end

-- Would have been easier to index shop items by name but we're already this far lol
local function getShopItem(self, name)
  for _, item in ipairs(self.shopItems) do
    if item.name == name then
      return item
    end
  end
end

local function loadPlayer(self, player)
  local playerId = player:getId()
  local playerData = sm.storage.load(playerId)

  if playerData then
    assert(playerData.coins)
    assert(playerData.inventory)
    assert(playerData.offer)
    assert(playerData.shopProgress)
    self.gameStates[playerId].coins = playerData.coins
    self.gameStates[playerId].inventory = playerData.inventory
    self.gameStates[playerId].offer = playerData.offer
    self.gameStates[playerId].shopProgress = playerData.shopProgress
    print("Loaded "..player.name.."'s player data from storage")
    return true
  end

  return false
end

local function syncPlayer(self, player)
  local playerId = player:getId()
  local gameState = self.gameStates[playerId]

  self.sendToClientQueue:push({client = player, callback = "client_syncGameData", data = {coins = gameState.coins, offer = gameState.offer, shopProgress = gameState.shopProgress}})
end

local function savePlayer(self, player)
  local playerId = player:getId()
  local gameState = self.gameStates[playerId]
  sm.storage.save(playerId, {coins = gameState.coins, inventory = gameState.inventory, offer = gameState.offer, shopProgress = gameState.shopProgress})
  syncPlayer(self, player)
  print("Saved "..player.name.."'s player data to storage")
end

function ServerGameManager:deleteBuild(player)
  if self.gameStates[player:getId()]["playing"] then
    print(player.name.." cannot delete their build as they are in a run")
    return
  end

  g_serverPlotManager:wipeBuild(player)
end

function ServerGameManager:revertBuild(player)
  if self.gameStates[player:getId()]["playing"] then
    print(player.name.." cannot revert their build as they are in a run")
    return
  end

  g_serverPlotManager:loadBuild(player, true)
end

function ServerGameManager:saveBuild(player)
  if self.gameStates[player:getId()]["playing"] then
    print(player.name.." cannot save as they are in a run")
    return
  end

  player:removeLift()
  g_serverPlotManager:saveBuild(player)
  self:recalculateInventory(player)
end

function ServerGameManager:takeOffer(player)
  local offers = sm.json.open("$CONTENT_DATA/rewards.json")
  local playerId = player:getId()
  local gameState = self.gameStates[playerId]
  local offer = offers[gameState.offer]

  if not offer then
    return
  end

  gameState.inventory[offer.itemId] = (gameState.inventory[offer.itemId] or 0) + offer.quantity
  gameState.offer = gameState.offer + 1

  savePlayer(self, player)

  sm.container.beginTransaction()
  sm.container.collect(player:getInventory(), sm.uuid.new(offer.itemId), offer.quantity)
  sm.container.endTransaction()

  self:stopRun(player)
end

function ServerGameManager:takeTreasure(player)
  local gameState = self.gameStates[player:getId()]
  gameState.coins = gameState.coins + 100


  gameState.inventory["5654e554-c373-470a-bf22-0bf39a2bdff9"] = (gameState.inventory["5654e554-c373-470a-bf22-0bf39a2bdff9"] or 0) + 1
  gameState.offer = gameState.offer + 1

  sm.container.beginTransaction()
  sm.container.collect(player:getInventory(), sm.uuid.new("5654e554-c373-470a-bf22-0bf39a2bdff9"), 1)
  sm.container.endTransaction()

  savePlayer(self, player)

  self:stopRun(player)
end

function ServerGameManager.onPlayerJoined(self, player)
  local playerId = player:getId()

  self.gameStates[playerId] = {
    playing = false,
    checkpoints = {},
    coins = 0,
    offer = 1,
    shopProgress = {},
    inventory = {}
  }

  self.gameStates[playerId].inventory[tostring(obj_doughnut)] = 1

  if not loadPlayer(self, player) then
    savePlayer(self, player)
  end

  local inventory = player:getInventory()
  local liftCount = sm.container.totalQuantity(inventory, tool_lift)
  if liftCount == 0 then
    sm.container.beginTransaction()
    sm.container.collect(inventory, tool_lift, 1)
    sm.container.endTransaction()
  end

  if g_serverPlotManager:respawnPlayer(player) then
    sm.event.sendToGame("loadPlotWhenReady", player)
  end

  syncPlayer(self, player)
end

function ServerGameManager.onPlayerLeft(self, player)
  self.gameStates[player:getId()] = nil
end

function ServerGameManager:buyItem(player, name)
  local gameState = self.gameStates[player:getId()]
  local item = getShopItem(self, name)

  if gameState.coins < item.cost then
    return
  end

  local unlocked = gameState.shopProgress[name]
  -- If player has not unlocked it or if we have explicitly stated that it's locked now
  if (item.requireUnlock and not unlocked) or unlocked == false then
    return
  end

  gameState.coins = gameState.coins - item.cost
  if not gameState.inventory[item.itemId] then
    gameState.inventory[item.itemId] = item.quantity
  else
    gameState.inventory[item.itemId] = gameState.inventory[item.itemId] + item.quantity
  end

  if item.lockOnBuy then
    gameState.shopProgress[name] = false
  end

  savePlayer(self, player)

  sm.container.beginTransaction()
  sm.container.collect(player:getInventory(), sm.uuid.new(item.itemId), item.quantity)
  sm.container.endTransaction()
end

function ServerGameManager:lockShopItem(player, name)
  local gameState = self.gameStates[player:getId()]
  gameState.shopProgress[name] = false

  savePlayer(self, player)
end

function ServerGameManager:unlockShopItem(player, name)
  local gameState = self.gameStates[player:getId()]
  gameState.shopProgress[name] = true

  savePlayer(self, player)
end

function ServerGameManager:unlockShopItems(player, items)
  local gameState = self.gameStates[player:getId()]
  local changed = false
  for _, name in ipairs(items) do
    if not gameState.shopProgress[name] then
      gameState.shopProgress[name] = true
      changed = true
    end
  end

  if changed then
    savePlayer(self, player)
  end
end

function ServerGameManager:disableInventory(player)
  player:getInventory():setAllowCollect(false)
  player:getInventory():setAllowSpend(false)
end

function ServerGameManager:enableInventory(player)
  player:getInventory():setAllowCollect(true)
  player:getInventory():setAllowSpend(true)
end

-- Modifies the players inventory to match their saved inventory minus their currently loaded build
-- Prefer modifying inventory directly as this is costly (e.g when buying things, transfer items and update saved data)
function ServerGameManager:recalculateInventory(player)
  local playerId = player:getId()
  local gameState = self.gameStates[playerId]

  local initial = gameState.inventory
  local buildCost = g_serverPlotManager:getBuildCost(player)
  local final = {}

  for id, quantity in pairs(initial) do
    if buildCost[id] then
      final[id] = quantity - buildCost[id]
    else
      final[id] = quantity
    end
  end

  -- Update final as the difference between the target and current inventory
  local inventory = player:getInventory()

  for i = 1, inventory:getSize() + 10, 1 do
    local item = inventory:getItem(i)
    if item then
      local id = tostring(item.uuid)
      if final[id] then
        final[id] = final[id] - item.quantity
      end
    end
  end

  -- Update inventory with changes
  sm.container.beginTransaction()
  for id, quantity in pairs(final) do
    if quantity > 0 then
      sm.container.collect(inventory, sm.uuid.new(id), quantity)
    elseif quantity < 0 then
      sm.container.spend(inventory, sm.uuid.new(id), -quantity)
    end
  end
  sm.container.endTransaction()
end

function ServerGameManager.startRun(self, player)
  if self.gameStates[player:getId()]["playing"] then
    print(player.name.." cannot start their run as they are already in one")
    return false
  end

  print(player.name.." is starting a run")
  player:removeLift()
  g_serverPlotManager:exitBuildMode(player)

  self.gameStates[player:getId()]["playing"] = true
  return true
end

function ServerGameManager.stopRun(self, player)
  local gamestate = self.gameStates[player:getId()]
  if not gamestate["playing"] then
    print(player.name.." cannot stop their run as they are not in one")
    return false
  end

  local totalReward = 0
  for _, reward in pairs(gamestate["checkpoints"]) do
    totalReward = totalReward + reward
  end
  print(player.name.." ended their run earning "..totalReward.." coins")
  gamestate.coins = gamestate.coins + totalReward

  gamestate["playing"] = false
  gamestate["checkpoints"] = {}
  g_serverPlotManager:respawnPlayer(player)
  g_serverPlotManager:loadBuild(player, true)
  sm.event.sendToPlayer(player, "server_stopTumble")

  savePlayer(self, player)
  return true
end

function ServerGameManager.passCheckpoint(self, player, checkpointId, reward)
  local gameState = self.gameStates[player:getId()]
  if not gameState["playing"] then
    return
  end

  if gameState["checkpoints"][checkpointId] then
    return
  end

  gameState["checkpoints"][checkpointId] = reward
  print(player.name.." passed checkpoint "..checkpointId.." valued at "..reward.." coins")
end

function ServerGameManager.onFixedUpdate(self, worldSelf)
  if (not self.sendToClientQueue) then
    return
  end

  while self.sendToClientQueue:size() > 0 do
    local request = self.sendToClientQueue:pop()
    worldSelf.network:sendToClient(request.client, request.callback, request.data)
  end
end
