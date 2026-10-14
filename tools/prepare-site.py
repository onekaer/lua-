from pathlib import Path
import json, sys, re, subprocess, tempfile, zipfile, shutil
root=Path(sys.argv[1]);release=json.loads(Path(sys.argv[2]).read_text(encoding='utf-8-sig'))
version=release['tagName'].removeprefix('v')
assert re.fullmatch(r'\d+\.\d+\.\d+',version), 'Versão inválida'
asset=next(item for item in release['assets'] if item['name'].startswith('LUA-') and item['name'].endswith('-Windows-x64.zip'))
download=asset.get('url') or asset.get('browser_download_url')
assert download.startswith('https://github.com/onekaer/lua-/releases/download/'), 'Download fora do repositório'
for name in ['index.html','style.css','app.js','assets/inicio.png','assets/captura.png','assets/galeria.png','assets/jogos.png','assets/rede.png']:
    assert (root/name).is_file(), 'Arquivo da página ausente: '+name
(root/'release.json').write_text(json.dumps({'version':version,'download':download,'bytes':asset['size']},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Página pronta para LUA',version)
mac_spec=Path('mac-release.json')
if mac_spec.is_file():
    mac_version=json.loads(mac_spec.read_text())['version']
    assert re.fullmatch(r'\d+\.\d+\.\d+',mac_version)
    tag='mac-v'+mac_version
    with tempfile.TemporaryDirectory() as tmp:
        result=subprocess.run(['gh','release','download',tag,'--repo','onekaer/lua-','--pattern','LUA-macOS-atualizacoes.json','--pattern','LUA-macOS-previas.zip','--dir',tmp],capture_output=True,text=True)
        if result.returncode==0:
            feed=json.loads((Path(tmp)/'LUA-macOS-atualizacoes.json').read_text())
            assert feed['version']==mac_version and feed['url'].startswith('https://github.com/onekaer/lua-/releases/download/'+tag+'/')
            (root/'mac-update.json').write_text(json.dumps(feed,indent=2)+'\n')
            dest=root/'assets/mac';dest.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(Path(tmp)/'LUA-macOS-previas.zip') as z:
                for name in z.namelist():
                    if re.fullmatch(r'(\d{2}-[a-z-]+|barra|captura|widget-inicio|gravacao)\.png',name):
                        (dest/name).write_bytes(z.read(name))
                for source,target in {'00-home.png':'inicio.png','barra.png':'barra.png','captura.png':'captura.png','09-gallery.png':'galeria.png','11-settings.png':'configuracoes.png'}.items():
                    (dest/target).write_bytes(z.read(source))
            print('Canal e imagens macOS',mac_version,'atualizados')
        elif 'id="macos"' in (root/'index.html').read_text():
            raise RuntimeError('A página Mac exige um pacote Mac já publicado: '+result.stderr)
