local ADDON, ns = ...
local C = ns:NewModule("cast", "Cast Bar", { pos = { p = "BOTTOM", rp = "BOTTOM", x = 0, y = 146 }, scale = 1, alpha = 1, fade = "always" })
local W = 250

-- The swing timer needs the combat log, which clients with secret values
-- don't give to addons. On those clients the swing timer is left out.
local function SwingAvailable()
  return not ns.SECRETS
end

function C:Build()
  local f = CreateFrame("Frame", "ForeverUICastBar", UIParent)
  f:SetSize(W, 38)
  self.frame = f

  local bar = ns.Bar(f, 14)
  bar:SetPoint("TOPLEFT", 18, 0)
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetStatusBarColor(0.5, 0.84, 1)
  bar.icon = f:CreateTexture(nil, "ARTWORK")
  bar.icon:SetSize(14, 14)
  bar.icon:SetPoint("RIGHT", bar, "LEFT", -3, 0)
  bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- Red zone at the end = your latency. Queue the next cast once the bar enters it.
  bar.lat = bar:CreateTexture(nil, "OVERLAY")
  bar.lat:SetColorTexture(0.88, 0.31, 0.27, 0.75)
  bar.lat:SetPoint("TOPRIGHT")
  bar.lat:SetPoint("BOTTOMRIGHT")
  bar.lat:SetWidth(1)
  bar.text = ns.Text(bar, 11)
  bar.text:SetPoint("LEFT", 4, 0)
  bar.time = ns.NumText(bar, 11, "RIGHT")
  bar.time:SetPoint("RIGHT", -4, 0)
  bar:Hide()
  bar.icon:Hide()
  self.bar = bar

  local sw = ns.Bar(f, 5)
  sw:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
  sw:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -6)
  sw:SetStatusBarColor(0.85, 0.85, 0.85)
  sw.text = ns.Text(f, 10)
  sw.text:SetPoint("TOPLEFT", sw, "BOTTOMLEFT", 0, -2)
  sw.time = ns.NumText(f, 10, "RIGHT")
  sw.time:SetPoint("TOPRIGHT", sw, "BOTTOMRIGHT", 0, -2)
  self.swing = sw
  self:HideSwing()

  self.guid = UnitGUID("player")
  self.nextSwing = {}
  -- Maul, Heroic Strike, Cleave, Raptor Strike replace a white swing.
  for _, id in ipairs({ 6807, 78, 845, 2973 }) do
    local n = ns.SpellName(id)
    if n then self.nextSwing[n] = true end
  end
  self.maul = ns.SpellName(6807)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    ns.SafeRegister(ev, e, "player")
  end
  if SwingAvailable() then ns.SafeRegister(ev, "COMBAT_LOG_EVENT_UNFILTERED") end
  ev:SetScript("OnEvent", function(_, e)
    if e == "COMBAT_LOG_EVENT_UNFILTERED" then
      C:CombatLog()
    elseif e == "UNIT_SPELLCAST_START" or e == "UNIT_SPELLCAST_DELAYED" then
      C:Start(false)
    elseif e == "UNIT_SPELLCAST_CHANNEL_START" or e == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
      C:Start(true)
    elseif e == "UNIT_SPELLCAST_INTERRUPTED" then
      C:Stop("Interrupted")
    else
      C:StopIfIdle()
    end
  end)
  f:SetScript("OnUpdate", function() C:OnUpdate() end)
end

local function Casting()
  local a = UnitCastingInfo("player")
  local b = UnitChannelInfo("player")
  return ns.Has(a) or ns.Has(b)
end

function C:StopIfIdle()
  if not Casting() then self:Stop(nil) end
end

