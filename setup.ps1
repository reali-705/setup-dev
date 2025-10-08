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
    
    # Verificar configuracao de PATH e variaveis de ambiente.
    [Parameter(Mandatory=$false)]
    [Alias("v")]
    [string]$Verify,
    
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

function Test-GitInstallation {
    Write-Log "[VERIFICACAO] Verificando instalacao do Git..." -Level "Info"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "[ERRO] Git nao encontrado! Instale: https://git-scm.com/download/win" -Level "Error"
        return $false
    } else {
        Write-Log "[SUCESSO] Git encontrado: $(git --version)" -Level "Success"
        return $true
    }
}

function Test-DiskSpace {
    Write-Log "[VERIFICACAO] Verificando espaco em disco..." -Level "Info"
    try {
        $FreeSpace = (Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Where-Object DeviceID -eq "C:").FreeSpace
        $FreeSpaceGB = [math]::Round($FreeSpace / 1GB, 2)
        
        if ($FreeSpace -lt 3GB) {
            Write-Log "[ERRO] Espaco insuficiente no drive C: $FreeSpaceGB GB (minimo 3GB necessarios)" -Level "Error"
            return $false
        } else {
            Write-Log "[SUCESSO] Espaco em disco: $FreeSpaceGB GB livres (minimo 3GB)" -Level "Success"
            return $true
        }
    } catch {
        Write-Log "[AVISO] Nao foi possivel verificar espaco em disco" -Level "Warning"
        return $true  # Continuar mesmo com aviso
    }
}

function Test-JsonFile {
    Write-Log "[VERIFICACAO] Verificando e carregando arquivo software.json..." -Level "Info"
    $ConfigFile = Join-Path $PSScriptRoot "config\software.json"
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "[ERRO] Arquivo 'software.json' nao encontrado em: $ConfigFile" -Level "Error"
        return $null
    }
    
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $SoftwareCount = ($Config.software.PSObject.Properties | Measure-Object).Count
        Write-Log "[SUCESSO] Configuracao carregada: $($SoftwareCount) softwares disponiveis." -Level "Success"
        return $Config
    }
    catch {
        Write-Log "[ERRO] Erro ao ler arquivo JSON: $($_.Exception.Message)." -Level "Error"
        return $null
    }
}

function Test-InternetConnection {
    Write-Log "[VERIFICACAO] Verificando conexao com internet..." -Level "Info"
    try {
        $TestConnection = Test-NetConnection -ComputerName "chocolatey.org" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $TestConnection) {
            Write-Log "[ERRO] Sem conexao com internet (chocolatey.org inacessivel)" -Level "Error"
            return $false
        } else {
            Write-Log "[SUCESSO] Conexao com internet confirmada" -Level "Success"
            return $true
        }
    }
    catch {
        Write-Log "[ERRO] Erro ao verificar conexao: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Get-WorkingDirectory {
    Write-Log "[VERIFICACAO] Verificando privilegios de administrador..." -Level "Info"
    $CurrentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $IsAdmin = $CurrentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($IsAdmin) {
        Write-Log "[SUCESSO] Modo ADMINISTRADOR detectado (Chocolatey)" -Level "Success"
    } else {
        Write-Log "[INFO] Modo USUARIO detectado (Instalacao Portatil)" -Level "Info"
    }
    
    Write-Host ""  # Quebra de linha após verificação geral
    
    if (-not $IsAdmin) {
        return "$env:USERPROFILE\Documents\TEMP_ENV"
    } else {
        return $null
    }
}

function Get-SoftwareList {
    param(
        [string]$UserInput,
        [PSCustomObject]$Config
    )
    
    if ($UserInput -eq "all") {
        # Retornar todos os softwares do JSON com suas configurações.
        $AllSoftware = @()
        foreach ($SoftwareName in $Config.software.PSObject.Properties.Name) {
            $SoftwareConfig = $Config.software.$SoftwareName
            $AllSoftware += [PSCustomObject]@{
                Name = $SoftwareName
                Config = $SoftwareConfig
            }
        }
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
                    $SoftwareConfig = $Config.software.$CleanName
                    $ValidSoftware += [PSCustomObject]@{
                        Name = $CleanName
                        Config = $SoftwareConfig
                    }
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
            $SoftwareNames = $ValidSoftware | ForEach-Object { $_.Name }
            Write-Log "[INSTALACAO] Softwares selecionados: $($SoftwareNames -join ', ')." -Level "Info"
        }
        
        return $ValidSoftware
    }
}

