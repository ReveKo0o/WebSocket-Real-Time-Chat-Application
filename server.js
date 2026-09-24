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

            if (data.type === 'register') {
                currentUser = data.sender;
                clients.set(currentUser, ws);
                console.log(`[Register] ${currentUser} connected.`);
            }

            // Özel Mesaj (DM)
            if (data.type === 'message') {
                const targetWs = clients.get(data.receiver);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify(data));
                }
            }

            // DM Sohbete Giriş Duyurusu ("In the chat")
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

                // Gruptakilere mevcut üye listesini ve yeni katılanı bildir
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

            // Grup Mesajı
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
        if (currentUser) {
            clients.delete(currentUser);
            groups.forEach((members, groupName) => {
                if (members.has(currentUser)) {
                    members.delete(currentUser);
                    // Gruptan çıkma durumunu kalanlara bildir
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
    });
});

console.log(`WebSocket server running on port ${PORT}`);
