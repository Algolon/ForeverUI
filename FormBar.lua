local ADDON, ns = ...
local FB = ns:NewModule("forms", "Form Bar", { pos = { p = "BOTTOM", rp = "BOTTOM", x = 0, y = 102 }, scale = 1, alpha = 1, fade = "always" })
local SIZE, GAP, MAX = 32, 5, 10
local CAT, BEAR, DIRE_BEAR = 768, 5487, 9634

-- Returns: icon, active, castable, spellID, name.
-- Old clients return (icon, name, active, castable); newer ones
-- (icon, active, castable, spellID). Handle both.
local function FormInfo(i)
  local a, b, c, d = GetShapeshiftFormInfo(i)
  if type(b) == "string" then return a, c, d, nil, b end
  return a, b, c, d, d and ns.SpellName(d)
end

-- Mana cost of one shift (the active form, otherwise Cat). Mana itself may
-- be secret, so we never divide by it; ns.Pips shows the shifts instead.
function ns.ShiftCost()
  if not ns.isDruid then return nil end
  local cost
  for i = 1, (GetNumShapeshiftForms() or 0) do
    local _, active, _, spellID = FormInfo(i)
    if ns.Plain(active) and spellID then cost = ns.PowerCost(spellID, 0) end
  end
  return cost or ns.PowerCost(CAT, 0) or ns.PowerCost(DIRE_BEAR, 0) or ns.PowerCost(BEAR, 0)
end

function FB:Build()
  local header = CreateFrame("Frame", "ForeverUIFormBar", UIParent, "SecureHandlerStateTemplate")
  header:SetSize(SIZE, SIZE)
  self.frame = header
  self.buttons = {}

  for i = 1, MAX do
    local b = CreateFrame("Button", "ForeverUIFormButton" .. i, header, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", header, "LEFT", (i - 1) * (SIZE + GAP), 0)
    b:SetID(i)
    b:SetAttribute("type", "macro")
    ns.Backdrop(b, 0.45)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.MaskIcon(b, b.icon)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    local ov = CreateFrame("Frame", nil, b)
    ov:SetAllPoints()
    ov:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.active = ov:CreateTexture(nil, "OVERLAY")
    b.active:SetAllPoints(b.icon)
    b.active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    b.active:SetBlendMode("ADD")
    b.active:Hide()
    b.hotkey = ns.NumText(ov, 9, "RIGHT")
    b.hotkey:SetPoint("TOPRIGHT", -2, -3)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetColorTexture(1, 1, 1, 0.15)
    ns.SetupClicks(b, header)
    b:SetScript("OnEnter", function(self)
      GameTooltip_SetDefaultAnchor(GameTooltip, self)
      GameTooltip:SetShapeshift(self:GetID())
      GameTooltip:AddLine("Shift-click: powershift (leave the form and shift straight back)", 0.56, 0.72, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:Hide()
    self.buttons[i] = b
  end

  -- Six pips: each one is a shift your current mana can pay for.
  self.shifts = ns.Pips(header, 6, 60, 6, 0.56, 0.72, 1)
  self.shifts:SetPoint("LEFT", header, "RIGHT", 10, 0)
  self.shifts.label = ns.Text(self.shifts, 10)
  self.shifts.label:SetPoint("LEFT", self.shifts, "RIGHT", 6, 0)
  self.shifts.label:SetText("shifts")
  self.shifts.label:SetTextColor(0.56, 0.72, 1)
  self.shifts:Hide()
  table.insert(ns.bindables, { buttons = self.buttons, prefix = "SHAPESHIFTBUTTON" })

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "LEARNED_SPELL_IN_TAB" }) do
    ns.SafeRegister(ev, e)
  end
  ns.SafeRegister(ev, "UNIT_POWER_FREQUENT", "player")
  ns.SafeRegister(ev, "UNIT_MAXPOWER", "player")
  ev:SetScript("OnEvent", function(_, e)
    if e == "UPDATE_SHAPESHIFT_FORMS" or e == "SPELLS_CHANGED" or e == "PLAYER_ENTERING_WORLD" or e == "LEARNED_SPELL_IN_TAB" then
      FB:Setup()
    elseif e == "UPDATE_SHAPESHIFT_COOLDOWN" or e == "UPDATE_SHAPESHIFT_FORM" then
      FB:UpdateCooldowns()
    end
    FB:Update()
  end)
  self:Setup()
end

-- Attributes and Show/Hide are protected in combat, so this waits if needed.
function FB:Setup()
  if InCombatLockdown() then
    ns:AfterCombat("forms-setup", function() FB:Setup() end)
    return
  end
  local n = math.min(GetNumShapeshiftForms() or 0, MAX)
  for i, b in ipairs(self.buttons) do
    local _, _, _, _, name = FormInfo(i)
    if i <= n and name then
      b:SetAttribute("macrotext", "/cast " .. name)
      b:SetAttribute("shift-macrotext1", "/cancelform\n/cast " .. name)
      b:Show()
    else
      b:Hide()
    end
  end
  self.count = n
  self.frame:SetSize(math.max(n, 1) * (SIZE + GAP) - GAP, SIZE)
  self:Update()
  self:UpdateCooldowns()
end

function FB:Update()
  for i = 1, (self.count or 0) do
    local b = self.buttons[i]
    local icon, active, castable = FormInfo(i)
    active, castable = ns.Plain(active), ns.Plain(castable)
    b.icon:SetTexture(icon)
    local v = castable == false and 0.4 or 1
    b.icon:SetVertexColor(v, v, v)
    b.active:SetShown(active and true or false)
    if active then ns.BorderColor(b, 1, 0.9, 0.6, 1) else ns.ResetBorder(b) end
  end
  -- The shift count lives on the player frame (under your mana while
  -- shifted); this row next to the form buttons stays hidden.
  self.shifts:Hide()
end

-- Only on cooldown events, so a running swipe is never restarted.
function FB:UpdateCooldowns()
  for i = 1, (self.count or 0) do
    local b = self.buttons[i]
    local _, _, _, spellID = FormInfo(i)
    local api = C_Spell
    if not (spellID and api and ns.ActionBars.FromDurationObject(b.cd, api.GetSpellCooldownDuration, spellID)) then
      local start, dur = GetShapeshiftFormCooldown(i)
      if not ns.ActionBars.SetCooldown(b.cd, start, dur) then b.cd:Hide() end
    end
  end
end

function FB:HideBlizzard()
  ns.HideBlizzard("StanceBarFrame")
  ns.HideBlizzard("StanceBar")
end

-- Spell IDs of the forms you know (their buffs stay off the buff row).
function ns.FormSpellIds()
  local ids = {}
  for i = 1, (GetNumShapeshiftForms() or 0) do
    local _, _, _, spellID = FormInfo(i)
    if spellID then ids[spellID] = true end
  end
  return ids
end
