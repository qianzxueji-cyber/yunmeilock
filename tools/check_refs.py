import os,sys,re

root=sys.argv[1] if len(sys.argv)>1 else 'ios'
files={}
for dp,dn,fn in os.walk(root):
    for f in fn:
        if f.endswith('.swift'):
            p=os.path.join(dp,f)
            rel=os.path.relpath(p,root).replace(os.sep,'/')
            if rel.startswith('YunmeiLock/'):rel=rel[len('YunmeiLock/'):]
            files[rel]=open(p,encoding='utf-8',errors='replace').read()

STR=re.compile(r'"(?:[^"\\]|\\.)*"')
def strip_strings(t):return STR.sub('""',t)

MODS=('public ','private(set) ','private ','fileprivate(set) ','fileprivate ','internal(set) ','internal ','final ','static ','class ','lazy ','override ','weak ','unowned ')
def strip_mods(t):
    changed=True
    while changed:
        changed=False
        if t.startswith('@'):
            t=re.sub(r'^@\w+(\([^)]*\))?\s*','',t);changed=True
        for m in MODS:
            if t.startswith(m):t=t[len(m):];changed=True
    return t

def decls_from(src):
    out=set()
    for line in src.splitlines():
        t=strip_mods(line.strip())
        mm=re.match(r'(?:var|let)\s+([A-Za-z_]\w*)',t)
        if mm:out.add(mm.group(1))
        mm=re.match(r'func\s+([A-Za-z_]\w*)',t)
        if mm:out.add(mm.group(1))
    return out

owners={'settings':'Store/Settings.swift','store':'Store/LockStore.swift',
        'ble':'Ble/BleUnlockService.swift','nfc':'NFC/NFCService.swift'}
known={k:decls_from(files.get(v,''))|{'objectWillChange'} for k,v in owners.items()}

problems=[]
for fname,src in files.items():
    if fname in ('Net/MD5.swift',):continue
    body=strip_strings(src)
    for obj in known:
        for mm in re.finditer(r'(?<![\w.])'+obj+r'\.([A-Za-z_]\w*)',body):
            if mm.group(1) not in known[obj]:
                problems.append('%s: %s.%s 未声明'%(fname,obj,mm.group(1)))

app=files.get('App/YunmeiLockApp.swift','')
provided={}
for mm in re.finditer(r'@StateObject\s+private\s+var\s+(\w+)\s*:\s*(\w+)',app):provided[mm.group(2)] = mm.group(1)
for mm in re.finditer(r'@StateObject\s+private\s+var\s+(\w+)\s*=\s*(\w+)\(',app):provided[mm.group(2)] = mm.group(1)
for t,name in list(provided.items()):
    if ('.environmentObject(%s)'%name) not in app:problems.append('注入声明了但没注入: '+t)

needed=set()
for fname,src in files.items():
    if fname.startswith('App/'):continue
    needed|=set(re.findall(r'@EnvironmentObject\s+private\s+var\s+\w+\s*:\s*(\w+)',src))
for t in sorted(needed):
    if t not in provided:problems.append('视图需要但 App 未提供: '+t)

types=set()
for src in files.values():types|=set(re.findall(r'^(?:struct|final class|class|enum|protocol)\s+(\w+)',src,re.M))
for t in sorted(needed-types):problems.append('EnvironmentObject 类型不存在: '+t)

# 跨文件调用的构造/方法粗查:RootView 里 MainView(...) 的标签必须存在
for callee,caller,rel in [('MainView','RootView','UI/MainView.swift'),('AddLockView','RootView','UI/AddLockView.swift')]:
    src=strip_strings(files.get(caller and ('App/RootView.swift'),''))
    for mm in re.finditer(callee+r'\(([^)]*)\)',src):
        args=mm.group(1)
        if not args:continue
        decl=files.get(rel,'')
        for label in re.findall(r'(\w+)\s*:',args):
            if label in ('lock','initialLock'):pass
            if (label+':') not in decl and ('_ '+label) not in decl:
                problems.append('%s 调用 %s 用了未知参数 %s'%(caller,callee,label))

print('files',len(files),'provided',sorted(provided),'needed',sorted(needed))
print('problems',len(problems))
for p in problems:print(' -',p)
