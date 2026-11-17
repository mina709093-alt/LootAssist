-- 주사위 창이 뜨면 최종 추천(개인 + 파티)을 채팅창에 미리 보여 준다 (주사위 창 강조는 6단계에서)
-- 입찰/차비 버튼은 누르지 않는다.
local _, NS = ...

NS.lastShare = nil

local function report(rollID, tries)
  local ok, link = pcall(GetLootRollItemLink, rollID)
  if not ok or not link or NS.IsSecret(link) then return end
  local r = NS.Advise(link)
  if r.loading and tries < 6 then
    C_Timer.After(0.5, function() NS.Safe(report, rollID, tries + 1) end)
    return
  end
  local reason = r.reasons[1] and (" - " .. r.reasons[1]) or ""
  NS.Print(("%s → %s%s"):format(link, r.colored, reason))
  for i = 2, math.min(#r.reasons, 3) do NS.Print("    " .. r.reasons[i]) end
  NS.lastShare = NS.ShareText(r, link)
end

-- 마지막 주사위 판정 문장을 채팅 입력창에 넣어 준다 (보내기는 직접)
function NS.OpenShareText()
  if not NS.lastShare then NS.Print("공유할 판정이 없습니다. 주사위가 뜬 뒤에 사용하세요."); return end
  local text = "/p " .. NS.lastShare
  local opened = false
  if ChatFrameUtil and ChatFrameUtil.OpenChat then opened = pcall(ChatFrameUtil.OpenChat, text) end
  if not opened and ChatFrame_OpenChat then opened = pcall(ChatFrame_OpenChat, text) end
  if not opened then NS.Print("채팅창에 직접 붙여 넣어 주세요: " .. NS.lastShare) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:SetScript("OnEvent", function(_, _, rollID)
  if not NS.db or NS.db.rollChat == false then return end
  NS.Safe(report, rollID, 0)
end)
