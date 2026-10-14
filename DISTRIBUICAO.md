# Distribuição, assinatura e SmartScreen

O LUA está em **beta**. A versão 1.10.2 distribuída pelo GitHub ainda não tem assinatura Authenticode de um editor reconhecido. A verificação local retornou `NotSigned`; não havia certificado de assinatura de código disponível nas lojas pessoais consultadas do Windows.

## Por que aparece “O Windows protegeu o computador”?

O SmartScreen considera a reputação do arquivo e do editor. Um executável novo e não assinado pode aparecer como aplicativo desconhecido. Esse aviso, isoladamente, não equivale a uma detecção de malware e também não certifica a segurança do arquivo.

## O que resolve na distribuição

1. Obter uma identidade de editor e assinatura de código reconhecida, por uma autoridade certificadora ou serviço como Microsoft Artifact Signing. A emissão pode exigir validação de identidade e cobrança.
2. Integrar a assinatura dos executáveis próprios à compilação, antes de gerar hashes e empacotar a versão. Usar SHA-256, carimbo de tempo e conferir a cadeia de confiança. Não alterar os arquivos depois de assinados.
3. Manter a mesma identidade de editor entre versões. Mesmo com assinatura válida, o SmartScreen pode continuar exibindo o aviso enquanto a reputação se forma.
4. Avaliar a publicação pela Microsoft Store. O caminho MSIX da Store pode fornecer a assinatura da Microsoft após certificação; o app e seus componentes precisam atender aos requisitos de distribuição.

Nenhum certificado foi criado artificialmente, e as proteções do Windows não foram alteradas. Certificados autoassinados não resolvem a confiança para os usuários. Não coloque certificados privados, senhas ou tokens no repositório, nos fontes públicos ou em logs. A configuração de um serviço de assinatura depende da identidade e do acesso aprovados pelo mantenedor.

O download oficial continua em [GitHub Releases](https://github.com/onekaer/lua-/releases). A atualização confere a integridade do pacote; essa conferência não substitui a assinatura de editor.

Referência: [Microsoft — SmartScreen reputation for Windows app developers](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).
