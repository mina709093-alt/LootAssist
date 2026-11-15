-- 직업 / 특성 / 착용 가능 장비 데이터
-- 숙련 표: 클래식 기준 + LootProbe 실측(주술사·마법사·전사 일치 확인, 2026-11-15)
-- 숫자 = 습득 가능 레벨 (실제 습득 여부는 확인하지 않고, 이 레벨 이상이면 보유로 간주)
local _, NS = ...

NS.ROLE_LABEL = {
  TANK = "탱커",
  HEALER = "힐러",
  CASTER = "캐스터 딜러",
  MELEE = "근접 딜러",
  RANGED = "원거리 딜러",
}

NS.DUAL_SPEC_LEVEL = 40

local ALL1 = 1

NS.Classes = {
  WARRIOR = {
    specs = {
      { key = "ARMS", name = "무기", role = "MELEE" },
      { key = "FURY", name = "분노", role = "MELEE" },
      { key = "PROTECTION", name = "방어", role = "TANK" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1, MAIL = ALL1, PLATE = 40, SHIELD = ALL1 },
    weapons = { SWORD1H = 1, SWORD2H = 1, AXE1H = 1, AXE2H = 1, MACE1H = 1, MACE2H = 1, DAGGER = 1,
                FIST = 1, POLEARM = 1, STAFF = 1, BOW = 1, CROSSBOW = 1, GUN = 1, THROWN = 1 },
  },
  PALADIN = {
    specs = {
      { key = "HOLY", name = "신성", role = "HEALER" },
      { key = "PROTECTION", name = "보호", role = "TANK" },
      { key = "RETRIBUTION", name = "징벌", role = "MELEE" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1, MAIL = ALL1, PLATE = 40, SHIELD = ALL1 },
    weapons = { SWORD1H = 1, SWORD2H = 1, AXE1H = 1, AXE2H = 1, MACE1H = 1, MACE2H = 1, POLEARM = 1 },
  },
  HUNTER = {
    specs = {
      { key = "BEASTMASTERY", name = "야수", role = "RANGED" },
      { key = "MARKSMANSHIP", name = "사격", role = "RANGED" },
      { key = "SURVIVAL", name = "생존", role = "RANGED" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1, MAIL = 40 },
    weapons = { SWORD1H = 1, SWORD2H = 1, AXE1H = 1, AXE2H = 1, DAGGER = 1, FIST = 1, POLEARM = 1,
                STAFF = 1, BOW = 1, CROSSBOW = 1, GUN = 1, THROWN = 1 },
  },
  ROGUE = {
    specs = {
      { key = "ASSASSINATION", name = "암살", role = "MELEE" },
      { key = "COMBAT", name = "전투", role = "MELEE" },
      { key = "SUBTLETY", name = "잠행", role = "MELEE" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1 },
    weapons = { SWORD1H = 1, MACE1H = 1, DAGGER = 1, FIST = 1, BOW = 1, CROSSBOW = 1, GUN = 1, THROWN = 1 },
  },
  PRIEST = {
    specs = {
      { key = "DISCIPLINE", name = "수양", role = "HEALER" },
      { key = "HOLY", name = "신성", role = "HEALER" },
      { key = "SHADOW", name = "암흑", role = "CASTER" },
    },
    armor = { CLOTH = ALL1 },
    weapons = { MACE1H = 1, DAGGER = 1, STAFF = 1, WAND = 1 },
  },
  SHAMAN = {
    specs = {
      { key = "ELEMENTAL", name = "정기", role = "CASTER" },
      { key = "ENHANCEMENT", name = "고양", role = "MELEE" },
      { key = "RESTORATION", name = "복원", role = "HEALER" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1, MAIL = 40, SHIELD = ALL1 },
    weapons = { AXE1H = 1, AXE2H = 1, MACE1H = 1, MACE2H = 1, DAGGER = 1, FIST = 1, STAFF = 1 },
  },
  MAGE = {
    specs = {
      { key = "ARCANE", name = "비전", role = "CASTER" },
      { key = "FIRE", name = "화염", role = "CASTER" },
      { key = "FROST", name = "냉기", role = "CASTER" },
    },
    armor = { CLOTH = ALL1 },
    weapons = { SWORD1H = 1, DAGGER = 1, STAFF = 1, WAND = 1 },
  },
  WARLOCK = {
    specs = {
      { key = "AFFLICTION", name = "고통", role = "CASTER" },
      { key = "DEMONOLOGY", name = "악마", role = "CASTER" },
      { key = "DESTRUCTION", name = "파괴", role = "CASTER" },
    },
    armor = { CLOTH = ALL1 },
    weapons = { SWORD1H = 1, DAGGER = 1, STAFF = 1, WAND = 1 },
  },
  DRUID = {
    specs = {
      { key = "BALANCE", name = "조화", role = "CASTER" },
      { key = "FERAL_BEAR", name = "야성(곰)", role = "TANK" },
      { key = "FERAL_CAT", name = "야성(표범)", role = "MELEE" },
      { key = "RESTORATION", name = "회복", role = "HEALER" },
    },
    armor = { CLOTH = ALL1, LEATHER = ALL1 },
    weapons = { MACE1H = 1, MACE2H = 1, DAGGER = 1, FIST = 1, STAFF = 1 },
  },
}

function NS.GetClassData(classFile)
  return NS.Classes[classFile or ""]
end

function NS.GetSpec(classFile, specKey)
  local c = NS.Classes[classFile or ""]
  if not c or not specKey then return nil end
  for _, s in ipairs(c.specs) do
    if s.key == specKey then return s end
  end
  return nil
end
