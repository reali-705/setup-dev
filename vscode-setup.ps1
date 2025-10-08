## ----------------------------------------------------
## VSCODE SETUP - CONFIGURAcaO DEDICADA DO VS CODE
## Versao: 1.0.0 - Sistema de Backup e Aplicacao
## ----------------------------------------------------

[CmdletBinding()]
param(
    # Aplicar configuracoes do projeto para o VS Code
    [Parameter(Mandatory=$false)]
    [Alias("a")]
    [switch]$Apply,
    
    # Resetar configuracoes para backup anterior
    [Parameter(Mandatory=$false)]
    [Alias("r")]
    [switch]$Reset,
    
    # Fazer backup das configuracoes atuais apenas
    [Parameter(Mandatory=$false)]
    [Alias("b")]
    [switch]$Backup,
    
    # Forcar sobrescrita sem confirmacao
    [Parameter(Mandatory=$false)]
    [Alias("f")]
    [switch]$Force,
    
    # Mostrar ajuda detalhada
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

function Test-VSCodeInstalled {
    [CmdletBinding()]
    param()
    
    try {
        # Testar comando 'code' no PATH
        $CodeVersion = code --version 2>$null
        if ($CodeVersion) {
            $Version = ($CodeVersion -split "`n")[0]
            Write-Log "[DETECTADO] VS Code versao: $Version" -Level "Success"
            return @{
                Installed = $true
                Version = $Version
                Path = (Get-Command code).Source
            }
        }
    } catch {
        # Silencioso - tentaremos outros metodos
    }
    
    # Verificar instalacoes padrao
    $DefaultPaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:PROGRAMFILES\Microsoft VS Code\Code.exe",
        "$env:PROGRAMFILES(X86)\Microsoft VS Code\Code.exe"
    )
    
    foreach ($Path in $DefaultPaths) {
        if (Test-Path $Path) {
            Write-Log "[DETECTADO] VS Code encontrado em: $Path" -Level "Success"
            return @{
                Installed = $true
                Version = "Detectado localmente"
                Path = $Path
            }
        }
    }
    
    return @{
        Installed = $false
        Version = $null
        Path = $null
    }
}

function Get-VSCodePaths {
    [CmdletBinding()]
    param()
    
    $UserPath = "$env:APPDATA\Code\User"
    $SettingsFile = Join-Path $UserPath "settings.json"
    $ExtensionsPath = "$env:USERPROFILE\.vscode\extensions"
    
    # Criar pasta User se nao existir
    if (-not (Test-Path $UserPath)) {
        New-Item -ItemType Directory -Path $UserPath -Force | Out-Null
        Write-Log "[CRIADO] Pasta de configuracoes VS Code: $UserPath" -Level "Info"
    }
    
    return @{
        UserPath = $UserPath
        SettingsFile = $SettingsFile
        ExtensionsPath = $ExtensionsPath
    }
}

function Get-BackupPath {
    [CmdletBinding()]
    param()
    
    $ProjectRoot = $PSScriptRoot
    $BackupDir = Join-Path $ProjectRoot "backups"
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Write-Log "[CRIADO] Diretorio de backups: $BackupDir" -Level "Info"
    }
    
    return $BackupDir
}

