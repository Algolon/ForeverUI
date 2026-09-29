local ADDON, ns = ...
local PR = ns:NewModule("procs", "Procs & Short Buffs", { pos = { p = "CENTER", rp = "CENTER", x = -190, y = -188 }, scale = 1, alpha = 1, fade = "always" })
local PD = ns:NewModule("pdebuffs", "Debuffs on You", { pos = { p = "CENTER", rp = "CENTER", x = -190, y = -138 }, scale = 1, alpha = 1, fade = "always" })
local TD = ns:NewModule("tdebuffs", "Target Debuffs", { pos = { p = "CENTER", rp = "CENTER", x = 190, y = -192 }, scale = 1, alpha = 1, fade = "always" })
local TB = ns:NewModule("tbuffs", "Target Buffs", { pos = { p = "CENTER", rp = "CENTER", x = 190, y = -150 }, scale = 1, alpha = 1, fade = "always" })

-- Long buffs stay in Blizzard's own buff frame for now (top right), where
-- right-click still cancels them.
--
-- Aura fields (duration, stacks, source...) can be secret values. Where a
-- choice depends on one, we look it up by spell ID or with a filter
-- instead of comparing the value.

local W = 230
local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0.2, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }
local CURES = {
  Poison = { 2893, 8946, 526, 4987, 1152 },   -- Abolish/Cure Poison, Cleanse, Purify
  Curse = { 2782, 475 },                      -- Remove Curse, Remove Lesser Curse
  Disease = { 552, 528, 2870, 4987, 1152 },
  Magic = { 527, 4987 },
}
-- Always shown as procs: Clearcasting, Tiger's Fury, Prowl, Dash, Enrage,
-- Frenzied Regeneration, Barkskin, Nature's Grace, Innervate, Nature's Swiftness.
local WHITELIST = { 16870, 5217, 6793, 9845, 9846, 5215, 6783, 9913, 1850, 9821, 5229,
  22842, 22895, 22896, 22812, 16886, 29166, 17116,
  -- Rejuvenation and Regrowth (all ranks) on yourself
  774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299,
  8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858,
  -- Nature's Grasp
  16689, 16810, 16811, 16812, 16813, 17329 }
local CLEARCASTING = 16870

local whitelistIds = {}
for _, id in ipairs(WHITELIST) do whitelistIds[id] = true end
local cureNames = {}
local containers = {}

