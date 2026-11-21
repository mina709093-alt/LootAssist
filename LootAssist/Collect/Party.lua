-- 파티 구성: 파티원 목록 + 특성/장비 정보 출처(자동 공유 > 살펴보기 > 직접 설정 > 미확인)
local _, NS = ...

NS.Party = {}          -- 현재 파티원 { unit, guid, name, class, className, level }
NS.PartyComm = {}      -- [이름] = 애드온 통신으로 받은 정보
NS.PartyInspect = {}   -- [guid] = { links = { [slot] = link }, time }

function NS.ShortName(n)
  if type(n) ~= "string" then return nil end
  return n:match("^([^%-%s]+)")
end

-- 장비 칸 종류 코드 (통신으로 칸별 현재 점수를 주고받을 때 사용)
NS.CATEGORY_LOC = {
  H = "INVTYPE_HEAD", N = "INVTYPE_NECK", S = "INVTYPE_SHOULDER", C = "INVTYPE_CHEST",
  W = "INVTYPE_WAIST", L = "INVTYPE_LEGS", F = "INVTYPE_FEET", R = "INVTYPE_WRIST",
  G = "INVTYPE_HAND", K = "INVTYPE_FINGER", T = "INVTYPE_TRINKET", B = "INVTYPE_CLOAK",
  ["1"] = "INVTYPE_WEAPON", ["2"] = "INVTYPE_2HWEAPON", M = "INVTYPE_WEAPONMAINHAND",
  O = "INVTYPE_SHIELD", D = "INVTYPE_RANGED",
}
local LOC_CATEGORY = {
  INVTYPE_ROBE = "C", INVTYPE_WEAPONOFFHAND = "O", INVTYPE_HOLDABLE = "O",
  INVTYPE_RANGEDRIGHT = "D", INVTYPE_THROWN = "D", INVTYPE_RELIC = "D",
}
for cat, loc in pairs(NS.CATEGORY_LOC) do LOC_CATEGORY[loc] = cat end
function NS.LocCategory(loc) return LOC_CATEGORY[loc or ""] end

function NS.RefreshRoster()
  local old = {}
  for _, m in ipairs(NS.Party) do old[m.name or ""] = true end
  wipe(NS.Party)
  local newcomer = false
  if IsInRaid and IsInRaid() then return false end
  for i = 1, 4 do
    local u = "party" .. i
    if UnitExists(u) then
      local name = UnitName(u)
      local className, classFile = UnitClass(u)
      if name and classFile then
        NS.Party[#NS.Party + 1] = { unit = u, guid = UnitGUID(u), name = name, class = classFile,
                                    className = className, level = UnitLevel(u) or 1 }
        if not old[name] then newcomer = true end
      end
    end
  end
  return newcomer
end

-- 직접 설정값 (파티원 이름별로 저장 = 같은 친구와 다시 만나면 그대로 사용)
function NS.ManualFor(name)
  NS.db.partyManual = NS.db.partyManual or {}
  local m = NS.db.partyManual[name or "?"]
  if not m then m = {}; NS.db.partyManual[name or "?"] = m end
  return m
end

-- 파티원 한 명의 특성/장비 정보 종합
function NS.MemberInfo(member)
  local info = { member = member }
  local c = NS.PartyComm[member.name]
  if c and c.class == member.class and c.primary then
    info.primary, info.secondary, info.specSource = c.primary, c.secondary, "comm"
  else
    local m = NS.ManualFor(member.name)
    if m.primary and NS.GetSpec(member.class, m.primary) then
      info.primary, info.specSource = m.primary, "manual"
      if m.secondary and m.secondary ~= m.primary and NS.GetSpec(member.class, m.secondary) then
        info.secondary = m.secondary
      end
    end
  end
  if info.secondary and (member.level or 1) < NS.DUAL_SPEC_LEVEL then info.secondary = nil end

  if c and c.class == member.class and c.scores and (c.scores.P or c.scores.S) then
    info.gearSource, info.commScores, info.commSlots = "comm", c.scores, c.slots
  elseif member.guid and NS.PartyInspect[member.guid] then
    info.gearSource, info.inspectLinks = "inspect", NS.PartyInspect[member.guid].links
  end
  return info
end

-- 반지·장신구: 통신으로 받은 칸별 아이템/점수가 두 칸 모두 있으면 칸별 교체 시나리오로 계산 (버전 2 이상)
local PAIR_SLOTS = { INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 } }
local function commPair(info, item, which)
  local slots = PAIR_SLOTS[item.equipLoc or ""]
  local t = slots and info.commSlots and info.commSlots[which]
  if not t then return nil end
  local equipped = {}
  for i, slot in ipairs(slots) do
    local e = t[slot]
    if not e then return nil end
    equipped[i] = e.empty and false or { itemID = e.id, s = e.s }
  end
  local best, plan = NS.PairOptions(item, slots, equipped, function(e) return e and e.s or 0 end)
  if not best then return nil, "UNIQUE" end
  return best.cur, nil, best.filled, plan
end

-- 파티원의 같은 칸 현재 장비 점수
function NS.MemberCurrentScore(info, item, specKey)
  if info.gearSource == "comm" then
    local which = (specKey == info.primary and "P") or (specKey == info.secondary and "S") or nil
    if which then
      local cur, why, filled, plan = commPair(info, item, which)
      if cur ~= nil or why then return cur, why, filled, plan end
    end
    local t = which and info.commScores[which]
    local cat = NS.LocCategory(item.equipLoc)
    if t and cat and t[cat] ~= nil then
      if t[cat] == "x" then return nil, "TWOHAND" end
      return t[cat]
    end
    return nil, "unknown"
  elseif info.gearSource == "inspect" then
    local links = info.inspectLinks
    return NS.CurrentSlotScore(item, info.member.class, specKey, function(slot) return links[slot] end)
  end
  return nil, "unknown"
end

---------------------------------------------------------------------------
-- 살펴보기: 사용자가 직접 살펴보기 한 결과만 읽는다 (애드온이 스스로 NotifyInspect 하지 않음)
---------------------------------------------------------------------------
local lastInspectUnit
if type(NotifyInspect) == "function" and hooksecurefunc then
  hooksecurefunc("NotifyInspect", function(unit) lastInspectUnit = unit end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, arg1)
  if not NS.db then return end
  if event == "INSPECT_READY" then
    NS.Safe(function()
      local unit = lastInspectUnit
      if not unit or UnitGUID(unit) ~= arg1 then return end
      local links, n = {}, 0
      for slot = 1, 18 do
        local link = GetInventoryItemLink(unit, slot)
        if link and not NS.IsSecret(link) then links[slot] = link; n = n + 1 end
      end
      if n > 0 then
        NS.PartyInspect[arg1] = { links = links, time = GetTime() }
        NS.Fire("PARTY_CHANGED")
      end
    end)
  else
    local newcomer = false
    NS.Safe(function() newcomer = NS.RefreshRoster() end)
    if newcomer and NS.RequestPartyInfo then NS.Safe(NS.RequestPartyInfo) end
    NS.Fire("PARTY_CHANGED")
  end
end)
