## ----------------------------------------------------
## SETUP DE DESENVOLVIMENTO - CIENCIA DA COMPUTACAO
## Versao: 1.0.0 - Primeira Versao Funcional
## ----------------------------------------------------

[CmdletBinding()]
param(
    # Instalar softwares especificos ou "all" para todos.
    [Parameter(Mandatory=$false)]
    [Alias("i")]
    [string]$Install,
    
    # Forcar reinstalacao mesmo se ja instalado.
    [Parameter(Mandatory=$false)]
    [Alias("f")]
    [switch]$Force,
    
    # Limpeza inteligente do ambiente.
    [Parameter(Mandatory=$false)]
    [Alias("c")]
    [switch]$Clean,
    
    # Mostrar ajuda.
    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help
)

# ============================================================
# FUNCOES AUXILIARES
# ============================================================

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

function Test-Prerequisites {
    Write-Log "[VERIFICACAO] Verificando pre-requisitos do sistema..." -Level "Info"
    $Issues = @()
    
    # Verificar Git (PRE-REQUISITO OBRIGATORIO).
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $Issues += "Git nao encontrado! Instale: https://git-scm.com/download/win."
    } else {
        Write-Log "[SUCESSO] Git encontrado: $(git --version)." -Level "Success"
    }
    
    # Verificar espaco em disco (minimo 3GB).
    try {
        $FreeSpace = (Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Where-Object DeviceID -eq "C:").FreeSpace
        if ($FreeSpace -lt 3GB) {
            $Issues += "Espaco insuficiente no drive C: (menos de 3GB livres)."
        }
    } catch {
        Write-Log "[AVISO] Nao foi possivel verificar espaco em disco." -Level "Warning"
    }
    
    # Verificar conexao com internet.
    try {
        $TestConnection = Test-NetConnection -ComputerName "chocolatey.org" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $TestConnection) {
            $Issues += "Sem conexao com a internet (chocolatey.org inacessivel)."
        }
    }
    catch {
        $Issues += "Erro ao verificar conexao: $($_.Exception.Message)."
    }
    
    # Verificar se o arquivo JSON existe.
    $ConfigFile = Join-Path $PSScriptRoot "config\software.json"
    if (-not (Test-Path $ConfigFile)) {
        $Issues += "Arquivo 'software.json' nao encontrado em: $ConfigFile."
    }
    
    # Retornar resultado.
    if ($Issues.Count -gt 0) {
        Write-Log "[ERRO] Problemas encontrados:" -Level "Error"
        foreach ($Issue in $Issues) {
            Write-Log "   - $Issue" -Level "Error"
        }
        return $false
    }
    
    Write-Log "[SUCESSO] Todos os pre-requisitos atendidos!" -Level "Success"
    return $true
}

function Test-IsAdmin {
    $CurrentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $CurrentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SoftwareConfig {
    $ConfigFile = Join-Path $PSScriptRoot "config\software.json"
    
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $SoftwareCount = $Config.software.PSObject.Properties.Count
        Write-Log "[SUCESSO] Configuracao carregada: $SoftwareCount softwares disponiveis." -Level "Success"
        return $Config
    }
    catch {
        Write-Log "[ERRO] Erro ao ler arquivo JSON: $($_.Exception.Message)." -Level "Error"
        return $null
    }
}

function Get-SoftwareList {
    param(
        [string]$UserInput,
        [PSCustomObject]$Config
    )
    
    if ($UserInput -eq "all") {
        # Retornar todos os softwares do JSON.
        $AllSoftware = @($Config.software.PSObject.Properties.Name)
        Write-Log "[INSTALACAO] Perfil 'all' selecionado: $($AllSoftware.Count) softwares." -Level "Info"
        return $AllSoftware
    }
    else {
        # Processar lista especifica com validacao robusta.
        # Aceita separadores: "," ou ", " (virgula com ou sem espaco).
        $RequestedSoftware = $UserInput -split ',\s*' | ForEach-Object { $_.Trim() }
        $ValidSoftware = @()
        $InvalidSoftware = @()
        
        foreach ($SoftwareName in $RequestedSoftware) {
            # Remover espacos extras e validar se nao esta vazio.
            $CleanName = $SoftwareName.Trim()
            if (-not [string]::IsNullOrEmpty($CleanName)) {
                if ($Config.software.PSObject.Properties.Name -contains $CleanName) {
                    $ValidSoftware += $CleanName
                }
                else {
                    $InvalidSoftware += $CleanName
                }
            }
        }
        
        # Relatorio de validacao.
        if ($InvalidSoftware.Count -gt 0) {
            Write-Log "[AVISO] Softwares nao encontrados no catalogo: $($InvalidSoftware -join ', ')." -Level "Warning"
        }
        
        if ($ValidSoftware.Count -gt 0) {
            Write-Log "[INSTALACAO] Softwares selecionados: $($ValidSoftware -join ', ')." -Level "Info"
        }
        
        return $ValidSoftware
    }
}

