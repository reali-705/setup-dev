# ============================================================
# SETUP DE DESENVOLVIMENTO v2.0
# Um script único para provisionar uma máquina de dev.
# Requer execução como Administrador.
# ============================================================

# ============================================================
# FUNÇÃO AUXILIAR: LOG DO TERMINAL
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
    
    $Timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Colors[$Level]
}

# ============================================================
# FUNÇÃO AUXILIAR: RECARREGAR PATH
# ============================================================
function Reload-Environment {
    Write-Log "Recarregando variáveis de ambiente (Path) nesta sessão..." "Info"
    
    # Lê os Paths "frescos" (de Usuário e Máquina) diretamente do Registro
    $newUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $newMachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Sobrescreve o Path da sessão atual
    $env:Path = $newUserPath + ";" + $newMachinePath
    Write-Log "Variáveis recarregadas." "Success"
}

# ============================================================
# PASSO 0: VERIFICAR SE É ADMIN
# ============================================================
function Test-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log "Erro: Este script precisa ser executado como Administrador." "Error"
        Write-Host "Por favor, clique com o botão direito no PowerShell e 'Executar como Administrador'."
        # Espera o usuário pressionar Enter para fechar
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
    Write-Log "Executando como Administrador." "Success"
}

# ============================================================
# PASSO 1: DETECTAR/INSTALAR CHOCOLATEY
# ============================================================
function Ensure-Chocolatey {
    # Verifica se o choco existe no Path (após a limpeza, não deve existir)
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey já está instalado." "Success"
        return $true
    }

    Write-Log "Chocolatey não encontrado. Instalando..." "Info"
    try {
        # Define a política de execução e protocolos de segurança para a instalação
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        # Comando de instalação oficial do Choco
        $installScript = ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Invoke-Expression $installScript
        
        Write-Log "Chocolatey instalado com sucesso." "Success"
        
        # IMPORTANTE: Recarrega o ambiente AGORA para que o choco possa ser usado no PASSO 2
        Reload-Environment
        return $true
    } catch {
        Write-Log "Falha crítica ao instalar Chocolatey: $_" "Error"
        return $false
    }
}

# ============================================================
# PASSO 2: INSTALAR SOFTWARES DA LISTA
# ============================================================
function Install-Software {
    Write-Log "Iniciando instalação dos softwares..." "Info"

    # Adicione ou remova pacotes Choco aqui.
    $softwareList = @(
        "vscode",
        "python",
        "openjdk",
        "swi-prolog",
        "nodejs",
        "postgresql16",
        "sqlitebrowser"
    )

    foreach ($pkg in $softwareList) {
        Write-Log "Instalando/Atualizando $pkg..." "Info"
        try {
            # Usamos 'upgrade' pois é seguro: instala se não existir, atualiza se já existir.
            choco upgrade $pkg -y -r
        } catch {
            Write-Log "Falha ao instalar $pkg." "Error"
        }
    }
    Write-Log "Instalação de softwares concluída." "Success"
}

# ============================================================
# PASSO 3: CONFIGURAR O PROFILE PERSONALIZADO
# ============================================================
function Setup-CustomProfile {
    Write-Log "Configurando o profile personalizado..." "Info"
    
    # -----------------------------------------------------------------
    # Deve apontar para onde o seu repositório `setup-dev` foi/será clonado.
    $meuProfile = (Resolve-Path -Path "$PSScriptRoot\powershell-profile.ps1").Path
    # -----------------------------------------------------------------
    
    # $PROFILE é a variável do PowerShell que aponta para o profile do usuário atual
    $profileOficial = $PROFILE
    
    # Cria o arquivo de profile se ele não existir
    if (-not (Test-Path $profileOficial)) {
        New-Item -Path $profileOficial -ItemType File -Force | Out-Null
        Write-Log "Arquivo de profile oficial criado em $profileOficial" "Info"
    }
    
    # A linha que queremos adicionar (o ". " no início executa o script)
    $linhaParaAdicionar = ". '$meuProfile'"
    
    # Adiciona a linha, mas só se ela já não existir
    if (-not (Get-Content $profileOficial | Select-String -Pattern $linhaParaAdicionar -Quiet)) {
        Add-Content -Path $profileOficial -Value $linhaParaAdicionar
        Write-Log "Profile personalizado adicionado ao $profileOficial" "Success"
    } else {
        Write-Log "Profile personalizado já estava configurado." "Info"
    }
}

# ============================================================
# EXECUÇÃO PRINCIPAL (JUNTANDO TUDO)
# ============================================================

# 1. Garante que estamos como Admin
Test-Admin

# 2. Garante que o Choco está pronto
if (Ensure-Chocolatey) {
    
    # 3. Instala todo o software
    Install-Software
    
    # 4. Recarrega o Path DE NOVO (para garantir que o profile encontre tudo)
    Reload-Environment
    
    # 5. Configura o profile para a próxima inicialização
    Setup-CustomProfile
    
    # 6. Carrega o profile nesta sessão
    Write-Log "Carregando o novo profile na sessão atual..." "Warning"
    . $PROFILE
    
    Write-Host ""
    Write-Log "SETUP CONCLUÍDO!" "Success"
    Write-Log "Seu novo profile foi carregado nesta sessão de Admin." "Info"
    Write-Log "Lembre-se de fechar e reabrir seus terminais NORMAIS." "Warning"
} else {
    Write-Log "A instalação não pode continuar sem o Chocolatey." "Error"
    Read-Host "Pressione Enter para sair..."
}