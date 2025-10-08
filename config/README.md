# 📂 Configurações Detalhadas - Setup Dev

Este arquivo contém a documentação completa das configurações incluídas no projeto.

## 🔧 PowerShell Profile - Configuração e Uso

### **Arquivo**: `powershell-profile.ps1`

### 📋 **O que é o PowerShell Profile?**
O PowerShell Profile é um script que executa automaticamente sempre que você abre uma nova sessão do PowerShell, carregando funções personalizadas, aliases e configurações.

### ⚙️ **Como Configurar o Profile**

#### **Método 1 - Automático (Recomendado)**
```powershell
# O setup.ps1 configura automaticamente, mas você pode fazer manualmente:
# 1. Verificar se existe profile atual
Test-Path $PROFILE

# 2. Criar backup se existir
if (Test-Path $PROFILE) {
    Copy-Item $PROFILE "$PROFILE.backup-$(Get-Date -Format 'yyyy-MM-dd')"
}

# 3. Aplicar o novo profile
$sourcePath = "C:\{Caminho\Para\Projeto}\setup-dev\config\powershell-profile.ps1"
Copy-Item $sourcePath $PROFILE
```

#### **Método 2 - Manual**
1. Abra o PowerShell como administrador
2. Execute: `notepad $PROFILE`
3. Cole o conteúdo de `powershell-profile.ps1`
4. Salve e reinicie o PowerShell

### 🎯 **Funções Disponíveis**

#### **Funções do Sistema**
- **`Write-Log`** (alias: `log`) - Sistema de logs colorido
  ```powershell
  log "Mensagem de info" -Level "Info"
  log "Erro crítico" -Level "Error"
  log "Sucesso!" -Level "Success"
  ```

- **`Test-IsAdmin`** (alias: `adm`) - Verificar privilégios
  ```powershell
  adm                    # Mostra ADMINISTRADOR ou USUARIO
  adm -ReturnBool        # Retorna $true ou $false
  ```

#### **Funções de Desenvolvimento**
- **`Activate-VirtualEnvironment`** (alias: `venv`) - Ativar ambiente virtual Python
  ```powershell
  venv                   # Ativa .venv na pasta atual
  ```

- **`New-ProjectStructure`** (alias: `mkp`) - Criar estrutura de projeto
  ```powershell
  mkp "MeuProjeto"              # Estrutura básica
  mkp "MeuProjeto" -Nivel 0     # Estrutura mínima
  mkp "MeuProjeto" -Nivel 2     # Estrutura completa
  ```

- **`Test-ApiEndpoint`** (alias: `api`) - Testar APIs
  ```powershell
  api "http://localhost:8000"
  api "https://api.github.com" -TimeoutSeconds 5
  ```

- **`Open-VSCodeWorkspace`** (alias: `cdr`) - Abrir VS Code
  ```powershell
  cdr                    # Abre VS Code na pasta atual
  cdr "C:\MeuProjeto"    # Abre VS Code em pasta específica
  ```

### 🔄 **Recarregar Profile**
Após fazer alterações, recarregue sem reiniciar:
```powershell
. $PROFILE
```

### 🛠️ **Personalização do Profile**

#### **Adicionar Suas Funções**
Edite `powershell-profile.ps1` e adicione no final:
```powershell
# SUAS FUNCOES PERSONALIZADAS
function Minha-Funcao {
    param([string]$Parametro)
    Write-Host "Olá, $Parametro!" -ForegroundColor Green
}
Set-Alias -Name "mf" -Value "Minha-Funcao"
```

#### **Modificar Aliases Existentes**
```powershell
# Exemplo: mudar alias 'api' para 'test'
Set-Alias -Name "test" -Value "Test-ApiEndpoint"
```

## 🎨 VS Code Settings - Configuração Detalhada

### **Arquivo**: `vscode-settings.json`

### 📋 **Configurações Principais**

#### **Interface e Tema**
```json
{
  "workbench.colorTheme": "One Dark Pro",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontFamily": "Fira Code, JetBrains Mono, Consolas, 'Courier New'",
  "editor.fontSize": 16,
  "editor.fontLigatures": true
}
```

#### **Formatação e Edição**
```json
{
  "editor.tabSize": 4,
  "editor.formatOnSave": true,
  "editor.rulers": [80, 120],
  "editor.wordWrap": "on"
}
```

#### **Configurações por Linguagem**
```json
{
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.rulers": [88, 120]
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
```

### 🔧 **Como Personalizar Settings**

#### **Adicionar Nova Configuração**
1. Abra VS Code Settings (`Ctrl + ,`)
2. Clique no ícone `{}` (Open Settings JSON)
3. Adicione sua configuração:
```json
{
  "editor.minimap.enabled": false,
  "workbench.colorTheme": "SeuTema"
}
```

#### **Configurações Específicas por Projeto**
Crie `.vscode/settings.json` na raiz do projeto:
```json
{
  "python.defaultInterpreterPath": "./venv/Scripts/python.exe",
  "eslint.workingDirectories": ["./frontend"]
}
```

### 🎯 **Configurações Recomendadas Extras**

#### **Para Python**
```json
{
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": true,
  "python.formatting.blackArgs": ["--line-length=88"],
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false
}
```

