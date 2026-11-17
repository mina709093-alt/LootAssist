-- C. 최종 행동 추천 엔진: 개인 평가(A) + 파티 분배(B)
-- 던전: 파티원 비교 / 필드·파티 없음: 내 기준만 (양보 권고 안 함)
local _, NS = ...

NS.FINAL = {
  BID_STRONG  = { label = "적극 입찰", color = "33ff66" },
  BID         = { label = "입찰 추천", color = "99dd55" },
  YIELD_MAYBE = { label = "상황에 따른 양보", color = "ffd24d" },
  YIELD       = { label = "양보 권장", color = "ff9966" },
  GREED       = { label = "차비 추천", color = "a8a8a8" },
  NO_DATA     = { label = "정보 부족", color = "ff9933" },
  NOT_GEAR    = { label = "장비 아님", color = "a8a8a8" },
}

local function finish(res, key)
  res.final = key
  local v = NS.FINAL[key]
  res.label = v.label
  res.colored = "|cff" .. v.color .. v.label .. "|r"
  return res
end

local function add(res, text) res.reasons[#res.reasons + 1] = text end

function NS.Advise(link)
  local p = NS.EvaluateForMe(link, { ignoreEquipped = true })
  local res = { personal = p, reasons = {} }
  if p.verdict == "LOADING" then res.loading = true; for _, r in ipairs(p.reasons) do add(res, r) end; return finish(res, "NO_DATA") end
  if p.verdict == "NOT_GEAR" then for _, r in ipairs(p.reasons) do add(res, r) end; return finish(res, "NOT_GEAR") end
  if p.verdict == "NEED_SPEC" or p.verdict == "NO_DATA" then for _, r in ipairs(p.reasons) do add(res, r) end; return finish(res, "NO_DATA") end
  if p.verdict == "GREED" or p.verdict == "EQUIPPED" then for _, r in ipairs(p.reasons) do add(res, r) end; return finish(res, "GREED") end

  local kind = NS.GetLocation()
  local partyMode = (kind == "DUNGEON") and #NS.Party > 0
  res.partyMode = partyMode
  if not partyMode then
    for _, r in ipairs(p.reasons) do add(res, r) end
    if #NS.Party > 0 then add(res, "필드에서는 파티원과 비교하지 않고 내 기준으로만 판단합니다") end
    return finish(res, p.verdict == "BID_STRONG" and "BID_STRONG" or "BID")
  end

  -- 던전: 파티원과 비교
  local E = NS.EVAL
  local rivals = NS.EvaluateParty(p.item)
  res.rivals = rivals
  local top = rivals[1]
  local Nrival = top and top.N or 0
  local fitMe = p.usedSecondary and ((p.fitS or 0) * E.SECONDARY_WEIGHT) or (p.fitP or 0)
  local gainMe = p.usedSecondary and p.gainS or p.gainP
  local Pme = (p.eligibility and p.eligibility.nonPrimaryArmor) and 0.6 or 1
  local Ume = (gainMe == nil) and 1 or ((gainMe <= 0) and 0.2 or (1 + math.min(gainMe, 1)))
  local Nme = fitMe * Pme * Ume
  res.Nme, res.Nrival = Nme, Nrival

  local key
  if Nrival <= 0 then
    key = (p.verdict == "BID_STRONG" or p.verdict == "BID") and "BID_STRONG" or "BID"
    add(res, "파티에 이 아이템이 더 필요한 사람이 없습니다")
  else
    local who = NS.MemberLabel(top)
    local complete = (not top.specUnknown) and top.gearKnown
    if p.usedSecondary and top.spec and top.spec.main then
      key = complete and "YIELD" or "YIELD_MAYBE"
      add(res, ("내 부 특성용이고, %s의 주 특성에 맞는 아이템입니다"):format(who))
    elseif Nme >= 1.2 * Nrival then
      key = (p.verdict == "BID_STRONG") and "BID_STRONG" or "BID"
      add(res, ("%s도 쓸 수 있지만 내게 더 필요합니다"):format(who))
    elseif Nme >= 0.8 * Nrival then
      key = "BID"
      add(res, ("%s와 비슷하게 필요합니다. 둘 다 입찰하는 것이 일반적입니다"):format(who))
    else
      key = complete and "YIELD" or "YIELD_MAYBE"
      add(res, ("%s에게 더 필요한 아이템입니다"):format(who))
    end
    if top.specUnknown then add(res, "그 파티원의 특성을 모릅니다 (창에서 직접 설정할 수 있습니다)") end
    if not top.gearKnown then add(res, "파티원 장비 정보 미확인 - 현재 장비와는 비교하지 못했습니다") end
  end
  if p.reasons[1] then add(res, "내 기준: " .. p.label .. " - " .. p.reasons[1]) end
  return finish(res, key)
end

-- 파티 채팅에 붙여 넣을 문장 (자동 전송하지 않음)
function NS.ShareText(res, link)
  if not res or not link then return nil end
  local plain = function(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local top = res.rivals and res.rivals[1]
  if (res.final == "YIELD" or res.final == "YIELD_MAYBE") and top then
    return plain(("%s 는 %s에게 더 맞는 것 같아 양보할게요."):format(link, NS.MemberLabel(top)))
  elseif res.final == "BID_STRONG" or res.final == "BID" then
    return plain(("%s 는 제 주 특성 업그레이드라 입찰할게요."):format(link))
  elseif res.final == "GREED" then
    return plain(("%s 는 저는 안 써서 차비할게요."):format(link))
  end
  return nil
end
