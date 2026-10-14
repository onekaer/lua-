from pathlib import Path
import json, subprocess, plistlib, shutil, zipfile, hashlib
root=Path.cwd();version=json.loads((root/'mac-release.json').read_text())['version']
out=root/'mac-package';contents=out/'LUA.app/Contents';(contents/'MacOS').mkdir(parents=True,exist_ok=True);(contents/'Resources').mkdir(exist_ok=True)
arm=root/'compiled/lua-macos-15';intel=root/'compiled/lua-macos-15-intel'
for folder in [arm,intel]:
 assert 'PASSOU' in (folder/'media-check.txt').read_text()
 assert 'PASSOU' in (folder/'ui-check.txt').read_text()
 assert 'Executed' in (folder/'tests.txt').read_text()
subprocess.run(['lipo','-create',str(arm/'LUA'),str(intel/'LUA'),'-output',str(contents/'MacOS/LUA')],check=True)
(contents/'MacOS/LUA').chmod(0o755)
plist={'CFBundleName':'LUA','CFBundleDisplayName':'LUA','CFBundleIdentifier':'app.lua.monitor','CFBundleExecutable':'LUA','CFBundlePackageType':'APPL','CFBundleShortVersionString':version,'CFBundleVersion':version,'LSMinimumSystemVersion':'15.0','NSHighResolutionCapable':True,'NSMicrophoneUsageDescription':'Inclua sua voz nas gravações e clipes somente quando a opção de microfone estiver ativada.','NSScreenCaptureUsageDescription':'Capture prints, grave vídeos e mantenha o histórico de clipes que você autorizou.','NSPrincipalClass':'NSApplication'}
icon_script=root/'draw-lua-icon.swift'
icon_script.write_text('''import AppKit
let image=NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSColor(calibratedRed:0.075,green:0.085,blue:0.12,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:20,y:20,width:984,height:984),xRadius:220,yRadius:220).fill()
NSColor(calibratedRed:0.48,green:0.66,blue:1,alpha:1).setFill()
NSBezierPath(ovalIn:NSRect(x:210,y:190,width:600,height:600)).fill()
NSColor(calibratedRed:0.075,green:0.085,blue:0.12,alpha:1).setFill()
NSBezierPath(ovalIn:NSRect(x:365,y:370,width:520,height:520)).fill()
NSColor(calibratedRed:0.75,green:0.85,blue:1,alpha:1).setFill()
let star=NSBezierPath();star.move(to:NSPoint(x:745,y:820));star.line(to:NSPoint(x:770,y:755));star.line(to:NSPoint(x:835,y:730));star.line(to:NSPoint(x:770,y:705));star.line(to:NSPoint(x:745,y:640));star.line(to:NSPoint(x:720,y:705));star.line(to:NSPoint(x:655,y:730));star.line(to:NSPoint(x:720,y:755));star.close();star.fill()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
''')
icon_png=root/'lua-icon.png';subprocess.run(['swift',str(icon_script),str(icon_png)],check=True)
iconset=root/'LUA.iconset';iconset.mkdir(exist_ok=True)
for size in [16,32,128,256,512]:
    for scale in [1,2]:
        pixels=size*scale;name=f'icon_{size}x{size}'+('@2x' if scale==2 else '')+'.png'
        subprocess.run(['sips','-z',str(pixels),str(pixels),str(icon_png),'--out',str(iconset/name)],check=True,stdout=subprocess.DEVNULL)
subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(contents/'Resources/LUA.icns')],check=True)
plist['CFBundleIconFile']='LUA'
(contents/'Info.plist').write_bytes(plistlib.dumps(plist))
if True:
 for name in ['README.md','LICENSE.txt','VALIDACAO.md']:
  (out/name).write_bytes((root/'macos'/name).read_bytes())
shutil.copytree(arm/'previews',out/'Prévias',dirs_exist_ok=True)
for folder,architecture in [(arm,'Apple-Silicon'),(intel,'Intel')]:
 for f in ['tests.txt','media-check.txt','ui-check.txt']:
  shutil.copy2(folder/f,out/(architecture+'-'+f))
subprocess.run(['codesign','--force','--deep','--sign','-',str(out/'LUA.app')],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(out/'LUA.app')],check=True)
subprocess.run(['lipo',str(contents/'MacOS/LUA'),'-verify_arch','arm64','x86_64'],check=True)
subprocess.run([str(contents/'MacOS/LUA'),'--verify-media',str(root/'universal-media-check')],check=True)
package=root/f'LUA-{version}-macOS-universal.zip'
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(out),str(package)],check=True)
shutil.make_archive(str(root/'LUA-macOS-previas'),'zip',arm/'previews')
feed={'version':version,'url':f'https://github.com/onekaer/lua-/releases/download/mac-v{version}/{package.name}','sha256':hashlib.sha256(package.read_bytes()).hexdigest(),'bytes':package.stat().st_size}
(root/'LUA-macOS-atualizacoes.json').write_text(json.dumps(feed,indent=2)+'\n')
(root/'mac-notes.md').write_text(f'''LUA {version} Beta para macOS 15 ou posterior. Aplicativo nativo universal, Apple Silicon e Intel.

CPU/RAM/rede/disco, estado térmico, capturas com ScreenCaptureKit, áudio/microfone, buffer de clipes, galeria, jogos .app/Steam, limpeza de duplicados com revisão, relatório e sobreposição móvel.

Testes automatizados executados em runners Mac Apple Silicon e Intel: compilação, regras de segurança, duplicados, atualização, vídeo sintético real H.264 e exportação de clipe. Prévias geradas pelo próprio app nativo, com dados demonstrativos.

Limitações: sem temperatura em °C/uso percentual de GPU garantidos; FPS via HUD Metal da Apple, sem métricas universais/1% low/DLSS. Sem assinatura Developer ID/notarização. Permissões de captura/microfone, jogos reais, tela cheia e desempenho precisam de validação em Mac físico. Não prometemos paridade completa com Windows. Atualizações verificadas com instalação opcional em Aplicativos e backup; instalação fora dessa pasta pode exigir substituição manual.

Extraia mac-package, mova LUA.app para Aplicativos. Leia README.md e VALIDACAO.md. Não desative as proteções do macOS.
''')
print(json.dumps(feed))