-- The client refuses to hand out auras it considers secret (for example
-- enemy debuffs in combat) and raises an error instead. Returns the aura,
-- or nil at the end of the list, or nil + true when this one was refused.
local function AuraData(unit, index, filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if ok then return d end
    return nil, true
  end
  if not UnitAura then return nil end
  local name, icon, count, dtype, duration, expires, source, _, _, spellId = UnitAura(unit, index, filter)
  if name == nil then return nil end
  return { name = name, icon = icon, applications = count, dispelName = dtype, duration = duration,
    expirationTime = expires, sourceUnit = source, spellId = spellId }
end

-- All readable auras for unit + filter. A refused aura is skipped instead
-- of ending the list, so one secret debuff no longer hides the others.
ns.auraBlocked = {}
local function ReadAuras(unit, filter)
  local out, blocked = {}, 0
  for i = 1, 40 do
    local d, refused = AuraData(unit, i, filter)
    if refused then
      blocked = blocked + 1
    elseif not d then
      break
    else
      out[#out + 1] = { d = d, index = i }
    end
  end
  ns.auraBlocked[unit .. " " .. filter] = blocked
  if InCombatLockdown() then
    local first = out[1] and out[1].d
    local secret = first and (ns.IsSecret(first.spellId) or ns.IsSecret(first.duration)) or false
    ns.combatAuraDiag = ns.combatAuraDiag or {}
    ns.combatAuraDiag[unit .. " " .. filter] = string.format("%d readable, %d refused%s", #out, blocked,
      secret and ", fields secret" or "")
  end
  return out, blocked
end

local function FormatTime(t)
  if t >= 3600 then return math.floor(t / 3600 + 0.5) .. "h" end
  if t >= 60 then return math.floor(t / 60 + 0.5) .. "m" end
  if t >= 10 then return tostring(math.floor(t + 0.5)) end
  return string.format("%.1f", t)
end

local function UpdateCures()
  local known = IsSpellKnown or (C_SpellBook and C_SpellBook.IsSpellKnown)
  for dtype, ids in pairs(CURES) do
    cureNames[dtype] = nil
    for _, id in ipairs(ids) do
      if known and known(id) then
        cureNames[dtype] = ns.SpellName(id)
        break
      end
    end
  end
end

local function CreateIcon(parent)
  local b = CreateFrame("Frame", nil, parent)
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
  local ov = CreateFrame("Frame", nil, b)
  ov:SetAllPoints()
  ov:SetFrameLevel(b.cd:GetFrameLevel() + 2)
  b.time = ns.NumText(ov, 11, "CENTER")
  b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
  b.count = ns.NumText(ov, 11, "RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -1, 2)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if self.auraInstanceID and GameTooltip.SetUnitAuraByAuraInstanceID then
      pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.auraInstanceID)
    elseif self.index and GameTooltip.SetUnitAura then
      pcall(GameTooltip.SetUnitAura, GameTooltip, self.unit, self.index, self.filter)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local function HideNumbers(cd, hide)
  if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(hide) end
end

-- Readable durations: our own swipe and timer text. Secret durations: the
-- client's duration object drives the swipe and its own countdown numbers.
local function SetAuraCooldown(b, d, unit)
  b.exp = nil
  local dur, exp = ns.Plain(d.duration), ns.Plain(d.expirationTime)
  if dur and exp then
    HideNumbers(b.cd, true)
    if dur > 0 then
      b.cd:SetCooldown(exp - dur, dur)
      b.cd:Show()
      b.exp = exp
    else
      b.cd:Hide()
    end
    return
  end
  local id = ns.Plain(d.auraInstanceID)
  local getDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
  if id and getDuration and b.cd.SetCooldownFromDurationObject then
    local ok, obj = pcall(getDuration, unit, id)
    if ok and obj and pcall(b.cd.SetCooldownFromDurationObject, b.cd, obj) then
      HideNumbers(b.cd, false)
      b.cd:Show()
      return
    end
  end
  b.cd:Hide()
end

local function SetCount(b, d, unit)
  local n = ns.Plain(d.applications)
  if n then
    b.count:SetText(n > 1 and n or "")
    return
  end
  local id = ns.Plain(d.auraInstanceID)
  local fn = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
  if id and fn then
    local ok, s = pcall(fn, unit, id, 2, 99)
    if ok then
      ns.SetText(b.count, s)
      return
    end
  end
  b.count:SetText("")
end

local function NewContainer(m, name, height, growLeft)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(W, height)
  f.icons = {}
  f.growLeft = growLeft
  f.placeholder = f:CreateTexture(nil, "BACKGROUND")
  f.placeholder:SetAllPoints()
  f.placeholder:SetColorTexture(1, 1, 1, 0.05)
  f.placeholder:Hide()
  m.frame = f
  function m:OnEditMode(on) f.placeholder:SetShown(on) end
  table.insert(containers, f)
  return f
end

-- entries: data, unit, index, filter, size, r, g, b, dim
local function Place(f, list)
  local x, shown = 0, 0
  for i, a in ipairs(list) do
    if x + a.size > W then break end
    local b = f.icons[i] or CreateIcon(f)
    f.icons[i] = b
    b:SetSize(a.size, a.size)
    b:ClearAllPoints()
    if f.growLeft then
      b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, 0)
    else
      b:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
    end
    x = x + a.size + 4
    local d = a.data
    pcall(b.icon.SetTexture, b.icon, d.icon)
    -- r, g, b = 0, 0, 0 means "no special colour": the normal bronze edge.
    if a.r == 0 and a.g == 0 and a.b == 0 then ns.ResetBorder(b) else ns.BorderColor(b, a.r, a.g, a.b, 1) end
    b:SetAlpha(a.dim and 0.55 or 1)
    SetCount(b, d, a.unit)
    SetAuraCooldown(b, d, a.unit)
    b.time:SetText("")
    b.unit, b.index, b.filter, b.auraInstanceID = a.unit, a.index, a.filter, ns.Plain(d.auraInstanceID)
    b:Show()
    shown = i
  end
  for i = shown + 1, #f.icons do f.icons[i]:Hide() end
  return shown
end

local whitelistNames, whitelistNameList = {}, {}

local SafeScanBuffs
local classCache = {} -- auraInstanceID -> "proc" | "long", learned while readable

local function ScanPlayerBuffs()
  if not PR.frame then return end
  local list, cc, found, foundNames = {}, false, {}, {}
  local ccName = ns.SpellName(CLEARCASTING)
  local dbg = { byId = 0, byName = 0, scan = 0, readable = 0 }
  local function add(d, index, via)
    if #list < 6 then
      dbg[via] = dbg[via] + 1
      list[#list + 1] = { data = d, unit = "player", index = index, filter = index and "HELPFUL" or nil,
        size = 34, r = 1, g = 0.88, b = 0.54 }
    end
  end
  -- 1. By spell ID: no aura field needs comparing.
  local byId = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if byId then
    for _, id in ipairs(WHITELIST) do
      local ok, d = pcall(byId, id)
      if ok and d then
        found[id] = true
        local n = ns.SpellName(id)
        if n then foundNames[n] = true end
        if id == CLEARCASTING then cc = true end
        add(d, nil, "byId")
      end
    end
  end
  -- 2. By spell name, for anything the ID lookup missed.
  local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if byName then
    for _, n in ipairs(whitelistNameList) do
      if not foundNames[n] then
        local ok, d = pcall(byName, "player", n, "HELPFUL")
        if ok and d then
          foundNames[n] = true
          if n == ccName then cc = true end
          add(d, nil, "byName")
        end
      end
    end
  end
  -- Your own buffs, by instance ID (for the secret case below).
  local own = {}
  for _, a in ipairs((ReadAuras("player", "HELPFUL|PLAYER"))) do
    local inst = ns.Plain(a.d.auraInstanceID)
    if inst then own[inst] = true end
  end
  -- Short buffs (60 s or less), plus any whitelisted proc the spell-ID
  -- lookup missed (Enrage went missing that way).
  for _, a in ipairs((ReadAuras("player", "HELPFUL"))) do
    local d, i = a.d, a.index
    dbg.readable = dbg.readable + 1
    local id, dur, name = ns.Plain(d.spellId), ns.Plain(d.duration), ns.Plain(d.name)
    local inst = ns.Plain(d.auraInstanceID)
    local listed = (id and whitelistIds[id]) or (name and whitelistNames[name])
    local already = (id and found[id]) or (name and foundNames[name])
    if id == CLEARCASTING or (name and name == ccName) then cc = true end
    local short = dur and dur > 0 and dur <= 60 and not listed
    if inst and (id or name or dur) then
      classCache[inst] = (listed or short) and "proc" or "long"
    elseif not id and not name and not dur then
      -- Everything secret (combat): known aura keeps its row; a new one
      -- you cast yourself (Enrage, Tiger's Fury, a HoT) counts as a proc.
      local class = inst and classCache[inst]
      if class == nil and inst and own[inst] then class = "proc" end
      short = class == "proc"
      listed = false
    end
    -- 3. Scanning: short buffs, plus listed procs nothing else found.
    if #list < 6 and (short or (listed and not already)) then
      local r, g, b = 0, 0, 0
      if listed then r, g, b = 1, 0.88, 0.54 end
      dbg.scan = dbg.scan + 1
      list[#list + 1] = { data = d, unit = "player", index = i, filter = "HELPFUL", size = 34, r = r, g = g, b = b }
    end
  end
  dbg.shown = Place(PR.frame, list)
  ns.procDebug = dbg
  -- The buff row leaves out exactly what this row shows, so a buff can
  -- never fall between the two rows.
  local shownIds, shownInst = {}, {}
  for n = 1, dbg.shown do
    local id = ns.Plain(list[n].data.spellId)
    if id then shownIds[id] = true end
    local inst = ns.Plain(list[n].data.auraInstanceID)
    if inst then shownInst[inst] = true end
  end
  ns.procShown, ns.procShownInst = shownIds, shownInst
  if cc ~= ns.clearcasting then
    ns.clearcasting = cc
    if ns.ActionBars then ns.ActionBars.dirty = true end
  end
end

-- Any error here is kept for /fui auras instead of silently losing the row.
SafeScanBuffs = function()
  local ok, err = pcall(ScanPlayerBuffs)
  if not ok then ns.procDebug = { error = tostring(err) } end
end

local function ScanPlayerDebuffs(keep)
  if not PD.frame then return end
  local auras, blocked = ReadAuras("player", "HARMFUL")
  -- Everything refused (e.g. in combat): keep showing what we had rather
  -- than blinking to empty. Expired timers still clear themselves.
  if keep and blocked > 0 and #auras == 0 then return end
  local list, cure = {}, nil
  for _, a in ipairs(auras) do
    local d, i = a.d, a.index
    local dt = ns.Plain(d.dispelName)
    local c = (dt and DISPEL[dt]) or { 0.8, 0, 0 }
    if not cure and dt and cureNames[dt] then cure = cureNames[dt] end
    if #list < 6 then
      list[#list + 1] = { data = d, unit = "player", index = i, filter = "HARMFUL", size = 34, r = c[1], g = c[2], b = c[3] }
    end
  end
  local shown = Place(PD.frame, list)
  local hint = PD.hint
  hint:ClearAllPoints()
  if cure and shown > 0 then
    hint:SetPoint("RIGHT", PD.frame.icons[shown], "LEFT", -6, 0)
    hint:SetText(cure .. " ›")
  else
    hint:SetText("")
  end
end

local function ScanTarget(keep)
  if not TD.frame then return end
  local list = {}
  if UnitExists("target") then
    local mineList, blocked = ReadAuras("target", "HARMFUL|PLAYER")
    local others, blocked2 = ReadAuras("target", "HARMFUL")
    if keep and blocked + blocked2 > 0 and #mineList + #others == 0 then return end
    -- Yours, via the PLAYER filter: large with a gold border.
    for _, a in ipairs(mineList) do
      local d, i = a.d, a.index
      list[#list + 1] = { data = d, unit = "target", index = i, filter = "HARMFUL|PLAYER", size = 30, r = 0.95, g = 0.76, b = 0.31 }
    end
    -- Others: small and dimmed, only when we can tell they're not yours.
    for _, a in ipairs(others) do
      local d, i = a.d, a.index
      local mine = ns.Plain(d.isFromPlayerOrPlayerPet)
      if mine == nil then
        local src = ns.Plain(d.sourceUnit)
        if src then mine = (src == "player" or src == "pet") end
      end
      if mine == false then
        list[#list + 1] = { data = d, unit = "target", index = i, filter = "HARMFUL", size = 22, r = 0, g = 0, b = 0, dim = true }
      end
    end
  end
  Place(TD.frame, list)
end

-- Buffs on your target (enemies and friends), small, in one row.
local function ScanTargetBuffs(keep)
  if not TB.frame then return end
  local list = {}
  if UnitExists("target") then
    local auras, blocked = ReadAuras("target", "HELPFUL")
    if keep and blocked > 0 and #auras == 0 then return end
    for _, a in ipairs(auras) do
      local d, i = a.d, a.index
      local stealable = ns.Plain(d.isStealable)
      local r, g, b = 0, 0, 0
      if stealable then r, g, b = 0.2, 0.6, 1 end
      list[#list + 1] = { data = d, unit = "target", index = i, filter = "HELPFUL", size = 22, r = r, g = g, b = b }
    end
  end
  Place(TB.frame, list)
end

function TB:IsEnabled()
  return ns.profile.options.targetFrame == "forever" and ns.profile.options.targetAuras == "forever"
end

function TB:Build()
  NewContainer(self, "ForeverUITargetBuffs", 40, false)
end

-- Our own player rows only when chosen: in combat this client gives them
-- nothing to show.
function PR:IsEnabled()
  return ns.profile.options.playerAuras == "forever"
end

function PD:IsEnabled()
  return ns.profile.options.playerAuras == "forever"
end

function PR:Build()
  NewContainer(self, "ForeverUIProcs", 50, true)
  for _, id in ipairs(WHITELIST) do
    local n = ns.SpellName(id)
    if n and not whitelistNames[n] then
      whitelistNames[n] = true
      whitelistNameList[#whitelistNameList + 1] = n
    end
  end
end

function PD:Build()
  local f = NewContainer(self, "ForeverUIPlayerDebuffs", 50, true)
  self.hint = ns.Text(f, 11, "RIGHT")
  self.hint:SetTextColor(0.44, 0.88, 0.54)
  UpdateCures()
end

-- Only when Forever UI draws the target auras itself.
function TD:IsEnabled()
  return ns.profile.options.targetFrame == "forever" and ns.profile.options.targetAuras == "forever"
end

function PD:HideBlizzard()
  -- Hide in place: it belongs to Blizzard's Edit Mode "Buffs and Debuffs".
  ns.HideBlizzard("DebuffFrame", false, true)
end

function TD:Build()
  NewContainer(self, "ForeverUITargetDebuffs", 46, false)
end

local ev = CreateFrame("Frame")
ns.SafeRegister(ev, "UNIT_AURA", "player", "target")
ns.SafeRegister(ev, "PLAYER_TARGET_CHANGED")
ns.SafeRegister(ev, "PLAYER_ENTERING_WORLD")
ns.SafeRegister(ev, "SPELLS_CHANGED")
ev:SetScript("OnEvent", function(_, e, unit)
  if not ns.profile then return end
  if e == "UNIT_AURA" then
    if unit == "player" then
      SafeScanBuffs()
      ScanPlayerDebuffs(true)
    elseif unit == "target" then
      ScanTarget(true)
      ScanTargetBuffs(true)
    end
  elseif e == "PLAYER_TARGET_CHANGED" then
    ScanTarget()
    ScanTargetBuffs()
  elseif e == "SPELLS_CHANGED" then
    UpdateCures()
  else
    SafeScanBuffs()
    ScanPlayerDebuffs()
    ScanTarget()
    ScanTargetBuffs()
  end
end)

local acc = 0
ev:SetScript("OnUpdate", function(_, el)
  acc = acc + el
  if acc < 0.1 then return end
  acc = 0
  local now = GetTime()
  for _, f in ipairs(containers) do
    for _, b in ipairs(f.icons) do
      if b:IsShown() and b.exp then
        local left = b.exp - now
        if left > 0 then
          b.time:SetText(FormatTime(left))
        else
          b:Hide()
        end
      end
    end
  end
end)

-- Shared with Buffs.lua.
ns.ReadAuras = ReadAuras
ns.SetAuraCooldown = SetAuraCooldown
ns.SetAuraCount = SetCount
ns.FormatTime = FormatTime
ns.procIds = whitelistIds
