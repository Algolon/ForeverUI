local ADDON, ns = ...
local AB = {}
ns.ActionBars = AB
AB.buttons = {}
AB.glowNames = {}

-- Action slots follow Blizzard's layout, so whatever is on your bars now
-- shows up here unchanged: page 1 = slots 1-12, Bottom Left = 61-72,
-- Bottom Right = 49-60, Right = 25-36, Left = 37-48. Key bindings are
-- Blizzard's too.
local BARS = {
  { key = "ab1", label = "Action Bar 1 (form paging)", name = "ForeverUIBar1", first = 1, n = 12, cols = 12, size = 36, gap = 4,
    paging = true, binding = "ACTIONBUTTON", blizzard = { "MainMenuBar", "MainActionBar" },
    pos = { p = "BOTTOM", rp = "BOTTOM", x = 0, y = 14 } },
  { key = "ab2", label = "Action Bar 2", name = "ForeverUIBar2", first = 61, n = 12, cols = 12, size = 36, gap = 4,
    binding = "MULTIACTIONBAR1BUTTON", blizzard = { "MultiBarBottomLeft" },
    pos = { p = "BOTTOM", rp = "BOTTOM", x = 0, y = 58 } },
  -- Bars 3 and 4: 2x6 grids to the right and left of the main bars.
  { key = "ab3", label = "Action Bar 3", name = "ForeverUIBar3", first = 49, n = 12, cols = 6, size = 36, gap = 4,
    binding = "MULTIACTIONBAR2BUTTON", blizzard = { "MultiBarBottomRight" }, optional = "bar3",
    pos = { p = "BOTTOMLEFT", rp = "BOTTOM", x = 246, y = 14 } },
  { key = "ab4", label = "Action Bar 4", name = "ForeverUIBar4", first = 37, n = 12, cols = 6, size = 36, gap = 4,
    binding = "MULTIACTIONBAR4BUTTON", blizzard = { "MultiBarLeft" }, optional = "bar4",
    pos = { p = "BOTTOMRIGHT", rp = "BOTTOM", x = -246, y = 14 } },
  { key = "util", label = "Utility Bar", name = "ForeverUIUtilBar", first = 25, n = 12, cols = 1, size = 32, gap = 4,
    binding = "MULTIACTIONBAR3BUTTON", blizzard = { "MultiBarRight" }, fade = "mouseover", optional = "util",
    pos = { p = "RIGHT", rp = "RIGHT", x = -6, y = 0 } },
}

-- Which page bar 1 shows. Manual paging (Shift+1..6) wins, then forms.
function ns.PageDriver()
  local d = "[actionbar:2] 2; [actionbar:3] 3; [actionbar:4] 4; [actionbar:5] 5; [actionbar:6] 6; [bonusbar:5] 11; "
  if ns.isDruid then
    d = d .. "[bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10; "
  else
    d = d .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "
  end
  return d .. "1"
end

------------------------------------------------------------------------
-- Cooldowns
------------------------------------------------------------------------
-- On this client cooldown numbers are secret. The old SetCooldown(start,
-- duration) refuses secrets, so we prefer the client's duration objects,
-- which the Cooldown widget reads directly. ns.cooldownPath records which
-- route works, for /fui diag.
ns.cooldownPath = "none yet"

local function LegacyCooldown(action)
  if GetActionCooldown then return GetActionCooldown(action) end
  if C_ActionBar and C_ActionBar.GetActionCooldown then
    local info = C_ActionBar.GetActionCooldown(action)
    if info then return info.startTime, info.duration end
  end
end

-- Plain start/duration (or secrets, if the widget accepts them).
function AB.SetCooldown(cd, start, duration)
  if not ns.IsSecret(start) and start == nil then start = 0 end
  if not ns.IsSecret(duration) and duration == nil then duration = 0 end
  if pcall(cd.SetCooldown, cd, start, duration) then
    cd:Show()
    return true
  end
  return false
end

local function FromDurationObject(cd, getter, ...)
  if not getter or not cd.SetCooldownFromDurationObject then return false end
  local ok, obj = pcall(getter, ...)
  if not ok then return false end
  if obj == nil then
    if cd.Clear then cd:Clear() else cd:Hide() end
    return true
  end
  if pcall(cd.SetCooldownFromDurationObject, cd, obj) then
    cd:Show()
    return true
  end
  return false
end

AB.FromDurationObject = FromDurationObject

function AB.ApplyActionCooldown(cd, action)
  local api = C_ActionBar
  if api and FromDurationObject(cd, api.GetActionCooldownDuration, action) then
    ns.cooldownPath = "duration object"
    return
  end
  local start, duration = LegacyCooldown(action)
  if AB.SetCooldown(cd, start, duration) then
    ns.cooldownPath = ns.IsSecret(duration) and "SetCooldown (secret)" or "SetCooldown"
  else
    ns.cooldownPath = "not available (secret)"
    cd:Hide()
  end
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
local function OnDragStart(self)
  if InCombatLockdown() then return end
  if ns.CVarBool("lockActionBars") and not IsModifiedClick("PICKUPACTION") then return end
  PickupAction(self:GetAttribute("action"))
  AB.dirty, AB.cdDirty = true, true
