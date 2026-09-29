local ADDON, ns = ...
local P = ns:NewModule("player", "Player", { pos = { p = "CENTER", rp = "CENTER", x = -190, y = -250 }, scale = 1, alpha = 1, fade = "always" })
local T = ns:NewModule("target", "Target", { pos = { p = "CENTER", rp = "CENTER", x = 190, y = -250 }, scale = 1, alpha = 1, fade = "always" })

-- Health and power may be secret values on this client. All numbers go
-- straight into widgets; nothing here compares or calculates with them.

local W, H = 230, 76
local POWER = {
  [0] = { 0.31, 0.55, 0.97 }, -- mana
  [1] = { 0.88, 0.28, 0.23 }, -- rage
  [2] = { 1, 0.5, 0.25 },     -- focus
  [3] = { 1, 0.88, 0.3 },     -- energy
}
local ENERGY = 3

local function Short(v)
  local p = ns.Plain(v)
  if p then
    if p >= 1e6 then return string.format("%.1fm", p / 1e6) end
    if p >= 1e4 then return string.format("%.1fk", p / 1e3) end
    return tostring(p)
  end
  if AbbreviateLargeNumbers then
    local ok, s = pcall(AbbreviateLargeNumbers, v)
    if ok then return s end
  end
  return v
end

-- Percentage 0-100, or nil. Uses the client's own percent API when it has
-- one (works with secrets), otherwise plain math.
local function Percent(unit, powerType)
  local scale = CurveConstants and CurveConstants.ScaleTo100
  if scale then
    local ok, v
    if powerType and UnitPowerPercent then
      ok, v = pcall(UnitPowerPercent, unit, powerType, false, scale)
    elseif not powerType and UnitHealthPercent then
      ok, v = pcall(UnitHealthPercent, unit, false, scale)
    end
    if ok then return v end
  end
  local cur, max
  if powerType then
    cur, max = ns.Plain(UnitPower(unit, powerType)), ns.Plain(UnitPowerMax(unit, powerType))
  else
    cur, max = ns.Plain(UnitHealth(unit)), ns.Plain(UnitHealthMax(unit))
  end
  if cur and max and max > 0 then return cur / max * 100 end
end

local function SetBar(bar, cur, max)
  pcall(bar.SetMinMaxValues, bar, 0, max)
  pcall(bar.SetValue, bar, cur)
end

local function ClassColor(unit)
  local _, class = UnitClass(unit)
  class = ns.Plain(class)
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local c = class and colors and colors[class]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-- The secure button is the click area; the visible panel inside can change
-- height in combat because it is not protected.
local function Create(name, unit)
  local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
  f:SetSize(W, H)
  f.unit = unit
  f:SetAttribute("unit", unit)
  f:SetAttribute("*type1", "target")
  f:SetAttribute("*type2", "togglemenu")
  f:RegisterForClicks("AnyUp")
  -- Hover shows the normal unit tooltip (class, level, guild, faction...).
  f:SetScript("OnEnter", function(self)
    if not UnitExists(self.unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(self.unit)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)

  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT")
  p:SetPoint("TOPRIGHT")
  p:SetHeight(56)
  ns.Backdrop(p, 0.58)
  f.panel = p

  f.level = ns.NumText(p, 12, "RIGHT")
  f.level:SetPoint("TOPRIGHT", -6, -6)
  f.name = ns.Text(p, 12)
  f.name:SetPoint("TOPLEFT", 6, -6)
  f.name:SetPoint("RIGHT", f.level, "LEFT", -6, 0)
  f.name:SetHeight(14)
  f.name:SetWordWrap(false)

  f.hp = ns.Bar(p, 17)
  f.hp:SetPoint("TOPLEFT", 5, -22)
  f.hp:SetPoint("TOPRIGHT", -5, -22)
  f.hpText = ns.NumText(f.hp, 11)
  f.hpText:SetPoint("LEFT", 4, 0)
  f.hpPct = ns.NumText(f.hp, 11, "RIGHT")
  f.hpPct:SetPoint("RIGHT", -4, 0)

  f.pw = ns.Bar(p, 10)
  f.pw:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -2)
  f.pw:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -2)
  f.pwText = ns.NumText(f.pw, 10, "RIGHT")
  f.pwText:SetPoint("RIGHT", -4, 0)
  return f
end

------------------------------------------------------------------------
-- Status icons Blizzard's frames had: raid target (skull, star...),
-- group leader, and PvP flag (player only).
------------------------------------------------------------------------
local iconFrames = {}

