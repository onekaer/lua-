# LUA Beta · Desempenhos, capturas e organização

[**Conheça o LUA e baixe a versão atual →**](https://onekaer.github.io/lua-/)

[Baixar pelo GitHub Releases](https://github.com/onekaer/lua-/releases/latest) · [Histórico de versões](https://github.com/onekaer/lua-/releases) · [Canal do atualizador](https://github.com/onekaer/lua-/releases/latest/download/LUA-atualizacoes.json)

**Windows 10/11 x64 · Em beta · Versão atual: 1.10.1**

O app está em desenvolvimento. Sensores, captura de FPS e sobreposições dependem do hardware, das permissões e do jogo. A versão atual ainda não possui assinatura digital de um editor reconhecido e pode receber um aviso do SmartScreen. Veja [distribuição e assinatura](DISTRIBUICAO.md).

![Prévia ilustrativa do LUA durante um jogo, com FPS, CPU e GPU](https://onekaer.github.io/lua-/assets/sobreposicao-jogo.svg?v=1.10.1)

*Cenário original e métricas demonstrativas; não é um benchmark nem uma captura real de jogo. As imagens das interfaces abaixo são do aplicativo.*

O LUA reúne CPU, GPU, RAM, temperaturas disponíveis, FPS, rede e armazenamento em um aplicativo nativo que abre compacto no canto e permanece na bandeja. Tem painel ampliado, abas personalizáveis e sobreposições com atalhos configuráveis.

## Recursos

- Monitoramento de hardware, processos e diagnóstico local.
- Temperatura real da CPU com LibreHardwareMonitor/PawnIO e assistente separado quando necessário.
- FPS automático do jogo reconhecido com PresentMon, sem injeção; 1% low, mínimo e máximo opcionais. Depende de permissão e compatibilidade.
- Tráfego de rede e teste de velocidade.
- Análise de pastas, arquivos grandes, temporários e duplicados com revisão antes da Lixeira.
- Biblioteca de jogos em grade ou lista, capas oficiais quando disponíveis, filtros, Explorar e desinstalação com confirmação.
- Gravação de tela, áudio/microfone, prints e buffer de clipes anteriores ao clique.
- Galeria por tipo/data, player e corte de trecho.
- Atualizador com instalação manual ou automática opcional, integridade e backup.

## Conheça cada área

### Início e hardware

Painel compacto com CPU, GPU, memória, temperaturas disponíveis, rede e espaço livre. Expanda quando quiser mais detalhes ou personalize a barra de abas nas Configurações. A leitura de CPU pode exigir o driver oficial PawnIO e permissão específica para o assistente de sensores.

<img src="https://onekaer.github.io/lua-/assets/inicio.png?v=1.10.1" alt="Início compacto do LUA com temperaturas, hardware e espaço livre" width="340">

### FPS e fluidez

O LUA identifica o jogo reconhecido em foco e acompanha seu FPS com PresentMon, sem uma lista de processos ou botão para iniciar manualmente. Jogos portáteis podem ser adicionados pela pasta da biblioteca. Na imagem, não há jogo ativo: valores ausentes aparecem como `—`. Em Métricas e detecção, escolha 1% low, mínimo e máximo. Mínimo/máximo são as menores/maiores médias de 2 s da sessão; 1% low usa até 600 frames dos últimos 10 s, com mínimo de 100 frames. A presença de uma DLL não confirma DLSS ativo; a comparação com e sem DLSS é manual.

![Página Jogos e FPS com detecção automática, frametime, low, mínimo e máximo](https://onekaer.github.io/lua-/assets/fps.png?v=1.10.1)

### Sobreposição durante o jogo

**Ctrl + Espaço** abre e fecha a sobreposição completa por padrão. Métricas no canto, barra centralizada e janelas flutuantes. A Visão geral mostra FPS acima das temperaturas, com a mesma fonte da CPU/GPU. A leitura é um único FPS geral; low, mínimo e máximo são opcionais. Mover widgets e usar seus botões preserva o foco do jogo. Para escrever em campos, ative Digitar explicitamente. Fora da edição, métricas e janelas fixadas permitem cliques através. A barra superior também aparece nos prints. Janela sem bordas costuma ser o modo mais compatível; tela cheia exclusiva pode impedir a exibição.

A barra mostra os ícones reais do app e Digitar; feche a sobreposição pelo atalho. Capturas reúne Print, clipe e Gravar, com Ver galeria abaixo.

![Barra real da sobreposição do LUA](https://onekaer.github.io/lua-/assets/barra.png?v=1.10.1)

<img src="https://onekaer.github.io/lua-/assets/sobreposicao.png?v=1.10.1" alt="Sobreposição real de hardware; FPS sem captura ativa aparece como traço" width="300">

<img src="https://onekaer.github.io/lua-/assets/inicio-sobreposicao.png?v=1.10.1" alt="Visão geral da sobreposição com FPS acima das temperaturas da CPU e GPU" width="340">

### Capturas e clipes retroativos

Print, gravação comum, áudio/microfone e salvamento do histórico anterior ao clique. Escolha atalhos, qualidade e duração. O buffer precisa estar ativo antes do acontecimento e usa recursos de captura. A gravação comum tem indicador e botão Parar; salvar um clipe usa o histórico existente.

<img src="https://onekaer.github.io/lua-/assets/captura.png?v=1.10.1" alt="Janela compacta de captura com print, clipe, gravação e galeria" width="380">

### Galeria

Vídeos, clipes e prints em áreas separadas. Busque, ordene por data, abra a mídia no player, corte trechos, mostre na pasta ou exclua após revisão. As mídias de demonstração da imagem mostram somente a interface do LUA.

![Galeria com filtros, miniaturas e ações Mostrar na pasta e Excluir](https://onekaer.github.io/lua-/assets/galeria.png?v=1.10.1)

### Jogos instalados

Grade como padrão, com alternativa em lista. Capas oficiais quando disponíveis, busca, filtros por plataforma e tamanho, Explorar e opções de capa no menu. A desinstalação pede confirmação e depende da plataforma; pastas portáteis podem ser adicionadas manualmente.

![Biblioteca de jogos com capas reais, plataformas, tamanhos e pesquisa](https://onekaer.github.io/lua-/assets/jogos.png?v=1.10.1)

### Rede e teste de internet

Tráfego de recebimento e envio, interfaces disponíveis, detalhes da conexão e teste de download, upload e latência. O teste de velocidade utiliza dados de teste da Cloudflare.

![Rede e teste de velocidade na interface do LUA](https://onekaer.github.io/lua-/assets/rede.png?v=1.10.1)

### Armazenamento, limpeza e diagnóstico

Veja o espaço livre e analise pastas, arquivos grandes, temporários antigos e duplicados por conteúdo. A limpeza permite selecionar os itens, marcar tudo e revisar antes de enviar à Lixeira. O diagnóstico reúne dados de memória, processador, rede e discos, com exportação de relatório. Uma leitura isolada não determina um defeito e a análise não substitui testes físicos do hardware.

![Armazenamento com espaço livre e análise de uma pasta de exemplo](https://onekaer.github.io/lua-/assets/armazenamento.png?v=1.10.1)

![Limpeza e duplicados antes da análise, com pasta de exemplo](https://onekaer.github.io/lua-/assets/limpeza.png?v=1.10.1)

*As imagens de armazenamento/limpeza usam C:\Exemplo e não mostram arquivos pessoais.*

![Diagnóstico local do LUA com memória, CPU, espaço livre e conexão](https://onekaer.github.io/lua-/assets/analise.png?v=1.10.1)

### Configurações e atualizações

Seções retráteis para navegação, sobreposições e atalhos. Atualizações ficam no último grupo, junto de Sobre o LUA. Uma versão nova gera notificação e botão azul Atualizar ao lado das Configurações no painel grande ou pequeno no rodapé compacto. Instalar automaticamente é opcional. O atalho de desktop é criado na primeira abertura e pode ser recriado nessa seção.

![Parte final das Configurações: atualização, informações do LUA e atalho de desktop](https://onekaer.github.io/lua-/assets/configuracoes.png?v=1.10.1)

## Instalar

Windows 10/11 x64 com .NET Framework 4.8. Baixe o ZIP completo, extraia toda a pasta e abra `LUA.exe`; o atalho é criado na Área de Trabalho. Se uma versão antiga ainda estiver aberta, use Sair na bandeja antes de abrir a pasta nova, ou utilize o atualizador do próprio app. Mantenha bibliotecas, ícones e ferramentas juntos. Para atualizar uma versão antiga sem canal configurado, use Sair na bandeja antes de abrir a nova.

CPU: clique na temperatura ou abra Hardware para instalar/ativar o PawnIO oficial e aceitar a permissão de leitura. FPS: abra um jogo reconhecido da biblioteca e aceite a permissão de LuaFpsCapture.exe quando solicitada. Cancelar não causa pedidos repetidos: use Reativar detecção de FPS para tentar novamente. A presença de DLL de DLSS não confirma a tecnologia ativa; a comparação disponível é manual.

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