function Backup-VSCodeSettings {
    [CmdletBinding()]
    param(
        [hashtable]$Paths
    )
    
    $BackupDir = Get-BackupPath
    $Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    
    try {
        # BACKUP 1: Settings JSON
        if (Test-Path $Paths.SettingsFile) {
            $SettingsBackup = Join-Path $BackupDir "settings-backup-$Timestamp.json"
            Copy-Item $Paths.SettingsFile $SettingsBackup -Force
            Write-Log "[BACKUP] Configuracoes salvas: backups\settings-backup-$Timestamp.json" -Level "Success"
        } else {
            Write-Log "[INFO] Nenhuma configuracao existente encontrada para backup" -Level "Info"
        }
        
        # BACKUP 2: Lista de Extensoes
        $ExtensionsBackup = Join-Path $BackupDir "extensions-backup-$Timestamp.txt"
        $InstalledExtensions = code --list-extensions 2>$null
        
        if ($InstalledExtensions) {
            $InstalledExtensions | Out-File $ExtensionsBackup -Encoding UTF8
            $ExtCount = ($InstalledExtensions | Measure-Object).Count
            Write-Log "[BACKUP] $ExtCount extensoes salvas: backups\extensions-backup-$Timestamp.txt" -Level "Success"
        } else {
            Write-Log "[INFO] Nenhuma extensao instalada encontrada para backup" -Level "Info"
        }
        
        return @{
            Success = $true
            SettingsBackup = $SettingsBackup
            ExtensionsBackup = $ExtensionsBackup
            Timestamp = $Timestamp
        }
        
    } catch {
        Write-Log "[ERRO] Falha no backup: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Apply-VSCodeSettings {
    [CmdletBinding()]
    param(
        [hashtable]$Paths,
        [bool]$Force = $false
    )
    
    $ProjectRoot = $PSScriptRoot
    $SourceSettings = Join-Path $ProjectRoot "config\vscode-settings.json"
    
    # Verificar se arquivo de configuracao existe
    if (-not (Test-Path $SourceSettings)) {
        Write-Log "[ERRO] Arquivo de configuracao nao encontrado: $SourceSettings" -Level "Error"
        Write-Log "[INFO] Execute primeiro o setup.ps1 ou verifique a estrutura do projeto" -Level "Warning"
        return $false
    }
    
    try {
        # Confirmacao se settings existente e nao forca
        if ((Test-Path $Paths.SettingsFile) -and (-not $Force)) {
            Write-Log "[AVISO] Configuracoes VS Code existentes detectadas" -Level "Warning"
            $Confirmation = Read-Host "Deseja substituir as configuracoes atuais? (s/N)"
            if ($Confirmation -notmatch '^[sS]') {
                Write-Log "[CANCELADO] Operacao cancelada pelo usuario" -Level "Warning"
                return $false
            }
        }
        
        # Aplicar configuracoes
        Copy-Item $SourceSettings $Paths.SettingsFile -Force
        Write-Log "[APLICADO] Configuracoes do projeto aplicadas com sucesso!" -Level "Success"
        
        # Verificar tamanho do arquivo copiado
        $FileInfo = Get-Item $Paths.SettingsFile
        Write-Log "[INFO] Arquivo de configuracoes: $($FileInfo.Length) bytes" -Level "Info"
        
        return $true
        
    } catch {
        Write-Log "[ERRO] Falha ao aplicar configuracoes: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Install-VSCodeExtensions {
    [CmdletBinding()]
    param(
        [bool]$Force = $false
    )
    
    $ProjectRoot = $PSScriptRoot
    $ExtensionsFile = Join-Path $ProjectRoot "config\extensions.txt"
    
    # Verificar se arquivo de extensoes existe
    if (-not (Test-Path $ExtensionsFile)) {
        Write-Log "[ERRO] Arquivo de extensoes nao encontrado: $ExtensionsFile" -Level "Error"
        return $false
    }
    
    try {
        # Carregar lista de extensoes recomendadas
        $RecommendedExtensions = Get-Content $ExtensionsFile | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
        
        if (-not $RecommendedExtensions -or $RecommendedExtensions.Count -eq 0) {
            Write-Log "[AVISO] Nenhuma extensao recomendada encontrada no arquivo" -Level "Warning"
            return $false
        }
        
        Write-Log "[INFO] Processando $($RecommendedExtensions.Count) extensoes recomendadas..." -Level "Info"
        
        # Obter extensoes ja instaladas
        $InstalledExtensions = code --list-extensions 2>$null
        
        $InstalledCount = 0
        $SkippedCount = 0
        $ErrorCount = 0
        
        foreach ($Extension in $RecommendedExtensions) {
            $IsInstalled = $InstalledExtensions -contains $Extension
            
            if ($IsInstalled -and (-not $Force)) {
                Write-Log "[SKIP] Ja instalada: $Extension" -Level "Info"
                $SkippedCount++
                continue
            }
            
            try {
                Write-Log "[INSTALANDO] $Extension..." -Level "Info"
                $Result = code --install-extension $Extension 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "[SUCESSO] Extensao instalada: $Extension" -Level "Success"
                    $InstalledCount++
                } else {
                    Write-Log "[ERRO] Falha na instalacao: $Extension - $Result" -Level "Error"
                    $ErrorCount++
                }
                
            } catch {
                Write-Log "[ERRO] Excecao ao instalar $Extension`: $($_.Exception.Message)" -Level "Error"
                $ErrorCount++
            }
        }
        
        # Resumo da instalacao
        Write-Log "[RESUMO] Extensoes - Instaladas: $InstalledCount | Ignoradas: $SkippedCount | Erros: $ErrorCount" -Level "Success"
        return $true
        
    } catch {
        Write-Log "[ERRO] Falha ao processar extensoes: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Reset-VSCodeSettings {
    [CmdletBinding()]
    param(
        [hashtable]$Paths
    )
    
    $BackupDir = Get-BackupPath
    
    try {
        # Listar backups disponiveis
        $SettingsBackups = Get-ChildItem (Join-Path $BackupDir "settings-backup-*.json") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        
        if (-not $SettingsBackups -or $SettingsBackups.Count -eq 0) {
            Write-Log "[ERRO] Nenhum backup de configuracoes encontrado em: $BackupDir" -Level "Error"
            return $false
        }
        
        Write-Log "[INFO] Backups disponiveis:" -Level "Info"
        for ($i = 0; $i -lt [Math]::Min(5, $SettingsBackups.Count); $i++) {
            $Backup = $SettingsBackups[$i]
            Write-Log "  [$($i+1)] $($Backup.Name) - $($Backup.LastWriteTime)" -Level "Info"
        }
        
        # Confirmar restauracao
        $Confirmation = Read-Host "Deseja restaurar o backup mais recente? (s/N)"
        if ($Confirmation -notmatch '^[sS]') {
            Write-Log "[CANCELADO] Restauracao cancelada pelo usuario" -Level "Warning"
            return $false
        }
        
        # Restaurar backup mais recente
        $LatestBackup = $SettingsBackups[0]
        Copy-Item $LatestBackup.FullName $Paths.SettingsFile -Force
        Write-Log "[RESTAURADO] Configuracoes restauradas do backup: $($LatestBackup.Name)" -Level "Success"
        
        # Perguntar sobre extensoes
        $ExtConfirmation = Read-Host "Deseja tambem restaurar a lista de extensoes? (s/N)"
        if ($ExtConfirmation -match '^[sS]') {
            $ExtBackupPattern = $LatestBackup.Name -replace "settings-backup-", "extensions-backup-" -replace "\.json$", ".txt"
            $ExtBackupFile = Join-Path $BackupDir $ExtBackupPattern
            
            if (Test-Path $ExtBackupFile) {
                Write-Log "[INFO] Lista de extensoes do backup encontrada. Voce precisara reinstala-las manualmente." -Level "Info"
                Write-Log "[INFO] Arquivo de referencia: $ExtBackupFile" -Level "Info"
            }
        }
        
        return $true
        
    } catch {
        Write-Log "[ERRO] Falha na restauracao: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Show-VSCodeStatus {
    [CmdletBinding()]
    param()
    
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host "                          STATUS VS CODE - CONFIGURACAO                    " -ForegroundColor Cyan
    Write-Host "=============================================================================" -ForegroundColor Cyan
    
    # Verificar instalacao
    $VSCodeInfo = Test-VSCodeInstalled
    if ($VSCodeInfo.Installed) {
        Write-Log "[VS CODE] Instalado - Versao: $($VSCodeInfo.Version)" -Level "Success"
        Write-Log "[CAMINHO] $($VSCodeInfo.Path)" -Level "Info"
    } else {
        Write-Log "[VS CODE] NAO INSTALADO - Execute setup.ps1 primeiro" -Level "Error"
        return
    }
    
    # Verificar configuracoes
    $Paths = Get-VSCodePaths
    if (Test-Path $Paths.SettingsFile) {
        $FileInfo = Get-Item $Paths.SettingsFile
        Write-Log "[SETTINGS] Configuracoes personalizadas ativas ($($FileInfo.Length) bytes)" -Level "Success"
    } else {
        Write-Log "[SETTINGS] Usando configuracoes padrao do VS Code" -Level "Info"
    }
    
    # Verificar extensoes
    try {
        $InstalledExtensions = code --list-extensions 2>$null
        if ($InstalledExtensions) {
            $ExtCount = ($InstalledExtensions | Measure-Object).Count
            Write-Log "[EXTENSOES] $ExtCount extensoes instaladas" -Level "Success"
        } else {
            Write-Log "[EXTENSOES] Nenhuma extensao instalada" -Level "Info"
        }
    } catch {
        Write-Log "[EXTENSOES] Nao foi possivel listar extensoes" -Level "Warning"
    }
    
    # Verificar arquivos de configuracao do projeto
    $ProjectRoot = $PSScriptRoot
    $ConfigSettings = Join-Path $ProjectRoot "config\vscode-settings.json"
    $ConfigExtensions = Join-Path $ProjectRoot "config\extensions.txt"
    
    Write-Host ""
    Write-Host "ARQUIVOS DE CONFIGURACAO DO PROJETO:" -ForegroundColor Yellow
    
    if (Test-Path $ConfigSettings) {
        Write-Log "[OK] config\vscode-settings.json - Disponivel" -Level "Success"
    } else {
        Write-Log "[X] config\vscode-settings.json - NAO ENCONTRADO" -Level "Error"
    }
    
    if (Test-Path $ConfigExtensions) {
        try {
            $ExtensionsList = Get-Content $ConfigExtensions | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
            $RecommendedCount = ($ExtensionsList | Measure-Object).Count
            Write-Log "[OK] config\extensions.txt - $RecommendedCount extensoes recomendadas" -Level "Success"
        } catch {
            Write-Log "[X] config\extensions.txt - Arquivo invalido" -Level "Error"
        }
    } else {
        Write-Log "[X] config\extensions.txt - NAO ENCONTRADO" -Level "Error"
    }
    
    # Verificar backups
    $BackupDir = Get-BackupPath
    $Backups = Get-ChildItem (Join-Path $BackupDir "*-backup-*") -ErrorAction SilentlyContinue
    if ($Backups) {
        $BackupCount = ($Backups | Measure-Object).Count
        Write-Log "[BACKUPS] $BackupCount arquivos de backup disponiveis" -Level "Info"
    } else {
        Write-Log "[BACKUPS] Nenhum backup encontrado" -Level "Info"
    }
    
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host "                    VSCODE-SETUP.PS1 - CONFIGURACAO VS CODE                " -ForegroundColor Cyan
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRICAO:" -ForegroundColor Yellow
    Write-Host "  Script dedicado para configuracao do VS Code com sistema de backup/restore"
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\vscode-setup.ps1 [PARAMETRO]"
    Write-Host ""
    Write-Host "PARAMETROS:" -ForegroundColor Yellow
    Write-Host "  -Apply    (-a)   Aplicar configuracoes do projeto ao VS Code" -ForegroundColor Green
    Write-Host "  -Reset    (-r)   Restaurar configuracoes de backup anterior" -ForegroundColor Green  
    Write-Host "  -Backup   (-b)   Fazer backup das configuracoes atuais apenas" -ForegroundColor Green
    Write-Host "  -Force    (-f)   Forcar operacao sem confirmacoes" -ForegroundColor Green
    Write-Host "  -Help     (-h)   Mostrar esta ajuda" -ForegroundColor Green
    Write-Host ""
    Write-Host "EXEMPLOS:" -ForegroundColor Yellow
    Write-Host "  .\vscode-setup.ps1               # Mostrar status atual" -ForegroundColor Cyan
    Write-Host "  .\vscode-setup.ps1 -Apply        # Aplicar configuracoes (com backup automatico)" -ForegroundColor Cyan
    Write-Host "  .\vscode-setup.ps1 -Apply -Force # Aplicar forcadamente (sem perguntas)" -ForegroundColor Cyan
    Write-Host "  .\vscode-setup.ps1 -Backup       # Apenas fazer backup" -ForegroundColor Cyan
    Write-Host "  .\vscode-setup.ps1 -Reset        # Restaurar backup anterior" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "OBSERVACOES:" -ForegroundColor Yellow
    Write-Host "  - Backups sao salvos automaticamente em: backups\"
    Write-Host "  - Configuracoes do projeto ficam em: config\"
    Write-Host "  - Lista de extensoes em: config\extensions.txt (uma por linha)"
    Write-Host "  - VS Code deve estar instalado (use setup.ps1 se necessario)"
    Write-Host "  - O script nao altera os arquivos de configuracao do projeto"
    Write-Host ""
}

# ============================================================
# LOGICA PRINCIPAL
# ============================================================

# Mostrar ajuda se solicitado
if ($Help) {
    Show-Help
    exit 0
}

# Verificar se VS Code esta instalado
Write-Log "[VERIFICANDO] Instalacao do VS Code..." -Level "Info"
$VSCodeInfo = Test-VSCodeInstalled

if (-not $VSCodeInfo.Installed) {
    Write-Log "[ERRO] VS Code nao foi encontrado no sistema" -Level "Error"
    Write-Log "[SOLUCAO] Execute o comando: .\setup.ps1 -Install vscode" -Level "Warning"
    Write-Log "[ALTERNATIVA] Instale manualmente: https://code.visualstudio.com/" -Level "Info"
    exit 1
}

# Obter caminhos de configuracao
$Paths = Get-VSCodePaths

# Processar parametros
if ($Backup) {
    Write-Log "[INICIANDO] Backup das configuracoes VS Code..." -Level "Info"
    $BackupResult = Backup-VSCodeSettings -Paths $Paths
    
    if ($BackupResult.Success) {
        Write-Log "[CONCLUIDO] Backup realizado com sucesso!" -Level "Success"
    } else {
        Write-Log "[FALHA] Erro durante o backup: $($BackupResult.Error)" -Level "Error"
        exit 1
    }
}
elseif ($Reset) {
    Write-Log "[INICIANDO] Restauracao de configuracoes..." -Level "Info"
    $ResetSuccess = Reset-VSCodeSettings -Paths $Paths
    
    if ($ResetSuccess) {
        Write-Log "[CONCLUIDO] Restauracao realizada com sucesso!" -Level "Success"
    } else {
        Write-Log "[FALHA] Erro durante a restauracao" -Level "Error"
        exit 1
    }
}
elseif ($Apply) {
    Write-Log "[INICIANDO] Aplicacao das configuracoes do projeto..." -Level "Info"
    
    # Fazer backup automatico (se nao forcado)
    if (-not $Force) {
        Write-Log "[BACKUP] Fazendo backup automatico das configuracoes atuais..." -Level "Info"
        $BackupResult = Backup-VSCodeSettings -Paths $Paths
        
        if (-not $BackupResult.Success) {
            Write-Log "[AVISO] Falha no backup, mas continuando... $($BackupResult.Error)" -Level "Warning"
        }
    }
    
    # Aplicar configuracoes
    $SettingsSuccess = Apply-VSCodeSettings -Paths $Paths -Force $Force
    
    if ($SettingsSuccess) {
        Write-Log "[SUCESSO] Configuracoes aplicadas!" -Level "Success"
        
        # Instalar extensoes
        Write-Log "[INSTALANDO] Extensoes recomendadas..." -Level "Info"
        $ExtensionsSuccess = Install-VSCodeExtensions -Force $Force
        
        if ($ExtensionsSuccess) {
            Write-Log "[CONCLUIDO] Configuracao do VS Code finalizada com sucesso!" -Level "Success"
        } else {
            Write-Log "[PARCIAL] Configuracoes aplicadas, mas houve problemas com extensoes" -Level "Warning"
        }
    } else {
        Write-Log "[FALHA] Erro ao aplicar configuracoes" -Level "Error"
        exit 1
    }
}
else {
    # Mostrar status se nenhum parametro especifico
    Show-VSCodeStatus
    
    Write-Host ""
    Write-Host "COMANDOS DISPONiVEIS:" -ForegroundColor Yellow
    Write-Host "  .\vscode-setup.ps1 -Apply    # Aplicar configuracoes do projeto" -ForegroundColor Green
    Write-Host "  .\vscode-setup.ps1 -Backup   # Backup das configuracoes atuais" -ForegroundColor Green
    Write-Host "  .\vscode-setup.ps1 -Reset    # Restaurar backup anterior" -ForegroundColor Green
    Write-Host "  .\vscode-setup.ps1 -Help     # Ajuda detalhada" -ForegroundColor Green
    Write-Host ""
}

Write-Host "=============================================================================" -ForegroundColor Cyan