function ns.AddUnitIcons(f, withPvP)
  local p = f.panel
  f.raidIcon = p:CreateTexture(nil, "OVERLAY", nil, 7)
  f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.raidIcon:SetSize(16, 16)
  f.raidIcon:SetPoint("CENTER", p, "TOP", 0, 1)
  f.raidIcon:Hide()
  f.leader = p:CreateTexture(nil, "OVERLAY", nil, 7)
  f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  f.leader:SetSize(12, 12)
  f.leader:SetPoint("CENTER", p, "TOPLEFT", 3, 1)
  f.leader:Hide()
  if withPvP then
    f.pvp = p:CreateTexture(nil, "OVERLAY", nil, 7)
    f.pvp:SetSize(24, 24)
    f.pvp:SetPoint("RIGHT", p, "LEFT", 2, -4)
    f.pvp:SetTexCoord(0, 0.62, 0, 0.62)
    f.pvp:Hide()
  end
  table.insert(iconFrames, f)
  ns.UpdateUnitIcons(f)
end

function ns.UpdateUnitIcons(f)
  local u = f.unit
  if not UnitExists(u) then
    f.raidIcon:Hide()
    f.leader:Hide()
    if f.pvp then f.pvp:Hide() end
    return
  end
  local idx = ns.Plain(GetRaidTargetIndex(u))
  if idx and SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(f.raidIcon, idx)
    f.raidIcon:Show()
  else
    f.raidIcon:Hide()
  end
  local isLeader = UnitIsGroupLeader or UnitIsPartyLeader
  f.leader:SetShown(isLeader and ns.Plain(isLeader(u)) and true or false)
  if f.pvp then
    local faction = ns.Plain(UnitFactionGroup(u))
    if ns.Plain(UnitIsPVP(u)) and (faction == "Alliance" or faction == "Horde") then
      f.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
      f.pvp:Show()
    else
      f.pvp:Hide()
    end
  end
end

local iconEv = CreateFrame("Frame")
for _, e in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_FLAGS_CHANGED",
  "UNIT_FACTION", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  ns.SafeRegister(iconEv, e)
end
iconEv:SetScript("OnEvent", function()
  for _, f in ipairs(iconFrames) do ns.UpdateUnitIcons(f) end
end)

------------------------------------------------------------------------
-- Heal prediction: incoming heals drawn as a lighter green piece right
-- after the health fill (your own heals brighter than other healers'),
-- plus shields. Each piece is a bar as wide as the health bar, starting
-- where the health fill ends, cut off at the bar's end by a clipping
-- frame. So the widgets do the maths and secret values still work.
------------------------------------------------------------------------
local function PredictionBar(parent, r, g, b, a)
  local s = CreateFrame("StatusBar", nil, parent)
  s:SetStatusBarTexture(ns.BAR_TEX)
  s:SetStatusBarColor(r, g, b, a)
  s:SetMinMaxValues(0, 1)
  s:SetValue(0)
  return s
end

function ns.AddHealPrediction(f, withText)
  local hp = f.hp
  local clip = CreateFrame("Frame", nil, hp)
  clip:SetAllPoints(hp)
  clip:SetClipsChildren(true)
  clip:SetFrameLevel(hp:GetFrameLevel() + 1)
  local fill = hp:GetStatusBarTexture()
  local mine = PredictionBar(clip, 0.45, 1, 0.5, 0.6)
  local other = PredictionBar(clip, 0.2, 0.8, 0.45, 0.5)
  local shield = PredictionBar(clip, 0.85, 0.92, 1, 0.45)
  mine:SetPoint("TOPLEFT", fill, "TOPRIGHT")
  mine:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
  other:SetPoint("TOPLEFT", mine:GetStatusBarTexture(), "TOPRIGHT")
  other:SetPoint("BOTTOMLEFT", mine:GetStatusBarTexture(), "BOTTOMRIGHT")
  shield:SetPoint("TOPLEFT", other:GetStatusBarTexture(), "TOPRIGHT")
  shield:SetPoint("BOTTOMLEFT", other:GetStatusBarTexture(), "BOTTOMRIGHT")
  local function Width()
    local w = hp:GetWidth()
    if w and w > 0 then
      mine:SetWidth(w)
      other:SetWidth(w)
      shield:SetWidth(w)
    end
  end
  hp:HookScript("OnSizeChanged", Width)
  Width()
  -- The health texts stay on top of the prediction.
  local top = CreateFrame("Frame", nil, hp)
  top:SetAllPoints(hp)
  top:SetFrameLevel(hp:GetFrameLevel() + 3)
  for _, key in ipairs({ "hpText", "hpPct" }) do
    if f[key] then f[key]:SetParent(top) end
  end
  if withText then
    f.healText = ns.NumText(top, 11)
    f.healText:SetTextColor(0.55, 1, 0.55)
    f.healText:SetPoint("LEFT", f.hpText, "RIGHT", 5, 0)
  end
  f.heal = { mine = mine, other = other, shield = shield }
end

local function Incoming(u, healer)
  if not UnitGetIncomingHeals then return end
  local ok, v = pcall(UnitGetIncomingHeals, u, healer)
  if ok then return v end
end

function ns.UpdateHealPrediction(f)
  local h = f.heal
  if not h then return end
  local u = f.unit
  local max = UnitHealthMax(u)
  local mine, all = Incoming(u, "player"), Incoming(u)
  local pm, pa = ns.Plain(mine), ns.Plain(all)
  local other
  if pm and pa then
    other = math.max(pa - pm, 0)
  elseif ns.IsSecret(mine) or ns.IsSecret(all) then
    -- Secret: no subtracting, so everything in one piece.
    mine, other = all or mine, 0
  end
  local shield = 0
  if UnitGetTotalAbsorbs then
    local ok, v = pcall(UnitGetTotalAbsorbs, u)
    if ok and v then shield = v end
  end
  for key, v in pairs({ mine = mine or 0, other = other or 0, shield = shield }) do
    pcall(h[key].SetMinMaxValues, h[key], 0, max)
    pcall(h[key].SetValue, h[key], v)
  end
  if f.healText then
    -- Only a readable amount gets a number; a secret one just the bar.
    f.healText:SetText((pa and pa > 0) and ("+" .. Short(pa)) or "")
  end
end

------------------------------------------------------------------------
-- Threat. Only in a group: solo you always have the mob's attention.
------------------------------------------------------------------------
function ns.UpdateThreatGlow(f, unit)
  if not f.threat then return end
  local inGroup = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)
  local status = inGroup and UnitThreatSituation and ns.Plain(UnitThreatSituation(unit))
  if status and status > 0 and GetThreatStatusColor then
    local r, g, b = GetThreatStatusColor(status)
    f.threat:SetColorTexture(r, g, b, 0.45)
    f.threat:Show()
  else
    f.threat:Hide()
  end
