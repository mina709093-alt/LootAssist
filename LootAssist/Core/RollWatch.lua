-- 주사위 창이 뜨면 내 기준 판정을 채팅창에 미리 보여 준다 (주사위 창 강조는 6단계에서)
-- 입찰/차비 버튼은 누르지 않는다.
local _, NS = ...

local function report(rollID, tries)
  local ok, link = pcall(GetLootRollItemLink, rollID)
  if not ok or not link or NS.IsSecret(link) then return end
  local r = NS.EvaluateForMe(link, { ignoreEquipped = true })
  if r.verdict == "LOADING" and tries < 6 then
    C_Timer.After(0.5, function() NS.Safe(report, rollID, tries + 1) end)
    return
  end
  local reason = r.reasons[1] and (" - " .. r.reasons[1]) or ""
  NS.Print(("%s → %s%s"):format(link, r.colored, reason))
end

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:SetScript("OnEvent", function(_, event, rollID)
  if not NS.db or NS.db.rollChat == false then return end
  NS.Safe(report, rollID, 0)
end)
