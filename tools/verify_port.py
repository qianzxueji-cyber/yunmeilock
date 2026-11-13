import os,sys,re,plistlib,hashlib,json

root=sys.argv[1] if len(sys.argv)>1 else 'ios'
expected=[
 'YunmeiLock/App/YunmeiLockApp.swift','YunmeiLock/App/RootView.swift',
 'YunmeiLock/Net/MD5.swift','YunmeiLock/Net/HTTPClient.swift','YunmeiLock/Net/YunmeiAPI.swift',
 'YunmeiLock/Store/SecureStore.swift','YunmeiLock/Store/Settings.swift','YunmeiLock/Store/LockStore.swift',
 'YunmeiLock/Ble/BleUnlockService.swift','YunmeiLock/Location/LocationProvider.swift',
 'YunmeiLock/NFC/NFCService.swift','YunmeiLock/QR/QRGenerator.swift','YunmeiLock/QR/QRScannerView.swift',
 'YunmeiLock/UI/LoginView.swift','YunmeiLock/UI/MainView.swift','YunmeiLock/UI/LockInfoView.swift',
 'YunmeiLock/UI/AddLockView.swift','YunmeiLock/UI/SettingsView.swift','YunmeiLock/UI/ShareQRView.swift',
 'YunmeiLock/Info.plist','project.yml','README.md',
 'Tests/YunmeiLockTests/LockTests.swift','Tests/YunmeiLockTests/UnlockFrameTests.swift']
problems=[]
for e in expected:
    p=os.path.join(root,e)
    if not os.path.exists(p):problems.append('MISSING '+e)
    elif os.path.getsize(p)==0:problems.append('EMPTY '+e)

pl=os.path.join(root,'YunmeiLock/Info.plist')
info={}
if os.path.exists(pl):
    try:
        info=plistlib.load(open(pl,'rb'))
    except Exception as ex:problems.append('Info.plist invalid: %s'%ex)
    urls=info.get('CFBundleURLTypes') or []
    schemes=[s for u in urls for s in (u.get('CFBundleURLSchemes') or [])]
    if 'yunmeiui' not in schemes:problems.append('Info.plist missing URL scheme yunmeiui')
    for k in ['NSBluetoothAlwaysUsageDescription','NSLocationWhenInUseUsageDescription','NSCameraUsageDescription','NFCReaderUsageDescription']:
        if k not in info:problems.append('Info.plist missing '+k)

allowed={'SwiftUI','UIKit','Foundation','CoreBluetooth','CoreNFC','CoreLocation','AVFoundation','CoreImage','XCTest','os','Combine','Security'}
imports=set()
swift=[]
for dp,dn,fn in os.walk(root):
    for f in fn:
        if f.endswith('.swift'):
            p=os.path.join(dp,f);swift.append(p)
            src=open(p,encoding='utf-8',errors='replace').read()
            for m in re.findall(r'^\s*import\s+(\w+)',src,re.M):
                imports.add(m)
                if m not in allowed:problems.append('unexpected import %s in %s'%(m,os.path.relpath(p,root)))
            if src.count('{')!=src.count('}'):problems.append('brace mismatch %s (%d/%d)'%(os.path.relpath(p,root),src.count('{'),src.count('}')))
            for bad in ['TODO','FIXME','<#','需要修改']:
                if bad in src:problems.append('placeholder %r in %s'%(bad,os.path.relpath(p,root)))
contract=['class YunmeiAPI','protocol HTTPClient','enum MD5','class Settings','class LockStore','class SecureStore','class BleUnlockService','class LocationProvider','class NFCService','enum QRGenerator','struct QRScannerView','enum UnlockStage']
joined='\n'.join(open(p,encoding='utf-8',errors='replace').read() for p in swift)
for c in contract:
    if c not in joined:problems.append('contract type missing: '+c)

for f,expect in [('model/Lock.swift',None),('Ble/UnlockFrame.swift',None)]:
    pass
p=os.path.join(root,'YunmeiLock/Model/Lock.swift')
src=open(p,encoding='utf-8',errors='replace').read()
if 'lock_info/' not in src:problems.append('Lock.swift lost deep link logic')
if 'components(separatedBy: "|")' not in src:problems.append('Lock.swift parse logic changed')
p=os.path.join(root,'YunmeiLock/Ble/UnlockFrame.swift')
src=open(p,encoding='utf-8',errors='replace').read()
if '0xA5' not in src or '0xD0' not in src:problems.append('UnlockFrame.swift frame constants changed')

print('swift files:',len(swift),'imports:',sorted(imports))
print('problems:',len(problems))
for p in problems:print(' -',p)
