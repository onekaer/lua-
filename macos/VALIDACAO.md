# Validação — LUA macOS 0.1.3 Beta

O resultado definitivo dos testes é fornecido pelo GitHub Actions nos arquivos Apple-Silicon/Intel do pacote. Compilação e execução não podem ser realizadas diretamente no Windows usado para o desenvolvimento.

Testes automatizados: caminhos/symlinks, duplicados por conteúdo, preservação de uma cópia, alteração de arquivos entre análise e limpeza, segmentos completos anteriores ao clique, contrato de atualização, SHA-256; preparação real de .app de teste com assinatura local e rejeição de versão divergente; codificação H.264 sintética e exportação de clipe; renderização nativa de todas as páginas e sobreposição.

Sem Mac físico nesta tarefa: não foram testados consentimento TCC, captura real de tela/áudio/microfone, comportamento em jogos, foco/Spaces/full screen, consumo prolongado, hardware Intel/Apple Silicon de usuários, troca de monitores ou Gatekeeper. Prévias usam dados demonstrativos, não medições de jogo.

Recursos sem equivalência nesta beta são indicados no app e README: temperaturas/GPU detalhadas, FPS universal/1% low/DLSS. Não é correto chamar esta beta de 100% validada ou de paridade completa com Windows.

Rodada 0.1.3: adiciona MP4 real sintético com duas trilhas AAC, clipe mixado e histórico MOV exportado em MP4; abertura normal, 12 páginas, ciclos da sobreposição, fechar/reabrir, amostragem e miniatura limitada. Logs do resultado ficam no pacote. O relatório técnico do encerramento original não foi fornecido; não há causa confirmada ou garantia de correção desse incidente.
