import sys
sys.path.insert(0, '.')
exec(open('adj.py').read())

def lstr(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

def ordered(d):
    return [d[k] for k in sorted(d)] if isinstance(d, dict) else []

D = section(src, 'Dungeons')
ST = section(src, 'ItemStatus')
BN = section(src, 'BossNames')
ko = BN.get('koKR', {})

out = []
out.append('-- 던전별 보스 전리품 데이터 (자동 생성: tools/convert_adj.py, 직접 수정 금지)')
out.append('-- 출처: Dungeon Codex (AeonDungeonJournal) 1.4 Data.lua, GPL-2.0')
out.append('--       그 원본은 AtlasLootClassic(GPL-2.0), QuestieDB, foreverchanges.pro (CREDITS.md 참고)')
out.append('-- status: verified = AtlasLootClassic 기반, beta = foreverchanges.pro 단독, unconfirmed = 데이터 없음')
out.append('local _, NS = ...')
out.append('')
out.append('NS.DungeonData = {')
nd = nb = ni = 0
for d in ordered(D):
    inst = d.get('instance') or 0
    if inst == 0 or not d.get('bosses'):
        continue
    nd += 1
    lv = d.get('levels', {})
    out.append('  { key = %s, instance = %d, status = %s, levels = { %s },' % (
        lstr(d['key']), inst, lstr(d.get('status', '?')), ', '.join(str(lv[k]) for k in sorted(lv))))
    out.append('    bosses = {')
    for b in ordered(d['bosses']):
        nb += 1
        items = ordered(b.get('items', {}))
        ni += len(items)
        drops = b.get('drops', {}) or {}
        dstr = ', '.join('[%d] = %s' % (k, ('%g' % v)) for k, v in sorted(drops.items()))
        kname = ko.get(b['npc'])
        fields = ['npc = %d' % b['npc'], 'name = %s' % lstr(b['name'])]
        if kname: fields.append('ko = %s' % lstr(kname))
        others = ordered(b.get('otherNpcs', {}))
        if others: fields.append('otherNpcs = { %s }' % ', '.join(map(str, others)))
        if b.get('rare'): fields.append('rare = true')
        fields.append('items = { %s }' % ', '.join(map(str, items)))
        if dstr: fields.append('drops = { %s }' % dstr)
        out.append('      { %s },' % ', '.join(fields))
    out.append('    },')
    out.append('  },')
out.append('}')
out.append('')
out.append('-- Forever에서 새로 생긴(new) / 바뀐(changed) 아이템')
out.append('NS.ItemForeverStatus = {')
row = []
for k, v in sorted(ST.items()):
    row.append('[%d] = %s' % (k, lstr(v)))
    if len(row) == 8:
        out.append('  ' + ', '.join(row) + ','); row = []
if row: out.append('  ' + ', '.join(row) + ',')
out.append('}')
open('../LootAssist/Data/Dungeons.lua', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('dungeons', nd, 'bosses', nb, 'items', ni, 'status', len(ST), 'ko names', sum(1 for d in ordered(D) for b in ordered(d.get('bosses', {})) if ko.get(b['npc'])), '/', nb)
