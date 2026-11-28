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
    elseif item.isWeapon then
      -- 보조 전용 무기는 보조 무기 공격력 가중치(시뮬 OffHandDps)가 있으면 그것을 쓴다
      if item.equipLoc == "INVTYPE_WEAPONOFFHAND" and W.DPS_OFFHAND then w = W.DPS_OFFHAND else w = W.DPS_MELEE end
    end
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
NS.PairOptions = pairOptions

local function hitOf(it) return (it and it.stats and it.stats.HITPCT) or 0 end

-- 가방 장비 (0.9.0) ---------------------------------------------------------
-- 가방에 지금 장비보다 좋은 것이 있으면 그것을 기준으로 비교하고, 무기는 가방 무기와의 조합까지 본다.
local bagCache
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:SetScript("OnEvent", function() bagCache = nil end)
end

-- 가방(0~4)의 장비 아이템. 못 읽은 아이템이 있으면 다음에 다시 읽는다
function NS.BagGear()
  if bagCache then return bagCache end
  local C = C_Container
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  local getLink = (C and C.GetContainerItemLink) or GetContainerItemLink
  if not (numSlots and getLink) then return {} end
  local list, complete = {}, true
  for bag = 0, 4 do
    local ok, n = pcall(numSlots, bag)
    for s = 1, (ok and type(n) == "number") and n or 0 do
      local ok2, l = pcall(getLink, bag, s)
      if ok2 and type(l) == "string" and not NS.IsSecret(l) then
        local _, _, _, loc = GetItemInfoInstant(l)
        if loc and NS.SLOTS[loc] then
          local it = NS.ReadItem(l)
          if it then list[#list + 1] = it else complete = false end
        end
      end
    end
  end
  if complete then bagCache = list end
  return list
end

-- 지금 바로 낄 수 있는 가방 장비 (평가하는 아이템과 같은 번호는 뺌)
function NS.UsableBagGear(item, classFile, level)
  local out = {}
  for _, b in ipairs(NS.BagGear()) do
    if b.itemID ~= item.itemID and (b.reqLevel or 0) <= level and NS.CheckEligibility(b, classFile, level).ok then
      out[#out + 1] = b
    end
  end
  return out
end

local function fits(it, slot)
  for _, s in ipairs(NS.SLOTS[it.equipLoc] or {}) do
    if s == slot then return true end
  end
  return false
end

-- 두 칸 부위 기준 조합: 낀 것과 가방 것 중 점수가 높은 것 (고유는 하나만). 같은 점수면 낀 것을 남긴다.
-- 돌려줌: 칸별 아이템(false = 빈 칸), 기준에 들어간 가방 아이템 목록, 적중 차이(기준 - 낀 것)
local function pairBaseline(slots, equipped, bag, score)
  local cands = {}
  for i = 1, #slots do
    if equipped[i] then cands[#cands + 1] = { it = equipped[i], slot = i, s = score(equipped[i]) } end
  end
  local nBag = 0
  for _, b in ipairs(bag) do
    local s = score(b)
    if fits(b, slots[1]) and s > 0 then cands[#cands + 1] = { it = b, s = s }; nBag = nBag + 1 end
  end
  if nBag == 0 then return equipped end
  table.sort(cands, function(a, b)
    if a.s ~= b.s then return a.s > b.s end
    return (a.slot and 1 or 0) > (b.slot and 1 or 0)
  end)
  local pick = {}
  for _, c in ipairs(cands) do
    if #pick >= #slots then break end
    local dup = false
    for _, p in ipairs(pick) do
      if c.it.unique and p.it.itemID == c.it.itemID then dup = true end
    end
    if not dup then pick[#pick + 1] = c end
  end
  local out, used, bagBase, shift = {}, {}, {}, 0
  for i = 1, #slots do out[i] = false; shift = shift - hitOf(equipped[i] or nil) end
  for _, c in ipairs(pick) do
    if c.slot then out[c.slot] = c.it; used[c.slot] = true end
  end
  for _, c in ipairs(pick) do
    if not c.slot then
      for i = 1, #slots do
        if not used[i] then out[i] = c.it; used[i] = true; break end
      end
      bagBase[#bagBase + 1] = c.it
    end
  end
  for i = 1, #slots do shift = shift + hitOf(out[i] or nil) end
  if #bagBase == 0 then return equipped end
  return out, bagBase, shift
end

-- 무기 조합 (주무기·보조장비·양손). 낀 무기와 가방 무기 중에서 고른다.
local WEAPON_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true,
                     INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local MH_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OH_LOC = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

-- must 를 주면 그 아이템이 들어간 조합 중 가장 좋은 것
local function bestWeaponSet(pool, W, score, must)
  local best
  local function canOH(x) return OH_LOC[x.equipLoc] or (W.dualWield and x.equipLoc == "INVTYPE_WEAPON") end
  local function try(a, b)
    if must and a ~= must and b ~= must then return end
    if a and b and a.unique and a.itemID == b.itemID then return end
    local s = score(a) + score(b)
    if not best or s > best.s then best = { s = s, mh = a, oh = b } end
  end
  try(nil, nil)
  for _, a in ipairs(pool) do
    if a.equipLoc == "INVTYPE_2HWEAPON" then
      try(a, nil)
    elseif MH_LOC[a.equipLoc] then
      try(a, nil)
      for _, b in ipairs(pool) do
        if b ~= a and canOH(b) then try(a, b) end
      end
    end
    if canOH(a) then try(nil, a) end
  end
  return best
end

-- 무기 칸 계산 (내 평가 전용, 가방 포함). 두 조합에 모두 들어간 무기는 빼고 바뀌는 부분만 점수로 비교한다.
local function weaponPlan(item, W, mh, oh, bag, score)
  local pool = {}
  if mh then pool[#pool + 1] = mh end
  if oh then pool[#pool + 1] = oh end
  for _, b in ipairs(bag) do
    if WEAPON_LOC[b.equipLoc] then pool[#pool + 1] = b end
  end
  local curSet = bestWeaponSet(pool, W, score)
  pool[#pool + 1] = item
  local newSet = bestWeaponSet(pool, W, score, item)
  if not newSet then return nil, "UNIQUE" end
  -- 양손 무기를 쓰는데 함께 쓸 한손 무기가 없는 보조장비
  if OH_LOC[item.equipLoc] and not newSet.mh and curSet.mh and curSet.mh.equipLoc == "INVTYPE_2HWEAPON" then
    return nil, "TWOHAND"
  end
  local function has(set, x) return x and (set.mh == x or set.oh == x) end
  local function isBag(x) return x and x ~= mh and x ~= oh and x ~= item end
  local cur, new, hitOld, hitNew = 0, 0, 0, 0
  local plan = { weaponSet = true, curSet = curSet, newSet = newSet,
                 hitShift = hitOf(curSet.mh) + hitOf(curSet.oh) - hitOf(mh or nil) - hitOf(oh or nil) }
  for _, x in ipairs({ curSet.mh or false, curSet.oh or false }) do
    if x and not has(newSet, x) then
      cur = cur + score(x); hitOld = hitOld + hitOf(x)
      plan.old = plan.old or x
      if isBag(x) then plan.bagBase = plan.bagBase or {}; plan.bagBase[#plan.bagBase + 1] = x end
    elseif x then
      plan.keep = x -- 두 조합에 모두 들어간 무기 (가방 것이면 "함께 쓰는 것"으로 안내)
      if isBag(x) then plan.bagWith = plan.bagWith or {}; plan.bagWith[#plan.bagWith + 1] = x end
    end
  end
  for _, x in ipairs({ newSet.mh or false, newSet.oh or false }) do
    if x and not has(curSet, x) then
      new = new + score(x); hitNew = hitNew + hitOf(x)
      if isBag(x) then plan.bagWith = plan.bagWith or {}; plan.bagWith[#plan.bagWith + 1] = x end
    end
  end
  plan.slot = (newSet.mh == item) and 16 or 17
  plan.total, plan.newScore, plan.hitOld, plan.hitNew = cur, new, hitOld, hitNew
  plan.sameEquipped = item.unique and ((mh and mh.itemID == item.itemID) or (oh and oh.itemID == item.itemID)) or false
  -- filled = 새 아이템이 밀어내는 무기가 있는가 (없으면 "비어 있는 칸을 채웁니다")
  return cur, nil, (plan.old ~= nil), plan
end

-- 같은 칸 현재 장비 점수. nil = 아직 못 읽음, 두 번째 값은 상황 설명, 세 번째 값은 칸에 장비가 있는지,
-- 네 번째 값은 교체 계획 { slot, old, total, pair, options, sameEquipped } (알 수 있을 때만)
-- 두 번째 값 "UNIQUE" = 고유 아이템이라 바꿀 수 있는 칸이 없음
-- getLink(slot) 를 주면 그 장비(살펴보기로 읽은 파티원 장비 등)로 계산한다
-- bag(0.9.0) = 지금 낄 수 있는 가방 장비 목록. 주면 가방 것까지 기준에 넣는다 (내 평가에서만 씀)
function NS.CurrentSlotScore(item, classFile, specKey, getLink, bag)
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

  if bag and WEAPON_LOC[loc] then
    local oh = readEquipped(17)
    if oh == nil then return nil, "loading" end
    return weaponPlan(item, W, mh, oh, bag, score)
  end

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
    local worn = equipped[1] or nil
    local base, s = worn, score(worn)
    for _, b in ipairs(bag or {}) do
      if fits(b, slots[1]) then
        local bs = score(b)
        if bs > s then base, s = b, bs end
      end
    end
    local plan = { slot = slots[1], old = base, total = s }
    if base ~= worn then plan.bagBase = { base }; plan.hitShift = hitOf(base) - hitOf(worn) end
    return s, nil, (equipped[1] ~= false or base ~= worn), plan
  end
  local bagBase, hitShift
  if bag then equipped, bagBase, hitShift = pairBaseline(slots, equipped, bag, score) end
  local best, plan = pairOptions(item, slots, equipped, score)
  if not best then return nil, "UNIQUE" end
  plan.bagBase, plan.hitShift = bagBase, hitShift
  return best.cur, nil, best.filled, plan
end

local function topStats(parts, n)
  local names = {}
  for i = 1, math.min(n, #parts) do
    if parts[i].value > 0 then names[#names + 1] = NS.StatLabel[parts[i].stat] or parts[i].stat end
  end
  return table.concat(names, ", ")
end

local function namesOf(list)
  local t = {}
  for _, it in ipairs(list) do t[#t + 1] = it.link or it.name or "?" end
  return table.concat(t, ", ")
end

local function W_dualWield(classFile, specKey)
  return (NS.GetWeights(classFile, specKey) or {}).dualWield
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

-- 적중 상한 반영 (0.8.0) ---------------------------------------------------

-- 지금 낀 장비의 적중 합계(%). 못 읽은 칸이 있으면 nil
function NS.EquippedHitSum(getLink)
  local sum = 0
  for slot = 1, 18 do
    local l
    if getLink then l = getLink(slot) else l = GetInventoryItemLink("player", slot) end
    if l and not NS.IsSecret(l) then
      local it = NS.ReadItem(l)
      if not it then return nil end
      sum = sum + hitOf(it)
    end
  end
  return sum
end

-- 특성·종족 적중 보너스(%): 게임에서 읽지 못해 직접 입력한 값 (/전리품 적중 n)
function NS.HitBonus()
  local v = NS.db and NS.Char().hitBonus
  return (type(v) == "number" and v > 0) and v or 0
end

-- 이 특성의 적중 상한(%): 주문 공격 특성은 주문, 나머지는 근접 상한
function NS.HitCapFor(spec)
  local spell = spec and (spec.role == "CASTER" or spec.role == "HEALER")
  return spell and NS.HitCapRef.SPELL or NS.HitCapRef.MELEE, spell
end

-- 교체로 바뀌는 적중의 점수 보정. 선형 점수(적중 1% = w점)에 더하는 값.
-- 상한을 넘는 적중은 0점이므로, 실제로 쓰이는 적중 변화량과 선형 계산의 차이를 돌려준다.
-- before = 교체 전 적중(장비 + 특성 보너스), oldHit = 빠지는 아이템 적중, newHit = 새 아이템 적중
function NS.HitCapAdjust(w, before, oldHit, newHit, cap)
  local after = before - oldHit + newHit
  local used = math.min(cap, after) - math.min(cap, before)
  return w * (used - (newHit - oldHit)), after
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
  local equippedHit -- 장비 적중 합계 (필요할 때 한 번만 읽음, false = 못 읽음)
  local bag = NS.UsableBagGear(item, me.class, me.level)
  local function evalSpec(spec)
    local new, parts = NS.SpecScore(item, me.class, spec.key)
    new = new or 0
    local cur, why, filled, plan = NS.CurrentSlotScore(item, me.class, spec.key, nil, bag)
    -- 무기 조합: 가방 무기와 함께 쓰는 경우 그 점수까지 새 점수에 넣는다
    if plan and plan.newScore then new = plan.newScore end
    -- 적중 상한: 상한을 넘는 적중은 점수에 넣지 않는다
    local hit
    local hw = (NS.GetWeights(me.class, spec.key) or {}).HITPCT or 0
    local newHit = item.stats.HITPCT or 0
    if hw > 0 and plan and cur ~= nil then
      if equippedHit == nil then equippedHit = NS.EquippedHitSum() or false end
      if equippedHit then
        local cap, spell = NS.HitCapFor(spec)
        local bonus = NS.HitBonus()
        local before = equippedHit + bonus + (plan.hitShift or 0)
        local adj, after
        if plan.pair and plan.options then
          -- 칸마다 빠지는 적중이 다르므로, 보정한 점수로 가장 좋은 칸을 다시 고른다
          local best, bestAdj, bestAfter
          for _, o in ipairs(plan.options) do
            if not o.blocked then
              local a, af = NS.HitCapAdjust(hw, before, hitOf(o.old), newHit, cap)
              if not best or (a - o.cur) > (bestAdj - best.cur) then best, bestAdj, bestAfter = o, a, af end
            end
          end
          if best then
            cur, filled, plan.slot, plan.old = best.cur, best.filled, best.slot, best.old
            adj, after = bestAdj, bestAfter
          end
        else
          adj, after = NS.HitCapAdjust(hw, before, plan.hitOld or (hitOf(plan.old) + hitOf(plan.both)),
            plan.hitNew or newHit, cap)
        end
        if adj then
          new = new + adj
          if adj < 0 then
            for _, p in ipairs(parts or {}) do
              if p.stat == "HITPCT" then p.value = math.max(0, p.value + adj) end
            end
            table.sort(parts, function(a, b) return a.value > b.value end)
          end
          hit = { after = after, before = before, gear = after - bonus, bonus = bonus, cap = cap, spell = spell,
                  adjust = adj, cut = math.max(0, -adj / hw) }
        end
      end
    end
    local slotGain = gainOf(new, cur)
    local gain = slotGain
    -- 두 칸 부위는 "두 칸 합(조합)" 기준으로 얼마나 좋아지는지 본다 (한 칸만 기준으로 하면 상승률이 부풀려짐)
    if plan and plan.pair and cur ~= nil and (plan.total or 0) > 0 then
      gain = (new - cur) / plan.total
    end
    return {
      new = new, parts = parts or {}, cur = cur, why = why, filled = filled, plan = plan,
      fit = NS.SpecFit(item, me.class, spec.key, maxScore),
      gain = gain, slotGain = slotGain, hit = hit,
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
    elseif P.plan and P.plan.bagBase then
      res.reasons[#res.reasons + 1] = ("가방에 있는 %s보다 좋지 않습니다"):format(namesOf(P.plan.bagBase))
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
  elseif plan and plan.weaponSet and key ~= "GREED"
      and ((item.equipLoc == "INVTYPE_WEAPON" and W_dualWield(me.class, mainSpec.key)) or plan.bagWith) then
    -- 무기 조합: 새 아이템이 들어갈 칸과 함께 쓰는 무기
    local ns = plan.newSet
    local partner = (ns.mh == item) and ns.oh or ns.mh
    res.swap = { slot = plan.slot, label = NS.SLOT_LABEL[plan.slot], old = plan.old, keep = partner }
  end
  -- 가방 장비를 기준이나 조합에 쓴 경우
  if plan and key ~= "GREED" then
    if plan.bagBase then
      res.reasons[#res.reasons + 1] = ("가방에 있는 %s이(가) 지금 장비보다 좋아서 그것과 비교했습니다"):format(namesOf(plan.bagBase))
    end
    if plan.bagWith then
      res.reasons[#res.reasons + 1] = ("가방의 %s와(과) 함께 쓰는 기준입니다"):format(namesOf(plan.bagWith))
    end
  end
  -- 적중 안내 (툴팁): 바꾼 뒤 적중 합계, 상한, 상한을 넘어 점수에서 뺀 양
  if (item.stats.HITPCT or 0) > 0 and main.hit then res.hit = main.hit end

  -- 점수 차이 (툴팁 "+n점" 표시용): 차비면 주 특성, 아니면 판정에 쓴 특성 기준
  local scoreBase = (key == "GREED") and P or main
  local scoreSpec = (key == "GREED") and pSpec or mainSpec
  if scoreBase.cur ~= nil then
    res.score = { new = scoreBase.new, cur = scoreBase.cur, delta = scoreBase.new - scoreBase.cur,
                  spec = scoreSpec.name, info = NS.WeightInfo(me.class, scoreSpec.key) }
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
