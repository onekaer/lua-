from pathlib import Path
import json, sys, re
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
