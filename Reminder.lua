local ADDON, ns = ...
local BR = ns:NewModule("reminder", "Buff Reminder", { pos = { p = "CENTER", rp = "CENTER", x = 0, y = -150 }, scale = 1, alpha = 1, fade = "always" })

-- Out of combat: a pulsing icon for each of your own long buffs that is
-- missing or about to run out. Click it to cast. Hidden in combat (the
-- buttons are secure; a state driver hides them, so nothing is changed
-- while the client forbids it). Auras can be read out of combat.

local SIZE, GAP, MAX = 36, 8, 3
local SOON = 30 -- seconds left that count as "about to run out"

-- Each entry is satisfied by any of its spells; the last one you know is
-- cast (so Mage Armor beats Ice Armor beats Frost Armor).
local BY_CLASS = {
  DRUID = { { 1126 }, { 467 } },                   -- Mark of the Wild, Thorns
  PRIEST = { { 1243 }, { 588 } },                  -- Power Word: Fortitude, Inner Fire
  MAGE = { { 1459 }, { 168, 7302, 6117 } },        -- Arcane Intellect, Frost/Ice/Mage Armor
  WARLOCK = { { 687, 706 } },                      -- Demon Skin / Demon Armor
  SHAMAN = { { 324 } },                            -- Lightning Shield
  HUNTER = { { 13165, 13163, 5118, 13159, 20043 } }, -- any Aspect
}

function BR:IsEnabled()
  return BY_CLASS[ns.playerClass] ~= nil
end

-- Passive spells (on this client Omen of Clarity is a talent that simply
-- procs, not a buff you cast) never need a reminder.
local function Passive(id)
  local fn = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
  if not fn then return false end
  local ok, v = pcall(fn, id)
  return ok and ns.Plain(v) and true or false
end

local function Known(id)
  if Passive(id) then return false end
  if IsPlayerSpell and ns.Plain(IsPlayerSpell(id)) then return true end
  if IsSpellKnown and ns.Plain(IsSpellKnown(id)) then return true end
  return false
end

-- nil: not present (or too short); true: fine.
local function Present(name)
  local d
  local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if fn then
    local ok, v = pcall(fn, "player", name, "HELPFUL")
    if ok then d = v end
  else
    for _, a in ipairs((ns.ReadAuras("player", "HELPFUL"))) do
      if ns.Plain(a.d.name) == name then d = a.d break end
    end
  end
  if not d then return nil end
  local exp, dur = ns.Plain(d.expirationTime), ns.Plain(d.duration)
  if exp and dur and dur > 0 and exp - GetTime() < SOON then return nil end
  return true
end

function BR:Build()
  local f = CreateFrame("Frame", "ForeverUIBuffReminder", UIParent, "SecureHandlerStateTemplate")
  f:SetSize(MAX * SIZE + (MAX - 1) * GAP, SIZE + 14)
  self.frame = f
  RegisterStateDriver(f, "visibility", "[combat] hide; show")
  self.buttons = {}
  for i = 1, MAX do
    local b = CreateFrame("Button", "ForeverUIBuffReminder" .. i, f, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOP", f, "TOP", (i - (MAX + 1) / 2) * (SIZE + GAP), 0)
    b:SetAttribute("type", "macro")
    -- Same click handling as the action bars (fires on the press or the
    -- release, whichever the client's "cast on key down" setting wants).
    ns.SetupClicks(b, f)
    ns.Backdrop(b, 0.6)
    ns.BorderColor(b, 1, 0.82, 0.3, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.MaskIcon(b, b.icon)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.spellName or "")
      GameTooltip:AddLine("Missing or running out. Click to cast.", 0.8, 0.82, 0.86)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- Gentle pulse so it gets noticed without shouting.
    local ag = b:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.55)
    a:SetDuration(0.9)
    ag:Play()
    b:Hide()
    self.buttons[i] = b
  end
  f.label = ns.Text(f, 10, "CENTER")
  f.label:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
  f.label:SetTextColor(1, 0.82, 0.3)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
    ns.SafeRegister(ev, e)
  end
  ns.SafeRegister(ev, "UNIT_AURA", "player")
  ev:SetScript("OnEvent", function() BR:Update() end)
  local acc = 0
  ev:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 5 then return end
    acc = 0
    BR:Update()
  end)
  self:Update()
end

function BR:Update()
  if InCombatLockdown() or ns.editing then return end
  local missing = {}
  local quiet = not ns.profile.options.reminder or ns.Plain(UnitIsDeadOrGhost("player"))
    or (UnitOnTaxi and ns.Plain(UnitOnTaxi("player")))
  if not quiet then
    for _, entry in ipairs(BY_CLASS[ns.playerClass]) do
      local best, have
      for _, id in ipairs(entry) do
        local name = ns.SpellName(id)
        if name and Known(id) then
          best = name
          if Present(name) then have = true end
        end
      end
      if best and not have then missing[#missing + 1] = best end
    end
  end
  for i, b in ipairs(self.buttons) do
    local name = missing[i]
    if name then
      b.spellName = name
      -- A macro, like the form bar's buttons (those cast fine here).
      b:SetAttribute("macrotext", "/cast [@player] " .. name)
      local tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(name)) or (GetSpellTexture and GetSpellTexture(name))
      pcall(b.icon.SetTexture, b.icon, tex)
      b:Show()
    else
      b:Hide()
    end
  end
  self.frame.label:SetText(#missing > 0 and "Buff missing" or "")
end

-- Edit Mode: show a placeholder so it can be placed.
function BR:OnEditMode(on)
  if InCombatLockdown() then return end
  local b = self.buttons[1]
  if on then
    b.spellName = "Buff Reminder"
    pcall(b.icon.SetTexture, b.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
    b:Show()
  else
    self:Update()
  end
end
