-- 게임 밖에서 LootAssist 엔진을 실측 데이터로 돌려 보는 테스트 (texlua)
local ADDON_DIR = "../LootAssist/"
local DATA = dofile("probe_data.lua")
local who, spec1, spec2, level = arg[1] or "A", arg[2], arg[3], tonumber(arg[4])

-- 최소 WoW API 흉내
local noop = function() end
local stub = setmetatable({}, { __index = function() return noop end })
function CreateFrame() return setmetatable({}, { __index = function() return noop end }) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print((m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
C_Timer = { After = noop, NewTicker = noop }
GetTime = function() return 0 end
date = os.date
local P = DATA[who]
local CLASS_KO = { SHAMAN = "주술사", MAGE = "마법사", WARRIOR = "전사" }
UnitClass = function() return CLASS_KO[P.class], P.class end
UnitLevel = function() return level or P.level end
UnitName = function() return "테스트" end
GetRealmName = function() return "학살자" end
GetInstanceInfo = function() return "통곡의 동굴", "party", 1, "", 5, 0, false, 43 end
GetInventoryItemLink = function(_, slot) return P.equipped[slot] end
local equippedSet = {}
for _, l in pairs(P.equipped) do equippedSet[l] = true end

local function rec(link) return P.items[link] or (DATA.A.items[link]) or (DATA.B.items[link]) end
C_Item = {
  GetItemInfoInstant = function(link) local r = rec(link); if not r then return nil end local v = r.instant
    return v[1], v[2], v[3], v[4], v[5], v[6], v[7] end,
  GetItemInfo = function(link) local r = rec(link); if not r then return nil end local v = r.info
    return v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14] end,
  GetItemStats = function(link) local r = rec(link); return r and r.stats or {} end,
  IsEquippedItem = function(link) return equippedSet[link] or false end,
  RequestLoadItemDataByID = noop,
}
C_TooltipInfo = { GetHyperlink = function(link) local r = rec(link); if not r then return nil end
  local lines = {}; for i = 1, 40 do if r.tip[i] then lines[#lines + 1] = { leftText = r.tip[i] } end end
  return { lines = lines } end }
SLASH_LOOTASSIST1 = nil; SlashCmdList = {}
wipe = function(t) for k in pairs(t) do t[k] = nil end end
hooksecurefunc = noop
UnitExists = function() return false end
InCombatLockdown = function() return false end
GetBuildInfo = function() return "1.60.1", "70938" end

-- toc 순서로 불러오기 (UI 제외)
local NS = {}
for _, f in ipairs({ "Core/Init.lua", "Data/Classes.lua", "Data/Weights.lua", "Core/Specs.lua", "Data/Dungeons.lua", "Core/Dungeons.lua",
                     "Engine/ItemReader.lua", "Engine/Eligibility.lua", "Engine/PersonalEval.lua", "Collect/Party.lua", "Engine/PartyEval.lua", "Engine/Advisor.lua", "Core/TestLog.lua" }) do
  local chunk = assert(loadfile(ADDON_DIR .. f))
  chunk("LootAssist", NS)
end
NS.db = { chars = {}, minimap = {}, window = {} }
NS.Char().primary = spec1
NS.Char().secondary = spec2

print(("== %s %s %d레벨, 주 %s / 부 %s"):format(who, P.class, UnitLevel(), tostring(spec1), tostring(spec2)))
for i, link in pairs(P.rolls) do
  local r = NS.EvaluateForMe(link, { ignoreEquipped = true })
  local name = link:match("%[(.-)%]")
  print(("%2d %-28s %-22s %s"):format(i, name, r.label, table.concat(r.reasons, " / ")))
end
if #NS.errors > 0 then print("ERRORS:"); for _, e in ipairs(NS.errors) do print(e) end end
if arg[5] then
  for i, link in pairs(P.rolls) do
    local r = NS.EvaluateForMe(link, { ignoreEquipped = true })
    if r.item then
      local max = NS.MaxSpecScore(r.item)
      local best, bestName = 0, ""
      for cf, c in pairs(NS.Classes) do for _, s in ipairs(c.specs) do
        if NS.CheckEligibility(r.item, cf, 60).ok then local v = NS.SpecScore(r.item, cf, s.key); if v and v >= best then best, bestName = v, cf .. "/" .. s.key end end end end
      local st = {}; for k, v in pairs(r.item.stats) do st[#st + 1] = k .. "=" .. v end
      print(("%2d fitP=%.2f gainP=%s max=%.1f(%s) [%s] dps=%.1f"):format(i, r.fitP or -1, tostring(r.gainP), max, bestName, table.concat(st, ","), r.item.dps))
    end
  end
end

-- 파티 시나리오: texlua harness.lua B FIRE nil 25 party
if arg[5] == "party" or arg[5] == "party2" then
  local A = DATA.A
  GetInstanceInfo = function() return "통곡의 동굴", "party", 1, "", 5, 0, false, 43 end
  NS.Party = {
    { unit = "party1", guid = "G-SHAMAN", name = "왕만두", class = "SHAMAN", className = "주술사", level = 27 },
    { unit = "party2", guid = "G-PRIEST", name = "마라탕", class = "PRIEST", className = "사제", level = 26 },
    { unit = "party3", guid = "G-WARRIOR", name = "돼지껍데기", class = "WARRIOR", className = "전사", level = 25 },
    { unit = "party4", guid = "G-ROGUE", name = "스무디", class = "ROGUE", className = "도적", level = 25 },
  }
  -- 주술사: 자동 공유(정기) + 장비는 살펴보기 결과(실측 장비)
  NS.PartyComm["왕만두"] = { class = "SHAMAN", primary = "ELEMENTAL", level = 27 }
  NS.PartyInspect["G-SHAMAN"] = { links = A.equipped }
  -- 사제: 직접 설정(신성), 장비 미확인
  NS.ManualFor("마라탕").primary = "HOLY"
  -- 전사: 특성 미확인, 장비 미확인 / 도적: 직접 설정(전투)
  NS.ManualFor("스무디").primary = "COMBAT"
  if arg[5] == "party2" then
    -- 나 = 주술사 A, 첫 파티원을 마법사 B(화염, 살펴보기 장비)로 교체
    NS.Party[1] = { unit = "party1", guid = "G-MAGE", name = "스무디마법", class = "MAGE", className = "마법사", level = 25 }
    NS.PartyComm["스무디마법"] = { class = "MAGE", primary = "FIRE", level = 25 }
    NS.PartyInspect["G-MAGE"] = { links = DATA.B.equipped }
  end
  print("== 파티 판정 (나: 마법사 화염 25)")
  local seen = {}
  for _, who in ipairs({ "A", "B" }) do
    for _, link in pairs(DATA[who].rolls) do
      if not seen[link] then
        seen[link] = true
        local r = NS.Advise(link)
        if r.final ~= "NOT_GEAR" then
          local name = link:match("%[(.-)%]")
          local plain = function(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
          print(("%-26s %-14s %s"):format(name, r.label, plain(table.concat(r.reasons, " / "))))
        end
      end
    end
  end
  if #NS.errors > 0 then print("ERRORS:"); for _, e in ipairs(NS.errors) do print(e) end end
end

if arg[5] == "log" then
  NS.Party = { { unit = "party1", guid = "G1", name = "왕만두", class = "SHAMAN", className = "주술사", level = 27 } }
  local sent = {}
  NS.SendRaw = function(m) sent[#sent + 1] = m end
  local link = P.rolls[22] or P.rolls[1]
  local r = NS.Advise(link)
  NS.LogRoll(link, r)
  print("보낸 메시지:", sent[1])
  -- 친구 쪽에서 같은 메시지를 받았다고 가정
  NS.OnRemoteLog("왕만두", sent[1]:match("^L|(.*)$"))
  for i, e in ipairs(NS.db.log) do
    local parts = {}
    for k, v in pairs(e) do if type(v) ~= "table" then parts[#parts + 1] = k .. "=" .. tostring(v) end end
    table.sort(parts)
    print(i, table.concat(parts, " "))
    if e.reasons then print("   reasons:", table.concat(e.reasons, " | ")) end
    if e.rivals then print("   rivals:", table.concat(e.rivals, " | ")) end
  end
end