#### **Para JavaScript/TypeScript**
```json
{
  "typescript.preferences.importModuleSpecifier": "relative",
  "javascript.preferences.importModuleSpecifier": "relative",
  "eslint.format.enable": true
}
```

#### **Para Performance**
```json
{
  "files.exclude": {
    "**/__pycache__": true,
    "**/node_modules": true,
    "**/.git/objects/**": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/.venv": true
  }
}
```

## 🔌 Extensões VS Code - Gerenciamento

### **Arquivo**: `extensions.txt`

### 📋 **Extensões Incluídas**

#### **Linguagens Core**
- `ms-python.python` - Suporte completo Python
- `ms-python.black-formatter` - Formatação Python
- `ms-python.vscode-pylance` - IntelliSense avançado Python
- `ms-python.debugpy` - Debug para pytest e desenvolvimento
- `esbenp.prettier-vscode` - Formatação JS/TS/HTML/CSS
- `dbaeumer.vscode-eslint` - Linting JavaScript/TypeScript

#### **Temas e Interface**
- `zhuangtongfa.material-theme` - One Dark Pro
- `pkief.material-icon-theme` - Material Icons
- `ms-ceintl.vscode-language-pack-pt-br` - Interface em português

#### **Ferramentas de Desenvolvimento**
- `ms-vscode.powershell` - Suporte PowerShell
- `redhat.vscode-yaml` - Editor YAML
- `ms-vscode.vscode-json` - Editor JSON melhorado
- `ms-vscode.vscode-typescript-next` - TypeScript avançado
- `formulahendry.code-runner` - Execução rápida de código

#### **Produtividade**
- `github.copilot` - IA para código
- `github.copilot-chat` - Chat com IA
- `formulahendry.auto-rename-tag` - Renomear tags HTML
- `christian-kohler.path-intellisense` - Autocomplete de paths

#### **Web Development**
- `bradlc.vscode-tailwindcss` - TailwindCSS IntelliSense
- `ms-vscode-remote.remote-wsl` - Desenvolvimento com WSL

### 🔧 **Gerenciar Extensões**

#### **Adicionar Nova Extensão**
1. Adicione o ID da extensão ao `extensions.txt`:
```txt
nova-extensao.id
```

2. Instale manualmente:
```powershell
code --install-extension nova-extensao.id
```

#### **Remover Extensão**
1. Remova a linha do `extensions.txt`
2. Desinstale:
```powershell
code --uninstall-extension extensao.id
```

#### **Instalar Todas as Extensões**
```powershell
# Ler arquivo e instalar cada uma
Get-Content "config\extensions.txt" | ForEach-Object {
    if ($_ -and $_ -notmatch "^#") {
        code --install-extension $_
    }
}
```

## 📦 Software.json - Lista de Softwares

### **Arquivo**: `software.json`

### 📋 **Estrutura do Arquivo**
```json
{
  "metadata": {
    "version": "1.0.0",
    "description": "Setup essencial para desenvolvimento"
  },
  "software": {
    "vscode": {
      "name": "Visual Studio Code",
      "chocolatey": { "packageName": "vscode" },
      "portable": { "downloadUrl": "..." }
    }
  }
}
```

### 🔧 **Adicionar Novo Software**
```json
{
  "meu-software": {
    "name": "Meu Software",
    "description": "Descrição do software",
    "version": "1.0.0",
    "chocolatey": {
      "packageName": "meu-software"
    },
    "portable": {
      "downloadUrl": "https://exemplo.com/download.zip",
      "filename": "software.zip",
      "extractFolder": "MeuSoftware",
      "executable": "app.exe"
    }
  }
}
```

## 🚀 Dicas de Uso Avançado

### **Sincronizar Entre Máquinas**
```powershell
# Exportar configurações atuais
$settingsPath = "$env:APPDATA\Code\User\settings.json"
Copy-Item $settingsPath "backup-settings.json"

# Exportar lista de extensões
code --list-extensions > "my-extensions.txt"
```

### **Verificar Status das Configurações**
```powershell
# Profile ativo
$PROFILE
Test-Path $PROFILE

# Configurações VS Code
$vscodePath = "$env:APPDATA\Code\User\settings.json"
Test-Path $vscodePath

# Extensões instaladas
code --list-extensions
```

### **Troubleshooting**

#### **PowerShell Profile**
```powershell
# Recarregar profile
. $PROFILE

# Verificar erros no profile
$Error[0] | Format-List -Force

# Testar função específica
Test-Path (Get-Command venv).Source
```

#### **VS Code + Python**
```powershell
# Verificar Pylance ativo
code --list-extensions | findstr pylance

# Resetar configurações VS Code
Move-Item "$env:APPDATA\Code\User\settings.json" "settings-backup.json"

# Verificar interpretador Python
# No VS Code: Ctrl+Shift+P → "Python: Select Interpreter"
```

#### **Debugging Issues**
- **pytest não funciona**: Instale `debugpy` com `pip install debugpy`
- **Code Runner não executa**: Verifique se Python está no PATH
- **Pylance lento**: Desative outras extensões Python conflitantes

---

**Para voltar à documentação principal: [`setup-dev`](../)**