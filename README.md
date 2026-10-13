# LUA · Monitoramento, capturas e jogos para Windows

[**Conheça o LUA e baixe a versão atual →**](https://onekaer.github.io/lua-/)

[Baixar pelo GitHub Releases](https://github.com/onekaer/lua-/releases/latest) · [Histórico de versões](https://github.com/onekaer/lua-/releases) · [Canal do atualizador](https://github.com/onekaer/lua-/releases/latest/download/LUA-atualizacoes.json)

![Painel compacto do LUA](https://onekaer.github.io/lua-/assets/inicio.png)

O LUA reúne CPU, GPU, RAM, temperaturas disponíveis, FPS, rede e armazenamento em um aplicativo nativo que abre compacto no canto e permanece na bandeja. Tem painel ampliado, abas personalizáveis e sobreposições com atalhos configuráveis.

## Recursos

- Monitoramento de hardware, processos e diagnóstico local.
- Temperatura real da CPU com LibreHardwareMonitor/PawnIO e assistente separado quando necessário.
- FPS por processo com PresentMon, sem injeção; depende de permissão e compatibilidade.
- Tráfego de rede e teste de velocidade.
- Análise de pastas, arquivos grandes, temporários e duplicados com revisão antes da Lixeira.
- Biblioteca de jogos em grade ou lista, capas oficiais quando disponíveis, filtros, Explorar e desinstalação com confirmação.
- Gravação de tela, áudio/microfone, prints e buffer de clipes anteriores ao clique.
- Galeria por tipo/data, player e corte de trecho.
- Atualizador com instalação manual ou automática opcional, integridade e backup.

## Instalar

Windows 10/11 x64 com .NET Framework 4.8. Baixe o ZIP completo, extraia toda a pasta e abra `LUA.exe`. Mantenha bibliotecas, ícones e ferramentas juntos. Para atualizar uma versão antiga sem canal configurado, use Sair na bandeja antes de abrir a nova.

CPU: clique na temperatura ou abra Hardware para instalar/ativar o PawnIO oficial e aceitar a permissão de leitura. FPS: selecione o processo do jogo em Jogos e FPS e aceite a permissão de LuaFpsCapture.exe. A presença de DLL de DLSS não confirma a tecnologia ativa; a comparação disponível é manual.

O buffer só guarda o que ocorreu enquanto estava ativo e consome recursos de captura. Clipes podem terminar cerca de 1 s antes do clique porque o último segmento aberto é excluído. Tela cheia exclusiva pode impedir a sobreposição; prefira janela sem bordas.

## Atualizações e publicação automática

Configure este endereço em Configurações → Atualizações → Origem:

```text
https://github.com/onekaer/lua-/releases/latest/download/LUA-atualizacoes.json
```

`lua-source.zip` contém **somente fontes, ícones, guias e a página**, sem dados pessoais, configurações de usuário ou vídeos de testes. Extraia para inspecionar/editar `app/src` e `site`. `release.json` declara a nova versão e o pacote base de dependências com SHA-256.

Ao enviar uma versão nova de `lua-source.zip` e incrementar `release.json` na branch main, o GitHub Actions compila, confere o pacote, publica o ZIP e o JSON de atualização e atualiza o site. Versões já publicadas não são sobrescritas. A primeira versão foi validada localmente em hardware real; o CI testa compilação, arquivos, recursos e parsers, e não substitui testes em jogos/dispositivos reais.

O workflow também pode ser executado em Actions → Publicar LUA e atualizar página. GitHub Pages deve usar GitHub Actions como origem.

## Componentes e licenças

LibreHardwareMonitor, PresentMon, FFmpeg, NAudio e ícones Fluent mantêm seus avisos no pacote, em `THIRD-PARTY.md` e `licenses`. O PawnIO é obtido separadamente da distribuição oficial e instalado somente mediante escolha do usuário. Os fontes próprios estão em `lua-source.zip` e no pacote do aplicativo.
