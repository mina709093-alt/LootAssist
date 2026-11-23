-- 주사위 창 강조: 게임 기본 주사위 창(GroupLootFrame1..N)에 최종 추천 글자와 버튼 빛을 덧붙인다
-- 원칙: 버튼은 절대 대신 누르지 않는다. 창을 옮기거나 크기를 바꾸지 않는다(ForeverLootRollMover 등과 충돌 방지).
-- 창이나 버튼을 못 찾으면 조용히 건너뛴다. 설정: LootAssistDB.rollHighlight (없으면 켬, false 면 끔)
local _, NS = ...

NS.rollAdvice = {} -- [rollID] = { final, label, colored, color, reasons }

-- 추천 → 빛을 줄 버튼 (입찰 = Need, 차비 = Greed, 양보 = Pass). 정보 부족/장비 아님은 글자만
NS.ROLL_BUTTON = {
  BID_STRONG = "NeedButton",
  BID = "NeedButton",
  GREED = "GreedButton",
  YIELD = "PassButton",
  YIELD_MAYBE = "PassButton",
}
local STRONG = { BID_STRONG = true, YIELD = true } -- 확실한 추천은 빛이 깜박인다

local deco = setmetatable({}, { __mode = "k" }) -- [주사위 창] = 덧붙인 글자·빛 (게임 창 표에 값을 쓰지 않음)
local hooked = setmetatable({}, { __mode = "k" })

local function enabled() return NS.db and NS.db.rollHighlight ~= false end

local function hexColor(hex)
  local r, g, b = (hex or "ffffff"):match("^(%x%x)(%x%x)(%x%x)$")
  if not r then return 1, 1, 1 end
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function maxFrames()
  local n = rawget(_G, "MAX_LOOT_FRAMES") -- 게임 상수, 없으면 4
  if type(n) ~= "number" or n < 1 or n > 20 then n = 4 end
  return n
end

-- ForeverLootRollMover 와 같은 순서로 버튼을 찾는다
local function getButton(frame, key)
  local container = frame.LootButtonContainer
  local name = frame.GetName and frame:GetName()
  local list = { type(container) == "table" and container[key] or nil, frame[key],
    type(name) == "string" and _G[name .. key] or nil }
  for i = 1, 3 do
    local b = list[i]
    if type(b) == "table" and b.CreateTexture then return b end
  end
  return nil
end

local function rollIDOf(frame)
  local id = frame.rollID
  if id == nil or NS.IsSecret(id) then return nil end
  return id
end

-- 전투 중 보호된 창에는 새 프레임을 붙이지 않는다 (글자·텍스처는 괜찮음)
local function canAttachFrame(frame)
  if not InCombatLockdown() then return true end
  return not (frame.IsProtected and frame:IsProtected())
end

-- 다른 애드온(DaylightUI 주사위 창 등)이 게임 주사위 창을 투명하게 숨겼으면 그리지 않는다.
-- 보이지 않는 창 위에 마우스를 받는 영역이 남아 클릭을 막지 않게 하기 위함
local function hiddenByOther(frame)
  if not frame.GetAlpha then return false end
  local ok, a = pcall(frame.GetAlpha, frame)
  return ok and type(a) == "number" and not NS.IsSecret(a) and a < 0.05
end

local function showTooltip(owner)
  local d = owner.__laDeco
  local frame = d and d.frame
  local id = frame and rollIDOf(frame)
  local a = id and NS.rollAdvice[id]
  if not a or not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:AddLine("전리품 도우미: " .. a.colored)
  for i = 1, math.min(#a.reasons, 3) do GameTooltip:AddLine(a.reasons[i], 0.9, 0.9, 0.9, true) end
  GameTooltip:AddLine("선택은 직접 합니다. 버튼을 대신 누르지 않습니다.", 0.55, 0.60, 0.63, true)
  GameTooltip:Show()
end

local function makeGlow(button)
  local glow = button:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER", button, "CENTER", 0, 0)
  local w, h = button:GetSize()
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if w <= 0 then w = 32 end
  if h <= 0 then h = 32 end
  glow:SetSize(w * 1.9, h * 1.9)
  glow:Hide()
  local ag = glow.CreateAnimationGroup and glow:CreateAnimationGroup()
  if ag then
    local fade = ag:CreateAnimation("Alpha")
    if fade then
      fade:SetFromAlpha(1)
      fade:SetToAlpha(0.35)
      fade:SetDuration(0.6)
    end
    ag:SetLooping("BOUNCE")
  end
  return { tex = glow, anim = ag }
end

local function ensureDeco(frame)
  local d = deco[frame]
  if d then return d end
  d = { frame = frame, glows = {} }
  -- 아이템 이름 아래, 남은 시간 막대 위 (277x67 기본 창 기준)
  d.text = NS.MakeText(frame, 11)
  d.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 60, 11)
  d.text:Hide()
  deco[frame] = d
  return d
