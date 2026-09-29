local ADDON, ns = ...
_G.ForeverUI = ns

ns.modules = {}
ns.moduleOrder = {}
ns.bindables = {}
ns.clickButtons = {}
ns.TEX = "Interface\\Buttons\\WHITE8X8"
ns.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff7c0aForever UI|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

-- RegisterEvent errors on event names the client does not know, so every
-- registration goes through pcall. That keeps one missing event from
-- breaking a whole module on an unfamiliar client build.
function ns.SafeRegister(frame, event, unit1, unit2)
  if unit1 then
    return pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2)
  end
  return pcall(frame.RegisterEvent, frame, event)
end

function ns:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    ns.SafeRegister(eventFrame, event)
  end
  table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if list then
    for i = 1, #list do list[i](event, ...) end
  end
end)

------------------------------------------------------------------------
-- Combat queue: protected changes wait until combat ends
------------------------------------------------------------------------
local queue = {}

function ns:AfterCombat(key, fn)
  if not InCombatLockdown() then
    fn()
    return
  end
  queue[key] = fn
end

ns:On("PLAYER_REGEN_ENABLED", function()
  for key, fn in pairs(queue) do
    queue[key] = nil
    fn()
  end
end)

------------------------------------------------------------------------
-- API shims (the client is a custom build, so check before calling)
------------------------------------------------------------------------
function ns.SpellName(id)
  if not id then return nil end
  if GetSpellInfo then return (GetSpellInfo(id)) end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(id)
    return info and info.name
  end
end

function ns.CVarBool(name)
  if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name) end
  if GetCVarBool then return GetCVarBool(name) end
  return GetCVar and GetCVar(name) == "1"
end

------------------------------------------------------------------------
-- Secret values
------------------------------------------------------------------------
-- This client hands addons "secret" numbers for health, power, auras and
-- casts. A secret can go straight into a widget (StatusBar:SetValue,
-- FontString:SetText) but any math or comparison on it is an error.
-- Code that needs an actual number goes through Plain(); display code
-- passes the raw value to the widget.
ns.SECRETS = type(issecretvalue) == "function"

function ns.IsSecret(v)
  return ns.SECRETS and issecretvalue(v) or false
end

-- The value itself, or nil when it is a secret.
function ns.Plain(v)
  if ns.SECRETS and issecretvalue(v) then return nil end
  return v
end

-- True when there is a value to show (a secret counts as a value).
function ns.Has(v)
  if ns.IsSecret(v) then return true end
  return v ~= nil
end

function ns.SetText(fs, v)
  if not pcall(fs.SetText, fs, v) then fs:SetText("") end
end

function ns.SetFormatted(fs, fmt, ...)
  if not pcall(fs.SetFormattedText, fs, fmt, ...) then fs:SetText("") end
end

function ns.PowerCost(spellID, powerType)
  local fn = GetSpellPowerCost or (C_Spell and C_Spell.GetSpellPowerCost)
  if not fn then return nil end
  local ok, costs = pcall(fn, spellID)
  if not ok or type(costs) ~= "table" then return nil end
  for _, c in ipairs(costs) do
    local cost = ns.Plain(c.cost)
    if c.type == powerType and cost and cost > 0 then return cost end
  end
end

------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Style: "Gilded Monolith"
------------------------------------------------------------------------
-- Dark, calm panels (Monolith) with a thin bronze edge, a faint inner
-- highlight and slightly rounded corners (Gilded Classic). Names in Friz
-- Quadrata, numbers in Arial Narrow. Every frame gets its look from here,
-- so the whole UI changes as one.
ns.MEDIA = "Interface\\AddOns\\ForeverUI\\Media\\"
ns.BAR_TEX = ns.MEDIA .. "bar"
ns.NUMFONT = "Fonts\\ARIALN.TTF"
ns.STYLE = {
  fill = { 0.06, 0.05, 0.04 },          -- warm near-black
  border = { 0.55, 0.43, 0.22, 1 },     -- bronze
  inner = { 1, 0.86, 0.6, 0.07 },       -- faint warm highlight
}

-- Nine-slice textures (rounded corners) need a modern client; older ones
-- fall back to square 1 px edges.
do
  local probe = UIParent:CreateTexture()
  ns.SLICED = probe.SetTextureSliceMargins ~= nil
  probe:Hide()
end

