Vamper = CreateFrame("FRAME")
Vamper.last_health = UnitHealth("player")
Vamper.running_total = 0
Vamper.running_total2 = 0
Vamper.vamp_stat_total = 0
Vamper.vamp_stats = {}
Vamper.tooltip = CreateFrame("GameTooltip", "VampToolTip", nil, "GameTooltipTemplate")
Vamper.tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

Vamper:RegisterEvent("UNIT_HEALTH")
Vamper:RegisterEvent("PLAYER_REGEN_DISABLED")
Vamper:RegisterEvent("PLAYER_REGEN_ENABLED")
Vamper:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Vamper:RegisterEvent("UNIT_INVENTORY_CHANGED")
Vamper:RegisterEvent("UNIT_COMBAT")
Vamper:SetScript("OnEvent", function ()
  Vamper[event](Vamper,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
end)

-- ve_dur = 0.2
-- local vamp_elapsed = 0
-- Vamper:SetScript("OnUpdate", function ()
--   vamp_elapsed = vamp_elapsed + arg1
--   if vamp_elapsed > ve_dur then
--     vamp_elapsed = 0
--     CombatLogAdd(GetTime() .." muffle wuffle1")
--     CombatLogAdd(GetTime() .." muffle wuffle2")
--     CombatLogAdd(GetTime() .." muffle wuffle3")
--     CombatLogAdd(GetTime() .." muffle wuffle4")
--     CombatLogAdd(GetTime() .." muffle wuffle5")
--   end
-- end)

function Vamper:CollectVampStat()
  for slot=1,19 do
    self.tooltip:SetInventoryItem("player", slot)
    for line=1, self.tooltip:NumLines() do
      local left = getglobal("VampToolTip" .. "TextLeft" .. line)
      local ltext = left:GetText()
      -- print(ltext)
      if ltext then
        local _,_,vamp = string.find(ltext, "^Equip: (%d+)%% of damage dealt is returned as healing.")
        if vamp then
          self.vamp_stat_total = self.vamp_stat_total + vamp
          table.insert(self.vamp_stats, vamp)
        end
      end
    end
  end
end

-- skip combat log parsing for heals by using UNIT_COMBAT
function Vamper:UNIT_COMBAT(target,action,atype,amount,unknown)
  if not self.in_combat then return end
  if target ~= "player" then return end

  if action == "HEAL" then
    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    local diff = hp + amount - maxhp

    self.running_total = self.running_total - (diff > 0 and (amount - diff) or amount)
  end
end

function Vamper:UNIT_INVENTORY_CHANGED(who)
  if who ~= "player" then return end
  self:CollectVampStat()
end

function Vamper:PLAYER_REGEN_DISABLED()
  self.in_combat = GetTime()
  self.running_total = 0
  -- self.running_total2 = 0
  self.last_health = UnitHealth("player")
  -- self:CollectVampStat()
end

function Vamper:PLAYER_ENTERING_WORLD()
  if UnitAffectingCombat("player") then self:PLAYER_REGEN_DISABLED() end
  self:CollectVampStat()
end

function Vamper:PLAYER_REGEN_ENABLED()
  if self.running_total > 0 then
    if MikCEH then MikCEH.ParseForIncomingSpellHeals(format("You gain %d health from Vampirism.", self.running_total)) end
    print(format("You gain %d health from vampirism/hp5. VampStats: %s. HPS: %.1f", self.running_total, table.concat(self.vamp_stats, ","), self.running_total / (GetTime() - self.in_combat)))
    -- print(format("You gain %d health from vampirism. HPS: %.1f", self.running_total2, self.running_total2 / (GetTime() - self.in_combat)))
  end
  self.running_total = 0
  -- self.running_total2 = 0
  self.in_combat = nil
end

function Vamper:UNIT_HEALTH(unit)
  if unit ~= "player" or not self.in_combat then return end
  local now_health = UnitHealth("player")
  local diff = now_health - self.last_health
  if diff > 0 then
    self.running_total = self.running_total + diff
    MikCEH.ParseForIncomingSpellHeals(format("You gain %d health from Vampirism.", diff))
  end
  self.last_health = now_health
end
