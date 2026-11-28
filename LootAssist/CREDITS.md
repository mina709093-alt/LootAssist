# 전리품 도우미 (LootAssist) - 출처와 라이선스

이 애드온은 GNU General Public License v2.0 (GPL-2.0)으로 배포합니다. 전문은 LICENSE 파일에 있습니다.

## 던전 전리품 데이터 (Data/Dungeons.lua)

- **Dungeon Codex (AeonDungeonJournal) 1.4** — GPL-2.0, CurseForge project 1715265
  - `Data.lua`의 던전·보스·아이템·드랍 확률·Forever 신규/변경 표시를 저장소의 `tools/convert_adj.py`로 변환했습니다.
- Dungeon Codex가 밝힌 원본 출처:
  - AtlasLootClassic (Hoizame) — 보스와 전리품, GPL-2.0
  - QuestieDB — 보스 이름 번역
  - foreverchanges.pro — Forever 레벨, 추가 보스, 드랍 확률, 신규/변경 아이템, Forever 신규 던전

## 데이터를 다시 만들려면

저장소의 `tools/convert_adj.py`를 Dungeon Codex의 `Data.lua`에 대해 실행하면 `Data/Dungeons.lua`가 새로 만들어집니다.

## 검증

2026-11-15 통곡의 동굴(빌드 1.60.1.70938)에서 실제로 나온 보스 전리품(파랑 9종)이 모두 데이터의 보스와 일치했습니다.

## 능력치 가중치 (Data/SimWeights.lua)

- **wowsims/forever** — MIT License, Copyright (c) 2022 wowsims team
  - https://github.com/wowsims/forever (라이선스 원문: 저장소의 `LICENSE`)
  - 각 특성 폴더 `ui/specs/<직업>/<특성>/presets.ts`(야성 드루이드는 `ui/specs/druid/feral_ep.ts`)의 EP 프리셋 값과
    `ui/sim/constants/mechanics.ts`의 레이팅 환산값(적중 10, 치명타 14, 가속 10, 숙련 10 = 1%)을 옮겼습니다.
  - 마법사·흑마법사(0.9.1)는 프리셋에 EP가 없어서, wowsims 웹 시뮬레이터(https://wowsims.com/forever)의
    능력치 가중치 계산을 프리셋 설정·장비 그대로 돌려 나온 값을 옮겼습니다(2026-11-28).
  - 확인한 버전: master `dc09e00` (2026-11-28). 코드는 가져오지 않았고 숫자만 씁니다.
  - wowsims는 이 프로젝트를 쓰는 곳에 원 프로젝트 링크를 남겨 달라고 요청합니다. 위 링크가 그 안내입니다.

MIT License 전문 (wowsims/forever):

```
MIT License

Copyright (c) 2022 wowsims team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