end

local function UpdateHealth(f)
  local u = f.unit
  if not UnitExists(u) then return end
  local cur, max = UnitHealth(u), UnitHealthMax(u)
  SetBar(f.hp, cur, max)
  ns.UpdateHealPrediction(f)
  if ns.Plain(UnitIsDeadOrGhost(u)) then
    f.hpText:SetText("Dead")
    f.hpPct:SetText("")
    return
  end
  ns.SetFormatted(f.hpText, "%s / %s", Short(cur), Short(max))
  local pct = Percent(u)
  if ns.Has(pct) then ns.SetFormatted(f.hpPct, "%.0f%%", pct) else f.hpPct:SetText("") end
end

local function UpdatePower(f)
  local u = f.unit
  if not UnitExists(u) then return end
  local pt = ns.Plain(UnitPowerType(u)) or 0
  local cur, max = UnitPower(u, pt), UnitPowerMax(u, pt)
  local c = POWER[pt] or POWER[0]
  f.pw:SetStatusBarColor(c[1], c[2], c[3])
  SetBar(f.pw, cur, max)
  if ns.Plain(max) == 0 then
    f.pwText:SetText("")
  else
    ns.SetFormatted(f.pwText, "%s / %s", cur, max)
  end
end

------------------------------------------------------------------------
-- Player
------------------------------------------------------------------------
function P:Build()
  local f = Create("ForeverUIPlayerFrame", "player")
  self.frame = f
  local p = f.panel
  ns.AddHealPrediction(f, true)
  f.threat = f:CreateTexture(nil, "BACKGROUND")
  f.threat:SetPoint("TOPLEFT", p, "TOPLEFT", -3, 3)
  f.threat:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 3, -3)
  f.threat:Hide()

  f.tick = ns.Bar(p, 2)
  f.tick:SetStatusBarColor(1, 0.88, 0.3)
  f.tick:SetValue(0)
  f.mana = ns.Bar(p, 4)
  f.mana:SetStatusBarColor(0.31, 0.55, 0.97)
  f.manaText = ns.NumText(p, 9)
  f.shifts = ns.Pips(p, 6, 84, 4, 0.56, 0.72, 1)
  f.combo = ns.Pips(p, 5, W - 10, 5, 1, 0.71, 0.23)

  -- Crossed swords while you're in combat, like Blizzard's player frame.
  f.combat = p:CreateTexture(nil, "OVERLAY")
  f.combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
  f.combat:SetTexCoord(0.5, 1, 0, 0.49)
  f.combat:SetSize(18, 18)
  f.combat:SetPoint("RIGHT", f.level, "LEFT", -2, 0)
  -- Same spot: crossed swords in combat, "zzz" while resting (inn, city).
  local inCombat = ns.Plain(UnitAffectingCombat("player")) and true or false
  local function UpdateState()
    if inCombat then
      f.combat:SetTexCoord(0.5, 1, 0, 0.49)
      f.combat:Show()
    elseif IsResting() then
      f.combat:SetTexCoord(0, 0.5, 0, 0.421875)
      f.combat:Show()
    else
      f.combat:Hide()
    end
  end
  local stateEv = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD" }) do
    ns.SafeRegister(stateEv, e)
  end
  stateEv:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" then inCombat = true elseif e == "PLAYER_REGEN_ENABLED" then inCombat = false end
    UpdateState()
  end)
  UpdateState()
  ns.AddUnitIcons(f, true)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_COMBO_POINTS", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE" }) do
    ns.SafeRegister(ev, e, "player")
  end
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
    "PLAYER_COMBO_POINTS", "PLAYER_LEVEL_UP" }) do
    ns.SafeRegister(ev, e)
  end
  ev:SetScript("OnEvent", function(_, e, _, token)
    if e == "UNIT_SPELLCAST_SUCCEEDED" then
      P.lastCast = GetTime()
      return
    elseif e == "UPDATE_SHAPESHIFT_FORM" then
      P.lastForm = GetTime()
    elseif e == "UNIT_POWER_FREQUENT" and token == "ENERGY" then
      P:TrackEnergy()
    end
    P:Update()
    T:UpdateCombo()
  end)

  -- The tick bar only runs while ticks arrive. Full energy means no more
  -- ticks (readable: we see it; secret: no tick for over 2 s), so it rests
  -- empty until you spend energy and the next tick comes in.
  p:SetScript("OnUpdate", function()
    if not f.tick:IsShown() then return end
    local last = P.lastTick
    local since = last and (GetTime() - last)
    if since and since < 2.2 and not P.energyFull then
      f.tick:SetValue((since % 2) / 2)
    else
      f.tick:SetValue(0)
    end
  end)
  self:Update()
