local ADDON, ns = ...
local EM = {}
ns.EditMode = EM

local movers = {}
local selected, ref, picking
local panel, grid

local BLUE = { 0.43, 0.76, 1 }
local GOLD = { 0.95, 0.76, 0.31 }
local GREEN = { 0.45, 0.85, 0.5 }
local GRID = 8

local function Snap(v)
  return math.floor(v / GRID + 0.5) * GRID
end

local function AnchorMover(m)
  local mv, f = movers[m], m.frame
  local s = f:GetScale()
  -- Blizzard frames (buffs, target auras) can have secret sizes.
  local w, h = ns.Plain(f:GetWidth()) or 200, ns.Plain(f:GetHeight()) or 40
  mv:ClearAllPoints()
  mv:SetPoint("CENTER", f, "CENTER")
  mv:SetSize(math.max(w * s, 24), math.max(h * s, 14))
end

-- Magnetic alignment: within ALIGN px of another frame's top, centre or
-- bottom (and left, centre, right), snap to it exactly. This is what puts
-- the player and target frames at precisely the same height.
local ALIGN = 8
local function Align(m, cx, cy)
  local mv = movers[m]
  local w, h = mv:GetWidth(), mv:GetHeight()
  local bestY, bestX
  for other, omv in pairs(movers) do
    if other ~= m and omv:IsShown() then
      local ol, ob, ow, oh = omv:GetRect()
      if ol then
        -- my top/centre/bottom vs. theirs
        for _, mine in ipairs({ h / 2, 0, -h / 2 }) do
          for _, theirs in ipairs({ ob + oh, ob + oh / 2, ob }) do
            local d = theirs - (cy + mine)
            if math.abs(d) <= ALIGN and (not bestY or math.abs(d) < math.abs(bestY)) then bestY = d end
          end
        end
        for _, mine in ipairs({ -w / 2, 0, w / 2 }) do
          for _, theirs in ipairs({ ol, ol + ow / 2, ol + ow }) do
            local d = theirs - (cx + mine)
            if math.abs(d) <= ALIGN and (not bestX or math.abs(d) < math.abs(bestX)) then bestX = d end
          end
        end
      end
    end
  end
  return cx + (bestX or 0), cy + (bestY or 0), bestX ~= nil or bestY ~= nil
end

-- Store the mover's position (UIParent units) and move the real frame there.
local function Commit(m, snap)
  local cx, cy = movers[m]:GetCenter()
  if not cx then return end
  if snap and ns.profile.options.snap then
    local aligned
    cx, cy, aligned = Align(m, cx, cy)
    if not aligned then
      local mid = UIParent:GetWidth() / 2
      if math.abs(cx - mid) < 12 then cx = mid else cx = Snap(cx) end
      cy = Snap(cy)
    end
  end
  ns:M(m.key).pos = { p = "CENTER", rp = "BOTTOMLEFT", x = cx, y = cy }
  ns:ApplyLayout(m)
  if m == selected then EM:ShowCoords() end
end

local function Paint(m, color)
  local mv = movers[m]
  if not mv then return end
  ns.Fill(mv, color[1], color[2], color[3], 0.22)
  ns.BorderColor(mv, color[1], color[2], color[3], 0.95)
end

local function CreateMover(m)
  local mv = CreateFrame("Button", nil, UIParent)
  mv:SetFrameStrata("DIALOG")
  mv:SetMovable(true)
  mv:SetClampedToScreen(true)
  mv:EnableMouse(true)
  mv:RegisterForDrag("LeftButton")
  ns.Backdrop(mv, 0.22)
  mv.label = ns.Text(mv, 11, "CENTER")
  mv.label:SetPoint("CENTER")
  mv.label:SetText(m.label)
  movers[m] = mv
  Paint(m, BLUE)

  mv:SetScript("OnMouseDown", function(self)
    if picking then
      self.picked = true
      EM:SetRef(m)
    else
      EM:Select(m)
    end
  end)
  mv:SetScript("OnMouseUp", function(self) self.picked = false end)
  mv:SetScript("OnDragStart", function(self)
    if self.picked then return end
    local l, b, w, h = self:GetRect()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    self:SetSize(w, h)
    self:StartMoving()
    self.dragging = true
  end)
  mv:SetScript("OnDragStop", function(self)
    if not self.dragging then return end
    self:StopMovingOrSizing()
    self.dragging = false
    Commit(m, true)
    AnchorMover(m)
  end)
  mv:SetScript("OnUpdate", function(self)
    if self.dragging then Commit(m, false) end
  end)
  mv:Hide()
  return mv
end

