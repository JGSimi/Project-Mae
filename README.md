# Mãe

**Uma assistente de IA que mora na sua barra de menus.** Discreta, rápida e sempre a um clique de distância — sem janelas extras, sem distrações. Ela está ali quando você precisa e desaparece quando não precisa.

## Funcionalidades

- **Sempre disponível, nunca no caminho** — Vive na barra de menus do macOS. Um clique abre, um clique fecha. Sem janelas ocupando espaço na sua tela.
- **Análise Inteligente de Tela** — Captura o que está na sua tela e oferece ajuda contextual automaticamente. Está lendo um currículo? Ela dá dicas. Vendo código? Ela encontra bugs.
- **Processamento Instantâneo da Área de Transferência** — Copie qualquer texto ou imagem e deixe a Mãe processar por você com um atalho. A resposta volta direto para a sua área de transferência.
- **Suporte a Anexos** — Arraste imagens, PDFs, códigos ou qualquer arquivo de texto direto no chat.
- **Respostas Formatadas** — Tudo renderizado em Markdown para facilitar a leitura.

---

## 🍏 Guia de Instalação para macOS

A versão para Mac é um aplicativo nativo Swift e requer o ambiente de desenvolvimento da Apple.

### Pré-requisitos
- Um Mac rodando macOS 13 ou superior.

### Passos para instalação
1. Vá até a página de **[Releases](../../releases/latest)** do repositório no GitHub.
2. Baixe o arquivo `.zip` ou `.dmg` da versão mais recente para macOS.
3. Extraia o aplicativo (se for um `.zip`) e mova o aplicativo `Mae` para a pasta **Aplicativos** (Applications).
4. Como o aplicativo ainda não possui a assinatura de desenvolvedor da Apple (Apple Developer Program), o macOS pode bloquear a execução por medidas de segurança (Gatekeeper).
5. Para liberar a execução, abra o **Terminal** e rode o seguinte comando:
   ```bash
   xattr -cr /Applications/Mae.app
   ```
   *(Atenção: substitua `/Applications/Mae.app` pelo caminho correto caso você tenha extraído o aplicativo em outra pasta).*
6. Pronto! Agora você pode abrir o Mae normalmente pelo Launchpad ou clicando duas vezes no aplicativo.
---

## 🪟 Guia de Instalação para Windows (Instavel e não recomendado)

(EM BREVE)
