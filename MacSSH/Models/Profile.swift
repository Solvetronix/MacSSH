import Foundation

enum SSHKeyType: String, Codable, CaseIterable, Identifiable {
    case password = "Password"
    case privateKey = "Private Key"
    case none = "None"
    var id: String { self.rawValue }
}

struct Profile: Identifiable, Codable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String?
    var privateKeyPath: String?
    var keyType: SSHKeyType
    var lastConnectionDate: Date?
    var description: String?
    
    init(id: UUID = UUID(), name: String, host: String, port: Int = 22, username: String, password: String? = nil, privateKeyPath: String? = nil, keyType: SSHKeyType = .password, lastConnectionDate: Date? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.privateKeyPath = privateKeyPath
        self.keyType = keyType
        self.lastConnectionDate = lastConnectionDate
        self.description = description
    }
} 