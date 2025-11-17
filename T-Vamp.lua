T_Vamp = CreateFrame("FRAME")
T_Vamp.last_health = UnitHealth("player")
T_Vamp.running_total = 0
T_Vamp.running_total2 = 0
T_Vamp.vamp_stat_total = 0
T_Vamp.vamp_stats = {}
T_Vamp.tooltip = CreateFrame("GameTooltip", "TVampToolTip", nil, "GameTooltipTemplate")
T_Vamp.tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
T_Vamp.firstScanDone = false -- Флаг первого сканирования

-- Регистрируем команду
SLASH_TVAMP1 = "/tvamp"
SlashCmdList["TVAMP"] = function(msg)
    T_Vamp:ShowVampStats()
end

T_Vamp:RegisterEvent("UNIT_HEALTH")
T_Vamp:RegisterEvent("PLAYER_REGEN_DISABLED")
T_Vamp:RegisterEvent("PLAYER_REGEN_ENABLED")
T_Vamp:RegisterEvent("PLAYER_ENTERING_WORLD")
-- T_Vamp:RegisterEvent("UNIT_INVENTORY_CHANGED") -- Оставляем закомментированным
T_Vamp:RegisterEvent("UNIT_COMBAT")
T_Vamp:SetScript("OnEvent", function ()
  T_Vamp[event](T_Vamp,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
end)

function T_Vamp:ShowVampStats()
    -- ВСЕГДА делаем сканирование при использовании команды
    self:CollectVampStat()
    self.firstScanDone = true
    
    local vamp_stats_string = ""
    if table.getn(self.vamp_stats) > 0 then
        vamp_stats_string = table.concat(self.vamp_stats, ",") .. " (всего: " .. self.vamp_stat_total .. "%)"
    else
        vamp_stats_string = "нет"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00T-Vamp:|r Статы вампиризма: " .. vamp_stats_string)
end

function T_Vamp:CollectVampStat()
  -- Полностью очищаем предыдущие значения
  self.vamp_stat_total = 0
  self.vamp_stats = {}
  
  for slot=1,19 do
    -- ОЧИЩАЕМ ТУЛТИП перед каждым предметом
    self.tooltip:ClearLines()
    self.tooltip:SetInventoryItem("player", slot)
    
    for line=1, self.tooltip:NumLines() do
      local left = getglobal("TVampToolTip" .. "TextLeft" .. line)
      local ltext = left:GetText()
      if ltext then
        -- Только две фразы для поиска
        local vamp = nil
        
        -- Стандартный вариант
        local _,_,v1 = string.find(ltext, "^Equip: (%d+)%% of damage dealt is returned as healing.")
        -- Vampirism вариант
        local _,_,v2 = string.find(ltext, "(%d+)%% Vampirism")
        
        vamp = v1 or v2
        
        if vamp then
          vamp = tonumber(vamp)
          self.vamp_stat_total = self.vamp_stat_total + vamp
          table.insert(self.vamp_stats, vamp)
        end
      end
    end
  end
end

-- Пропускать анализ лога боя для исцелений, используя UNIT_COMBAT
function T_Vamp:UNIT_COMBAT(target,action,atype,amount,unknown)
  if not self.in_combat then return end
  if target ~= "player" then return end

  if action == "HEAL" then
    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    local diff = hp + amount - maxhp

    self.running_total = self.running_total - (diff > 0 and (amount - diff) or amount)
  end
end

function T_Vamp:PLAYER_REGEN_DISABLED()
  self.in_combat = GetTime()
  self.running_total = 0
  self.last_health = UnitHealth("player")
  -- При начале боя делаем сканирование статов
  self:CollectVampStat()
  self.firstScanDone = true
end

function T_Vamp:PLAYER_ENTERING_WORLD()
  if UnitAffectingCombat("player") then 
      self:PLAYER_REGEN_DISABLED() 
  else
      -- При входе в мир сбрасываем флаг, чтобы первая команда /tvamp сработала
      self.firstScanDone = false
  end
end

-- Сообщение, отправляемое в аддон MikScrollingBattleText (MSBT)
function T_Vamp:PLAYER_REGEN_ENABLED()
  if self.running_total > 0 then
    if MikCEH then MikCEH.ParseForIncomingSpellHeals(format("You gain %d health from Vampirism.", self.running_total)) end
    
    -- Создаем строку со статами вампиризма
    local vamp_stats_string = ""
    if table.getn(self.vamp_stats) > 0 then
      vamp_stats_string = table.concat(self.vamp_stats, ",") .. " (всего: " .. self.vamp_stat_total .. "%)"
    else
      vamp_stats_string = "нет"
    end
    
    -- Вывод с префиксом T-Vamp
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00T-Vamp:|r " .. format("Восстановлено %d здоровья за бой. Статы вампиризма: %s. ИВС: %.1f", 
      self.running_total, vamp_stats_string, self.running_total / (GetTime() - self.in_combat)))
  end
  self.running_total = 0
  self.in_combat = nil
end

function T_Vamp:UNIT_HEALTH(unit)
  if unit ~= "player" or not self.in_combat then return end
  local now_health = UnitHealth("player")
  local diff = now_health - self.last_health
  if diff > 0 then
    self.running_total = self.running_total + diff
    -- Сообщение, отправляемое в аддон MikScrollingBattleText (MSBT)
    if MikCEH then
      MikCEH.ParseForIncomingSpellHeals(format("You gain %d health from Vampirism.", diff))
    end
  end
  self.last_health = now_health
end
