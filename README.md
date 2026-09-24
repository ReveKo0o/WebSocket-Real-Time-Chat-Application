WebSocket Real-Time Chat Application

This repository contains a real-time, lightweight chat application consisting of a Node.js WebSocket backend and a Flutter frontend. The system relies on a client-server architecture supporting direct messaging (DM), group chats, live member tracking, and heartbeat monitoring to maintain stable connections across different networks.

Project Architecture

- Backend: Node.js with the `ws` library, designed to handle socket connections, user presence, group broadcasting, and automatic self-pinging to prevent server sleep on free hosting tiers.
- Frontend: Flutter application supporting cross-platform deployment (Windows, Linux, and Android).

1. Setting Up the Backend Server

To deploy your own instance of the WebSocket server (for example, on Render):

1. Fork this repository to your GitHub account.
2. Create a new Web Service on Render and connect it to your forked repository.
3. Configure the service settings:
   - Environment: Node
   - Build Command: npm install
   - Start Command: node server.js
4. Once deployed, copy your assigned server URL (e.g., https://your-server-name.onrender.com).

2. Configuring the Flutter Frontend

Before building the application, point the client to your newly created WebSocket server URL:

1. Clone your repository to your local machine:
   git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY-NAME.git
   cd YOUR-REPOSITORY-NAME
2. Locate the file in your Flutter source code where the WebSocket connection is initialized (typically inside your main or service files where WebSocketChannel.connect is called).
3. Replace the default WebSocket URL string with your Render server URL, changing "https://" to "wss://" (or keeping the appropriate WebSocket scheme your code uses).

3. Running and Building on Different Platforms

Ensure you have the Flutter SDK and Node.js installed on your system.

Linux Installation and Execution
1. Open a terminal in the project directory.
2. Run the following commands to fetch dependencies and run the application:
   flutter pub get
   flutter run -d linux

Windows Installation and Execution
1. Open Command Prompt or PowerShell in the project directory.
2. Run the following commands:
   flutter pub get
   flutter run -d windows

Building an Android APK
1. Open a terminal in the project directory.
2. Clean previous builds and generate the release APK:
   flutter clean
   flutter pub get
   flutter build apk --release
3. The output APK file will be available at build/app/outputs/flutter-apk/app-release.apk.

License

This project is open-source and available for modification and personal use.
