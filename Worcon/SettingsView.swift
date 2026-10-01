import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @FocusState private var addressFocused: Bool
    @ObservedObject var store: ConversationStore
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("backendURL") private var backendURL = "http://MacBook-Pro.local:8787"
    @State private var accessToken = ""
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题", selection: $appearance) {
                        ForEach(WorconAppearance.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("模型连接") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("服务地址")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        TextField("https://你的线上服务地址", text: $backendURL)
                            .focused($addressFocused)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(.horizontal, 13).padding(.vertical, 12)
                            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color.primary.opacity(0.1)))

                        SecureField("线上连接口令", text: $accessToken)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($addressFocused)
                            .padding(.horizontal, 13).padding(.vertical, 12)
                            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                        HStack {
                            Button("保存口令") {
                                let value = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
                                let status = KeychainStore.saveBackendToken(value)
                                viewModel.notice = status == errSecSuccess ? "连接口令已安全保存在这台 iPhone。" : "保存连接口令失败，请重试。"
                                viewModel.showingNotice = true
                                addressFocused = false
                            }
                            .disabled(accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Spacer()
                            Button("移除口令") {
                                let status = KeychainStore.deleteBackendToken()
                                if status == errSecSuccess { accessToken = "" }
                            }
                        }
                        .font(.footnote)
                        Text("线上服务使用 HTTPS 和独立连接口令。Groq 密钥只存放在服务端。")
                            .font(.footnote).foregroundStyle(.secondary)

                        Button {
                            Task { await viewModel.checkBackend(backendURL: backendURL, store: store) }
                        } label: {
                            HStack { Spacer(); if viewModel.isChecking { ProgressView().tint(Color(uiColor: .systemBackground)) }; Text(viewModel.isChecking ? "正在检查…" : "检查连接").font(.system(size: 14, weight: .semibold)); Spacer() }
                                .padding(.vertical, 12).foregroundStyle(Color(uiColor: .systemBackground))
                                .background(settingsAccent, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isChecking || backendURL.isEmpty)

                        if viewModel.hasSavedKey {
                            Text("这台 iPhone 里还留有你刚才保存的旧版密钥。它不会被 App 使用；实际请求由 Mac 后端的环境变量持有密钥。")
                                .font(.system(size: 11)).lineSpacing(3).foregroundStyle(.secondary)
                            Button("删除 iPhone 上未使用的旧密钥", role: .destructive) {
                                let status = KeychainStore.delete()
                                if status == errSecSuccess {
                                    viewModel.hasSavedKey = false
                                    viewModel.notice = "已删除 iPhone 上未使用的密钥。Mac 后端使用独立的环境变量密钥。"
                                    viewModel.showingNotice = true
                                }
                            }.font(.system(size: 12))
                        }
                        Text("本机开发地址仍需手机和 Mac 连接同一 Wi-Fi；线上地址可使用 Wi-Fi 或手机流量。")
                            .font(.system(size: 11)).lineSpacing(3).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                }
                Section("连接状态") {
                    Label(store.connectionMessage, systemImage: "circle.slash")
                        .foregroundStyle(.secondary)
                    Text("当前配置的服务需要保持在线。连接失败时不会生成模拟回复。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("体验") {
                    Toggle("等待动画", isOn: $animationsEnabled)
                }
                Section("聊天记录") {
                    Button("删除当前对话", role: .destructive) { store.deleteSelected() }
                    Button("清空所有记录", role: .destructive) { viewModel.showingDeleteConfirmation = true }
                }
                Section {
                    Text("Worcon 提供情绪支持与自我理解，不替代专业医疗服务。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.worconBackground)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("清空所有聊天记录？", isPresented: $viewModel.showingDeleteConfirmation, titleVisibility: .visible) {
                Button("清空记录", role: .destructive) { store.clearAll() }
                Button("取消", role: .cancel) {}
            }
            .alert("Worcon 连接", isPresented: $viewModel.showingNotice) {
                Button("好", role: .cancel) {}
            } message: { Text(viewModel.notice) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { addressFocused = false }
                }
            }
        }
        .preferredColorScheme(WorconAppearance(rawValue: appearance)?.colorScheme)
        .onAppear { accessToken = KeychainStore.readBackendToken() ?? "" }
    }

    @Environment(\.dismiss) private var dismiss

    private var settingsAccent: Color { .worconAccent }
}

@MainActor
private final class SettingsViewModel: ObservableObject {
    @Published var showingDeleteConfirmation = false
    @Published var showingNotice = false
    @Published var notice = ""
    @Published var hasSavedKey = KeychainStore.read() != nil
    @Published var isChecking = false

    func checkBackend(backendURL: String, store: ConversationStore) async {
        guard let base = URL(string: backendURL),
              let url = URL(string: "/health", relativeTo: base) else {
            notice = "服务地址格式不正确。线上地址应以 https:// 开头。"
            showingNotice = true
            return
        }
        isChecking = true
        defer { isChecking = false }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 130
            if let token = KeychainStore.readBackendToken(), !token.isEmpty {
                guard url.scheme?.lowercased() == "https" else {
                    notice = "保存了线上连接口令后，请使用 HTTPS 服务地址。"
                    showingNotice = true
                    return
                }
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                store.connectionMessage = "连接口令无效"
                notice = "连接口令缺失或无效。请在设置中保存与线上服务相同的口令。"
                showingNotice = true
                return
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let health = try? JSONDecoder().decode(BackendHealth.self, from: data), health.status == "ok" else {
                throw URLError(.badServerResponse)
            }
            store.connectionMessage = health.groqConfigured
                ? (health.authRequired == true ? "线上服务已连接，Groq 密钥已配置" : "服务已连接，Groq 密钥已配置")
                : "服务已连接，但尚未配置 Groq 密钥"
            notice = store.connectionMessage
        } catch {
            store.connectionMessage = "后端未连接"
            notice = "连接失败。请检查服务地址与网络。\n\(error.localizedDescription)"
        }
        showingNotice = true
    }

    private struct BackendHealth: Decodable {
        let status: String
        let groqConfigured: Bool
        let authRequired: Bool?
    }
}
