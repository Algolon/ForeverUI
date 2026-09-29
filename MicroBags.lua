local ADDON, ns = ...
local MB = ns:NewModule("micro", "Micro Menu", { pos = { p = "BOTTOMRIGHT", rp = "BOTTOMRIGHT", x = -6, y = 50 }, scale = 1, alpha = 1, fade = "always" })
local BB = ns:NewModule("bags", "Bag Bar", { pos = { p = "BOTTOMRIGHT", rp = "BOTTOMRIGHT", x = -6, y = 4 }, scale = 1, alpha = 1, fade = "always" })

-- These are Blizzard's own buttons, moved into our bars. That keeps every
-- click, tooltip and hotkey working exactly as before.
local MICRO = {
  "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
  "SocialsMicroButton", "GuildMicroButton", "WorldMapMicroButton", "LFGMicroButton",
  "MainMenuMicroButton", "HelpMicroButton",
}
local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
  "CharacterReagentBag0Slot" }
local BAG_IDS = { 0, 1, 2, 3, 4, 5 } -- container IDs, same order (5 = reagent bag)

-- Give a Blizzard bag slot our rounded bronze edge; the slot keeps working
-- exactly as before.
local skinned = {}
local function Skin(b)
  if skinned[b] then return end
  skinned[b] = true
  local nt = b.GetNormalTexture and b:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
  local name = b.GetName and b:GetName()
  local icon = b.icon or b.Icon or (name and _G[name .. "IconTexture"])
  if icon then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.MaskIcon(b, icon)
  end
  local skin = CreateFrame("Frame", nil, b)
  skin:SetAllPoints()
  skin:SetFrameLevel(b:GetFrameLevel() + 2)
  ns.Edge(skin)
  b.fuiFree = ns.NumText(skin, 13, "RIGHT")
  b.fuiFree:SetPoint("TOPRIGHT", -2, -2)
end

-- Collapse repeated calls into one layout on the next frame.
local function Debounce(fn)
  local pending = false
  return function()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
      pending = false
      fn()
    end)
  end
end

local function MicroList()
  local names = (type(MICRO_BUTTONS) == "table" and #MICRO_BUTTONS > 0) and MICRO_BUTTONS or MICRO
  local list = {}
  for _, n in ipairs(names) do
    local b = type(n) == "string" and _G[n] or n
    if type(b) == "table" and b.SetParent then list[#list + 1] = b end
  end
  return list
end

function MB:Build()
  local f = CreateFrame("Frame", "ForeverUIMicroBar", UIParent)
  f:SetSize(100, 30)
  self.frame = f
  local busy = false
  local function layout()
    if busy then return end
    busy = true
    local x, h = 0, 1
    for _, b in ipairs(MicroList()) do
      if b:GetParent() ~= f then b:SetParent(f) end
      -- Blizzard scales some of these buttons; offsets are in the
      -- button's own scale, sizes we add up in ours.
      local s = b:GetScale()
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x / s, 0)
      if b:IsShown() then
        x = x + b:GetWidth() * s + 1
        h = math.max(h, b:GetHeight() * s)
      end
    end
    f:SetSize(math.max(x - 1, 1), h)
    busy = false
  end
  self.Layout = Debounce(layout)
  layout()
  -- Blizzard re-anchors these buttons now and then; put them back.
  local function moved()
    if not busy then self.Layout() end
  end
  for _, b in ipairs(MicroList()) do hooksecurefunc(b, "SetPoint", moved) end
  for _, fn in ipairs({ "UpdateMicroButtonsParent", "MoveMicroButtons", "UpdateMicroButtons" }) do
    if type(_G[fn]) == "function" then hooksecurefunc(fn, self.Layout) end
  end
  if MicroMenu and MicroMenu.Layout then hooksecurefunc(MicroMenu, "Layout", self.Layout) end
end

function MB:HideBlizzard()
  ns.HideBlizzard("MicroButtonAndBagsBar")
  ns.HideBlizzard("MicroMenuContainer")
end

------------------------------------------------------------------------
-- Bags
------------------------------------------------------------------------
local function BagApi()
  local C = C_Container
  return (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots,
         (C and C.GetContainerNumSlots) or GetContainerNumSlots
end

function BB:Build()
  local f = CreateFrame("Frame", "ForeverUIBagBar", UIParent)
  f:SetSize(200, 40)
  self.frame = f
  local busy = false
  local function layout()
    if busy then return end
    busy = true
    local x, h = 0, 1
    for _, n in ipairs(BAGS) do
      local b = _G[n]
      if b then
        if b:GetParent() ~= f then b:SetParent(f) end
        local s = b:GetScale()
        b:ClearAllPoints()
        b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -x / s, 0)
        b:Show()
        x = x + b:GetWidth() * s + 3
        h = math.max(h, b:GetHeight() * s)
        Skin(b)
      end
    end
    local key = _G.KeyRingButton
    if key then
      if key:GetParent() ~= f then key:SetParent(f) end
      local s = key:GetScale()
      key:ClearAllPoints()
      key:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -x / s, 0)
      x = x + key:GetWidth() * s + 3
      h = math.max(h, key:GetHeight() * s)
    end
    f:SetSize(math.max(x - 3, 1), h)
    busy = false
    self:UpdateCount()
  end
  self.Layout = Debounce(layout)
  layout()
  -- Blizzard re-anchors bag buttons now and then; put them back.
  local function moved()
    if not busy then self.Layout() end
  end
  for _, n in ipairs(BAGS) do
    if _G[n] then hooksecurefunc(_G[n], "SetPoint", moved) end
  end
  if _G.KeyRingButton then hooksecurefunc(_G.KeyRingButton, "SetPoint", moved) end
  if BagsBar and BagsBar.Layout then hooksecurefunc(BagsBar, "Layout", self.Layout) end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do ns.SafeRegister(ev, e) end
  ev:SetScript("OnEvent", function() BB:UpdateCount() end)
end

function BB:UpdateCount()
  local numFree, numSlots = BagApi()
  if not numFree or not numSlots then return end
  local total = 0
  for i, name in ipairs(BAGS) do
    local bag = BAG_IDS[i]
    local free, bagType = numFree(bag)
    free = free or 0
    local btn = _G[name]
    if btn and btn.fuiFree then
      if (numSlots(bag) or 0) > 0 then
        btn.fuiFree:SetText(free)
        if free == 0 then btn.fuiFree:SetTextColor(1, 0.42, 0.35) else btn.fuiFree:SetTextColor(1, 1, 1) end
      else
        btn.fuiFree:SetText("")
      end
    end
    -- Quivers and ammo pouches don't count as free bag space.
    if bagType == nil or bagType == 0 then total = total + free end
  end
end

function BB:HideBlizzard()
  ns.HideBlizzard("BagsBar")
end
