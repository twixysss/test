local Auction = {}

Auction.TICKS_PER_MINUTE = 60 * 60

function Auction.ensure_global()
  global.auctions = global.auctions or {}
  global.next_auction_id = global.next_auction_id or 1
  global.player_data = global.player_data or {}
end

function Auction.get_player(player_index)
  local player = game.get_player(player_index)
  if not player or not player.valid then
    return nil
  end
  return player
end

function Auction.ensure_player_data(player)
  Auction.ensure_global()
  global.player_data[player.index] = global.player_data[player.index] or {
    balance = 0,
    avatar_sprite = "entity/character",
    friends = {},
    guild = nil
  }
  return global.player_data[player.index]
end

function Auction.get_balance(player)
  local data = Auction.ensure_player_data(player)
  return data.balance
end

function Auction.add_balance(player, amount)
  local data = Auction.ensure_player_data(player)
  data.balance = data.balance + amount
end

function Auction.take_balance(player, amount)
  local data = Auction.ensure_player_data(player)
  if data.balance < amount then
    return false
  end
  data.balance = data.balance - amount
  return true
end

function Auction.has_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  return inventory.get_item_count(name) >= count
end

function Auction.remove_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  local removed = inventory.remove({name = name, count = count})
  return removed == count
end

function Auction.add_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  local inserted = inventory.insert({name = name, count = count})
  return inserted == count
end

function Auction.format_auction(auction)
  local buyout_text = auction.buyout_price and (" buyout:" .. auction.buyout_price) or ""
  local bid_text = auction.highest_bid and (" bid:" .. auction.highest_bid) or ""
  return string.format("#%d %s x%d start:%d%s%s ends:%dm",
    auction.id,
    auction.item_name,
    auction.item_count,
    auction.start_price,
    bid_text,
    buyout_text,
    math.max(0, math.floor((auction.ends_at - game.tick) / Auction.TICKS_PER_MINUTE))
  )
end

function Auction.create(player, item_name, item_count, start_price, buyout_price, duration_minutes)
  Auction.ensure_global()

  if not Auction.has_items(player, item_name, item_count) then
    return false, "Недостаточно предметов для продажи."
  end

  if start_price < 1 then
    return false, "Стартовая цена должна быть больше 0."
  end

  local duration = math.max(1, duration_minutes or 60)

  if not Auction.remove_items(player, item_name, item_count) then
    return false, "Не удалось изъять предметы из инвентаря."
  end

  local auction = {
    id = global.next_auction_id,
    seller_index = player.index,
    seller_name = player.name,
    item_name = item_name,
    item_count = item_count,
    start_price = start_price,
    buyout_price = buyout_price,
    highest_bid = nil,
    highest_bidder = nil,
    ends_at = game.tick + duration * Auction.TICKS_PER_MINUTE,
    created_at = game.tick
  }

  global.auctions[auction.id] = auction
  global.next_auction_id = global.next_auction_id + 1

  return true, string.format("Аукцион создан: %s", Auction.format_auction(auction))
end

function Auction.place_bid(player, auction_id, bid_amount)
  Auction.ensure_global()

  local auction = global.auctions[auction_id]
  if not auction then
    return false, "Аукцион не найден."
  end

  if auction.ends_at <= game.tick then
    return false, "Аукцион уже завершён."
  end

  local min_bid = auction.highest_bid and (auction.highest_bid + 1) or auction.start_price
  if bid_amount < min_bid then
    return false, string.format("Ставка должна быть не меньше %d.", min_bid)
  end

  if not Auction.take_balance(player, bid_amount) then
    return false, "Недостаточно валюты для ставки."
  end

  if auction.highest_bidder then
    local previous_bidder = Auction.get_player(auction.highest_bidder)
    if previous_bidder then
      Auction.add_balance(previous_bidder, auction.highest_bid)
    end
  end

  auction.highest_bid = bid_amount
  auction.highest_bidder = player.index

  return true, string.format("Ставка принята: %s", Auction.format_auction(auction))
end

function Auction.buyout(player, auction_id)
  Auction.ensure_global()

  local auction = global.auctions[auction_id]
  if not auction then
    return false, "Аукцион не найден."
  end

  if auction.ends_at <= game.tick then
    return false, "Аукцион уже завершён."
  end

  if not auction.buyout_price then
    return false, "У этого аукциона нет выкупа."
  end

  if not Auction.take_balance(player, auction.buyout_price) then
    return false, "Недостаточно валюты для выкупа."
  end

  if auction.highest_bidder then
    local previous_bidder = Auction.get_player(auction.highest_bidder)
    if previous_bidder then
      Auction.add_balance(previous_bidder, auction.highest_bid)
    end
  end

  local seller = Auction.get_player(auction.seller_index)
  if seller then
    Auction.add_balance(seller, auction.buyout_price)
  end

  Auction.add_items(player, auction.item_name, auction.item_count)
  global.auctions[auction_id] = nil

  return true, string.format("Выкуп завершён: %s", auction.item_name)
end

function Auction.cancel(player, auction_id)
  Auction.ensure_global()

  local auction = global.auctions[auction_id]
  if not auction then
    return false, "Аукцион не найден."
  end

  if auction.seller_index ~= player.index then
    return false, "Отменить может только продавец."
  end

  if auction.highest_bidder then
    return false, "Нельзя отменить аукцион с текущей ставкой."
  end

  Auction.add_items(player, auction.item_name, auction.item_count)
  global.auctions[auction_id] = nil

  return true, "Аукцион отменён."
end

function Auction.finish(auction_id)
  local auction = global.auctions[auction_id]
  if not auction then
    return
  end

  local seller = Auction.get_player(auction.seller_index)

  if auction.highest_bidder then
    local buyer = Auction.get_player(auction.highest_bidder)
    if buyer then
      Auction.add_items(buyer, auction.item_name, auction.item_count)
    end
    if seller then
      Auction.add_balance(seller, auction.highest_bid)
    end
  else
    if seller then
      Auction.add_items(seller, auction.item_name, auction.item_count)
    end
  end

  global.auctions[auction_id] = nil
end

return Auction
