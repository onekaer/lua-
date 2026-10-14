# LUA para macOS 0.1.4 Beta

Aplicativo nativo SwiftUI/AppKit, para macOS 15 ou posterior. Binário universal Apple Silicon e Intel. Código próprio sob MIT, sem dependências binárias do Windows.

## Instalar

Extraia o ZIP completo, abra mac-package e mova LUA.app para Aplicativos. O app permanece na barra de menus ao fechar a janela. A beta tem assinatura local ad hoc para integridade, mas não uma assinatura Developer ID/notarização da Apple. O Gatekeeper pode bloquear a abertura. Confira a origem; não desative as proteções do sistema. A distribuição sem avisos exige identidade de desenvolvedor e notarização.

## Captura e permissões

Autorize a gravação da tela/áudio em Ajustes do Sistema → Privacidade e Segurança. O microfone é opcional e pede permissão separada. A gravação de tela só começa após a autorização, e nas próximas aberturas o histórico se prepara automaticamente quando a permissão já foi concedida. Indicadores de privacidade do macOS permanecem ativos.

Print, gravação comum e clipes usam ScreenCaptureKit e AVFoundation. Gravações e clipes em MP4, H.264 até 1080p, 30 fps; áudio AAC. Os segmentos temporários do histórico continuam em MOV e não são o vídeo final. O buffer armazena até aproximadamente 120 s, em segmentos temporários de 3 s. O clipe usa somente segmentos completos anteriores: pode terminar até 3 s antes do clique. Nada que ocorreu antes de ativar o histórico pode ser recuperado. Gravação comum e buffer são independentes. A gravação tem indicador com Parar; clipes notificam ao terminar. Sistema e microfone são trilhas independentes no MP4; o MP4 de clipe mixa as trilhas.

Atalhos: Control + Espaço abre/fecha sobreposição; Command + Shift + P tira print; Command + Shift + R inicia/para gravação; Command + Shift + F8 salva clipe. O atalho da sobreposição pode ser alterado para evitar conflito com a troca de idioma do macOS. Fechar o painel não encerra o app; Sair fica na barra de menus.

## Adaptações

- CPU e memória: APIs Mach; memória ativa/cabeada/comprimida, definição diferente do Windows.
- Rede: Wi-Fi/Ethernet en*, sem somar VPNs virtuais duas vezes. Teste HTTPS opcional com Cloudflare (10 MB download + 2 MB upload).
- Armazenamento: espaço do volume pessoal, análise de pastas pessoais e duplicados por SHA-256, marcação e confirmação antes da Lixeira. Apps/pacotes, links simbólicos, Library e pastas ocultas são excluídos. Duplicados preservam uma cópia.
- Jogos: apps adicionados manualmente e .app encontrados na pasta padrão da Steam. Abrir, explorar e remover da biblioteca com confirmação; remover não desinstala os arquivos.
- FPS: abre jogos compatíveis com MTL_HUD_ENABLED=1. O HUD da Apple mede FPS Metal no próprio jogo. Launchers podem não repassar a configuração. Não há medição universal no LUA, 1% low/mínimo/máximo ou detecção DLSS/MetalFX nesta beta.
- Sensores: estado térmico do sistema; temperatura em °C, ventoinhas e uso da GPU não são fornecidos por uma API pública universal. Leituras indisponíveis são declaradas.
- Sobreposição: painéis sem ativação, móveis e fixáveis; fixados permitem clique através fora da edição. Digitar autoriza foco explicitamente. Full screen/Spaces/jogos reais precisam de validação adicional.
- Galeria: vídeos/clipes/prints locais, busca, miniaturas, player e Lixeira com confirmação. Player com recorte de trechos preservando o original; capas personalizadas no menu do jogo.
- Atualizações: canal Mac separado do Windows, HTTPS oficial, tamanho e SHA-256. Instalação automática opcional quando LUA.app está em Aplicativos com permissão de escrita; extração e assinatura local conferidas, versão validada e backup preservado. Fora de Aplicativos, o pacote verificado fica em Downloads para instalação manual.

## Verificação

O GitHub Actions compila e executa testes em macOS Apple Silicon e Intel. Testes incluem segurança de caminhos/links, duplicados, arquivos modificados após análise, seleção de segmentos retroativos, canal e hash, geração real de vídeo sintético H.264 e exportação de clipe. Imagens são renderizadas pelo próprio app com dados demonstrativos. Testes não equivalem a gravação do desktop, consentimento TCC ou benchmark de jogo num Mac físico.

Compilar em um Mac com Xcode Command Line Tools: `swift test` e `swift build -c release`. O executável fica no caminho informado por `swift build -c release --show-bin-path`. O workflow monta o .app, combina as duas arquiteturas e verifica assinatura local.

Fontes Apple: [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos) e [Metal Performance HUD](https://developer.apple.com/videos/play/tech-talks/110339/).

## Estabilidade e consumo na beta 0.1.4

Miniaturas de prints são reduzidas para até 440 px antes da decodificação, em trabalho separado da interface. Captura mantém três buffers de tela e limita segmentos simultâneos em finalização a dois, com descarte de objetos temporários a cada callback. Em disco lento o histórico pode ter intervalos; a gravação comum continua independente. Alterações de áudio aguardam a parada da sessão anterior; callbacks antigos são descartados. A lista de aplicativos é renovada a cada 10 s. Salvar um print ou falhar outra ação não libera uma exportação de clipe ainda ativa.

A causa do encerramento informado não foi determinada sem o relatório de falha. Esses ajustes corrigem riscos encontrados no código; não provam que todo encerramento foi resolvido. Os testes do pacote verificam abertura normal, navegação, ciclos da sobreposição, fechar/reabrir, miniatura e bloqueio de exportação, além do MP4 sintético com duas trilhas AAC e clipe mixado. Captura/TCC/jogos em Mac físico continuam pendentes.

## Indicador de gravação

O indicador usa o visual do Windows: ponto vermelho, REC, tempo decorrido, estado do histórico e botão Parar. A janela não ativa o teclado do jogo. Ao finalizar, mostra Salvando e aguarda o MP4.

O ScreenCaptureKit exclui somente a janela desse indicador do fluxo que alimenta o vídeo, o histórico e os prints do LUA. Antes de exibir o indicador, a entrega de amostras é pausada; o filtro é atualizado pelo ID da janela e o gravador só inicia após a confirmação. Quadros anteriores à retomada são descartados. Se o filtro não puder ser preparado, a gravação não começa e o indicador é recolhido. Os demais painéis da sobreposição continuam capturáveis. Isso se aplica às capturas feitas pelo LUA; não controla gravadores externos.

Base: [filtro de janelas da Apple](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(display:excludingwindows:)). Compilação, estado de interface e bloqueios são verificáveis em CI. A exclusão visual no vídeo real e o comportamento em jogos ainda exigem validação com permissão de captura em Mac físico.
