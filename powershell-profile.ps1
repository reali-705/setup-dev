# ===================================================================
# PERFIL POWERSHELL "MAESTRO" v2.1
# Autor: reali-705
#
# Este perfil é o "maestro". Ele não contém lógica,
# apenas encontra e carrega os módulos da pasta /modules.
# ===================================================================

# -------------------------------------------------------------------
# 1. ENCONTRAR E CARREGAR MÓDULOS PERSONALIZADOS
# -------------------------------------------------------------------
try {
    # $PSScriptRoot é a pasta onde este script (o profile) está.
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules"

    # Importa os nossos módulos pela ordem de dependência
    # (O 'util' tem de ser o primeiro, pois os outros dependem dele)
    Import-Module (Join-Path $ModulePath "util.psm1") -ErrorAction Stop
    Import-Module (Join-Path $ModulePath "make-project.psm1") -ErrorAction Stop
    Import-Module (Join-Path $ModulePath "dev-help.psm1") -ErrorAction Stop

} catch {
    Write-Host "[ERRO] Falha ao carregar módulos personalizados: $_" -ForegroundColor Red
}

# -------------------------------------------------------------------
# 2. EXECUTAR FUNÇÕES DE INICIALIZAÇÃO
# -------------------------------------------------------------------
try {
    Set-TerminalSyntaxTheme
} catch {
    Write-Host "[ERRO] Falha ao aplicar personalizações do terminal." -ForegroundColor Red
}

# -------------------------------------------------------------------
# 3. MENSAGEM DE BOAS-VINDAS
# -------------------------------------------------------------------

Write-Host ""
Write-Host "===========================================================================" -ForegroundColor Magenta
Write-Host "                   Perfil PowerShell (v2.1 Modular)" -ForegroundColor DarkMagenta
Write-Host "===========================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "FUNÇÕES DE DESENVOLVIMENTO:" -ForegroundColor Cyan
Write-Host "- New-Project   -   Cria um novo projeto a partir de um template." -ForegroundColor Yellow
Write-Host "- Open-VSCode   -   Abre o VS Code reutilizando a janela atual." -ForegroundColor Yellow
Write-Host "- Invoke-Venv   -   Ativa o ambiente virtual Python (.venv) na pasta atual." -ForegroundColor Yellow
Write-Host ""
