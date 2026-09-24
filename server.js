const WebSocket = require('ws');
const http = require('http');
const https = require('https');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('WebSocket server is active and running!\n');
});


const wss = new WebSocket.Server({ server });

const clients = new Map(); // username -> ws
const groups = new Map();  // groupName -> Set of usernames


function heartbeat() {
    this.isAlive = true;
}

wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', heartbeat);

    let currentUser = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            if (data.type === 'register') {
                currentUser = data.sender;
                clients.set(currentUser, ws);
                console.log(`[Register] ${currentUser} connected.`);
            }

            
            if (data.type === 'message') {
                const targetWs = clients.get(data.receiver);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify(data));
                }
            }

            
            if (data.type === 'join_dm_presence') {
                const targetWs = clients.get(data.receiver);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify({
                        type: 'presence_notification',
                        sender: data.sender,
                        text: `${data.sender} is in the chat.`
                    }));
                }
            }

            // Gruba Katılma ve Üyeleri Listeleme
            if (data.type === 'join_group') {
                const groupName = data.group;
                const username = data.sender;
                
                if (!groups.has(groupName)) {
                    groups.set(groupName, new Set());
                }
                const members = groups.get(groupName);
                members.add(username);

                const memberList = Array.from(members);
                memberList.forEach((member) => {
                    const memberWs = clients.get(member);
                    if (memberWs && memberWs.readyState === WebSocket.OPEN) {
                        memberWs.send(JSON.stringify({
                            type: 'group_update',
                            group: groupName,
                            members: memberList,
                            notification: `${username} joined the group.`
                        }));
                    }
                });
                console.log(`[Group Join] ${username} joined ${groupName}. Members:`, memberList);
            }

            
            if (data.type === 'group_message') {
                const groupName = data.group;
                const sender = data.sender;
                const groupMembers = groups.get(groupName);

                if (groupMembers) {
                    groupMembers.forEach((member) => {
                        if (member !== sender) {
                            const memberWs = clients.get(member);
                            if (memberWs && memberWs.readyState === WebSocket.OPEN) {
                                memberWs.send(JSON.stringify(data));
                            }
                        }
                    });
                }
            }

        } catch (e) {
            console.log('Error:', e);
        }
    });

    ws.on('close', () => {
        handleDisconnect(currentUser);
    });
});


function handleDisconnect(currentUser) {
    if (currentUser) {
        clients.delete(currentUser);
        groups.forEach((members, groupName) => {
            if (members.has(currentUser)) {
                members.delete(currentUser);
                const memberList = Array.from(members);
                memberList.forEach((member) => {
                    const mWs = clients.get(member);
                    if (mWs && mWs.readyState === WebSocket.OPEN) {
                        mWs.send(JSON.stringify({
                            type: 'group_update',
                            group: groupName,
                            members: memberList,
                            notification: `${currentUser} left the group.`
                        }));
                    }
                });
            }
        });
        console.log(`[Disconnected] ${currentUser} left.`);
    }
}


const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);

wss.on('close', () => {
    clearInterval(interval);
});


setInterval(() => {
    https.get('https://websocket-server-c1w9.onrender.com', (res) => {
        // console.log(`Keep-alive ping, status: ${res.statusCode}`);
    }).on('error', (err) => {
        console.error('Ping error: ', err.message);
    });
}, 240000);

server.listen(PORT, () => {
    pc = null;
    console.log(`WebSocket server running on port ${PORT}`);
});
