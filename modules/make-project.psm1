using module ".\util.psm1"

# =========================================================
# FUNÇÕES AUXILIARES (PRIVADAS)
# (Não são exportadas. Apenas usadas pela função principal)
# =========================================================

<#
.SYNOPSIS
    (Helper Privado) Instala o ambiente virtual Python e as dependências.
#>
function Invoke-PythonEnvInstall {
    param (
        [string]$DestinationPath
    )
    
    try {
        wl "Configurando ambiente virtual e instalando dependências..."
        $pythonExe = (Get-Command python -ErrorAction Stop).Source
        $pipExe = Join-Path -Path $DestinationPath -ChildPath ".venv\Scripts\pip.exe"

        # Cria o ambiente virtual
        $procVenv = Start-Process $pythonExe -ArgumentList "-m venv .venv" -WorkingDirectory $DestinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procVenv.ExitCode -ne 0) { throw "Falha ao executar 'python -m venv .venv'." }

        # Instala as dependencias do pyproject.toml
        $procPip = Start-Process $pipExe -ArgumentList "install -e .[dev]" -WorkingDirectory $DestinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procPip.ExitCode -ne 0) { throw "Falha ao executar 'pip install -e .[dev]'." }

        wl "Ambiente virtual Python configurado e dependências instaladas!" -t Success
        return $true
    } catch {
        wl "Falha ao criar ou instalar dependências do venv: $_" -t Warning
        wl "O projeto foi criado, mas o venv precisa ser configurado manualmente." -t Warning
        return $false
    }
}

<#
.SYNOPSIS
    (Helper Privado) Instala as dependências do Node.js.
#>
function Invoke-NodeEnvInstall {
    param (
        [string]$DestinationPath
    )
    
    try {
        wl "Instalando dependências com npm..."
        $npmExe = (Get-Command npm -ErrorAction Stop).Source

        # Instala as dependencias do package.json
        $procNpm = Start-Process $npmExe -ArgumentList "install" -WorkingDirectory $DestinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procNpm.ExitCode -ne 0) { throw "Falha ao executar 'npm install'." }

        wl "Dependências Node.js instaladas com sucesso!" -t Success
        return $true
    } catch {
        wl "Falha ao instalar as dependências do npm: $_" -t Warning
        wl "O projeto foi criado, mas voce precisara instalar as dependências manualmente." -t Warning
        return $false
    }
}

<#
.SYNOPSIS
    (Helper Privado) Compila o projeto Java e baixa as dependências do Maven.
#>
function Invoke-JavaEnvInstall {
    param (
        [string]$DestinationPath
    )

    try {
        wl "Compilando projeto e baixando dependências Maven..."
        $mavenExe = (Get-Command mvn -ErrorAction Stop).Source

        # "package" é o comando do Maven que compila e baixa as dependências.
        $procMaven = Start-Process $mavenExe -ArgumentList "package" -WorkingDirectory $DestinationPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($procMaven.ExitCode -ne 0) { throw "Falha ao executar 'mvn package'." }

        wl "Dependências Java (Maven) baixadas e projeto compilado!" -t Success
        return $true
    } catch {
        wl "Falha ao compilar o projeto Maven: $_" -t Warning
        wl "O projeto foi criado, mas as dependências precisam ser baixadas manualmente (execute 'mvn package')." -t Warning
        return $false
    }
}

# =========================================================
# FUNÇÃO PRINCIPAL (PÚBLICA)
# (Esta é a única função que o utilizador chama)
# =========================================================

<#
.SYNOPSIS
    Cria uma nova estrutura de projeto a partir de um template.

.DESCRIPTION
    Automatiza a criação de projetos (Python, TS, Java.)
    copiando um template pré-definido e personalizando os
    nomes de arquivos e conteúdos internos (placeholders).

.PARAMETER ProjectName
    O nome do seu novo projeto.
    Aliases: -n, -name

.PARAMETER Language
    A linguagem de programação do projeto.
    Aliases: -l

.PARAMETER Type
    O template a ser usado.

.PARAMETER ProjectPath
    O caminho onde o projeto será criado (Padrão: pasta atual).
    Aliases: -p, -path
