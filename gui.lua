local Auction = require("auction")

local Gui = {}

Gui.GUI_ROOT = "mmo_auction_root"
Gui.GUI_AUCTION_LIST = "mmo_auction_list"
Gui.GUI_BALANCE_LABEL = "mmo_balance_label"
Gui.GUI_REFRESH_BUTTON = "mmo_refresh_button"
Gui.GUI_NPC_LIST = "mmo_npc_list"
Gui.GUI_NPC_TAB = "mmo_npc_tab"
Gui.GUI_AUCTION_TAB = "mmo_auction_tab"
Gui.GUI_PROFILE_TAB = "mmo_profile_tab"
Gui.GUI_TABS = "mmo_tabs"
Gui.GUI_PROFILE_LIST = "mmo_profile_list"
Gui.GUI_AVATAR_SPRITE = "mmo_avatar_sprite"
Gui.GUI_PROFILE_NAME = "mmo_profile_name"
Gui.GUI_PROFILE_FRIENDS = "mmo_profile_friends"
Gui.GUI_PROFILE_GUILD = "mmo_profile_guild"

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

function Gui.resolve_avatar_sprite(name)
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

local function create_auction_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "Аукцион", name = Gui.GUI_AUCTION_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_auction_frame", direction = "vertical"})
  frame.style.padding = 8

  local header = frame.add({type = "flow", name = "mmo_header", direction = "horizontal"})
  header.add({type = "label", name = Gui.GUI_BALANCE_LABEL, caption = "Баланс: 0"})
  header.add({type = "button", name = Gui.GUI_REFRESH_BUTTON, caption = "Обновить"})

  frame.add({type = "line"})
  frame.add({type = "label", caption = "Список аукционов:"})
  frame.add({type = "scroll-pane", name = Gui.GUI_AUCTION_LIST, direction = "vertical"}).style.maximal_height = 300

  tab_pane.add_tab(tab, frame)
end

local function create_npc_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "NPC", name = Gui.GUI_NPC_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_npc_frame", direction = "vertical"})
  frame.style.padding = 8
  frame.add({type = "label", caption = "Торговцы NPC (низкие покупки, высокие продажи):"})
  frame.add({type = "scroll-pane", name = Gui.GUI_NPC_LIST, direction = "vertical"}).style.maximal_height = 300
  tab_pane.add_tab(tab, frame)
end

local function create_profile_tab(tab_pane)
  local tab = tab_pane.add({type = "tab", caption = "Профиль", name = Gui.GUI_PROFILE_TAB})
  local frame = tab_pane.add({type = "frame", name = "mmo_profile_frame", direction = "vertical"})
  frame.style.padding = 8

  local header = frame.add({type = "flow", direction = "horizontal"})
  header.add({type = "sprite", name = Gui.GUI_AVATAR_SPRITE, sprite = "entity/character"})
  header.add({type = "label", name = Gui.GUI_PROFILE_NAME, caption = "Игрок"})

  frame.add({type = "label", name = Gui.GUI_PROFILE_GUILD, caption = "Гильдия: Нет"})
  frame.add({type = "label", name = Gui.GUI_PROFILE_FRIENDS, caption = "Друзья: нет"})
  frame.add({type = "line"})
  frame.add({type = "label", caption = "Ваши лоты на аукционе:"})
  frame.add({type = "scroll-pane", name = Gui.GUI_PROFILE_LIST, direction = "vertical"}).style.maximal_height = 300

  tab_pane.add_tab(tab, frame)
end

