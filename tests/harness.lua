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

local function rec(link) return P.items[link] end
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

-- toc 순서로 불러오기 (UI 제외)
local NS = {}
for _, f in ipairs({ "Core/Init.lua", "Data/Classes.lua", "Data/Weights.lua", "Core/Specs.lua", "Data/Dungeons.lua", "Core/Dungeons.lua",
                     "Engine/ItemReader.lua", "Engine/Eligibility.lua", "Engine/PersonalEval.lua" }) do
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
