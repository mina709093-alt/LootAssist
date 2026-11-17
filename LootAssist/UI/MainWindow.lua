-- 메인 창: 현재 위치, 내 캐릭터, 주/부 특성 설정
local _, NS = ...

local W, H = 360, 440
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

  -- 파티 구성
  main.partyLabel = NS.MakeText(main, 12, NS.Style.accent)
  main.partyLabel:SetPoint("TOPLEFT", main.roleLine, "BOTTOMLEFT", 0, -16)
  main.partyLabel:SetText("파티원")
  main.partyHint = NS.MakeText(main, 10, NS.Style.muted)
  main.partyHint:SetPoint("LEFT", main.partyLabel, "RIGHT", 8, 0)
  main.partyHint:SetText("특성 버튼: 왼쪽 클릭 주 특성, 오른쪽 클릭 부 특성")
  main.partyRows = {}
  for i = 1, 4 do
    local row = CreateFrame("Frame", nil, main)
    row:SetSize(W - 24, 24)
    if i == 1 then row:SetPoint("TOPLEFT", main.partyLabel, "BOTTOMLEFT", 0, -6)
    else row:SetPoint("TOPLEFT", main.partyRows[i - 1], "BOTTOMLEFT", 0, -4) end
    row.name = NS.MakeText(row, 12)
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(120)
    row.spec = NS.MakeButton(row, 130, 22, "", nil)
    row.spec:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.spec:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.spec:SetScript("OnClick", function(self, button)
      if self.enabledState and self.member then NS.Safe(NS.CyclePartySpec, self.member, button == "RightButton") end
    end)
    row.tag = NS.MakeText(row, 10, NS.Style.muted)
    row.tag:SetPoint("LEFT", row.spec, "RIGHT", 6, 0)
    row.tag:SetWidth(W - 24 - 120 - 130 - 14)
    main.partyRows[i] = row
  end
  main.partyEmpty = NS.MakeText(main, 11, NS.Style.muted)
  main.partyEmpty:SetPoint("TOPLEFT", main.partyLabel, "BOTTOMLEFT", 0, -8)
  main.partyEmpty:SetText("파티에 들어가면 파티원이 여기에 표시됩니다.")

  -- 하단 안내
  main.footer = NS.MakeText(main, 10, NS.Style.muted)
  main.footer:SetPoint("BOTTOMLEFT", 12, 10)
  main.footer:SetWidth(W - 24)
  main.footer:SetText("")

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
  main.footer:SetText(desc or "")

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

  NS.RefreshPartyRows()
end

local SOURCE_LABEL = { comm = "|cff66dd66자동 공유|r", manual = "직접 설정" }

local function specText(classFile, key)
  local s = NS.GetSpec(classFile, key)
  return s and s.name or nil
end

function NS.RefreshPartyRows()
  if not main or not main:IsShown() then return end
  local count = #NS.Party
  main.partyEmpty:SetShown(count == 0)
  for i, row in ipairs(main.partyRows) do
    local m = NS.Party[i]
    if m then
      local info = NS.MemberInfo(m)
      row.member = m
      row.name:SetText(("%s %d"):format(NS.ClassColorText(m.class, m.name or "?"), m.level or 0))
      local p = specText(m.class, info.primary) or "특성 미확인"
      local s = specText(m.class, info.secondary)
      row.spec:SetLabel(s and (p .. " / " .. s) or p)
      row.spec:SetEnabledState(info.specSource ~= "comm")
      row.spec.tooltip = info.specSource == "comm" and "애드온이 자동으로 받은 정보입니다"
        or "왼쪽 클릭: 주 특성 바꾸기 / 오른쪽 클릭: 부 특성 바꾸기(40레벨 이상)"
      local gear = (info.gearSource == "comm" and "장비 공유") or (info.gearSource == "inspect" and "살펴보기") or "장비 미확인"
      row.tag:SetText((SOURCE_LABEL[info.specSource] or "|cffff9933미확인|r") .. " · " .. gear)
      row:Show()
    else
      row.member = nil
      row:Hide()
    end
  end
end

-- 직접 설정: 미확인 -> 특성1 -> 특성2 -> ... -> 미확인 순서로 바꾼다
function NS.CyclePartySpec(member, secondary)
  local c = NS.GetClassData(member.class)
  if not c then return end
  if secondary and (member.level or 1) < NS.DUAL_SPEC_LEVEL then
    NS.Print(("%s은(는) %d레벨 미만이라 부 특성을 설정할 수 없습니다."):format(member.name, NS.DUAL_SPEC_LEVEL))
    return
  end
  local m = NS.ManualFor(member.name)
  local field = secondary and "secondary" or "primary"
  local order = { false }
  for _, s in ipairs(c.specs) do
    if not (secondary and s.key == m.primary) then order[#order + 1] = s.key end
  end
  local idx = 1
  for i, k in ipairs(order) do if k == (m[field] or false) then idx = i end end
  local nextKey = order[idx % #order + 1]
  m[field] = nextKey or nil
  if not secondary and m.secondary == m.primary then m.secondary = nil end
  NS.RefreshPartyRows()
end

function NS.ToggleMainWindow()
  if not main then NS.CreateMainWindow() end
  if main:IsShown() then main:Hide() else main:Show() end
end

NS.On("PARTY_CHANGED", function() NS.RefreshPartyRows() end)
