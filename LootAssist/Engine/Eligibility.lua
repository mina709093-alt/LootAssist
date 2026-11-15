-- 착용 가능 판정 (별도 모듈)
-- 원칙: 직업이 습득할 수 있는 숙련은 보유한 것으로 본다. 단, 사슬/판금처럼 습득 레벨이 있는 숙련은 그 레벨부터.
local _, NS = ...

local WEAPON_SUB = {
  [0] = "AXE1H", [1] = "AXE2H", [2] = "BOW", [3] = "GUN", [4] = "MACE1H", [5] = "MACE2H",
  [6] = "POLEARM", [7] = "SWORD1H", [8] = "SWORD2H", [10] = "STAFF", [13] = "FIST",
  [15] = "DAGGER", [16] = "THROWN", [18] = "CROSSBOW", [19] = "WAND",
}
local WEAPON_ANY = { [14] = true, [20] = true } -- 기타(곡괭이 등), 낚싯대
local ARMOR_SUB = { [1] = "CLOTH", [2] = "LEATHER", [3] = "MAIL", [4] = "PLATE", [6] = "SHIELD" }
local RELIC_SUB = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" } -- 성서 / 우상 / 토템
local ARMOR_RANK = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4 }

NS.ARMOR_LABEL = { CLOTH = "천", LEATHER = "가죽", MAIL = "사슬", PLATE = "판금", SHIELD = "방패" }
NS.WEAPON_LABEL = {
  AXE1H = "한손 도끼", AXE2H = "양손 도끼", BOW = "활", GUN = "총", MACE1H = "한손 둔기", MACE2H = "양손 둔기",
  POLEARM = "장창", SWORD1H = "한손 검", SWORD2H = "양손 검", STAFF = "지팡이", FIST = "장착 무기",
  DAGGER = "단검", THROWN = "투척 무기", CROSSBOW = "석궁", WAND = "마법봉",
}

-- 장비 칸 (INVTYPE -> 인벤토리 슬롯 번호)
NS.SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
  INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- 이 레벨에서 입을 수 있는 가장 무거운 방어구 = 주 방어구
function NS.PrimaryArmor(classFile, level)
  local c = NS.GetClassData(classFile)
  if not c then return nil end
  local best, bestRank = nil, 0
  for key, need in pairs(c.armor) do
    local rank = ARMOR_RANK[key]
    if rank and (level or 1) >= need and rank > bestRank then best, bestRank = key, rank end
  end
  return best
end

-- 결과: { ok, notGear, reason, needLevel, armorType, weaponType, nonPrimaryArmor }
function NS.CheckEligibility(item, classFile, level)
  local r = {}
  local c = NS.GetClassData(classFile)
  if not c then r.ok = false; r.reason = "직업 정보를 알 수 없습니다"; return r end
  level = level or 1

  local loc = item.equipLoc
  if loc == "INVTYPE_BODY" or loc == "INVTYPE_TABARD" then
    r.notGear = true; r.reason = "장식용 아이템입니다"; return r
  end
  if not NS.SLOTS[loc] then
    r.notGear = true; r.reason = "장비 아이템이 아닙니다"; return r
  end

  if item.isWeapon then
    local wt = WEAPON_SUB[item.subclassID or -1]
    if WEAPON_ANY[item.subclassID or -1] then
      r.ok = true; r.weaponType = "MISC"
    elseif not wt then
      r.ok = false; r.reason = "알 수 없는 무기 종류입니다"
    else
      r.weaponType = wt
      local need = c.weapons[wt]
      if not need then
        r.ok = false; r.reason = ("%s 무기 기술을 배울 수 없는 직업입니다"):format(NS.WEAPON_LABEL[wt] or wt)
      elseif level < need then
        r.ok = false; r.needLevel = need; r.reason = ("%s 무기 기술은 %d레벨부터 배울 수 있습니다"):format(NS.WEAPON_LABEL[wt] or wt, need)
      else
        r.ok = true
      end
    end
  elseif item.isArmor then
    local sub = item.subclassID or -1
    if loc == "INVTYPE_CLOAK" or sub == 0 then
      r.ok = true -- 망토, 목걸이, 반지, 장신구, 보조장비(손에 드는 것)는 누구나
    elseif RELIC_SUB[sub] then
      r.ok = (RELIC_SUB[sub] == classFile)
      if not r.ok then r.reason = "다른 직업 전용 유물입니다" end
    else
      local at = ARMOR_SUB[sub]
      if not at then
        r.ok = false; r.reason = "알 수 없는 방어구 종류입니다"
      else
        r.armorType = at
        local need = c.armor[at]
        if not need then
          r.ok = false; r.reason = ("%s 방어구를 입을 수 없는 직업입니다"):format(NS.ARMOR_LABEL[at])
        elseif level < need then
          r.ok = false; r.needLevel = need; r.reason = ("%s 방어구는 %d레벨부터 입을 수 있습니다"):format(NS.ARMOR_LABEL[at], need)
        else
          r.ok = true
          local primary = NS.PrimaryArmor(classFile, level)
          if ARMOR_RANK[at] and primary and ARMOR_RANK[at] < ARMOR_RANK[primary] then
            r.nonPrimaryArmor = true
            r.primaryArmor = primary
          end
        end
      end
    end
  else
    r.notGear = true; r.reason = "장비 아이템이 아닙니다"
  end
  return r
end
