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
