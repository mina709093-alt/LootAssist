-- 아이템 툴팁에 내 기준 평가 한 줄 추가
local _, NS = ...

-- 툴팁은 자주 다시 그려지므로 같은 아이템은 잠깐 결과를 재사용
local cache = { link = nil, time = 0, result = nil }
NS.On("SPEC_CHANGED", function() cache.link = nil end)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function() cache.link = nil end)

-- 캐릭터 창의 장비 칸에 마우스를 올린 경우 (지금 끼고 있는 바로 그 아이템)
local function onCharacterSlot(tooltip)
  if not tooltip.GetOwner then return false end
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if not ok or not owner or not owner.GetName then return false end
  local ok2, name = pcall(owner.GetName, owner)
  if not ok2 or type(name) ~= "string" or NS.IsSecret(name) then return false end
  return name:find("^Character.+Slot$") ~= nil
end

local function itemName(it)
  if not it then return nil end
  return it.link or it.name
end

local function addLines(tooltip, link)
  if not NS.db or NS.db.tooltip == false then return end
  if onCharacterSlot(tooltip) then return end
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
  -- 반지/장신구/쌍수 무기: 어느 칸을 바꾸는지
  local s = r.swap
  if s and s.label then
    local old = itemName(s.old)
    tooltip:AddLine(("  교체 대상: %s%s"):format(s.label, old and (" " .. old) or " (빈 칸)"), 0.78, 0.78, 0.78, true)
    local keep = itemName(s.keep)
    if keep then tooltip:AddLine("  교체 후 함께 쓰는 것: " .. keep, 0.78, 0.78, 0.78, true) end
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
