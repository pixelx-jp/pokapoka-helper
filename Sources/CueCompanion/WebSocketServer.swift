import Foundation
import Network

/// WebSocket server for streaming audio to clients
/// Local transcription (WhisperKit) is disabled - see WhisperTranscriber.swift.disabled to re-enable
actor AudioWebSocketServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var _isCapturing = false

    init(port: Int) {
        self.port = UInt16(port)
    }

    /// Update capture status (called from main app)
    func setCapturing(_ capturing: Bool) {
        _isCapturing = capturing
    }

    /// Get current capture status
    var isCapturing: Bool {
        _isCapturing
    }

    /// Start the WebSocket server
    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Enable WebSocket protocol
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        guard let port = NWEndpoint.Port(rawValue: self.port) else {
            throw NSError(domain: "WebSocketServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port"])
        }

        listener = try NWListener(using: parameters, on: port)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("WebSocket server listening on port \(self.port)")
            case .failed(let error):
                print("WebSocket server failed: \(error)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }

        listener?.start(queue: .main)
    }

    /// Stop the WebSocket server
    func stop() async {
        listener?.cancel()
        listener = nil

        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()

        print("WebSocket server stopped")
    }

    /// Broadcast audio data to all connected clients
    nonisolated func broadcast(audioData: Data) {
        Task {
            await self.broadcastToClients(audioData: audioData)
        }
    }

    private func broadcastToClients(audioData: Data) {
        // Send raw audio data as binary WebSocket frame
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "audio", metadata: [metadata])

        for connection in connections {
            connection.send(content: audioData, contentContext: context, isComplete: true, completion: .idempotent)
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionStateChange(connection, state: state)
            }
        }

        connection.start(queue: .main)
        connections.append(connection)

        // Send welcome message
        sendText("connected", to: connection)

        // Start receiving messages
        receiveMessage(from: connection)

        print("New WebSocket client connected. Total: \(connections.count)")
    }

    private func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .failed(let error):
            print("Connection failed: \(error)")
            removeConnection(connection)
        case .cancelled:
            removeConnection(connection)
        default:
            break
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        print("Client disconnected. Total: \(connections.count)")
    }

    // MARK: - Message Handling

    private func receiveMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("Receive error: \(error)")
                return
            }

            if let content = content, !content.isEmpty {
                Task {
                    await self.processMessage(content, context: context, from: connection)
                }
            }

            // Continue receiving
            Task {
                await self.receiveMessage(from: connection)
            }
        }
    }

    private func processMessage(_ data: Data, context: NWConnection.ContentContext?, from connection: NWConnection) async {
        // Check if it's a text message
        if let text = String(data: data, encoding: .utf8) {
            await handleTextMessage(text, from: connection)
        }
    }

    private func handleTextMessage(_ text: String, from connection: NWConnection) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle simple text commands
        switch trimmed.lowercased() {
        case "ping":
            sendText("pong", to: connection)
        case "status", "capture_status":
            // Return capture status
            let response: [String: Any] = [
                "type": "capture_status",
                "capturing": _isCapturing
            ]
            await sendJSON(response, to: connection)
        case "model_status":
            // Local transcription is disabled
            let response: [String: Any] = [
                "type": "model_status",
                "status": "unavailable",
                "error": "Local transcription is disabled in this build"
            ]
            await sendJSON(response, to: connection)
        case "load_model":
            // Local transcription is disabled
            let response: [String: Any] = [
                "type": "model_status",
                "status": "unavailable",
                "error": "Local transcription is disabled in this build"
            ]
            await sendJSON(response, to: connection)
        default:
            // Try to parse as JSON command
            if let jsonData = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "transcribe":
                    await sendError("Local transcription is disabled in this build", to: connection)
                default:
                    await sendError("Unknown command type: \(type)", to: connection)
                }
            }
        }
    }

    // MARK: - Send Helpers

    private func sendText(_ text: String, to connection: NWConnection) {
        guard let data = text.data(using: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func sendJSON(_ object: [String: Any], to connection: NWConnection) async {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        sendText(jsonString, to: connection)
    }

    private func sendError(_ message: String, to connection: NWConnection) async {
        let response: [String: Any] = [
            "type": "error",
            "error": message
        ]
        await sendJSON(response, to: connection)
    }
}
