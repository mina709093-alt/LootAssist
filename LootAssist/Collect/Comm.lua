-- 애드온 통신: 같은 애드온을 쓰는 파티원끼리 직업·특성·칸별 현재 장비 점수를 자동으로 주고받는다
-- 전투 중에는 보내지 않고, 전투가 끝나면 보낸다. 채팅창에는 아무것도 표시되지 않는다.
-- 메시지: S|버전|직업|레벨|주특성|부특성   P|칸점수...(주 특성)   Q|칸점수...(부 특성)   R|1 (다시 보내 달라는 요청)
local _, NS = ...

local PREFIX = "LootAssist"
local VERSION = 1
local pending = false
local scheduled = false

local function channel()
  if IsInRaid and IsInRaid() then return nil end
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end

local function send(msg)
  local ch = channel()
  if not ch then return end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
  if msg:sub(1, 1) == "S" and NS.Log then
    NS.Log("commSend", { channel = ch, ok = ok, result = tostring(res), dungeon = (NS.GetLocation() == "DUNGEON") or nil })
  end
  if not ok or (type(res) == "number" and res ~= 0) then
    if NS.Log then NS.Log("commFail", { channel = ch, msg = msg:sub(1, 1), result = tostring(res) }) end
    NS.db.commErrors = NS.db.commErrors or {}
    if #NS.db.commErrors < 20 then
      table.insert(NS.db.commErrors, date("%m-%d %H:%M") .. " " .. ch .. " " .. tostring(res))
    end
  end
end

NS.SendRaw = send

local function encodeScores(specKey)
  local me = NS.GetPlayerInfo()
  local parts = {}
  for cat, loc in pairs(NS.CATEGORY_LOC) do
    local s, why = NS.CurrentSlotScore({ equipLoc = loc }, me.class, specKey)
    if s then parts[#parts + 1] = cat .. ("%.1f"):format(s)
    elseif why == "TWOHAND" then parts[#parts + 1] = cat .. "x" end
  end
  return table.concat(parts, ",")
end

function NS.BroadcastMe()
  if not channel() then return end
  if InCombatLockdown() then pending = true; return end
  pending = false
  local me = NS.GetPlayerInfo()
  local p, s = NS.GetActiveSpecs()
  send(("S|%d|%s|%d|%s|%s"):format(VERSION, me.class or "?", me.level or 1, p or "-", s or "-"))
  if p then send("P|" .. encodeScores(p)) end
  if s then send("Q|" .. encodeScores(s)) end
end

-- 여러 이벤트가 몰려도 2초에 한 번만 보낸다
function NS.QueueBroadcast()
  if scheduled then return end
  scheduled = true
  C_Timer.After(2, function()
    scheduled = false
    NS.Safe(NS.BroadcastMe)
  end)
end

function NS.RequestPartyInfo()
  if not channel() or InCombatLockdown() then return end
  send("R|1")
  NS.QueueBroadcast()
end

local function onMessage(msg, sender)
  local name = NS.ShortName(sender)
  if not name or name == UnitName("player") then return end
  local kind, rest = msg:match("^(%u)|(.*)$")
  if not kind then return end
  local c = NS.PartyComm[name]
  if kind == "S" then
    local ver, cls, lvl, p, s = rest:match("^(%d+)|(%u+)|(%d+)|([^|]*)|([^|]*)$")
    if not ver then return end
    c = c or {}
    if c.primary ~= p or c.secondary ~= s then c.scores = nil end
    c.version, c.class, c.level = tonumber(ver), cls, tonumber(lvl)
    c.primary = (p ~= "-" and p ~= "") and p or nil
    c.secondary = (s ~= "-" and s ~= "") and s or nil
    c.time = GetTime()
    NS.PartyComm[name] = c
    if NS.Log then NS.Log("commRecv", { from = name, class = cls, level = tonumber(lvl), primary = c.primary,
      secondary = c.secondary, combat = InCombatLockdown() or nil, dungeon = (NS.GetLocation() == "DUNGEON") or nil }) end
  elseif (kind == "P" or kind == "Q") and c then
    local t = {}
    for cat, v in rest:gmatch("(%w)([%dx%.%-]+)") do
      t[cat] = (v == "x") and "x" or tonumber(v)
    end
    c.scores = c.scores or {}
    c.scores[kind == "P" and "P" or "S"] = t
  elseif kind == "L" then
    if NS.OnRemoteLog then NS.OnRemoteLog(name, rest) end
    return
  elseif kind == "R" then
    NS.QueueBroadcast()
    return
  else
    return
  end
  NS.Fire("PARTY_CHANGED")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, event, ...)
  if not NS.db then return end
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    C_Timer.After(5, function() NS.Safe(NS.RequestPartyInfo) end)
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, msg, _, sender = ...
    if prefix == PREFIX and type(msg) == "string" and not NS.IsSecret(msg) then
      NS.Safe(onMessage, msg, sender)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then NS.QueueBroadcast() end
  else
    NS.QueueBroadcast()
  end
end)

NS.On("SPEC_CHANGED", function() NS.QueueBroadcast() end)