end

-- Energy arrives in ticks of 20 every 2 seconds. When the value is readable
-- we look at the size of the jump. When it is secret we use timing instead:
-- an energy change that doesn't follow one of your own casts or a shift is
-- a tick.
function P:TrackEnergy()
  local now = GetTime()
  local e = ns.Plain(UnitPower("player", ENERGY))
  if e then
    local max = ns.Plain(UnitPowerMax("player", ENERGY))
    self.energyFull = max ~= nil and e >= max
    if self.lastE then
      local d = e - self.lastE
      if (d >= 18 and d <= 22) or (d > 0 and d < 18 and e == max) then self.lastTick = now end
    end
    self.lastE = e
    return
  end
  self.energyFull = false
  C_Timer.After(0.12, function()
    local t = GetTime()
    if t - (P.lastCast or 0) > 0.3 and t - (P.lastForm or 0) > 0.3 then P.lastTick = now end
  end)
end

function P:Layout()
  local f = self.frame
  local p = f.panel
  local pt = ns.Plain(UnitPowerType("player")) or 0
  local energy = pt == ENERGY
  local inForm = ns.isDruid and pt ~= 0
  local y = -53

  f.tick:ClearAllPoints()
  if energy then
    f.tick:SetPoint("TOPLEFT", 5, y)
    f.tick:SetPoint("TOPRIGHT", -5, y)
    f.tick:Show()
    y = y - 4
  else
    f.tick:Hide()
  end

  f.mana:ClearAllPoints()
  f.manaText:ClearAllPoints()
  f.shifts:ClearAllPoints()
  if inForm then
    f.mana:SetPoint("TOPLEFT", 5, y)
    f.mana:SetPoint("TOPRIGHT", -150, y)
    f.manaText:SetPoint("LEFT", f.mana, "RIGHT", 6, 0)
    f.shifts:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, y)
    f.mana:Show()
    f.manaText:Show()
    f.shifts:SetShown(ns.ShiftCost and ns.ShiftCost() ~= nil)
    y = y - 9
  else
    f.mana:Hide()
    f.manaText:Hide()
    f.shifts:Hide()
  end

  f.combo:ClearAllPoints()
  -- On the target frame instead, when that frame has them.
  if energy and not T.comboHere then
    f.combo:SetPoint("TOPLEFT", p, "TOPLEFT", 5, y)
    f.combo:Show()
    y = y - 8
  else
    f.combo:Hide()
  end
  p:SetHeight(-y + 2)
end

function P:Update()
  local f = self.frame
  -- Full name: on this client UnitPVPName includes the surname
  -- ("Kapsalon Shoarma"); plain UnitName has the first name only.
  local full = UnitPVPName and UnitPVPName("player")
  if ns.Has(full) then ns.SetText(f.name, full) else ns.SetText(f.name, UnitName("player")) end
  f.name:SetTextColor(ClassColor("player"))
  ns.SetText(f.level, UnitLevel("player"))
  f.hp:SetStatusBarColor(0.05, 0.85, 0.1)
  UpdateHealth(f)
  UpdatePower(f)
  ns.UpdateThreatGlow(f, "player")
  self:Layout()

  if f.mana:IsShown() then
    SetBar(f.mana, UnitPower("player", 0), UnitPowerMax("player", 0))
    local pct = Percent("player", 0)
    if ns.Has(pct) then ns.SetFormatted(f.manaText, "%.0f%%", pct) else f.manaText:SetText("") end
    local cost = ns.ShiftCost and ns.ShiftCost()
    if cost then f.shifts:Set(UnitPower("player", 0), cost) end
  end

  if f.combo:IsShown() then
    local cp
    if GetComboPoints then
      cp = GetComboPoints("player", "target")
    elseif Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
      cp = UnitPower("player", Enum.PowerType.ComboPoints)
    end
    if ns.Has(cp) then f.combo:Set(cp, 1) else f.combo:Set(0, 1) end
  end
