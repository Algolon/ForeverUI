local ADDON, ns = ...

-- Blizzard's chat stays Blizzard's: position, tabs and messages work as
-- before. We dress it in the Forever UI style, add a copy window and
-- shorter channel names. Chat messages can be secret on this
-- client, so a message we can't read is skipped, never forced.

-- Keep a Blizzard texture invisible, even when Blizzard fades it back in
-- (the chat background fades in on mouse-over).
local function KeepInvisible(t)
  if type(t) ~= "table" or not t.SetAlpha then return end
  t:SetAlpha(0)
  hooksecurefunc(t, "SetAlpha", function(self, a)
    if a and a > 0 then self:SetAlpha(0) end
  end)
end

local function StripTextures(frame)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then KeepInvisible(r) end
  end
end

------------------------------------------------------------------------
-- Chat copy window
------------------------------------------------------------------------
local MAX_LINES = 300

-- Links, colours and icons removed: "[Iron Pike]" instead of the raw link code.
local function Clean(text)
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|K.-|k", "?")
  return text
end

local copy

local function BuildCopyWindow()
  local f = CreateFrame("Frame", "ForeverUIChatCopy", UIParent)
  f:SetSize(620, 400)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  ns.Backdrop(f, 0.95)
  tinsert(UISpecialFrames, "ForeverUIChatCopy") -- Escape closes it

  f.title = ns.Text(f, 13)
  f.title:SetPoint("TOPLEFT", 12, -10)
  f.title:SetText("|cfff2c14eChat|r  ·  select text and press Ctrl+C")

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetSize(70, 20)
  close:SetPoint("TOPRIGHT", -8, -7)
  close:SetText("Close")
  close:SetScript("OnClick", function() f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f)
  scroll:SetPoint("TOPLEFT", 12, -34)
  scroll:SetPoint("BOTTOMRIGHT", -12, 12)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
  end)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(0)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(590)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
  -- Read-only: typing puts the original text back.
  edit:SetScript("OnTextChanged", function(self, user)
    if user and f.text then self:SetText(f.text) end
  end)
  scroll:SetScrollChild(edit)
  f.edit, f.scroll = edit, scroll
  f:Hide()
  return f
end

