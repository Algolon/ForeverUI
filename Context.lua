local ADDON, ns = ...

-- Context modes: Questing, Dungeon, Raid, PvP or Resting, from where you
-- are. The info bar shows the mode; the quest tracker follows it:
--   * in combat it dims, so it doesn't pull your eye
--   * in a dungeon or raid it stays faint until you hover it
-- Only the tracker's alpha changes. Collapsing it from an addon could taint
-- the quest item buttons, so we don't.

local CX = {}
ns.Context = CX

local LABELS = { quest = "Questing", dungeon = "Dungeon", raid = "Raid", pvp = "PvP", rest = "Resting" }
local COMBAT_ALPHA, INSTANCE_ALPHA = 0.35, 0.15

CX.ORDER = { "quest", "dungeon", "raid", "pvp", "rest" }
CX.LABELS = LABELS

-- A mode you picked yourself (/fui mode, or right-click the info bar)
-- wins until you set it back to auto. Not saved: a reload means auto.
function CX.Set(mode)
  CX.override = LABELS[mode] and mode or nil
  CX.Update()
end

function CX.Cycle()
  local cur = CX.override
  if not cur then
    CX.Set(CX.ORDER[1])
    return
  end
  for i, m in ipairs(CX.ORDER) do
    if m == cur then
      CX.Set(CX.ORDER[i + 1]) -- after the last one: back to auto
      return
    end
  end
end

function CX.Detect()
  if CX.override then return CX.override end
  local inInstance, kind = IsInInstance()
  inInstance, kind = ns.Plain(inInstance), ns.Plain(kind)
  if inInstance then
    if kind == "raid" then return "raid" end
    if kind == "party" then return "dungeon" end
    if kind == "pvp" or kind == "arena" then return "pvp" end
  end
  if IsResting() then return "rest" end
  return "quest"
end

function ns.ContextLabel()
  if not ns.profile or not ns.profile.options.context then return nil end
  return LABELS[CX.mode or "quest"] .. (CX.override and "*" or "")
end

local function Tracker()
  return _G.ObjectiveTrackerFrame or _G.WatchFrame or _G.QuestWatchFrame
end

local function TargetAlpha(tracker)
  if not ns.profile.options.context then return 1 end
  if tracker:IsMouseOver() then return 1 end
  if CX.inCombat then return COMBAT_ALPHA end
  if CX.mode == "dungeon" or CX.mode == "raid" then return INSTANCE_ALPHA end
  return 1
end

function CX.Update()
  CX.mode = CX.Detect()
end

ns:On("PLAYER_LOGIN", function()
  CX.inCombat = ns.Plain(UnitAffectingCombat("player")) and true or false
  CX.Update()
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    ns.SafeRegister(ev, e)
  end
  ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" then CX.inCombat = true elseif e == "PLAYER_REGEN_ENABLED" then CX.inCombat = false end
    CX.Update()
  end)
  -- Ease the tracker's alpha towards where it should be (and back to full
  -- while you hover it).
  -- `managed`: we changed the alpha and haven't given it back yet; until
  -- then the tracker is left entirely alone.
  local managed = false
  ev:SetScript("OnUpdate", function(_, el)
    local t = Tracker()
    if not t or not t:IsShown() then return end
    local want = TargetAlpha(t)
    if want == 1 and not managed then return end
    managed = true
    local cur = t:GetAlpha()
    if math.abs(cur - want) > 0.01 then
      t:SetAlpha(cur + (want - cur) * math.min(1, el * 8))
    else
      t:SetAlpha(want)
      if want == 1 then managed = false end
    end
  end)
end)