local function BuildGrid()
  local g = CreateFrame("Frame", nil, UIParent)
  g:SetAllPoints(UIParent)
  g:SetFrameStrata("BACKGROUND")
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local step = 32
  local function line(vertical, offset, r, gr, b, a)
    local t = g:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(r, gr, b, a)
    if vertical then
      t:SetPoint("TOPLEFT", g, "TOPLEFT", offset, 0)
      t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", offset, 0)
      t:SetWidth(1)
    else
      t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, offset)
      t:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, offset)
      t:SetHeight(1)
    end
  end
  -- Start from the centre so the centre lines sit on the grid.
  for x = (w / 2) % step, w, step do line(true, x, 1, 1, 1, 0.07) end
  for y = (h / 2) % step, h, step do line(false, y, 1, 1, 1, 0.07) end
  line(true, w / 2, 0.75, 0.35, 1, 0.6)
  line(false, h / 2, 0.75, 0.35, 1, 0.6)
  g:Hide()
  return g
end

local function PanelButton(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 100, 22)
  b:SetText(text)
  return b
end

local function Slider(parent, label, minV, maxV, step, onChange, fmt)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(180, 16)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.18)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  s:SetThumbTexture(ns.TEX)
  local thumb = s:GetThumbTexture()
  thumb:SetSize(10, 16)
  thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
  s.label = ns.Text(s, 11)
  s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
  s.label:SetText(label)
  s.value = ns.Text(s, 11)
  s.value:SetPoint("LEFT", s, "RIGHT", 10, 0)
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    self.value:SetText(fmt and fmt(v) or (math.floor(v * 100 + 0.5) .. "%"))
    if not self.silent then onChange(v) end
  end)
  return s
end

