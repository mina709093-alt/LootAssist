-- 내 주/부 특성 (엔진과 UI가 함께 사용)
local _, NS = ...

-- 저장된 특성이 현재 직업/레벨과 맞는지 정리
function NS.ValidateChar()
  local info = NS.GetPlayerInfo()
  local c = NS.Char()
  if c.primary and not NS.GetSpec(info.class, c.primary) then c.primary = nil end
  if c.secondary and not NS.GetSpec(info.class, c.secondary) then c.secondary = nil end
  if c.secondary and c.secondary == c.primary then c.secondary = nil end
end

-- 레벨 40 미만이면 부 특성은 저장돼 있어도 평가에 쓰지 않는다
function NS.GetActiveSpecs()
  local info = NS.GetPlayerInfo()
  local c = NS.Char()
  local secondary = nil
  if info.level >= NS.DUAL_SPEC_LEVEL then secondary = c.secondary end
  return c.primary, secondary
end

