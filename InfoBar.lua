local ADDON, ns = ...
local IB = ns:NewModule("info", "Info Bar", { pos = { p = "TOPLEFT", rp = "TOPLEFT", x = 8, y = -8 }, scale = 1, alpha = 1, fade = "always" })

-- A slim bar top left, split into cells: time · fps · latency · gold ·
-- bags · durability. Labels in muted bronze, values in white, warnings in
-- colour. Hover for details.

local LABEL = "|cffb39a64"
local PAD, GAP, H = 9, 16, 22

local function Money(copper)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  return string.format("%d|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", g, s, c)
end

local function Bags()
  local C = C_Container
  local numFree = (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  if not numFree or not numSlots then return nil end
  local free, total = 0, 0
  for bag = 0, 4 do
    local f, bagType = numFree(bag)
    if bagType == nil or bagType == 0 then
      free = free + (f or 0)
      total = total + (numSlots(bag) or 0)
    end
  end
  return free, total
end

-- Lowest durability of your equipped items, in percent.
local function Durability()
  local lowest
  for slot = 1, 19 do
    local cur, max = GetInventoryItemDurability(slot)
    cur, max = ns.Plain(cur), ns.Plain(max)
    if cur and max and max > 0 then
      local pct = cur / max * 100
      if not lowest or pct < lowest then lowest = pct end
    end
  end
  return lowest
end

local function Warn(level, text)
  if level == 2 then return "|cffff6b5a" .. text .. "|r" end
  if level == 1 then return "|cffffd100" .. text .. "|r" end
  return text
end

function IB:Build()
  local f = CreateFrame("Frame", "ForeverUIInfoBar", UIParent)
  f:SetSize(360, H)
  ns.Backdrop(f, 0.8)
  self.frame = f
  f.cells, f.dividers = {}, {}
  for i = 1, 7 do
    local cell = ns.NumText(f, 12)
    f.cells[i] = cell
    if i > 1 then
      local d = f:CreateTexture(nil, "ARTWORK")
      d:SetColorTexture(ns.STYLE.border[1], ns.STYLE.border[2], ns.STYLE.border[3], 0.55)
      d:SetSize(1, H - 10)
      f.dividers[i] = d
    end
  end
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(s) IB:Tooltip(s) end)
  f:SetScript("OnLeave", GameTooltip_Hide)
  -- Click: Blizzard's clock options (stopwatch, alarm), which lived on the
  -- minimap clock before.
  f:SetScript("OnMouseUp", function(_, button)
    -- Right-click: pick the context mode by hand (… → auto).
    if button == "RightButton" and ns.Context then
      ns.Context.Cycle()
      IB:Update()
      return
    end
    if button ~= "LeftButton" then return end
    if not TimeManager_Toggle then
      local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
      if load then pcall(load, "Blizzard_TimeManager") end
    end
    if TimeManager_Toggle then TimeManager_Toggle() end
  end)

  local acc = 1
  f:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 1 then return end
    acc = 0
    IB:Update()
  end)
end

function IB:Update()
  local f = self.frame
  local _, _, home = GetNetStats()
  local fps = math.floor(GetFramerate() + 0.5)
  local ms = home or 0
  local values = {}
  local mode = ns.ContextLabel and ns.ContextLabel()
  if mode then values[1] = "|cfff2c14e" .. mode .. "|r" end
  for _, v in ipairs({
    date("%H:%M"),
    Warn(fps < 20 and 2 or fps < 40 and 1 or 0, tostring(fps)) .. LABEL .. " fps|r",
    Warn(ms > 400 and 2 or ms > 200 and 1 or 0, tostring(ms)) .. LABEL .. " ms|r",
    Money(GetMoney()),
  }) do values[#values + 1] = v end
  local free, total = Bags()
  if free then
    values[#values + 1] = LABEL .. "Bags|r " .. Warn(free <= 2 and 2 or free <= 6 and 1 or 0, (total - free) .. "/" .. total)
  end
  local dur = Durability()
  if dur then
    values[#values + 1] = LABEL .. "Dur|r " .. Warn(dur < 30 and 2 or dur < 60 and 1 or 0, math.floor(dur + 0.5) .. "%")
  end

  local x = PAD
  for i, cell in ipairs(f.cells) do
    local v = values[i]
    local d = f.dividers[i]
    if v then
      if d then
        d:ClearAllPoints()
        d:SetPoint("LEFT", f, "LEFT", x - GAP / 2, 0)
        d:Show()
      end
      cell:ClearAllPoints()
      cell:SetPoint("LEFT", f, "LEFT", x, 0)
      cell:SetText(v)
      cell:Show()
      x = x + cell:GetStringWidth() + GAP
    else
      cell:Hide()
      if d then d:Hide() end
    end
  end
  f:SetWidth(x - GAP + PAD)
end

function IB:Tooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:AddLine("Forever UI")
  GameTooltip:AddLine("Click for stopwatch and alarm", 0.6, 0.63, 0.68)
  GameTooltip:AddLine("Right-click to change the context mode (* = set by hand)", 0.6, 0.63, 0.68)
  local h, m = GetGameTime()
  GameTooltip:AddDoubleLine("Local time", date("%H:%M"), 0.8, 0.82, 0.86, 1, 1, 1)
  GameTooltip:AddDoubleLine("Server time", string.format("%02d:%02d", h, m), 0.8, 0.82, 0.86, 1, 1, 1)
  local _, _, home, world = GetNetStats()
  GameTooltip:AddDoubleLine("Latency (home / world)", string.format("%d / %d ms", home or 0, world or 0), 0.8, 0.82, 0.86, 1, 1, 1)
  GameTooltip:AddDoubleLine("Gold", Money(GetMoney()), 0.8, 0.82, 0.86, 1, 1, 1)
  local free, total = Bags()
  if free then
    GameTooltip:AddDoubleLine("Bag space", string.format("%d free of %d", free, total), 0.8, 0.82, 0.86, 1, 1, 1)
  end
  local dur = Durability()
  if dur then
    GameTooltip:AddDoubleLine("Lowest durability", string.format("%d%%", math.floor(dur + 0.5)), 0.8, 0.82, 0.86, 1, 1, 1)
  end
  if ns.SessionTooltip then ns.SessionTooltip(GameTooltip) end
  GameTooltip:Show()
end