end

function P:HideBlizzard()
  ns.HideBlizzard("PlayerFrame", true)
end

------------------------------------------------------------------------
-- Target, with target of target and target cast bar underneath
------------------------------------------------------------------------
local TH = 56                 -- target frame height
local COMBO_H = 8             -- the combo point row under it, when shown
local CAST_W, TOT_W = 124, 100 -- together with a 6 px gap: the frame's width

function T:IsEnabled()
  return ns.profile.options.targetFrame == "forever"
end

-- Target of target: small, snapped under the right half of the target frame.
-- `extra`: room for the combo row. The secure button is that much taller
-- from the start (it can't change in combat); only the visible part slides
-- down when the combo row appears.
local function CreateToT(parent, extra)
  local t = CreateFrame("Button", "ForeverUIToTFrame", UIParent, "SecureUnitButtonTemplate")
  t:SetSize(TOT_W, 26 + extra)
  t:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -4)
  t.unit = "targettarget"
  t:SetAttribute("unit", "targettarget")
  t:SetAttribute("*type1", "target")
  t:SetAttribute("*type2", "togglemenu")
  t:RegisterForClicks("AnyUp")
  t:SetScript("OnEnter", function(self)
    if not UnitExists(self.unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(self.unit)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", GameTooltip_Hide)
  local p = CreateFrame("Frame", nil, t)
  p:SetHeight(26)
  function t:SetShift(dy)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -dy)
    p:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, -dy)
  end
  t:SetShift(0)
  ns.Backdrop(p, 0.58)
  t.name = ns.Text(p, 10)
  t.name:SetPoint("TOPLEFT", 4, -3)
  t.name:SetPoint("TOPRIGHT", -4, -3)
  t.name:SetHeight(11)
  t.name:SetWordWrap(false)
  t.hp = ns.Bar(p, 7)
  t.hp:SetPoint("BOTTOMLEFT", 3, 3)
  t.hp:SetPoint("BOTTOMRIGHT", -3, 3)
  RegisterUnitWatch(t)

  -- The target's target changes without a reliable event, so poll it.
  local acc = 0
  p:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.2 then return end
    acc = 0
    if not UnitExists("targettarget") then return end
    ns.SetText(t.name, UnitName("targettarget"))
    t.name:SetTextColor(ClassColor("targettarget"))
    SetBar(t.hp, UnitHealth("targettarget"), UnitHealthMax("targettarget"))
    local reaction = ns.Plain(UnitReaction("targettarget", "player"))
    if reaction and reaction <= 3 then
      t.hp:SetStatusBarColor(0.88, 0.35, 0.3)
    else
      t.hp:SetStatusBarColor(0.05, 0.85, 0.1)
    end
  end)
  return t
end

-- Target cast bar: snapped under the left part of the target frame.
local function CreateTargetCast(parent)
  local c = ns.Bar(parent, 12)
  c:SetWidth(CAST_W)
  function c:SetShift(dy)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -4 - dy)
  end
  c:SetShift(0)
  c:SetStatusBarColor(1, 0.7, 0.2)
  c.text = ns.Text(c, 10)
  c.text:SetPoint("LEFT", 3, 0)
  c.text:SetPoint("RIGHT", -3, 0)
  c.text:SetWordWrap(false)
  c:Hide()

  function c:Start(channel)
    local name, st, et, _
    if channel then
      name, _, _, st, et = UnitChannelInfo("target")
    else
      name, _, _, st, et = UnitCastingInfo("target")
    end
    if not ns.Has(name) then return end
    ns.SetText(self.text, name)
    self:SetMinMaxValues(0, 1)
    local pst, pet = ns.Plain(st), ns.Plain(et)
    if pst and pet then
      self.cast = { st = pst / 1000, et = pet / 1000, channel = channel }
    else
      -- Secret times: let the client drive the bar if it can.
      self.cast = { timer = true }
      local durFn = channel and UnitChannelDuration or UnitCastingDuration
      local ok = false
      if durFn and self.SetTimerDuration then
        local got, obj = pcall(durFn, "target")
        if got and obj then ok = pcall(self.SetTimerDuration, self, obj) end
      end
      if not ok then self:SetValue(1) end
    end
    self:Show()
  end

  function c:Stop()
    self.cast = nil
    if not ns.editing then self:Hide() end
  end

  function c:Refresh()
    if ns.Has(UnitCastingInfo("target")) then
      self:Start(false)
    elseif ns.Has(UnitChannelInfo("target")) then
      self:Start(true)
    else
      self:Stop()
    end
  end

  c:SetScript("OnUpdate", function(self)
    local cast = self.cast
    if not cast or cast.timer then return end
    local now = GetTime()
    local dur = cast.et - cast.st
    local p = dur > 0 and (now - cast.st) / dur or 1
    if p >= 1.05 then
      self:Stop()
      return
    end
    if cast.channel then p = 1 - p end
    self:SetValue(math.max(0, math.min(1, p)))
  end)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    ns.SafeRegister(ev, e, "target")
  end
  ns.SafeRegister(ev, "PLAYER_TARGET_CHANGED")
  ev:SetScript("OnEvent", function(_, e)
    if e == "UNIT_SPELLCAST_START" or e == "UNIT_SPELLCAST_DELAYED" then
      c:Start(false)
    elseif e == "UNIT_SPELLCAST_CHANNEL_START" or e == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
      c:Start(true)
    else
      c:Refresh()
    end
  end)
  return c