function Install-ViaChocolatey {
    param(
        [string]$SoftwareName,
        [PSCustomObject]$SoftwareConfig,
        [bool]$Force = $false
    )
    
    $PackageName = $SoftwareConfig.chocolatey.packageName
    
    # Informar sobre modo forcado se aplicavel
    if ($Force) {
        Write-Log "[FORCE] Modo forcado ativado. Reinstalando $($SoftwareConfig.name)..." -Level "Info"
    }
    
    Write-Log "[CHOCOLATEY] Instalando via Chocolatey: $($SoftwareConfig.name)." -Level "Info"
    
    try {
        $Result = choco install $PackageName -y --no-progress --force
        if ($LASTEXITCODE -eq 0) {
            Write-Log "[SUCESSO] $($SoftwareConfig.name) instalado com sucesso!" -Level "Success"
            
            # Configurar variaveis de ambiente apos instalacao bem-sucedida
            $null = Set-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $true
            
            # Verificar se as configuracoes foram aplicadas corretamente
            $null = Compare-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $true
            
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
        [string]$SoftwareName,
        [PSCustomObject]$SoftwareConfig,
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
    
    # Configurar diretorios para instalacao portatil
    $ExtractFolder = $SoftwareConfig.portable.extractFolder
    $SoftwareFolder = Join-Path $BasePath $ExtractFolder
    
    # Se for modo forcado, remover instalacao anterior
    if ($Force -and (Test-Path $SoftwareFolder)) {
        Write-Log "[FORCE] Removendo instalacao anterior: $SoftwareFolder" -Level "Info"
        Remove-Item $SoftwareFolder -Recurse -Force -ErrorAction SilentlyContinue
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
        
        # Configurar variaveis de ambiente apos instalacao bem-sucedida
        $null = Set-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $false -InstallPath $BasePath
        
        # Verificar se as configuracoes foram aplicadas corretamente
        $null = Compare-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $false -InstallPath $BasePath
        
        return $true
    }
    catch {
        Write-Log "[ERRO] Erro na instalacao portatil: $($_.Exception.Message)." -Level "Error"
        return $false
    }
}

function Test-SoftwareInstalled {
    param(
        [string]$SoftwareName,
        [PSCustomObject]$SoftwareConfig,
        [bool]$IsAdmin,
        [string]$InstallPath = $null
    )
    
    Write-Log "[VERIFICACAO] Verificando se $($SoftwareConfig.name) ja esta instalado..." -Level "Info"
    
    if ($IsAdmin) {
        # Verificar via Chocolatey
        try {
            $PackageName = $SoftwareConfig.chocolatey.packageName
            $InstalledPackages = choco list --local-only $PackageName --exact 2>$null
            $IsInstalled = ($InstalledPackages -match $PackageName)
            
            if ($IsInstalled) {
                Write-Log "[JA_INSTALADO] $($SoftwareConfig.name) ja esta instalado via Chocolatey" -Level "Warning"
            } else {
                Write-Log "[NAO_INSTALADO] $($SoftwareConfig.name) nao foi encontrado via Chocolatey" -Level "Info"
            }
            
            return $IsInstalled
        }
        catch {
            Write-Log "[ERRO] Erro ao verificar instalacao via Chocolatey: $($_.Exception.Message)" -Level "Error"
            return $false
        }
    }
    else {
        # Verificar instalação portátil
        if (-not $SoftwareConfig.portable) {
            Write-Log "[AVISO] $($SoftwareConfig.name) requer privilegios de administrador" -Level "Warning"
            return $false
        }
        
        $ExtractFolder = $SoftwareConfig.portable.extractFolder
        $SoftwareFolder = Join-Path $InstallPath $ExtractFolder
        
        if (Test-Path $SoftwareFolder) {
            $Contents = Get-ChildItem $SoftwareFolder -ErrorAction SilentlyContinue
            $IsInstalled = ($Contents.Count -gt 0)
            
            if ($IsInstalled) {
                Write-Log "[JA_INSTALADO] $($SoftwareConfig.name) ja esta instalado em: $SoftwareFolder" -Level "Warning"
            } else {
                Write-Log "[NAO_INSTALADO] $($SoftwareConfig.name) pasta existe mas esta vazia: $SoftwareFolder" -Level "Info"
            }
            
            return $IsInstalled
        }
        
        Write-Log "[NAO_INSTALADO] $($SoftwareConfig.name) nao foi encontrado em: $SoftwareFolder" -Level "Info"
        return $false
    }
}

function Compare-PathConfiguration {
    param(
        [string]$SoftwareName,
        [PSCustomObject]$SoftwareConfig,
        [bool]$IsAdmin,
        [string]$InstallPath = $null
    )
    
    # Verificar se existe configuracao de PATH no JSON
    if (-not $SoftwareConfig.path) {
        Write-Log "[INFO] $($SoftwareConfig.name): Nenhuma configuracao de PATH definida no JSON" -Level "Info"
        return $true
    }
    
    # Selecionar configuracao baseada no modo
    $PathConfig = if ($IsAdmin) { $SoftwareConfig.path.chocolatey } else { $SoftwareConfig.path.portable }
    
    if (-not $PathConfig) {
        Write-Log "[AVISO] $($SoftwareConfig.name): Configuracao de PATH nao disponivel para este modo" -Level "Warning"
        return $false
    }
    
    # Verificar se é auto-configurado
    if ($PathConfig.autoConfigured) {
        Write-Log "[INFO] $($SoftwareConfig.name): PATH configurado automaticamente pelo instalador" -Level "Success"
        return $true
    }
    
    $AllValid = $true
    
    # Verificar variáveis de ambiente personalizadas
    if ($PathConfig.environmentVariables) {
        foreach ($EnvVar in $PathConfig.environmentVariables.PSObject.Properties) {
            $VarName = $EnvVar.Name
            $ExpectedValue = Expand-PathTokens -Path $EnvVar.Value -InstallPath $InstallPath
            
            # Resolver wildcards
            if ($ExpectedValue -match '\*') {
                $ResolvedPath = Get-ChildItem (Split-Path $ExpectedValue -Parent) -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match ($ExpectedValue -replace '.*\\(.+)', '$1' -replace '\*', '.*') } | 
                               Select-Object -First 1 -ExpandProperty FullName
                if ($ResolvedPath) {
                    $ExpectedValue = $ResolvedPath
                }
            }
            
            $CurrentValue = [Environment]::GetEnvironmentVariable($VarName, $PathConfig.scope)
            
            if ($CurrentValue -eq $ExpectedValue) {
                Write-Log "[OK] $VarName esta configurado corretamente: $CurrentValue" -Level "Success"
            }
            elseif ([string]::IsNullOrEmpty($CurrentValue)) {
                Write-Log "[ERRO] $VarName nao esta configurado. Esperado: $ExpectedValue" -Level "Error"
                $AllValid = $false
            }
            else {
                Write-Log "[DIFERENCA] $VarName configurado diferente:" -Level "Warning"
                Write-Log "  Sistema: $CurrentValue" -Level "Warning"
                Write-Log "  JSON:    $ExpectedValue" -Level "Warning"
                $AllValid = $false
            }
        }
    }
    
    # Verificar PATHs principais
    if ($PathConfig.paths) {
        $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", $PathConfig.scope)
        
        foreach ($PathEntry in $PathConfig.paths) {
            $ExpandedPath = Expand-PathTokens -Path $PathEntry -InstallPath $InstallPath
            
            # Resolver wildcards
            if ($ExpandedPath -match '\*') {
                $ResolvedPath = Get-ChildItem (Split-Path $ExpandedPath -Parent) -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match ($ExpandedPath -replace '.*\\(.+)', '$1' -replace '\*', '.*') } | 
                               Select-Object -First 1 -ExpandProperty FullName
                if ($ResolvedPath) {
                    $ExpandedPath = $ResolvedPath
                }
            }
            
            if ($CurrentPath -like "*$ExpandedPath*") {
                Write-Log "[OK] PATH configurado: $ExpandedPath" -Level "Success"
            }
            else {
                Write-Log "[ERRO] PATH nao encontrado no sistema: $ExpandedPath" -Level "Error"
                $AllValid = $false
            }
        }
    }
    
    # Verificar PATHs adicionais
    if ($SoftwareConfig.path.additional) {
        foreach ($AdditionalPath in $SoftwareConfig.path.additional) {
            $ExpandedPath = Expand-PathTokens -Path $AdditionalPath.path -InstallPath $InstallPath
            $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", $AdditionalPath.scope)
            
            if ($CurrentPath -like "*$ExpandedPath*") {
                Write-Log "[OK] PATH adicional ($($AdditionalPath.description)): $ExpandedPath" -Level "Success"
            }
            else {
                Write-Log "[ERRO] PATH adicional nao encontrado: $ExpandedPath ($($AdditionalPath.description))" -Level "Error"
                $AllValid = $false
            }
        }
    }
    
    return $AllValid
}

