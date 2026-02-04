local Auction = {}

local TICKS_PER_MINUTE = 60 * 60
local GUI_ROOT = "mmo_auction_root"
local GUI_AUCTION_LIST = "mmo_auction_list"
local GUI_BALANCE_LABEL = "mmo_balance_label"
local GUI_REFRESH_BUTTON = "mmo_refresh_button"
local GUI_NPC_LIST = "mmo_npc_list"
local GUI_NPC_TAB = "mmo_npc_tab"
local GUI_AUCTION_TAB = "mmo_auction_tab"
local GUI_PROFILE_TAB = "mmo_profile_tab"
local GUI_TABS = "mmo_tabs"
local GUI_PROFILE_LIST = "mmo_profile_list"
local GUI_AVATAR_SPRITE = "mmo_avatar_sprite"
local GUI_PROFILE_NAME = "mmo_profile_name"
local GUI_PROFILE_FRIENDS = "mmo_profile_friends"
local GUI_PROFILE_GUILD = "mmo_profile_guild"

local NPC_MERCHANTS = {
  {
    name = "Скупщик Металла",
    buy = {item = "iron-plate", price = 2},
    sell = {item = "iron-plate", price = 8}
  },
  {
    name = "Механический Брокер",
    buy = {item = "copper-plate", price = 2},
    sell = {item = "copper-plate", price = 9}
  },
  {
    name = "Торговец Шестерёнок",
    buy = {item = "iron-gear-wheel", price = 5},
    sell = {item = "iron-gear-wheel", price = 20}
  }
}

local function ensure_global()
  global.auctions = global.auctions or {}
  global.next_auction_id = global.next_auction_id or 1
  global.player_data = global.player_data or {}
end

local function get_player(player_index)
  local player = game.get_player(player_index)
  if not player or not player.valid then
    return nil
  end
  return player
end

local function ensure_player_data(player)
  ensure_global()
  global.player_data[player.index] = global.player_data[player.index] or {
    balance = 0,
    avatar_sprite = "entity/character",
    friends = {},
    guild = nil
  }
  return global.player_data[player.index]
end

local function get_balance(player)
  local data = ensure_player_data(player)
  return data.balance
end

local function add_balance(player, amount)
  local data = ensure_player_data(player)
  data.balance = data.balance + amount
end

local function take_balance(player, amount)
  local data = ensure_player_data(player)
  if data.balance < amount then
    return false
  end
  data.balance = data.balance - amount
  return true
end

local function has_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  return inventory.get_item_count(name) >= count
end

local function remove_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  local removed = inventory.remove({name = name, count = count})
  return removed == count
end

local function add_items(player, name, count)
  local inventory = player.get_main_inventory()
  if not inventory then
    return false
  end
  local inserted = inventory.insert({name = name, count = count})
  return inserted == count
end

local function resolve_avatar_sprite(name)
  if not name or name == "" then
    return nil
  end
  if game.item_prototypes[name] then
    return "item/" .. name
  end
  if game.entity_prototypes[name] then
    return "entity/" .. name
  end
  if game.virtual_signal_prototypes[name] then
    return "virtual-signal/" .. name
  end
  return nil
end

local function format_auction(auction)
  local buyout_text = auction.buyout_price and (" buyout:" .. auction.buyout_price) or ""
  local bid_text = auction.highest_bid and (" bid:" .. auction.highest_bid) or ""
  return string.format("#%d %s x%d start:%d%s%s ends:%dm",
    auction.id,
    auction.item_name,
    auction.item_count,
    auction.start_price,
    bid_text,
    buyout_text,
    math.max(0, math.floor((auction.ends_at - game.tick) / TICKS_PER_MINUTE))
  )
end

function Auction.create(player, item_name, item_count, start_price, buyout_price, duration_minutes)
  ensure_global()

  if not has_items(player, item_name, item_count) then
    return false, "Недостаточно предметов для продажи."
  end

  if start_price < 1 then
    return false, "Стартовая цена должна быть больше 0."
  end

  local duration = math.max(1, duration_minutes or 60)

  if not remove_items(player, item_name, item_count) then
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
    ends_at = game.tick + duration * TICKS_PER_MINUTE,
    created_at = game.tick
  }

  global.auctions[auction.id] = auction
  global.next_auction_id = global.next_auction_id + 1

  return true, string.format("Аукцион создан: %s", format_auction(auction))
end