end

function T:Build()
  local f = Create("ForeverUITargetFrame", "target")
  self.frame = f
  ns.AddHealPrediction(f, true)
  -- Your threat on this target, in a group: "Threat 72%" on the power bar.
  f.threatText = ns.NumText(f.pw, 9)
  f.threatText:SetPoint("LEFT", 4, 0)
  -- Combo points sit on the target, so they're shown there: a row under
  -- the power bar that only appears while the target has combo points.
  -- The panel grows, the cast bar and the visible target-of-target slide
  -- down with it. (Their secure click areas can't move in combat, so the
  -- target-of-target's is simply 8 px taller.)
  local extra = 0
  if ns.playerClass == "ROGUE" or ns.playerClass == "DRUID" then
    f.combo = ns.Pips(f.panel, 5, W - 10, 5, 1, 0.71, 0.23)
    f.combo:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 5, -54)
    f.combo:Hide()
    T.comboHere = true
    extra = COMBO_H
  end
  f:SetHeight(TH)
  f.panel:SetHeight(TH)
  f.tot = CreateToT(f, extra)
  f.cast = CreateTargetCast(f)
  ns.AddUnitIcons(f)
  RegisterUnitWatch(f)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION",
    "UNIT_CLASSIFICATION_CHANGED", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED" }) do
    ns.SafeRegister(ev, e, "target")
  end
  ns.SafeRegister(ev, "UNIT_THREAT_LIST_UPDATE", "target")
  ns.SafeRegister(ev, "UNIT_THREAT_SITUATION_UPDATE", "player")
  ns.SafeRegister(ev, "GROUP_ROSTER_UPDATE")
  ns.SafeRegister(ev, "PLAYER_TARGET_CHANGED")
  ev:SetScript("OnEvent", function() T:Update() end)
end

function T:UpdateCombo()
  local f = self.frame
  if not f or not f.combo then return end
  local cp
  if UnitExists("target") then
    if GetComboPoints then
      cp = GetComboPoints("player", "target")
    elseif Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
      cp = UnitPower("player", Enum.PowerType.ComboPoints)
    end
  end
  if ns.Has(cp) then f.combo:Set(cp, 1) else f.combo:Set(0, 1) end

  -- Show the row only with combo points on this target. A secret count
  -- can't be compared: then show it while you're in an energy form.
  local show
  local n = ns.Plain(cp)
  if n then
    show = n > 0
  elseif ns.IsSecret(cp) then
    show = ns.Plain(UnitPowerType("player")) == ENERGY
  else
    show = false
  end
  if show == self.comboShown then return end
  self.comboShown = show
  local dy = show and COMBO_H or 0
  f.combo:SetShown(show)
  f.panel:SetHeight(TH + dy)
  f.tot:SetShift(dy)
  f.cast:SetShift(dy)
end

function T:UpdateThreat()
  local f = self.frame
  local inGroup = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)
  local fn = UnitDetailedThreatSituation
  if not inGroup or not fn or not ns.Plain(UnitCanAttack("player", "target")) then
    f.threatText:SetText("")
    return
  end
  local ok, _, status, pct = pcall(fn, "player", "target")
  if not ok or not ns.Has(pct) then
    f.threatText:SetText("")
    return
  end
  local s = ns.Plain(status)
  if s and GetThreatStatusColor then
    f.threatText:SetTextColor(GetThreatStatusColor(s))
  else
    f.threatText:SetTextColor(1, 0.82, 0.3)
  end
  ns.SetFormatted(f.threatText, "Threat %.0f%%", pct)
end

