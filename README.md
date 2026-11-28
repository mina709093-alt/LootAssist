# 전리품 도우미 (LootAssist)

와우 포에버(WoW: Forever)용 애드온입니다. 던전에서 주사위 창이 뜨면 **입찰 / 양보 / 차비** 중 무엇이 합리적인지 판단을 돕습니다.
상수팩 애드온이며, 아직 **테스트 중**입니다.

## 데이터 출처와 연락처 (Data sources & contact)

이 애드온은 아래에 적은 프로젝트들의 공개 데이터를 이용해 만들었습니다. 데이터를 만들고 공개해 주신 분들께 깊이 감사드립니다.

저작권자나 데이터를 제공하신 분께서 사용을 원하지 않으시면, 언제든 아래 메일로 알려 주십시오.
요청을 받는 즉시 해당 데이터의 사용을 멈추고, 이후 배포본에서 빼겠습니다. 그 밖에 필요하신 조치가 있으면 성심껏 협조하겠습니다.
미처 허락을 구하지 못한 부분이 있었다면 진심으로 사과드립니다.

- 연락처: mina709093@gmail.com

> This add-on is built with publicly available data from the projects listed below, and we are sincerely grateful to their authors.
> If you are a rights holder or data provider and would prefer that we not use your data, please contact us at any time at mina709093@gmail.com.
> We will stop using it immediately upon request, remove it from future releases, and cooperate fully with any further steps you may need.
> We apologize for any inconvenience this may have caused.

