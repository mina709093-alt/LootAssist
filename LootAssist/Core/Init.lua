-- 전리품 도우미 (LootAssist) - 코어
local ADDON, NS = ...
NS.VERSION = "0.2.2"
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
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
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
  elseif cmd == "minimap" then
    NS.db.minimap.hide = not NS.db.minimap.hide
    NS.Safe(NS.UpdateMinimapButton)
    NS.Print("미니맵 버튼 " .. (NS.db.minimap.hide and "숨김" or "표시"))
  else
    NS.Print("/전리품 - 창 열기/닫기")
    NS.Print("/전리품 던전 - 현재 던전의 보스별 전리품 데이터 보기")
    NS.Print("/전리품 minimap - 미니맵 버튼 숨기기/보이기")
    NS.Print("/전리품 errors - 오류 기록 보기")
  end
end
