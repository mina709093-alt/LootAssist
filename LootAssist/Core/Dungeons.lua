-- 던전 데이터 색인: 인스턴스 ID / 아이템 ID 로 빠르게 찾기
local _, NS = ...

NS.STATUS_LABEL = {
  verified = "|cff66dd66검증됨|r",
  beta = "|cffffcc00베타 자료|r",
  unconfirmed = "|cffff6666미확인|r",
}

NS.DungeonsByInstance = {}  -- [instanceID] = { 던전, ... } (붉은십자군 수도원처럼 같은 ID를 쓰는 날개가 있음)
NS.ItemSources = {}         -- [itemID] = { { dungeon = d, boss = b, chance = n }, ... }

local function build()
  for _, d in ipairs(NS.DungeonData or {}) do
    local list = NS.DungeonsByInstance[d.instance]
    if not list then list = {}; NS.DungeonsByInstance[d.instance] = list end
    table.insert(list, d)
    for _, b in ipairs(d.bosses) do
      for _, itemID in ipairs(b.items) do
        local src = NS.ItemSources[itemID]
        if not src then src = {}; NS.ItemSources[itemID] = src end
        table.insert(src, { dungeon = d, boss = b, chance = b.drops and b.drops[itemID] or nil })
      end
    end
  end
end
NS.Safe(build)

function NS.GetDungeonsForInstance(instanceID)
  return NS.DungeonsByInstance[instanceID or -1]
end

function NS.GetCurrentDungeons()
  local kind, name, instanceID = NS.GetLocation()
  if kind ~= "DUNGEON" then return nil, name end
  return NS.GetDungeonsForInstance(instanceID), name
end

function NS.BossDisplayName(b)
  return b.ko or b.name
end

-- 현재 던전 데이터 요약 (창 / 명령어에서 사용)
function NS.DescribeCurrentDungeon()
  local kind, placeName, instanceID = NS.GetLocation()
  if kind ~= "DUNGEON" then return nil end
  local list = NS.GetDungeonsForInstance(instanceID)
  if not list then
    return ("%s: 아직 확인된 드랍 정보가 없습니다."):format(placeName or "?")
  end
  local bosses, items, status = 0, 0, list[1].status
  for _, d in ipairs(list) do
    bosses = bosses + #d.bosses
    for _, b in ipairs(d.bosses) do items = items + #b.items end
    if d.status ~= "verified" then status = d.status end
  end
  return ("던전 데이터: 보스 %d · 아이템 %d (%s)"):format(bosses, items, NS.STATUS_LABEL[status] or status)
end
