-- 전리품 도우미 (LootAssist) - 코어
local ADDON, NS = ...
NS.VERSION = "0.4.3"
NS.TAG = "|cff66ccff[전리품 도우미]|r "

function NS.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(NS.TAG .. tostring(msg))
end

---------------------------------------------------------------------------
-- 오류 격리: 어떤 오류도 기본 게임 플레이를 방해하지 않게 한다
---------------------------------------------------------------------------
NS.errors = {}
function NS.Safe(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    if #NS.errors < 30 then table.insert(NS.errors, date("%H:%M:%S") .. " " .. tostring(err)) end
    if NS.debug then NS.Print("|cffff5555오류:|r " .. tostring(err)) end
  end
  return ok, err
end

---------------------------------------------------------------------------
-- 간단한 내부 이벤트 (특성 변경 시 다른 모듈이 다시 계산하도록)
---------------------------------------------------------------------------
local listeners = {}
function NS.On(name, fn)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], fn)
end
function NS.Fire(name, ...)
  for _, fn in ipairs(listeners[name] or {}) do NS.Safe(fn, ...) end
end

---------------------------------------------------------------------------
-- 저장 데이터
---------------------------------------------------------------------------
local DEFAULTS = {
  dbVersion = 1,
  minimap = { angle = 210, hide = false },
  window = {},
  chars = {},
}

local function copyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function NS.CharKey()
  local name = UnitName("player") or "?"
  local realm = GetRealmName and GetRealmName() or "?"
  return name .. "-" .. realm
end

-- 캐릭터별 설정: primary / secondary = 특성 key (Data/Classes.lua)
function NS.Char()
  local key = NS.CharKey()
  local c = NS.db.chars[key]
  if type(c) ~= "table" then
    c = {}
    NS.db.chars[key] = c
  end
  return c
end

---------------------------------------------------------------------------
-- 내 캐릭터 / 위치 정보
---------------------------------------------------------------------------
NS.levelOverride = nil -- PLAYER_LEVEL_UP 직후 UnitLevel 이 늦게 바뀌는 경우 대비

function NS.GetPlayerInfo()
  local className, classFile = UnitClass("player")
  return {
    name = UnitName("player"),
    class = classFile,
    className = className,
    level = NS.levelOverride or UnitLevel("player") or 1,
  }
end

-- kind: DUNGEON / FIELD / INSTANCE
function NS.GetLocation()
  local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
  if instanceType == "party" then
    return "DUNGEON", name, instanceID
  elseif instanceType == nil or instanceType == "none" then
    local zone = GetZoneText and GetZoneText() or name
    if zone == nil or zone == "" then zone = name end
    return "FIELD", zone, nil
  else
    return "INSTANCE", name, instanceID
  end
end

NS.LOCATION_LABEL = {
  DUNGEON = "|cffff9933던전|r",
  FIELD = "|cff66dd66필드|r",
  INSTANCE = "|cff66aaff기타 인스턴스|r",
}

---------------------------------------------------------------------------
-- 이벤트
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
  local arg1 = ...
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    if type(LootAssistDB) ~= "table" then LootAssistDB = {} end
    copyDefaults(LootAssistDB, DEFAULTS)
    NS.db = LootAssistDB
    self:UnregisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_LEVEL_UP")
  elseif event == "PLAYER_LOGIN" then
    NS.Safe(NS.CreateMainWindow)
    NS.Safe(NS.CreateMinimapButton)
    NS.Safe(NS.ValidateChar)
    NS.Print("불러왔습니다. 미니맵 버튼 또는 |cffffff00/전리품|r 으로 창을 엽니다.")
  elseif event == "PLAYER_LEVEL_UP" then
    NS.levelOverride = tonumber(arg1)
    NS.Safe(NS.ValidateChar)
    NS.Safe(NS.RefreshMainWindow)
    C_Timer.After(2, function() NS.levelOverride = nil end)
  else
    NS.Safe(NS.RefreshMainWindow)
  end
end)

