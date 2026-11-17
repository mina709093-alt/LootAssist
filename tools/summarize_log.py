"""LootAssist 저장 파일(LootAssist.lua)의 테스트 기록을 아이템별 표로 정리한다.
사용: python summarize_log.py LootAssist.lua
"""
import sys
from collections import defaultdict
sys.path.insert(0, '.')
import luasv

db = luasv.load(sys.argv[1])
log = [db['log'][k] for k in sorted(db.get('log', {}))]
print('기록 %d건' % len(log))
sessions = [e for e in log if e.get('k') == 'session']
for s in sessions:
    print('접속: %s %s %s레벨 v%s (주 %s / 부 %s)' % (s.get('name'), s.get('class'), s.get('level'), s.get('version'), s.get('primary'), s.get('secondary')))

print('\n[통신]')
kinds = defaultdict(int)
for e in log:
    kinds[e.get('k')] += 1
print(dict(kinds))
for e in log:
    if e.get('k') == 'commFail':
        print('  실패', e)
dungeon_recv = [e for e in log if e.get('k') == 'commRecv' and e.get('dungeon')]
print('  던전 안에서 받은 공유: %d건' % len(dungeon_recv))

print('\n[주사위 판정: 아이템별로 나와 친구들 판정 비교]')
by_item = defaultdict(list)
for e in log:
    if e.get('k') in ('roll', 'friendRoll'):
        by_item[(e.get('item'))].append(e)
for item, es in by_item.items():
    name = next((e.get('name') for e in es if e.get('name')), '')
    print('- %s %s (보스: %s)' % (item, name, next((e.get('boss') for e in es if e.get('boss')), '?')))
    for e in es:
        who = '나' if e['k'] == 'roll' else e.get('from')
        print('    %-8s %-12s 개인=%-10s N나=%s N파티=%s %s' % (who, e.get('final'), e.get('personal'), e.get('Nme'), e.get('Nrival'),
              (e.get('reasons') or {}).get(1, '') if isinstance(e.get('reasons'), dict) else ''))

print('\n[획득 메시지]')
for e in log:
    if e.get('k') == 'lootMsg':
        print('  ', e.get('t'), e.get('text'))
for key in ('unknownStats', 'seenStats', 'commErrors'):
    if db.get(key):
        print('\n[%s]' % key, db[key])