end

local function OnReceiveDrag(self)
  if InCombatLockdown() then return end
  PlaceAction(self:GetAttribute("action"))
  AB.dirty, AB.cdDirty = true, true
end

local function OnEnter(self)
  local action = self:GetAttribute("action")
  if not action or not HasAction(action) then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  GameTooltip:SetAction(action)
  GameTooltip:Show()
end

local function CreateButton(parent, name, index, slot, size)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  b:SetAttribute("type", "action")
  b:SetAttribute("action", slot)
  b:SetAttribute("index", index)
  b:SetAttribute("checkselfcast", true)
  b:SetAttribute("checkfocuscast", true)
  b:SetAttribute("fui-dragguard", true)
  ns.Backdrop(b, 0.45)

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ns.MaskIcon(b, icon)
  b.icon = icon

  local cd = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
  cd:SetAllPoints(icon)
  if cd.SetDrawBling then cd:SetDrawBling(false) end
  b.cd = cd

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(icon)
  hl:SetColorTexture(1, 1, 1, 0.15)
  ns.MaskIcon(b, hl)

  -- Texts and glows sit above the cooldown swipe.
  local ov = CreateFrame("Frame", nil, b)
  ov:SetAllPoints()
  ov:SetFrameLevel(cd:GetFrameLevel() + 2)
  b.active = ov:CreateTexture(nil, "OVERLAY")
  b.active:SetAllPoints(icon)
  b.active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  b.active:SetBlendMode("ADD")
  b.active:Hide()
  b.glow = ov:CreateTexture(nil, "OVERLAY", nil, 2)
  b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.glow:SetBlendMode("ADD")
  b.glow:SetVertexColor(1, 0.85, 0.35)
  b.glow:SetSize(size * 1.9, size * 1.9)
  b.glow:SetPoint("CENTER")
  b.glow:Hide()
  b.hotkey = ns.NumText(ov, 10, "RIGHT")
  b.hotkey:SetPoint("TOPRIGHT", -2, -3)
  b.count = ns.NumText(ov, 11, "RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -2, 3)

  b:RegisterForDrag("LeftButton", "RightButton")
  b:SetScript("OnDragStart", OnDragStart)
  b:SetScript("OnReceiveDrag", OnReceiveDrag)
  b:SetScript("OnEnter", OnEnter)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("PostClick", function() AB.dirty = true end)
  b:HookScript("OnAttributeChanged", function(_, attr)
    -- A new page means a new slot: refresh everything, including cooldowns.
    if attr == "action" then AB.dirty, AB.cdDirty = true, true end
  end)
  return b
end

function AB.ShouldGlow(action)
  if not ns.clearcasting then return false end
  local kind, id = GetActionInfo(action)
  if kind ~= "spell" then return false end
  local name = ns.SpellName(ns.Plain(id))
  return name and AB.glowNames[name] or false
end

local function HasIcon(b)
  local action = b:GetAttribute("action")
  local tex = action and GetActionTexture(action)
  return ns.IsSecret(tex) or tex ~= nil, action, tex
end

-- Cooldowns are only touched when the game says they changed, so a
-- running swipe is never reset mid-animation.
function AB.UpdateCooldown(b)
  local has, action = HasIcon(b)
  if has then AB.ApplyActionCooldown(b.cd, action) else b.cd:Hide() end
end

-- Everything else (range, usable, stacks, highlights) refreshes often.
-- Empty slots disappear, unless you're placing something (a spell on the
-- cursor or Blizzard's "show grid"), in Edit Mode, or with /fui empty on.
-- Only alpha changes, so this also works in combat.
local function ShowEmpty()
  if ns.editing or AB.grid then return true end
  if ns.profile and ns.profile.options.emptySlots then return true end
  return GetCursorInfo() ~= nil
end

function AB.Update(b)
  local has, action, tex = HasIcon(b)
  if not has then
    b.icon:Hide()
    b.count:SetText("")
    b.active:Hide()
    b.glow:Hide()
    ns.Fill(b, 0, 0, 0, 0.25)
    b:SetAlpha(ShowEmpty() and 1 or 0)
    return
  end
  b:SetAlpha(1)
  ns.Fill(b, 0, 0, 0, 0.45)
  b.icon:SetTexture(tex)
  b.icon:Show()

  if ns.Plain(IsConsumableAction(action)) or ns.Plain(IsStackableAction(action)) then
    ns.SetText(b.count, GetActionCount(action))
  else
    b.count:SetText("")
  end

  -- Current action also covers "on next swing" abilities such as Maul.
  local current, auto = ns.Plain(IsCurrentAction(action)), ns.Plain(IsAutoRepeatAction(action))
  b.active:SetShown((current or auto) and true or false)

  local usable, noMana = IsUsableAction(action)
  local inRange = ns.Plain(IsActionInRange(action))
  if inRange == false or inRange == 0 then
    b.icon:SetVertexColor(0.9, 0.25, 0.25)
  elseif ns.IsSecret(usable) or ns.IsSecret(noMana) or usable then
    b.icon:SetVertexColor(1, 1, 1)
  elseif noMana then
    b.icon:SetVertexColor(0.45, 0.55, 1)
  else
    b.icon:SetVertexColor(0.4, 0.4, 0.4)
  end
  b.glow:SetShown(AB.ShouldGlow(action))
end

------------------------------------------------------------------------
-- Bars
------------------------------------------------------------------------
function AB:BuildBar(m)
  local def = m.def
  local header = CreateFrame("Frame", def.name, UIParent, "SecureHandlerStateTemplate")
  m.frame = header
  m.buttons = {}
  local rows = math.ceil(def.n / def.cols)
  header:SetSize(def.cols * def.size + (def.cols - 1) * def.gap, rows * def.size + (rows - 1) * def.gap)

  for i = 1, def.n do
    local b = CreateButton(header, def.name .. "Button" .. i, i, def.first + i - 1, def.size)
    local col, row = (i - 1) % def.cols, math.floor((i - 1) / def.cols)
    b:SetPoint("TOPLEFT", header, "TOPLEFT", col * (def.size + def.gap), -row * (def.size + def.gap))
    ns.SetupClicks(b, header)
    m.buttons[i] = b
    table.insert(AB.buttons, b)
  end

  if def.paging then
    header:SetAttribute("_onstate-page", [[
      control:ChildUpdate("page", newstate)
    ]])
    for _, b in ipairs(m.buttons) do
      b:SetAttribute("_childupdate-page", [[
        local page = tonumber(message) or 1
        self:SetAttribute("action", (page - 1) * 12 + self:GetAttribute("index"))
      ]])
    end
    RegisterStateDriver(header, "page", ns.PageDriver())
  end

  if def.binding then
    table.insert(ns.bindables, { buttons = m.buttons, prefix = def.binding })
  end
  AB.dirty, AB.cdDirty = true, true
end

for _, def in ipairs(BARS) do
  local m = ns:NewModule(def.key, def.label, { pos = def.pos, scale = 1, alpha = 1, fade = def.fade or "always" })
  m.def = def
  if def.optional then
    function m:IsEnabled() return ns.profile.options[def.optional] end
  end
  function m:Build()
    if not next(AB.glowNames) then
      -- Abilities that light up while Clearcasting is active.
      for _, id in ipairs({ 5221, 6785, 6807, 779 }) do
        local n = ns.SpellName(id)
        if n then AB.glowNames[n] = true end
      end
    end
    AB:BuildBar(self)
  end
  function m:HideBlizzard()
    for _, n in ipairs(def.blizzard) do ns.HideBlizzard(n) end
  end
end

------------------------------------------------------------------------
-- Keep visuals current
------------------------------------------------------------------------
local COOLDOWN_EVENTS = {
  ACTIONBAR_UPDATE_COOLDOWN = true, SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true,
  ACTIONBAR_SLOT_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true, PLAYER_ENTERING_WORLD = true,
  ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true,
}

local updater = CreateFrame("Frame")
for _, e in ipairs({
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
  "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM",
  "PLAYER_TARGET_CHANGED", "BAG_UPDATE", "PLAYER_ENTERING_WORLD", "CURRENT_SPELL_CAST_CHANGED",
  "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
  "UPDATE_MACROS", "SPELLS_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "CURSOR_CHANGED", "CURSOR_UPDATE",
}) do
  ns.SafeRegister(updater, e)
end
ns.SafeRegister(updater, "UNIT_POWER_FREQUENT", "player")
ns.SafeRegister(updater, "UNIT_INVENTORY_CHANGED", "player")
updater:SetScript("OnEvent", function(_, e)
  if e == "ACTIONBAR_SHOWGRID" then AB.grid = true elseif e == "ACTIONBAR_HIDEGRID" then AB.grid = false end
  AB.dirty = true
  if COOLDOWN_EVENTS[e] then AB.cdDirty = true end
end)

local elapsed = 0
updater:SetScript("OnUpdate", function(_, el)
  if AB.cdDirty then
    AB.cdDirty = false
    for _, b in ipairs(AB.buttons) do AB.UpdateCooldown(b) end
  end
  elapsed = elapsed + el
  if (AB.dirty and elapsed > 0.05) or elapsed > 0.2 then
    elapsed = 0
    AB.dirty = false
    for _, b in ipairs(AB.buttons) do AB.Update(b) end
  end
end)
