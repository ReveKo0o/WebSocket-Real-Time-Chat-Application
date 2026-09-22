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
                console.log(`[Register] ${currentUser} bağlandı.`);
            }

            if (data.type === 'message' || data.type === 'friend_request' || data.type === 'request_accepted') {
            const targetWs = clients.get(data.receiver);
            if (targetWs && targetWs.readyState === WebSocket.OPEN) {
            targetWs.send(JSON.stringify(data));
            console.log(`[Sended - ${data.type}] ${data.sender} -> ${data.receiver}`);
        }
    }    
        } catch (e) {
            console.log('some bullshit that idk what happened:', e);
        }
    });

    ws.on('close', () => {
        if (currentUser) {
            clients.delete(currentUser);
            console.log(`[disconnected] ${currentUser} leaved.`);
        }
    });
});

console.log(`WebSocket server ${PORT} working on that port.`);