function T:Update()
  local f = self.frame
  if not UnitExists("target") then return end
  ns.SetText(f.name, UnitName("target"))
  f.name:SetTextColor(1, 1, 1)

  local r, g, b = 0.05, 0.85, 0.1
  local reaction = ns.Plain(UnitReaction("target", "player"))
  if ns.Plain(UnitIsPlayer("target")) then
    r, g, b = ClassColor("target")
  elseif UnitIsTapDenied and ns.Plain(UnitIsTapDenied("target")) then
    r, g, b = 0.55, 0.55, 0.55
  elseif reaction and reaction <= 3 then
    r, g, b = 0.88, 0.35, 0.3
  elseif reaction == 4 then
    r, g, b = 0.95, 0.8, 0.3
  end
  f.hp:SetStatusBarColor(r, g, b)
  T:UpdateThreat()
  T:UpdateCombo()

  local level = UnitLevel("target")
  local plainLevel = ns.Plain(level)
  local class = ns.Plain(UnitClassification("target"))
  local suffix = (class == "elite" and "+") or (class == "rareelite" and " R+") or (class == "rare" and " R")
    or (class == "worldboss" and " Boss") or ""
  f.level:SetTextColor(1, 1, 1)
  if plainLevel and plainLevel > 0 then
    f.level:SetText(plainLevel .. suffix)
    local colorFn = GetCreatureDifficultyColor or GetQuestDifficultyColor
    local c = colorFn and colorFn(plainLevel)
    if c then f.level:SetTextColor(c.r, c.g, c.b) end
  elseif plainLevel then
    f.level:SetText("??" .. suffix)
    f.level:SetTextColor(1, 0.2, 0.2)
  else
    ns.SetFormatted(f.level, "%s%s", level, suffix)
  end
  UpdateHealth(f)
  UpdatePower(f)
end

-- Show placeholders while editing so everything can be placed without a target.
function T:OnEditMode(on)
  local f = self.frame
  if InCombatLockdown() then return end
  local t, c = f.tot, f.cast
  if on then
    UnregisterUnitWatch(f)
    UnregisterUnitWatch(t)
    f:Show()
    t:Show()
    if not UnitExists("target") then
      f.name:SetText("Target (preview)")
      f.level:SetText("")
      f.hpText:SetText("")
      f.hpPct:SetText("")
      f.pwText:SetText("")
    end
    if not UnitExists("targettarget") then t.name:SetText("Target of target") end
    if not c.cast then
      c.text:SetText("Target cast bar")
      c:SetMinMaxValues(0, 1)
      c:SetValue(0.6)
      c:Show()
    end
  else
    RegisterUnitWatch(f)
    RegisterUnitWatch(t)
    if not c.cast then c:Hide() end
    self:Update()
  end
end

-- Keep a Blizzard part invisible, even when Blizzard fades it back in.
local function KeepInvisible(part)
  if type(part) ~= "table" or not part.SetAlpha then return end
  part:SetAlpha(0)
  hooksecurefunc(part, "SetAlpha", function(self, a)
    if a and a > 0 then self:SetAlpha(0) end
  end)
end

-- Blizzard's aura icons, re-stacked on top of the Forever UI target frame:
-- debuffs in the row(s) right above it, buffs above those, rows growing
-- upward, no gaps. We never read the auras (the client forbids that in
-- combat); we only move the icon frames after Blizzard has updated them,
-- anchoring each to the previous one so no (secret) size is needed.
local PER_ROW, SPACING = 8, 3

-- What the last re-stack found; shown by /fui target info.
ns.targetIconDiag = { how = "not run yet", debuffs = 0, buffs = 0, runs = 0 }

