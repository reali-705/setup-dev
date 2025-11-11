using module ".\util.psm1"

<#
.SYNOPSIS
    Cria uma nova estrutura de projeto Python a partir de um template.

.DESCRIPTION
    Automatiza a criação de projetos Python (base ou web)
    copiando um template pré-definido e personalizando os
    nomes de arquivos e conteúdos internos (placeholders).

.PARAMETER ProjectName
    O nome do seu novo projeto (ex: "minha-api-legal").
    Aliases: -n, -name

.PARAMETER ProjectType
    O template a ser usado (base ou web).
    Aliases: -t, -type

.PARAMETER ProjectPath
    O caminho onde o projeto será criado (Padrão: pasta atual).
    Aliases: -p, -path

.EXAMPLE
    mkpy -n "minha-api-legal" -t "web"
    (Cria um projeto web Python chamado "minha-api-legal" na pasta atual)
#>
function Make-ProjectPython {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("name", "n")]
        [string]$ProjectName,
        [Parameter(Mandatory = $true)]
        [Alias("type", "t")]
        [ValidateSet("base", "web")]
        [string]$ProjectType,
        [Parameter(Mandatory = $false)]
        [Alias("path", "p")]
        [string]$ProjectPath = (Get-Location).Path
    )

    # Variaveis Constantes do template
    $templateNameProject = "{{NOME_DO_PROJETO}}"
    $templateNamePackage = "my_app"

    # Define os caminhos do _template e do destino
    $templatePath = Join-Path -Path $PSScriptRoot -ChildPath "..\_templates\python\$ProjectType"
    $ProjectName = $ProjectName.Trim().replace(" ", "-").ToLower()
    $destinationPath = Join-Path -Path $ProjectPath -ChildPath $ProjectName

    # Verifica se o template existe e se o destino ja existe
    if (-not (Test-Path -Path $templatePath)) {
        Write-Log "Template nao encontrado em '$templatePath'." -Level "Error"
        return
    }
    if (Test-Path -Path $destinationPath) {
        Write-Log "O projeto '$ProjectName' ja existe em '$ProjectPath'." -Level "Error"
        return
    }

    try {
        # Copia os arquivos do template para o destino
        Write-Log "Criando projeto '$ProjectName' do tipo '$ProjectType' em '$destinationPath'..."
        Copy-Item -Path "$templatePath\*" -Destination $destinationPath -Recurse -Container -ErrorAction Stop

        # Altera o nome do script para o nome do projeto
        $genericSrcPath = Join-Path $destinationPath "src\$templateNamePackage"
        if (Test-Path -Path $genericSrcPath) {
            Rename-Item -Path $genericSrcPath -NewName ($ProjectName -replace "-", "_") -ErrorAction Stop
        }

        # Atualiza o nome do projeto em arquivos relevantes
        $filesToUpdate = @(
            Join-Path $destinationPath "README.md",
            Join-Path $destinationPath "pyproject.toml",
        )
        foreach ($file in $filesToUpdate) {
            if (Test-Path -Path $file) {
                (Get-Content -Path $file -Raw) -replace $templateNameProject, $ProjectName | Set-Content -Path $file -Encoding UTF8 -ErrorAction Stop
            }
        }

        Write-Log "Projeto '$ProjectName' criado com sucesso em '$destinationPath'!" -l Success
    } catch {
        Write-Log "ERRO CRÍTICO: Falha ao criar o projeto: $_" -l Error
        Write-Log "Apagando '$destinationPath'..." -l Warning
        Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    try {
        # Instalando o ambiente virtual e dependencias
        Write-Log "Configurando ambiente virtual e instalando dependências..."
        $erroInstall = $false

        # Executavel do python
        $pythonExe = (Get-Command python -ErrorAction Stop).Source

        # Cria o ambiente virtual
        $procVenv = Start-Process $pythonExe -ArgumentList "-m venv .venv" -WorkingDirectory $destinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procVenv.ExitCode -ne 0) {
            throw "Falha ao executar 'python -m venv .venv'."
        }

        # Executavel do pip dentro do venv
        $pipExe = Join-Path -Path $destinationPath -ChildPath ".venv\Scripts\pip.exe"

        # Instala as dependencias do pyproject.toml
        $procPip = Start-Process $pipExe -ArgumentList "install -e .[dev]" -WorkingDirectory $destinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procPip.ExitCode -ne 0) {
            throw "Falha ao executar 'pip install -e .[dev]'."
        }

        Write-Log "Ambiente virtual configurado e dependências instaladas com sucesso!" -l Success
    } catch {
        Write-Log "Falha ao criar ou ativar o ambiente virtual: $_" -l Warning
        Write-Log "O projeto foi criado, mas voce precisara configurar o ambiente virtual manualmente." -l Warning
        $erroInstall = $true
    }
    Write-Log "Proximos passos:"
    Write-Log "1. Navegue até '$destinationPath' com 'cd $ProjectName'." -l Atention
    Write-Log "2. Ative o ambiente virtual com '\.venv\Scripts\Activate.ps1'" -l Atention
    if($erroInstall) {
        Write-Log "3. Instale as dependências com 'pip install -e .[dev]'" -l Atention
    }
}

# =========================================================
# EXPORTS E ALIASES DAS FUNÇÕES
# =========================================================
Set-Alias -Name "mkpy" -Value "Make-ProjectPython"
Export-ModuleMember -Function (
    Make-ProjectPython
)