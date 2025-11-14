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

.PARAMETER Type
    O nível da mensagem, que controla a cor. (Padrão: "Info")
    (Alias: -t)

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
        [Alias("t")]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug", "Atenção")]
        [string]$Type = "Info"
    )
    
    $Colors = @{
        "Info"    = "White"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Success" = "Green"
        "Debug"   = "Gray"
        "Atenção"= "Cyan"
    }
    
    $Timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$Timestamp] [$Type] $Message" -ForegroundColor $Colors[$Type]
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
    Set-PSReadLineOption -Colors @{
        Command            = [ConsoleColor]::DarkYellow
        Parameter          = [ConsoleColor]::Cyan
        String             = [ConsoleColor]::Green
        Number             = [ConsoleColor]::Blue
        Operator           = [ConsoleColor]::DarkMagenta
        Variable           = [ConsoleColor]::Blue
        Type               = [ConsoleColor]::White
        Comment            = [ConsoleColor]::DarkGreen
    }
}

# =========================================================
# EXPORTS E ALIASES DAS FUNÇÕES
# =========================================================

Set-Alias -Name "wl" -Value "Write-Log"

Export-ModuleMember -Function "Write-Log", "Set-TerminalSyntaxTheme" -Alias "wl"