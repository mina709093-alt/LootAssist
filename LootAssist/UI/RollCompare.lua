-- 주사위 아이템 비교: 주사위 아이템에 마우스를 올리면(게임 주사위 창, DaylightUI 카드 모두) 그 칸에 지금 끼고 있는
-- 아이템 툴팁을 옆에 같이 보여 준다. 추천과 별개로 직접 눈으로 비교할 수 있게.
-- 게임의 Shift 비교나 "항상 비교"가 켜져 있으면 게임 비교가 나오므로 이것은 숨긴다(두 번 겹치지 않게).
-- 설정: LootAssistDB.rollCompare (없으면 켬, false 면 끔)
local _, NS = ...

local MAX = 2
local tips = {}
local hooked = false

local function enabled() return NS.db and NS.db.rollCompare ~= false end

-- 게임 자체 비교가 나오는 중인지 (Shift 또는 "항상 비교" 설정)
local function gameCompares(tip)
  local TU = rawget(_G, "TooltipUtil")
  if type(TU) == "table" and type(TU.ShouldDoItemComparison) == "function" then
    local ok, want = pcall(TU.ShouldDoItemComparison, tip)
    if ok then return want == true end
  end
  local imc = rawget(_G, "IsModifiedClick")
  if type(imc) == "function" then
    local ok, want = pcall(imc, "COMPAREITEMS")
    return ok and want == true
  end
  return false
end

local function getTip(i)
  if tips[i] then return tips[i] end
  local tt = CreateFrame("GameTooltip", "LootAssistCompareTooltip" .. i, UIParent, "GameTooltipTemplate")
  tt.laHeader = NS.MakeText(tt, 11, NS.Style.accent)
  tt.laHeader:SetPoint("BOTTOMLEFT", tt, "TOPLEFT", 2, 2)
  tt:Hide()
  tips[i] = tt
  return tt
end

local function hideAll()
  for i = 1, MAX do
    local tt = tips[i]
    if tt and tt:IsShown() then tt:Hide() end
    if tt then tt.laSlot = nil end
  end
end
NS.HideRollCompare = hideAll

local function equipLocOf(link)
  if not link or NS.IsSecret(link) then return nil end
  local ok, item = pcall(NS.ReadItem, link)
  return ok and type(item) == "table" and item.equipLoc or nil
end

-- 비교할 칸 목록 (최대 2개)
function NS.CompareSlots(loc)
  local base = loc and NS.SLOTS[loc]
  if not base then return {} end
  local link = function(s) return GetInventoryItemLink("player", s) end
  local out = {}
  if loc == "INVTYPE_WEAPON" then
    -- 한손 무기: 주무기, 그리고 보조 칸에 무기를 들고 있을 때만 보조 칸
    out[1] = 16
    local ol = equipLocOf(link(17))
    if ol == "INVTYPE_WEAPON" or ol == "INVTYPE_WEAPONOFFHAND" then out[2] = 17 end
  elseif loc == "INVTYPE_2HWEAPON" then
    -- 양손 무기: 주무기, 보조 칸에 무언가 있으면 그것도 (같이 벗게 됨)
    out[1] = 16
    if link(17) then out[2] = 17 end
  else
    for i = 1, math.min(#base, MAX) do out[i] = base[i] end
  end
  return out
end

local function place(tt, anchor, leftSide)
  tt:ClearAllPoints()
  if leftSide then
    tt:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
  else
    tt:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
  end
end

local function show(tip, rollID)
  hideAll()
  if not enabled() or rollID == nil or NS.IsSecret(rollID) then return end
  if gameCompares(tip) then return end
  local ok, link = pcall(GetLootRollItemLink, rollID)
  if not ok then return end
  local loc = equipLocOf(link)
  local slots = NS.CompareSlots(loc)
  if #slots == 0 then return end
  -- 화면 오른쪽에 가까우면 왼쪽에 붙인다
  local right = tip.GetRight and tip:GetRight()
  local screen = UIParent and UIParent.GetWidth and UIParent:GetWidth()
  local leftSide = type(right) == "number" and type(screen) == "number" and screen > 0
    and right + 300 * #slots > screen
  local anchor = tip
  for i, slot in ipairs(slots) do
    local tt = getTip(i)
    tt:SetOwner(tip, "ANCHOR_NONE")
    local label = NS.SLOT_LABEL[slot] or tostring(slot)
    if GetInventoryItemLink("player", slot) then
      tt:SetInventoryItem("player", slot)
      tt.laHeader:SetText("착용 중: " .. label)
    else
      tt:SetText("비어 있음", 0.6, 0.6, 0.6)
      tt.laHeader:SetText("착용 중: " .. label)
    end
    tt.laSlot = slot
    place(tt, anchor, leftSide)
    tt:Show()
    anchor = tt
  end
end

local function install()
  if hooked or type(GameTooltip) ~= "table" or type(hooksecurefunc) ~= "function" then return end
  if type(GameTooltip.SetLootRollItem) ~= "function" then return end
  hooked = true
  hooksecurefunc(GameTooltip, "SetLootRollItem", function(tip, rollID) NS.Safe(show, tip, rollID) end)
  -- 툴팁이 다른 내용으로 바뀌거나 닫히면 같이 숨긴다 (0.2초마다 다시 채울 때도 지웠다가 바로 다시 그림)
  if GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipCleared", function() NS.Safe(hideAll) end)
    GameTooltip:HookScript("OnHide", function() NS.Safe(hideAll) end)
  end
end

function NS.ToggleRollCompare()
  NS.db.rollCompare = (NS.db.rollCompare == false)
  if not NS.db.rollCompare then hideAll() end
  return NS.db.rollCompare
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() NS.Safe(install) end)
