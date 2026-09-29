local ADDON, ns = ...
local X = ns:NewModule("xp", "XP Bar", { pos = { p = "BOTTOM", rp = "BOTTOM", x = 0, y = 4 }, scale = 1, alpha = 1, fade = "always" })

function X:Build()
  local f = CreateFrame("Frame", "ForeverUIXPBar", UIParent)
  f:SetSize(476, 10)
  self.frame = f

  local rested = ns.Bar(f, 6)
  rested:SetPoint("TOPLEFT")
  rested:SetPoint("TOPRIGHT")
  rested:SetStatusBarColor(0.44, 0.66, 1, 0.45)
  local xp = CreateFrame("StatusBar", nil, f)
  xp:SetAllPoints(rested)
  xp:SetStatusBarTexture(ns.BAR_TEX)
  xp:SetStatusBarColor(0.7, 0.49, 0.94)
  xp:SetFrameLevel(rested:GetFrameLevel() + 1)
  self.rested, self.xp = rested, xp

  -- Watched reputation (the faction you track in the reputation panel).
  local rep = ns.Bar(f, 3)
  rep:SetPoint("BOTTOMLEFT")
  rep:SetPoint("BOTTOMRIGHT")
  rep:Hide()
  self.rep = rep

  f:EnableMouse(true)
  f:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:AddLine(X:Text(), 1, 1, 1)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "UPDATE_FACTION" }) do
    ns.SafeRegister(ev, e)
  end
  ev:SetScript("OnEvent", function() X:Update() end)
  self:Update()
end

local function AtMaxLevel()
  local max = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 60
  local level = ns.Plain(UnitLevel("player"))
  return level ~= nil and level >= max
end

-- name, standing (1-8), bottom, top, value of the watched faction.
local function Watched()
  if C_Reputation and C_Reputation.GetWatchedFactionData then
    local d = C_Reputation.GetWatchedFactionData()
    if d and d.name then
      return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding
    end
    return nil
  end
  if GetWatchedFactionInfo then
    local name, standing, min, max, value = GetWatchedFactionInfo()
    if name then return name, standing, min, max, value end
  end
end

function X:UpdateRep()
  local name, standing, min, max, value = Watched()
  if not name or not max or max <= min then
    self.rep:Hide()
    return
  end
  local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
  if c then self.rep:SetStatusBarColor(c.r, c.g, c.b) else self.rep:SetStatusBarColor(0.2, 0.7, 0.3) end
  self.rep:SetMinMaxValues(0, max - min)
  self.rep:SetValue(value - min)
  self.rep:Show()
end

function X:Update()
  self:UpdateRep()
  local done = AtMaxLevel()
  self.xp:SetShown(not done)
  self.rested:SetShown(not done)
  if done then return end
  local cur, max = UnitXP("player"), UnitXPMax("player")
  pcall(self.xp.SetMinMaxValues, self.xp, 0, max)
  pcall(self.xp.SetValue, self.xp, cur)
  local pcur, pmax, rested = ns.Plain(cur), ns.Plain(max), ns.Plain(GetXPExhaustion())
  if pcur and pmax and pmax > 0 then
    self.rested:SetMinMaxValues(0, pmax)
    self.rested:SetValue(math.min(pmax, pcur + (rested or 0)))
  else
    self.rested:SetValue(0)
  end
end

function X:Text()
  local text = self:XPText()
  local name, standing, min, max, value = Watched()
  if name and max and max > min then
    local label = _G["FACTION_STANDING_LABEL" .. tostring(standing)] or ""
    text = text .. string.format("\n%s: %s  (%d / %d)", name, label, value - min, max - min)
  end
  return text
end

function X:XPText()
  if AtMaxLevel() then return "Max level" end
  local cur, max = ns.Plain(UnitXP("player")), ns.Plain(UnitXPMax("player"))
  if not cur or not max or max <= 0 then return "XP" end
  local rested = ns.Plain(GetXPExhaustion()) or 0
  return string.format("Level %s  ·  %.1f%%  (%d / %d)  ·  rested %d%%",
    tostring(ns.Plain(UnitLevel("player")) or "?"), cur / max * 100, cur, max, math.floor(rested / max * 100 + 0.5))
end

function X:HideBlizzard()
  ns.HideBlizzard("MainMenuExpBar")
  -- These call methods on their parent; hide them in place.
  for _, n in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
    ns.HideBlizzard(n, false, true)
  end
end
