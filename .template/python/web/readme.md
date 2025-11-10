# {{NOME_DO_PROJETO}}

Descrição do seu novo projeto web.

## 🚀 Próximos Passos

1.  Crie e ative o ambiente virtual:
    ```sh
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    ```
2.  Instale as dependências:
    ```sh
    pip install -e .[dev]
    # (O '-e .' instala o seu projeto em modo "editável" usando o pyproject.toml)
    ```
3.  Rode a aplicação:
    ```sh
    uvicorn src.my_app.main:app --reload
    ```