local Auction = require("auction")

local Auth = {}

local INTERFACE_NAME = "mmo_auction_auth"

local function ensure_auth()
  Auction.ensure_global()
  global.pending_auth = global.pending_auth or {}
end

local function get_pending(player_index)
  ensure_auth()
  return global.pending_auth[player_index]
end

local function set_pending(player_index, action, login, email)
  ensure_auth()
  global.pending_auth[player_index] = {
    action = action,
    login = login,
    email = email
  }
end

local function clear_pending(player_index)
  ensure_auth()
  global.pending_auth[player_index] = nil
end

function Auth.register()
  if remote.interfaces[INTERFACE_NAME] then
    return
  end

  remote.add_interface(INTERFACE_NAME, {
    request_login = function(player_name, login, email)
      local player = game.get_player(player_name)
      if not player or not player.valid then
        return false
      end
      set_pending(player.index, "login", login, email)
      player.print("Введите пароль: /auth-password <пароль>")
      return true
    end,
    request_register = function(player_name, login, email)
      local player = game.get_player(player_name)
      if not player or not player.valid then
        return false
      end
      set_pending(player.index, "register", login, email)
      player.print("Введите пароль для регистрации: /auth-password <пароль>")
      return true
    end,
    confirm_auth = function(player_name, login, email)
      local player = game.get_player(player_name)
      if not player or not player.valid then
        return false
      end
      Auction.set_auth_status(player, "authenticated", login, email)
      clear_pending(player.index)
      player.print("Авторизация подтверждена сервером.")
      return true
    end,
    reject_auth = function(player_name, reason)
      local player = game.get_player(player_name)
      if not player or not player.valid then
        return false
      end
      Auction.set_auth_status(player, "unauthenticated", nil, nil)
      clear_pending(player.index)
      player.print(reason or "Авторизация отклонена сервером.")
      return true
    end
  })
end

function Auth.handle_password(player, password)
  local pending = get_pending(player.index)
  if not pending then
    player.print("Нет активного запроса авторизации.")
    return
  end
  if not password or password == "" then
    player.print("Укажите пароль: /auth-password <пароль>")
    return
  end
  if not remote.interfaces["mmo_auction_sync"] then
    player.print("Сервер синхронизации не зарегистрирован.")
    return
  end
  if not remote.interfaces["mmo_auction_sync"].submit_auth then
    player.print("Сервер не поддерживает приём авторизации.")
    return
  end
  remote.call("mmo_auction_sync", "submit_auth", player.name, pending.action, pending.login, pending.email, password)
  player.print("Данные отправлены на сервер.")
end

return Auth
