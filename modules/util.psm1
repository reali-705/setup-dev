# =========================================================
# MÓDULO: UTIL (Funções Base)
# =========================================================

<#
.SYNOPSIS
    Imprime uma mensagem formatada no console (Host).

.DESCRIPTION
    Função de log padronizada que adiciona um timestamp (HH:mm:ss) e cores
    com base no nível da mensagem (Info, Warning, Error, Success, Debug).

.PARAMETER Message
    O conteúdo da mensagem a ser exibida. Este é um parâmetro posicional.
    (Aliases: -m, -msg)

.PARAMETER Level
    O nível da mensagem, que controla a cor. (Padrão: "Info")
    (Alias: -l)

.EXAMPLE
    PS C:\> wl "Servidor iniciado com sucesso." -l Success
    [14:30:01] [Success] Servidor iniciado com sucesso.

.EXAMPLE
    PS C:\> wl "Arquivo config.json não encontrado."
    [14:30:05] [Info] Arquivo config.json não encontrado.

.NOTES
    Alias de função: wl
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias("m", "msg")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias("l")]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Level = "Info"
    )
    
    $Colors = @{
        "Info"    = "White"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Success" = "Green"
        "Debug"   = "Gray"
    }
    
    $Timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Colors[$Level]
}

<#
.SYNOPSIS
    Define o esquema de cores da sintaxe do PSReadLine para a sessão atual.

.DESCRIPTION
    Personaliza as cores dos comandos, parâmetros, strings, etc.,
    que você digita no terminal.

.NOTES
    Alias de função: tst
    As configurações são válidas apenas para a sessão atual e
    precisam ser carregadas pelo script de profile.
#>
function Set-TerminalSyntaxTheme {
    Write-Log "Aplicando tema de sintaxe ao terminal..."

    Set-PSReadLineOption -Colors @{
        Command            = [ConsoleColor]::Cyan
        Parameter          = [ConsoleColor]::Yellow
        String             = [ConsoleColor]::Green
        Number             = [ConsoleColor]::Magenta
        Operator           = [ConsoleColor]::White
        Variable           = [ConsoleColor]::Blue
        Type               = [ConsoleColor]::DarkCyan
        Comment            = [ConsoleColor]::DarkGreen
    }
}

<#
.SYNOPSIS
    Configura o autocompletar (Tab) para usar menus e histórico.

.DESCRIPTION
    Ativa duas funcionalidades de produtividade:
    1. O menu de autocompletar interativo (modo 'Windows').
    2. As "sugestões fantasma" baseadas no seu histórico (modo 'InlineView').

.NOTES
    Alias de função: tc
    As configurações são válidas apenas para a sessão atual e
    precisam ser carregadas pelo script de profile.
#>
function Set-TerminalCompletion {
    Write-Log "Aplicando configuracoes de autocompletar..."

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
}

# =========================================================
# EXPORTS E ALIASES DAS FUNÇÕES
# =========================================================

Set-Alias -Name "wl" -Value "Write-Log"
Set-Alias -Name "tst" -Value "Set-TerminalSyntaxTheme"
Set-Alias -Name "tc" -Value "Set-TerminalCompletion"
Export-ModuleMember -Function (
    Write-Log,
    Set-TerminalSyntaxTheme,
    Set-TerminalCompletion
)