#>
function New-Project {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("name", "n")]
        [string]$ProjectName,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("l")]
        [ValidateSet("py", "python", "ts", "typescript", "jv", "java")]
        [string]$Language,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet("base", "web")]
        [string]$Type,

        [Parameter(Mandatory = $false)]
        [Alias("path", "p")]
        [string]$ProjectPath = (Get-Location).Path
    )

    # Variaveis Constantes do template
    $templateNameProject = "{{NOME_DO_PROJETO}}"
    $templateNamePackage = "my_app" # (Nome placeholder padrão para Python)

    # Definição de Nomes e Caminhos
    $ProjectName = $ProjectName.Trim().replace(" ", "-").ToLower()
    $PackageName = $ProjectName -replace "-", "_"

    # Mapeamento de Linguagens
    if ($Language -eq "py") { $Language = "python" }
    if ($Language -eq "ts") { $Language = "typescript" }
    if ($Language -eq "jv") { $Language = "java" }

    $commonPath = Join-Path -Path $PSScriptRoot -ChildPath "..\_templates\_common"
    $templatePath = Join-Path -Path $PScriptRoot -ChildPath "..\_templates\$Language\$Type"
    $destinationPath = Join-Path -Path $ProjectPath -ChildPath $ProjectName

    # Validação de caminhos e existência de projeto iguais
    if (-not (Test-Path -Path $templatePath)) {
        wl "Template '$Language/$Type' nao encontrado em '$templatePath'." -t Error
        return
    }
    if (Test-Path -Path $destinationPath) {
        wl "O projeto '$ProjectName' ja existe em '$ProjectPath'." -t Error
        return
    }

    # =========================================================
    # 1. GERAÇÃO DA ESTRUTURA (Lógica Comum)
    # =========================================================
    try {
        wl "Criando projeto '$ProjectName' (Template: '$Language/$Type') em '$destinationPath'..."

        # Cópia dos arquivos do template
        Copy-Item -Path "$commonPath\*" -Destination $destinationPath -Recurse -Container -ErrorAction Stop
        Copy-Item -Path "$templatePath\*" -Destination $destinationPath -Recurse -Container -ErrorAction Stop

        # Lógica de Rename (Específica do Python)
        if ($Language -eq "python") {
            wl "Renomeando pasta do pacote para '$PackageName'..."
            $genericSrcPath = Join-Path $destinationPath "src\$templateNamePackage"
            if (Test-Path -Path $genericSrcPath) {
                Rename-Item -Path $genericSrcPath -NewName $PackageName -ErrorAction Stop
            }
        }
        
        # Lógica de Substituição de Placeholders
        wl "Personalizando arquivos do projeto..."
        $filesToUpdate = @(
            Join-Path $destinationPath "README.md",
            Join-Path $destinationPath "pyproject.toml",    # Para Python
            Join-Path $destinationPath "package.json"       # Para TypeScript
            Join-Path $destinationPath "pom.xml"            # Para Java
        )
        
        foreach ($file in $filesToUpdate) {
            if (Test-Path -Path $file) {
                (Get-Content -Path $file -Raw) -replace $templateNameProject, $ProjectName | Set-Content -Path $file -Encoding UTF8 -ErrorAction Stop
            }
        }

        wl "Estrutura do projeto '$ProjectName' criada com sucesso!" -t Success
    } catch {
        wl "ERRO CRÍTICO: Falha ao criar a estrutura do projeto: $_" -t Error
        wl "Apagando '$destinationPath'..." -t Warning
        Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # =========================================================
    # 2. INSTALAÇÃO DE DEPENDÊNCIAS (Lógica Específica)
    # =========================================================
    $installSuccess = $false
    if ($Language -eq "python") {
        # Chama a função helper privada de Python
        $installSuccess = Invoke-PythonEnvInstall -DestinationPath $destinationPath
    } 
    elseif ($Language -eq "typescript") {
        # Chama a função helper privada de Node
        $installSuccess = Invoke-NodeEnvInstall -DestinationPath $destinationPath
    }
    elseif ($Language -eq "java") {
        $installSuccess = Invoke-JavaEnvInstall -DestinationPath $destinationPath
    }

    # =========================================================
    # 3. PRÓXIMOS PASSOS (Lógica Específica)
    # =========================================================
    wl "Projeto concluído!" -t Success
    wl "Próximos passos:" -t Atention
    wl "1. cd $ProjectName" -t Atention
    $ProximoPasso = 2
    
    if ($Language -eq "python") {
        wl "$ProximoPasso. venv (para ativar o ambiente virtual)" -t Atention
        $ProximoPasso++
        if (-not $installSuccess) {
            wl "$ProximoPasso. pip install -e .[dev] (para instalar as dependências)" -t Atention
            $ProximoPasso++
        }
    }
    elseif ($Language -eq "typescript") {
        if (-not $installSuccess) {
            wl "$ProximoPasso. npm install (para instalar as dependências)" -t Atention
            $ProximoPasso++
        }
        wl "$ProximoPasso. npm run dev (para iniciar o servidor)" -t Atention
    }
    elseif ($Language -eq "java") {
        if (-not $installSuccess) {
            wl "$ProximoPasso. mvn package (para baixar as dependências e compilar o projeto)" -t Atention
            $ProximoPasso++
        }
        wl "$ProximoPasso. (Configurar o ambiente Java conforme necessário)" -t Atention
    }
    wl "$ProximoPasso. Começar a desenvolver!" -t Atention
}

# =========================================================
# EXPORTS E ALIASES DAS FUNÇÕES
# =========================================================
Set-Alias -Name "mkp" -Value "New-Project"
Export-ModuleMember -Function New-Project