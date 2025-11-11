using module ".\utils.psm1"

# =========================================================
# FUNÇÕES DE AJUDA AO DESENVOLVIMENTO
# =========================================================

<#
.SYNOPSIS
    Abre o VS Code no diretório especificado (ou no atual).

.DESCRIPTION
    Esta função é um atalho de produtividade para abrir rapidamente
    o Visual Studio Code. Ela usa a flag '--reuse-window' para
    tentar reutilizar uma janela existente do VS Code.

.PARAMETER Path
    O caminho do diretório ou arquivo a ser aberto.
    Se omitido, o padrão é o diretório atual ('.').
    Este é um parâmetro posicional.

.NOTES
    Alias de função: cdr
    Esta função requer que o 'code.exe' (VS Code)
    esteja disponível no seu PATH de ambiente.
#>
function Open-VSCodeWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$Path = "."
    )

    try {
        # Tenta resolver o caminho absoluto
        $fullPath = Resolve-Path -Path $Path -ErrorAction Stop

        wl "Abrindo o VSCode no caminho..."
        wl $fullPath.Path -t Atention # (Usar .Path para obter a string limpa)

        Start-Process "code" -ArgumentList "--reuse-window", "`"$($fullPath.Path)`"" -NoNewWindow -ErrorAction Stop
        
        wl "VSCode aberto com sucesso!" -t Success
    } catch {
        wl "Erro ao abrir o VSCode: $_" -t Error
        wl "Verifique se o 'code.exe' está no seu PATH." -t Warning
    }
}


<#
.SYNOPSIS
    Ativa o ambiente virtual Python (.venv) no escopo atual.

.DESCRIPTION
    Procura por um ambiente virtual na pasta './.venv' e, se
    encontrado, executa o script 'Activate.ps1' usando "dot-sourcing"
    (o comando '.') para que o ambiente seja ativado no
    terminal do utilizador (escopo atual).

.EXAMPLE
    PS C:\projetos\minha-api> venv
    (Procura por C:\projetos\minha-api\.venv\Scripts\Activate.ps1 e o ativa)

.NOTES
    Alias de função: venv
    Esta função deve ser executada na raiz de um projeto Python
    que contenha uma pasta '.venv' criada pelo 'python -m venv'.
#>
function Activate-VirtualEnvironment {
    [CmdletBinding()]
    param()

    $venvPath = Join-Path -Path (Get-Location) -ChildPath ".venv\Scripts\Activate.ps1"

    if (-not (Test-Path -Path $venvPath)) {
        wl "Ambiente virtual '.venv' não encontrado em: $(Get-Location)" -t Warning
        wl "Para criar um ambiente, execute: python -m venv .venv" -t Atention
        return
    }

    try {
        wl "Ativando o ambiente virtual..."

        . $venvPath

        wl "Ambiente virtual ativado!" -t Success
    } catch {

        wl "Erro ao ativar o ambiente virtual: $_" -t Error
    }
}


# =========================================================
# EXPORTS E ALIASES DAS FUNÇÕES
# (Essencial para o 'maestro' powershell-profile.ps1)
# =========================================================

Set-Alias -Name "cdr" -Value "Open-VSCodeWorkspace"
Set-Alias -Name "venv" -Value "Activate-VirtualEnvironment"

Export-ModuleMember -Function (
    Open-VSCodeWorkspace,
    Activate-VirtualEnvironment
)
