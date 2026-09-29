local ADDON, ns = ...

------------------------------------------------------------------------
-- Quest objectives, read from your quest log (out of combat it's plain
-- text): item name -> { quest title, "8/12", done }. Used by the tooltip
-- line and the progress toasts.
------------------------------------------------------------------------
local Q = {}
ns.Quests = Q
Q.items = {}

local function QuestTitle(i)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader then return ns.Plain(info.title) end
    return nil
  end
  if GetQuestLogTitle then
    local title, _, _, isHeader = GetQuestLogTitle(i)
    if not isHeader then return ns.Plain(title) end
  end
end

function Q.Scan()
  local items = {}
  local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
    or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
  for i = 1, n do
    local title = QuestTitle(i)
    if title and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
      for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
        local text, kind, done = GetQuestLogLeaderBoard(j, i)
        text = ns.Plain(text)
        if text and kind == "item" then
          local name, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)")
          if name then
            items[name] = { quest = title, progress = have .. "/" .. need, done = done and true or false }
          end
        end
      end
    end
  end
  Q.items = items
end

------------------------------------------------------------------------
-- Smart tooltip: "Quest item" and which quest still needs it.
------------------------------------------------------------------------
local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

-- The item's class (12 = quest). This client has no global GetItemInfo;
-- the instant lookup lives in C_Item and needs no server data.
local function ItemClass(link)
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if fn then
    local ok, _, _, _, _, _, classID = pcall(fn, link)
    if ok then return ns.Plain(classID) end
  end
end

local function AddQuestLines(tt)
  if not ns.profile or not ns.profile.options.questTooltip then return end
  local ok, name, link = pcall(tt.GetItem, tt)
  if not ok then return end
  name, link = ns.Plain(name), ns.Plain(link)
  if not name then return end
  local need = Q.items[name]
  local classID = link and ItemClass(link)
  if need then
    local r, g, b = 1, 0.82, 0.3
    if need.done then r, g, b = 0.45, 0.85, 0.5 end
    tt:AddLine("Quest: " .. need.quest .. "  (" .. need.progress .. ")", r, g, b)
    tt:Show()
  elseif classID == QUEST_CLASS then
    tt:AddLine("Quest item", 1, 0.82, 0.3)
    tt:Show()
  end
end

ns:On("PLAYER_LOGIN", function()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
      if tt == GameTooltip or tt == ItemRefTooltip then AddQuestLines(tt) end
    end)
  else
    GameTooltip:HookScript("OnTooltipSetItem", AddQuestLines)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", AddQuestLines) end
  end
  Q.Scan()
  local qev = CreateFrame("Frame")
  ns.SafeRegister(qev, "QUEST_LOG_UPDATE")
  qev:SetScript("OnEvent", Q.Scan)
end)

------------------------------------------------------------------------
-- Progress toasts: "Lunar Fungus 9/12" in a small Gilded panel instead of
-- Blizzard's yellow text. Other messages still go to Blizzard's spot.
------------------------------------------------------------------------
local QT = ns:NewModule("questtoast", "Quest Progress", { pos = { p = "TOP", rp = "TOP", x = 0, y = -190 }, scale = 1, alpha = 1, fade = "always" })

local W, H, MAX, SHOW = 260, 40, 3, 3.5

function QT:IsEnabled()
  return ns.profile.options.questToast
end

local function Toast(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(W, H)
  ns.Backdrop(t, 0.8)
  t.title = ns.Text(t, 10)
  t.title:SetPoint("TOPLEFT", 8, -5)
  t.title:SetPoint("RIGHT", -8, 0)
  t.title:SetWordWrap(false)
  t.title:SetTextColor(0.7, 0.62, 0.45)
  t.text = ns.Text(t, 13)
  t.text:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -2)
  t.text:SetPoint("RIGHT", -60, 0)
  t.text:SetWordWrap(false)
  t.count = ns.NumText(t, 13, "RIGHT")
  t.count:SetPoint("TOPRIGHT", -8, -18)
  t.bar = ns.Bar(t, 2)
  t.bar:SetPoint("BOTTOMLEFT", 4, 3)
  t.bar:SetPoint("BOTTOMRIGHT", -4, 3)
  t.bar:SetStatusBarColor(0.95, 0.76, 0.31)
  t:Hide()
  return t
end

function QT:Build()
  local f = CreateFrame("Frame", "ForeverUIQuestToasts", UIParent)
  f:SetSize(W, MAX * (H + 4))
  self.frame = f
  self.toasts = {}
  for i = 1, MAX do self.toasts[i] = Toast(f) end

  -- Quest progress arrives as an info message; we take those over.
  if UIErrorsFrame then UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE") end
  local ev = CreateFrame("Frame")
  ns.SafeRegister(ev, "UI_INFO_MESSAGE")
  ev:SetScript("OnEvent", function(_, e, a1, a2)
    local msg = a2
    if type(a1) == "string" and a2 == nil then msg = a1 end -- older clients: message only
    if not QT:Show(msg) and UIErrorsFrame then
      UIErrorsFrame:AddMessage(msg, 1, 1, 0, 1)
    end
  end)

  f:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, t in ipairs(self.toasts) do
      if t:IsShown() then
        local age = now - t.born
        if age > SHOW + 0.6 then
          t:Hide()
        elseif age > SHOW then
          t:SetAlpha(1 - (age - SHOW) / 0.6)
        end
      end
    end
  end)
end

-- true when the message was quest progress and got a toast.
function QT:Show(msg)
  local plain = ns.Plain(msg)
  if not plain then return false end
  local name, have, need = plain:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
  local complete = not name and plain:match("^(.-)%s*%(Complete%)$")
  if not name and not complete then return false end
  have, need = tonumber(have), tonumber(need)

  -- Newest on top: shift the others down, reuse the oldest.
  local t = table.remove(self.toasts)
  table.insert(self.toasts, 1, t)
  for i, x in ipairs(self.toasts) do
    x:ClearAllPoints()
    x:SetPoint("TOP", self.frame, "TOP", 0, -(i - 1) * (H + 4))
  end
  -- The quest it belongs to, when we know the objective by name.
  Q.Scan()
  local info = Q.items[name or complete]
  t.title:SetText(info and info.quest or "Quest progress")
  t.text:SetText(name or complete)
  if complete or (have and need and have >= need) then
    t.count:SetText(complete and "Done" or (have .. "/" .. need))
    t.count:SetTextColor(0.45, 0.85, 0.5)
    t.bar:SetMinMaxValues(0, 1)
    t.bar:SetValue(1)
    t.bar:SetStatusBarColor(0.45, 0.85, 0.5)
  else
    t.count:SetText(have .. "/" .. need)
    t.count:SetTextColor(1, 1, 1)
    t.bar:SetMinMaxValues(0, need)
    t.bar:SetValue(have)
    t.bar:SetStatusBarColor(0.95, 0.76, 0.31)
  end
  t.born = GetTime()
  t:SetAlpha(1)
  t:Show()
  return true
end

function QT:OnEditMode(on)
  if on then
    local t = self.toasts[1]
    t.title:SetText("Quest progress")
    t.text:SetText("Lunar Fungus")
    t.count:SetText("9/12")
    t.bar:SetMinMaxValues(0, 12)
    t.bar:SetValue(9)
    t.born = GetTime() + 3600
    t:SetAlpha(1)
    t:Show()
  else
    for _, t in ipairs(self.toasts) do t:Hide() end
  end
end