function Auction.place_bid(player, auction_id, bid_amount)
  ensure_global()

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

  if not take_balance(player, bid_amount) then
    return false, "Недостаточно валюты для ставки."
  end

  if auction.highest_bidder then
    local previous_bidder = get_player(auction.highest_bidder)
    if previous_bidder then
      add_balance(previous_bidder, auction.highest_bid)
    end
  end

  auction.highest_bid = bid_amount
  auction.highest_bidder = player.index

  return true, string.format("Ставка принята: %s", format_auction(auction))
end

function Auction.buyout(player, auction_id)
  ensure_global()

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

  if not take_balance(player, auction.buyout_price) then
    return false, "Недостаточно валюты для выкупа."
  end

  if auction.highest_bidder then
    local previous_bidder = get_player(auction.highest_bidder)
    if previous_bidder then
      add_balance(previous_bidder, auction.highest_bid)
    end
  end

  local seller = get_player(auction.seller_index)
  if seller then
    add_balance(seller, auction.buyout_price)
  end

  add_items(player, auction.item_name, auction.item_count)
  global.auctions[auction_id] = nil

  return true, string.format("Выкуп завершён: %s", auction.item_name)
end

function Auction.cancel(player, auction_id)
  ensure_global()

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

  add_items(player, auction.item_name, auction.item_count)
  global.auctions[auction_id] = nil

  return true, "Аукцион отменён."
end

function Auction.finish(auction_id)
  local auction = global.auctions[auction_id]
  if not auction then
    return
  end

  local seller = get_player(auction.seller_index)

  if auction.highest_bidder then
    local buyer = get_player(auction.highest_bidder)
    if buyer then
      add_items(buyer, auction.item_name, auction.item_count)
    end
    if seller then
      add_balance(seller, auction.highest_bid)
    end
  else
    if seller then
      add_items(seller, auction.item_name, auction.item_count)
    end
  end

  global.auctions[auction_id] = nil
end

local function destroy_gui(player)
  local root = player.gui.screen[GUI_ROOT]
  if root then
    root.destroy()
  end
end

local function create_auction_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "Аукцион", name = GUI_AUCTION_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_auction_frame", direction = "vertical"})
  frame.style.padding = 8

  local header = frame.add({type = "flow", name = "mmo_header", direction = "horizontal"})
  header.add({type = "label", name = GUI_BALANCE_LABEL, caption = "Баланс: 0"})
  header.add({type = "button", name = GUI_REFRESH_BUTTON, caption = "Обновить"})

  frame.add({type = "line"})
  frame.add({type = "label", caption = "Список аукционов:"})
  frame.add({type = "scroll-pane", name = GUI_AUCTION_LIST, direction = "vertical"}).style.maximal_height = 300

  tab_pane.add_tab(tab, frame)
end

local function create_npc_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "NPC", name = GUI_NPC_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_npc_frame", direction = "vertical"})
  frame.style.padding = 8
  frame.add({type = "label", caption = "Торговцы NPC (низкие покупки, высокие продажи):"})
  frame.add({type = "scroll-pane", name = GUI_NPC_LIST, direction = "vertical"}).style.maximal_height = 300
  tab_pane.add_tab(tab, frame)
end

local function create_profile_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "Профиль", name = GUI_PROFILE_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_profile_frame", direction = "vertical"})
  frame.style.padding = 8

  local header = frame.add({type = "flow", direction = "horizontal"})
  header.add({type = "sprite", name = GUI_AVATAR_SPRITE, sprite = "entity/character"})
  header.add({type = "label", name = GUI_PROFILE_NAME, caption = "Игрок"})

  frame.add({type = "label", name = GUI_PROFILE_GUILD, caption = "Гильдия: Нет"})
  frame.add({type = "label", name = GUI_PROFILE_FRIENDS, caption = "Друзья: нет"})
  frame.add({type = "line"})
  frame.add({type = "label", caption = "Ваши лоты на аукционе:"})
  frame.add({type = "scroll-pane", name = GUI_PROFILE_LIST, direction = "vertical"}).style.maximal_height = 300

  tab_pane.add_tab(tab, frame)
end

