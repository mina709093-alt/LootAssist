-- 아이템 정보 읽기: 링크 -> 정규화된 아이템 정보
-- 아이템 하위 분류 번호는 LootProbe 실측과 일치 확인 (한손 도검 7, 한손 둔기 4, 총 3, 사슬 3, 천 1, 방패 6 등)
local _, NS = ...

local function isSecret(v)
  if issecretvalue then
    local ok, r = pcall(issecretvalue, v)
    return ok and r
  end
  return false
end
NS.IsSecret = isSecret

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats

-- 고유 / 고유 장착 문장 (게임 전역 문자열이 있으면 그것과 비교)
local function isUniqueLine(t)
  local u1, u2 = rawget(_G, "ITEM_UNIQUE"), rawget(_G, "ITEM_UNIQUE_EQUIPPABLE")
  if (type(u1) == "string" and t == u1) or (type(u2) == "string" and t == u2) then return true end
  return t == "고유" or t == "고유 장착" or t:find("^고유 %(") ~= nil or t:find("^고유 장착:") ~= nil
end

-- 툴팁 문장에서 숫자로 안 나오는 효과 읽기
-- 적중/치명타는 "율이 1% 만큼 증가"(%) 또는 "치명타 +14"(레이팅) 두 형식으로 나온다 (사용자 확인 2026-11-21)
local function parseTooltip(link, item)
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
  for _, line in ipairs(data.lines) do
    local t = line.leftText
    if type(t) == "string" and not isSecret(t) then
      if isUniqueLine(t) then item.unique = true end
      local isEffect = t:find("효과:") ~= nil
      if isEffect then
        local handled = false
        if t:find("5초마다") or t:find("최대") or t:find("숙련도가") or t:find("배웁니다") then
          handled = true -- 능력치 키로 이미 들어오는 효과, 또는 제작법
        end
        -- 상시 효과(착용 효과)만 능력치로 본다. 사용 효과의 일시적인 치명타 증가는 넣지 않는다.
        local passive = t:find("^착용 효과:") ~= nil
        local crit = passive and t:match("치명타[^%d]*(%d+%.?%d*)%%")
        local critR = passive and not crit and t:match("치명타[^%d]*%+(%d+)")
        local hit = passive and not crit and not critR and t:match("적중[^%d]*(%d+%.?%d*)%%")
        local hitR = passive and not crit and not critR and not hit and t:match("적중[^%d]*%+(%d+)")
        if crit then
          item.tipPct.CRIT = (item.tipPct.CRIT or 0) + tonumber(crit); handled = true
        elseif critR then
          item.tipRating.CRIT = (item.tipRating.CRIT or 0) + tonumber(critR); handled = true
        elseif hit then
          item.tipPct.HIT = (item.tipPct.HIT or 0) + tonumber(hit); handled = true
        elseif hitR then
          item.tipRating.HIT = (item.tipRating.HIT or 0) + tonumber(hitR); handled = true
        end
        if not handled and t:find("^착용 효과:") and not t:find("에 대한") then
          local ap = t:match("전투력이 (%d+)만큼 증가")
          if ap then
            item.stats.AP = (item.stats.AP or 0) + tonumber(ap)
            item.parsed = true; handled = true
          end
        end
        if not handled and not t:find("^%(%d%) 세트") and not t:find("세트 효과") then
          item.special = true -- 점수에 넣지 못한 특수 효과
        end
      end
    end
  end
end

-- 반환: item 테이블, 또는 nil + "loading"/"invalid"
function NS.ReadItem(link)
  if type(link) ~= "string" or isSecret(link) then return nil, "invalid" end
  local itemID, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(link)
  if not itemID then return nil, "invalid" end

  local name, _, quality, itemLevel, reqLevel, _, _, _, _, _, _, _, _, bindType = GetItemInfo(link)
  if not name then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return nil, "loading"
  end

  local item = {
    link = link, itemID = itemID, name = name, quality = quality or 0,
    itemLevel = itemLevel or 0, reqLevel = reqLevel or 0,
    equipLoc = equipLoc or "", classID = classID, subclassID = subclassID,
    bindType = bindType, stats = {}, unknown = {}, dps = 0,
    ratingKey = {}, tipPct = {}, tipRating = {},
  }

  local ok, raw = pcall(GetItemStats, link)
  if ok and type(raw) == "table" then
    for key, value in pairs(raw) do
      if type(key) == "string" and type(value) == "number" then
        local stat = NS.StatKeys[key] or NS.StatKeysUnverified[key]
        local rating = NS.RatingKeys[key] or NS.RatingKeysUnverified[key]
        if rating then
          item.ratingKey[rating] = (item.ratingKey[rating] or 0) + value
          if NS.RatingKeysUnverified[key] and NS.db then
            NS.db.seenStats = NS.db.seenStats or {}
            NS.db.seenStats[key] = { label = tostring(rawget(_G, key)), item = itemID, value = value }
          end
        elseif stat == "DPS" then
          item.dps = value
        elseif stat then
          item.stats[stat] = (item.stats[stat] or 0) + value
          if NS.StatKeysUnverified[key] and NS.db then
            NS.db.seenStats = NS.db.seenStats or {}
            NS.db.seenStats[key] = { label = tostring(rawget(_G, key)), item = itemID }
          end
        elseif not NS.StatKeysIgnored[key] then
          local label = rawget(_G, key)
          item.unknown[#item.unknown + 1] = type(label) == "string" and label or key
          if NS.db then
            NS.db.unknownStats = NS.db.unknownStats or {}
            NS.db.unknownStats[key] = { label = tostring(label), item = itemID }
          end
        end
      end
    end
  end

  parseTooltip(link, item)

  -- 적중/치명타를 % 하나로 합친다. 툴팁 문장을 읽었으면 그것을 쓰고(같은 효과를 두 번 세지 않기 위해),
  -- 못 읽었으면 능력치 키(레이팅)를 환산표로 바꿔 쓴다.
  for _, k in ipairs({ "CRIT", "HIT" }) do
    local per = NS.RatingPerPct[k]
    local pct
    if item.tipPct[k] or item.tipRating[k] then
      pct = (item.tipPct[k] or 0) + (item.tipRating[k] or 0) / per
    elseif item.ratingKey[k] then
      pct = item.ratingKey[k] / per
    end
    if pct and pct > 0 then
      local s = k .. "PCT"
      item.stats[s] = (item.stats[s] or 0) + pct
      item.parsed = true
    end
  end

  item.isWeapon = (classID == 2)
  item.isArmor = (classID == 4)
  item.isRanged = (equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN")
  item.isBoE = (bindType == 2)
  return item
end
