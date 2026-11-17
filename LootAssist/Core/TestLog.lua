-- 테스트 기록: 플레이하는 동안 판정과 통신 결과를 저장 파일(LootAssistDB.log)에 남긴다.
-- 파티원(같은 애드온 사용)의 판정 요약도 파티 통신으로 받아 내 기록에 함께 쌓는다.
-- 그래서 한 사람의 저장 파일만 있으면 파티 전체 판정을 확인할 수 있다.
local _, NS = ...

local MAX_ENTRIES = 600
local storeMyRoll -- 아래 "수집" 부분에서 정의

local function plain(s)
  if type(s) ~= "string" then return s end
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
NS.Plain = plain

function NS.Log(kind, data)
  if not NS.db or NS.db.testLog == false then return end
  local log = NS.db.log
  if type(log) ~= "table" then log = {}; NS.db.log = log end
  data = data or {}
  data.t = date("%m-%d %H:%M:%S")
  data.k = kind
  log[#log + 1] = data
  while #log > MAX_ENTRIES do table.remove(log, 1) end
end

local function itemIDOf(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- 주사위 판정 기록 (RollWatch 에서 호출)
function NS.LogRoll(link, r)
  local _, placeName, instanceID = NS.GetLocation()
  local p = r.personal or {}
  local entry = {
    item = itemIDOf(link), name = link and link:match("%[(.-)%]"),
    place = placeName, instance = instanceID, boss = NS.lastEncounter,
    combat = InCombatLockdown() or nil,
    final = r.final, personal = p.verdict,
    fitP = p.fitP and tonumber(("%.2f"):format(p.fitP)), gainP = p.gainP and tonumber(("%.2f"):format(p.gainP)),
    Nme = r.Nme and tonumber(("%.2f"):format(r.Nme)), Nrival = r.Nrival and tonumber(("%.2f"):format(r.Nrival)),
    reasons = {},
    rivals = {},
  }
  for i = 1, math.min(#r.reasons, 4) do entry.reasons[i] = plain(r.reasons[i]) end
  for i, rv in ipairs(r.rivals or {}) do
    local info = rv.info or {}
    entry.rivals[i] = ("%s %s %s N=%.2f spec:%s gear:%s"):format(
      rv.member.name or "?", rv.member.class or "?",
      (rv.spec and rv.spec.key) or "-", rv.N or 0,
      info.specSource or "미확인", info.gearSource or "미확인")
  end
  NS.Log("roll", entry)
  entry.t = entry.t or date("%m-%d %H:%M:%S")
  storeMyRoll(entry)
  NS.KickSync()
end

---------------------------------------------------------------------------
-- 수집 (모으는 사람 = 수집자)
-- 모든 사람은 자기 주사위 판정을 번호(seq)를 붙여 db.myRolls 에 보관한다.
-- 수집자(/전리품 수집 으로 켠 사람)와 파티가 되면, 수집자가 "어디까지 받았는지"(A)를 알려 주고
-- 각자 그 뒤의 판정(H)을 1.5초에 하나씩, 전투가 아닐 때만 보낸다.
-- 그래서 수집자가 없을 때 친구들끼리 플레이한 판정도 나중에 수집자 파일로 모인다.
-- 메시지: A|대상이름|받은마지막번호    H|번호|시각|아이템|최종|개인|N나|N파티|경쟁자|장소|보스|이유
---------------------------------------------------------------------------
local MAX_MY_ROLLS = 1500

local function cutBytes(str, max)
  str = tostring(str or ""):gsub("|", "/")
  if #str <= max then return str end
  local out = ""
  for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #out + #ch > max then break end
    out = out .. ch
  end
  return out
end

storeMyRoll = function(entry)
  local db = NS.db
  db.myRolls = db.myRolls or {}
  db.mySeq = (db.mySeq or 0) + 1
  local top = entry.rivals[1] and entry.rivals[1]:match("^(%S+)") or "-"
  db.myRolls[#db.myRolls + 1] = {
    seq = db.mySeq, t = entry.t, item = entry.item, final = entry.final, personal = entry.personal,
    Nme = entry.Nme, Nrival = entry.Nrival, top = top, place = entry.place, boss = entry.boss,
    reason = entry.reasons[1],
  }
  while #db.myRolls > MAX_MY_ROLLS do table.remove(db.myRolls, 1) end
end

-- 보내는 쪽 -------------------------------------------------------------
local cursor = nil      -- 수집자가 받은 마지막 번호
local collectorName = nil
local ticker = nil

local function collectorInParty()
  if not collectorName then return false end
  for _, m in ipairs(NS.Party) do if m.name == collectorName then return true end end
  return false
end

local function nextToSend()
  for _, e in ipairs(NS.db.myRolls or {}) do
    if e.seq > (cursor or 0) then return e end
  end
end

local function encodeH(e)
  local head = ("H|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|"):format(e.seq, cutBytes(e.t, 14), e.item or 0, e.final or "-",
    e.personal or "-", e.Nme or "-", e.Nrival or "-", cutBytes(e.top, 30), cutBytes(e.place, 36), cutBytes(e.boss, 36))
  return head .. cutBytes(e.reason, 250 - #head)
end

local function tick()
  if not collectorInParty() or not NS.SendRaw then
    if ticker then ticker:Cancel(); ticker = nil end
    return
  end
  if InCombatLockdown() then return end
  local e = nextToSend()
  if not e then
    if ticker then ticker:Cancel(); ticker = nil end
    return
  end
  NS.SendRaw(encodeH(e))
  cursor = e.seq
end

function NS.KickSync()
  if ticker or not cursor or not collectorInParty() then return end
  if not nextToSend() then return end
  if C_Timer.NewTicker then ticker = C_Timer.NewTicker(1.5, function() NS.Safe(tick) end) end
end

function NS.OnAck(sender, rest)
  local target, seq = rest:match("^([^|]+)|(%d+)$")
  if not target or target ~= UnitName("player") then return end
  collectorName = sender
  seq = tonumber(seq)
  if not cursor or seq > cursor or not ticker then cursor = seq end
  NS.KickSync()
end

-- 받는 쪽 (수집자) ------------------------------------------------------
function NS.SendAck(memberName)
  if not NS.db.collector or not NS.SendRaw then return end
  local got = NS.db.collectedSeq and NS.db.collectedSeq[memberName] or 0
  NS.SendRaw(("A|%s|%d"):format(memberName, got))
end

function NS.OnHistory(sender, rest)
  if not NS.db.collector then return end
  local seq, t, item, final, personal, nme, nrival, top, place, boss, reason =
    rest:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
  if not seq then return end
  seq = tonumber(seq)
  local db = NS.db
  db.collected = db.collected or {}
  db.collectedSeq = db.collectedSeq or {}
  if seq <= (db.collectedSeq[sender] or 0) then return end
  db.collected[sender] = db.collected[sender] or {}
  local m
  for _, pm in ipairs(NS.Party) do if pm.name == sender then m = pm end end
  table.insert(db.collected[sender], {
    seq = seq, t = t, item = tonumber(item), final = final, personal = personal,
    Nme = tonumber(nme), Nrival = tonumber(nrival), top = top, place = place, boss = boss, reason = reason,
    class = m and m.class, level = m and m.level,
  })
  db.collectedSeq[sender] = seq
end

-- 예전 0.4.1 판정 요약(L) 메시지는 무시한다
function NS.OnRemoteLog() end

---------------------------------------------------------------------------
-- 그 밖의 기록: 접속 정보, 보스, 파티 구성, 획득 메시지
---------------------------------------------------------------------------
local function logSession()
  local me = NS.GetPlayerInfo()
  local p, s = NS.GetActiveSpecs()
  local build = { GetBuildInfo() }
  NS.Log("session", { version = NS.VERSION, build = build[1] .. "." .. tostring(build[2]),
                      name = me.name, class = me.class, level = me.level, primary = p, secondary = s })
end

local function logParty()
  local list = {}
  for _, m in ipairs(NS.Party) do
    local info = NS.MemberInfo(m)
    list[#list + 1] = ("%s %s %d spec:%s(%s) gear:%s"):format(m.name or "?", m.class or "?", m.level or 0,
      info.primary or "-", info.specSource or "미확인", info.gearSource or "미확인")
  end
  NS.Log("party", { members = list })
end

local partyLogPending = false
NS.On("PARTY_CHANGED", function()
  if partyLogPending then return end
  partyLogPending = true
  C_Timer.After(10, function() partyLogPending = false; NS.Safe(logParty) end)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(_, event, ...)
  if not NS.db then return end
  if event == "PLAYER_LOGIN" then
    C_Timer.After(8, function() NS.Safe(logSession) end)
  elseif event == "ENCOUNTER_END" then
    local encounterID, encounterName, _, _, success = ...
    if not NS.IsSecret(encounterName) then
      NS.lastEncounter = encounterName
      NS.Log("boss", { id = encounterID, name = encounterName, kill = (success == 1) or nil })
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    NS.Safe(NS.KickSync)
  elseif event == "CHAT_MSG_LOOT" then
    local text = ...
    if NS.GetLocation() == "DUNGEON" and type(text) == "string" and not NS.IsSecret(text) then
      NS.Log("lootMsg", { text = plain(text) })
    end
  end
end)
