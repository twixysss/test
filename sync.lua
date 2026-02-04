local Auction = require("auction")

local Sync = {}

local INTERFACE_NAME = "mmo_auction_sync"

local function ensure_token()
  Auction.ensure_global()
  if not global.sync_token then
    global.sync_token = nil
  end
end

local function validate_token(token)
  ensure_token()
  return token and global.sync_token and token == global.sync_token
end

local function resolve_player_index(name)
  if not name or name == "" then
    return nil
  end
  local player = game.get_player(name)
  if player and player.valid then
    return player.index
  end
  return nil
end

local function apply_player_snapshot(player_name, snapshot)
  local player = game.get_player(player_name)
  if not player or not player.valid then
    return
  end
  local data = Auction.ensure_player_data(player)
  if type(snapshot.balance) == "number" then
    data.balance = math.floor(snapshot.balance)
  end
  if type(snapshot.avatar_sprite) == "string" and snapshot.avatar_sprite ~= "" then
    data.avatar_sprite = snapshot.avatar_sprite
  end
  if snapshot.guild ~= nil then
    data.guild = snapshot.guild
  end
  if type(snapshot.friends) == "table" then
    data.friends = snapshot.friends
  end
end

local function apply_auctions_snapshot(auctions)
  Auction.ensure_global()
  global.auctions = {}
  local next_id = 1

  for _, auction in ipairs(auctions) do
    if type(auction) == "table" and auction.item_name and auction.item_count and auction.start_price then
      local item_count = math.floor(auction.item_count)
      local start_price = math.floor(auction.start_price)
      if item_count > 0 and start_price > 0 then
        local seller_index = auction.seller_index
        if not seller_index and auction.seller_name then
          seller_index = resolve_player_index(auction.seller_name)
        end
        local record = {
          id = auction.id or next_id,
          seller_index = seller_index,
          seller_name = auction.seller_name or "",
          item_name = auction.item_name,
          item_count = item_count,
          start_price = start_price,
          buyout_price = auction.buyout_price,
          highest_bid = auction.highest_bid,
          highest_bidder = auction.highest_bidder,
          ends_at = auction.ends_at or (game.tick + Auction.TICKS_PER_MINUTE),
          created_at = auction.created_at or game.tick
        }

        global.auctions[record.id] = record
        if record.id >= next_id then
          next_id = record.id + 1
        end
      end
    end
  end

  global.next_auction_id = next_id
end

function Sync.register()
  if remote.interfaces[INTERFACE_NAME] then
    return
  end

  remote.add_interface(INTERFACE_NAME, {
    set_token = function(token)
      ensure_token()
      global.sync_token = token
      return true
    end,
    push_snapshot = function(token, payload)
      if not validate_token(token) then
        return false
      end
      if not payload or type(payload) ~= "table" then
        return false
      end
      if payload.auctions then
        apply_auctions_snapshot(payload.auctions)
      end
      if payload.players then
        for player_name, snapshot in pairs(payload.players) do
          apply_player_snapshot(player_name, snapshot)
        end
      end
      return true
    end,
    push_auctions = function(token, auctions)
      if not validate_token(token) then
        return false
      end
      if not auctions or type(auctions) ~= "table" then
        return false
      end
      apply_auctions_snapshot(auctions)
      return true
    end,
    push_player = function(token, player_name, snapshot)
      if not validate_token(token) then
        return false
      end
      if not player_name or type(snapshot) ~= "table" then
        return false
      end
      apply_player_snapshot(player_name, snapshot)
      return true
    end
  })
end

return Sync