function C:Start(channel)
  local name, tex, st, et, _
  if channel then
    name, _, tex, st, et = UnitChannelInfo("player")
  else
    name, _, tex, st, et = UnitCastingInfo("player")
  end
  if not ns.Has(name) then return end
  local bar = self.bar
  ns.SetText(bar.text, name)
  pcall(bar.icon.SetTexture, bar.icon, tex)
  bar.icon:Show()
  bar:SetStatusBarColor(0.5, 0.84, 1)
  bar:SetMinMaxValues(0, 1)
  self.fadeAt = nil

  local pst, pet = ns.Plain(st), ns.Plain(et)
  if pst and pet then
    self.cast = { st = pst / 1000, et = pet / 1000, channel = channel }
    local _, _, home, world = GetNetStats()
    local lat = math.max(home or 0, world or 0) / 1000
    local dur = math.max(self.cast.et - self.cast.st, 0.01)
    bar.lat:SetWidth(math.max(1, math.min(1, lat / dur) * (W - 18)))
    bar.lat:SetShown(not channel)
  else
    -- Secret cast times: let the client drive the bar if it can.
    self.cast = { timer = true, channel = channel }
    bar.lat:Hide()
    bar.time:SetText("")
    local durFn = channel and UnitChannelDuration or UnitCastingDuration
    local ok = false
    if durFn and bar.SetTimerDuration then
      local got, obj = pcall(durFn, "player")
      if got and obj then ok = pcall(bar.SetTimerDuration, bar, obj) end
    end
    if not ok then bar:SetValue(1) end
  end
  bar:Show()
end

function C:Stop(message)
  self.cast = nil
  local bar = self.bar
  if message then
    bar.text:SetText(message)
    bar.time:SetText("")
    bar:SetStatusBarColor(0.88, 0.31, 0.27)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.lat:Hide()
    self.fadeAt = GetTime() + 0.6
  elseif not ns.editing then
    bar:Hide()
    bar.icon:Hide()
  end
end

function C:CombatLog()
  local _, sub, _, src, _, _, _, _, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()
  if src ~= self.guid then return end
  if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
    self:ResetSwing()
  elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and spellName and self.nextSwing[spellName] then
    self:ResetSwing()
  end
end

function C:ResetSwing()
  self.swingStart = GetTime()
  self.swingDur = ns.Plain(UnitAttackSpeed("player")) or 2
end

-- Swing timer shows in Bear form only (form IDs 5 = Bear, 8 = Dire Bear).
function C:ShowSwing(now)
  if not SwingAvailable() then return false end
  if ns.editing then return true end
  if not self.swingStart then return false end
  local id = GetShapeshiftFormID and GetShapeshiftFormID()
  if id ~= 5 and id ~= 8 then return false end
  return InCombatLockdown() or (now - self.swingStart) < (self.swingDur + 1)
end

function C:HideSwing()
  local sw = self.swing
  sw:Hide()
  sw.text:Hide()
  sw.time:Hide()
end

function C:OnUpdate()
  local now = GetTime()
  local bar = self.bar
  local c = self.cast
  if c and not c.timer then
    local dur = c.et - c.st
    local p = dur > 0 and (now - c.st) / dur or 1
    if p >= 1.05 then
      self:Stop(nil)
    else
      if c.channel then p = 1 - p end
      bar:SetValue(math.max(0, math.min(1, p)))
      bar.time:SetFormattedText("%.1f / %.1f", math.max(0, now - c.st), dur)
    end
  elseif not c and self.fadeAt and now > self.fadeAt then
    self.fadeAt = nil
    if not ns.editing then
      bar:Hide()
      bar.icon:Hide()
    end
  end

  if not self:ShowSwing(now) then
    self:HideSwing()
    return
  end
  local sw = self.swing
  local start, dur = self.swingStart or now, self.swingDur or 2.5
  local elapsed = math.min(now - start, dur)
  sw:SetValue(dur > 0 and elapsed / dur or 1)
  sw.time:SetFormattedText("%.1f / %.1f", elapsed, dur)
  local queued = false
  if self.maul and IsCurrentSpell then
    local ok, v = pcall(IsCurrentSpell, self.maul)
    queued = ok and ns.Plain(v) and true or false
  end
  sw.text:SetText(queued and "Swing  ·  |cffffffffMaul queued|r" or "Swing")
  sw:Show()
  sw.text:Show()
  sw.time:Show()
end

function C:OnEditMode(on)
  local bar = self.bar
  if on and not self.cast then
    bar.text:SetText("Cast bar (preview)")
    bar.time:SetText("1.2 / 2.5")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.5)
    bar:Show()
  elseif not on and not self.cast then
    bar:Hide()
    bar.icon:Hide()
  end
end

function C:HideBlizzard()
  ns.HideBlizzard("CastingBarFrame", true)
  ns.HideBlizzard("PlayerCastingBarFrame", true)
end