local function update_balance_label(player)
  local root = player.gui.screen[GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[GUI_TABS]
  if not tabs then
    return
  end
  local auction_frame = tabs["mmo_auction_frame"]
  if not auction_frame then
    return
  end
  local header = auction_frame["mmo_header"]
  if not header then
    return
  end
  local label = header[GUI_BALANCE_LABEL]
  if not label then
    return
  end
  label.caption = string.format("Баланс: %d", get_balance(player))
end

local function populate_auction_list(player)
  local root = player.gui.screen[GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[GUI_TABS]
  if not tabs then
    return
  end
  local auction_frame = tabs["mmo_auction_frame"]
  if not auction_frame then
    return
  end
  local list = auction_frame[GUI_AUCTION_LIST]
  if not list then
    return
  end
  list.clear()

  local count = 0
  for _, auction in pairs(global.auctions) do
    count = count + 1
    list.add({type = "label", caption = format_auction(auction)})
  end

  if count == 0 then
    list.add({type = "label", caption = "Активных аукционов нет."})
  end
end

local function populate_npc_list(player)
  local root = player.gui.screen[GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[GUI_TABS]
  if not tabs then
    return
  end
  local npc_frame = tabs["mmo_npc_frame"]
  if not npc_frame then
    return
  end
  local list = npc_frame[GUI_NPC_LIST]
  if not list then
    return
  end
  list.clear()

  for index, npc in ipairs(NPC_MERCHANTS) do
    local row = list.add({type = "flow", direction = "horizontal"})
    row.add({type = "label", caption = npc.name})
    row.add({type = "label", caption = string.format(" | Покупка: %s (%d)", npc.buy.item, npc.buy.price)})
    row.add({type = "button", name = "npc_sell_" .. index, caption = "Продать"})
    row.add({type = "label", caption = string.format(" | Продажа: %s (%d)", npc.sell.item, npc.sell.price)})
    row.add({type = "button", name = "npc_buy_" .. index, caption = "Купить"})
  end
end

local function populate_profile(player)
  local root = player.gui.screen[GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[GUI_TABS]
  if not tabs then
    return
  end
  local profile_frame = tabs["mmo_profile_frame"]
  if not profile_frame then
    return
  end

  local data = ensure_player_data(player)
  local avatar = profile_frame[GUI_AVATAR_SPRITE]
  if avatar then
    avatar.sprite = data.avatar_sprite or "entity/character"
  end
  local name_label = profile_frame[GUI_PROFILE_NAME]
  if name_label then
    name_label.caption = string.format("Игрок: %s", player.name)
  end
  local guild_label = profile_frame[GUI_PROFILE_GUILD]
  if guild_label then
    guild_label.caption = string.format("Гильдия: %s", data.guild or "Нет")
  end
  local friends_label = profile_frame[GUI_PROFILE_FRIENDS]
  if friends_label then
    local friend_names = {}
    for _, friend_index in ipairs(data.friends) do
      local friend = get_player(friend_index)
      if friend then
        table.insert(friend_names, friend.name)
      end
    end
    if #friend_names == 0 then
      friends_label.caption = "Друзья: нет"
    else
      friends_label.caption = "Друзья: " .. table.concat(friend_names, ", ")
    end
  end

  local list = profile_frame[GUI_PROFILE_LIST]
  if not list then
    return
  end
  list.clear()

  local count = 0
  for _, auction in pairs(global.auctions) do
    if auction.seller_index == player.index then
      count = count + 1
      list.add({type = "label", caption = format_auction(auction)})
    end
  end

  if count == 0 then
    list.add({type = "label", caption = "У вас нет активных лотов."})
  end
end

local function refresh_gui(player)
  update_balance_label(player)
  populate_auction_list(player)
  populate_npc_list(player)
  populate_profile(player)
end

local function ensure_gui(player)
  if player.gui.screen[GUI_ROOT] then
    refresh_gui(player)
    return
  end

  local root = player.gui.screen.add({type = "frame", name = GUI_ROOT, direction = "vertical"})
  root.caption = "MMO Аукцион"
  root.auto_center = true
  root.style.padding = 8

  local tab_pane = root.add({type = "tabbed-pane", name = GUI_TABS})
  create_auction_tab(tab_pane)
  create_npc_tab(tab_pane)
  create_profile_tab(tab_pane)

  refresh_gui(player)
end

local function refresh_gui_if_open(player)
  if player.gui.screen[GUI_ROOT] then
    refresh_gui(player)
  end
end

local function list_auctions(player)
  ensure_global()
  local count = 0
  for _, auction in pairs(global.auctions) do
    count = count + 1
    player.print(format_auction(auction))
  end
  if count == 0 then
    player.print("Активных аукционов нет.")
  end
end

local function parse_number(value)
  local num = tonumber(value)
  if not num then
    return nil
  end
  return math.floor(num)
end

commands.add_command("auction-create", "Создать аукцион: /auction-create item count start_price [buyout] [duration_minutes]", function(event)
  local player = get_player(event.player_index)
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
  local player = get_player(event.player_index)
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
  local player = get_player(event.player_index)
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
  local player = get_player(event.player_index)
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
  local player = get_player(event.player_index)
  if not player then
    return
  end
  list_auctions(player)
end)

commands.add_command("auction-gui", "Открыть окно аукциона", function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end
  ensure_gui(player)
end)

commands.add_command("auction-avatar", "Установить аватар: /auction-avatar <item|entity|signal>", function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end

  local sprite = resolve_avatar_sprite(event.parameter)
  if not sprite then
    player.print("Не удалось распознать аватар. Укажите имя предмета, сущности или сигнала.")
    return
  end

  local data = ensure_player_data(player)
  data.avatar_sprite = sprite
  refresh_gui_if_open(player)
  player.print("Аватар обновлён.")
end)

commands.add_command("auction-friend-add", "Добавить друга: /auction-friend-add <player>", function(event)
  local player = get_player(event.player_index)
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
  local data = ensure_player_data(player)
  for _, friend_index in ipairs(data.friends) do
    if friend_index == target.index then
      player.print("Этот игрок уже в друзьях.")
      return
    end
  end
  table.insert(data.friends, target.index)
  refresh_gui_if_open(player)
  player.print("Друг добавлен.")
end)

commands.add_command("auction-friend-remove", "Удалить друга: /auction-friend-remove <player>", function(event)
  local player = get_player(event.player_index)
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
  local data = ensure_player_data(player)
  for index, friend_index in ipairs(data.friends) do
    if friend_index == target.index then
      table.remove(data.friends, index)
      refresh_gui_if_open(player)
      player.print("Друг удалён.")
      return
    end
  end
  player.print("Игрок не найден в списке друзей.")
end)

commands.add_command("auction-guild-set", "Установить гильдию: /auction-guild-set <name>", function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end
  local guild_name = event.parameter
  if not guild_name or guild_name == "" then
    player.print("Укажите название гильдии.")
    return
  end
  local data = ensure_player_data(player)
  data.guild = guild_name
  refresh_gui_if_open(player)
  player.print("Гильдия обновлена.")
end)

commands.add_command("auction-guild-clear", "Сбросить гильдию", function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end
  local data = ensure_player_data(player)
  data.guild = nil
  refresh_gui_if_open(player)
  player.print("Гильдия сброшена.")
end)

script.on_init(function()
  ensure_global()
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end
  ensure_player_data(player)
  ensure_gui(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  local player = get_player(event.player_index)
  if not player then
    return
  end
  local element = event.element
  if not element or not element.valid then
    return
  end

  if element.name == GUI_REFRESH_BUTTON then
    refresh_gui(player)
    return
  end

  local npc_sell = string.match(element.name, "^npc_sell_(%d+)$")
  local npc_buy = string.match(element.name, "^npc_buy_(%d+)$")

  if npc_sell then
    local npc = NPC_MERCHANTS[tonumber(npc_sell)]
    if npc then
      if not remove_items(player, npc.buy.item, 1) then
        player.print("Недостаточно предметов для продажи NPC.")
        return
      end
      add_balance(player, npc.buy.price)
      refresh_gui(player)
    end
    return
  end

  if npc_buy then
    local npc = NPC_MERCHANTS[tonumber(npc_buy)]
    if npc then
      if not take_balance(player, npc.sell.price) then
        player.print("Недостаточно валюты для покупки у NPC.")
        return
      end
      if not add_items(player, npc.sell.item, 1) then
        add_balance(player, npc.sell.price)
        player.print("Нет места в инвентаре.")
        return
      end
      refresh_gui(player)
    end
  end
end)

script.on_nth_tick(60, function()
  ensure_global()
  for auction_id, auction in pairs(global.auctions) do
    if auction.ends_at <= game.tick then
      Auction.finish(auction_id)
    end
  end
end)

script.on_nth_tick(TICKS_PER_MINUTE, function()
  for _, player in pairs(game.connected_players) do
    refresh_gui_if_open(player)
  end
end)
