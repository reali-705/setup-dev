## ----------------------------------------------------
## SETUP DE DESENVOLVIMENTO - CIENCIA DA COMPUTACAO
## Versao: 1.0.1 - Ajuste de logica e organizacao
## ----------------------------------------------------

[CmdletBinding()]
param(
    # Limpeza inteligente do ambiente.
    [Parameter(Mandatory=$false)]
    [Alias("c")]
    [switch]$Clean,
    
    # Instalar softwares especificos ou "all" para todos.
    [Parameter(Mandatory=$false)]
    [Alias("i")]
    [string]$Install = "all",
    
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

function Format-Input {
    param(
        [string]$Input
    )

    if ($Input -eq "all") {
        return $script:JsonConfig.PSObject.Properties.Name
    }

    $CleanInput = $Input.Trim().ToLower()
    $Delimiters = @(",", ";", "-", " ")

    return $CleanInput.Split($Delimiters, [StringSplitOptions]::RemoveEmptyEntries)
}

function DiskSpaceCheck {
    $Drive = Get-PSDrive -Name C
    if ($Drive.Free -lt 5GB) {
        return $false
    }
    return $true
}

function Detected-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey ja esta instalado." "Success"
        return $true
    }

    Write-Log "Chocolatey nao esta instalado." "Warning"
    Write-Log "Instalando Chocolatey..." "Info"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Log "Chocolatey instalado com sucesso." "Success"
            return $true
        } else {
            Write-Log "Falha ao instalar Chocolatey." "Error"
            return $false
        }
    } catch {
        Write-Log "Erro ao instalar Chocolatey: $_" "Error"
        return $false
    }
}

function Extract-Json {
    param(
        [string]$FilePath
    )

    if (-Not (Test-Path $FilePath)) {
        Write-Log "Arquivo JSON nao encontrado: $FilePath" "Error"
        return $null
    }

    try {
        $JsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        return $JsonContent
    } catch {
        Write-Log "Erro ao ler o arquivo JSON: $FilePath" "Error"
        return $null
    }
}

function Extract-SoftwareConfig {
    param(
        [string]$SoftwareName
    )

    if (-not $script:JsonConfig) {
        Write-Log "Configuracao JSON nao carregada." "Error"
        return $null
    }

    $SoftwareConfig = $script:JsonConfig.$SoftwareName
    if (-not $SoftwareConfig) {
        Write-Log "Software nao encontrado na configuracao: $SoftwareName" "Error"
        return $null
    }

    return $SoftwareConfig
}

function Install-From-Chocolatey {
    param(
        [string]$PackageName
    )

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "Chocolatey nao esta disponivel para instalar $PackageName." "Error"
        return $false
    }

    try {
        if (-not (choco search $PackageName --exact --limit 1 2>$null)) {
            Write-Log "Pacote $PackageName nao encontrado no repositorio Chocolatey." "Error"
            return $false
        }
    } catch {
        Write-Log "Falha ao buscar $PackageName no repositorio Chocolatey: $_" "Error"
        return $false
    }

    Write-Log "Tentando instalar/atualizar $PackageName via Chocolatey..." "Info"    
    try {
        choco upgrade $PackageName -y
        Write-Log "Pacote $PackageName instalado/atualizado com sucesso." "Success"
        return $true
    } catch {
        Write-Log "Falha critica ao executar o Chocolatey para $PackageName: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Install-Portable {
    param(
        [psobject]$Config
    )

    if (-not $Config.url) {
        Write-Log "URL de download nao especificada para o software." "Error"
        return $false
    }

    if ($ConfigInstall.path) {
        $ConfigInstall.path = Join-Path -Path $script:PathTemp -ChildPath $ConfigInstall.path
    }

    $Directory = Join-Path -Path $script:PathTemp -ChildPath ($Config.directory)
    $ZipPath = Join-Path -Path $script:PathTemp -ChildPath "$($Config.directory)-zip"

    if (-not (Test-Path -Path $Directory)) {
        Write-Log "Diretorio temporario nao encontrado: $Directory" "Warning"
        Write-Log "Criando diretorio temporario: $Directory" "Info"
        New-Item -ItemType Directory -Path $Directory | Out-Null
    }

    Write-Log "Baixando arquivo de $($Config.url)..." "Info"
    try {
        Invoke-WebRequest -Uri $Config.url -OutFile $ZipPath -ErrorAction Stop
        Write-Log "Download concluido." "Success"
    } catch {
        Write-Log "Falha ao baixar arquivo de $($Config.url): $_" "Error"
        return $false
    }

    Write-Log "Extraindo arquivo para $Directory..." "Info"
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $Directory -Force
        Write-Log "Extracao concluida." "Success"
    } catch {
        Write-Log "Falha ao extrair arquivo para $Directory: $_" "Error"
        return $false
    }

    Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue

    Write-Log "Software portatil instalado em $Directory." "Success"
    return $true
}

function Reload-Path {
    $UserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $MachinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:Path = "$UserPath;$MachinePath"
}

