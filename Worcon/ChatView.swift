import SwiftUI

struct ChatView: View {
    @ObservedObject var store: ConversationStore
    @StateObject private var viewModel = ChatViewModel()
    @AppStorage("backendURL") private var backendURL = "http://MacBook-Pro.local:8787"
    @AppStorage("groqModel") private var groqModel = "openai/gpt-oss-20b"
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            KeyboardDock {
                VStack(spacing: 0) {
                    if let conversation = store.selectedConversation, conversation.messages.isEmpty {
                        welcome
                    } else {
                        messageList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } bar: {
                composer
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color.worconBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { inputFocused = false; store.createConversation() } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 44, height: 44)

                    }
                    .accessibilityLabel("新建对话")
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        WorconMark(size: 24)
                        Text("worcon")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .tracking(0.2)
                    }
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Menu {
                            Button("GPT OSS 20B · 快速") { groqModel = "openai/gpt-oss-20b" }
                            Button("GPT OSS 120B · 深度") { groqModel = "openai/gpt-oss-120b" }
                            Button("Qwen 3.8 27B · 推理") { groqModel = "qwen/qwen3.8-27b" }
                        } label: {
                            HStack(spacing: 4) {
                                Text(modelRoleTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 44)

                        }
                        .accessibilityLabel("切换聊天模型，当前职责为\(modelRoleTitle)")

                        Button { inputFocused = false; viewModel.showingSettings = true } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44)

                        }
                        .accessibilityLabel("更多设置")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingSettings) { SettingsView(store: store) }
        }
        .tint(.primary)
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color.worconAccent).frame(width: 6, height: 6)
                    Text("一个留给自己的空间")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(Color.primary.opacity(0.54))
                }
                .padding(.top, 34)

                Text("你好，\n慢慢说。")
                    .font(.system(size: 43, weight: .regular, design: .rounded))
                    .tracking(-1.6)
                    .lineSpacing(1)
                    .foregroundStyle(Color.primary.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)

                Text("最近有什么事情，想找个地方理一理？")
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text("也可以从这里开始")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.38))
                        .padding(.bottom, 3)

                    starter("最近有件事一直在我脑子里转…", symbol: "arrow.turn.down.right")
                    starter("我现在有点说不清自己的感受。", symbol: "waveform.path")
                    starter("我想做个决定，想先把思路理清。", symbol: "circle.lefthalf.filled")
                }
                .padding(.top, 38)

                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text("你的对话保存在这台设备上")
                        .font(.system(size: 11, weight: .regular))
                }
                .foregroundStyle(Color.primary.opacity(0.34))
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 26)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(store.selectedConversation?.messages ?? []) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if store.isGenerating {
                        if store.streamingReply.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView().tint(.secondary)
                                Text("正在认真读你说的话…")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Spacer()
                                Button("停止") { store.cancelGeneration() }
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        } else {
                            MessageBubble(message: ChatMessage(id: store.streamingMessageID, role: .assistant, content: store.streamingReply))
                            HStack {
                                Text("正在回复…").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("停止") { store.cancelGeneration() }.font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    if let error = store.generationError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("暂时没有收到回复", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.footnote)
                                .lineSpacing(3)
                                .foregroundStyle(Color.primary.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            if error != "回复已取消。可以重试。" {
                                Button("重试") { store.retryLast(model: groqModel, backendURL: backendURL) }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.worconAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.worconAccent.opacity(0.12), in: Capsule())
                            } else {
                                Button("继续生成") { store.retryLast(model: groqModel, backendURL: backendURL) }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.worconAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.worconAccent.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.orange.opacity(0.14), lineWidth: 0.7))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: store.selectedConversation?.messages.count) { _, _ in
                if let last = store.selectedConversation?.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("写下你想说的话…", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .font(.body)
                .padding(.vertical, 10)
                .padding(.leading, 8)
                .accessibilityLabel("消息内容")
            Button { inputFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起键盘")
                .opacity(inputFocused ? 1 : 0)
                .disabled(!inputFocused)
                .accessibilityHidden(!inputFocused)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 35, height: 35)
                    .background(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.primary.opacity(0.28) : Color.worconAccent, in: Circle())
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isGenerating)
            .padding(6)
            .accessibilityLabel("发送消息")
        }
        .padding(.leading, 8)
        .padding(.trailing, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(Color.primary.opacity(0.13), lineWidth: 0.7))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(LinearGradient(colors: [.worconBackground.opacity(0), .worconBackground.opacity(0.96)], startPoint: .top, endPoint: .bottom))
    }

    private func send() {
        let text = viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.send(text, model: groqModel, backendURL: backendURL)
        viewModel.draft = ""
        inputFocused = false
    }

    private var modelRoleTitle: String {
        switch groqModel {
        case "openai/gpt-oss-120b": "深度"
        case "qwen/qwen3.8-27b": "推理"
        default: "快速"
        }
    }

    private func starter(_ title: String, symbol: String) -> some View {
        Button {
            viewModel.draft = title.replacingOccurrences(of: "…", with: "")
            inputFocused = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.worconAccent.opacity(0.9))
                    .frame(width: 21)
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.26))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 44) }
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        WorconMark(size: 17)
                        Text("worcon")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.46))
                    }
                    Text(message.content)
                        .font(.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .foregroundStyle(Color.primary.opacity(0.9))
                }
                Spacer(minLength: 18)
            } else {
                Text(message.content)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .background(Color.primary.opacity(0.105), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.6))
            }
            if message.role == .assistant { Spacer(minLength: 20) }
        }
        .frame(maxWidth: .infinity)
    }
}

