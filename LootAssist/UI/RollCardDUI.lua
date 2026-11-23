-- 주사위 창 강조 (DaylightUI 카드): DaylightUI 의 자체 주사위 카드에도 추천 글자와 버튼 테두리를 덧붙인다
-- DaylightUI 공개 API 1.13 이상(kind "rollcard")만 쓴다. DaylightUI 파일과 카드 부품은 건드리지 않고,
-- API.Attach 가 주는 덮개 프레임 위에만 그린다. 버튼 클릭은 건드리지 않고, 대신 누르지도 않는다.
-- DaylightUI 가 없거나 버전이 낮으면 조용히 건너뛴다. 설정은 게임 창 강조와 같다(LootAssistDB.rollHighlight).
local _, NS = ...

-- 추천 → 카드 버튼 이름 (입찰 = need, 차비 = greed, 양보 = pass)
NS.CARD_BUTTON = {
  BID_STRONG = "need",
  BID = "need",
  GREED = "greed",
  YIELD = "pass",
  YIELD_MAYBE = "pass",
}
local STRONG = { BID_STRONG = true, YIELD = true }

local API
local deco = setmetatable({}, { __mode = "k" }) -- [카드] = 덧붙인 글자·테두리

local function enabled() return NS.db and NS.db.rollHighlight ~= false end

local function hexColor(hex)
  local r, g, b = (hex or "ffffff"):match("^(%x%x)(%x%x)(%x%x)$")
  if not r then return 1, 1, 1 end
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- 버튼을 둘러싸는 2px 테두리 (덮개 프레임 위, 마우스는 받지 않음)
local function makeRing(holder)
  local ring = CreateFrame("Frame", nil, holder)
  ring:EnableMouse(false)
  ring.edges = {}
  for i = 1, 4 do ring.edges[i] = ring:CreateTexture(nil, "OVERLAY") end
  local e = ring.edges
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(2)
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(2)
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(2)
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(2)
  local ag = ring.CreateAnimationGroup and ring:CreateAnimationGroup()
  if ag then
    local fade = ag:CreateAnimation("Alpha")
    if fade then
      fade:SetFromAlpha(1)
      fade:SetToAlpha(0.35)
      fade:SetDuration(0.6)
    end
    ag:SetLooping("BOUNCE")
  end
  ring.anim = ag
  ring:Hide()
  return ring
end

local function ensureDeco(card)
  local d = deco[card]
  if d then return d end
  local holder = API.Attach(card)
  if not holder then return nil end
  d = { holder = holder }
  d.text = NS.MakeText(holder, 11)
  d.text:SetJustifyH("RIGHT")
  d.text:Hide()
  d.ring = makeRing(holder)
  deco[card] = d
  return d
end

local function clear(card)
  local d = deco[card]
  if not d then return end
  d.text:Hide()
  if d.ring.anim then d.ring.anim:Stop() end
  d.ring:Hide()
  d.rollID = nil
end

-- 카드 하나를 그린다. info 가 없으면(첫 호출) rollID 로 판단한다
local function paintCard(card, parts, info, rollID)
  if type(info) == "table" then
    if info.sample then clear(card); return end
    rollID = info.rollID
  end
  if rollID == nil or NS.IsSecret(rollID) then clear(card); return end
  local a = NS.rollAdvice[rollID]
  if not enabled() or not a or (type(info) == "table" and info.done) then clear(card); return end
  local d = ensureDeco(card)
  if not d then return end
  d.rollID = rollID
  parts = type(parts) == "table" and parts or {}

  -- 추천 글자: 아이템 종류 줄(sub) 오른쪽 끝. sub 가 없으면 카드 오른쪽 위
  d.text:ClearAllPoints()
  if type(parts.sub) == "table" and parts.sub.GetObjectType then
    d.text:SetPoint("RIGHT", parts.sub, "RIGHT", 0, 0)
  else
    d.text:SetPoint("TOPRIGHT", d.holder, "TOPRIGHT", -8, -8)
  end
  d.text:SetText("추천: " .. a.colored)
  d.text:Show()

  -- 버튼 테두리: 아직 고르지 않았고, 그 버튼이 보일 때만
  local ring = d.ring
  if ring.anim then ring.anim:Stop() end
  ring:Hide()
  local kind = NS.CARD_BUTTON[a.final]
  local buttons = type(parts.buttons) == "table" and parts.buttons or {}
  local b = kind and buttons[kind]
  local picked = type(info) == "table" and info.mine ~= nil
  if type(b) == "table" and b.IsShown and b:IsShown() and not picked then
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    local r, g, bl = hexColor(a.color)
    for _, e in ipairs(ring.edges) do e:SetColorTexture(r, g, bl, 1) end
    ring:SetAlpha(STRONG[a.final] and 1 or 0.8)
    ring:Show()
    if ring.anim and STRONG[a.final] then ring.anim:Play() end
  end
end

-- RollHighlight 의 SetRollAdvice / 켜고 끄기에서 부른다: 보이는 카드를 다시 그린다
function NS.UpdateRollCards(rollID)
  if not API then return end
  if rollID ~= nil then
    local card = API.GetRollCard(rollID)
    if card then paintCard(card, API.Parts and API.Parts(card), nil, rollID) end
    return
  end
  for card, d in pairs(deco) do
    local id = d.rollID
    if id == nil and API.Frames then
      for c, unit in API.Frames("rollcard") do if c == card then id = unit end end
    end
    paintCard(card, API.Parts and API.Parts(card), nil, id)
  end
end

local function setup()
  local DUI = rawget(_G, "DaylightUI")
  local api = type(DUI) == "table" and DUI.API
  if type(api) ~= "table" or api.major ~= 1 or (tonumber(api.minor) or 0) < 13 then return end
  if type(api.For) ~= "function" or type(api.Attach) ~= "function" or type(api.GetRollCard) ~= "function" then return end
  local me = api.For("LootAssist")
  if type(me) ~= "table" or type(me.Paint) ~= "function" then return end
  API = api
  me.Paint("rollcard", function(card, parts, info)
    NS.Safe(paintCard, card, parts, info, nil)
  end)
  if type(api.On) == "function" then
    api.On("FrameRemoved", function(kind, frame)
      if kind == "rollcard" then NS.Safe(clear, frame) end
    end, "LootAssist")
  end
  NS.duiCards = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() NS.Safe(setup) end)