function Add-To-Path {
    param(
        [string]$NewPath,
        [string]$Mode
    )

    if (-not (Test-Path $NewPath)) {
        Write-Log "Caminho nao encontrado: $NewPath" "Error"
        return $false
    }

    $CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", $Mode)
    if ($CurrentPath.Split(";") -contains $NewPath) {
        Write-Log "Caminho ja existe no PATH: $NewPath" "Warning"
        return $null
    }

    [System.Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$NewPath", $Mode)
    Write-Log "Caminho adicionado ao PATH: $NewPath" "Success"
    Reload-Path
}

function Clean-Adm {
    Write-Log "Iniciando limpeza do ambiente em modo administrador..." "Warning"
    # Adicione aqui a logica de limpeza especifica para o modo administrador
}

function Clean-User {
    Write-Log "Iniciando limpeza do ambiente em modo usuario..." "Warning"
    if (Test-Path $script:PathTemp) {
        try {
            Remove-Item -Path $script:PathTemp -Recurse -Force
            Write-Log "Diretorio temporario removido: $script:PathTemp" "Success"
        } catch {
            Write-Log "Falha ao remover diretorio temporario: $_" "Error"
        }
    } else {
        Write-Log "Diretorio temporario nao existe: $script:PathTemp" "Info"
    }
}

function Remove-From-Path {
    Write-Log "Removendo os caminhos PATH das variaveis de ambiente..." "Warning"
    $Accountant = 0

    $PATH-User = $script:JsonConfig.PSObject.Properties.name | ForEach-Object {
        $SoftwareConfig = $script:JsonConfig.$_
        if ($SoftwareConfig -and $SoftwareConfig.portable.path) {
            @($SoftwareConfig.portable.path) | ForEach-Object { Join-Path -Path $script:PathTemp -ChildPath $_ }
        }
    }
    foreach ($Path in $PATH-User) {
        $CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $NewPath = ($CurrentPath.Split(";") | Where-Object { $_ -ne $Path }) -join ";"
        [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Log "Caminho removido do PATH do usuario: $Path" "Info"
        $Accountant++
    }

    $PATH-Machine = $script:JsonConfig.PSObject.Properties.name | ForEach-Object {
        $SoftwareConfig = $script:JsonConfig.$_
        if ($SoftwareConfig -and $SoftwareConfig.chocolatey.path) {
            $SoftwareConfig.chocolatey.path
        }
    }
    foreach ($Path in $PATH-Machine) {
        $CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $NewPath = ($CurrentPath.Split(";") | Where-Object { $_ -ne $Path }) -join ";"
        [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "Machine")
        Write-Log "Caminho removido do PATH da maquina: $Path" "Info"
        $Accountant++
    }

    if ($Accountant -eq 0) {
        Write-Log "Nenhum caminho foi removido do PATH." "Warning"
    } else {
        Write-Log "Total de caminhos removidos do PATH: $Accountant" "Success"
    }
    Reload-Path
}

# ============================================================
# LOGICA PRINCIPAL
# ============================================================

if ($Help) {
    Show-Help
    exit 0
}

# definindo variaveis globais/scripts
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
$script:PathTemp = Join-Path -Path $HOME -ChildPath "setup-dev-temp"
$script:JsonConfig = Extract-Json -FilePath ".\config\software.json"
if (-not $script:JsonConfig) {
    exit 1
}

if ($IsAdmin) {
    Write-Log "Executando em modo administrador." "Warning"
    $InstallMode = "chocolatey"
    $Path-Mode = "Machine"
    if (-not (Detected-Chocolatey)) {
        exit 1
    }
} else {
    Write-Log "Executando em modo usuario." "Warning"
    $InstallMode = "portable"
    $Path-Mode = "User"
    if (-not (Test-Path $script:PathTemp)) {
        New-Item -ItemType Directory -Path $script:PathTemp | Out-Null
    }
}
Write-Host ""

if ($Clean) {
    if ($IsAdmin) {
        Clean-Adm
    } elseif (Test-Path $script:PathTemp) {
        Clean-User
    }
    exit 0
}

if ($Install) {
    if (-not (DiskSpaceCheck)) {
        Write-Log "Espaco em disco insuficiente para a instalacao/atualizacao." "Error"
        exit 1
    }

    $InputSoftwares = Format-Input -Input $Install
    $Accountant = 0

    Write-Log "Iniciando instalacao/atualizacao de softwares: $($InputSoftwares -join ', ')" "Warning"
    foreach ($Software in $InputSoftwares) {
        Write-Host ""
        $Config = Extract-SoftwareConfig -SoftwareName $Software
        if (-not $Config) {
            Write-Log "Software nao encontrado em config/software.json: $Software" "Error"
            continue
        }

        $ConfigInstall = $Config.$InstallMode

        if (-not $ConfigInstall) {
            Write-Log "Método de instalacao '$InstallMode' nao disponivel para $Software. Ignorando..." "Error"
            continue
        }

        if ($IsAdmin) {
            Install-From-Chocolatey -PackageName $ConfigInstall.packageName
        } else {
            Install-Portable -Config $ConfigInstall
        }

        if ($ConfigInstall.path) {
            foreach ($NewPath in $ConfigInstall.path) {
                Add-To-Path -NewPath $NewPath -Mode $Path-Mode
            }
        }

        $Accountant++
    }

    Write-Host ""
    if ($Accountant -eq 0) {
        Write-Log "Nenhum software foi instalado/atualizado." "Error"
        exit 1
    }
    Write-Log "Instalacao/atualizacao concluida. Total de softwares processados: $Accountant / $($InputSoftwares.Count)" "Success"
}