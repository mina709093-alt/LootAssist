-- 능력치 키와 특성별 가중치
-- 키 확인: LootProbe 실측(2026-11-15, 빌드 1.60.1.70938)에서 나온 키만 NS.StatKeys 에 둔다.
-- 아직 실측에서 보지 못한 키는 NS.StatKeysUnverified 에 두고, 실제로 나오면 LootAssistDB.seenStats 에 기록한다.
-- 가중치 단위: 그 특성의 주 능력치 1점 = 1.0. 수치는 초기값이며 테스트 결과를 보며 조정한다.
local _, NS = ...

NS.StatKeys = {
  ITEM_MOD_STRENGTH_SHORT = "STR",
  ITEM_MOD_AGILITY_SHORT = "AGI",
  ITEM_MOD_STAMINA_SHORT = "STA",
  ITEM_MOD_INTELLECT_SHORT = "INT",
  ITEM_MOD_SPIRIT_SHORT = "SPI",
  ITEM_MOD_SPELL_POWER_SHORT = "SP",          -- 주문력: 피해와 치유 모두
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SD",    -- 주문 공격력
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL", -- 주문 치유
  ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "FIRE",
  ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "FROST",
  ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
  ITEM_MOD_HEALTH_REGEN_SHORT = "HP5",
  RESISTANCE0_NAME = "ARMOR",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
  ITEM_MOD_SPELL_PENETRATION_SHORT = "SPELLPEN",  -- 주문 관통력 (실측: LootAssistDB.unknownStats, 아이템 12543)
  ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT = "PHYS",   -- 물리 공격력 (실측: LootAssistDB.unknownStats, 아이템 274614)
}

-- 같은 이름 규칙이지만 아직 실측에서 확인하지 못한 키
NS.StatKeysUnverified = {
  ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "SHADOW",
  ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "NATURE",
  ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "ARCANE",
  ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "HOLY",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP",
  ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
  ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
  ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
  ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
  ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "EXP",
  ITEM_MOD_HASTE_RATING_SHORT = "HASTE",                  -- 가속 레이팅 (값은 레이팅 그대로)
  ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARPEN",      -- 방어구 관통
}

-- 레이팅 키: 값은 레이팅 점수이고, 아래 환산표로 %로 바꿔 HITPCT / CRITPCT 에 더한다
NS.RatingKeys = {
  ITEM_MOD_CRIT_RATING_SHORT = "CRIT", -- "치명타 및 극대화" (실측: LootAssistDB.unknownStats, 아이템 1263)
}
NS.RatingKeysUnverified = {
  ITEM_MOD_HIT_RATING_SHORT = "HIT",
}

-- 레이팅 몇 점이 1%인가
-- CRIT 14: 게임 측정 (34레벨 고양 주술사, 치명타 +14 장비 착용 시 캐릭터 창 치명타 +1.0%, 2026-11-21)
--          다른 레벨에서도 같은지는 확인하지 못함
-- HIT 10: WOWF BiS 페이지 상한 표기("장비 30 (3%)") 기준, 게임에서 측정하지 않음 (미검증)
-- 두 값 모두 wowsims/forever ui/sim/constants/mechanics.ts(60레벨)와 같음 (2026-11-28 확인)
NS.RatingPerPct = { CRIT = 14, HIT = 10 }

-- 적중 상한(%, 특성 보너스 포함 값). 0.8.0부터 점수에 씀: 상한을 넘는 적중은 0점 (Engine/PersonalEval.lua NS.HitCapAdjust)
-- 출처: WOWF BiS 페이지 "공격대 우두머리 상한" 표기, wowsims/forever 프리셋 주석(정기 17%, 고양 8%)과 같음.
-- 63레벨 우두머리 기준. 원거리(사냥꾼)는 근접 값을 씀. 던전 우두머리·60레벨 미만 기준은 확인하지 못함 (미검증)
NS.HitCapRef = { MELEE = 8, SPELL = 17 }