local function Sliced(f, file, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(ns.MEDIA .. file)
  t:SetTextureSliceMargins(8, 8, 8, 8)
  if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
    t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
  end
  t:SetAllPoints()
  return t
end

function ns.Text(parent, size, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(ns.FONT, size or 11, "OUTLINE")
  fs:SetJustifyH(justify or "LEFT")
  fs:SetTextColor(1, 1, 1)
  return fs
end

-- Numbers (health, timers, hotkeys) in the narrow font.
function ns.NumText(parent, size, justify, layer)
  local fs = ns.Text(parent, size, justify, layer)
  fs:SetFont(ns.NUMFONT, (size or 11) + 1, "OUTLINE")
  return fs
end

-- Without nine-slice support we build the rounded panel by hand: four 4x4
-- corner pieces (one texture, flipped per corner) plus straight 1 px lines
-- and plain rectangles. Works on every client.
local C = 4
local FLIPS = {
  TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
  BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

local function Piece(f, layer, sub, list)
  local t = f:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(ns.TEX)
  list[#list + 1] = t
  return t
end

local function Corners(f, file, layer, sub, list)
  for point, tc in pairs(FLIPS) do
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(ns.MEDIA .. file)
    t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    t:SetSize(C, C)
    t:SetPoint(point)
    list[#list + 1] = t
  end
end

-- Four straight lines, `inset` px in from the edge, between the corners.
local function Lines(f, inset, layer, sub, list)
  local t = Piece(f, layer, sub, list)
  t:SetPoint("TOPLEFT", C, -inset); t:SetPoint("TOPRIGHT", -C, -inset); t:SetHeight(1)
  t = Piece(f, layer, sub, list)
  t:SetPoint("BOTTOMLEFT", C, inset); t:SetPoint("BOTTOMRIGHT", -C, inset); t:SetHeight(1)
  t = Piece(f, layer, sub, list)
  t:SetPoint("TOPLEFT", inset, -C); t:SetPoint("BOTTOMLEFT", inset, C); t:SetWidth(1)
  t = Piece(f, layer, sub, list)
  t:SetPoint("TOPRIGHT", -inset, -C); t:SetPoint("BOTTOMRIGHT", -inset, C); t:SetWidth(1)
end

local function Tint(list, r, g, b, a)
  for _, t in ipairs(list) do t:SetVertexColor(r, g, b, a or 1) end
end

-- Border only (for Blizzard buttons we dress up, like the bag slots).
function ns.Edge(f)
  local s = ns.STYLE
  if ns.SLICED then
    local inner = Sliced(f, "inner", "OVERLAY", 5)
    inner:SetVertexColor(unpack(s.inner))
    local edge = Sliced(f, "border", "OVERLAY", 6)
    edge:SetVertexColor(unpack(s.border))
    f.edgeParts = { edge }
    return
  end
  local inner, edge = {}, {}
  Corners(f, "cinner", "OVERLAY", 5, inner)
  Lines(f, 1, "OVERLAY", 5, inner)
  Corners(f, "cedge", "OVERLAY", 6, edge)
  Lines(f, 0, "OVERLAY", 6, edge)
  Tint(inner, unpack(s.inner))
  Tint(edge, unpack(s.border))
  f.edgeParts = edge
end

-- Panel: fill + bronze edge. alpha = fill opacity.
function ns.Backdrop(f, alpha)
  local s = ns.STYLE
  local fill = {}
  if ns.SLICED then
    fill[1] = Sliced(f, "fill", "BACKGROUND", -8)
  else
    -- A plus-shaped fill with rounded corner pieces, so nothing pokes out.
    local t = Piece(f, "BACKGROUND", -8, fill)
    t:SetPoint("TOPLEFT", 0, -C); t:SetPoint("BOTTOMRIGHT", 0, C)
    t = Piece(f, "BACKGROUND", -8, fill)
    t:SetPoint("TOPLEFT", C, 0); t:SetPoint("TOPRIGHT", -C, 0); t:SetHeight(C)
    t = Piece(f, "BACKGROUND", -8, fill)
    t:SetPoint("BOTTOMLEFT", C, 0); t:SetPoint("BOTTOMRIGHT", -C, 0); t:SetHeight(C)
    Corners(f, "cfill", "BACKGROUND", -8, fill)
  end
  f.fillParts = fill
  Tint(fill, s.fill[1], s.fill[2], s.fill[3], alpha or 0.6)
  ns.Edge(f)
end

-- Recolour a panel's fill without losing its rounded shape.
function ns.Fill(f, r, g, b, a)
  Tint(f.fillParts or {}, r, g, b, a)
end

function ns.BorderColor(f, r, g, b, a)
  Tint(f.edgeParts or {}, r, g, b, a)
end

function ns.ResetBorder(f)
  ns.BorderColor(f, unpack(ns.STYLE.border))
end

-- Round the corners of an icon so it sits inside the rounded edge.
function ns.MaskIcon(owner, icon)
  if not owner.CreateMaskTexture then return end
  local m = owner:CreateMaskTexture()
  m:SetTexture(ns.MEDIA .. "fill", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(icon)
  icon:AddMaskTexture(m)
end

function ns.Bar(parent, height)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetStatusBarTexture(ns.BAR_TEX)
  b:SetMinMaxValues(0, 1)
  b:SetValue(1)
  b:SetHeight(height)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)
  b.bg = bg
  return b
end

-- A row of small bars. Pip i fills while value >= i * step. Because the
-- StatusBar does the comparison, this also works with secret values:
-- combo points (step 1) or "how many shifts does my mana pay for".
function ns.Pips(parent, count, width, height, r, g, b)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height)
  f.pips = {}
  local gap = 2
  local w = (width - gap * (count - 1)) / count
  for i = 1, count do
    local p = ns.Bar(f, height)
    p:SetWidth(w)
    p:SetPoint("LEFT", f, "LEFT", (i - 1) * (w + gap), 0)
    p:SetStatusBarColor(r, g, b)
    p.bg:SetColorTexture(1, 1, 1, 0.1)
    p:SetValue(0)
    f.pips[i] = p
  end
  function f:Set(value, step)
    for i, p in ipairs(self.pips) do
      p:SetMinMaxValues((i - 1) * step, i * step)
      if not pcall(p.SetValue, p, value) then p:SetValue(0) end
    end
  end
  return f
end

function ns.ShortKey(key)
  if not key then return "" end
  key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"):gsub("META%-", "M")
  key = key:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD"):gsub("BUTTON", "M")
  key = key:gsub("NUMPAD", "N"):gsub("SPACE", "Sp"):gsub("MINUS", "-"):gsub("PLUS", "+")
  return key
end

------------------------------------------------------------------------
-- Hiding Blizzard frames we replace
------------------------------------------------------------------------
ns.hider = CreateFrame("Frame", "ForeverUIHider", UIParent)
ns.hider:Hide()
ns.hidden = {}

-- Clear a key on a Blizzard frame without leaving taint behind. Edit Mode
-- frames remember "isShownExternal"; a tainted copy of that key makes
-- Blizzard code fail later. (Same approach as Bartender4.)
local function PurgeKey(t, k)
  t[k] = nil
  local c = 42
  repeat
    if t[c] == nil then t[c] = nil end
    c = c + 1
  until issecurevariable(t, k) or c > 10000
end

local function HideNow(f)
  -- Edit Mode replaces Hide(); HideBase() is the untouched original.
  if f.HideBase then f:HideBase() else f:Hide() end
end

local keptHidden = {}

-- keepParent: hide the frame but leave it where it is. Some Blizzard
-- frames (the XP/reputation bars) call methods on their parent, so moving
-- them into our hidden frame breaks Blizzard's HUD Edit Mode.
function ns.HideBlizzard(name, unregister, keepParent)
  local f = type(name) == "string" and _G[name] or name
  if type(f) ~= "table" or not f.SetParent then return end
  if InCombatLockdown() and f.IsProtected and f:IsProtected() then
    ns:AfterCombat("hide" .. tostring(name), function() ns.HideBlizzard(name, unregister, keepParent) end)
    return
  end
  if unregister and f.UnregisterAllEvents then f:UnregisterAllEvents() end
  if f.system and issecurevariable then PurgeKey(f, "isShownExternal") end
  HideNow(f)
  if keepParent then
    if not keptHidden[f] then
      keptHidden[f] = true
      hooksecurefunc(f, "Show", HideNow)
      if f.SetShown then
        hooksecurefunc(f, "SetShown", function(self, shown)
          if shown then HideNow(self) end
        end)
      end
    end
  else
    f:SetParent(ns.hider)
  end
  table.insert(ns.hidden, tostring(name))
end

-- Report actions the client refuses, so we know exactly what to change.
ns.blocked = {}
local function OnBlocked(_, addon, fn)
  if addon ~= ADDON then return end
  table.insert(ns.blocked, tostring(fn))
  ns.Print("|cffff6b5ablocked by the client:|r " .. tostring(fn) .. "  (type /fui diag and send the output along)")
end
ns:On("ADDON_ACTION_FORBIDDEN", OnBlocked)
ns:On("ADDON_ACTION_BLOCKED", OnBlocked)

------------------------------------------------------------------------
-- Secure clicks: fire exactly once per key press
------------------------------------------------------------------------
-- Buttons listen to both key-down and key-up, and a secure wrapper lets
-- only one of the two through, following the game setting "cast on key
-- down" (or /fui keydown); the client's secure template expects exactly
-- that. Key bindings arrive as the virtual button "Keybind". On action
-- buttons ("fui-dragguard") a mouse press with Shift never fires: that
-- press is the start of Shift+drag, so the spell moves without casting.
function ns.KeyDownPref()
  local o = ns.profile and ns.profile.options.keydown or "auto"
  if o == "on" or o == "aan" then return true end
  if o == "off" or o == "uit" then return false end
  return ns.CVarBool("ActionButtonUseKeyDown") and true or false
end

function ns.SetupClicks(button, header)
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("fui-keydown", ns.KeyDownPref())
  SecureHandlerWrapScript(button, "OnClick", header, [[
    if self:GetAttribute("fui-keydown") then
      if not down then return false end
    elseif down then
      return false
    end
    if button == "Keybind" then return "LeftButton" end
    if self:GetAttribute("fui-dragguard") and IsShiftKeyDown() then return false end
  ]])
  table.insert(ns.clickButtons, button)
end

function ns.UpdateClickPref()
  ns:AfterCombat("clickpref", function()
    local v = ns.KeyDownPref()
    for _, b in ipairs(ns.clickButtons) do b:SetAttribute("fui-keydown", v) end
  end)
end

ns:On("CVAR_UPDATE", function()
  if ns.profile then ns.UpdateClickPref() end
end)

------------------------------------------------------------------------
-- Key bindings: reuse the player's own Blizzard bindings
------------------------------------------------------------------------
local bindOwner = CreateFrame("Frame", "ForeverUIBindingOwner", UIParent)
local lastSignature

function ns.ApplyBindings(force)
  if InCombatLockdown() then
    ns:AfterCombat("bindings", function() ns.ApplyBindings(true) end)
    return
  end
  local sig = {}
  for _, entry in ipairs(ns.bindables) do
    for i in ipairs(entry.buttons) do
      local k1, k2 = GetBindingKey(entry.prefix .. i)
      sig[#sig + 1] = (k1 or "") .. "," .. (k2 or "")
    end
  end
  sig = table.concat(sig, ";")
  -- Setting override bindings can fire UPDATE_BINDINGS again; skip when
  -- nothing changed so we never loop.
  if sig == lastSignature and not force then return end
  lastSignature = sig

  ClearOverrideBindings(bindOwner)
  for _, entry in ipairs(ns.bindables) do
    for i, b in ipairs(entry.buttons) do
      local k1, k2 = GetBindingKey(entry.prefix .. i)
      if k1 then SetOverrideBindingClick(bindOwner, true, k1, b:GetName(), "Keybind") end
      if k2 then SetOverrideBindingClick(bindOwner, true, k2, b:GetName(), "Keybind") end
      if b.hotkey then b.hotkey:SetText(ns.ShortKey(k1)) end
    end
  end
end

ns:On("UPDATE_BINDINGS", function()
  if ns.profile then ns.ApplyBindings() end
end)

------------------------------------------------------------------------
-- Saved variables & profiles
------------------------------------------------------------------------
ns.defaults = {
  modules = {},
  options = { keydown = "auto", bar3 = true, bar4 = true, util = false, emptySlots = false, context = true, reminder = true, questToast = true, questTooltip = true, meterSkin = true, issueReporter = "small", snap = true, targetFrame = "forever", targetAuras = "blizzard", playerAuras = "blizzard", chatChannels = "short" },
}

local function copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copy(v) end
  return c
end
ns.copy = copy

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns:NewModule(key, label, defaults)
  local m = { key = key, label = label, defaults = defaults }
  ns.defaults.modules[key] = defaults
  ns.modules[key] = m
  table.insert(ns.moduleOrder, m)
  return m
end

function ns:M(key)
  return ns.profile.modules[key]
end

function ns:UseProfile(name)
  local db = ForeverUIDB
  db.profiles[name] = db.profiles[name] or {}
  local p = db.profiles[name]
  merge(p, ns.defaults)
  -- v0.3: bar 3 is on by default, so every Blizzard bar gets replaced.
  if (p.version or 1) < 2 then
    p.options.bar3 = true
    p.version = 2
  end
  -- v0.4: bars 3 and 4 become 2x6 grids beside the main bars, and the
  -- target frame defaults to Blizzard's (it can show auras in combat).
  if p.version < 3 then
    p.options.bar3 = true
    p.options.bar4 = true
    p.options.targetFrame = "blizzard"
    p.modules.ab3.pos = copy(ns.defaults.modules.ab3.pos)
    p.version = 3
  end
  -- v0.4.1: player/target frames lower, cast bar above the form bar.
  if p.version < 4 then
    for _, key in ipairs({ "player", "target", "cast", "procs", "pdebuffs", "tdebuffs" }) do
      if p.modules[key] then p.modules[key].pos = copy(ns.defaults.modules[key].pos) end
    end
    p.version = 4
  end
  -- v0.5: Forever UI's own target frame (with ToT and cast bar) by default.
  if p.version < 5 then
    p.options.targetFrame = "forever"
    p.version = 5
  end
  -- v0.8.1: target auras come from Blizzard's frame (works in combat).
  if p.version < 6 then
    p.options.targetAuras = "blizzard"
    p.version = 6
  end
  -- v0.8.4: Forever UI draws the target auras by default again.
  if p.version < 7 then
    p.options.targetAuras = "forever"
    p.version = 7
  end
  -- v0.8.5: Blizzard's target aura icons (they keep working in combat),
  -- now placed automatically under the Forever UI target frame.
  if p.version < 8 then
    p.options.targetAuras = "blizzard"
    p.version = 8
  end
  -- v0.9: this client refuses every aura read to addons in combat, so
  -- Blizzard draws all auras and Forever UI places them.
  if p.version < 9 then
    p.options.targetAuras = "blizzard"
    p.options.playerAuras = "blizzard"
    p.version = 9
  end
  -- v0.9.1: new default spot for the target aura icons.
  if p.version < 10 then
    p.version = 10
  end
  -- v0.9.5: the vertical utility bar is off unless you turn it on.
  if p.version < 11 then
    p.options.util = false
    p.version = 11
  end
  db.chars[ns.charKey] = name
  ns.profileName = name
  ns.profile = db.profiles[name]
end

function ns:InitDB()
  ForeverUIDB = ForeverUIDB or {}
  local db = ForeverUIDB
  db.profiles = db.profiles or {}
  db.chars = db.chars or {}
  ns.charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
  ns:UseProfile(db.chars[ns.charKey] or "Standaard")
end

------------------------------------------------------------------------
-- Layout & visibility
------------------------------------------------------------------------
function ns:ApplyLayout(m)
  local f = m.frame
  if not f then return end
  if InCombatLockdown() and f:IsProtected() then
    ns:AfterCombat("layout" .. m.key, function() ns:ApplyLayout(m) end)
    return
  end
  local s = ns:M(m.key)
  local scale = s.scale or 1
  local p = s.pos
  f:SetScale(scale)
  f:ClearAllPoints()
  -- Positions are stored in UIParent units; offsets scale with the frame.
  f:SetPoint(p.p, UIParent, p.rp, p.x / scale, p.y / scale)
  ns.Fader:Set(f, s.fade or "always", s.alpha or 1)
end

function ns:ResetModule(m)
  local s, d = ns:M(m.key), m.defaults
  s.pos = copy(d.pos)
  s.scale = d.scale or 1
  s.alpha = d.alpha or 1
  s.fade = d.fade or "always"
  if d.w then s.w, s.h = d.w, d.h end
  if m.ApplySize then m:ApplySize() end
  ns:ApplyLayout(m)
end

function ns:ResetLayout()
  if InCombatLockdown() then
    ns.Print("You can only reset out of combat.")
    return
  end
  for _, m in ipairs(ns.moduleOrder) do
    if m.frame then ns:ResetModule(m) end
  end
  if ns.editing then ns.EditMode:Reanchor() end
  ns.Print("Layout reset to default.")
end

-- Fader: "always", "mouseover" or "breath" (dims when nothing is going on)
local Fader = CreateFrame("Frame")
ns.Fader = Fader
Fader.frames = {}
Fader.modes = { "always", "mouseover", "breath" }
Fader.labels = { always = "Always", mouseover = "Mouseover", breath = "Breathe" }

function Fader:Set(f, mode, alpha)
  self.frames[f] = { mode = mode, alpha = alpha }
  f:SetAlpha(self:Target(f))
end

local function Hurt()
  local cur, max = ns.Plain(UnitHealth("player")), ns.Plain(UnitHealthMax("player"))
  return cur and max and cur < max
end

function Fader:Target(f)
  local c = self.frames[f]
  if not c then return 1 end
  if ns.editing or c.mode == "always" then return c.alpha end
  if c.mode == "mouseover" then
    return f:IsMouseOver() and c.alpha or 0
  end
  if InCombatLockdown() or UnitExists("target") or IsModifierKeyDown() or f:IsMouseOver() or Hurt() then
    return c.alpha
  end
  return c.alpha * 0.15
end

Fader:SetScript("OnUpdate", function(self, elapsed)
  local k = math.min(1, elapsed * 10)
  for f in pairs(self.frames) do
    local cur, target = f:GetAlpha(), self:Target(f)
    if math.abs(cur - target) > 0.01 then
      f:SetAlpha(cur + (target - cur) * k)
    elseif cur ~= target then
      f:SetAlpha(target)
    end
  end
end)

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------
local function Report(what, err)
  ns.Print("|cffff6b5aerror in " .. what .. "|r: " .. tostring(err))
  local handler = geterrorhandler and geterrorhandler()
  if handler then handler(err) end
end

ns:On("PLAYER_LOGIN", function()
  ns.playerClass = select(2, UnitClass("player"))
  ns.isDruid = ns.playerClass == "DRUID"
  ns:InitDB()

  for _, m in ipairs(ns.moduleOrder) do
    if m.Build and (not m.IsEnabled or m:IsEnabled()) then
      local ok, err = pcall(m.Build, m)
      if not ok then Report(m.label, err) end
    end
  end
  for _, m in ipairs(ns.moduleOrder) do
    if m.frame then ns:ApplyLayout(m) end
  end
  for _, m in ipairs(ns.moduleOrder) do
    if m.frame and m.HideBlizzard then
      local ok, err = pcall(m.HideBlizzard, m)
      if not ok then Report(m.label .. " (hiding Blizzard frames)", err) end
    end
  end
  ns.ApplyBindings(true)
  ns.Print("loaded, profile '" .. ns.profileName .. "'. Type /fui to edit the layout, /fui help for more.")
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
function ns:ProfileCommand(name)
  name = name and strtrim(name) or ""
  local db = ForeverUIDB
  if name == "" then
    local names = {}
    for k in pairs(db.profiles) do names[#names + 1] = k end
    table.sort(names)
    ns.Print("Profiles: " .. table.concat(names, ", ") .. ". Active: " .. ns.profileName .. ".")
    return
  end
  if InCombatLockdown() then
    ns.Print("Switch profiles out of combat.")
    return
  end
  if not db.profiles[name] then
    db.profiles[name] = copy(ns.profile)
    ns.Print("Created profile '" .. name .. "' as a copy of '" .. ns.profileName .. "'.")
  end
  ns:UseProfile(name)
  for _, m in ipairs(ns.moduleOrder) do
    if m.frame then ns:ApplyLayout(m) end
  end
  ns.UpdateClickPref()
  if ns.editing then ns.EditMode:Reanchor() end
  ns.Print("Active profile: " .. name .. ". Turning bars or the target frame on/off needs a /reload.")
end

-- Frames Forever UI may replace, to see which ones this client has.
local DIAG_FRAMES = {
  "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
  "StanceBar", "StanceBarFrame", "MicroMenuContainer", "MicroButtonAndBagsBar", "BagsBar",
  "PlayerFrame", "TargetFrame", "TargetFrameToT", "PlayerCastingBarFrame", "CastingBarFrame", "BuffFrame", "DebuffFrame",
  "MainStatusTrackingBarContainer", "StatusTrackingBarManager", "MainMenuExpBar", "MinimapCluster", "PartyFrame", "CompactPartyFrame",
}

local function Diag()
  local version, build, _, iface = GetBuildInfo()
  ns.Print("diagnostics")
  print(string.format("  client %s (%s), interface %s, secret values: %s", tostring(version), tostring(build),
    tostring(iface), ns.SECRETS and "yes" or "no"))
  local parts = {}
  for _, n in ipairs(DIAG_FRAMES) do
    local f = _G[n]
    local state = "-"
    if type(f) == "table" and f.IsVisible then state = f:IsVisible() and "shown" or "hidden" end
    parts[#parts + 1] = n .. "=" .. state
  end
  print("  frames: " .. table.concat(parts, ", "))
  local built = {}
  for _, m in ipairs(ns.moduleOrder) do
    built[#built + 1] = m.key .. (m.frame and (m.frame:IsVisible() and "+" or "~") or "!")
  end
  print("  modules (+ shown, ~ hidden, ! not built): " .. table.concat(built, " "))
  print("  cooldowns via: " .. tostring(ns.cooldownPath) .. ", target frame: " .. tostring(ns.profile.options.targetFrame)
    .. ", target auras: " .. tostring(ns.profile.options.targetAuras)
    .. ", corners: " .. (ns.SLICED and "nine-slice" or "hand-built"))
  local reads = {}
  for k, v in pairs(ns.auraBlocked or {}) do reads[#reads + 1] = k .. "=" .. v end
  table.sort(reads)
  print("  aura reads refused (last scan): " .. (#reads > 0 and table.concat(reads, ", ") or "none"))
  -- Find Blizzard's swing timer so we can dock or style it later.
  local swing = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and k:lower():find("swing") and type(v) == "table" and v.GetObjectType then
      swing[#swing + 1] = k
    end
  end
  table.sort(swing)
  print("  swing frames: " .. (#swing > 0 and table.concat(swing, ", ") or "none found"))
  local combat = {}
  for k, v in pairs(ns.combatAuraDiag or {}) do combat[#combat + 1] = k .. ": " .. v end
  table.sort(combat)
  print("  auras during last combat: " .. (#combat > 0 and table.concat(combat, "; ") or "no combat yet"))
  print("  blocked: " .. (#ns.blocked > 0 and table.concat(ns.blocked, ", ") or "nothing"))
end

local function Help()
  ns.Print("commands:")
  print("  /fui  — toggle edit mode")
  print("  /fui profile [name]  — list profiles, or switch (a new profile starts as a copy of the current one)")
  print("  /fui bar3 on|off  — action bar 3, right of the main bars (needs /reload)")
  print("  /fui bar4 on|off  — action bar 4, left of the main bars (needs /reload)")
  print("  /fui util on|off  — vertical utility bar on the right edge (needs /reload)")
  print("  /fui empty on|off  — show empty action slots (they also show while you drag a spell)")
  print("  /fui context on|off  — context modes: quest tracker dims in combat and in instances")
  print("  /fui reminder on|off  — buff reminder out of combat")
  print("  /fui questtoast on|off  — quest progress in a Forever UI panel (needs /reload)")
  print("  /fui questtip on|off  — quest line on item tooltips")
  print("  /fui session [reset]  — this session's gold, XP, quests, kills")
  print("  /fui meter  — style Blizzard's damage meter now and list its windows")
  print("  /fui meterfont <8-16>|off  — text size in the damage meter rows")
  print("  /fui mode auto|quest|dungeon|raid|pvp|rest  — context mode (auto follows where you are)")
  print("  /fui issue small|hidden|normal  — the Issue Reporter button (normal needs /reload)")
  print("  /fui fade  — how transparent chat and damage meter are per mode (on|off also works)")
  print("  /fui target blizzard|forever  — which target frame to use (needs /reload)")
  print("  /fui targetauras blizzard|forever  — who draws the target's buffs/debuffs (needs /reload)")
  print("  /fui playerauras blizzard|forever  — who draws your own buffs/debuffs (needs /reload)")
  print("  /fui keydown auto|on|off  — fire buttons on key down or key up")
  print("  /fui reset confirm  — reset the whole layout of this profile")
  print("  /fui copy  — open the chat copy window")
  print("  /fui chat short|name|off  — channel names as [1], [1. General] or Blizzard's")
  print("  /fui diag  — technical diagnostics")
  print("  /fui auras  — list your buffs and where they show up")
end

-- Accept English and the earlier Dutch words.
local ON = { on = true, aan = true }
local OFF = { off = true, uit = true }

local function Toggle(option, value, label)
  if ON[value] or OFF[value] then
    ns.profile.options[option] = ON[value] and true or false
    ns.Print(label .. " is now " .. (ON[value] and "on" or "off") .. ". Type /reload to apply.")
  else
    ns.Print("Usage: /fui " .. option .. " on  or  /fui " .. option .. " off")
  end
end

SLASH_FOREVERUI1 = "/fui"
SLASH_FOREVERUI2 = "/foreverui"
SlashCmdList.FOREVERUI = function(msg)
  if not ns.profile then return end
  local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
  cmd = (cmd or ""):lower()
  rest = rest and strtrim(rest) or ""
  local value = rest:lower()
  if cmd == "" or cmd == "edit" then
    ns.EditMode:Toggle()
  elseif cmd == "copy" then
    if ns.OpenChatCopy then ns.OpenChatCopy() end
  elseif cmd == "diag" then
    Diag()
  elseif cmd == "target" and (value == "info") then
    local parts = {}
    if TargetFrame then
      for k, v in pairs(TargetFrame) do
        if type(k) == "string" and type(v) == "table" and v.GetObjectType then parts[#parts + 1] = k end
      end
      for _, child in ipairs({ TargetFrame:GetChildren() }) do
        local n = child:GetName()
        if n then parts[#parts + 1] = n end
      end
    end
    table.sort(parts)
    ns.Print("TargetFrame parts: " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
    -- Small unnamed child frames are the aura icons: where, how many, visible?
    local function scan(frame, path, depth, out)
      for _, c in ipairs({ frame:GetChildren() }) do
        local w, h = c:GetSize()
        w, h = ns.Plain(w), ns.Plain(h)
        if not c:GetName() and w and h and w > 8 and w < 40 and math.abs(w - h) < 4 then
          out[#out + 1] = string.format("%s (%s, alpha %.1f, x %d, y %d)", path, c:IsVisible() and "visible" or "hidden",
            c:GetEffectiveAlpha(), math.floor((c:GetLeft() or 0) + 0.5), math.floor((c:GetBottom() or 0) + 0.5))
        elseif depth > 0 then
          scan(c, path .. "." .. (c:GetName() or c:GetObjectType()), depth - 1, out)
        end
      end
    end
    local icons = {}
    if TargetFrame then scan(TargetFrame, "TargetFrame", 2, icons) end
    local content = TargetFrame and TargetFrame.TargetFrameContent
    local auras = content and content.TargetFrameContentContextual and content.TargetFrameContentContextual.Auras
    if auras then
      print(string.format("  Auras frame: %s, alpha %.1f, left %s, top %s", auras:IsVisible() and "visible" or "hidden",
        auras:GetEffectiveAlpha(), tostring(ns.Plain(auras:GetLeft()) and math.floor(auras:GetLeft())),
        tostring(ns.Plain(auras:GetTop()) and math.floor(auras:GetTop()))))
    end
    print("  aura-like icons: " .. (#icons > 0 and table.concat(icons, "; ", 1, math.min(#icons, 4)) or "none (target something with buffs)")
      .. (#icons > 4 and (" ... +" .. (#icons - 4)) or ""))
    local td = ns.targetIconDiag
    if td then
      if ns.RelayoutTargetIcons then ns.RelayoutTargetIcons() end
      print(string.format("  re-stack: %s, %d debuffs, %d buffs, %d runs", td.how, td.debuffs, td.buffs, td.runs))
    end
    print(string.format("  TargetFrame: %s, alpha %.1f, scale %.2f", TargetFrame and (TargetFrame:IsVisible() and "visible" or "hidden") or "missing",
      TargetFrame and TargetFrame:GetEffectiveAlpha() or 0, TargetFrame and TargetFrame:GetEffectiveScale() or 0))
  elseif cmd == "auras" then
    -- Which buffs the client lets us read, and where each one ends up.
    local list, blocked = ns.ReadAuras("player", "HELPFUL")
    ns.Print("your buffs (" .. #list .. " readable, " .. blocked .. " refused):")
    for _, a in ipairs(list) do
      local id, name = ns.Plain(a.d.spellId), ns.Plain(a.d.name)
      local dur = ns.Plain(a.d.duration)
      local where = (id and ns.procShown and ns.procShown[id]) and "procs row" or "buff row"
      local listed = id and ns.procIds[id] and " (proc list)" or ""
      print(string.format("  %s (%s, %ss) -> %s%s", tostring(name or "secret"), tostring(id or "secret"),
        tostring(dur or "?"), where, listed))
    end
    local d = ns.procDebug or {}
    if d.error then
      print("  procs row error: " .. d.error)
    else
      print(string.format("  procs row: %s shown (by id %s, by name %s, by scan %s, %s readable)",
        tostring(d.shown), tostring(d.byId), tostring(d.byName), tostring(d.scan), tostring(d.readable)))
    end
  elseif cmd == "profile" or cmd == "profiel" then
    ns:ProfileCommand(rest)
  elseif cmd == "reset" then
    if value == "confirm" or value == "bevestig" then
      ns:ResetLayout()
    else
      ns.Print("Type '/fui reset confirm' to reset the whole layout of this profile.")
    end
  elseif cmd == "bar3" then
    Toggle("bar3", value, "Action bar 3")
  elseif cmd == "bar4" then
    Toggle("bar4", value, "Action bar 4")
  elseif cmd == "util" then
    Toggle("util", value, "Utility bar")
  elseif cmd == "empty" then
    if ON[value] or OFF[value] then
      ns.profile.options.emptySlots = ON[value] and true or false
      ns.Print("Empty action slots: " .. (ON[value] and "shown" or "hidden") .. ".")
    else
      ns.Print("Usage: /fui empty on  or  /fui empty off")
    end
  elseif cmd == "context" or cmd == "reminder" or cmd == "questtoast" or cmd == "questtip" then
    local key = ({ context = "context", reminder = "reminder", questtoast = "questToast", questtip = "questTooltip" })[cmd]
    local label = ({ context = "Context modes", reminder = "Buff reminder", questtoast = "Quest progress toasts (after /reload)", questtip = "Quest tooltip line" })[cmd]
    if ON[value] or OFF[value] then
      ns.profile.options[key] = ON[value] and true or false
      ns.Print(label .. " is now " .. (ON[value] and "on" or "off") .. ".")
      if cmd == "reminder" and ns.modules.reminder and ns.modules.reminder.frame then ns.modules.reminder:Update() end
    else
      ns.Print("Usage: /fui " .. cmd .. " on  or  /fui " .. cmd .. " off")
    end
  elseif cmd == "session" then
    if value == "reset" then
      ns.Session.Reset()
      ns.Print("session reset.")
    else
      ns.Session.Print()
    end
  elseif cmd == "meter" then
    ns.Skins.Report()
  elseif cmd == "meterfont" then
    local n = tonumber(value)
    if n and n >= 8 and n <= 16 then
      ns.profile.options.meterFont = n
      ns.Print("Damage meter text: " .. n .. ".")
    elseif OFF[value] then
      ns.profile.options.meterFont = nil
      ns.Print("Damage meter text: Blizzard's size again after /reload.")
    else
      ns.Print("Usage: /fui meterfont 8..16  or  /fui meterfont off")
    end
  elseif cmd == "mode" then
    local cx = ns.Context
    if value == "auto" or cx.LABELS[value] then
      cx.Set(value)
      ns.Print("Context mode: " .. (value == "auto" and ("auto (now " .. cx.LABELS[cx.mode] .. ")") or cx.LABELS[value]) .. ".")
    else
      ns.Print("Usage: /fui mode auto|quest|dungeon|raid|pvp|rest")
    end
  elseif cmd == "issue" then
    if value == "small" or value == "hidden" or value == "normal" then
      ns.profile.options.issueReporter = value
      ns.Skins.Issue()
      ns.Print("Issue Reporter: " .. value .. (value == "normal" and ". Type /reload to apply." or "."))
    else
      ns.Skins.IssueReport()
      ns.Print("Usage: /fui issue small|hidden|normal")
    end
  elseif cmd == "fade" then
    if ON[value] or OFF[value] then
      ns.profile.options.fade.on = ON[value] and true or false
      ns.Print("Hover fade is now " .. (ON[value] and "on" or "off") .. ".")
    else
      ns.Fade.Open()
    end
  elseif cmd == "target" then
    if value == "blizzard" or value == "forever" then
      ns.profile.options.targetFrame = value
      ns.Print("Target frame: " .. value .. ". Type /reload to apply.")
    else
      ns.Print("Usage: /fui target blizzard  or  /fui target forever")
    end
  elseif cmd == "chat" then
    if value == "short" or value == "name" or value == "off" then
      ns.profile.options.chatChannels = value
      local example = { short = "[1]", name = "[1. General]", off = "[1. General - Zone]" }
      ns.Print("Channel names now look like " .. example[value] .. " (new messages).")
    else
      ns.Print("Usage: /fui chat short  ([1])  |  name  ([1. General])  |  off")
    end
  elseif cmd == "playerauras" then
    if value == "blizzard" or value == "forever" then
      ns.profile.options.playerAuras = value
      ns.Print("Your buffs/debuffs from: " .. value .. ". Type /reload to apply.")
    else
      ns.Print("Usage: /fui playerauras blizzard  or  /fui playerauras forever  (forever: no auras in combat on this client)")
    end
  elseif cmd == "targetauras" then
    if value == "blizzard" or value == "forever" then
      ns.profile.options.targetAuras = value
      ns.Print("Target buffs/debuffs from: " .. value .. ". Type /reload to apply.")
    else
      ns.Print("Usage: /fui targetauras blizzard  or  /fui targetauras forever")
    end
  elseif cmd == "keydown" then
    local v = (ON[value] and "on") or (OFF[value] and "off") or (value == "auto" and "auto") or nil
    if v then
      ns.profile.options.keydown = v
      ns.UpdateClickPref()
      ns.Print("Keydown: " .. v .. " (buttons now fire on key " .. (ns.KeyDownPref() and "down" or "up") .. ").")
    else
      ns.Print("Usage: /fui keydown auto | on | off")
    end
  else
    Help()
  end
end
