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

A versão de Windows utiliza a stack do **Tauri**, que combina os benefícios e a performance de um backend em Rust, com a flexibilidade da construção de telas usando tecnologias web (React/Vite).

### Pré-requisitos
Para o desenvolvimento com Tauri e Rust no Windows, é necessário configurar algumas ferramentas no seu sistema:

1. **Node.js**: (versão 18 ou superior). Utilizado para rodar o frontend React. [Baixar Node.js](https://nodejs.org/)
2. **Rust & Cargo**: Ferramenta de build do backend. Instale executando o Instalador via `rustup`. [Baixar instalador Rust](https://rustup.rs/)
3. **Microsoft Visual Studio C++ Build Tools**: Requisito essencial para compilar o Rust no Windows. 
   - Ao executar o instalador do `rustup`, ele normalmente avisa ou conduz a instalação automaticamente.
   - Se precisar instalar manualmente, [baixe o Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/), execute o instalador e assegure-se de selecionar a opção **"Desenvolvimento para desktop com C++"**.

### Passos para rodar localmente
1. **Clone o repositório:**
   Feito de preferência pelo Prompt de Comando ou PowerShell:
   ```bash
   git clone <URL_DO_REPOSITORIO>
   cd "Mae - WindowsPort"
   ```

2. **Navegue até o diretório da versão Windows:**
   ```bash
   cd mae-windows
   ```

3. **Instale as dependências do frontend (React/Vite):**
   ```bash
   npm install
   ```

4. **Execute o projeto em modo de desenvolvimento:**
   O Tauri irá compilar a aplicação em janela e iniciar o servidor Vite automaticamente mostrando as atualizações de interface em tempo real:
   ```bash
   npm run tauri dev
   ```
   *(Atenção: A primeira compilação do Rust irá demorar mais tempo, pois ele fará o download e a compilação do zero de todas as bibliotecas necessárias).*

### Compilando para Produção (Gerar executável .exe)
Quando quiser construir a versão final da sua aplicação para instalar ou distribuir aos usuários, rode na pasta `mae-windows`:
```bash
npm run tauri build
```
Após o processo de build, o instalador e o executável final `.exe` serão encontrados na pasta: `src-tauri/target/release/bundle/`.