-- 점수에서 빼는 키 (저항력은 두 이름으로 중복 제공됨)
NS.StatKeysIgnored = {
  RESISTANCE1_NAME = true, RESISTANCE2_NAME = true, RESISTANCE3_NAME = true,
  RESISTANCE4_NAME = true, RESISTANCE5_NAME = true, RESISTANCE6_NAME = true,
  ITEM_MOD_HOLY_RESISTANCE_SHORT = true, ITEM_MOD_FIRE_RESISTANCE_SHORT = true,
  ITEM_MOD_NATURE_RESISTANCE_SHORT = true, ITEM_MOD_FROST_RESISTANCE_SHORT = true,
  ITEM_MOD_SHADOW_RESISTANCE_SHORT = true, ITEM_MOD_ARCANE_RESISTANCE_SHORT = true,
  ITEM_MOD_FISHING_SHORT = true,
}

NS.StatLabel = {
  STR = "힘", AGI = "민첩성", STA = "체력", INT = "지능", SPI = "정신력",
  SP = "주문력", SD = "주문 공격력", HEAL = "치유량",
  FIRE = "화염 공격력", FROST = "냉기 공격력", SHADOW = "암흑 공격력",
  NATURE = "자연 공격력", ARCANE = "비전 공격력", HOLY = "신성 공격력",
  MP5 = "마나 회복", HP5 = "생명력 회복", ARMOR = "방어도", DPS = "무기 공격력",
  HITPCT = "적중", CRITPCT = "치명타", EXP = "숙련", AP = "전투력", RAP = "원거리 전투력",
  DEF = "방어 숙련", DODGE = "회피", PARRY = "무기 막기", BLOCK = "방패 막기", BLOCKVAL = "방패 피해 흡수",
  SPELLPEN = "주문 관통력", PHYS = "물리 공격력", HASTE = "가속", ARPEN = "방어구 관통",
}

-- 공통 묶음
local function merge(a, b)
  local t = {}
  for k, v in pairs(a) do t[k] = v end
  for k, v in pairs(b or {}) do t[k] = v end
  return t
end

local MELEE_STR = { STR = 1.0, AGI = 0.7, STA = 0.2, AP = 0.5, HITPCT = 12, CRITPCT = 11, EXP = 0.8, ARMOR = 0.002, DPS_MELEE = 5, DPS_RANGED = 0.3 }
local MELEE_AGI = { AGI = 1.0, STR = 0.5, STA = 0.2, AP = 0.5, HITPCT = 12, CRITPCT = 12, EXP = 0.8, ARMOR = 0.002, DPS_MELEE = 5, DPS_RANGED = 0.3 }
local TANK = { STA = 1.0, STR = 0.6, AGI = 0.6, ARMOR = 0.03, DEF = 1.0, DODGE = 1.0, PARRY = 1.0, BLOCK = 0.7, BLOCKVAL = 0.5, HITPCT = 6, AP = 0.2, DPS_MELEE = 2 }
local HEALER = { HEAL = 0.55, SP = 0.55, INT = 0.8, MP5 = 1.5, SPI = 0.3, STA = 0.2, CRITPCT = 6, DPS_WAND = 0.5 }
local CASTER = { SD = 1.0, SP = 1.0, INT = 0.4, SPI = 0.15, STA = 0.2, MP5 = 0.6, HITPCT = 10, CRITPCT = 9, DPS_WAND = 1.0 }

