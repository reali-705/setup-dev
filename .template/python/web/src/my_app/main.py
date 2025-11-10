from fastapi import FastAPI
from .database import engine, Base

# Cria as tabelas do banco de dados (se não existirem)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="{{NOME_DO_PROJETO}}")


@app.get("/")
def read_root():
    return {"message": "Bem-vindo ao {{NOME_DO_PROJETO}}!"}