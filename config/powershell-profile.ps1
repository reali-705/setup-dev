#==============================================================================
# PERFIL PERSONALIZADO DO POWERSHELL - DESENVOLVIMENTO  
#==============================================================================
# Autor: Reali-705
# Versao: 2.0.1 - Corrigido
# Data: 06/10/2025
# Descricao: Perfil completo com funcoes essenciais + funcoes de desenvolvimento.
#           Separado do setup.ps1 para melhor organizacao.
#==============================================================================

#------------------------------------------------------------------------------
# FUNCOES ESSENCIAIS DO SISTEMA
#------------------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $Colors = @{
        "Info" = "White"
        "Warning" = "Yellow"  
        "Error" = "Red"
        "Success" = "Green"
    }
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Colors[$Level]
}

function Test-IsAdmin {
    param(
        [switch]$ReturnBool,
        [switch]$ReturnUser
    )
    
    $CurrentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $IsAdmin = $CurrentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($ReturnBool) {
        return $IsAdmin
    } elseif ($ReturnUser) {
        if ($IsAdmin) {
            return "ADMINISTRADOR"
        } else {
            return "USUARIO"
        }
    } else {
        if ($IsAdmin) {
            Write-Host "ADMINISTRADOR" -ForegroundColor Green
        } else {
            Write-Host "USUARIO" -ForegroundColor Yellow
        }
    }
}

#------------------------------------------------------------------------------
# FUNCOES DE DESENVOLVIMENTO
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# FUNCAO: Activate-VirtualEnvironment
# DESCRICAO: Ativa o ambiente virtual Python (.venv) na pasta atual
# PARAMETROS: Nenhum
# USO: venv
# ALIAS: venv
#------------------------------------------------------------------------------
function Activate-VirtualEnvironment {
    [CmdletBinding()]
    param()
    
    # Define o caminho para o script de ativacao do ambiente virtual
    $venvPath = Join-Path -Path (Get-Location) -ChildPath ".venv\Scripts\Activate.ps1"
    
    if (Test-Path -Path $venvPath) {
        try {
            # Ativa o ambiente virtual
            & $venvPath
            Write-Log "[SUCESSO] Ambiente virtual ativado com sucesso." -Level "Success"
        }
        catch {
            Write-Log "[ERRO] Erro ao ativar o ambiente virtual: $($_.Exception.Message)" -Level "Error"
        }
    }
    else {
        Write-Log "[AVISO] Ambiente virtual (.venv) nao encontrado na pasta atual: $(Get-Location)" -Level "Warning"
        Write-Host "  Para criar um ambiente virtual, execute: python -m venv .venv" -ForegroundColor Gray
    }
}

#------------------------------------------------------------------------------
# FUNCAO: New-ProjectStructure
# DESCRICAO: Cria estrutura de pastas e arquivos para um novo projeto
# PARAMETROS: 
#   -Nome: Nome do projeto (obrigatorio)
#   -Nivel: Nivel de complexidade da estrutura (0, 1 ou 2 - padrao: 2)
# USO: mkp -Nome "MeuProjeto" [-Nivel 2]
# ALIAS: mkp
#------------------------------------------------------------------------------
function New-ProjectStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Nome,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, 1, 2)]
        [int]$Nivel = 2
    )
    
    # Validacao do nome do projeto
    if ($Nome -match '[<>:"/\\|?*]') {
        Write-Log "[ERRO] Nome do projeto contem caracteres invalidos." -Level "Error"
        Write-Host "  Caracteres nao permitidos: < > : / \ | ? *" -ForegroundColor Gray
        return
    }
    
    Write-Log "[PROJETO] Criando projeto '$Nome' com nivel de estrutura '$Nivel'..." -Level "Info"
    
    # Define o caminho completo do projeto no diretorio atual
    $projetoPath = Join-Path -Path (Get-Location) -ChildPath $Nome
    
    # Verifica se o diretorio ja existe
    if (Test-Path -Path $projetoPath) {
        Write-Log "[AVISO] O diretorio '$Nome' ja existe no local atual. Operacao cancelada." -Level "Warning"
        return
    }
    
    try {
        # Cria o diretorio principal do projeto
        New-Item -ItemType Directory -Path $projetoPath -Force | Out-Null
        Write-Log "[SUCESSO] Diretorio principal criado." -Level "Success"
        
        # Navega para o diretorio do projeto
        Push-Location -Path $projetoPath
        
        # Cria estrutura basica (nivel 0+)
        Write-Log "[INFO] Criando estrutura basica..." -Level "Info"
        New-Item -ItemType File -Path "README.md" -Value "# $Nome`r`n`r`nDescricao do projeto aqui.`r`n" -Force | Out-Null
        New-Item -ItemType File -Path ".gitignore" -Value "# Arquivos temporarios`r`n*.tmp`r`n*.log`r`n`r`n# Dependencias`r`nnode_modules/`r`n__pycache__/`r`n" -Force | Out-Null
        New-Item -ItemType Directory -Path "src" -Force | Out-Null
        
        # Estrutura intermediaria (nivel 1+)
        if ($Nivel -ge 1) {
            Write-Log "[INFO] Criando estrutura intermediaria..." -Level "Info"
            New-Item -ItemType Directory -Path "dist", "tests" -Force | Out-Null
            Add-Content -Path ".gitignore" -Value "`r`n# Build outputs`r`ndist/`r`nbuild/`r`n"
        }
        
        # Estrutura avancada (nivel 2)
        if ($Nivel -eq 2) {
            Write-Log "[INFO] Criando estrutura avancada..." -Level "Info"
            New-Item -ItemType Directory -Path "docs", "assets", "scripts", ".github" -Force | Out-Null
            
            # Cria arquivo basico de configuracao do GitHub Actions
            $githubPath = Join-Path -Path ".github" -ChildPath "workflows"
            New-Item -ItemType Directory -Path $githubPath -Force | Out-Null
        }
        
        Write-Log "[SUCESSO] Projeto '$Nome' criado com sucesso!" -Level "Success"
        Write-Log "[INFO] Localizacao: $projetoPath" -Level "Info"
    }
    catch {
        Write-Log "[ERRO] Erro ao criar a estrutura do projeto: $($_.Exception.Message)" -Level "Error"
    }
    finally {
        # Retorna ao diretorio anterior
        Pop-Location -ErrorAction SilentlyContinue
    }
}

