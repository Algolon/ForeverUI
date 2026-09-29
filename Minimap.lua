local ADDON, ns = ...
local MM = ns:NewModule("minimap", "Minimap", { pos = { p = "TOPRIGHT", rp = "TOPRIGHT", x = -8, y = -8 }, scale = 1, alpha = 1, fade = "always" })

-- Square, borderless minimap with zone and coordinates underneath. The
-- small Blizzard buttons (tracking, mail, calendar, queue...) move into a
-- row under the map: dimmed, full brightness when you hover the minimap.

local SIZE = 200
local ROW_BUTTON = 22

-- Whatever exists on this client ends up in the button row.
local function ButtonCandidates()
  local list = {}
  local function add(b)
    if type(b) == "table" and b.SetParent and b.GetWidth then list[#list + 1] = b end
  end
  for _, n in ipairs({ "MiniMapTrackingFrame", "MiniMapTracking", "MiniMapMailFrame", "MiniMapLFGFrame", "LFGMinimapFrame",
    "MiniMapBattlefieldFrame", "QueueStatusMinimapButton", "GameTimeFrame", "ExpansionLandingPageMinimapButton" }) do
    add(_G[n])
  end
  if MinimapCluster then
    add(MinimapCluster.Tracking)
    add(MinimapCluster.IndicatorFrame)
  end
  return list
end

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

local function Coords()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not ns.Plain(map) then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok2 or not pos then return nil end
  local x, y = ns.Plain(pos.x), ns.Plain(pos.y)
  if not x or not y then return nil end
  return x * 100, y * 100
end

local PVP_COLORS = {
  sanctuary = { 0.41, 0.8, 0.94 }, friendly = { 0.1, 1, 0.1 }, hostile = { 1, 0.1, 0.1 },
  contested = { 1, 0.7, 0 }, combat = { 1, 0.1, 0.1 },
}

function MM:Build()
  local f = CreateFrame("Frame", "ForeverUIMinimap", UIParent)
  f:SetSize(SIZE, SIZE + 20 + ROW_BUTTON)
  self.frame = f

  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOP")
  holder:SetSize(SIZE, SIZE)
  -- Own rounded frame, larger than the panels' corners: dark fill behind,
  -- bronze 1 px ring on top. The map's mask follows the ring's inner curve,
  -- so no map pixels show past the corners.
  local S = ns.STYLE
  local bg = holder:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(ns.MEDIA .. "mapfill")
  bg:SetVertexColor(S.fill[1], S.fill[2], S.fill[3], 0.6)

  Minimap:SetParent(holder)
  Minimap:ClearAllPoints()
  Minimap:SetPoint("CENTER", holder, "CENTER")
  Minimap:SetSize(SIZE - 2, SIZE - 2)
  pcall(Minimap.SetMaskTexture, Minimap, ns.MEDIA .. "mapmask")

  local ringFrame = CreateFrame("Frame", nil, holder)
  ringFrame:SetAllPoints()
  ringFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  local ring = ringFrame:CreateTexture(nil, "OVERLAY")
  ring:SetAllPoints()
  ring:SetTexture(ns.MEDIA .. "mapborder")
  ring:SetVertexColor(S.border[1], S.border[2], S.border[3], S.border[4])
  -- Only the archaeology ring goes; the quest area glow stays, so you can
  -- see you're in the right area.
  for _, fn in ipairs({ "SetArchBlobRingScalar", "SetArchBlobRingAlpha" }) do
    if Minimap[fn] then pcall(Minimap[fn], Minimap, 0) end
  end

  -- Mouse wheel zooms (only if Blizzard doesn't already handle it).
  Minimap:EnableMouseWheel(true)
  if not Minimap:GetScript("OnMouseWheel") then
    Minimap:SetScript("OnMouseWheel", function(self, delta)
      local z, levels = self:GetZoom(), self:GetZoomLevels()
      if delta > 0 and z < levels - 1 then self:SetZoom(z + 1)
      elseif delta < 0 and z > 0 then self:SetZoom(z - 1) end
    end)
  end

  f.zone = ns.Text(f, 11)
  f.zone:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 2, -4)
  f.zone:SetPoint("RIGHT", f, "RIGHT", -70, 0)
  f.zone:SetWordWrap(false)
  f.coords = ns.NumText(f, 11, "RIGHT")
  f.coords:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", -2, -4)
  f.coords:SetTextColor(0.8, 0.82, 0.86)

  -- Button row under the zone line.
  local row = CreateFrame("Frame", nil, f)
  row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  row:SetSize(SIZE, ROW_BUTTON)
  f.row = row
  local busy = false
  local function layout()
    if busy then return end
    busy = true
    local x = 0
    for _, b in ipairs(ButtonCandidates()) do
      if b:GetParent() ~= row then b:SetParent(row) end
      local w, h = b:GetWidth(), b:GetHeight()
      local scale = (h > 0) and math.min(1, ROW_BUTTON / h) or 1
      b:SetScale(scale)
      b:ClearAllPoints()
      b:SetPoint("LEFT", row, "LEFT", x / scale, 0)
      if b:IsShown() then x = x + w * scale + 4 end
    end
    busy = false
  end
  self.Layout = Debounce(layout)
  layout()
  local function moved()
    if not busy then self.Layout() end
  end
  for _, b in ipairs(ButtonCandidates()) do hooksecurefunc(b, "SetPoint", moved) end

  -- Dim the row unless you hover the minimap area.
  local acc = 0
  f:SetScript("OnUpdate", function(_, el)
    local target = (f:IsMouseOver() or ns.editing) and 1 or 0.45
    local cur = row:GetAlpha()
    if math.abs(cur - target) > 0.01 then row:SetAlpha(cur + (target - cur) * math.min(1, el * 10)) end
    acc = acc + el
    if acc < 0.5 then return end
    acc = 0
    MM:UpdateText()
  end)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    ns.SafeRegister(ev, e)
  end
  ev:SetScript("OnEvent", function() MM:UpdateText() end)
  self:UpdateText()
end

function MM:UpdateText()
  local f = self.frame
  f.zone:SetText(GetMinimapZoneText and GetMinimapZoneText() or "")
  local pvp = GetZonePVPInfo and GetZonePVPInfo()
  local c = PVP_COLORS[ns.Plain(pvp) or ""] or { 1, 0.82, 0 }
  f.zone:SetTextColor(c[1], c[2], c[3])
  local x, y = Coords()
  f.coords:SetText(x and string.format("%.1f, %.1f", x, y) or "")
end

function MM:HideBlizzard()
  -- MinimapCluster belongs to Blizzard's Edit Mode: hide in place. The map
  -- itself already lives in our frame.
  ns.HideBlizzard("MinimapCluster", false, true)
  if Minimap.ZoomIn then ns.HideBlizzard(Minimap.ZoomIn, false, true) end
  if Minimap.ZoomOut then ns.HideBlizzard(Minimap.ZoomOut, false, true) end
  for _, n in ipairs({ "MinimapZoomIn", "MinimapZoomOut", "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture",
    "MinimapBackdrop", "MinimapToggleButton", "MiniMapWorldMapButton", "MinimapZoneTextButton", "TimeManagerClockButton" }) do
    ns.HideBlizzard(n)
  end
end
