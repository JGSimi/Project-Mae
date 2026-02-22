# Mae

Bem-vindo ao repositório do **Mae**, uma aplicação de chat com modelos de IA. Este projeto possui duas portabilidades com bases de código distintas para oferecer a experiência mais otimizada e nativa em seus respectivos sistemas operacionais:

- **macOS:** Desenvolvido nativamente utilizando Swift e SwiftUI.
- **Windows:** Desenvolvido utilizando o framework Tauri (Rust) com um frontend moderno em React e TypeScript.

Abaixo, você encontrará guias detalhados de como configurar o ambiente e rodar o projeto em ambas as plataformas.

---

## 🍏 Guia de Instalação para macOS

A versão para Mac é um aplicativo nativo Swift e requer o ambiente de desenvolvimento da Apple.

### Pré-requisitos
- Um Mac rodando macOS 13 ou superior.
- **Xcode** instalado (versão mais recente disponível gratuitamente na Mac App Store).

### Passos para rodar localmente
1. **Clone o repositório:**
   ```bash
   git clone <URL_DO_REPOSITORIO>
   cd "Mae - WindowsPort"
   ```

2. **Abra o projeto no Xcode:**
   Navegue até a pasta `Mae` e abra o arquivo principal do projeto:
   ```bash
   open Mae/Mae.xcodeproj
   ```
   *(Alternativamente, você pode abrir o Finder, entrar na pasta `Mae` e dar um duplo clique no arquivo `Mae.xcodeproj`).*

3. **Configure a assinatura do aplicativo (Sign & Capabilities):**
   - Com o Xcode aberto, clique no projeto `Mae` na barra de navegação lateral esquerda (topo).
   - Vá até a aba **Signing & Capabilities**.
   - No campo **Team**, selecione a sua conta de desenvolvedor conectada ao Xcode ou configure um perfil pessoal (Personal Team) para conseguir rodar localmente.

4. **Compile e Rode:**
   - Selecione o seu Mac como dispositivo de destino (Target Device) na parte superior central da janela do Xcode.
   - Clique no botão de "Play" (Run) no canto superior esquerdo ou simplesmente pressione `Cmd + R` para compilar e iniciar a aplicação.

---

## 🪟 Guia de Instalação para Windows

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

---

## 🛠 Estrutura do Repositório

Aqui está um resumo condensado da organização dos arquivos:

```text
├── Mae/                   # Código fonte da versão nativa do macOS
│   ├── Mae.xcodeproj      # Arquivo de projeto do Xcode
│   └── ...                # Arquivos fontes em .swift
│
├── mae-windows/           # Código fonte da versão do Windows
│   ├── src/               # Frontend construido em React/TypeScript
│   ├── src-tauri/         # Backend escrito em Rust (Core da janela e sistema)
│   ├── package.json       # Configurações do ambiente Node e scripts utilitários
│   └── ...
│
└── README.md              # Documentação principal
```