---------------------------------------------------------------------------
-- 명령어
---------------------------------------------------------------------------
SLASH_LOOTASSIST1 = "/lla"
SLASH_LOOTASSIST2 = "/전리품"
SlashCmdList.LOOTASSIST = function(msg)
  msg = msg or ""
  local cmd = (msg:match("^%s*(%S*)") or ""):lower()
  local rest = msg:match("^%s*%S+%s+(.+)$")
  if cmd == "" or cmd == "show" then
    NS.Safe(NS.ToggleMainWindow)
  elseif cmd == "debug" then
    NS.debug = not NS.debug
    NS.Print("디버그 " .. (NS.debug and "켬" or "끔"))
  elseif cmd == "errors" then
    if #NS.errors == 0 then NS.Print("기록된 오류가 없습니다.") end
    for _, e in ipairs(NS.errors) do NS.Print(e) end
  elseif cmd == "dungeon" or cmd == "던전" then
    local desc = NS.DescribeCurrentDungeon and NS.DescribeCurrentDungeon()
    if not desc then
      NS.Print("던전 안에서 사용할 수 있습니다.")
    else
      NS.Print(desc)
      local list = NS.GetCurrentDungeons()
      for _, d in ipairs(list or {}) do
        for i, b in ipairs(d.bosses) do
          NS.Print(("  %d. %s - 아이템 %d개"):format(i, NS.BossDisplayName(b), #b.items))
        end
      end
    end
  elseif cmd == "평가" or cmd == "eval" then
    if not rest then
      NS.Print("사용법: /전리품 평가 [아이템 링크]  (채팅창에 Shift+클릭으로 링크를 넣으세요)")
    else
      local r = NS.Advise(rest)
      NS.Print(rest .. " → " .. r.colored)
      for _, line in ipairs(r.reasons) do NS.Print("  " .. line) end
      local p = r.personal
      if p and p.fitP then
        NS.Print(("  적합도 주 %.2f / 상승 %s"):format(p.fitP, p.gainP and ("%.0f%%"):format(p.gainP * 100) or "?"))
      end
      if r.Nme then NS.Print(("  필요도 나 %.2f / 파티 최대 %.2f"):format(r.Nme, r.Nrival or 0)) end
      NS.lastShare = NS.ShareText(r, rest)
    end
  elseif cmd == "툴팁" or cmd == "tooltip" then
    NS.db.tooltip = (NS.db.tooltip == false)
    NS.Print("툴팁 평가 " .. (NS.db.tooltip and "켬" or "끔"))
  elseif cmd == "채팅" or cmd == "chat" then
    NS.db.rollChat = (NS.db.rollChat == false)
    NS.Print("주사위 판정 채팅 알림 " .. (NS.db.rollChat and "켬" or "끔"))
  elseif cmd == "공유" or cmd == "share" then
    NS.Safe(NS.OpenShareText)
  elseif cmd == "파티" or cmd == "party" then
    if #NS.Party == 0 then NS.Print("파티원이 없습니다.") end
    for _, m in ipairs(NS.Party) do
      local info = NS.MemberInfo(m)
      local ps = NS.GetSpec(m.class, info.primary)
      NS.Print(("%s %s %d - 특성: %s (%s) / 장비: %s"):format(m.name, m.className or m.class, m.level or 0,
        ps and ps.name or "미확인", info.specSource or "없음", info.gearSource or "미확인"))
    end
  elseif cmd == "기록" or cmd == "log" then
    local log = NS.db.log or {}
    local count = {}
    for _, e in ipairs(log) do count[e.k] = (count[e.k] or 0) + 1 end
    NS.Print(("테스트 기록 %d건 - 내 주사위 %d · 보스 %d · 통신 받음 %d · 통신 실패 %d"):format(
      #log, count.roll or 0, count.boss or 0, count.commRecv or 0, count.commFail or 0))
    NS.Print(("내 판정 보관 %d건 (수집자에게 보낼 것)"):format(#(NS.db.myRolls or {})))
    if NS.db.collector then
      NS.Print("|cff66dd66수집 켜짐|r - 친구별로 모은 판정:")
      for who, list in pairs(NS.db.collected or {}) do NS.Print(("  %s: %d건"):format(who, #list)) end
    end
    NS.Print("/reload 또는 로그아웃 후 WTF\\Account\\<계정>\\SavedVariables\\LootAssist.lua 파일을 보내 주세요.")
  elseif cmd == "수집" or cmd == "collect" then
    NS.db.collector = not NS.db.collector
    NS.Print("수집 " .. (NS.db.collector and "|cff66dd66켬|r - 파티원들이 보관한 판정을 받아 모읍니다" or "끔"))
    if NS.db.collector and NS.RequestPartyInfo then NS.Safe(NS.RequestPartyInfo) end
  elseif cmd == "기록지우기" then
    NS.db.log = {}
    NS.Print("테스트 기록을 지웠습니다.")
  elseif cmd == "minimap" then
    NS.db.minimap.hide = not NS.db.minimap.hide
    NS.Safe(NS.UpdateMinimapButton)
    NS.Print("미니맵 버튼 " .. (NS.db.minimap.hide and "숨김" or "표시"))
  else
    NS.Print("/전리품 - 창 열기/닫기")
    NS.Print("/전리품 평가 [아이템 링크] - 내 기준 판정과 이유 보기")
    NS.Print("/전리품 툴팁 - 아이템 툴팁의 판정 표시 켜기/끄기")
    NS.Print("/전리품 채팅 - 주사위가 뜰 때 채팅창 판정 알림 켜기/끄기")
    NS.Print("/전리품 파티 - 파티원 특성/장비 정보 출처 보기")
    NS.Print("/전리품 공유 - 마지막 주사위 판정 문장을 채팅 입력창에 넣기 (보내기는 직접)")
    NS.Print("/전리품 던전 - 현재 던전의 보스별 전리품 데이터 보기")
    NS.Print("/전리품 기록 - 테스트 기록 현황 (/전리품 기록지우기 로 비우기)")
    NS.Print("/전리품 수집 - 이 캐릭터를 수집자로 켜기/끄기 (파티원 판정을 모음)")
    NS.Print("/전리품 minimap - 미니맵 버튼 숨기기/보이기")
    NS.Print("/전리품 errors - 오류 기록 보기")
  end
end