local function BuildPanel()
  local p = CreateFrame("Frame", "ForeverUIEditPanel", UIParent)
  p:SetSize(340, 322)
  p:SetPoint("TOP", UIParent, "TOP", 0, -110)
  p:SetFrameStrata("FULLSCREEN_DIALOG")
  p:SetMovable(true)
  p:EnableMouse(true)
  p:SetClampedToScreen(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", p.StopMovingOrSizing)
  ns.Backdrop(p, 0.95)
  ns.BorderColor(p, 0.55, 0.45, 0.2, 1)

  p.title = ns.Text(p, 14)
  p.title:SetPoint("TOPLEFT", 14, -12)
  p.title:SetText("|cfff2c14eForever UI|r  ·  Edit Mode")
  p.profile = ns.Text(p, 10)
  p.profile:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
  p.profile:SetTextColor(0.6, 0.63, 0.68)

  p.sel = ns.Text(p, 13)
  p.sel:SetPoint("TOPLEFT", 14, -54)
  p.sel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  p.scale = Slider(p, "Scale", 0.5, 2, 0.05, function(v)
    if not selected then return end
    ns:M(selected.key).scale = v
    ns:ApplyLayout(selected)
    AnchorMover(selected)
  end)
  p.scale:SetPoint("TOPLEFT", 14, -94)

  p.alpha = Slider(p, "Opacity", 0.1, 1, 0.05, function(v)
    if not selected then return end
    ns:M(selected.key).alpha = v
    ns:ApplyLayout(selected)
  end)
  p.alpha:SetPoint("TOPLEFT", 14, -136)

  p.fade = PanelButton(p, "Visible: Always", 190)
  p.fade:SetPoint("TOPLEFT", 12, -162)
  p.fade:SetScript("OnClick", function()
    if not selected then return end
    local s, modes = ns:M(selected.key), ns.Fader.modes
    local idx = 1
    for i, v in ipairs(modes) do
      if v == s.fade then idx = i end
    end
    s.fade = modes[idx % #modes + 1]
    ns:ApplyLayout(selected)
    EM:Refresh()
  end)

  p.resetOne = PanelButton(p, "Reset frame", 110)
  p.resetOne:SetPoint("LEFT", p.fade, "RIGHT", 6, 0)
  p.resetOne:SetScript("OnClick", function()
    if not selected then return end
    ns:ResetModule(selected)
    AnchorMover(selected)
    EM:Refresh()
  end)

  p.snap = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
  p.snap:SetSize(24, 24)
  p.snap:SetPoint("TOPLEFT", 10, -190)
  p.snap:SetScript("OnClick", function(self)
    ns.profile.options.snap = self:GetChecked() and true or false
  end)
  p.snapText = ns.Text(p, 11)
  p.snapText:SetPoint("LEFT", p.snap, "RIGHT", 2, 0)
  p.snapText:SetText("Snap: align to other frames, grid and screen centre")

  -- Align to: pick a second frame, then line the selected one up with it.
  p.pick = PanelButton(p, "Align to...", 110)
  p.pick:SetPoint("TOPLEFT", 12, -220)
  p.pick:SetScript("OnClick", function()
    if not selected then return end
    picking = not picking
    EM:Refresh()
  end)
  p.refText = ns.Text(p, 11)
  p.refText:SetPoint("LEFT", p.pick, "RIGHT", 8, 0)
  p.refText:SetPoint("RIGHT", p, "RIGHT", -12, 0)
  p.refText:SetJustifyH("LEFT")
  p.alignButtons = {}
  local prev
  for _, e in ipairs({ { "TOP", "Top" }, { "MIDDLE", "Middle" }, { "BOTTOM", "Bottom" },
    { "LEFT", "Left" }, { "CENTRE", "Centre" }, { "RIGHT", "Right" } }) do
    local b = PanelButton(p, e[2], 49)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -248) end
    b:SetScript("OnClick", function() EM:AlignTo(e[1]) end)
    p.alignButtons[#p.alignButtons + 1] = b
    prev = b
  end

  p.hint = ns.Text(p, 10)
  p.hint:SetPoint("TOPLEFT", 14, -280)
  p.hint:SetTextColor(0.6, 0.63, 0.68)
  p.hint:SetText("Drag frames · arrows = 1 px · Shift+arrow = 10 px · Esc = done")

  p.resetAll = PanelButton(p, "Reset all", 130)
  p.resetAll:SetPoint("BOTTOMLEFT", 12, 10)
  p.resetAll:SetScript("OnClick", function(self)
    if self.armed then
      self.armed = false
      self:SetText("Reset all")
      ns:ResetLayout()
      return
    end
    self.armed = true
    self:SetText("Sure? Click again")
    C_Timer.After(3, function()
      if self.armed then
        self.armed = false
        self:SetText("Reset all")
      end
    end)
  end)

  p.done = PanelButton(p, "Done", 90)
  p.done:SetPoint("BOTTOMRIGHT", -12, 10)
  p.done:SetScript("OnClick", function() EM:Close() end)

  -- Size box under the panel, only for frames with a width/height setting
  -- (the party frames).
  local sb = CreateFrame("Frame", nil, p)
  sb:SetSize(340, 96)
  sb:SetPoint("TOP", p, "BOTTOM", 0, -4)
  ns.Backdrop(sb, 0.95)
  ns.BorderColor(sb, 0.55, 0.45, 0.2, 1)
  local px = function(v) return math.floor(v + 0.5) .. " px" end
  local function SetSize(axis, v)
    if not selected or not selected.ApplySize then return end
    ns:M(selected.key)[axis] = math.floor(v + 0.5)
    selected:ApplySize()
    C_Timer.After(0, function() if selected then AnchorMover(selected) end end)
  end
  sb.w = Slider(sb, "Width", 100, 300, 2, function(v) SetSize("w", v) end, px)
  sb.w:SetPoint("TOPLEFT", 14, -26)
  sb.h = Slider(sb, "Height", 24, 80, 1, function(v) SetSize("h", v) end, px)
  sb.h:SetPoint("TOPLEFT", 14, -70)
  sb:Hide()
  p.sizeBox = sb

  local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
  p:EnableKeyboard(true)
  p:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput(false)
      if picking then
        picking = false
        EM:Refresh()
      else
        EM:Close()
      end
      return
    end
    local d = ARROWS[key]
    if d and selected then
      self:SetPropagateKeyboardInput(false)
      local n = IsShiftKeyDown() and 10 or 1
      EM:Nudge(d[1] * n, d[2] * n)
      return
    end
    self:SetPropagateKeyboardInput(true)
  end)

  p:Hide()
  return p
end

function EM:Select(m)
  if selected then Paint(selected, BLUE) end
  if m and m == ref then ref = nil end
  selected = m
  picking = false
  if m then Paint(m, GOLD) end
  EM:Refresh()
end

-- The frame the selected one gets lined up with (green).
function EM:SetRef(m)
  picking = false
  if m == selected then
    EM:Refresh()
    return
  end
  if ref then Paint(ref, BLUE) end
  ref = m
  if m then Paint(m, GREEN) end
  EM:Refresh()
end

-- Line up an edge (or the middle) of the selected frame with the same edge
-- of the reference frame; the other axis stays where it is.
function EM:AlignTo(edge)
  if not selected or not ref or ref == selected then return end
  local mv, rv = movers[selected], movers[ref]
  local cx, cy = mv:GetCenter()
  local l, b, rw, rh = rv:GetRect()
  if not cx or not cy or not l then return end
  local w, h = mv:GetWidth(), mv:GetHeight()
  if edge == "TOP" then cy = b + rh - h / 2
  elseif edge == "MIDDLE" then cy = b + rh / 2
  elseif edge == "BOTTOM" then cy = b + h / 2
  elseif edge == "LEFT" then cx = l + w / 2
  elseif edge == "CENTRE" then cx = l + rw / 2
  elseif edge == "RIGHT" then cx = l + rw - w / 2
  end
  ns:M(selected.key).pos = { p = "CENTER", rp = "BOTTOMLEFT", x = cx, y = cy }
  ns:ApplyLayout(selected)
  AnchorMover(selected)
  EM:ShowCoords()
end

function EM:Refresh()
  if not panel then return end
  panel.profile:SetText("Profile: " .. ns.profileName .. "   (/fui profile <name>)")
  panel.snap:SetChecked(ns.profile.options.snap)
  local canAlign = selected and ref and ref ~= selected
  for _, b in ipairs(panel.alignButtons) do b:SetEnabled(canAlign and true or false) end
  panel.pick:SetEnabled(selected and true or false)
  panel.pick:SetText(picking and "Cancel" or "Align to...")
  if picking then
    panel.refText:SetText("|cff73d980Click the frame to align with|r")
  elseif canAlign then
    panel.refText:SetText("|cff73d980" .. ref.label .. "|r")
  else
    panel.refText:SetText("|cff959ca8no frame picked|r")
  end
  local sb = panel.sizeBox
  if selected and selected.ApplySize and selected.sizeRange then
    local s, r = ns:M(selected.key), selected.sizeRange
    sb.w.silent, sb.h.silent = true, true
    sb.w:SetMinMaxValues(r.w[1], r.w[2])
    sb.h:SetMinMaxValues(r.h[1], r.h[2])
    sb.w:SetValue(s.w or selected.defaults.w)
    sb.h:SetValue(s.h or selected.defaults.h)
    sb.w.silent, sb.h.silent = false, false
    sb:Show()
  else
    sb:Hide()
  end
  if not selected then
    panel.sel:SetText("Click a frame")
    panel.fade:SetText("Visible: —")
    return
  end
  local s = ns:M(selected.key)
  EM:ShowCoords()
  panel.scale.silent = true
  panel.scale:SetValue(s.scale or 1)
  panel.scale.silent = false
  panel.alpha.silent = true
  panel.alpha:SetValue(s.alpha or 1)
  panel.alpha.silent = false
  panel.fade:SetText("Visible: " .. (ns.Fader.labels[s.fade] or s.fade))
end

-- Selected frame's name plus its centre, so two frames can be matched exactly.
function EM:ShowCoords()
  if not panel or not selected then return end
  local mv = movers[selected]
  if not mv then return end
  local cx, cy = mv:GetCenter()
  if cx and cy then
    panel.sel:SetText(string.format("%s   |cff959ca8x %d  ·  y %d|r", selected.label, math.floor(cx + 0.5), math.floor(cy + 0.5)))
  else
    panel.sel:SetText(selected.label)
  end
end

function EM:Nudge(dx, dy)
  local cx, cy = movers[selected]:GetCenter()
  ns:M(selected.key).pos = { p = "CENTER", rp = "BOTTOMLEFT", x = cx + dx, y = cy + dy }
  ns:ApplyLayout(selected)
  AnchorMover(selected)
  EM:ShowCoords()
end

function EM:Reanchor()
  for m in pairs(movers) do AnchorMover(m) end
  EM:Refresh()
end

function EM:Open()
  if InCombatLockdown() then
    ns.Print("Edit mode only works out of combat.")
    return
  end
  if not panel then
    panel = BuildPanel()
    grid = BuildGrid()
  end
  ns.editing = true
  for _, m in ipairs(ns.moduleOrder) do
    if m.frame then
      if m.OnEditMode then m:OnEditMode(true) end
      local mv = movers[m] or CreateMover(m)
      AnchorMover(m)
      mv:Show()
    end
  end
  grid:Show()
  panel:Show()
  EM:Select(nil)
end

function EM:Close()
  if not ns.editing then return end
  ns.editing = false
  for m, mv in pairs(movers) do
    mv:Hide()
    if m.OnEditMode then m:OnEditMode(false) end
  end
  if selected then Paint(selected, BLUE) end
  if ref then Paint(ref, BLUE) end
  selected, ref, picking = nil, nil, false
  if grid then grid:Hide() end
  if panel then panel:Hide() end
end

function EM:Toggle()
  if ns.editing then EM:Close() else EM:Open() end
end

ns:On("PLAYER_REGEN_DISABLED", function()
  if ns.editing then
    EM:Close()
    ns.Print("Edit mode closed: you entered combat.")
  end
end)
