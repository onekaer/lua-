# LUA: manutenção e publicação

O usuário autorizou publicar as atualizações do LUA em onekaer/lua- e manter sua página com download e imagens. Preserve esta publicação como parte de futuras atualizações do app.

- Extraia lua-source.zip para editar app/src, app/icons e site; o pacote base é somente o cache imutável de dependências.
- Incremente as versões em AssemblyInfo.cs, AppUpdates.cs, manifest e release.json de forma consistente. Não sobrescreva uma versão publicada.
- Faça os testes locais apropriados, atualize guias e imagens e remonte lua-source.zip.
- Envie fontes e release.json na mesma atualização da main; o workflow compila/publica a versão e a página automaticamente.
- Não publique settings.json, dados de usuário, gravações reais, relatórios privados, diretórios work, credenciais ou executáveis externos sem os avisos exigidos.
- Preserve a instalação automática como opção do usuário. Nunca invente temperaturas/FPS nem afirme compatibilidade universal.

## Edição macOS

A edição nativa está em outputs/LUA-macOS; seus fontes públicos também ficam em macos/ no repositório e em macos/ dentro de lua-source.zip. Ao gerar o pacote de fontes, preserve app/ (Windows), macos/ e site/. Não remova uma plataforma ao atualizar a outra.

A versão Mac é independente da versão Windows: mantenha Model.version e mac-release.json iguais. O workflow macos.yml compila/testa em Apple Silicon e Intel, monta o app universal e publica mac-v<VERSAO>, sem alterar o latest do Windows. O canal Mac fica em mac-update.json no GitHub Pages; prepare-site.py busca o manifesto e as prévias nativas da release Mac. Versões publicadas são imutáveis.

Para macOS, preserve os limites declarados: FPS via HUD Metal em jogos compatíveis; sem FPS universal/1% low/DLSS e sem temperatura/GPU detalhada garantida por APIs públicas. Captura real, TCC, foco em jogos e desempenho exigem validação em Mac físico; testes de runners e imagens demonstrativas não provam esses cenários. Não declare paridade completa ou 100% de compatibilidade sem evidência.