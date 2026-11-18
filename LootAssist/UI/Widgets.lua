-- 공용 위젯: 어두운 평면 스타일
local _, NS = ...

-- 상수 스타일 색 (Sangsu'sStyle UI 애드온과 같은 색)
NS.Style = {
  bg = { 0.035, 0.055, 0.065, 0.92 },
  border = { 0, 0, 0, 1 },
  panel = { 0.02, 0.035, 0.042, 1 },
  btn = { 0.055, 0.085, 0.10, 1 },
  btnHover = { 0.08, 0.12, 0.14, 1 },
  btnEdge = { 0.20, 0.25, 0.28, 1 },
  selected = { 0.045, 0.32, 0.26, 1 },
  disabled = { 0.03, 0.045, 0.052, 1 },
  accent = { 0.063, 0.816, 0.627 },
  muted = { 0.55, 0.60, 0.63 },
}

local FLAT = "Interface\\Buttons\\WHITE8x8"

function NS.ApplyFlat(frame, bg, border)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  local b = bg or NS.Style.bg
  local e = border or NS.Style.border
  frame:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
  frame:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
end

function NS.MakeText(parent, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local font = fs:GetFont()
  if font then fs:SetFont(font, size or 12, "") end
  local c = color or { 0.92, 0.92, 0.92 }
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetJustifyH("LEFT")
  return fs
end

-- 선택형 평면 버튼
function NS.MakeButton(parent, width, height, label, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, height)
  NS.ApplyFlat(b, NS.Style.btn, NS.Style.btnEdge)
  b.text = NS.MakeText(b, 12)
  b.text:SetPoint("CENTER")
  b.text:SetJustifyH("CENTER")
  b.text:SetText(label or "")
  b.selected, b.enabledState = false, true

  function b:Repaint()
    local c
    if not self.enabledState then c = NS.Style.disabled
    elseif self.selected then c = NS.Style.selected
    elseif self.hover then c = NS.Style.btnHover
    else c = NS.Style.btn end
    self:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    local e = (self.hover and self.enabledState) and NS.Style.accent or NS.Style.btnEdge
    self:SetBackdropBorderColor(e[1], e[2], e[3], 1)
    if self.enabledState then self.text:SetTextColor(0.95, 0.95, 0.95)
    else self.text:SetTextColor(0.40, 0.40, 0.42) end
  end
  function b:SetSelected(v) self.selected = v and true or false; self:Repaint() end
  function b:SetEnabledState(v) self.enabledState = v and true or false; self:Repaint() end
  function b:SetLabel(t) self.text:SetText(t) end

  b:SetScript("OnEnter", function(self)
    self.hover = true; self:Repaint()
    if self.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    self.hover = false; self:Repaint()
    GameTooltip:Hide()
  end)
  b:SetScript("OnClick", function(self, ...)
    if self.enabledState and onClick then NS.Safe(onClick, self, ...) end
  end)
  b:Repaint()
  return b
end

function NS.ClassColorText(classFile, text)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile or ""]
  if c and c.colorStr then return "|c" .. c.colorStr .. text .. "|r" end
  if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, text) end
  return text
end