local function update_balance_label(player)
  local root = player.gui.screen[Gui.GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[Gui.GUI_TABS]
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
  local label = header[Gui.GUI_BALANCE_LABEL]
  if not label then
    return
  end
  label.caption = string.format("Баланс: %d", Auction.get_balance(player))
end

local function populate_auction_list(player)
  local root = player.gui.screen[Gui.GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[Gui.GUI_TABS]
  if not tabs then
    return
  end
  local auction_frame = tabs["mmo_auction_frame"]
  if not auction_frame then
    return
  end
  local list = auction_frame[Gui.GUI_AUCTION_LIST]
  if not list then
    return
  end
  list.clear()

  local count = 0
  for _, auction in pairs(global.auctions or {}) do
    count = count + 1
    list.add({type = "label", caption = Auction.format_auction(auction)})
  end

  if count == 0 then
    list.add({type = "label", caption = "Активных аукционов нет."})
  end
end

local function populate_npc_list(player)
  local root = player.gui.screen[Gui.GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[Gui.GUI_TABS]
  if not tabs then
    return
  end
  local npc_frame = tabs["mmo_npc_frame"]
  if not npc_frame then
    return
  end
  local list = npc_frame[Gui.GUI_NPC_LIST]
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
  local root = player.gui.screen[Gui.GUI_ROOT]
  if not root then
    return
  end
  local tabs = root[Gui.GUI_TABS]
  if not tabs then
    return
  end
  local profile_frame = tabs["mmo_profile_frame"]
  if not profile_frame then
    return
  end

  local data = Auction.ensure_player_data(player)
  local avatar = profile_frame[Gui.GUI_AVATAR_SPRITE]
  if avatar then
    avatar.sprite = data.avatar_sprite or "entity/character"
  end
  local name_label = profile_frame[Gui.GUI_PROFILE_NAME]
  if name_label then
    name_label.caption = string.format("Игрок: %s", player.name)
  end
  local guild_label = profile_frame[Gui.GUI_PROFILE_GUILD]
  if guild_label then
    guild_label.caption = string.format("Гильдия: %s", data.guild or "Нет")
  end
  local friends_label = profile_frame[Gui.GUI_PROFILE_FRIENDS]
  if friends_label then
    local friend_names = {}
    for _, friend_ref in ipairs(data.friends) do
      if type(friend_ref) == "number" then
        local friend = Auction.get_player(friend_ref)
        if friend then
          table.insert(friend_names, friend.name)
        end
      elseif type(friend_ref) == "string" then
        table.insert(friend_names, friend_ref)
      end
    end
    if #friend_names == 0 then
      friends_label.caption = "Друзья: нет"
    else
      friends_label.caption = "Друзья: " .. table.concat(friend_names, ", ")
    end
  end

  local list = profile_frame[Gui.GUI_PROFILE_LIST]
  if not list then
    return
  end
  list.clear()

  local count = 0
  for _, auction in pairs(global.auctions or {}) do
    if auction.seller_index == player.index then
      count = count + 1
      list.add({type = "label", caption = Auction.format_auction(auction)})
    end
  end

  if count == 0 then
    list.add({type = "label", caption = "У вас нет активных лотов."})
  end
end

function Gui.refresh(player)
  Auction.ensure_global()
  update_balance_label(player)
  populate_auction_list(player)
  populate_npc_list(player)
  populate_profile(player)
end

function Gui.ensure(player)
  if player.gui.screen[Gui.GUI_ROOT] then
    Gui.refresh(player)
    return
  end

  local root = player.gui.screen.add({type = "frame", name = Gui.GUI_ROOT, direction = "vertical"})
  root.caption = "MMO Аукцион"
  root.auto_center = true
  root.style.padding = 8

  local tab_pane = root.add({type = "tabbed-pane", name = Gui.GUI_TABS})
  create_auction_tab(tab_pane)
  create_npc_tab(tab_pane)
  create_profile_tab(tab_pane)

  Gui.refresh(player)
end

function Gui.refresh_if_open(player)
  if player.gui.screen[Gui.GUI_ROOT] then
    Gui.refresh(player)
  end
end

function Gui.handle_click(event)
  local player = Auction.get_player(event.player_index)
  if not player then
    return
  end
  local element = event.element
  if not element or not element.valid then
    return
  end

  if element.name == Gui.GUI_REFRESH_BUTTON then
    Gui.refresh(player)
    return
  end

  local npc_sell = string.match(element.name, "^npc_sell_(%d+)$")
  local npc_buy = string.match(element.name, "^npc_buy_(%d+)$")

  if npc_sell then
    local npc = NPC_MERCHANTS[tonumber(npc_sell)]
    if npc then
      if not Auction.remove_items(player, npc.buy.item, 1) then
        player.print("Недостаточно предметов для продажи NPC.")
        return
      end
      Auction.add_balance(player, npc.buy.price)
      Gui.refresh(player)
    end
    return
  end

  if npc_buy then
    local npc = NPC_MERCHANTS[tonumber(npc_buy)]
    if npc then
      if not Auction.take_balance(player, npc.sell.price) then
        player.print("Недостаточно валюты для покупки у NPC.")
        return
      end
      if not Auction.add_items(player, npc.sell.item, 1) then
        Auction.add_balance(player, npc.sell.price)
        player.print("Нет места в инвентаре.")
        return
      end
      Gui.refresh(player)
    end
  end
end

return Gui
