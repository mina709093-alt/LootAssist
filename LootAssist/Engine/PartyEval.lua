-- B. 파티 아이템 분배 엔진: 파티원마다 이 아이템이 얼마나 필요한지(필요도 N) 계산
-- N = 착용(E) × 특성 적합도(F) × 주 방어구(P) × 업그레이드(U)
-- 장비를 모르면 U = 1(중립)로 두고, 추측해서 줄이거나 늘리지 않는다.
local _, NS = ...

function NS.EvaluateParty(item)
  local out = {}
  local maxScore = NS.MaxSpecScore(item)
  for _, m in ipairs(NS.Party) do
    local r = { member = m, N = 0 }
    local el = NS.CheckEligibility(item, m.class, m.level or 1)
    r.eligible = el.ok
    if el.ok then
      local info = NS.MemberInfo(m)
      r.info = info
      local candidates = {}
      if info.primary then
        candidates[1] = { key = info.primary, mult = 1, main = true }
        if info.secondary then candidates[2] = { key = info.secondary, mult = NS.EVAL.SECONDARY_WEIGHT, main = false } end
      else
        r.specUnknown = true
        local c = NS.GetClassData(m.class)
        for _, s in ipairs(c and c.specs or {}) do candidates[#candidates + 1] = { key = s.key, mult = 1, main = true } end
      end
      local best
      for _, cand in ipairs(candidates) do
        local fit = NS.SpecFit(item, m.class, cand.key, maxScore) * cand.mult
        if not best or fit > best.fit then best = { fit = fit, spec = cand } end
      end
      if best then
        r.fit, r.spec = best.fit, best.spec
        local P = el.nonPrimaryArmor and 0.6 or 1
        local U = 1
        r.gearKnown = false
        if not r.specUnknown then
          local cur, why = NS.MemberCurrentScore(info, item, best.spec.key)
          if cur ~= nil then
            r.gearKnown = true
            local new = NS.SpecScore(item, m.class, best.spec.key) or 0
            local g
            if cur <= 0 then g = (new > 0) and 1 or 0 else g = (new - cur) / cur end
            r.gain = g
            U = (g <= 0) and 0 or (1 + math.min(g, 1))
          elseif why == "TWOHAND" then
            r.gearKnown, U = true, 0.5
          end
        end
        r.nonPrimaryArmor = el.nonPrimaryArmor
        if r.fit >= NS.EVAL.FIT then r.N = r.fit * P * U end
      end
    end
    out[#out + 1] = r
  end
  table.sort(out, function(a, b) return a.N > b.N end)
  return out
end

function NS.MemberLabel(r)
  local m = r.member
  local who = NS.ClassColorText and NS.ClassColorText(m.class, m.name) or m.name
  if r.specUnknown then return ("%s(%s, 특성 미확인)"):format(who, m.className or m.class) end
  local s = NS.GetSpec(m.class, r.spec and r.spec.key)
  return ("%s(%s %s)"):format(who, s and s.name or "?", m.className or m.class)
end
