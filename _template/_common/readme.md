# {{NOME_DO_PROJETO}}

**Linguagem:** {{LINGUAGEM}}.  
**Autor:** [Alessandro Reali](https://github.com/reali-705).  
**Status:** Em Desenvolvimento

## 🚀 Configuração Inicial

Este projeto foi gerado localmente pelo [`setup-dev`](https://github.com/reali-705/setup-dev).
Siga estes passos para publicá-lo no GitHub e configurar o seu ambiente de desenvolvimento.

### 1. Crie o Repositório no GitHub

Vá até [github.com/new](https://github.com/new). E
crie um novo repositório vazio com o nome: **{{NOME_DO_PROJETO}}**.

- **Importante:** Não adicione `README.md` nem `.gitignore`. Eles já estão nesta pasta.

### 2. Conecte o Repositório Local ao Remoto
Execute os seguintes comandos no seu terminal (dentro desta pasta do projeto):
```powershell
# 0. Caso não tenha entrado na pasta do projeto
cd {{NOME_DO_PROJETO}}

# 1. Inicializa o git e muda o nome da branch padrão para 'main'
git init -b main

# 2. Adiciona todos os arquivos do template
git add .
git commit -m "feat: commit inicial com a estrutura do projeto"

# 3. Conecte ao seu repositório no GitHub
git remote add origin https://github.com/reali-705/{{NOME_DO_PROJETO}}.git

# 4. Envie o seu código para o GitHub
git push -u origin main
```