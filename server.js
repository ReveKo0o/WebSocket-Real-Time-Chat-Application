const WebSocket = require('ws');
const PORT = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: PORT });

const clients = new Map(); // username -> ws
const groups = new Map();  // groupName -> Set of usernames

wss.on('connection', (ws) => {
    let currentUser = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            // 1. Kayıt Olma
            if (data.type === 'register') {
                currentUser = data.sender;
                clients.set(currentUser, ws);
                console.log(`[Register] ${currentUser} connected.`);
            }

            // 2. Özel Mesaj (DM)
            if (data.type === 'message') {
                const targetWs = clients.get(data.receiver);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify(data));
                    console.log(`[DM] ${data.sender} -> ${data.receiver}`);
                }
            }

            // 3. Gruba Katılma
            if (data.type === 'join_group') {
                const groupName = data.group;
                const username = data.sender;
                
                if (!groups.has(groupName)) {
                    groups.set(groupName, new Set());
                }
                groups.get(groupName).add(username);
                console.log(`[Group Join] ${username} joined group: ${groupName}`);
            }

            // 4. Grup Mesajı
            if (data.type === 'group_message') {
                const groupName = data.group;
                const sender = data.sender;
                const groupMembers = groups.get(groupName);

                if (groupMembers) {
                    groupMembers.forEach((member) => {
                        // Mesajı gönderen hariç gruptakilere ilet (veya istersen kendine de dönebilir)
                        if (member !== sender) {
                            const memberWs = clients.get(member);
                            if (memberWs && memberWs.readyState === WebSocket.OPEN) {
                                memberWs.send(JSON.stringify(data));
                            }
                        }
                    });
                    console.log(`[Group Message] ${sender} -> Group: ${groupName}`);
                }
            }

        } catch (e) {
            console.log('Error parsing message:', e);
        }
    });

    ws.on('close', () => {
        if (currentUser) {
            clients.delete(currentUser);
            // Gruplardan da çıkaralım
            groups.forEach((members) => members.delete(currentUser));
            console.log(`[Disconnected] ${currentUser} left.`);
        }
    });
});

console.log(`WebSocket server running on port ${PORT}`);
