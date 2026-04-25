import Foundation

class DiscordRPC {
    private var socketFD: Int32 = -1
    private let clientId: String
    
    init(clientId: String) {
        self.clientId = clientId
    }
    
    func connect() -> Bool {
        disconnect()
        
        let fileManager = FileManager.default
        let basePaths = [
            NSTemporaryDirectory(),
            "/tmp/",
            "\(NSHomeDirectory())/Library/Application Support/discord/",
            "\(NSHomeDirectory())/.discord/"
        ]
        
        var socketPath: String?
        for basePath in basePaths {
            for i in 0...9 {
                let path = (basePath as NSString).appendingPathComponent("discord-ipc-\(i)")
                if fileManager.fileExists(atPath: path) {
                    socketPath = path
                    break
                }
            }
            if socketPath != nil { break }
        }
        
        guard let finalPath = socketPath else {
            return false
        }
        
        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        if socketFD == -1 { return false }
        
        // Prevent SIGPIPE on write if connection drops
        var set: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &set, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = finalPath.utf8CString
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        if pathBytes.count > sunPathSize {
            disconnect()
            return false
        }
        
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let buffer = UnsafeMutableRawBufferPointer(start: ptr, count: sunPathSize)
            for (index, byte) in pathBytes.enumerated() {
                buffer.storeBytes(of: byte, toByteOffset: index, as: CChar.self)
            }
        }
        
        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        
        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            let sockaddrPtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
            return Darwin.connect(socketFD, sockaddrPtr, addrSize)
        }
        
        if result == -1 {
            disconnect()
            return false
        }
        
        let handshake: [String: Any] = ["v": 1, "client_id": clientId]
        guard let data = try? JSONSerialization.data(withJSONObject: handshake, options: []) else {
            disconnect()
            return false
        }
        
        if !writeFrame(opcode: 0, data: data) {
            disconnect()
            return false
        }
        
        return true
    }
    
    func disconnect() {
        if socketFD != -1 {
            close(socketFD)
            socketFD = -1
        }
    }
    
    func setActivity(activity: [String: Any]) {
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": ProcessInfo.processInfo.processIdentifier,
                "activity": activity
            ] as [String: Any],
            "nonce": UUID().uuidString
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
        
        if !writeFrame(opcode: 1, data: data) {
            if connect() {
                _ = writeFrame(opcode: 1, data: data)
            }
        }
    }
    
    func clearActivity() {
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": ProcessInfo.processInfo.processIdentifier
            ],
            "nonce": UUID().uuidString
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
        _ = writeFrame(opcode: 1, data: data)
    }
    
    private func drainSocket() {
        if socketFD == -1 { return }
        var buffer = [UInt8](repeating: 0, count: 1024)
        let flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)
        
        while true {
            let bytesRead = Darwin.read(socketFD, &buffer, buffer.count)
            if bytesRead <= 0 { break }
        }
        
        _ = fcntl(socketFD, F_SETFL, flags)
    }
    
    private func writeFrame(opcode: Int32, data: Data) -> Bool {
        if socketFD == -1 { return false }
        
        drainSocket()
        
        var op = opcode.littleEndian
        var len = Int32(data.count).littleEndian
        
        var fullData = Data()
        withUnsafeBytes(of: &op) { fullData.append(contentsOf: $0) }
        withUnsafeBytes(of: &len) { fullData.append(contentsOf: $0) }
        fullData.append(data)
        
        let bytesWritten = fullData.withUnsafeBytes { buffer -> Int in
            return Darwin.write(socketFD, buffer.baseAddress, buffer.count)
        }
        
        return bytesWritten == fullData.count
    }
}