#------------------------------------------------------------------------------
# FUNCAO: Test-ApiEndpoint
# DESCRICAO: Testa se um endpoint de API esta online e respondendo
# PARAMETROS: 
#   -Uri: URL do endpoint a ser testado (obrigatorio)
#   -TimeoutSeconds: Timeout em segundos (padrao: 10)
# USO: Test-ApiEndpoint "http://127.0.0.1:8000" [-TimeoutSeconds 15]
# ALIAS: api
#------------------------------------------------------------------------------
function Test-ApiEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [uri]$Uri,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 10
    )
    
    Write-Log "[API] Testando conectividade da API..." -Level "Info"
    Write-Host "  Endpoint: $Uri" -ForegroundColor Gray
    Write-Host "  Timeout: $TimeoutSeconds segundos" -ForegroundColor Gray
    
    try {
        # Testa a conectividade do endpoint
        $response = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        
        Write-Log "[SUCESSO] API respondeu corretamente." -Level "Success"
        Write-Host "  Status: Endpoint acessivel e funcional" -ForegroundColor Gray
        
        return $true
    }
    catch [System.Net.WebException] {
        Write-Log "[ERRO] FALHA DE CONECTIVIDADE! Erro de rede: $($_.Exception.Message)" -Level "Error"
        return $false
    }
    catch [System.TimeoutException] {
        Write-Log "[ERRO] TIMEOUT! O endpoint nao respondeu dentro de $TimeoutSeconds segundos." -Level "Error"
        return $false
    }
    catch {
        Write-Log "[ERRO] ERRO INESPERADO! Detalhes: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

#------------------------------------------------------------------------------
# FUNCAO: Open-VSCodeWorkspace
# DESCRICAO: Abre o VS Code no diretorio especificado ou atual
# PARAMETROS: 
#   -Path: Caminho do diretorio a ser aberto (padrao: diretorio atual)
# USO: Open-VSCodeWorkspace [caminho]
# ALIAS: cdr
#------------------------------------------------------------------------------
function Open-VSCodeWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Path = "."
    )
    
    # Resolve o caminho completo
    $fullPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
    
    if (-not $fullPath) {
        Write-Log "[ERRO] Caminho nao encontrado: $Path" -Level "Error"
        return
    }
    
    try {
        Write-Log "[VSCODE] Abrindo VS Code..." -Level "Info"
        Write-Host "  Diretorio: $fullPath" -ForegroundColor Gray
        
        # Abre o VS Code com o workspace especificado
        Start-Process -FilePath "code" -ArgumentList "--reuse-window", "`"$fullPath`"" -NoNewWindow
        
        Write-Log "[SUCESSO] VS Code iniciado com sucesso." -Level "Success"
    }
    catch {
        Write-Log "[ERRO] Erro ao abrir VS Code: $($_.Exception.Message)" -Level "Error"
        Write-Host "  Verifique se o VS Code esta instalado e disponivel no PATH" -ForegroundColor Gray
    }
}

#==============================================================================
# DEFINICAO DE ALIASES
#==============================================================================
# Aliases de sistema
Set-Alias -Name "log" -Value "Write-Log" -Description "Sistema de logs colorido"
Set-Alias -Name "adm" -Value "Test-IsAdmin" -Description "Verifica se o usuario e administrador"

# Aliases de desenvolvimento
Set-Alias -Name "venv" -Value "Activate-VirtualEnvironment" -Description "Ativa ambiente virtual Python"
Set-Alias -Name "mkp" -Value "New-ProjectStructure" -Description "Cria estrutura de projeto"
Set-Alias -Name "api" -Value "Test-ApiEndpoint" -Description "Testa endpoint de API"
Set-Alias -Name "cdr" -Value "Open-VSCodeWorkspace" -Description "Abre VS Code"

#==============================================================================
# INICIALIZACAO DO PERFIL
#==============================================================================
Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Magenta
Write-Host "                PERFIL $(Test-IsAdmin -ReturnUser) POWERSHELL V2.0 CARREGADO" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "FUNCOES DISPONIVEIS:" -ForegroundColor Yellow

Write-Host "  SISTEMA:" -ForegroundColor Magenta
Write-Host "    -> log           - Sistema de logs colorido (Write-Log)" -ForegroundColor Green
Write-Host "    -> adm           - Exibe USUARIO/ADMINISTRADOR (Test-IsAdmin)" -ForegroundColor Green

Write-Host "  DESENVOLVIMENTO:" -ForegroundColor Magenta
Write-Host "    -> venv          - Ativar ambiente virtual Python (Activate-VirtualEnvironment)" -ForegroundColor Green
Write-Host "    -> mkp           - Criar estrutura de projeto (New-ProjectStructure)" -ForegroundColor Green  
Write-Host "    -> api           - Testar endpoint de API (Test-ApiEndpoint)" -ForegroundColor Green
Write-Host "    -> cdr           - Abrir VS Code (Open-VSCodeWorkspace)" -ForegroundColor Green

# ===========================================================================================
# CONFIGURACAO VSCODE
# ===========================================================================================
function Apply-VSCodeSettings {
    [CmdletBinding()]
    param()
    
    $sourcePath = "c:\Users\PC\Desktop\projetos\setup-dev\config\vscode-settings.json"
    $destPath = "$env:APPDATA\Code\User\settings.json"
    
    try {
        # Backup das configuracoes atuais
        if (Test-Path $destPath) {
            $backupPath = "$env:APPDATA\Code\User\settings-backup-$(Get-Date -Format 'yyyy-MM-dd-HH-mm').json"
            Copy-Item $destPath $backupPath -Force
            Write-Log "Backup criado: $backupPath" -Level "Info"
        }
        
        # Aplicar novas configuracoes
        Copy-Item $sourcePath $destPath -Force
        Write-Log "Configuracoes do VS Code aplicadas com sucesso!" -Level "Success"
    } catch {
        Write-Log "Erro ao aplicar configuracoes: $($_.Exception.Message)" -Level "Error"
    }
}

function Setup-VSCodeWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProjectPath = (Get-Location).Path
    )
    
    try {
        $vscodePath = Join-Path $ProjectPath ".vscode"
        
        # Criar pasta .vscode se nao existir
        if (!(Test-Path $vscodePath)) {
            New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null
            Write-Log "Pasta .vscode criada em: $ProjectPath" -Level "Info"
        }
        
        # Converter arquivo de extensoes de .txt para .json
        $extensionsSource = "c:\Users\PC\Desktop\projetos\setup-dev\config\extensions.txt"
        $extensionsDest = Join-Path $vscodePath "extensions.json"
        
        # Ler extensoes do arquivo .txt
        $extensionsList = Get-Content $extensionsSource | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
        
        # Criar objeto JSON no formato esperado pelo VS Code
        $extensionsJson = @{
            recommendations = $extensionsList
        }
        
        # Salvar como JSON
        $extensionsJson | ConvertTo-Json | Out-File $extensionsDest -Encoding UTF8 -Force
        Write-Log "Sistema de extensoes configurado para o projeto!" -Level "Success"
        Write-Log "Abra o VS Code neste diretorio para ver as extensoes recomendadas." -Level "Info"
        
    } catch {
        Write-Log "Erro ao configurar workspace: $($_.Exception.Message)" -Level "Error"
    }
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan