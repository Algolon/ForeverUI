local ADDON, ns = ...
local PT = ns:NewModule("party", "Party", { pos = { p = "LEFT", rp = "LEFT", x = 12, y = 80 }, scale = 1, alpha = 1, fade = "always",
  w = 170, h = 40 })

-- Four compact party frames, left of centre. Each shows:
--   * a coloured border when the member has a debuff YOU can remove
--     (the "HARMFUL|RAID" filter asks the client for exactly that)
--   * your own Rejuvenation and Regrowth as small icons, top right
--   * dimmed when out of range
--   * role (tank/healer/damage), ready check, AFK/DND and a threat glow
-- All lookups use filters and spell names, so nothing compares secret values.

local W, H, GAP = 170, 40, 6 -- W and H: defaults, the profile can change them
PT.sizeRange = { w = { 110, 260 }, h = { 30, 70 } }

local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
  TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
  HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
  DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local READY_TEX = {
  ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
  notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0.2, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }
local HOTS = { 774, 8936 } -- Rejuvenation, Regrowth (names are looked up once)

local function AuraByName(unit, name, filter)
  local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if fn then
    local ok, d = pcall(fn, unit, name, filter)
    if ok then return d end
    return nil
  end
  for _, a in ipairs((ns.ReadAuras(unit, filter))) do
    if ns.Plain(a.d.name) == name then return a.d end
  end
end

local function CreateMember(parent, i)
  local unit = "party" .. i
  local f = CreateFrame("Button", "ForeverUIParty" .. i, parent, "SecureUnitButtonTemplate")
  f.unit = unit
  f:SetAttribute("unit", unit)
  f:SetAttribute("*type1", "target")
  f:SetAttribute("*type2", "togglemenu")
  f:RegisterForClicks("AnyUp")
  f:SetScript("OnEnter", function(self)
    if not UnitExists(self.unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(self.unit)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)

  -- Threat: a soft coloured glow around the frame (yellow → red).
  f.threat = f:CreateTexture(nil, "BACKGROUND")
  f.threat:SetPoint("TOPLEFT", -3, 3)
  f.threat:SetPoint("BOTTOMRIGHT", 3, -3)
  f.threat:SetColorTexture(1, 0, 0, 0.45)
  f.threat:Hide()

  local p = CreateFrame("Frame", nil, f)
  p:SetAllPoints()
  ns.Backdrop(p, 0.58)
  f.panel = p

  f.role = p:CreateTexture(nil, "OVERLAY")
  f.role:SetTexture(ROLE_TEX)
  f.role:SetSize(12, 12)
  f.role:SetPoint("TOPLEFT", 4, -4)
  f.role:Hide()

  f.tag = ns.Text(p, 10)
  f.tag:SetTextColor(0.6, 0.63, 0.68)
  f.tag:SetPoint("TOPRIGHT", p, "TOPRIGHT", -34, -5)

  f.name = ns.Text(p, 11)
  f.name:SetPoint("TOPLEFT", 5, -4)
  f.name:SetPoint("RIGHT", f.tag, "LEFT", -4, 0)
  f.name:SetHeight(12)
  f.name:SetWordWrap(false)

  -- Ready check, big in the middle while it runs.
  f.ready = p:CreateTexture(nil, "OVERLAY", nil, 7)
  f.ready:SetSize(22, 22)
  f.ready:SetPoint("CENTER", p, "CENTER", 0, -4)
  f.ready:Hide()

  f.hp = ns.Bar(p, 14)
  f.hp:SetPoint("TOPLEFT", 4, -18)
  f.hp:SetPoint("TOPRIGHT", -4, -18)
  f.hpText = ns.NumText(f.hp, 10, "RIGHT")
  f.hpText:SetPoint("RIGHT", -3, 0)
  ns.AddHealPrediction(f)
  f.pw = ns.Bar(p, 3)
  f.pw:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -2)
  f.pw:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -2)

  -- Your HoTs on this member.
  f.hots = {}
  for h = 1, #HOTS do
    local t = p:CreateTexture(nil, "OVERLAY")
    t:SetSize(12, 12)
    t:SetPoint("TOPRIGHT", p, "TOPRIGHT", -3 - (h - 1) * 14, -3)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:Hide()
    f.hots[h] = t
  end

  ns.AddUnitIcons(f)
  RegisterUnitWatch(f)
  return f
end

-- Width and height come from the profile (Edit Mode: select Party). Secure
-- frames, so only out of combat.
function PT:ApplySize()
  local c = self.frame
  if not c then return end
  ns:AfterCombat("party-size", function()
    local s = ns:M("party")
    local w, h = s.w or W, s.h or H
    c:SetSize(w, 4 * h + 3 * GAP)
    for i, f in ipairs(self.members) do
      f:SetSize(w, h)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(i - 1) * (h + GAP))
      f.hp:SetHeight(math.max(h - 26, 6))
    end
  end)
end

function PT:Build()
  local c = CreateFrame("Frame", "ForeverUIPartyFrames", UIParent)
  self.frame = c
  self.members = {}
  for i = 1, 4 do self.members[i] = CreateMember(c, i) end
  self:ApplySize()
  self.hotNames = {}
  for h, id in ipairs(HOTS) do self.hotNames[h] = ns.SpellName(id) end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA",
    "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
    "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "PLAYER_FLAGS_CHANGED", "PLAYER_ROLES_ASSIGNED",
    "UNIT_THREAT_SITUATION_UPDATE", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
    ns.SafeRegister(ev, e)
  end
  ev:SetScript("OnEvent", function(_, e, unit)
    if e == "READY_CHECK" or e == "READY_CHECK_CONFIRM" then
      for n = 1, 4 do PT:UpdateReady(n) end
      return
    elseif e == "READY_CHECK_FINISHED" then
      -- Leave the result up for a moment, like Blizzard does.
      C_Timer.After(6, function() for n = 1, 4 do PT.members[n].ready:Hide() end end)
      return
    end
    local i = type(unit) == "string" and tonumber(unit:match("^party(%d)$"))
    if i then
      if e == "UNIT_AURA" then PT:UpdateAuras(i) else PT:Update(i) end
    elseif not unit or e == "GROUP_ROSTER_UPDATE" or e == "PARTY_MEMBERS_CHANGED" or e == "PLAYER_ENTERING_WORLD" then
      PT:UpdateAll()
    end
  end)

  local acc = 0
  ev:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.5 then return end
    acc = 0
    for n = 1, 4 do PT:UpdateRange(n) end
  end)
  self:UpdateAll()
end

function PT:UpdateAll()
  for i = 1, 4 do
    self:Update(i)
    self:UpdateAuras(i)
    self:UpdateRange(i)
  end
end

function PT:Update(i)
  local f = self.members[i]
  local u = f.unit
  if not UnitExists(u) then return end
  ns.SetText(f.name, UnitName(u))
  f.name:SetTextColor(ns.ClassColor(u))
  f.hp:SetStatusBarColor(0.05, 0.85, 0.1)
  ns.SetUnitBar(f.hp, UnitHealth(u), UnitHealthMax(u))
  ns.UpdateHealPrediction(f)

  if ns.Plain(UnitIsConnected(u)) == false then
    f.hpText:SetText("Offline")
  elseif ns.Plain(UnitIsDeadOrGhost(u)) then
    f.hpText:SetText("Dead")
  else
    local pct = ns.UnitPercent(u)
    if ns.Has(pct) then ns.SetFormatted(f.hpText, "%.0f%%", pct) else f.hpText:SetText("") end
  end

  local pt = ns.Plain(UnitPowerType(u)) or 0
  local c = ns.PowerColors[pt] or ns.PowerColors[0]
  f.pw:SetStatusBarColor(c[1], c[2], c[3])
  ns.SetUnitBar(f.pw, UnitPower(u, pt), UnitPowerMax(u, pt))

  -- Role: tank / healer / damage icon before the name.
  local role = UnitGroupRolesAssigned and ns.Plain(UnitGroupRolesAssigned(u))
  local rc = role and ROLE_COORDS[role]
  f.name:ClearAllPoints()
  if rc then
    f.role:SetTexCoord(rc[1], rc[2], rc[3], rc[4])
    f.role:Show()
    f.name:SetPoint("TOPLEFT", f.role, "TOPRIGHT", 3, 0)
  else
    f.role:Hide()
    f.name:SetPoint("TOPLEFT", 5, -4)
  end
  f.name:SetPoint("RIGHT", f.tag, "LEFT", -4, 0)

  -- AFK / DND.
  if ns.Plain(UnitIsAFK(u)) then
    f.tag:SetText("AFK")
  elseif ns.Plain(UnitIsDND(u)) then
    f.tag:SetText("DND")
  else
    f.tag:SetText("")
  end

  ns.UpdateThreatGlow(f, u)
end

function PT:UpdateReady(i)
  local f = self.members[i]
  local status = UnitExists(f.unit) and GetReadyCheckStatus and ns.Plain(GetReadyCheckStatus(f.unit))
  local tex = status and READY_TEX[status]
  if tex then
    f.ready:SetTexture(tex)
    f.ready:Show()
  else
    f.ready:Hide()
  end
end

function PT:UpdateAuras(i)
  local f = self.members[i]
  local u = f.unit
  if not UnitExists(u) then return end

  -- Border: a debuff you can remove.
  local dispellable = ns.ReadAuras(u, "HARMFUL|RAID")
  local first = dispellable[1]
  if first then
    local dt = ns.Plain(first.d.dispelName)
    local col = (dt and DISPEL[dt]) or { 0.8, 0.3, 1 }
    ns.BorderColor(f.panel, col[1], col[2], col[3], 1)
  else
    ns.ResetBorder(f.panel)
  end

  -- Your HoTs.
  for h, t in ipairs(f.hots) do
    local name = self.hotNames[h]
    local d = name and AuraByName(u, name, "HELPFUL|PLAYER")
    if d then
      pcall(t.SetTexture, t, d.icon)
      t:Show()
    else
      t:Hide()
    end
  end
end

function PT:UpdateRange(i)
  local f = self.members[i]
  if not UnitExists(f.unit) or not UnitInRange then
    f.panel:SetAlpha(1)
    return
  end
  local inRange, checked = UnitInRange(f.unit)
  inRange, checked = ns.Plain(inRange), ns.Plain(checked)
  if checked and inRange == false then f.panel:SetAlpha(0.45) else f.panel:SetAlpha(1) end
end

-- Placeholders so the frames can be placed without a group.
function PT:OnEditMode(on)
  if InCombatLockdown() then return end
  for i, f in ipairs(self.members) do
    if on then
      UnregisterUnitWatch(f)
      f:Show()
      if not UnitExists(f.unit) then
        f.name:SetText("Party " .. i)
        f.name:SetTextColor(1, 1, 1)
        f.hpText:SetText("")
        f.tag:SetText("")
        f.role:Hide()
      end
    else
      RegisterUnitWatch(f)
    end
  end
  if not on then self:UpdateAll() end
end

function PT:HideBlizzard()
  -- PartyFrame / CompactPartyFrame belong to Blizzard's Edit Mode: hide in place.
  ns.HideBlizzard("PartyFrame", false, true)
  ns.HideBlizzard("CompactPartyFrame", false, true)
  for i = 1, 4 do ns.HideBlizzard("PartyMemberFrame" .. i, true) end
  ns.HideBlizzard("PartyMemberBackground")
end
