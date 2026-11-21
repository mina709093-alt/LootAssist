-- A. 개인 아이템 평가 엔진: 내 직업 / 주·부 특성 / 현재 장비 기준
local _, NS = ...

NS.VERDICT = {
  BID_STRONG = { label = "1순위 · 적극 입찰", color = "33ff66" },
  BID        = { label = "2순위 · 입찰 추천", color = "99dd55" },
  BID_WEAK   = { label = "2순위(약함) · 입찰 고려", color = "ffd24d" },
  GREED      = { label = "차비 추천", color = "a8a8a8" },
  EQUIPPED   = { label = "착용 중", color = "a8a8a8" },
  NOT_GEAR   = { label = "장비 아님", color = "a8a8a8" },
  NEED_SPEC  = { label = "주 특성 설정 필요", color = "ff9933" },
  LOADING    = { label = "분석 중", color = "a8a8a8" },
  NO_DATA    = { label = "정보 부족", color = "ff9933" },
}

-- 기준값 (테스트하며 조정)
NS.EVAL = {
  STRONG_FIT = 0.6,   -- 이 특성에 잘 맞는 아이템
  FIT = 0.35,         -- 어느 정도 맞는 아이템
  STRONG_GAIN = 0.10, -- 10% 이상 좋아지면 큰 업그레이드
  SECONDARY_WEIGHT = 0.6,
}

