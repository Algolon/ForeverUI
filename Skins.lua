local ADDON, ns = ...

-- A light Gilded Monolith touch on Blizzard's damage meter: a warm dark
-- panel behind each window and a bronze edge around it. Blizzard's own
-- frames are never changed; our frames only follow them (anchored to them,
-- shown and hidden with them). /fui meter lists what was found.

local SK = {}
ns.Skins = SK
SK.styled = {}
SK.parts = {}  -- window -> { under, over }, for fading
SK.shrunk = {} -- window -> keys of the header parts made smaller

local HEADER_SCALE = 0.67

local function IsFrame(v)
  return type(v) == "table" and type(v.GetObjectType) == "function" and v.IsObjectType
    and v:IsObjectType("Frame")
end

-- Top-level meter windows: named DamageMeter..., not a sub-part (no
-- "ScrollBox", "Header" ... in the name), and window-sized.
local function Candidates()
  local list = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and k:find("^DamageMeter") and IsFrame(v) and not SK.styled[v] then
      local sub = k:find("Scroll") or k:find("Header") or k:find("Button") or k:find("Bar%d")
        or k:find("Entry") or k:find("Tab") or k:find("Menu") or k:find("Dropdown")
      local w, h = ns.Plain(v:GetWidth()), ns.Plain(v:GetHeight())
      if not sub and w and h and w >= 120 and h >= 40 then list[#list + 1] = { name = k, frame = v } end
    end
  end
  -- The session windows are the real windows (DamageMeter is their
  -- container); style only those when they exist, else the outermost.
  local sessions = {}
  for _, c in ipairs(list) do
    if c.name:find("SessionWindow%d+$") then sessions[#sessions + 1] = c end
  end
  if #sessions > 0 then return sessions end
  local set = {}
  for _, c in ipairs(list) do set[c.frame] = true end
  local out = {}
  for _, c in ipairs(list) do
    local p = c.frame:GetParent()
    if not set[p] then out[#out + 1] = c end
  end
  return out
end

local function Style(c)
  local win = c.frame
  local strata = win:GetFrameStrata()
  local level = win:GetFrameLevel()

  local under = CreateFrame("Frame", nil, UIParent)
  under:SetPoint("TOPLEFT", win, "TOPLEFT", -3, 3)
  under:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 3, -3)
  under:SetFrameStrata(strata)
  under:SetFrameLevel(math.max(level - 1, 0))
  ns.Backdrop(under, 0.55)
  for _, t in ipairs(under.edgeParts or {}) do t:Hide() end

  local over = CreateFrame("Frame", nil, UIParent)
  over:SetAllPoints(under)
  over:SetFrameStrata(strata)
  over:SetFrameLevel(level + 20)
  ns.Backdrop(over, 0)
  for _, t in ipairs(over.fillParts or {}) do t:Hide() end

  local function sync()
    local shown = win:IsVisible()
    under:SetShown(shown)
    over:SetShown(shown)
    local a = win:GetEffectiveAlpha()
    under:SetAlpha(a)
    over:SetAlpha(a)
  end
  SK.parts[win] = { under = under, over = over, sync = sync }
  win:HookScript("OnShow", sync)
  win:HookScript("OnHide", sync)
  sync()
  SK.styled[win] = c.name
  SK.ShrinkHeader(win)
end

-- The top strip of a session window, made about 2/3 as high:
--   * the controls scale down (the type dropdown a little less, so the
--     "Damage Done" title stays readable)
--   * MinimizeContainer (the list with the rows) moves up by what the strip
--     lost, so the strip itself is lower
-- Names come from /fui meter on this client. A scaled frame keeps its
-- anchors, so it stays in place, only smaller.
local PART_SCALES = {
  DamageMeterTypeDropdown = 0.74,
  SessionDropdown = HEADER_SCALE,
  SettingsDropdown = HEADER_SCALE,
  MinimizeButton = HEADER_SCALE,
}

-- Move the container's top anchors up by `amount`, and again whenever
-- Blizzard re-anchors it (only the points Blizzard itself just set).
local function Lift(c, amount, scaled)
  local ours, busy, pending = {}, false, false
  local function apply()
    pending = false
    busy = true
    local pts = {}
    for i = 1, c:GetNumPoints() do
      local p, rel, rp, x, y = c:GetPoint(i)
      pts[#pts + 1] = { p, rel, rp, ns.Plain(x) or 0, ns.Plain(y) or 0 }
    end
    c:ClearAllPoints()
    for _, pt in ipairs(pts) do
      local p, rel, rp, x, y = pt[1], pt[2], pt[3], pt[4], pt[5]
      -- Anchored to a part we scaled: that part's shrinking moves it already.
      if p:find("TOP") and ours[p] ~= y and not (rel and scaled[rel]) then y = y + amount end
      c:SetPoint(p, rel, rp, x, y)
      ours[p] = y
    end
    busy = false
  end
  hooksecurefunc(c, "SetPoint", function()
    if busy or pending then return end
    pending = true
    C_Timer.After(0, apply)
  end)
  apply()
end

function SK.ShrinkHeader(win)
  if SK.shrunk[win] then return end
  local done, scaled = {}, {}
  for k, scale in pairs(PART_SCALES) do
    local v = win[k]
    if IsFrame(v) then
      v:SetScale(scale)
      scaled[v] = true
      done[#done + 1] = k
    end
  end
  local c = win.MinimizeContainer
  local dd = win.DamageMeterTypeDropdown
  local amount = 8
  if IsFrame(dd) then amount = math.floor((ns.Plain(dd:GetHeight()) or 24) * (1 - HEADER_SCALE) + 0.5) end
  SK.lift = amount
  if IsFrame(c) then
    Lift(c, amount, scaled)
    done[#done + 1] = "MinimizeContainer (moved up " .. amount .. ")"
  end
  -- The strip's own art, when it has recognisable names: the band gets
  -- shorter, divider lines move up with the list.
  for k, v in pairs(win) do
    if type(k) == "string" and type(v) == "table" and v.IsObjectType and v:IsObjectType("Texture") then
      if k:find("Header") and not k:find("Line") then
        local h = ns.Plain(v:GetHeight())
        if h and h > amount + 4 then
          v:SetHeight(h - amount)
          done[#done + 1] = k .. " (shorter)"
        end
      elseif k:find("Divider") or k:find("Separator") or k:find("Line") then
        Lift(v, amount, scaled)
        done[#done + 1] = k .. " (moved up)"
      end
    end
  end
  SK.headerParts = SK.headerParts or {}
  SK.headerParts[win] = scaled
  SK.shrunk[win] = done
end

function SK.Scan()
  if not ns.profile or not ns.profile.options.meterSkin then return 0 end
  local found = Candidates()
  for _, c in ipairs(found) do Style(c) end
  return #found
end

local ev = CreateFrame("Frame")
ns.SafeRegister(ev, "PLAYER_ENTERING_WORLD")
ns.SafeRegister(ev, "ADDON_LOADED")
ns.SafeRegister(ev, "PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e, name)
  if e == "ADDON_LOADED" and not (type(name) == "string" and name:find("DamageMeter")) then return end
  -- Windows appear a moment after loading.
  C_Timer.After(2, SK.Scan)
end)

function SK.Report()
  SK.Scan()
  local names = {}
  for _, n in pairs(SK.styled) do names[#names + 1] = n end
  table.sort(names)
  ns.Print("damage meter windows styled: " .. (#names > 0 and table.concat(names, ", ") or "none found (open the meter first)"))
  -- What each window is made of, so the header can be targeted exactly.
  for win, n in pairs(SK.styled) do
    local keys = {}
    for k, v in pairs(win) do
      if type(k) == "string" and IsFrame(v) then keys[#keys + 1] = k end
    end
    table.sort(keys)
    print("  " .. n .. " parts: " .. table.concat(keys, ", "))
    print("  made smaller: " .. (#SK.shrunk[win] > 0 and table.concat(SK.shrunk[win], ", ") or "nothing"))
    SK.Layout(win)
    SK.RowReport(win)
  end
end

-- Where things hang, for fixing the strip's height: the list container and
-- every texture of the window, with their anchors and height.
local function Rel(win, rel)
  if rel == nil then return "?" end
  if rel == win then return "window" end
  for k, v in pairs(win) do
    if v == rel and type(k) == "string" then return k end
  end
  return (rel.GetName and rel:GetName()) or "other"
end

local function Points(win, r)
  local out = {}
  for i = 1, r:GetNumPoints() do
    local p, rel, rp, x, y = r:GetPoint(i)
    out[#out + 1] = string.format("%s>%s:%s(%s,%s)", p, Rel(win, rel), tostring(rp),
      tostring(ns.Plain(x) and math.floor(x + 0.5)), tostring(ns.Plain(y) and math.floor(y + 0.5)))
  end
  local h = ns.Plain(r:GetHeight())
  return table.concat(out, " ") .. "  h=" .. tostring(h and math.floor(h + 0.5))
end

function SK.Layout(win)
  local c = win.MinimizeContainer
  if IsFrame(c) then print("  MinimizeContainer: " .. Points(win, c)) end
  for k, v in pairs(win) do
    if type(k) == "string" and type(v) == "table" and v.IsObjectType and v:IsObjectType("Texture") then
      print("  tex " .. k .. ": " .. Points(win, v))
    end
  end
  local n = 0
  for _, r in ipairs({ win:GetRegions() }) do
    if r:IsObjectType("Texture") then n = n + 1 end
  end
  print("  textures on the window: " .. n .. " (named ones listed above)")
end

------------------------------------------------------------------------
-- Issue Reporter (the WoW Forever bug button, top left): small and faint
-- until you hover it, or hidden. F6 keeps working either way.
-- /fui issue small|hidden|normal
------------------------------------------------------------------------
local ISSUE_SCALE, ISSUE_ALPHA = 0.6, 0.3
SK.issue = {}
local issueHooked = {}

local function IssueFrames()
  local list = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and (k:find("IssueReport") or k:find("BugReport")) and IsFrame(v) then
      local p = v:GetParent()
      if p == nil or p == UIParent then list[#list + 1] = { name = k, frame = v } end
    end
  end
  return list
end

function SK.Issue()
  if not ns.profile then return end
  local mode = ns.profile.options.issueReporter
  for _, c in ipairs(IssueFrames()) do
    local f = c.frame
    SK.issue[f] = c.name
    if mode == "hidden" then
      ns.HideBlizzard(f, false, true)
    elseif mode == "small" then
      if not issueHooked[f] then
        issueHooked[f] = true
        f:SetScale(ISSUE_SCALE)
        f:SetAlpha(ISSUE_ALPHA)
        f:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
        f:HookScript("OnLeave", function(self) self:SetAlpha(ISSUE_ALPHA) end)
      end
    end
  end
end

local issueEv = CreateFrame("Frame")
ns.SafeRegister(issueEv, "PLAYER_ENTERING_WORLD")
issueEv:SetScript("OnEvent", function()
  C_Timer.After(3, SK.Issue)
end)

function SK.IssueReport()
  SK.Issue()
  local names = {}
  for _, n in pairs(SK.issue) do names[#names + 1] = n end
  table.sort(names)
  ns.Print("issue reporter frames: " .. (#names > 0 and table.concat(names, ", ") or "none found"))
end

------------------------------------------------------------------------
-- Damage meter rows: the class icon as a square at the row's height, and
-- the text at your chosen size (/fui meterfont 9), so more of the name
-- fits. Rows are recycled while scrolling, so this runs every second on
-- the visible windows. The header is left alone (it has its own size).
------------------------------------------------------------------------
local ICON_KEYS = { "Icon", "ClassIcon", "SpecIcon", "icon" }

local function IsTexture(v)
  return type(v) == "table" and type(v.IsObjectType) == "function" and v:IsObjectType("Texture")
end

-- Square by its own height: the width follows, wherever it's anchored.
local function Square(tex)
  local w, h = ns.Plain(tex:GetWidth()), ns.Plain(tex:GetHeight())
  if w and h and h > 4 and h < 60 and math.abs(w - h) > 0.5 then tex:SetWidth(h) end
end

-- An unnamed icon: a texture flush with the row's left edge, a bit wider
-- than high (bar fills and backgrounds are far wider).
local function LooksLikeIcon(frame, tex)
  local w, h = ns.Plain(tex:GetWidth()), ns.Plain(tex:GetHeight())
  local fl, tl = ns.Plain(frame:GetLeft()), ns.Plain(tex:GetLeft())
  return w and h and fl and tl and h >= 8 and h <= 40 and w > h * 1.15 and w < h * 3 and math.abs(tl - fl) <= 4
end

local function Walk(frame, depth, skip, size)
  if depth > 8 or skip[frame] then return end
  for _, key in ipairs(ICON_KEYS) do
    local icon = frame[key]
    if IsTexture(icon) then
      Square(icon)
    elseif IsFrame(icon) then
      -- On this client the row's Icon is a 24x24 frame in a 17 px row:
      -- make it a square at the row's height (its texture fills it).
      local h = ns.Plain(frame:GetHeight())
      local w, ih = ns.Plain(icon:GetWidth()), ns.Plain(icon:GetHeight())
      if h and h > 4 and h < 60 and w and ih and (math.abs(w - h) > 0.5 or math.abs(ih - h) > 0.5) then
        icon:SetSize(h, h)
      end
    end
  end
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:IsObjectType("Texture") then
      if depth >= 3 and LooksLikeIcon(frame, r) then Square(r) end
    elseif size and r:IsObjectType("FontString") then
      local ok, path, cur, flags = pcall(r.GetFont, r)
      if ok and path and cur and math.abs(cur - size) > 0.1 then r:SetFont(path, size, flags) end
    end
  end
  for _, c in ipairs({ frame:GetChildren() }) do Walk(c, depth + 1, skip, size) end
end

-- The session timer ("[00:16]") is text straight on the window, next to the
-- title: shrink it like the title (74%), from its own original size.
local timerSize = {}
local function ShrinkTimer(win)
  for _, r in ipairs({ win:GetRegions() }) do
    if r:IsObjectType("FontString") then
      local text = ns.Plain(r:GetText())
      local ok, path, cur, flags = pcall(r.GetFont, r)
      if ok and path and cur and (timerSize[r] or (text and text:find("^%[?%d+:%d%d"))) then
        timerSize[r] = timerSize[r] or math.floor(cur * 0.74 + 0.5)
        if math.abs(cur - timerSize[r]) > 0.1 then r:SetFont(path, timerSize[r], flags) end
      end
    end
  end
  for k, v in pairs(win) do
    if type(k) == "string" and (k:find("Timer") or k:find("Time")) and type(v) == "table" and v.IsObjectType then
      local fs = v:IsObjectType("FontString") and v or (v.Text and v.Text.IsObjectType and v.Text)
      if fs and fs:IsObjectType("FontString") then
        local ok, path, cur, flags = pcall(fs.GetFont, fs)
        if ok and path and cur then
          timerSize[fs] = timerSize[fs] or math.floor(cur * 0.74 + 0.5)
          if math.abs(cur - timerSize[fs]) > 0.1 then fs:SetFont(path, timerSize[fs], flags) end
        end
      elseif v:IsObjectType("Frame") and not (SK.headerParts[win] and SK.headerParts[win][v]) then
        v:SetScale(0.74)
        SK.headerParts[win][v] = true
      end
    end
  end
end

function SK.Rows()
  if not ns.profile or not ns.profile.options.meterSkin then return end
  local size = ns.profile.options.meterFont
  for win in pairs(SK.styled) do
    if win:IsVisible() then
      SK.headerParts = SK.headerParts or {}
      SK.headerParts[win] = SK.headerParts[win] or {}
      pcall(ShrinkTimer, win)
      Walk(win, 0, SK.headerParts[win], size)
    end
  end
end

-- One row, for /fui meter: what it's made of and how big.
function SK.RowReport(win)
  local found
  local function find(f, d)
    if found or d > 8 then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c:IsObjectType("StatusBar") and d >= 2 then found = f return end
      find(c, d + 1)
    end
  end
  find(win, 0)
  if not found then
    print("  row: none visible (fight something first)")
    return
  end
  local parts = {}
  local function size(r)
    local w, h = ns.Plain(r:GetWidth()), ns.Plain(r:GetHeight())
    return string.format("%sx%s", tostring(w and math.floor(w + 0.5)), tostring(h and math.floor(h + 0.5)))
  end
  for k, v in pairs(found) do
    if type(k) == "string" and type(v) == "table" and v.IsObjectType then
      parts[#parts + 1] = k .. "=" .. v:GetObjectType() .. " " .. size(v)
    end
  end
  table.sort(parts)
  print("  row " .. size(found) .. ": " .. table.concat(parts, ", "))
end

C_Timer.NewTicker(1, function() pcall(SK.Rows) end)