function Set-PathConfiguration {
    param(
        [string]$SoftwareName,
        [PSCustomObject]$SoftwareConfig,
        [bool]$IsAdmin,
        [string]$InstallPath = $null
    )
    
    # Verificar se existe configuracao de PATH no JSON
    if (-not $SoftwareConfig.path) {
        return $true
    }
    
    # Selecionar configuracao baseada no modo
    $PathConfig = if ($IsAdmin) { $SoftwareConfig.path.chocolatey } else { $SoftwareConfig.path.portable }
    
    if (-not $PathConfig -or $PathConfig.autoConfigured) {
        return $true
    }
    
    Write-Log "[CONFIG] Configurando PATH para $($SoftwareConfig.name)..." -Level "Info"
    
    # Configurar variáveis de ambiente personalizadas
    if ($PathConfig.environmentVariables) {
        foreach ($EnvVar in $PathConfig.environmentVariables.PSObject.Properties) {
            $VarName = $EnvVar.Name
            $VarValue = Expand-PathTokens -Path $EnvVar.Value -InstallPath $InstallPath
            
            # Resolver wildcards
            if ($VarValue -match '\*') {
                $ResolvedPath = Get-ChildItem (Split-Path $VarValue -Parent) -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match ($VarValue -replace '.*\\(.+)', '$1' -replace '\*', '.*') } | 
                               Select-Object -First 1 -ExpandProperty FullName
                if ($ResolvedPath) {
                    $VarValue = $ResolvedPath
                }
            }
            
            if (Test-Path $VarValue) {
                $CurrentValue = [Environment]::GetEnvironmentVariable($VarName, $PathConfig.scope)
                if ($CurrentValue -ne $VarValue) {
                    Write-Log "[CONFIG] Configurando $VarName = $VarValue" -Level "Info"
                    [Environment]::SetEnvironmentVariable($VarName, $VarValue, $PathConfig.scope)
                    Write-Log "[SUCESSO] $VarName configurado" -Level "Success"
                }
            }
        }
    }
    
    # Configurar PATHs
    if ($PathConfig.paths) {
        $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", $PathConfig.scope)
        $PathsToAdd = @()
        
        foreach ($PathEntry in $PathConfig.paths) {
            $ExpandedPath = Expand-PathTokens -Path $PathEntry -InstallPath $InstallPath
            
            # Resolver wildcards
            if ($ExpandedPath -match '\*') {
                $ResolvedPath = Get-ChildItem (Split-Path $ExpandedPath -Parent) -Directory -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -match ($ExpandedPath -replace '.*\\(.+)', '$1' -replace '\*', '.*') } | 
                               Select-Object -First 1 -ExpandProperty FullName
                if ($ResolvedPath) {
                    $ExpandedPath = $ResolvedPath
                }
            }
            
            if (Test-Path $ExpandedPath) {
                if ($CurrentPath -notlike "*$ExpandedPath*") {
                    $PathsToAdd += $ExpandedPath
                }
            }
        }
        
        if ($PathsToAdd.Count -gt 0) {
            Write-Log "[CONFIG] Adicionando ao PATH: $($PathsToAdd -join ';')" -Level "Info"
            $NewPath = "$CurrentPath;$($PathsToAdd -join ';')"
            [Environment]::SetEnvironmentVariable("PATH", $NewPath, $PathConfig.scope)
            Write-Log "[SUCESSO] PATH atualizado" -Level "Success"
        }
    }
    
    # Configurar PATHs adicionais
    if ($SoftwareConfig.path.additional) {
        foreach ($AdditionalPath in $SoftwareConfig.path.additional) {
            $ExpandedPath = Expand-PathTokens -Path $AdditionalPath.path -InstallPath $InstallPath
            $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", $AdditionalPath.scope)
            
            if ($CurrentPath -notlike "*$ExpandedPath*") {
                Write-Log "[CONFIG] Adicionando PATH adicional ($($AdditionalPath.description)): $ExpandedPath" -Level "Info"
                [Environment]::SetEnvironmentVariable("PATH", "$CurrentPath;$ExpandedPath", $AdditionalPath.scope)
                Write-Log "[SUCESSO] PATH adicional configurado" -Level "Success"
            }
        }
    }
    
    return $true
}