function ns.OpenChatCopy()
  copy = copy or BuildCopyWindow()
  local chat = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
  local lines, skipped = {}, 0
  local n = chat.GetNumMessages and chat:GetNumMessages() or 0
  for i = math.max(1, n - MAX_LINES + 1), n do
    local ok, line = pcall(function()
      local text = chat:GetMessageInfo(i)
      return Clean(text)
    end)
    if ok and type(line) == "string" then lines[#lines + 1] = line else skipped = skipped + 1 end
  end
  if skipped > 0 then lines[#lines + 1] = "(" .. skipped .. " line(s) could not be read by addons)" end
  copy.text = table.concat(lines, "\n")
  copy.edit:SetText(copy.text)
  copy:Show()
  copy.edit:SetFocus()
  copy.edit:HighlightText()
  C_Timer.After(0, function() copy.scroll:SetVerticalScroll(copy.scroll:GetVerticalScrollRange()) end)
end

------------------------------------------------------------------------
-- Chat style
------------------------------------------------------------------------
local CHAT_TEXTURES = CHAT_FRAME_TEXTURES or { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture",
  "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }

-- One chat window: background art out, Forever UI tab and input box.
-- Also used for windows opened later (whispers in their own tab).
local dressed = {}
local function DressWindow(name)
  if dressed[name] or not _G[name] then return end
  dressed[name] = true
  -- Blizzard's own chat background: gone, ours is the only one.
  for _, part in ipairs(CHAT_TEXTURES) do KeepInvisible(_G[name .. part]) end
  -- Tabs: Blizzard art out, a small Forever UI panel behind the text.
  local tab = _G[name .. "Tab"]
  if tab then
    StripTextures(tab)
    local bg = CreateFrame("Frame", nil, tab)
    bg:SetPoint("TOPLEFT", 2, -4)
    bg:SetPoint("BOTTOMRIGHT", -2, 0)
    bg:SetFrameLevel(math.max(tab:GetFrameLevel() - 1, 0))
    ns.Backdrop(bg, 0.7)
  end
  -- Every chat window has its own input box: all in Forever UI style.
  local edit = _G[name .. "EditBox"]
  if edit then
    for _, part in ipairs({ "Left", "Mid", "Right" }) do
      KeepInvisible(_G[name .. "EditBox" .. part] or edit[part])
    end
    local box = CreateFrame("Frame", nil, edit)
    box:SetPoint("TOPLEFT", 2, -3)
    box:SetPoint("BOTTOMRIGHT", -2, 3)
    box:SetFrameLevel(math.max(edit:GetFrameLevel() - 1, 0))
    ns.Backdrop(box, 0.85)
  end
end

local function DressChat()
  local chat = _G.ChatFrame1
  if not chat then return end

  local panel = CreateFrame("Frame", "ForeverUIChatPanel", UIParent)
  panel:SetFrameStrata("BACKGROUND")
  panel:SetPoint("TOPLEFT", chat, "TOPLEFT", -6, 6)
  panel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 6, -6)
  ns.Backdrop(panel, 0.62)
  ns.chatPanel = panel

  -- Copy button, top right of the chat: dim until you hover the chat.
  local btn = CreateFrame("Button", "ForeverUIChatCopyButton", UIParent)
  btn:SetSize(20, 20)
  btn:SetPoint("TOPRIGHT", chat, "TOPRIGHT", 2, 2)
  btn:SetFrameStrata("MEDIUM")
  ns.Backdrop(btn, 0.85)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("TOPLEFT", 3, -3)
  btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  btn.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
  btn:SetScript("OnClick", ns.OpenChatCopy)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine("Copy chat")
    GameTooltip:AddLine("Opens this tab's recent lines, ready to copy.", 0.8, 0.82, 0.86, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
  btn:SetAlpha(0.35)
  local acc = 0
  btn:SetScript("OnUpdate", function(self, el)
    acc = acc + el
    if acc < 0.1 then return end
    acc = 0
    self:SetAlpha(((panel:IsMouseOver() or self:IsMouseOver()) and 1 or 0.35) * (ns.chatFade or 1))
  end)

  for i = 1, (NUM_CHAT_WINDOWS or 10) do DressWindow("ChatFrame" .. i) end
  if type(_G.FCF_OpenTemporaryWindow) == "function" then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for i = 1, 20 do DressWindow("ChatFrame" .. i) end
    end)
  end
end

------------------------------------------------------------------------
-- Shorter channel names
------------------------------------------------------------------------
-- "[1. General - Redridge Mountains]" becomes "[1]" (short) or
-- "[1. General]" (name); "off" leaves Blizzard's text alone. The link part
-- stays, so clicking the channel name still works. Messages the client
-- keeps secret are passed through untouched.
local function Shorten(text)
  local mode = ns.profile and ns.profile.options.chatChannels or "short"
  if mode == "off" then return text end
  return (text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", function(link, label)
    local num, name = label:match("^(%d+)%.%s*([^%-]+)")
    if not num then return nil end -- [Party], [Guild]... stay as they are
    if mode == "short" then return "|Hchannel:" .. link .. "|h[" .. num .. "]|h" end
    return "|Hchannel:" .. link .. "|h[" .. num .. ". " .. strtrim(name) .. "]|h"
  end))
end

local function HookChannels()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    -- ChatFrame2 is the combat log: leave it alone.
    if frame and i ~= 2 and frame.AddMessage then
      local original = frame.AddMessage
      frame.AddMessage = function(self, text, ...)
        if not ns.IsSecret(text) and type(text) == "string" then
          local ok, short = pcall(Shorten, text)
          if ok and short then text = short end
        end
        return original(self, text, ...)
      end
    end
  end
end

------------------------------------------------------------------------
-- Chat buttons in one column, top left of the chat
------------------------------------------------------------------------
-- Blizzard spreads them along the left edge (social at the top, menu at
-- the bottom); here they stack from the top, hidden ones skipped. When
-- Blizzard moves one back, we put it in line again.
local CHAT_BUTTONS = { "QuickJoinToastButton", "FriendsMicroButton", "ChatFrameChannelButton",
  "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatFrameMenuButton" }

local function StackChatButtons()
  local panel = ns.chatPanel
  if not panel then return end
  local busy, pending = false, false
  local function layout()
    busy = true
    local prev
    for _, n in ipairs(CHAT_BUTTONS) do
      local b = _G[n]
      if b and b:IsShown() then
        b:ClearAllPoints()
        if prev then
          b:SetPoint("TOP", prev, "BOTTOM", 0, -2)
        else
          -- Centred on a column 14 px left of the panel: the buttons'
          -- frames are wider than their art, so aligning their right edge
          -- left a gap and pushed the art off screen.
          b:SetPoint("TOP", panel, "TOPLEFT", -14, 0)
        end
        prev = b
      end
    end
    busy = false
  end
  local function soon()
    if busy or pending then return end
    pending = true
    C_Timer.After(0, function()
      pending = false
      layout()
    end)
  end
  for _, n in ipairs(CHAT_BUTTONS) do
    local b = _G[n]
    if b then
      hooksecurefunc(b, "SetPoint", soon)
      b:HookScript("OnShow", soon)
      b:HookScript("OnHide", soon)
    end
  end
  layout()
end

ns:On("PLAYER_LOGIN", function()
  -- In this order: the buttons line up against the panel DressChat makes.
  for _, step in ipairs({ { "chat", DressChat }, { "channels", HookChannels }, { "buttons", StackChatButtons } }) do
    local what, fn = step[1], step[2]
    local ok, err = pcall(fn)
    if not ok then ns.Print("|cffff6b5aerror in " .. what .. " style|r: " .. tostring(err)) end
  end
end)
