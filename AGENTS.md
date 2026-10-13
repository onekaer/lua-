# LUA: manutenção e publicação

O usuário autorizou publicar as atualizações do LUA em onekaer/lua- e manter sua página com download e imagens. Preserve esta publicação como parte de futuras atualizações do app.

- Extraia lua-source.zip para editar app/src, app/icons e site; o pacote base é somente o cache imutável de dependências.
- Incremente as versões em AssemblyInfo.cs, AppUpdates.cs, manifest e release.json de forma consistente. Não sobrescreva uma versão publicada.
- Faça os testes locais apropriados, atualize guias e imagens e remonte lua-source.zip.
- Envie fontes e release.json na mesma atualização da main; o workflow compila/publica a versão e a página automaticamente.
- Não publique settings.json, dados de usuário, gravações reais, relatórios privados, diretórios work, credenciais ou executáveis externos sem os avisos exigidos.
- Preserve a instalação automática como opção do usuário. Nunca invente temperaturas/FPS nem afirme compatibilidade universal.
