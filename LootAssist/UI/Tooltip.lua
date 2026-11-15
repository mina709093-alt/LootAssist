-- 아이템 툴팁에 내 기준 평가 한 줄 추가
local _, NS = ...

-- 툴팁은 자주 다시 그려지므로 같은 아이템은 잠깐 결과를 재사용
local cache = { link = nil, time = 0, result = nil }
NS.On("SPEC_CHANGED", function() cache.link = nil end)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function() cache.link = nil end)

local function addLines(tooltip, link)
  if not NS.db or NS.db.tooltip == false then return end
  local now = GetTime()
  local r
  if cache.link == link and now - cache.time < 1.5 and cache.result then
    r = cache.result
  else
    r = NS.EvaluateForMe(link)
    if r.verdict ~= "LOADING" then cache.link, cache.time, cache.result = link, now, r end
  end
  if not r or r.verdict == "NOT_GEAR" or r.verdict == "EQUIPPED" then return end
  tooltip:AddLine(" ")
  tooltip:AddLine("|cff66ccff전리품 도우미:|r " .. r.colored)
  for i = 1, math.min(#r.reasons, 3) do
    tooltip:AddLine("  " .. r.reasons[i], 0.78, 0.78, 0.78, true)
  end
end

local function onItemTooltip(tooltip)
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  if not tooltip.GetItem then return end
  local ok, _, link = pcall(tooltip.GetItem, tooltip)
  if not ok or not link or NS.IsSecret(link) then return end
  NS.Safe(addLines, tooltip, link)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
  NS.tooltipHooked = true
end
