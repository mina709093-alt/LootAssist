import re, sys
sys.path.insert(0,'.')
import luasv
class P2(luasv.P):
    def table(self):
        self.i += 1; d = {}; arr = 1
        while True:
            self.ws()
            if self.s[self.i] == '}':
                self.i += 1; return d
            if self.s[self.i] == '[':
                self.i += 1; k = self.val(); self.ws(); self.i += 1; self.ws(); self.i += 1
                d[k] = self.val(); continue
            m = re.compile(r'([A-Za-z_]\w*)\s*=(?!=)').match(self.s, self.i)
            if m:
                self.i = m.end(); d[m.group(1)] = self.val()
            else:
                d[arr] = self.val(); arr += 1
def section(src, name):
    j = src.find('NS.%s = ' % name)
    p = P2(src); p.i = src.find('{', j)
    return p.val()
src = open(sys.argv[1] if len(sys.argv) > 1 else 'Data.lua', encoding='utf-8').read()
