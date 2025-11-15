# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================
function log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateSet("info", "warning", "error", "success")]
        [string]$Level = "info"
    )
    
    $Colors = @{
        "info" = "White"
        "warning" = "Yellow"  
        "error" = "Red"
        "success" = "Green"
    }
    
    $Timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$Timestamp] [$($Level.ToUpper())] $Message" -ForegroundColor $Colors[$Level]
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        log "Este script precisa ser executado como Administrador." error
        log "Por favor, clique com o botão direito no PowerShell e 'Executar como Administrador'." error
        # Espera o usuário pressionar Enter para fechar
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
    log "Executando como Administrador." "Success"
}

function Ensure-Chocolatey {
    # Verifica se o choco existe no Path
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        log "Chocolatey já está instalado." success
        return
    }

    log "Chocolatey não encontrado. Instalando..." warning
    try {
        winget install -e --id=Chocolatey.Chocolatey -s winget -hiden -accept-source-agreements -accept-package-agreements
        # Recarrega o Path para garantir que o choco esteja disponível
        log "Recarregando Path da sessão para encontrar o Chocolatey..."
        $newUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $newMachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $env:Path = $newUserPath + ";" + $newMachinePath

        log "Chocolatey instalado com sucesso." success
    } catch {
        log "Falha crítica ao instalar Chocolatey: $_" error
        log "A instalação não pode continuar sem o Chocolatey." error
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
}

function Install-Software {
    log "Iniciando instalação dos softwares..."

    # Adicione ou remova pacotes Choco aqui.
    $softwareList = @(
        "vscode",
        "python",
        "openjdk",
        "swi-prolog",
        "nodejs",
        "postgresql16",
        "sqlitebrowser",
        "git",
        "jetbrainstoolbox",
        "docker-desktop",
        "postman"
    )

    foreach ($pkg in $softwareList) {
        log "Instalando/Atualizando $pkg..."
        try {
            # Usamos 'upgrade' pois é seguro: instala se não existir, atualiza se já existir.
            choco upgrade $pkg -y -r
        } catch {
            log "Falha ao instalar $pkg." error
        }
    }
    log "Instalação de softwares concluída." success

    log "Recarregando variáveis de ambiente (Path) nesta sessão..."
    refreshenv
}

function Setup-CustomProfile {
    log "Configurando o profile personalizado..."
    
    # -----------------------------------------------------------------
    # Definir variáveis 
    $meuProfile = (Resolve-Path -Path "$PSScriptRoot\powershell-profile.ps1").Path
    $profileOficial = $PROFILE
    $linhaParaAdicionar = ". '$meuProfile'"
    # -----------------------------------------------------------------
        
    # Cria o arquivo de profile se ele não existir
    if (-not (Test-Path $profileOficial)) {
        New-Item -Path $profileOficial -ItemType File -Force | Out-Null
        log "Arquivo de profile oficial criado em $profileOficial"
    }
        
    # Adiciona a linha, mas só se ela já não existir
    if (-not (Get-Content $profileOficial | Select-String -Pattern $linhaParaAdicionar -SimpleMatch -Quiet)) {
        Add-Content -Path $profileOficial -Value $linhaParaAdicionar
        log "Profile personalizado adicionado ao $profileOficial" success
    } else {
        log "Profile personalizado já estava configurado."
    }
}

# ============================================================
# EXECUÇÃO PRINCIPAL
# ============================================================

# 1. Garante que estamos como Admin
Test-Admin

# 2. Garante que o Choco está pronto
Ensure-Chocolatey

# 3. Instala todo o software
Install-Software

# 4. Configura o profile para a próxima inicialização
Setup-CustomProfile

# 5. Carrega o profile nesta sessão
log "Carregando o novo profile na sessão atual..." warning
. $PROFILE

log "SETUP CONCLUÍDO!" success
log "Lembre-se de fechar e reabrir seus terminais." warning