// Vector mark: a small seedling growing from soil, inside one quiet circle.
private struct WorconMark: View {
    var size: CGFloat = 24
    var body: some View {
        Canvas { context, canvas in
            let w = canvas.width
            let h = canvas.height
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: w, height: h)),
                         with: .color(Color.worconAccent.opacity(0.13)))
            var soil = Path()
            soil.move(to: CGPoint(x: w * 0.16, y: h * 0.75))
            soil.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.75), control: CGPoint(x: w * 0.5, y: h * 0.56))
            soil.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.75), control: CGPoint(x: w * 0.5, y: h * 1.02))
            context.fill(soil, with: .color(Color(red: 0.55, green: 0.39, blue: 0.24)))
            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.5, y: h * 0.73))
            stem.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.38), control: CGPoint(x: w * 0.45, y: h * 0.5))
            context.stroke(stem, with: .color(Color.worconAccent), style: StrokeStyle(lineWidth: w * 0.065, lineCap: .round))
            var left = Path()
            left.move(to: CGPoint(x: w * 0.49, y: h * 0.49))
            left.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.28), control: CGPoint(x: w * 0.23, y: h * 0.54))
            left.addQuadCurve(to: CGPoint(x: w * 0.49, y: h * 0.49), control: CGPoint(x: w * 0.47, y: h * 0.24))
            context.fill(left, with: .color(Color.worconAccent))
            var right = Path()
            right.move(to: CGPoint(x: w * 0.51, y: h * 0.42))
            right.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.20), control: CGPoint(x: w * 0.5, y: h * 0.17))
            right.addQuadCurve(to: CGPoint(x: w * 0.51, y: h * 0.42), control: CGPoint(x: w * 0.81, y: h * 0.44))
            context.fill(right, with: .color(Color(red: 0.43, green: 0.72, blue: 0.42)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var showingSettings = false
}

// Let UIKit track keyboard movement directly, including interactive dismissal.
// Both hosting views opt out of a second SwiftUI keyboard safe-area adjustment.
private struct KeyboardDock<Content: View, Bar: View>: UIViewControllerRepresentable {
    let content: Content
    let bar: Bar
    init(@ViewBuilder content: () -> Content, @ViewBuilder bar: () -> Bar) {
        self.content = content()
        self.bar = bar()
    }
    func makeUIViewController(context: Context) -> DockController<Content, Bar> {
        DockController(content: content, bar: bar)
    }
    func updateUIViewController(_ controller: DockController<Content, Bar>, context: Context) {
        controller.contentHost.rootView = content
        controller.barHost.rootView = bar
        controller.barHost.view.invalidateIntrinsicContentSize()
    }
}

private final class DockController<Content: View, Bar: View>: UIViewController {
    let contentHost: UIHostingController<Content>
    let barHost: UIHostingController<Bar>
    init(content: Content, bar: Bar) {
        contentHost = UIHostingController(rootView: content)
        barHost = UIHostingController(rootView: bar)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        contentHost.safeAreaRegions = []
        barHost.safeAreaRegions = []
        barHost.sizingOptions = [.intrinsicContentSize]
        for host in [contentHost as UIViewController, barHost as UIViewController] {
            addChild(host)
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
        barHost.view.setContentHuggingPriority(.required, for: .vertical)
        barHost.view.setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            contentHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentHost.view.bottomAnchor.constraint(equalTo: barHost.view.topAnchor),
            barHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            barHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barHost.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
    }
}
