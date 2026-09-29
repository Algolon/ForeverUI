local ADDON, ns = ...
local LB = ns:NewModule("buffs", "Buffs", { pos = { p = "TOPRIGHT", rp = "TOPRIGHT", x = -222, y = -8 }, scale = 1, alpha = 1, fade = "always" })

function LB:IsEnabled()
  return ns.profile.options.playerAuras == "forever"
end

------------------------------------------------------------------------
-- Blizzard's own buff and debuff frames
------------------------------------------------------------------------
-- This client refuses every aura read to addons in combat (/fui diag shows
-- "40 refused"). Only Blizzard's frames can show auras then, so by default
-- they do the drawing. Their place, size and direction are set in
-- Blizzard's own HUD Edit Mode ("Buffs and Debuffs"). Forever UI no longer
-- moves them: two owners made them jump back after a reload, teleport or
-- opening Blizzard's Edit Mode. (Kept for reference, not registered.)
local function HostModule(key, label, global, pos)
  local m = ns:NewModule(key, label, { pos = pos, scale = 1, alpha = 1, fade = "always" })
  function m:IsEnabled()
    return ns.profile.options.playerAuras == "blizzard" and _G[global] ~= nil
  end
  function m:Build()
    self.frame = _G[global]
  end
  ns:On("EDIT_MODE_LAYOUTS_UPDATED", function()
    if m.frame then ns:AfterCombat("host" .. key, function() ns:ApplyLayout(m) end) end
  end)
  return m
end


-- Long buffs, top right next to the minimap. Procs and your forms are left
-- out: procs have their own row above the player frame, forms are on the
-- form bar.
--
-- Right-click cancels a buff. Cancelling is a protected action, so the
-- icons are secure buttons whose "index" attribute points at the aura.
-- Attributes can't change in combat; to never cancel the wrong buff,
-- cancelling is switched off from the moment combat starts until it ends.

local SIZE, GAP, ROW_H, PER_ROW, ROWS = 30, 4, 46, 12, 3
local MAX = PER_ROW * ROWS

local function OnEnter(self)
  if not self.hasAura then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  if self.auraInstanceID and GameTooltip.SetUnitAuraByAuraInstanceID then
    pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, "player", self.auraInstanceID)
  elseif self.index and GameTooltip.SetUnitAura then
    pcall(GameTooltip.SetUnitAura, GameTooltip, "player", self.index, "HELPFUL")
  end
  if not InCombatLockdown() then GameTooltip:AddLine("Right-click to cancel", 0.6, 0.63, 0.68) end
  GameTooltip:Show()
end

local function CreateButton(header, i)
  local b = CreateFrame("Button", "ForeverUIBuff" .. i, header, "SecureActionButtonTemplate")
  b:SetSize(SIZE, SIZE)
  local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
  b:SetPoint("TOPRIGHT", header, "TOPRIGHT", -col * (SIZE + GAP), -row * ROW_H)
  b:SetAttribute("type2", "cancelaura")
  b:SetAttribute("unit", "player")
  b:SetAttribute("filter", "HELPFUL")
  b:SetAttribute("fui-valid", false)
  b:SetAttribute("fui-keydown", ns.KeyDownPref())
  b:RegisterForClicks("RightButtonUp", "RightButtonDown")
  SecureHandlerWrapScript(b, "OnClick", header, [[
    if not self:GetAttribute("fui-valid") then return false end
    if self:GetAttribute("fui-keydown") then
      if not down then return false end
    elseif down then
      return false
    end
  ]])
  table.insert(ns.clickButtons, b)

  ns.Backdrop(b, 0.9)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ns.MaskIcon(b, b.icon)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  b.cd:SetReverse(true)
  b.cd.noCooldownCount = true
  if b.cd.SetDrawBling then b.cd:SetDrawBling(false) end
  local ov = CreateFrame("Frame", nil, b)
  ov:SetAllPoints()
  ov:SetFrameLevel(b.cd:GetFrameLevel() + 2)
  b.time = ns.NumText(ov, 10, "CENTER")
  b.time:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b.count = ns.NumText(ov, 10, "RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -1, 2)
  b:SetScript("OnEnter", OnEnter)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetAlpha(0)
  return b
end

function LB:Build()
  local header = CreateFrame("Frame", "ForeverUIBuffs", UIParent, "SecureHandlerBaseTemplate")
  header:SetSize(PER_ROW * (SIZE + GAP) - GAP, ROWS * ROW_H - (ROW_H - SIZE - 14))
  self.frame = header
  self.buttons = {}
  for i = 1, MAX do self.buttons[i] = CreateButton(header, i) end

  -- Weapon enchants (sharpening stones, oils, poisons), left of the buffs.
  self.enchants = {}
  for n = 1, 2 do
    local e = CreateFrame("Frame", nil, header)
    e:SetSize(SIZE, SIZE)
    e:SetPoint("TOPRIGHT", header, "TOPLEFT", -GAP - (n - 1) * (SIZE + GAP), 0)
    ns.Backdrop(e, 0.9)
    ns.BorderColor(e, 0.62, 0.35, 0.9, 1)
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetPoint("TOPLEFT", 1, -1)
    e.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.MaskIcon(e, e.icon)
    e.time = ns.NumText(e, 10, "CENTER")
    e.time:SetPoint("TOP", e, "BOTTOM", 0, -2)
    e.slot = n == 1 and 16 or 17
    e:EnableMouse(true)
    e:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
      GameTooltip:SetInventoryItem("player", self.slot)
      GameTooltip:Show()
    end)
    e:SetScript("OnLeave", GameTooltip_Hide)
    e:Hide()
    self.enchants[n] = e
  end

  local ev = CreateFrame("Frame")
  ns.SafeRegister(ev, "UNIT_AURA", "player")
  ns.SafeRegister(ev, "PLAYER_ENTERING_WORLD")
  ns.SafeRegister(ev, "PLAYER_REGEN_DISABLED")
  ns.SafeRegister(ev, "PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" then
      -- Last moment attributes may change: switch cancelling off.
      for _, b in ipairs(LB.buttons) do b:SetAttribute("fui-valid", false) end
      return
    end
    LB:Scan(e == "UNIT_AURA")
  end)

  local acc = 0
  ev:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.25 then return end
    acc = 0
    local now = GetTime()
    LB:UpdateEnchants()
    for _, b in ipairs(LB.buttons) do
      if b.hasAura and b.exp then
        local left = b.exp - now
        b.time:SetText(left > 0 and ns.FormatTime(left) or "")
      end
    end
  end)
  self:Scan(false)