function Install-ViaChocolatey {
    param(
        [PSCustomObject]$SoftwareConfig,
        [string]$SoftwareName,
        [bool]$Force = $false
    )
    
    $PackageName = $SoftwareConfig.chocolatey.packageName
    
    # Verificar se o software ja esta instalado (se nao for forcado).
    if (-not $Force) {
        Write-Log "[VERIFICACAO] Verificando se $($SoftwareConfig.name) ja esta instalado..." -Level "Info"
        
        try {
            $InstalledPackages = choco list --local-only $PackageName --exact 2>$null
            if ($InstalledPackages -match $PackageName) {
                Write-Log "[JA_INSTALADO] $($SoftwareConfig.name) ja esta instalado. Pulando instalacao." -Level "Warning"
                return $true
            }
        }
        catch {
            Write-Log "[AVISO] Nao foi possivel verificar pacotes instalados. Prosseguindo com instalacao." -Level "Warning"
        }
    }
    else {
        Write-Log "[FORCE] Modo forcado ativado. Reinstalando $($SoftwareConfig.name)..." -Level "Info"
    }
    
    Write-Log "[CHOCOLATEY] Instalando via Chocolatey: $($SoftwareConfig.name)." -Level "Info"
    
    try {
        $Result = choco install $PackageName -y --no-progress --force
        if ($LASTEXITCODE -eq 0) {
            Write-Log "[SUCESSO] $($SoftwareConfig.name) instalado com sucesso!" -Level "Success"
            return $true
        }
        else {
            Write-Log "[ERRO] Falha ao instalar $($SoftwareConfig.name)." -Level "Error"
            return $false
        }
    }
    catch {
        Write-Log "[ERRO] Erro ao instalar $($SoftwareConfig.name): $($_.Exception.Message)." -Level "Error"
        return $false
    }
}