| 데이터 | 가져온 곳 (라이선스) | 쓰는 곳 | 확인 방법 |
|---|---|---|---|
| 던전 보스 전리품, 드랍 확률, Forever 신규·변경 표시 | Dungeon Codex (AeonDungeonJournal) 1.4 (GPL-2.0, CurseForge project 1715265). Dungeon Codex의 원본: AtlasLootClassic(GPL-2.0), QuestieDB, foreverchanges.pro | `LootAssist/Data/Dungeons.lua` | `tools/convert_adj.py`로 변환. 2026-11-15 통곡의 동굴에서 실제로 나온 보스 전리품 9종이 모두 데이터와 일치 |
| 특성별 능력치 가중치(EP), 레이팅 환산값 | [wowsims/forever](https://github.com/wowsims/forever) (MIT, Copyright (c) 2022 wowsims team) — 각 특성의 `presets.ts`, `ui/sim/constants/mechanics.ts` | `LootAssist/Data/SimWeights.lua` (0.7.0) | master `dc09e00`(2026-11-28)의 숫자만 옮김(코드는 가져오지 않음). 치명타 레이팅 14 = 1%는 게임 측정(34레벨 주술사)과 같음. 오프라인 시험으로 환산 확인 |

자세한 출처와 라이선스 전문은 `LootAssist/CREDITS.md`에 있습니다.

- 자동으로 입찰하거나 차비를 누르지 않습니다. 최종 선택은 항상 직접 합니다.
- 내 직업·특성으로 착용할 수 있는지, 파티원에게 더 필요한 아이템인지를 함께 봅니다.

## 설치

[상수팩 안내](https://github.com/mina709093-alt/SangsuPack)의 WowUp 설치 방법을 따라, 아래 주소를 **Install from URL**에 붙여 넣습니다.

```
https://github.com/mina709093-alt/LootAssist
```

게임에서 미니맵 버튼이나 `/전리품`으로 창을 엽니다.

## 현재 버전에서 되는 것 (0.7.x)

- 현재 위치(던전 / 필드 / 기타 인스턴스)와 내 캐릭터 표시
- 주 특성 / 부 특성(40레벨부터) 선택
- 착용 판정: 직업별 무기·방어구 숙련, 사슬·판금 40레벨 제한, 주 방어구 구분
- 내 기준 아이템 평가: 특성별 능력치 가중치, 현재 장비 대비 상승량, 판정 이유
- **시뮬레이터 가중치 (0.7.0)**: 28개 특성 중 18개는 wowsims(와우 포에버 시뮬레이터, 60레벨 기준) 가중치로 점수를 매깁니다. 나머지(신성·보호 성기사, 복원 주술사, 마법사, 흑마법사, 회복 드루이드)는 추정 가중치입니다. 툴팁에 "현재 장비 대비 +n점"과 점수 기준을 보여 줍니다. 장신구 사용·발동 효과와 세트 효과는 점수에 넣지 않습니다.
- **파티 판정 (던전)**: 파티원과 비교해 적극 입찰 / 입찰 추천 / 상황에 따른 양보 / 양보 권장 / 차비 추천
- **자동 공유**: 이 애드온을 쓰는 파티원끼리 직업·특성·장비 점수를 자동으로 주고받음 (전투 중에는 보내지 않음)
- 파티원 특성 직접 설정 (이름별로 기억), 살펴보기 결과로 장비 비교
- 아이템 툴팁에 내 기준 판정, 주사위가 뜨면 채팅창에 최종 판정
- **주사위 창 강조 (0.6.0)**: 주사위 창에 추천 글자를 색으로 보여 주고, 추천하는 버튼(입찰 / 차비 / 양보)에 빛이 납니다. 추천 글자에 마우스를 올리면 판정 이유가 나옵니다. 버튼은 누르지 않습니다.
- **DaylightUI 주사위 카드 (0.6.0)**: DaylightUI의 주사위 카드를 쓰면 카드에도 추천 글자와 버튼 테두리를 보여 줍니다.
- **착용 중인 아이템 같이 보기 (0.6.0)**: 주사위 아이템에 마우스를 올리면 그 칸에 지금 끼고 있는 아이템도 옆에 보여 줍니다(Shift 없이). 반지·장신구는 두 칸 모두.
- 던전 29곳 보스 전리품 데이터 (`/전리품 던전`)

필드에서는 파티원과 비교하지 않고 내 기준으로만 판단합니다.

## 명령어

| 명령어 | 하는 일 |
|---|---|
| `/전리품` | 창 열기/닫기 |
| `/전리품 평가 [아이템 링크]` | 내 기준 판정과 이유 |
| `/전리품 툴팁` | 툴팁 판정 표시 켜기/끄기 |
| `/전리품 채팅` | 주사위 판정 채팅 알림 켜기/끄기 |
| `/전리품 강조` | 주사위 창(카드) 강조 켜기/끄기 |
| `/전리품 비교` | 주사위 아이템에 마우스를 올리면 끼고 있는 아이템도 보여 주기 켜기/끄기 |
| `/전리품 파티` | 파티원 특성/장비 정보 출처 |
| `/전리품 공유` | 마지막 판정 문장을 채팅 입력창에 넣기 (보내기는 직접) |
| `/전리품 던전` | 현재 던전의 보스별 전리품 데이터 |
| `/전리품 기록` | 테스트 기록 현황 (`/전리품 기록지우기`로 비우기) |
| `/전리품 수집` | 이 계정을 수집자로 켜기/끄기 (파티원들이 보관한 판정을 모음) |

## 테스트

플레이하는 동안 주사위 판정, 파티 통신 결과, 보스 처치, 획득 메시지가 저장 파일에 자동으로 기록됩니다.
모든 사람은 자기 주사위 판정을 보관해 두고, **수집자**(`/전리품 수집`으로 켠 사람)와 파티가 되면 아직 보내지 않은 판정을 자동으로 보냅니다(1.5초에 하나씩, 전투 중에는 멈춤).
그래서 수집자가 없을 때 다른 사람들끼리 플레이한 판정도 나중에 수집자의 `LootAssist.lua` 한 파일로 모입니다. 보내는 것은 주사위 판정 요약(아이템, 판정, 필요도, 이유 첫 줄)뿐입니다.
`tools/summarize_log.py LootAssist.lua` 로 아이템별 표로 정리할 수 있습니다.


`tests/harness.lua`는 게임 밖에서 엔진을 실측 데이터(2026-11-15 통곡의 동굴)로 돌려 봅니다.
`cd tests && texlua harness.lua A ELEMENTAL RESTORATION` (A=주술사, B=마법사)
파티 판정: `texlua harness.lua B FIRE nil 25 party`

## 라이선스와 출처

GPL-2.0 (`LICENSE`). 던전 전리품 데이터는 Dungeon Codex(GPL-2.0)에서 변환했고, 능력치 가중치는 wowsims/forever(MIT)의 값을 씁니다. 자세한 출처는 `LootAssist/CREDITS.md`에 있습니다.
데이터를 다시 만들려면 `tools` 폴더에서 `python convert_adj.py <Dungeon Codex의 Data.lua 경로>`를 실행합니다.
