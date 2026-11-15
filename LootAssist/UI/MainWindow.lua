-- 메인 창: 현재 위치, 내 캐릭터, 주/부 특성 설정
local _, NS = ...

local W, H = 340, 290
local main

local function savePosition(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  NS.db.window.point = { point, relPoint, x, y }
end

local function restorePosition(f)
  local p = NS.db.window.point
  f:ClearAllPoints()
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  end
end

local function setPrimary(key)
  local c = NS.Char()
  if c.primary == key then return end
  c.primary = key
  if c.secondary == key then c.secondary = nil end
  NS.RefreshMainWindow()
  NS.Fire("SPEC_CHANGED")
end

local function setSecondary(key)
  local c = NS.Char()
  if c.secondary == key then c.secondary = nil else c.secondary = key end
  NS.RefreshMainWindow()
  NS.Fire("SPEC_CHANGED")
end

local function buildSpecRow(parent, anchorTo, onPick)
  local row = { buttons = {} }
  for i = 1, 4 do
    local b = NS.MakeButton(parent, 74, 26, "", function(self) onPick(self.specKey) end)
    if i == 1 then
      b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -6)
    else
      b:SetPoint("LEFT", row.buttons[i - 1], "RIGHT", 4, 0)
    end
    row.buttons[i] = b
  end
  return row
end

local function fillSpecRow(row, classData, selectedKey, enabled, disabledKey)
  local specs = classData and classData.specs or {}
  local count = #specs
  local width = count == 4 and 74 or 100
  for i, b in ipairs(row.buttons) do
    local s = specs[i]
    if s then
      b.specKey = s.key
      b:SetLabel(s.name)
      b:SetWidth(width)
      b.tooltip = s.name .. " - " .. (NS.ROLE_LABEL[s.role] or s.role)
      b:SetEnabledState(enabled and s.key ~= disabledKey)
      b:SetSelected(selectedKey == s.key)
      b:Show()
    else
      b:Hide()
    end
  end
end

function NS.CreateMainWindow()
  if main then return main end
  main = CreateFrame("Frame", "LootAssistMainFrame", UIParent, "BackdropTemplate")
  main:SetSize(W, H)
  main:SetFrameStrata("MEDIUM")
  main:SetClampedToScreen(true)
  main:SetMovable(true)
  main:EnableMouse(true)
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", main.StartMoving)
  main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition(self) end)
  NS.ApplyFlat(main)
  restorePosition(main)
  main:Hide()
  tinsert(UISpecialFrames, "LootAssistMainFrame") -- ESC 로 닫기

  -- 제목 줄
  local title = NS.MakeText(main, 14, NS.Style.accent)
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("전리품 도우미")

  local ver = NS.MakeText(main, 10, NS.Style.muted)
  ver:SetPoint("LEFT", title, "RIGHT", 6, -1)
  ver:SetText("v" .. NS.VERSION)

  local close = NS.MakeButton(main, 22, 22, "X", function() main:Hide() end)
  close:SetPoint("TOPRIGHT", -6, -6)

  local line = main:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(NS.Style.border[1], NS.Style.border[2], NS.Style.border[3], 1)
  line:SetPoint("TOPLEFT", 1, -34)
  line:SetPoint("TOPRIGHT", -1, -34)
  line:SetHeight(1)

  -- 위치 / 캐릭터
  main.location = NS.MakeText(main, 12)
  main.location:SetPoint("TOPLEFT", 12, -44)
  main.location:SetWidth(W - 24)

  main.charLine = NS.MakeText(main, 12)
  main.charLine:SetPoint("TOPLEFT", main.location, "BOTTOMLEFT", 0, -8)
  main.charLine:SetWidth(W - 24)

  -- 주 특성
  main.primaryLabel = NS.MakeText(main, 12, NS.Style.accent)
  main.primaryLabel:SetPoint("TOPLEFT", main.charLine, "BOTTOMLEFT", 0, -16)
  main.primaryLabel:SetText("주 특성")
  main.primaryRow = buildSpecRow(main, main.primaryLabel, setPrimary)

  -- 부 특성
  main.secondaryLabel = NS.MakeText(main, 12, NS.Style.accent)
  main.secondaryLabel:SetPoint("TOPLEFT", main.primaryRow.buttons[1], "BOTTOMLEFT", 0, -16)
  main.secondaryLabel:SetText("부 특성")
  main.secondaryRow = buildSpecRow(main, main.secondaryLabel, setSecondary)

  main.secondaryNote = NS.MakeText(main, 11, NS.Style.muted)
  main.secondaryNote:SetPoint("TOPLEFT", main.secondaryRow.buttons[1], "BOTTOMLEFT", 0, -6)
  main.secondaryNote:SetWidth(W - 24)

  -- 역할 요약
  main.roleLine = NS.MakeText(main, 12)
  main.roleLine:SetPoint("TOPLEFT", main.secondaryNote, "BOTTOMLEFT", 0, -12)
  main.roleLine:SetWidth(W - 24)

  -- 하단 안내
  main.footer = NS.MakeText(main, 10, NS.Style.muted)
  main.footer:SetPoint("BOTTOMLEFT", 12, 10)
  main.footer:SetWidth(W - 24)
  main.footer:SetText("특성은 직접 선택합니다. 다음 버전에서 아이템 판정이 추가됩니다.")

  main:SetScript("OnShow", function() NS.Safe(NS.RefreshMainWindow) end)
  return main
end

function NS.RefreshMainWindow()
  if not main or not main:IsShown() then return end
  local info = NS.GetPlayerInfo()
  local classData = NS.GetClassData(info.class)
  local c = NS.Char()

  local kind, placeName = NS.GetLocation()
  main.location:SetText(("현재 위치: %s  %s"):format(NS.LOCATION_LABEL[kind] or kind, placeName or ""))

  local desc = NS.DescribeCurrentDungeon and NS.DescribeCurrentDungeon()
  main.footer:SetText(desc or "특성은 직접 선택합니다. 다음 버전에서 아이템 판정이 추가됩니다.")

  main.charLine:SetText(("%s  ·  %s  ·  %d레벨"):format(
    info.name or "?", NS.ClassColorText(info.class, info.className or "?"), info.level or 0))

  fillSpecRow(main.primaryRow, classData, c.primary, true, nil)

  local dualOK = (info.level or 0) >= NS.DUAL_SPEC_LEVEL
  fillSpecRow(main.secondaryRow, classData, dualOK and c.secondary or nil, dualOK, c.primary)
  if dualOK then
    main.secondaryNote:SetText("한 번 더 누르면 부 특성을 해제합니다.")
  else
    main.secondaryNote:SetText(("부 특성은 %d레벨(이중 특성)부터 설정할 수 있습니다."):format(NS.DUAL_SPEC_LEVEL))
  end

  local p, s = NS.GetActiveSpecs()
  local ps, ss = NS.GetSpec(info.class, p), NS.GetSpec(info.class, s)
  if not ps then
    main.roleLine:SetText("|cffffcc00주 특성을 선택해 주세요.|r")
  else
    local text = ("역할: %s (%s)"):format(NS.ROLE_LABEL[ps.role] or ps.role, ps.name)
    if ss then text = text .. ("  /  부: %s (%s)"):format(NS.ROLE_LABEL[ss.role] or ss.role, ss.name) end
    main.roleLine:SetText(text)
  end
end

function NS.ToggleMainWindow()
  if not main then NS.CreateMainWindow() end
  if main:IsShown() then main:Hide() else main:Show() end
end