function Expand-PathTokens {
    param(
        [string]$Path,
        [string]$InstallPath = $null
    )
    
    $ExpandedPath = $Path
    $ExpandedPath = $ExpandedPath -replace '\{InstallPath\}', $InstallPath
    $ExpandedPath = $ExpandedPath -replace '\{AppData\}', $env:APPDATA
    $ExpandedPath = $ExpandedPath -replace '\{ProgramFiles\}', ${env:ProgramFiles}
    
    return $ExpandedPath
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
        $Config = Test-JsonFile
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
    Write-Host "  -Verify   (-v)   Verificar PATH e variaveis (especificos ou 'all')" -ForegroundColor Green
    Write-Host "  -Help     (-h)   Mostrar esta ajuda" -ForegroundColor Green
    Write-Host ""
    Write-Host "EXEMPLOS:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 -Install all                   # Instalar todos os softwares" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -Install 'vscode,python'       # Instalar softwares especificos" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -i vscode                      # Instalar apenas VS Code" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -i nodejs -Force               # Forcar reinstalacao do Node.js" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -Verify all                    # Verificar PATH de todos os softwares" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -v python                      # Verificar apenas configuracao Python" -ForegroundColor Cyan
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
if ($Help -or (-not $Install -and -not $Clean -and -not $Verify)) {
    Show-Help
    exit 0
}

# ===== LOGICA DE LIMPEZA =====
if ($Clean) {
    # 1. Verificar administrador
    $TempPath = Get-WorkingDirectory
    $IsAdmin = ($TempPath -eq $null)
    
    # 2. Executar função de apagar
    Clean-Environment -IsAdmin $IsAdmin -TempPath $TempPath
    exit 0
}

# ===== LOGICA DE INSTALACAO =====
if ($Install) {
    # 1. Verificar instalação do Git
    if (-not (Test-GitInstallation)) {
        exit 1
    }
    
    # 2. Verificar espaço de disco
    if (-not (Test-DiskSpace)) {
        exit 1
    }
    
    # 3. Verificar arquivo.json e carregar configuração
    $Config = Test-JsonFile
    if (-not $Config) {
        exit 1
    }
    
    # 4. Verificar conexão com internet
    if (-not (Test-InternetConnection)) {
        exit 1
    }
    
    # 5. Verificar administrador
    $TempPath = Get-WorkingDirectory
    $IsAdmin = ($TempPath -eq $null)
    
    # Configurar Chocolatey se admin
    if ($IsAdmin -and -not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "[CHOCOLATEY] Instalando Chocolatey..." -Level "Info"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            refreshenv
            Write-Log "[SUCESSO] Chocolatey instalado com sucesso!" -Level "Success"
            Write-Host ""
        }
        catch {
            Write-Log "[ERRO] Falha na instalacao do Chocolatey: $($_.Exception.Message)" -Level "Error"
            exit 1
        }
    }
    
    # Obter lista de softwares
    $SoftwareList = Get-SoftwareList -UserInput $Install -Config $Config
    if ($SoftwareList.Count -eq 0) {
        Write-Log "[ERRO] Nenhum software valido encontrado para instalacao" -Level "Error"
        exit 1
    }
    
    # Criar diretório portátil se necessário
    if (-not $IsAdmin -and $TempPath -and -not (Test-Path $TempPath)) {
        Write-Log "[DIRETORIO] Criando diretorio de instalacao portatil: $TempPath" -Level "Info"
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
        Write-Host ""
    }
    
    Write-Log "[INICIO] Iniciando instalacao de $($SoftwareList.Count) software(s)..." -Level "Info"
    Write-Host ""
    $SuccessCount = 0
    
    # 6. Para cada software do parâmetro
    foreach ($SoftwareItem in $SoftwareList) {
        $SoftwareName = $SoftwareItem.Name
        $SoftwareConfig = $SoftwareItem.Config
        Write-Log "[PROCESSANDO] $($SoftwareConfig.name)" -Level "Info"
        
        # 6.1. Verificar parâmetro force
        $ShouldInstall = $false
        
        if ($Force) {
            # 6.1.1. Se force, instale o software
            Write-Log "[FORCE] Modo forcado ativado - reinstalando" -Level "Info"
            $ShouldInstall = $true
        }
        else {
            # 6.1.2. Se não force, verifique se o software existe
            $IsInstalled = Test-SoftwareInstalled -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $IsAdmin -InstallPath $TempPath
            
            if ($IsInstalled) {
                # 6.1.2.1. Se existe, pule
                Write-Log "[JA_INSTALADO] Software ja esta instalado - pulando" -Level "Warning"
                $ShouldInstall = $false
            }
            else {
                # 6.1.2.2. Se não existe, instale
                Write-Log "[NAO_INSTALADO] Software nao encontrado - instalando" -Level "Info"
                $ShouldInstall = $true
            }
        }
        
        # Instalar se necessário
        if ($ShouldInstall) {
            $InstallSuccess = $false
            
            if ($IsAdmin) {
                $InstallSuccess = Install-ViaChocolatey -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -Force $Force
            }
            else {
                $InstallSuccess = Install-Portable -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -BasePath $TempPath -Force $Force
            }
            
            if ($InstallSuccess) {
                $SuccessCount++
            }
        }
        else {
            # Mesmo que não instale, verificar PATH se software já existe
            if ($SoftwareConfig.path) {
                $null = Compare-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $IsAdmin -InstallPath $TempPath
            }
        }
        
        Write-Host ""  # Pular linha após cada software
    }
    
    # Relatório final
    $TotalSoftware = $SoftwareList.Count
    if ($TotalSoftware -eq $null) {
        $TotalSoftware = ($SoftwareList | Measure-Object).Count
    }
    
    Write-Log "[CONCLUIDO] Instalacao concluida!" -Level "Success"
    Write-Log "[RELATORIO] Sucessos: $SuccessCount de $TotalSoftware" -Level "Info"
    
    if (-not $IsAdmin -and $SuccessCount -gt 0) {
        Write-Log "[DIRETORIO] Softwares instalados em: $TempPath" -Level "Info"
    }
}

