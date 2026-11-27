//
//  SOCKS5BridgeServer.swift
//  Sockystick
//

import Foundation
import Network

public final class SOCKS5BridgeServer {
    public static let shared = SOCKS5BridgeServer()

    public private(set) var isRunning: Bool = false
    public private(set) var listeningPort: UInt16 = 10800

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.sockystick.socks5bridge", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<Void>()
    private var activeConnections: [ObjectIdentifier: NWConnection] = [:]

    private var upstreamHost: String = ""
    private var upstreamPort: UInt16 = 1080
    private var username: String = ""
    private var password: String = ""

    public init() {
        queue.setSpecific(key: queueKey, value: ())
    }

    public var activeConnectionCount: Int {
        onQueueSync { activeConnections.count }
    }

    private func onQueueSync<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return work()
        }
        return queue.sync(execute: work)
    }

    private func trackConnection(_ connection: NWConnection) {
        activeConnections[ObjectIdentifier(connection)] = connection
    }

    private func closeConnection(_ connection: NWConnection) {
        activeConnections.removeValue(forKey: ObjectIdentifier(connection))
        connection.cancel()
    }

    private func closePair(_ first: NWConnection, _ second: NWConnection) {
        closeConnection(first)
        closeConnection(second)
    }

    public func start(
        port: UInt16 = 10800,
        upstreamHost: String,
        upstreamPort: UInt16,
        username: String,
        password: String
    ) throws {
        stop()

        self.listeningPort = port
        self.upstreamHost = upstreamHost
        self.upstreamPort = upstreamPort
        self.username = username
        self.password = password

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "SOCKS5BridgeServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback

        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] clientConn in
            self?.handleClientConnection(clientConn)
        }

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                LogStore.log(
                    level: .success,
                    category: "Bridge",
                    message: "Local SOCKS5 Auth Bridge active on 127.0.0.1:\(port)",
                    details: "Forwarding with RFC 1929 authentication to remote proxy \(upstreamHost):\(upstreamPort) (User: \(username))"
                )
            case .failed(let err):
                self?.isRunning = false
                LogStore.log(
                    level: .error,
                    category: "Bridge",
                    message: "Local SOCKS5 Auth Bridge listener failed",
                    details: err.localizedDescription
                )
            case .cancelled:
                self?.isRunning = false
                LogStore.log(
                    level: .info,
                    category: "Bridge",
                    message: "Local SOCKS5 Auth Bridge stopped"
                )
            default:
                break
            }
        }

        listener.start(queue: queue)
    }

    public func stop() {
        let closedCount: Int = onQueueSync {
            listener?.cancel()
            listener = nil
            isRunning = false

            let count = activeConnections.count
            for connection in activeConnections.values {
                connection.cancel()
            }
            activeConnections.removeAll()
            return count
        }

        if closedCount > 0 {
            LogStore.log(
                level: .info,
                category: "Bridge",
                message: "Closed \(closedCount) active bridged connection(s) on bridge stop"
            )
        }
    }

    // MARK: - Socket Buffer Reading Helper

    private func readUntil(
        connection: NWConnection,
        currentBuffer: Data,
        minimumLength: Int,
        completion: @escaping (Data?) -> Void
    ) {
        if currentBuffer.count >= minimumLength {
            completion(currentBuffer)
            return
        }

        let needed = minimumLength - currentBuffer.count
        connection.receive(minimumIncompleteLength: needed, maximumLength: 65536) { [weak self] newData, _, isComplete, error in
            guard let newData = newData, !newData.isEmpty, error == nil else {
                completion(nil)
                return
            }

            var updatedBuffer = currentBuffer
            updatedBuffer.append(newData)

            if updatedBuffer.count >= minimumLength {
                completion(updatedBuffer)
            } else {
                self?.readUntil(
                    connection: connection,
                    currentBuffer: updatedBuffer,
                    minimumLength: minimumLength,
                    completion: completion
                )
            }
        }
    }

    // MARK: - Connection Handling

    private func handleClientConnection(_ clientConn: NWConnection) {
        trackConnection(clientConn)
        clientConn.start(queue: queue)

        // Read Client Greeting (minimum 2 bytes: VER, NMETHODS)
        readUntil(connection: clientConn, currentBuffer: Data(), minimumLength: 2) { [weak self] greetingHeader in
            guard let self = self, let greetingHeader = greetingHeader, greetingHeader[0] == 0x05 else {
                self?.closeConnection(clientConn)
                return
            }

            let nMethods = Int(greetingHeader[1])
            let fullGreetingLen = 2 + nMethods

            self.readUntil(connection: clientConn, currentBuffer: greetingHeader, minimumLength: fullGreetingLen) { [weak self] fullGreetingData in
                guard let self = self, let fullGreetingData = fullGreetingData, fullGreetingData.count >= fullGreetingLen else {
                    self?.closeConnection(clientConn)
                    return
                }

                let extraData = fullGreetingData.subdata(in: fullGreetingLen..<fullGreetingData.count)

                // Reply to local client: NO AUTH REQUIRED (0x00) on 127.0.0.1 bridge
                let reply = Data([0x05, 0x00])
                clientConn.send(content: reply, completion: .contentProcessed({ err in
                    guard err == nil else {
                        self.closeConnection(clientConn)
                        return
                    }
                    self.processClientRequestBuffer(clientConn: clientConn, buffer: extraData)
                }))
            }
        }
    }

    private func processClientRequestBuffer(clientConn: NWConnection, buffer: Data) {
        // Read at least 4 bytes of SOCKS5 CONNECT header: VER (0x05), CMD, RSV, ATYP
        readUntil(connection: clientConn, currentBuffer: buffer, minimumLength: 4) { [weak self] headerBuffer in
            guard let self = self, let headerBuffer = headerBuffer, headerBuffer[0] == 0x05 else {
                self?.closeConnection(clientConn)
                return
            }

            let atyp = headerBuffer[3]
            var minRequestLen = 4
            switch atyp {
            case 0x01: // IPv4: 4 bytes IP + 2 bytes Port = 6 -> total 10
                minRequestLen = 4 + 6
            case 0x04: // IPv6: 16 bytes IP + 2 bytes Port = 18 -> total 22
                minRequestLen = 4 + 18
            case 0x03: // Domain: 1 byte domain length + domain bytes + 2 bytes Port
                self.readUntil(connection: clientConn, currentBuffer: headerBuffer, minimumLength: 5) { domainLenBuf in
                    guard let domainLenBuf = domainLenBuf, domainLenBuf.count >= 5 else {
                        self.closeConnection(clientConn)
                        return
                    }
                    let domainLen = Int(domainLenBuf[4])
                    let fullLen = 4 + 1 + domainLen + 2
                    self.readUntil(connection: clientConn, currentBuffer: domainLenBuf, minimumLength: fullLen) { fullReqBuf in
                        guard let fullReqBuf = fullReqBuf, fullReqBuf.count >= fullLen else {
                            self.closeConnection(clientConn)
                            return
                        }
                        let clientRequestData = fullReqBuf.subdata(in: 0..<fullLen)
                        let initialPayload = fullReqBuf.subdata(in: fullLen..<fullReqBuf.count)
                        self.connectUpstreamAndPipe(clientConn: clientConn, clientRequestData: clientRequestData, initialPayload: initialPayload)
                    }
                }
                return
            default:
                self.closeConnection(clientConn)
                return
            }

            self.readUntil(connection: clientConn, currentBuffer: headerBuffer, minimumLength: minRequestLen) { fullReqBuf in
                guard let fullReqBuf = fullReqBuf, fullReqBuf.count >= minRequestLen else {
                    self.closeConnection(clientConn)
                    return
                }
                let clientRequestData = fullReqBuf.subdata(in: 0..<minRequestLen)
                let initialPayload = fullReqBuf.subdata(in: minRequestLen..<fullReqBuf.count)
                self.connectUpstreamAndPipe(clientConn: clientConn, clientRequestData: clientRequestData, initialPayload: initialPayload)
            }
        }
    }

    private func connectUpstreamAndPipe(clientConn: NWConnection, clientRequestData: Data, initialPayload: Data) {
        let params = NWParameters.tcp
        params.preferNoProxies = true
        let upstreamConn = NWConnection(
            host: NWEndpoint.Host(upstreamHost),
            port: NWEndpoint.Port(rawValue: upstreamPort)!,
            using: params
        )
        trackConnection(upstreamConn)

        upstreamConn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.performUpstreamHandshakeAndAuth(
                    clientConn: clientConn,
                    upstreamConn: upstreamConn,
                    clientRequestData: clientRequestData,
                    initialPayload: initialPayload
                )
            case .failed(let err):
                LogStore.log(
                    level: .error,
                    category: "Bridge",
                    message: "Bridge failed connecting to remote SOCKS5 server \(self.upstreamHost):\(self.upstreamPort)",
                    details: err.localizedDescription
                )
                self.closeConnection(upstreamConn)
                self.sendClientErrorReply(clientConn: clientConn, rep: 0x05)
            default:
                break
            }
        }
        upstreamConn.start(queue: queue)
    }

    private func performUpstreamHandshakeAndAuth(
        clientConn: NWConnection,
        upstreamConn: NWConnection,
        clientRequestData: Data,
        initialPayload: Data
    ) {
        // Send Greeting to Upstream SOCKS5 server: VER 0x05, 2 Methods: 0x00 (No Auth), 0x02 (Username/Password)
        let upstreamGreeting = Data([0x05, 0x02, 0x00, 0x02])
        upstreamConn.send(content: upstreamGreeting, completion: .contentProcessed({ [weak self] err in
            guard let self = self, err == nil else {
                self?.closeConnection(upstreamConn)
                self?.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                return
            }

            self.readUntil(connection: upstreamConn, currentBuffer: Data(), minimumLength: 2) { replyData in
                guard let replyData = replyData, replyData.count >= 2, replyData[0] == 0x05 else {
                    self.closeConnection(upstreamConn)
                    self.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                    return
                }

                let chosenMethod = replyData[1]
                if chosenMethod == 0x02 {
                    self.performUpstreamRFC1929Auth(
                        clientConn: clientConn,
                        upstreamConn: upstreamConn,
                        clientRequestData: clientRequestData,
                        initialPayload: initialPayload
                    )
                } else if chosenMethod == 0x00 {
                    self.sendClientRequestToUpstream(
                        clientConn: clientConn,
                        upstreamConn: upstreamConn,
                        clientRequestData: clientRequestData,
                        initialPayload: initialPayload
                    )
                } else {
                    LogStore.log(level: .error, category: "Bridge", message: "Upstream SOCKS5 server rejected available auth methods (Method: \(chosenMethod))")
                    self.closeConnection(upstreamConn)
                    self.sendClientErrorReply(clientConn: clientConn, rep: 0x07)
                }
            }
        }))
    }

    private func performUpstreamRFC1929Auth(
        clientConn: NWConnection,
        upstreamConn: NWConnection,
        clientRequestData: Data,
        initialPayload: Data
    ) {
        let uData = Array(username.utf8)
        let pData = Array(password.utf8)

        var authPacket = Data([0x01, UInt8(min(uData.count, 255))])
        authPacket.append(contentsOf: uData.prefix(255))
        authPacket.append(UInt8(min(pData.count, 255)))
        authPacket.append(contentsOf: pData.prefix(255))

        upstreamConn.send(content: authPacket, completion: .contentProcessed({ [weak self] err in
            guard let self = self, err == nil else {
                self?.closeConnection(upstreamConn)
                self?.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                return
            }

            self.readUntil(connection: upstreamConn, currentBuffer: Data(), minimumLength: 2) { authResp in
                guard let authResp = authResp, authResp.count >= 2, authResp[1] == 0x00 else {
                    LogStore.log(level: .error, category: "Bridge", message: "Upstream SOCKS5 proxy rejected credentials for user '\(self.username)'")
                    self.closeConnection(upstreamConn)
                    self.sendClientErrorReply(clientConn: clientConn, rep: 0x05)
                    return
                }

                self.sendClientRequestToUpstream(
                    clientConn: clientConn,
                    upstreamConn: upstreamConn,
                    clientRequestData: clientRequestData,
                    initialPayload: initialPayload
                )
            }
        }))
    }

    private func sendClientRequestToUpstream(
        clientConn: NWConnection,
        upstreamConn: NWConnection,
        clientRequestData: Data,
        initialPayload: Data
    ) {
        upstreamConn.send(content: clientRequestData, completion: .contentProcessed({ [weak self] err in
            guard let self = self, err == nil else {
                self?.closeConnection(upstreamConn)
                self?.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                return
            }

            self.readUntil(connection: upstreamConn, currentBuffer: Data(), minimumLength: 4) { replyHeader in
                guard let replyHeader = replyHeader, replyHeader.count >= 4, replyHeader[0] == 0x05 else {
                    self.closeConnection(upstreamConn)
                    self.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                    return
                }

                let atyp = replyHeader[3]
                var reqReplyLen = 4
                switch atyp {
                case 0x01: reqReplyLen = 4 + 6
                case 0x04: reqReplyLen = 4 + 18
                case 0x03:
                    self.readUntil(connection: upstreamConn, currentBuffer: replyHeader, minimumLength: 5) { domainHeader in
                        guard let domainHeader = domainHeader, domainHeader.count >= 5 else {
                            self.closeConnection(upstreamConn)
                            self.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                            return
                        }
                        let domainLen = Int(domainHeader[4])
                        let fullLen = 4 + 1 + domainLen + 2
                        self.readUntil(connection: upstreamConn, currentBuffer: domainHeader, minimumLength: fullLen) { fullReply in
                            guard let fullReply = fullReply, fullReply.count >= fullLen else {
                                self.closeConnection(upstreamConn)
                                self.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                                return
                            }
                            self.forwardUpstreamReplyAndStartPiping(
                                clientConn: clientConn,
                                upstreamConn: upstreamConn,
                                replyData: fullReply,
                                initialPayload: initialPayload
                            )
                        }
                    }
                    return
                default:
                    self.closeConnection(upstreamConn)
                    self.sendClientErrorReply(clientConn: clientConn, rep: 0x08)
                    return
                }

                self.readUntil(connection: upstreamConn, currentBuffer: replyHeader, minimumLength: reqReplyLen) { fullReply in
                    guard let fullReply = fullReply, fullReply.count >= reqReplyLen else {
                        self.closeConnection(upstreamConn)
                        self.sendClientErrorReply(clientConn: clientConn, rep: 0x01)
                        return
                    }
                    self.forwardUpstreamReplyAndStartPiping(
                        clientConn: clientConn,
                        upstreamConn: upstreamConn,
                        replyData: fullReply,
                        initialPayload: initialPayload
                    )
                }
            }
        }))
    }

    private func forwardUpstreamReplyAndStartPiping(
        clientConn: NWConnection,
        upstreamConn: NWConnection,
        replyData: Data,
        initialPayload: Data
    ) {
        clientConn.send(content: replyData, completion: .contentProcessed({ [weak self] err in
            guard let self = self, err == nil else {
                self?.closePair(clientConn, upstreamConn)
                return
            }

            if !initialPayload.isEmpty {
                upstreamConn.send(content: initialPayload, completion: .contentProcessed({ [weak self] sendErr in
                    guard sendErr == nil else {
                        self?.closePair(clientConn, upstreamConn)
                        return
                    }
                    self?.startPiping(clientConn: clientConn, upstreamConn: upstreamConn)
                }))
            } else {
                self.startPiping(clientConn: clientConn, upstreamConn: upstreamConn)
            }
        }))
    }

    private func startPiping(clientConn: NWConnection, upstreamConn: NWConnection) {
        // Bidirectional TCP streaming between browser and remote SOCKS5 server
        pipeConnection(from: clientConn, to: upstreamConn)
        pipeConnection(from: upstreamConn, to: clientConn)
    }

    private func pipeConnection(from source: NWConnection, to destination: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                destination.send(content: data, completion: .contentProcessed({ sendErr in
                    if sendErr == nil && !isComplete {
                        self?.pipeConnection(from: source, to: destination)
                    } else {
                        self?.closePair(source, destination)
                    }
                }))
            } else if isComplete || error != nil {
                self?.closePair(source, destination)
            }
        }
    }

    private func sendClientErrorReply(clientConn: NWConnection, rep: UInt8) {
        let errReply = Data([0x05, rep, 0x00, 0x01, 0, 0, 0, 0, 0, 0])
        clientConn.send(content: errReply, completion: .contentProcessed({ [weak self] _ in
            self?.closeConnection(clientConn)
        }))
    }
}