local function ByTemplate(pools, template, list)
  local ok = pcall(function()
    local pool = pools.GetPool and pools:GetPool(template)
    if pool and pool.EnumerateActive then
      for icon in pool:EnumerateActive() do list[#list + 1] = icon end
    elseif pools.EnumerateActiveByTemplate then
      for icon in pools:EnumerateActiveByTemplate(template) do list[#list + 1] = icon end
    end
  end)
  return ok and #list > 0
end

-- Blizzard's icons, split into debuffs and buffs. Pools first (by template,
-- else all active icons told apart by the debuff border), then the old
-- numbered frames (TargetFrameDebuff1, TargetFrameBuff1, ...).
local function CollectIcons(tf)
  local debuffs, buffs, how = {}, {}, "none found"
  local pools = tf.auraPools
  if pools then
    local d = ByTemplate(pools, "TargetDebuffFrameTemplate", debuffs)
    local b = ByTemplate(pools, "TargetBuffFrameTemplate", buffs)
    if d or b then
      how = "pools by template"
    elseif pools.EnumerateActive then
      pcall(function()
        for icon in pools:EnumerateActive() do
          if icon.Border and not icon.Stealable then debuffs[#debuffs + 1] = icon else buffs[#buffs + 1] = icon end
        end
      end)
      if #debuffs + #buffs > 0 then how = "pools, all active" end
    end
  end
  if #debuffs + #buffs == 0 then
    for i = 1, 40 do
      local f = _G["TargetFrameDebuff" .. i]
      if f and f:IsShown() then debuffs[#debuffs + 1] = f end
      f = _G["TargetFrameBuff" .. i]
      if f and f:IsShown() then buffs[#buffs + 1] = f end
    end
    if #debuffs + #buffs > 0 then how = "numbered frames" end
  end
  -- Keep Blizzard's own order (it numbers the icons with SetID).
  local function byId(a, b) return a:GetID() < b:GetID() end
  pcall(table.sort, debuffs, byId)
  pcall(table.sort, buffs, byId)
  return debuffs, buffs, how
end

-- Lay out one group upward from `below`; returns the first icon of the top
-- row, so the next group can start above it.
local function Stack(icons, below, gap)
  local rowStart, prev
  for i, icon in ipairs(icons) do
    icon:ClearAllPoints()
    if i == 1 then
      icon:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, gap)
      rowStart = icon
    elseif (i - 1) % PER_ROW == 0 then
      icon:SetPoint("BOTTOMLEFT", rowStart, "TOPLEFT", 0, SPACING)
      rowStart = icon
    else
      icon:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", SPACING, 0)
    end
    prev = icon
  end
  return rowStart
end

local function Relayout()
  local tf, anchor = _G.TargetFrame, T.frame
  if not tf or not anchor then return end
  local debuffs, buffs, how = CollectIcons(tf)
  local top = Stack(debuffs, anchor, 5)
  if top then Stack(buffs, top, SPACING + 2) else Stack(buffs, anchor, 5) end
  local d = ns.targetIconDiag
  d.how, d.debuffs, d.buffs, d.runs = how, #debuffs, #buffs, d.runs + 1
end

-- Blizzard can place its icons again after UpdateAuras (a position pass or
-- a layout on the next frame), so re-stack right away and once more a frame
-- later.
local pending
local function RelayoutSoon()
  Relayout()
  if pending then return end
  pending = true
  C_Timer.After(0, function()
    pending = false
    Relayout()
  end)
end
ns.RelayoutTargetIcons = RelayoutSoon

function T:HideBlizzard()
  ns.HideBlizzard("ComboFrame", true)
  local tf = _G.TargetFrame
  if ns.profile.options.targetAuras ~= "blizzard" or not tf then
    ns.HideBlizzard("TargetFrame", true)
    ns.HideBlizzard("TargetFrameToT", true)
    return
  end
  -- Blizzard's frame keeps running for its buff/debuff icons only; its art,
  -- bars, texts, own ToT and cast bar go invisible, part by part. The icons
  -- live in TargetFrameContent.TargetFrameContentContextual.Auras, next to
  -- the leader/PvP/raid icons, so that container is never hidden as a whole.
  local content = tf.TargetFrameContent
  local contextual = content and content.TargetFrameContentContextual
  if contextual then
    for key, part in pairs(contextual) do
      if key ~= "Auras" and type(part) == "table" and part.SetAlpha then KeepInvisible(part) end
    end
  end
  for _, part in ipairs({
    tf.TargetFrameContainer,
    content and content.TargetFrameContentMain,
    tf.healthbar, tf.manabar, tf.name, tf.portrait, tf.totFrame, tf.spellbar, tf.TargetFrameSpellBar,
    tf.threatIndicator, tf.threatNumericIndicator, tf.TargetFramePowerBarAlt, tf.powerBarAlt,
    tf.healAbsorbBar, tf.myHealPredictionBar, tf.otherHealPredictionBar, tf.overAbsorbGlow,
    tf.overHealAbsorbGlow, tf.tempMaxHealthLossBar, tf.totalAbsorbBar,
  }) do
    KeepInvisible(part)
  end
  KeepInvisible(_G.TargetFrameToT)
  ns:AfterCombat("targetframe-mouse", function()
    tf:EnableMouse(false)
    if tf.totFrame then tf.totFrame:EnableMouse(false) end
  end)

  -- Re-stack the icons every time Blizzard updates or places them.
  for _, method in ipairs({ "UpdateAuras", "UpdateAuraPositions", "UpdateAuraFrames" }) do
    if type(tf[method]) == "function" then hooksecurefunc(tf, method, RelayoutSoon) end
  end
  for _, fn in ipairs({ "TargetFrame_UpdateAuras", "TargetFrame_UpdateAuraPositions" }) do
    if type(_G[fn]) == "function" then
      hooksecurefunc(fn, function(frame)
        if frame == tf then RelayoutSoon() end
      end)
    end
  end
  local auras = contextual and contextual.Auras
  if auras and type(auras.Layout) == "function" then hooksecurefunc(auras, "Layout", RelayoutSoon) end
  local ev = CreateFrame("Frame")
  ns.SafeRegister(ev, "PLAYER_TARGET_CHANGED")
  ns.SafeRegister(ev, "UNIT_AURA", "target")
  ev:SetScript("OnEvent", RelayoutSoon)
  RelayoutSoon()
end

-- Shared with Party.lua.
ns.UnitPercent = Percent
ns.ShortNumber = Short
ns.SetUnitBar = SetBar
ns.ClassColor = ClassColor
ns.PowerColors = POWER