end

-- 툴팁용 투명 영역 (글자 위에만, 버튼은 덮지 않음)
local function ensureHit(d)
  if d.hit or not canAttachFrame(d.frame) then return d.hit end
  local hit = CreateFrame("Frame", nil, d.frame)
  hit:SetPoint("TOPLEFT", d.text, "TOPLEFT", -2, 2)
  hit:SetPoint("BOTTOMRIGHT", d.text, "BOTTOMRIGHT", 2, -2)
  hit:EnableMouse(true)
  hit.__laDeco = d
  hit:SetScript("OnEnter", showTooltip)
  hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  d.hit = hit
  return hit
end

local function hideGlows(d)
  for _, g in pairs(d.glows) do
    if g.anim then g.anim:Stop() end
    g.tex:Hide()
  end
end

local function clear(frame)
  local d = deco[frame]
  if not d then return end
  d.text:Hide()
  hideGlows(d)
  if d.hit then
    pcall(d.hit.EnableMouse, d.hit, false)
    if canAttachFrame(frame) then d.hit:Hide() end
  end
end

local function decorate(frame)
  local id = rollIDOf(frame)
  local a = id and NS.rollAdvice[id]
  if not enabled() or not a or not (frame.IsShown and frame:IsShown()) or hiddenByOther(frame) then
    clear(frame)
    return
  end
  local d = ensureDeco(frame)
  d.text:SetText("추천: " .. a.colored)
  d.text:Show()
  local hit = ensureHit(d)
  if hit then
    pcall(hit.EnableMouse, hit, true)
    if canAttachFrame(frame) then hit:Show() end
  end
  hideGlows(d)
  local key = NS.ROLL_BUTTON[a.final]
  local button = key and getButton(frame, key)
  if button then
    local g = d.glows[key]
    if not g or g.button ~= button then
      g = makeGlow(button)
      g.button = button
      d.glows[key] = g
    end
    g.tex:SetVertexColor(hexColor(a.color))
    g.tex:SetAlpha(STRONG[a.final] and 1 or 0.8)
    g.tex:Show()
    if g.anim and STRONG[a.final] then g.anim:Play() end
  end
end

local function hookFrame(frame)
  if hooked[frame] or not frame.HookScript then return end
  hooked[frame] = true
  frame:HookScript("OnShow", function(self) NS.Safe(decorate, self) end)
  frame:HookScript("OnHide", function(self) NS.Safe(clear, self) end)
end

local globalHooked = false
local function installHooks()
  for i = 1, maxFrames() do
    local frame = _G["GroupLootFrame" .. i]
    if type(frame) == "table" and frame.IsShown then hookFrame(frame) end
  end
  if not globalHooked and type(hooksecurefunc) == "function"
    and type(rawget(_G, "GroupLootFrame_OpenNewFrame")) == "function" then
    globalHooked = true
    hooksecurefunc("GroupLootFrame_OpenNewFrame", function() NS.Safe(NS.UpdateRollHighlights) end)
  end
end

-- 보이는 주사위 창을 모두 다시 그린다
function NS.UpdateRollHighlights()
  installHooks()
  for i = 1, maxFrames() do
    local frame = _G["GroupLootFrame" .. i]
    if type(frame) == "table" and frame.IsShown then NS.Safe(decorate, frame) end
  end
end

-- RollWatch 가 추천을 계산하면 부른다
function NS.SetRollAdvice(rollID, r)
  if rollID == nil or NS.IsSecret(rollID) or type(r) ~= "table" then return end
  local n = 0
  for _ in pairs(NS.rollAdvice) do n = n + 1 end
  if n > 30 then NS.rollAdvice = {} end
  local v = NS.FINAL[r.final] or {}
  NS.rollAdvice[rollID] = { final = r.final, label = r.label, colored = r.colored, color = v.color,
    reasons = r.reasons or {} }
  NS.UpdateRollHighlights()
  if NS.UpdateRollCards then NS.Safe(NS.UpdateRollCards, rollID) end
  -- 게임 창이나 DaylightUI 카드가 늦게 준비되는 경우를 대비해 한 번 더
  C_Timer.After(0.2, function()
    NS.Safe(NS.UpdateRollHighlights)
    if NS.UpdateRollCards then NS.Safe(NS.UpdateRollCards, rollID) end
  end)
end

function NS.ToggleRollHighlight()
  NS.db.rollHighlight = (NS.db.rollHighlight == false)
  NS.Safe(NS.UpdateRollHighlights)
  if NS.UpdateRollCards then NS.Safe(NS.UpdateRollCards) end
  return NS.db.rollHighlight
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() NS.Safe(installHooks) end)
