// Importa o framework Express
import express, { Express, Request, Response } from 'express';
import path from 'path';

// importa as suas rotas...


const app: Express = express();
const port = 3000;

// Diz ao Express para servir arquivos estáticos da pasta 'static/'
app.use('/static', express.static(path.join(__dirname, '..', 'static')));

// Rota principal
app.get('/', (req: Request, res: Response) => {
    res.send('Servidor TypeScript funcionando!');
});

// "Monta" as suas outras rotas


// Inicia o servidor
app.listen(port, () => {
    console.log(`[servidor]: Servidor a rodar em http://localhost:${port}`);
});