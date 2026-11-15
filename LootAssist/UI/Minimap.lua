-- 미니맵 바깥 둘레 버튼 (드래그로 위치 이동)
local _, NS = ...

local btn

local function updatePosition()
  if not btn then return end
  local angle = math.rad(NS.db.minimap.angle or 210)
  local radius = (Minimap:GetWidth() / 2) + 10
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  NS.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
  updatePosition()
end

function NS.CreateMinimapButton()
  if btn then return btn end
  btn = CreateFrame("Button", "LootAssistMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("CENTER")

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  -- LootProbe 로 확인된 주사위 창 아틀라스
  if not pcall(icon.SetAtlas, icon, "lootroll-toast-icon-need-up") then
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
  end

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  btn:SetScript("OnClick", function() NS.Safe(NS.ToggleMainWindow) end)
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("전리품 도우미", 0.4, 0.8, 1)
    GameTooltip:AddLine("클릭: 창 열기/닫기", 1, 1, 1)
    GameTooltip:AddLine("드래그: 버튼 위치 이동", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  NS.UpdateMinimapButton()
  return btn
end

function NS.UpdateMinimapButton()
  if not btn then return end
  if NS.db.minimap.hide then btn:Hide() else btn:Show() end
  updatePosition()
end
