local Auction = require("auction")
local Gui = require("gui")

local function parse_number(value)
  local num = tonumber(value)
  if not num then
    return nil
  end
  return math.floor(num)
end

local function list_auctions(player)
  Auction.ensure_global()
  local count = 0
  for _, auction in pairs(global.auctions) do
    count = count + 1
    player.print(Auction.format_auction(auction))
  end
  if count == 0 then
    player.print("Активных аукционов нет.")
  end
end

commands.add_command("auction-create", "Создать аукцион: /auction-create item count start_price [buyout] [duration_minutes]", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end

  local args = {}
  for token in string.gmatch(event.parameter or "", "%S+") do
    table.insert(args, token)
  end

  if #args < 3 then
    player.print("Пример: /auction-create iron-plate 100 50 200 60")
    return
  end

  local item_name = args[1]
  local item_count = parse_number(args[2])
  local start_price = parse_number(args[3])
  local buyout_price = args[4] and parse_number(args[4]) or nil
  local duration_minutes = args[5] and parse_number(args[5]) or 60

  if not item_count or not start_price then
    player.print("Количество и цена должны быть числами.")
    return
  end

  local ok, message = Auction.create(player, item_name, item_count, start_price, buyout_price, duration_minutes)
  player.print(message)
end)

commands.add_command("auction-bid", "Сделать ставку: /auction-bid id amount", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end

  local args = {}
  for token in string.gmatch(event.parameter or "", "%S+") do
    table.insert(args, token)
  end

  if #args < 2 then
    player.print("Пример: /auction-bid 1 75")
    return
  end

  local auction_id = parse_number(args[1])
  local bid_amount = parse_number(args[2])

  if not auction_id or not bid_amount then
    player.print("ID и ставка должны быть числами.")
    return
  end

  local ok, message = Auction.place_bid(player, auction_id, bid_amount)
  player.print(message)
end)

commands.add_command("auction-buyout", "Выкупить: /auction-buyout id", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end

  local auction_id = parse_number(event.parameter)
  if not auction_id then
    player.print("Пример: /auction-buyout 1")
    return
  end

  local ok, message = Auction.buyout(player, auction_id)
  player.print(message)
end)

commands.add_command("auction-cancel", "Отменить аукцион: /auction-cancel id", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end

  local auction_id = parse_number(event.parameter)
  if not auction_id then
    player.print("Пример: /auction-cancel 1")
    return
  end

  local ok, message = Auction.cancel(player, auction_id)
  player.print(message)
end)

commands.add_command("auction-list", "Показать аукционы", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  list_auctions(player)
end)

commands.add_command("auction-gui", "Открыть окно аукциона", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  Gui.ensure(player)
end)

commands.add_command("auction-avatar", "Установить аватар: /auction-avatar <item|entity|signal>", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end

  local sprite = Gui.resolve_avatar_sprite(event.parameter)
  if not sprite then
    player.print("Не удалось распознать аватар. Укажите имя предмета, сущности или сигнала.")
    return
  end

  local data = Auction.ensure_player_data(player)
  data.avatar_sprite = sprite
  Gui.refresh_if_open(player)
  player.print("Аватар обновлён.")
end)

commands.add_command("auction-friend-add", "Добавить друга: /auction-friend-add <player>", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  local target_name = event.parameter
  if not target_name or target_name == "" then
    player.print("Укажите имя игрока.")
    return
  end
  local target = game.get_player(target_name)
  if not target then
    player.print("Игрок не найден.")
    return
  end
  if target.index == player.index then
    player.print("Нельзя добавить самого себя.")
    return
  end
  local data = Auction.ensure_player_data(player)
  for _, friend_index in ipairs(data.friends) do
    if friend_index == target.index then
      player.print("Этот игрок уже в друзьях.")
      return
    end
  end
  table.insert(data.friends, target.index)
  Gui.refresh_if_open(player)
  player.print("Друг добавлен.")
end)

commands.add_command("auction-friend-remove", "Удалить друга: /auction-friend-remove <player>", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  local target_name = event.parameter
  if not target_name or target_name == "" then
    player.print("Укажите имя игрока.")
    return
  end
  local target = game.get_player(target_name)
  if not target then
    player.print("Игрок не найден.")
    return
  end
  local data = Auction.ensure_player_data(player)
  for index, friend_index in ipairs(data.friends) do
    if friend_index == target.index then
      table.remove(data.friends, index)
      Gui.refresh_if_open(player)
      player.print("Друг удалён.")
      return
    end
  end
  player.print("Игрок не найден в списке друзей.")
end)

commands.add_command("auction-guild-set", "Установить гильдию: /auction-guild-set <name>", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  local guild_name = event.parameter
  if not guild_name or guild_name == "" then
    player.print("Укажите название гильдии.")
    return
  end
  local data = Auction.ensure_player_data(player)
  data.guild = guild_name
  Gui.refresh_if_open(player)
  player.print("Гильдия обновлена.")
end)

commands.add_command("auction-guild-clear", "Сбросить гильдию", function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  local data = Auction.ensure_player_data(player)
  data.guild = nil
  Gui.refresh_if_open(player)
  player.print("Гильдия сброшена.")
end)

script.on_init(function()
  Auction.ensure_global()
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  Auction.ensure_player_data(player)
  Gui.ensure(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  Gui.handle_click(event)
end)

script.on_nth_tick(60, function()
  Auction.ensure_global()
  for auction_id, auction in pairs(global.auctions) do
    if auction.ends_at <= game.tick then
      Auction.finish(auction_id)
    end
  end
end)

script.on_nth_tick(Auction.TICKS_PER_MINUTE, function()
  for _, player in pairs(game.connected_players) do
    Gui.refresh_if_open(player)
  end
end)
