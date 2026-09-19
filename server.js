const WebSocket = require('ws');
const PORT = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: PORT });

const clients = new Map();

wss.on('connection', (ws) => {
    let currentUser = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            if (data.type === 'register') {
                currentUser = data.sender;
                clients.set(currentUser, ws);
                console.log(`[Kayıt] ${currentUser} bağlandı.`);
            }

            if (data.type === 'message') {
                const targetWs = clients.get(data.receiver);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify(data));
                    console.log(`[İletildi] ${data.sender} -> ${data.receiver}`);
                }
            }
        } catch (e) {
            console.log('Hata:', e);
        }
    });

    ws.on('close', () => {
        if (currentUser) {
            clients.delete(currentUser);
            console.log(`[Koptu] ${currentUser} ayrıldı.`);
        }
    });
});

console.log(`WebSocket sunucusu ${PORT} portunda çalışıyor.`);