function Install-Portable {
    param(
        [PSCustomObject]$SoftwareConfig,
        [string]$SoftwareName,
        [string]$BasePath,
        [bool]$Force = $false
    )
    
    # Verificar se tem versao portatil.
    if (-not $SoftwareConfig.portable) {
        Write-Log "[AVISO] $($SoftwareConfig.name) requer privilegios de administrador (pulando)." -Level "Warning"
        return $false
    }
    
    if ($SoftwareConfig.portable.note) {
        Write-Log "[AVISO] $($SoftwareConfig.name): $($SoftwareConfig.portable.note)." -Level "Warning"
        return $false
    }
    
    # Verificar se ja foi instalado como portatil (se nao for forcado).
    $ExtractFolder = $SoftwareConfig.portable.extractFolder
    $SoftwareFolder = Join-Path $BasePath $ExtractFolder
    
    if (-not $Force) {
        Write-Log "[VERIFICACAO] Verificando se $($SoftwareConfig.name) ja esta instalado..." -Level "Info"
        
        if (Test-Path $SoftwareFolder) {
            # Verificar se o diretorio nao esta vazio.
            $Contents = Get-ChildItem $SoftwareFolder -ErrorAction SilentlyContinue
            if ($Contents.Count -gt 0) {
                Write-Log "[JA_INSTALADO] $($SoftwareConfig.name) ja esta instalado em: $SoftwareFolder. Pulando instalacao." -Level "Warning"
                return $true
            }
        }
    }
    else {
        Write-Log "[FORCE] Modo forcado ativado. Reinstalando $($SoftwareConfig.name)..." -Level "Info"
        # Remover instalacao anterior se existir.
        if (Test-Path $SoftwareFolder) {
            Remove-Item $SoftwareFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "[PORTABLE] Instalando versao portatil: $($SoftwareConfig.name)." -Level "Info"
    
    $DownloadUrl = $SoftwareConfig.portable.downloadUrl
    $FileName = $SoftwareConfig.portable.filename
    $ExtractFolder = $SoftwareConfig.portable.extractFolder
    
    $SoftwareFolder = Join-Path $BasePath $ExtractFolder
    $DownloadFile = Join-Path $BasePath $FileName
    
    try {
        # Criar diretorio de destino.
        if (-not (Test-Path $SoftwareFolder)) {
            New-Item -ItemType Directory -Path $SoftwareFolder -Force | Out-Null
        }
        
        # Baixar arquivo.
        Write-Log "[DOWNLOAD] Baixando $($SoftwareConfig.name)..." -Level "Info"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadFile -UseBasicParsing
        
        # Extrair arquivo.
        Write-Log "[EXTRACAO] Extraindo para: $SoftwareFolder." -Level "Info"
        Expand-Archive -Path $DownloadFile -DestinationPath $SoftwareFolder -Force
        
        # Limpar arquivo temporario.
        Remove-Item $DownloadFile -Force -ErrorAction SilentlyContinue
        
        Write-Log "[SUCESSO] $($SoftwareConfig.name) instalado em: $SoftwareFolder." -Level "Success"
        return $true
    }
    catch {
        Write-Log "[ERRO] Erro na instalacao portatil: $($_.Exception.Message)." -Level "Error"
        return $false
    }
}

function Clean-Environment {
    param(
        [bool]$IsAdmin,
        [string]$TempPath
    )
    
    Write-Log "[LIMPEZA] Iniciando limpeza do ambiente..." -Level "Info"
    
    # Limpeza de instalacoes portateis.
    if ($TempPath -and (Test-Path $TempPath)) {
        Write-Log "[LIMPEZA] Removendo instalacoes portateis..." -Level "Info"
        try {
            Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "[SUCESSO] Diretorio removido: $TempPath." -Level "Success"
        }
        catch {
            Write-Log "[AVISO] Erro ao remover diretorio portatil: $($_.Exception.Message)." -Level "Warning"
        }
    }
    
    # Limpeza via Chocolatey (se admin).
    if ($IsAdmin) {
        Write-Log "[ADMIN] Executando limpeza via Chocolatey..." -Level "Info"
        
        # Obter lista de softwares instalados.
        $Config = Get-SoftwareConfig
        if ($Config) {
            foreach ($SoftwareName in $Config.software.PSObject.Properties.Name) {
                $PackageName = $Config.software.$SoftwareName.chocolatey.packageName
                Write-Log "[REMOCAO] Desinstalando: $PackageName." -Level "Info"
                choco uninstall $PackageName -y --remove-dependencies 2>$null
            }
        }
        
        # Limpar cache do Chocolatey.
        Write-Log "[LIMPEZA] Limpando cache do Chocolatey..." -Level "Info"
        choco cache remove --all 2>$null
    }
    
    # Limpeza geral do sistema.
    Write-Log "[LIMPEZA] Limpeza geral do sistema..." -Level "Info"
    
    # Limpar arquivos temporarios.
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Limpar cache NuGet.
    if (Test-Path "$env:LOCALAPPDATA\NuGet\Cache") {
        Remove-Item -Path "$env:LOCALAPPDATA\NuGet\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Log "[SUCESSO] Limpeza concluida com sucesso!" -Level "Success"
}

# ============================================================
# LOGICA PRINCIPAL
# ============================================================

function Show-Help {
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host "                    SETUP.PS1 - INSTALACAO DE SOFTWARE                     " -ForegroundColor Cyan
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRICAO:" -ForegroundColor Yellow
    Write-Host "  Script principal para instalacao automatica de ferramentas de desenvolvimento"
    Write-Host "  Suporta instalacao via Chocolatey (admin) ou modo portatil (usuario)"
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 [PARAMETRO]"
    Write-Host ""
    Write-Host "PARAMETROS:" -ForegroundColor Yellow
    Write-Host "  -Install  (-i)   Instalar softwares (especificos ou 'all')" -ForegroundColor Green
    Write-Host "  -Force    (-f)   Forcar reinstalacao mesmo se ja instalado" -ForegroundColor Green  
    Write-Host "  -Clean    (-c)   Limpeza completa do ambiente" -ForegroundColor Green
    Write-Host "  -Help     (-h)   Mostrar esta ajuda" -ForegroundColor Green
    Write-Host ""
    Write-Host "EXEMPLOS:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 -Install all                   # Instalar todos os softwares" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -Install 'vscode,python'       # Instalar softwares especificos" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -i vscode                      # Instalar apenas VS Code" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -i nodejs -Force               # Forcar reinstalacao do Node.js" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -Clean                         # Limpeza completa do ambiente" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SOFTWARES DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host "  vscode, python, nodejs, openjdk11, sqlite, mysql," -ForegroundColor Green
    Write-Host "  postman, msys2, dotnet-sdk" -ForegroundColor Green
    Write-Host ""
    Write-Host "OBSERVACOES:" -ForegroundColor Yellow
    Write-Host "  - Modo ADMIN: Instala via Chocolatey (recomendado)"
    Write-Host "  - Modo USUARIO: Instala versoes portateis em ~/Documents/TEMP_ENV"
    Write-Host "  - Requer Git instalado como pre-requisito"
    Write-Host "  - Lista de softwares configurada em: config\software.json"
    Write-Host "  - Para configurar VS Code apos instalacao: .\vscode-setup.ps1 -Apply"
    Write-Host ""
}

# Mostrar ajuda se solicitado
if ($Help -or (-not $Install -and -not $Clean)) {
    Show-Help
    exit 0
}

# Verificar pre-requisitos.
if (-not (Test-Prerequisites)) {
    Write-Log "[ERRO] Pre-requisitos nao atendidos. Encerrando execucao." -Level "Error"
    exit 1
}

# Detectar privilegios UMA VEZ.
$IsAdmin = Test-IsAdmin
$TempPath = if (-not $IsAdmin) { "$env:USERPROFILE\Documents\TEMP_ENV" } else { $null }

if ($IsAdmin) {
    Write-Log "[ADMIN] Modo ADMINISTRADOR detectado (Chocolatey)." -Level "Info"
    
    # Verificar se Chocolatey esta instalado.
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "[CHOCOLATEY] Instalando Chocolatey..." -Level "Info"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            refreshenv
            Write-Log "[SUCESSO] Chocolatey instalado com sucesso!" -Level "Success"
        }
        catch {
            Write-Log "[ERRO] Falha na instalacao do Chocolatey: $($_.Exception.Message)." -Level "Error"
            exit 1
        }
    } else {
        Write-Log "[SUCESSO] Chocolatey ja esta disponivel." -Level "Success"
    }
} else {
    Write-Log "[USUARIO] Modo USUARIO detectado (Instalacao Portatil)." -Level "Info"
    Write-Log "[DIRETORIO] Diretorio: $TempPath." -Level "Info"
}

# Executar limpeza se solicitada.
if ($Clean) {
    Clean-Environment -IsAdmin $IsAdmin -TempPath $TempPath
    exit 0
}

# Executar instalacao se solicitada.
if ($Install) {
    # Carregar configuracao.
    $Config = Get-SoftwareConfig
    if (-not $Config) {
        Write-Log "[ERRO] Nao foi possivel carregar a configuracao." -Level "Error"
        exit 1
    }
    
    # Obter lista de softwares.
    $SoftwareList = Get-SoftwareList -UserInput $Install -Config $Config
    
    if ($SoftwareList.Count -eq 0) {
        Write-Log "[ERRO] Nenhum software valido encontrado para instalacao." -Level "Error"
        exit 1
    }
    
    # Criar diretorio portatil se necessario.
    if (-not $IsAdmin -and $TempPath) {
        if (-not (Test-Path $TempPath)) {
            Write-Log "[DIRETORIO] Criando diretorio de instalacao portatil..." -Level "Info"
            New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
        }
    }
    
    # Loop de instalacao.
    Write-Log "[INICIO] Iniciando instalacao de $($SoftwareList.Count) software(s)..." -Level "Info"
    $SuccessCount = 0
    
    foreach ($SoftwareName in $SoftwareList) {
        $SoftwareConfig = $Config.software.$SoftwareName
        
        Write-Log "[PROCESSANDO] Processando: $($SoftwareConfig.name)." -Level "Info"
        
        if ($IsAdmin) {
            if (Install-ViaChocolatey -SoftwareConfig $SoftwareConfig -SoftwareName $SoftwareName -Force $Force) {
                $SuccessCount++
            }
        }
        else {
            if (Install-Portable -SoftwareConfig $SoftwareConfig -SoftwareName $SoftwareName -BasePath $TempPath -Force $Force) {
                $SuccessCount++
            }
        }
    }
    
    # Relatorio final.
    Write-Host ""
    Write-Log "[CONCLUIDO] Instalacao concluida!" -Level "Success"
    Write-Log "[RELATORIO] Sucessos: $SuccessCount de $($SoftwareList.Count)." -Level "Info"
    
    if (-not $IsAdmin -and $SuccessCount -gt 0) {
        Write-Log "[DIRETORIO] Softwares instalados em: $TempPath." -Level "Info"
        Write-Log "[DICA] Adicione os executaveis ao PATH para usar globalmente." -Level "Info"
    }
}
