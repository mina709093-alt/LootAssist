"""Minimal parser for WoW SavedVariables Lua tables -> Python objects."""
import re, sys, json

class P:
    def __init__(self, s):
        self.s, self.i = s, 0
    def ws(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in ' \t\r\n,;':
                self.i += 1
            elif s.startswith('--', self.i):
                j = s.find('\n', self.i); self.i = len(s) if j < 0 else j
            else:
                break
    def val(self):
        self.ws(); s = self.s; c = s[self.i]
        if c == '{': return self.table()
        if c == '"': return self.string()
        m = re.compile(r'-?\d+(\.\d+)?([eE][-+]?\d+)?').match(s, self.i)
        if m:
            self.i = m.end(); t = m.group(0)
            return float(t) if ('.' in t or 'e' in t.lower()) else int(t)
        for w, v in (('true', True), ('false', False), ('nil', None)):
            if s.startswith(w, self.i):
                self.i += len(w); return v
        raise ValueError('bad at %d: %r' % (self.i, s[self.i:self.i+40]))
    def string(self):
        s = self.s; self.i += 1; out = []
        while True:
            c = s[self.i]
            if c == '\\':
                n = s[self.i+1]
                if n.isdigit():
                    m = re.compile(r'\d{1,3}').match(s, self.i+1)
                    out.append(chr(int(m.group(0)))); self.i = m.end(); continue
                out.append({'n': '\n', 't': '\t', '"': '"', '\\': '\\'}.get(n, n)); self.i += 2; continue
            if c == '"':
                self.i += 1; return ''.join(out)
            out.append(c); self.i += 1
    def table(self):
        self.i += 1; d = {}; arr = 1
        while True:
            self.ws()
            if self.s[self.i] == '}':
                self.i += 1; return d
            if self.s[self.i] == '[':
                self.i += 1; k = self.val(); self.ws()
                assert self.s[self.i] == ']'; self.i += 1; self.ws()
                assert self.s[self.i] == '='; self.i += 1
                d[k] = self.val()
            else:
                d[arr] = self.val(); arr += 1

def load(path):
    s = open(path, encoding='utf-8', errors='replace').read()
    j = s.find('=')
    return P(s[j+1:]).val()

if __name__ == '__main__':
    print(json.dumps(load(sys.argv[1]), ensure_ascii=False, indent=1)[:2000])
