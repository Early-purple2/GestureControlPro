// server.js
// Serveur Node.js pour la gestion des commandes gestuelles via WebSocket

const WebSocket = require('ws');
const http = require('http');
const gestureHandler = require('./gesture_handler');

const PORT = process.env.PORT || 8080;

// Serveur HTTP minimal (pour health check)
const server = http.createServer((req, res) => {
  if (req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'running', timestamp: Date.now() }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

// Serveur WebSocket
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  console.log('🔗 Client WebSocket connecté');

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      if (data.type === 'gesture_command') {
        // Traitement de la commande gestuelle
        const result = await gestureHandler.handleGestureCommand(data.payload);
        ws.send(JSON.stringify({ id: data.id, status: result ? 'executed' : 'failed' }));
      }
    } catch (err) {
      console.error('❌ Erreur traitement message:', err);
      ws.send(JSON.stringify({ status: 'error', error: err.message }));
    }
  });

  ws.on('close', () => {
    console.log('🔌 Client WebSocket déconnecté');
  });
});

server.listen(PORT, () => {
  console.log(`🌐 Serveur Node.js démarré sur le port ${PORT}`);
});

