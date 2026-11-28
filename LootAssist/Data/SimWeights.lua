-- 시뮬레이터 가중치 (wowsims/forever, MIT 라이선스, https://github.com/wowsims/forever)
-- 각 특성 폴더 presets.ts 의 EP 프리셋 값을 그대로 옮겼다 (druid/feral_ep.ts 는 소수 넷째 자리 반올림).
-- 확인: master dc09e00 (2026-11-28). 시뮬 조건: 캐릭터 60레벨, 우두머리 63레벨, 프리셋 장비·특성·로테이션.
-- 레이팅 환산(ui/sim/constants/mechanics.ts): 적중 10, 치명타 14, 가속 10, 숙련 10 = 1%
-- 불러올 때 그 특성의 주 능력치(main) 1점 = 1.0 으로 나눠 NS.Weights 의 같은 특성을 바꾼다.
-- 여기 없는 특성(시뮬 프리셋에 EP가 없음)은 Data/Weights.lua 의 추정값을 그대로 쓴다.
local _, NS = ...

local HIT_PER_PCT, CRIT_PER_PCT = 10, 14

-- 시뮬 능력치 이름 -> 이 애드온 능력치 이름 (HITPCT/CRITPCT 는 1% 단위라 환산값을 곱한다)
local MAP = {
  Strength = "STR", Agility = "AGI", Stamina = "STA", Intellect = "INT", Spirit = "SPI",
  SpellDamage = "SD", HealingPower = "HEAL",
  ArcaneDamage = "ARCANE", FireDamage = "FIRE", FrostDamage = "FROST", HolyDamage = "HOLY",
  NatureDamage = "NATURE", ShadowDamage = "SHADOW", SpellPiercing = "SPELLPEN",
  AttackPower = "AP", RangedAttackPower = "RAP",
  HasteRating = "HASTE", ExpertiseRating = "EXP", ArmorPenetration = "ARPEN",
  DefenseRating = "DEF", DodgeRating = "DODGE", ParryRating = "PARRY", BlockRating = "BLOCK", BlockValue = "BLOCKVAL",
  Armor = "ARMOR", MP5 = "MP5", PhysicalDamage = "PHYS",
  MainHandDps = "DPS_MELEE", OffHandDps = "DPS_OFFHAND", RangedDps = "DPS_RANGED",
}
NS.SimStatMap = MAP

-- file: wowsims 저장소 안의 위치, preset: 프리셋 이름, main: 점수 1점의 기준 능력치
NS.SimEP = {
  WARRIOR = {
    ARMS = { file = "ui/specs/warrior/dps/presets.ts", preset = "Pre-BiS - Arms", main = "Strength",
      ep = { Strength = 2.2, Agility = 1.76, AttackPower = 1, ArmorPenetration = 0.46, HitRating = 5.03,
             HasteRating = 1.29, CritRating = 2.32, ExpertiseRating = 1.57, MainHandDps = 16.71, OffHandDps = 0 } },
    FURY = { file = "ui/specs/warrior/dps/presets.ts", preset = "Pre-BiS - Fury", main = "Strength",
      ep = { Strength = 2.2, Agility = 1.7, AttackPower = 1, ArmorPenetration = 0.39, HitRating = 1.69,
             HasteRating = 1.76, CritRating = 2.26, ExpertiseRating = 2.35, MainHandDps = 12.59, OffHandDps = 2.66 } },
    PROTECTION = { file = "ui/specs/warrior/protection/presets.ts", preset = "Pre-BiS - Balanced", main = "Stamina",
      ep = { Stamina = 1.15, Strength = 0.62, Agility = 0.66, AttackPower = 0.27, HitRating = 0.04, CritRating = 0.43,
             HasteRating = 0.17, ExpertiseRating = 2.35, ArmorPenetration = 0.11, DefenseRating = 0.53, BlockRating = 0,
             BlockValue = 0.76, DodgeRating = 0.29, ParryRating = 0.26, Armor = 0.06, MainHandDps = 1.42 } },
  },
  PALADIN = {
    RETRIBUTION = { file = "ui/specs/paladin/retribution/presets.ts", preset = "Holy Shock", main = "Strength",
      ep = { Strength = 2.4, Agility = 1.91, Intellect = 1.77, SpellDamage = 2.47, HolyDamage = 2.06, SpellPiercing = 0.84,
             AttackPower = 1, HitRating = 7.23, CritRating = 3, HasteRating = 2.73, ArmorPenetration = 0.22,
             ExpertiseRating = 4.81, MP5 = 0.01, MainHandDps = 14.02 } },
  },
  HUNTER = {
    BEASTMASTERY = { file = "ui/specs/hunter/dps/presets.ts", preset = "Turret", main = "Agility",
      ep = { Agility = 1, Intellect = 0.64, RangedAttackPower = 0.34, HitRating = 1.26, CritRating = 0.87,
             HasteRating = 0.75, MP5 = 0.41, RangedDps = 3.29 } },
    MARKSMANSHIP = { file = "ui/specs/hunter/dps/presets.ts", preset = "Turret", main = "Agility",
      ep = { Agility = 1, Intellect = 0.64, RangedAttackPower = 0.34, HitRating = 1.26, CritRating = 0.87,
             HasteRating = 0.75, MP5 = 0.41, RangedDps = 3.29 } },
    SURVIVAL = { file = "ui/specs/hunter/dps/presets.ts", preset = "Weave", main = "Agility",
      ep = { Agility = 1, Strength = 0.22, Intellect = 0.44, AttackPower = 0.2, RangedAttackPower = 0.2,
             HitRating = 1.43, CritRating = 0.83, HasteRating = 0.82, MP5 = 0.12, MainHandDps = 2.93, RangedDps = 1.69 } },
  },
  ROGUE = {
    ASSASSINATION = { file = "ui/specs/rogue/dps/presets.ts", preset = "Assassination", main = "Agility",
      ep = { Stamina = 0.01, Agility = 2.06, Strength = 1.1, CritRating = 2.02, HasteRating = 1.93, HitRating = 2.8,
             ExpertiseRating = 2.77, ArmorPenetration = 0.4, SpellPiercing = 0.65, AttackPower = 1.0, PhysicalDamage = 10.55,
             MainHandDps = 8.44, OffHandDps = 4.16 } },
    COMBAT = { file = "ui/specs/rogue/dps/presets.ts", preset = "Combat Sinister", main = "Agility",
      ep = { Stamina = 0.01, Agility = 1.96, Strength = 1.1, CritRating = 1.7, HasteRating = 1.72, HitRating = 2.42,
             ExpertiseRating = 2.55, ArmorPenetration = 0.41, SpellPiercing = 0.19, AttackPower = 1.0, PhysicalDamage = 7.97,
             MainHandDps = 10.57, OffHandDps = 2.93 } },
    SUBTLETY = { file = "ui/specs/rogue/dps/presets.ts", preset = "Subtlety", main = "Agility",
      ep = { Stamina = 0.01, Agility = 1.93, Strength = 1.1, CritRating = 1.63, HasteRating = 1.43, HitRating = 2.12,
             ExpertiseRating = 2.42, ArmorPenetration = 0.33, SpellPiercing = 0.16, AttackPower = 1.0, PhysicalDamage = 6.83,
             MainHandDps = 10.47, OffHandDps = 2.27 } },
  },
  PRIEST = {
    DISCIPLINE = { file = "ui/specs/priest/healer/presets.ts", preset = "Disc Single-Target", main = "HealingPower",
      ep = { HealingPower = 1.0, CritRating = 0.7, HasteRating = 0.15, Intellect = 0.2, Spirit = 0.15, MP5 = 0.4 } },
    HOLY = { file = "ui/specs/priest/healer/presets.ts", preset = "Holy Single-Target", main = "HealingPower",
      ep = { HealingPower = 1.0, CritRating = 0.3, HasteRating = 0.5, Intellect = 0.35, Spirit = 0.3, MP5 = 0.6 } },
    SHADOW = { file = "ui/specs/priest/dps/presets.ts", preset = "Shadow", main = "SpellDamage",
      ep = { Intellect = 0.26, SpellDamage = 1.0, ShadowDamage = 1.0, SpellPiercing = 2.49, HitRating = 1.2,
             CritRating = 0.99, HasteRating = -0.09, MP5 = 0.01 } },
  },
  SHAMAN = {
    ELEMENTAL = { file = "ui/specs/shaman/elemental/presets.ts", preset = "Default", main = "SpellDamage",
      ep = { Intellect = 0.19, Spirit = 0.02, SpellDamage = 1, FireDamage = 0.31, NatureDamage = 0.69, SpellPiercing = 1.81,
             HitRating = 1.18, CritRating = 0.61, HasteRating = 1.23, MP5 = 0.04 } },
    ENHANCEMENT = { file = "ui/specs/shaman/enhancement/presets.ts", preset = "Pre-BiS", main = "Strength",
      ep = { Strength = 2.2, Agility = 1.32, Intellect = 1.99, AttackPower = 1, HitRating = 5.2, CritRating = 2.42,
             HasteRating = 2.81, ExpertiseRating = 3.5, ArmorPenetration = 0.37, SpellDamage = 1.27, NatureDamage = 0.72,
             SpellPiercing = 2.52, MainHandDps = 14.18 } },
  },
  DRUID = {
    BALANCE = { file = "ui/specs/druid/balance/presets.ts", preset = "Pre-BiS", main = "SpellDamage",
      ep = { Intellect = 0.23, Spirit = 0.02, SpellDamage = 1, ArcaneDamage = 0.62, NatureDamage = 0.38, HitRating = 1.15,
             CritRating = 0.72, HasteRating = 1, MP5 = 0.08 } },
    FERAL_BEAR = { file = "ui/specs/druid/feral_ep.ts", preset = "Bear", main = "Stamina",
      ep = { Strength = 0.4861, Agility = 0.4335, Stamina = 1.0029, AttackPower = 0.2209, HitRating = 0.6879,
             CritRating = 0.3633, HasteRating = 0.3581, ArmorPenetration = 0.0826, ExpertiseRating = 1.776,
             DefenseRating = 0.8758, DodgeRating = 0.1074, Armor = 0.1744, PhysicalDamage = 1.3667, MainHandDps = 3.0931 } },
    FERAL_CAT = { file = "ui/specs/druid/feral_ep.ts", preset = "Cat", main = "Agility",
      ep = { Strength = 0.5942, Agility = 0.6547, AttackPower = 0.2438, HitRating = 0.5212, CritRating = 0.5057,
             HasteRating = 0.3931, ArmorPenetration = 0.0742, ExpertiseRating = 0.4904, PhysicalDamage = 1.8631,
             MainHandDps = 2.142 } },
  },
  -- 아래 두 직업은 presets.ts 에 EP 프리셋이 없어서, wowsims 웹 시뮬레이터(wowsims.com/forever, dc09e00)의
  -- "Stat Weights" 계산을 프리셋 설정·장비 그대로 돌려 얻은 값이다 (12,500회, 2026-11-28, 소수 둘째 자리).
  -- 웹 화면은 적중·치명타·가속을 1% 단위로 보여 주므로 레이팅 1점 값으로 바꿔 적는다 (적중·가속 ÷10, 치명타 ÷14).
  -- 신성·보호 성기사, 복원 주술사, 회복 드루이드는 웹에서 "장비 계획 전용(시뮬 없음)"이거나 프리셋 장비가 없어 계산하지 못했다.
  MAGE = {
    ARCANE = { file = "wowsims.com/forever/mage/dps (웹 계산)", preset = "Arcane", main = "SpellDamage",
      ep = { Intellect = 0.86, SpellDamage = 1, ArcaneDamage = 0.89, FireDamage = 0.11, SpellPiercing = 2.58, Spirit = 0.13,
             HitRating = 13.66 / 10, CritRating = 8.80 / 14, HasteRating = 23.17 / 10, MP5 = 0.16 } },
    FIRE = { file = "wowsims.com/forever/mage/dps (웹 계산)", preset = "Fire", main = "SpellDamage",
      ep = { Intellect = 0.31, SpellDamage = 1, ArcaneDamage = 0.12, FireDamage = 0.88, SpellPiercing = 2.24,
             HitRating = 14.80 / 10, CritRating = 11.56 / 14, HasteRating = 10.42 / 10 } },
    FROST = { file = "wowsims.com/forever/mage/dps (웹 계산)", preset = "Frost Incin", main = "SpellDamage",
      ep = { Intellect = 0.26, SpellDamage = 1, FrostDamage = 1.00, SpellPiercing = 2.16, Spirit = 0.04,
             HitRating = 15.36 / 10, CritRating = 9.61 / 14, HasteRating = 10.61 / 10, MP5 = 0.12 } },
  },
  WARLOCK = {
    AFFLICTION = { file = "wowsims.com/forever/warlock/dps (웹 계산)", preset = "Aff (Wrack)", main = "SpellDamage",
      ep = { Intellect = 0.33, SpellDamage = 1, ShadowDamage = 0.98, SpellPiercing = 0.19, Spirit = 0.04,
             HitRating = 6.77 / 10, CritRating = 10.35 / 14, HasteRating = 4.30 / 10, MP5 = 0.24 } },
    DEMONOLOGY = { file = "wowsims.com/forever/warlock/dps (웹 계산)", preset = "Demo (Fire Brand)", main = "SpellDamage",
      ep = { Intellect = 0.32, SpellDamage = 1, FireDamage = 0.74, ShadowDamage = 0.26, SpellPiercing = 1.29, Spirit = 0.15,
             HitRating = 12.88 / 10, CritRating = 8.61 / 14, HasteRating = 5.49 / 10, MP5 = 0.30 } },
    DESTRUCTION = { file = "wowsims.com/forever/warlock/dps (웹 계산)", preset = "Destro", main = "SpellDamage",
      ep = { Intellect = 0.29, SpellDamage = 1, FireDamage = 0.64, ShadowDamage = 0.34, SpellPiercing = 1.39, Spirit = 0.12,
             HitRating = 10.24 / 10, CritRating = 10.23 / 14, HasteRating = 7.40 / 10, MP5 = 0.28 } },
  },
}

-- 시뮬 EP -> 이 애드온 가중치 (주 능력치 1점 = 1.0)
function NS.ConvertSimEP(def)
  local base = def.ep[def.main]
  if not base or base == 0 then return nil end
  local w = {}
  for k, v in pairs(def.ep) do
    local key, mult = MAP[k], 1
    if k == "HitRating" then key, mult = "HITPCT", HIT_PER_PCT
    elseif k == "CritRating" then key, mult = "CRITPCT", CRIT_PER_PCT end
    if key then w[key] = v * mult / base end
  end
  -- "주문력"(피해와 치유 모두) 능력치는 주문 공격력과 치유량을 둘 다 올린다
  if w.SD or w.HEAL then w.SP = (w.SD or 0) + (w.HEAL or 0) end
  return w
end

-- 기존 추정값에서 시뮬이 다루지 않는 것만 이어받는다: 쌍수 표시, 마법봉 공격력(시뮬에 마법봉 없음, 추정값)
local KEEP = { dualWield = true, DPS_WAND = true }

for classFile, specs in pairs(NS.SimEP) do
  NS.Weights[classFile] = NS.Weights[classFile] or {}
  for specKey, def in pairs(specs) do
    local w = NS.ConvertSimEP(def)
    if w then
      local old = NS.Weights[classFile][specKey] or {}
      for k in pairs(KEEP) do
        if old[k] ~= nil and w[k] == nil then w[k] = old[k] end
      end
      w._source, w._main, w._preset = "sim", MAP[def.main] or def.main, def.preset
      NS.Weights[classFile][specKey] = w
    end
  end
end
