-- 테스트 기록: 플레이하는 동안 판정과 통신 결과를 저장 파일(LootAssistDB.log)에 남긴다.
-- 파티원(같은 애드온 사용)의 판정 요약도 파티 통신으로 받아 내 기록에 함께 쌓는다.
-- 그래서 한 사람의 저장 파일만 있으면 파티 전체 판정을 확인할 수 있다.
local _, NS = ...

local MAX_ENTRIES = 600

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
  NS.QueueRollShare(entry)
end

---------------------------------------------------------------------------
-- 파티원에게 내 판정 요약 보내기 / 받기 (전투 중에는 모아 두었다가 전투 후 전송)
-- 메시지: L|아이템ID|최종|개인|Nme|Nrival|1순위경쟁자
---------------------------------------------------------------------------
local outbox = {}

function NS.QueueRollShare(entry)
  local top = entry.rivals[1] and entry.rivals[1]:match("^(%S+)") or "-"
  outbox[#outbox + 1] = ("L|%s|%s|%s|%s|%s|%s"):format(
    entry.item or 0, entry.final or "-", entry.personal or "-",
    entry.Nme or "-", entry.Nrival or "-", top)
  NS.FlushOutbox()
end

function NS.FlushOutbox()
  if #outbox == 0 or not NS.SendRaw then return end
  if InCombatLockdown() then return end
  for _, msg in ipairs(outbox) do NS.SendRaw(msg) end
  wipe(outbox)
end

function NS.OnRemoteLog(name, rest)
  local item, final, personal, nme, nrival, top = rest:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
  if not item then return end
  local m
  for _, pm in ipairs(NS.Party) do if pm.name == name then m = pm end end
  NS.Log("friendRoll", {
    from = name, class = m and m.class, level = m and m.level,
    item = tonumber(item), final = final, personal = personal,
    Nme = tonumber(nme), Nrival = tonumber(nrival), top = top,
  })
end

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
    NS.Safe(NS.FlushOutbox)
  elseif event == "CHAT_MSG_LOOT" then
    local text = ...
    if NS.GetLocation() == "DUNGEON" and type(text) == "string" and not NS.IsSecret(text) then
      NS.Log("lootMsg", { text = plain(text) })
    end
  end
end)