NS.Weights = {
  WARRIOR = {
    ARMS = merge(MELEE_STR),
    FURY = merge(MELEE_STR, { dualWield = true }),
    PROTECTION = merge(TANK),
  },
  PALADIN = {
    HOLY = merge(HEALER, { INT = 1.0, SPI = 0.2, DPS_WAND = 0 }),
    PROTECTION = merge(TANK, { SP = 0.3, INT = 0.3 }),
    RETRIBUTION = merge(MELEE_STR, { AGI = 0.6, INT = 0.2, SP = 0.3, DPS_RANGED = 0 }),
  },
  HUNTER = {
    BEASTMASTERY = { AGI = 1.0, INT = 0.3, STA = 0.2, RAP = 0.45, AP = 0.4, STR = 0.05, HITPCT = 12, CRITPCT = 12, ARMOR = 0.002, DPS_RANGED = 5, DPS_MELEE = 0.3, dualWield = true },
    MARKSMANSHIP = { AGI = 1.0, INT = 0.3, STA = 0.2, RAP = 0.45, AP = 0.4, STR = 0.05, HITPCT = 12, CRITPCT = 12, ARMOR = 0.002, DPS_RANGED = 5, DPS_MELEE = 0.3, dualWield = true },
    SURVIVAL = { AGI = 1.0, INT = 0.3, STA = 0.2, RAP = 0.45, AP = 0.4, STR = 0.05, HITPCT = 12, CRITPCT = 12, ARMOR = 0.002, DPS_RANGED = 5, DPS_MELEE = 0.5, dualWield = true },
  },
  ROGUE = {
    ASSASSINATION = merge(MELEE_AGI, { dualWield = true }),
    COMBAT = merge(MELEE_AGI, { dualWield = true }),
    SUBTLETY = merge(MELEE_AGI, { dualWield = true }),
  },
  PRIEST = {
    DISCIPLINE = merge(HEALER, { SPI = 0.6 }),
    HOLY = merge(HEALER, { SPI = 0.6 }),
    SHADOW = merge(CASTER, { SHADOW = 1.0, SPI = 0.4, CRITPCT = 4 }),
  },
  SHAMAN = {
    ELEMENTAL = merge(CASTER, { NATURE = 1.0, FIRE = 0.3, DPS_WAND = 0 }),
    -- AGI 0.92: 게임 측정(34레벨 고양, 민첩 약 12 = 치명타 1%) × 치명타 1% 가중치 11 → 11 / 12. 민첩은 이 특성 전투력을 올리지 않음(측정)
    ENHANCEMENT = merge(MELEE_STR, { AGI = 0.92, INT = 0.2, SP = 0.2, DPS_RANGED = 0 }),
    RESTORATION = merge(HEALER, { MP5 = 1.6, SPI = 0.2, DPS_WAND = 0 }),
  },
  MAGE = {
    ARCANE = merge(CASTER, { ARCANE = 1.0, INT = 0.5 }),
    FIRE = merge(CASTER, { FIRE = 1.0 }),
    FROST = merge(CASTER, { FROST = 1.0 }),
  },
  WARLOCK = {
    AFFLICTION = merge(CASTER, { SHADOW = 1.0, STA = 0.3, CRITPCT = 5 }),
    DEMONOLOGY = merge(CASTER, { SHADOW = 1.0, STA = 0.3, CRITPCT = 5 }),
    DESTRUCTION = merge(CASTER, { SHADOW = 1.0, FIRE = 0.5, STA = 0.3 }),
  },
  DRUID = {
    BALANCE = merge(CASTER, { NATURE = 0.7, ARCANE = 0.7, DPS_WAND = 0 }),
    FERAL_BEAR = merge(TANK, { AGI = 0.7, DPS_MELEE = 0, PARRY = 0, BLOCK = 0, BLOCKVAL = 0 }),
    FERAL_CAT = { AGI = 1.0, STR = 1.0, AP = 0.5, STA = 0.2, HITPCT = 12, CRITPCT = 12, EXP = 0.8, ARMOR = 0.002 },
    RESTORATION = merge(HEALER, { SPI = 0.6, DPS_WAND = 0 }),
  },
}

function NS.GetWeights(classFile, specKey)
  local c = NS.Weights[classFile or ""]
  return c and c[specKey or ""]
end

-- 점수 기준 설명: { sim = 시뮬 가중치인가, unit = "힘" 같은 1점 기준 능력치 이름, preset = 시뮬 프리셋 이름 }
-- 추정 가중치는 묶음마다 기준이 달라서 unit 을 주지 않는다.
function NS.WeightInfo(classFile, specKey)
  local W = NS.GetWeights(classFile, specKey)
  if not W then return nil end
  if W._source == "sim" then
    return { sim = true, unit = NS.StatLabel[W._main] or W._main, preset = W._preset }
  end
  return { sim = false }
end