-- 특성 하나 기준 아이템 점수와 능력치별 기여
function NS.SpecScore(item, classFile, specKey)
  local W = NS.GetWeights(classFile, specKey)
  if not W then return nil end
  local total, parts = 0, {}
  for stat, value in pairs(item.stats) do
    local w = W[stat]
    if w and w ~= 0 and type(w) == "number" then
      local v = w * value
      total = total + v
      parts[#parts + 1] = { stat = stat, value = v }
    end
  end
  local statsOnly = total
  if item.dps and item.dps > 0 then
    local w
    if item.subclassID == 19 then w = W.DPS_WAND
    elseif item.isRanged then w = W.DPS_RANGED
    elseif item.isWeapon then w = W.DPS_MELEE end
    if w and w > 0 then
      total = total + w * item.dps
      parts[#parts + 1] = { stat = "DPS", value = w * item.dps }
    end
  end
  table.sort(parts, function(a, b) return a.value > b.value end)
  return total, parts, statsOnly
end

-- 이 특성이 이 무기의 공격력(DPS)을 쓰는가
local function usesWeaponDPS(item, W)
  if not (item.dps and item.dps > 0 and W) then return false end
  if item.subclassID == 19 then return (W.DPS_WAND or 0) > 0 end
  if item.isRanged then return (W.DPS_RANGED or 0) >= 1 end
  return (W.DPS_MELEE or 0) >= 1
end

-- 이 아이템을 입을 수 있는 모든 특성 중 능력치 점수가 가장 높은 값 (적합도 기준)
-- 무기 공격력(DPS)은 업그레이드 비교에만 쓰고 적합도에는 넣지 않는다 (DPS 때문에 캐스터 지팡이가 근접용으로 보이는 것 방지)
function NS.MaxSpecScore(item)
  local best = 0
  for classFile, c in pairs(NS.Classes) do
    local el = NS.CheckEligibility(item, classFile, 60)
    if el.ok then
      for _, s in ipairs(c.specs) do
        local _, _, statsOnly = NS.SpecScore(item, classFile, s.key)
        if statsOnly and statsOnly > best then best = statsOnly end
      end
    end
  end
  return best
end

-- 적합도 0~1
function NS.SpecFit(item, classFile, specKey, maxScore)
  local _, _, statsOnly = NS.SpecScore(item, classFile, specKey)
  if (maxScore or 0) > 0 then return (statsOnly or 0) / maxScore end
  -- 능력치가 없는 무기: 그 무기 공격력을 쓰는 특성이면 맞는 것으로 본다
  return usesWeaponDPS(item, NS.GetWeights(classFile, specKey)) and 1 or 0
end

local function readEquipped(slot, getLink)
  local link
  if getLink then link = getLink(slot) else link = GetInventoryItemLink("player", slot) end
  if not link then return false end
  local it, state = NS.ReadItem(link)
  if not it then return nil, state end
  return it
end

-- 칸 이름 (교체 대상 표시용)
NS.SLOT_LABEL = {
  [1] = "머리", [2] = "목", [3] = "어깨", [5] = "가슴", [6] = "허리", [7] = "다리", [8] = "발",
  [9] = "손목", [10] = "손", [11] = "반지 1", [12] = "반지 2", [13] = "장신구 1", [14] = "장신구 2",
  [15] = "등", [16] = "주무기", [17] = "보조장비", [18] = "원거리",
}

-- 두 칸 부위(반지, 장신구, 쌍수 한손 무기): 칸마다 "이 칸을 새 아이템으로 바꾸는" 시나리오를 만든다.
-- 고유 아이템은 다른 칸에 같은 아이템이 있으면 그 칸으로는 바꿀 수 없다(같은 고유 아이템 두 개 착용 불가).
-- equipped[i] = 칸 i의 아이템(false = 빈 칸)
local function pairOptions(item, slots, equipped, score)
  local opts, total, same = {}, 0, false
  for i = 1, #slots do
    total = total + score(equipped[i] or nil)
    if equipped[i] and item.itemID and equipped[i].itemID == item.itemID then same = true end
  end
  for i, slot in ipairs(slots) do
    local blocked = false
    if item.unique and item.itemID then
      for j = 1, #slots do
        if j ~= i and equipped[j] and equipped[j].itemID == item.itemID then blocked = true end
      end
    end
    opts[#opts + 1] = { slot = slot, cur = score(equipped[i] or nil), filled = (equipped[i] ~= false),
                        old = equipped[i] or nil, blocked = blocked }
  end
  -- 바꿀 수 있는 칸 중 점수가 가장 낮은 칸 = 바꿨을 때 조합 점수가 가장 높아지는 칸
  local best
  for _, o in ipairs(opts) do
    if not o.blocked and (not best or o.cur < best.cur) then best = o end
  end
  return best, { pair = true, total = total, options = opts, sameEquipped = same,
                 slot = best and best.slot, old = best and best.old }
end

-- 같은 칸 현재 장비 점수. nil = 아직 못 읽음, 두 번째 값은 상황 설명, 세 번째 값은 칸에 장비가 있는지,
-- 네 번째 값은 교체 계획 { slot, old, total, pair, options, sameEquipped } (알 수 있을 때만)
-- 두 번째 값 "UNIQUE" = 고유 아이템이라 바꿀 수 있는 칸이 없음
-- getLink(slot) 를 주면 그 장비(살펴보기로 읽은 파티원 장비 등)로 계산한다
function NS.CurrentSlotScore(item, classFile, specKey, getLink)
  local W = NS.GetWeights(classFile, specKey) or {}
  local readEquipped = function(slot) return readEquipped(slot, getLink) end
  local loc = item.equipLoc
  local function score(it) if not it then return 0 end return (NS.SpecScore(it, classFile, specKey)) or 0 end

  local mh, mhState = readEquipped(16)
  if mh == nil and (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND"
      or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_WEAPONMAINHAND") then
    return nil, mhState
  end
  local mhIs2H = mh and mh.equipLoc == "INVTYPE_2HWEAPON"

  if loc == "INVTYPE_2HWEAPON" then
    local oh = readEquipped(17)
    if oh == nil then return nil, "loading" end
    local total = score(mh) + score(oh or nil)
    return total, nil, (mh ~= false or oh ~= false), { slot = 16, old = mh or nil, total = total, both = (oh or nil) }
  elseif loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
    if mhIs2H then return nil, "TWOHAND" end
    local oh = readEquipped(17)
    if oh == nil then return nil, "loading" end
    local s = score(oh or nil)
    return s, nil, (oh ~= false), { slot = 17, old = oh or nil, total = s }
  elseif loc == "INVTYPE_WEAPON" then
    if mhIs2H then
      local s = score(mh)
      return s, nil, true, { slot = 16, old = mh, total = s, replaces2H = true }
    end
    local a = score(mh or nil)
    if W.dualWield then
      local oh = readEquipped(17)
      if oh == nil then return nil, "loading" end
      if oh and oh.isWeapon then
        local best, plan = pairOptions(item, { 16, 17 }, { mh, oh }, score)
        if not best then return nil, "UNIQUE" end
        return best.cur, nil, true, plan
      end
      if not oh then return 0, nil, false, { slot = 17, total = a } end
    end
    return a, nil, (mh ~= false), { slot = 16, old = mh or nil, total = a }
  end

  local slots = NS.SLOTS[loc]
  if not slots then return nil, "invalid" end
  local equipped = {}
  for i, slot in ipairs(slots) do
    local it, state = readEquipped(slot)
    if it == nil then return nil, state end
    equipped[i] = it
  end
  if #slots == 1 then
    local s = score(equipped[1] or nil)
    return s, nil, (equipped[1] ~= false), { slot = slots[1], old = equipped[1] or nil, total = s }
  end
  local best, plan = pairOptions(item, slots, equipped, score)
  if not best then return nil, "UNIQUE" end
  return best.cur, nil, best.filled, plan
end

local function topStats(parts, n)
  local names = {}
  for i = 1, math.min(n, #parts) do
    if parts[i].value > 0 then names[#names + 1] = NS.StatLabel[parts[i].stat] or parts[i].stat end
  end
  return table.concat(names, ", ")
end

local function gainOf(new, cur)
  if cur == nil then return nil end
  if cur <= 0 then return (new > 0) and 1 or 0 end
  return (new - cur) / cur
end

local function finish(res, key)
  res.verdict = key
  local v = NS.VERDICT[key]
  res.label = v.label
  res.colored = "|cff" .. v.color .. v.label .. "|r"
  return res
end

local function isEquipped(link)
  local fn = C_Item and C_Item.IsEquippedItem or IsEquippedItem
  if not fn then return false end
  local ok, r = pcall(fn, link)
  return ok and r
end

-- 결과: { verdict, label, colored, reasons = {...}, item, fitP, gainP, fitS, gainS }
function NS.EvaluateForMe(link, opts)
  local res = { reasons = {} }
  local item, state = NS.ReadItem(link)
  if not item then
    if state == "loading" then res.reasons[1] = "아이템 정보를 불러오는 중입니다"; return finish(res, "LOADING") end
    res.reasons[1] = "아이템을 읽을 수 없습니다"; return finish(res, "NO_DATA")
  end
  res.item = item
  local me = NS.GetPlayerInfo()

  local el = NS.CheckEligibility(item, me.class, me.level)
  res.eligibility = el
  if el.notGear then res.reasons[1] = el.reason; return finish(res, "NOT_GEAR") end
  if not el.ok then res.reasons[1] = el.reason; return finish(res, "GREED") end
  local pairLoc = (item.equipLoc == "INVTYPE_FINGER" or item.equipLoc == "INVTYPE_TRINKET")
  if not (opts and opts.ignoreEquipped) and isEquipped(link) then
    -- 반지/장신구는 고유가 아니면 같은 것을 하나 더 낄 수 있으므로 계속 평가한다
    if not pairLoc or item.unique then
      res.reasons[1] = "지금 착용하고 있는 아이템입니다"; return finish(res, "EQUIPPED")
    end
    res.equippedCopy = true
  end

  local primary, secondary = NS.GetActiveSpecs()
  local pSpec = NS.GetSpec(me.class, primary)
  if not pSpec then res.reasons[1] = "창에서 주 특성을 먼저 선택해 주세요"; return finish(res, "NEED_SPEC") end
  local sSpec = NS.GetSpec(me.class, secondary)

  local maxScore = NS.MaxSpecScore(item)
  local function evalSpec(spec)
    local new, parts = NS.SpecScore(item, me.class, spec.key)
    new = new or 0
    local cur, why, filled, plan = NS.CurrentSlotScore(item, me.class, spec.key)
    local slotGain = gainOf(new, cur)
    local gain = slotGain
    -- 두 칸 부위는 "두 칸 합(조합)" 기준으로 얼마나 좋아지는지 본다 (한 칸만 기준으로 하면 상승률이 부풀려짐)
    if plan and plan.pair and cur ~= nil and (plan.total or 0) > 0 then
      gain = (new - cur) / plan.total
    end
    return {
      new = new, parts = parts or {}, cur = cur, why = why, filled = filled, plan = plan,
      fit = NS.SpecFit(item, me.class, spec.key, maxScore),
      gain = gain, slotGain = slotGain,
    }
  end
  local P = evalSpec(pSpec)
  local S = sSpec and evalSpec(sSpec) or nil
  res.fitP, res.gainP, res.slotGainP = P.fit, P.gain, P.slotGain
  if S then res.fitS, res.gainS, res.slotGainS = S.fit, S.gain, S.slotGain end

  if item.reqLevel > me.level then
    res.reasons[#res.reasons + 1] = ("%d레벨부터 착용할 수 있습니다"):format(item.reqLevel)
  end

  local E = NS.EVAL
  local key
  local uniqueWorn = item.unique and P.plan and P.plan.sameEquipped
  if uniqueWorn or P.why == "UNIQUE" then
    key = "GREED"
    res.reasons[#res.reasons + 1] = "고유 아이템이라 하나만 착용할 수 있는데, 같은 아이템을 이미 착용하고 있습니다"
  elseif P.why == "TWOHAND" then
    if P.fit >= E.FIT then
      key = "BID_WEAK"
      res.reasons[#res.reasons + 1] = ("%s(%s)에 맞는 보조장비지만, 지금은 양손 무기를 써서 한손 무기와 함께 써야 합니다"):format("주 특성", pSpec.name)
    else
      key = "GREED"
      res.reasons[#res.reasons + 1] = "양손 무기를 쓰는 중이라 보조장비는 바로 쓸 수 없습니다"
    end
  elseif P.gain == nil then
    key = "BID_WEAK"
    res.reasons[#res.reasons + 1] = "현재 장비 정보를 읽는 중이라 비교하지 못했습니다"
  elseif P.fit >= E.STRONG_FIT and P.gain >= E.STRONG_GAIN then
    key = "BID_STRONG"
  elseif P.fit >= E.FIT and P.gain > 0 then
    key = "BID"
  elseif S and S.gain and S.fit >= E.STRONG_FIT and S.gain >= E.STRONG_GAIN then
    key = "BID"
    res.usedSecondary = true
  elseif P.gain > 0 or (S and S.gain and S.gain > 0) then
    key = "BID_WEAK"
    if P.gain <= 0 then res.usedSecondary = true end
  else
    key = "GREED"
  end

  -- 사유 문장
  local main = res.usedSecondary and S or P
  local mainSpec = res.usedSecondary and sSpec or pSpec
  local which = res.usedSecondary and "부 특성" or "주 특성"
  local stats = topStats(main.parts, 2)
  if key == "GREED" and P.gain ~= nil and P.why ~= "TWOHAND" and not uniqueWorn then
    if maxScore <= 0 then
      res.reasons[#res.reasons + 1] = "점수에 넣을 능력치가 없습니다 (저항력 등은 제외)"
    elseif P.fit < E.FIT and (not S or S.fit < E.FIT) then
      res.reasons[#res.reasons + 1] = ("%s(%s)에 맞는 능력치가 적습니다"):format(which, pSpec.name)
    else
      res.reasons[#res.reasons + 1] = "현재 장비보다 좋지 않습니다"
    end
  elseif key ~= "GREED" and main.gain ~= nil then
    local pct = math.floor(main.gain * 100 + 0.5)
    local gainText
    local isPair = main.plan and main.plan.pair
    if (main.cur or 0) > 0 and isPair then gainText = ("두 칸 조합 기준 약 %d%% 좋아집니다"):format(pct)
    elseif (main.cur or 0) > 0 then gainText = ("현재 장비보다 약 %d%% 좋습니다"):format(pct)
    elseif main.filled then gainText = "지금 장비는 이 특성에 쓸모 있는 능력치가 없습니다"
    else gainText = "비어 있는 칸을 채웁니다" end
    if stats ~= "" then
      res.reasons[#res.reasons + 1] = ("%s(%s) 기준: %s, %s"):format(which, mainSpec.name, stats, gainText)
    else
      res.reasons[#res.reasons + 1] = ("%s(%s) 기준: %s"):format(which, mainSpec.name, gainText)
    end
    if main.fit < E.FIT then
      res.reasons[#res.reasons + 1] = "특성에 맞는 능력치는 적지만 지금 장비보다는 낫습니다"
    end
  end

  -- 두 칸 부위: 어느 칸을 바꾸는지 (툴팁 표시용)
  local plan = main.plan
  if plan and plan.pair and plan.slot and key ~= "GREED" then
    local keep
    for _, o in ipairs(plan.options) do
      if o.slot ~= plan.slot then keep = o.old end
    end
    res.swap = { slot = plan.slot, label = NS.SLOT_LABEL[plan.slot], old = plan.old, keep = keep }
  end
  if res.equippedCopy and key ~= "GREED" then
    res.reasons[#res.reasons + 1] = "같은 아이템을 이미 하나 착용 중입니다 (고유 아님, 하나 더 착용 가능)"
  end

  if el.nonPrimaryArmor then
    res.reasons[#res.reasons + 1] = ("주 방어구(%s)가 아닙니다"):format(NS.ARMOR_LABEL[el.primaryArmor] or el.primaryArmor)
    if key == "BID_STRONG" then key = "BID" elseif key == "BID" then key = "BID_WEAK" end
  end
  if item.isBoE then res.reasons[#res.reasons + 1] = "착용 시 귀속 아이템입니다 (거래 가능)" end
  if item.special then res.reasons[#res.reasons + 1] = "특수 효과는 점수에 넣지 않았습니다" end
  if #item.unknown > 0 then
    res.reasons[#res.reasons + 1] = "확인 안 된 능력치가 있어 점수가 부정확할 수 있습니다: " .. table.concat(item.unknown, ", ")
  end
  return finish(res, key)
end
