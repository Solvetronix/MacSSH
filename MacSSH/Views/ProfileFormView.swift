import SwiftUI

struct ProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var privateKeyPath: String = ""
    @State private var keyType: SSHKeyType = .password
    @State private var description: String = ""
    @State private var keyInfo: (type: String, fingerprint: String)? = nil
    
    private var editingProfile: Profile?
    
    init(viewModel: ProfileViewModel, editingProfile: Profile? = nil) {
        self.viewModel = viewModel
        self.editingProfile = editingProfile
        
        if let profile = editingProfile {
            _name = State(initialValue: profile.name)
            _host = State(initialValue: profile.host)
            _port = State(initialValue: String(profile.port))
            _username = State(initialValue: profile.username)
            _password = State(initialValue: profile.password ?? "")
            _privateKeyPath = State(initialValue: profile.privateKeyPath ?? "")
            _keyType = State(initialValue: profile.keyType)
            _description = State(initialValue: profile.description ?? "")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SSH Connection")
                .font(.title2.bold())
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("Name").frame(width: 80, alignment: .leading)
                        TextField("Connection name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Host").frame(width: 80, alignment: .leading)
                        TextField("example.com", text: $host)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Port").frame(width: 80, alignment: .leading)
                        TextField("22", text: $port)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Username").frame(width: 80, alignment: .leading)
                        TextField("user", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Auth Type").frame(width: 80, alignment: .leading)
                        Picker("", selection: $keyType) {
                            ForEach(SSHKeyType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if keyType == .password {
                        HStack {
                            Text("Password").frame(width: 80, alignment: .leading)
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    } else if keyType == .privateKey {
                        HStack {
                            Text("Key Path").frame(width: 80, alignment: .leading)
                            TextField("/path/to/private/key", text: $privateKeyPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Browse") {
                                selectPrivateKey()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let keyInfo = keyInfo {
                            HStack {
                                Text("Key Info").frame(width: 80, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Type: \(keyInfo.type)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Fingerprint: \(keyInfo.fingerprint)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Description").frame(width: 80, alignment: .leading)
                        TextField("Optional description", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    saveProfile()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .frame(minWidth: 420, minHeight: 400)
        .onChange(of: privateKeyPath) { _, newPath in
            if !newPath.isEmpty && keyType == .privateKey {
                loadKeyInfo(path: newPath)
            } else {
                keyInfo = nil
            }
        }
    }
    
    private func selectPrivateKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text]
        panel.message = "Select SSH Private Key"
        
        if panel.runModal() == .OK {
            privateKeyPath = panel.url?.path ?? ""
        }
    }
    
    private func loadKeyInfo(path: String) {
        Task {
            let info = SSHService.getSSHKeyInfo(path: path)
            await MainActor.run {
                self.keyInfo = info
            }
        }
    }
    
    private func saveProfile() {
        let profile = Profile(
            id: editingProfile?.id ?? UUID(),
            name: name,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            password: keyType == .password ? (password.isEmpty ? nil : password) : nil,
            privateKeyPath: keyType == .privateKey ? (privateKeyPath.isEmpty ? nil : privateKeyPath) : nil,
            keyType: keyType,
            lastConnectionDate: editingProfile?.lastConnectionDate,
            description: description.isEmpty ? nil : description
        )
        
        if editingProfile != nil {
            viewModel.updateProfile(profile)
        } else {
            viewModel.addProfile(profile)
        }
    }
} 