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
(contents/'Info.plist').write_bytes(plistlib.dumps(plist))
with zipfile.ZipFile(root/'lua-source.zip') as z:
 for name in ['README.md','LICENSE.txt','VALIDACAO.md']:
  (out/name).write_bytes(z.read('macos/'+name))
shutil.copytree(arm/'previews',out/'Prévias',dirs_exist_ok=True)
for folder,architecture in [(arm,'Apple-Silicon'),(intel,'Intel')]:
 for f in ['tests.txt','media-check.txt','ui-check.txt']:
  shutil.copy2(folder/f,out/(architecture+'-'+f))
subprocess.run(['codesign','--force','--deep','--sign','-',str(out/'LUA.app')],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(out/'LUA.app')],check=True)
subprocess.run(['lipo','-verify_arch','arm64','x86_64',str(contents/'MacOS/LUA')],check=True)
subprocess.run([str(contents/'MacOS/LUA'),'--verify-media',str(root/'universal-media-check')],check=True)
package=root/f'LUA-{version}-macOS-universal.zip'
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(out),str(package)],check=True)
shutil.make_archive(str(root/'LUA-macOS-previas'),'zip',arm/'previews')
feed={'version':version,'url':f'https://github.com/onekaer/lua-/releases/download/mac-v{version}/{package.name}','sha256':hashlib.sha256(package.read_bytes()).hexdigest(),'bytes':package.stat().st_size}
(root/'LUA-macOS-atualizacoes.json').write_text(json.dumps(feed,indent=2)+'\n')
(root/'mac-notes.md').write_text(f'''LUA {version} Beta para macOS 15 ou posterior. Aplicativo nativo universal, Apple Silicon e Intel.

CPU/RAM/rede/disco, estado térmico, capturas com ScreenCaptureKit, áudio/microfone, buffer de clipes, galeria, jogos .app/Steam, limpeza de duplicados com revisão, relatório e sobreposição móvel.

Testes automatizados executados em runners Mac Apple Silicon e Intel: compilação, regras de segurança, duplicados, atualização, vídeo sintético real H.264 e exportação de clipe. Prévias geradas pelo próprio app nativo, com dados demonstrativos.

Limitações: sem temperatura em °C/uso percentual de GPU garantidos; FPS via HUD Metal da Apple, sem métricas universais/1% low/DLSS. Sem assinatura Developer ID/notarização. Permissões de captura/microfone, jogos reais, tela cheia e desempenho precisam de validação em Mac físico. Não prometemos paridade completa com Windows. Atualizações desta beta são baixadas/verificadas, com substituição manual do app.

Extraia mac-package, mova LUA.app para Aplicativos. Leia README.md e VALIDACAO.md. Não desative as proteções do macOS.
''')
print(json.dumps(feed))
