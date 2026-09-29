local ADDON, ns = ...

-- Session report: what this play session brought. It starts when you log
-- in (a /reload keeps it) and shows in the info bar tooltip and with
-- /fui session. XP, gold, quests, kills that gave XP, deaths, per hour.

local S = {}
ns.Session = S

local function Data()
  ForeverUIDB.session = ForeverUIDB.session or {}
  return ForeverUIDB.session[ns.charKey]
end

function S.Reset()
  ForeverUIDB.session = ForeverUIDB.session or {}
  ForeverUIDB.session[ns.charKey] = {
    start = time(), money = GetMoney(), xp = 0, quests = 0, kills = 0, deaths = 0,
    lastXP = ns.Plain(UnitXP("player")), lastMax = ns.Plain(UnitXPMax("player")),
  }
end

local function Money(copper)
  local sign = copper < 0 and "-" or ""
  copper = math.abs(copper)
  return string.format("%s%d|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", sign,
    math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100)
end

local function Duration(sec)
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h > 0 then return string.format("%dh %02dm", h, m) end
  return string.format("%dm", m)
end

local function PerHour(v, sec)
  if sec < 60 then return 0 end
  return v * 3600 / sec
end

-- Lines as { label, value } pairs.
function S.Lines()
  local d = Data()
  if not d then return {} end
  local sec = time() - d.start
  local gold = GetMoney() - d.money
  local lines = {
    { "Session", Duration(sec) },
    { "Gold", Money(gold) .. string.format("  (%s/h)", Money(math.floor(PerHour(gold, sec)))) },
  }
  local max = ns.Plain(UnitXPMax("player"))
  if d.xp > 0 or (max and max > 0) then
    local line = string.format("%d  (%d/h)", d.xp, math.floor(PerHour(d.xp, sec)))
    local cur = ns.Plain(UnitXP("player"))
    local xph = PerHour(d.xp, sec)
    if cur and max and xph > 0 then
      line = line .. "  · level in " .. Duration((max - cur) / xph * 3600)
    end
    lines[#lines + 1] = { "XP", line }
  end
  lines[#lines + 1] = { "Quests turned in", tostring(d.quests) }
  lines[#lines + 1] = { "Kills (with XP)", tostring(d.kills) }
  lines[#lines + 1] = { "Deaths", tostring(d.deaths) }
  return lines
end

function ns.SessionTooltip(tt)
  local lines = S.Lines()
  if #lines == 0 then return end
  tt:AddLine(" ")
  tt:AddLine("This session", 0.95, 0.76, 0.31)
  for _, l in ipairs(lines) do tt:AddDoubleLine(l[1], l[2], 0.8, 0.82, 0.86, 1, 1, 1) end
end

function S.Print()
  ns.Print("this session:")
  for _, l in ipairs(S.Lines()) do print("  " .. l[1] .. ": " .. l[2]) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "QUEST_TURNED_IN", "PLAYER_DEAD",
  "CHAT_MSG_COMBAT_XP_GAIN" }) do
  ns.SafeRegister(ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1, a2)
  if not ns.profile then return end
  if e == "PLAYER_ENTERING_WORLD" then
    -- a1 = first login, a2 = /reload: a new session only on a real login.
    if a1 or not Data() then S.Reset() end
    return
  end
  local d = Data()
  if not d then return end
  if e == "PLAYER_XP_UPDATE" then
    local cur, max = ns.Plain(UnitXP("player")), ns.Plain(UnitXPMax("player"))
    if cur and d.lastXP then
      local gain = cur - d.lastXP
      -- Level up: the rest of the old level plus what's in the new one.
      if gain < 0 and d.lastMax then gain = (d.lastMax - d.lastXP) + cur end
      if gain > 0 then d.xp = d.xp + gain end
    end
    d.lastXP, d.lastMax = cur, max
  elseif e == "QUEST_TURNED_IN" then
    d.quests = d.quests + 1
  elseif e == "PLAYER_DEAD" then
    d.deaths = d.deaths + 1
  elseif e == "CHAT_MSG_COMBAT_XP_GAIN" then
    -- "X dies, you gain N experience." (quest XP doesn't say "dies")
    local msg = ns.Plain(a1)
    if msg and msg:find(" dies") then d.kills = d.kills + 1 end
  end
end)
