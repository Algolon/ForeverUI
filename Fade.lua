local ADDON, ns = ...

-- Hover fade: the chat and the damage meter sit semi-transparent and come
-- to full strength while you hover them (or type in the chat). How
-- transparent depends on the context mode, set per mode in /fui fade.

local FD = {}
ns.Fade = FD

local MODES = { "combat", "quest", "dungeon", "raid", "pvp", "rest" }
local MODE_LABELS = { combat = "In combat", quest = "Questing", dungeon = "Dungeon", raid = "Raid", pvp = "PvP", rest = "Resting" }
local GROUPS = { "chat", "meter" }
local GROUP_LABELS = { chat = "Chat", meter = "Damage meter" }

ns.defaults.options.fade = {
  on = true,
  chat = { combat = 0.6, quest = 0.5, dungeon = 0.5, raid = 0.5, pvp = 0.5, rest = 0.4 },
  meter = { combat = 1, quest = 0.5, dungeon = 0.8, raid = 0.8, pvp = 0.8, rest = 0.35 },
}

local function Mode()
  local cx = ns.Context
  if cx and cx.inCombat then return "combat" end
  return (cx and cx.mode) or "quest"
end

------------------------------------------------------------------------
-- What gets faded
------------------------------------------------------------------------
local function ChatFrames()
  local list = {}
  for i = 1, 20 do
    local c = _G["ChatFrame" .. i]
    if c and c:IsShown() then list[#list + 1] = c end
  end
  return list
end

local function ChatHovered()
  local p = ns.chatPanel
  if p and p:IsMouseOver(30, 0, 0, 0) then return true end
  for i = 1, 20 do
    local e = _G["ChatFrame" .. i .. "EditBox"]
    if e and e:HasFocus() then return true end
  end
  return false
end

local function Ease(frame, want, el)
  local cur = frame:GetAlpha()
  if math.abs(cur - want) > 0.01 then
    frame:SetAlpha(cur + (want - cur) * math.min(1, el * 8))
  elseif cur ~= want then
    frame:SetAlpha(want)
  end
end

local chatAlpha, restored = 1, true

local function Tick(_, el)
  local o = ns.profile and ns.profile.options.fade
  if not o then return end
  if not o.on then
    if not restored then
      -- Give everything back once after switching off.
      for _, c in ipairs(ChatFrames()) do c:SetAlpha(1) end
      if ns.chatPanel then ns.chatPanel:SetAlpha(1) end
      if GeneralDockManager then GeneralDockManager:SetAlpha(1) end
      for win, parts in pairs(ns.Skins and ns.Skins.parts or {}) do
        win:SetAlpha(1)
        parts.sync()
      end
      ns.chatFade, restored = 1, true
    end
    return
  end
  restored = false
  local mode = Mode()

  -- Chat
  local want = ChatHovered() and 1 or (o.chat[mode] or 1)
  chatAlpha = chatAlpha + (want - chatAlpha) * math.min(1, el * 8)
  if math.abs(chatAlpha - want) <= 0.01 then chatAlpha = want end
  ns.chatFade = chatAlpha
  for _, c in ipairs(ChatFrames()) do c:SetAlpha(chatAlpha) end
  if ns.chatPanel then ns.chatPanel:SetAlpha(chatAlpha) end
  if GeneralDockManager then GeneralDockManager:SetAlpha(chatAlpha) end

  -- Damage meter windows
  for win, parts in pairs(ns.Skins and ns.Skins.parts or {}) do
    if win:IsVisible() then
      Ease(win, win:IsMouseOver() and 1 or (o.meter[mode] or 1), el)
      parts.sync()
    end
  end
end

ns:On("PLAYER_LOGIN", function()
  local f = CreateFrame("Frame")
  f:SetScript("OnUpdate", Tick)
end)

------------------------------------------------------------------------
-- Settings: /fui fade
------------------------------------------------------------------------
local panel

local function Slider(parent, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(110, 14)
  s:SetMinMaxValues(0.1, 1)
  s:SetValueStep(0.05)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.18)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  s:SetThumbTexture(ns.TEX)
  local thumb = s:GetThumbTexture()
  thumb:SetSize(8, 14)
  thumb:SetVertexColor(0.95, 0.76, 0.31)
  s.value = ns.NumText(s, 11)
  s.value:SetPoint("LEFT", s, "RIGHT", 6, 0)
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v * 20 + 0.5) / 20
    self.value:SetText(math.floor(v * 100 + 0.5) .. "%")
    if not self.silent then onChange(v) end
  end)
  return s
end

local function Build()
  local p = CreateFrame("Frame", "ForeverUIFadePanel", UIParent)
  p:SetSize(400, 64 + #MODES * 26 + 44)
  p:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  p:SetFrameStrata("FULLSCREEN_DIALOG")
  p:SetMovable(true)
  p:EnableMouse(true)
  p:SetClampedToScreen(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", p.StopMovingOrSizing)
  ns.Backdrop(p, 0.95)
  ns.BorderColor(p, 0.55, 0.45, 0.2, 1)

  local title = ns.Text(p, 14)
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("|cfff2c14eForever UI|r  ·  Hover fade")
  local sub = ns.Text(p, 10)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetTextColor(0.6, 0.63, 0.68)
  sub:SetText("Strength while you're not hovering, per context mode")

  for g, group in ipairs(GROUPS) do
    local h = ns.Text(p, 11)
    h:SetPoint("TOPLEFT", 110 + (g - 1) * 150, -58)
    h:SetTextColor(0.95, 0.76, 0.31)
    h:SetText(GROUP_LABELS[group])
  end

  p.sliders = {}
  for r, mode in ipairs(MODES) do
    local y = -80 - (r - 1) * 26
    local l = ns.Text(p, 11)
    l:SetPoint("TOPLEFT", 14, y)
    l:SetText(MODE_LABELS[mode])
    for g, group in ipairs(GROUPS) do
      local s = Slider(p, function(v) ns.profile.options.fade[group][mode] = v end)
      s:SetPoint("TOPLEFT", 110 + (g - 1) * 150, y)
      p.sliders[#p.sliders + 1] = { s = s, group = group, mode = mode }
    end
  end

  p.toggle = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
  p.toggle:SetSize(24, 24)
  p.toggle:SetPoint("BOTTOMLEFT", 10, 10)
  p.toggle:SetScript("OnClick", function(self) ns.profile.options.fade.on = self:GetChecked() and true or false end)
  local tt = ns.Text(p, 11)
  tt:SetPoint("LEFT", p.toggle, "RIGHT", 2, 0)
  tt:SetText("Hover fade on")

  local done = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  done:SetSize(90, 22)
  done:SetText("Done")
  done:SetPoint("BOTTOMRIGHT", -12, 10)
  done:SetScript("OnClick", function() p:Hide() end)
  tinsert(UISpecialFrames, "ForeverUIFadePanel")
  p:Hide()
  return p
end

function FD.Open()
  panel = panel or Build()
  local o = ns.profile.options.fade
  for _, e in ipairs(panel.sliders) do
    e.s.silent = true
    e.s:SetValue(o[e.group][e.mode] or 1)
    e.s.silent = false
  end
  panel.toggle:SetChecked(o.on)
  panel:Show()
end