# ===== LOGICA DE VERIFICACAO =====
if ($Verify) {
    # 1. Verificar administrador
    $TempPath = Get-WorkingDirectory
    $IsAdmin = ($TempPath -eq $null)
    
    # 2. Verificar arquivo.json e carregar configuração
    $Config = Test-JsonFile
    if (-not $Config) {
        exit 1
    }
    Write-Host ""
    
    # Obter lista de softwares
    $SoftwareList = Get-SoftwareList -UserInput $Verify -Config $Config
    if ($SoftwareList.Count -eq 0) {
        Write-Log "[ERRO] Nenhum software valido encontrado para verificacao" -Level "Error"
        exit 1
    }
    
    Write-Log "[INICIO] Verificando configuracao de $($SoftwareList.Count) software(s)..." -Level "Info"
    Write-Host ""
    $ValidCount = 0
    
    # 3. Para cada software do parâmetro
    foreach ($SoftwareItem in $SoftwareList) {
        $SoftwareName = $SoftwareItem.Name
        $SoftwareConfig = $SoftwareItem.Config
        Write-Log "[VERIFICANDO] $($SoftwareConfig.name)" -Level "Info"
        
        # 3.2. Verificar caminho PATH no arquivo.json
        if ($SoftwareConfig.path) {
            # 3.1.1. Se tiver path, faça verificação
            $IsValid = Compare-PathConfiguration -SoftwareName $SoftwareName -SoftwareConfig $SoftwareConfig -IsAdmin $IsAdmin -InstallPath $TempPath
            
            if ($IsValid) {
                $ValidCount++
                Write-Log "[OK] $($SoftwareConfig.name): Configuracao VALIDA" -Level "Success"
            }
            else {
                Write-Log "[ERRO] $($SoftwareConfig.name): Configuracao com PROBLEMAS" -Level "Error"
            }
        }
        else {
            Write-Log "[INFO] $($SoftwareConfig.name): Nenhuma configuracao de PATH necessaria" -Level "Info"
            $ValidCount++
        }
        
        Write-Host ""  # Pular linha após cada software
    }
    
    # Relatório final
    $TotalSoftware = $SoftwareList.Count
    if ($TotalSoftware -eq $null) {
        $TotalSoftware = ($SoftwareList | Measure-Object).Count
    }
    
    Write-Log "[CONCLUIDO] Verificacao concluida!" -Level "Success"
    Write-Log "[RELATORIO] Validos: $ValidCount de $TotalSoftware" -Level "Info"
    
    if ($ValidCount -lt $TotalSoftware) {
        Write-Log "[DICA] Execute setup.ps1 -Install [software] para reinstalar softwares com problemas" -Level "Info"
    }
}