end

function LB:Scan(keep)
  local auras, blocked = ns.ReadAuras("player", "HELPFUL")
  if keep and blocked > 0 and #auras == 0 then return end
  local forms = ns.FormSpellIds and ns.FormSpellIds() or {}
  local list = {}
  for _, a in ipairs(auras) do
    local id = ns.Plain(a.d.spellId)
    local inst = ns.Plain(a.d.auraInstanceID)
    local inProcs = (id and ns.procShown and ns.procShown[id]) or (inst and ns.procShownInst and ns.procShownInst[inst])
    if not (id and forms[id]) and not inProcs and #list < MAX then list[#list + 1] = a end
  end

  local canSet = not InCombatLockdown()
  for i, b in ipairs(self.buttons) do
    local a = list[i]
    if a then
      local d = a.d
      pcall(b.icon.SetTexture, b.icon, d.icon)
      ns.SetAuraCount(b, d, "player")
      ns.SetAuraCooldown(b, d, "player")
      b.time:SetText("")
      b.index, b.auraInstanceID, b.hasAura = a.index, ns.Plain(d.auraInstanceID), true
      b:SetAlpha(1)
      if canSet then
        b:SetAttribute("index", a.index)
        b:SetAttribute("fui-valid", true)
      end
    else
      b.hasAura, b.exp = false, nil
      b:SetAlpha(0)
      if canSet then b:SetAttribute("fui-valid", false) end
    end
  end
end

function LB:UpdateEnchants()
  if not GetWeaponEnchantInfo then return end
  local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()
  local data = { { ns.Plain(hasMH), ns.Plain(mhExp) }, { ns.Plain(hasOH), ns.Plain(ohExp) } }
  local shown = 0
  for n, e in ipairs(self.enchants) do
    local has, exp = data[n][1], data[n][2]
    if has then
      shown = shown + 1
      e:ClearAllPoints()
      e:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -GAP - (shown - 1) * (SIZE + GAP), 0)
      e.icon:SetTexture(GetInventoryItemTexture("player", e.slot))
      e.time:SetText(exp and ns.FormatTime(exp / 1000) or "")
      e:Show()
    else
      e:Hide()
    end
  end
end

function LB:OnEditMode(on)
  if on then
    for i = 1, PER_ROW do self.buttons[i]:SetAlpha(1) end
  else
    self:Scan(false)
  end
end

function LB:HideBlizzard()
  -- Part of Blizzard's Edit Mode: hide in place.
  ns.HideBlizzard("BuffFrame", false, true)
  ns.HideBlizzard("TemporaryEnchantFrame")
end
