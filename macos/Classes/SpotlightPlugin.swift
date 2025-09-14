import Cocoa
import FlutterMacOS
import Carbon
import SwiftUI
import AppKit

public class SpotlightPlugin: NSObject, FlutterPlugin {
    // Flutter 通信通道
    private var channel: FlutterMethodChannel!

    // Spotlight window
    private var spotlightWindow: NSWindow!
    private var spotlightViewModel: SpotlightViewModel!

    // Carbon 热键相关
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private var hasCenteredOnce = false

    // MARK: - Method calls from Flutter
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SpotlightPlugin()
        instance.channel = FlutterMethodChannel(name: "spotlight", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(instance, channel: instance.channel)

        instance.createSpotlightWindow()
        instance.registerCarbonHotkey()
    }

    deinit {
        unregisterCarbonHotkey()
    }

    // MARK: - Carbon 热键注册
    private func registerCarbonHotkey() {
        let trusted = AXIsProcessTrusted()

        if !trusted {
            // 需要辅助功能权限
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x53504C54), id: 1)
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                let pluginPtr = unsafeBitCast(userData, to: SpotlightPlugin.self)

                DispatchQueue.main.async {
                    pluginPtr.toggleSpotlight(show: true)
                }

                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if result != noErr {
            print("❌ 安装事件处理器失败: \(result)")
            return
        }

        // let modifiers = UInt32(cmdKey | shiftKey)
        let modifiers = UInt32(optionKey)
        let keyCode = UInt32(49)

        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerResult == noErr {
            print("✅ Carbon 热键注册成功！")
        } else {
            print("❌ Carbon 热键注册失败: \(registerResult)")
        }
    }

    private func unregisterCarbonHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    // MARK: - Method calls from Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateResult":
            DispatchQueue.main.async {
                if let text = call.arguments as? String {
                    self.spotlightViewModel.showResult(text)
                } else {
                    self.spotlightViewModel.resultFinished()
                }
            }
            result(nil)
            // if let text = call.arguments as? String {
            //     DispatchQueue.main.async {
            //         self.spotlightViewModel.showResult(text)
            //     }
            //     result(nil)
            // } else {
            //     result(FlutterError(code: "invalid_args", message: "expected string", details: nil))
            // }
        case "show":
            DispatchQueue.main.async {
                self.toggleSpotlight(show: true)
            }
            result(nil)
        case "hide":
            DispatchQueue.main.async {
                self.toggleSpotlight(show: false)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Window creation (SwiftUI版本)
    private func createSpotlightWindow() {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 180

        spotlightViewModel = SpotlightViewModel()
        spotlightViewModel.onTranslate = { [weak self] text in
            self?.channel.invokeMethod("onTranslate", arguments: text)
        }
        spotlightViewModel.onSearch = { [weak self] text in
            self?.performSearch(text)
        }
        spotlightViewModel.onClose = { [weak self] in
            self?.toggleSpotlight(show: false)
        }

        let spotlightView = SpotlightView(viewModel: spotlightViewModel)
        let hostingController = NSHostingController(rootView: spotlightView)

        spotlightWindow = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        spotlightWindow.isReleasedWhenClosed = false
        spotlightWindow.level = .floating
        spotlightWindow.titleVisibility = .hidden
        spotlightWindow.titlebarAppearsTransparent = true
        spotlightWindow.standardWindowButton(.closeButton)?.isHidden = true
        spotlightWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        spotlightWindow.standardWindowButton(.zoomButton)?.isHidden = true
        spotlightWindow.isMovableByWindowBackground = true

        spotlightWindow.isOpaque = false
        spotlightWindow.backgroundColor = .clear
        spotlightWindow.contentViewController = hostingController
        spotlightWindow.delegate = self
    }

    // MARK: - 新增：执行搜索
    private func performSearch(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        // URL 编码
        if let encodedText = trimmedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "https://www.google.com/search?q=\(encodedText)"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                // 搜索后关闭窗口
                toggleSpotlight(show: false)
            }
        }
    }

    // MARK: - Toggle show/hide
    private func toggleSpotlight(show: Bool) {
        if show {
            spotlightWindow.makeKeyAndOrderFront(nil)

            if !hasCenteredOnce {
                spotlightWindow.center()
                hasCenteredOnce = true
            }

            NSApp.activate(ignoringOtherApps: true)
            spotlightViewModel.reset()

            // 延迟聚焦，确保窗口已完全显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.spotlightViewModel.focusInput = true

                // --- 读取剪贴板 ---
                // if let clipboardText = NSPasteboard.general.string(forType: .string), !clipboardText.isEmpty {
                //     self.spotlightViewModel.inputText = clipboardText
                //     // 设置全选标志
                //     self.spotlightViewModel.selectAll = true
                // } else {
                //     self.spotlightViewModel.inputText = ""
                // }
            }
        } else {
            spotlightWindow.orderOut(nil)
        }
    }
}

// 让窗口失去焦点时关闭
extension SpotlightPlugin: NSWindowDelegate {
    public func windowDidResignKey(_ notification: Notification) {
        toggleSpotlight(show: false)
    }
}

// MARK: - SwiftUI ViewModel
class SpotlightViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var resultText: String = ""
    @Published var showResult: Bool = false
    @Published var focusInput: Bool = false
    @Published var finished: Bool = false
    @Published var selectAll: Bool = false  // 控制全选
    @Published var isSearchMode: Bool = false

    var onTranslate: ((String) -> Void)?
    var onSearch: ((String) -> Void)?
    var onClose: (() -> Void)?

    func performAction() {  // 根据模式执行不同操作
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        if isSearchMode {
            onSearch?(text)
        } else {
            onTranslate?(text)
        }
    }

    func close() {
        onClose?()
    }

    func showResult(_ text: String) {
        resultText += text
        showResult = true
        finished = false
    }

    func resultFinished() {
        finished = true
    }

    func backToInput() {
        selectAll = true
        showResult = false
        focusInput = true
        resultText = ""
    }

    func copyResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(resultText, forType: .string)
    }

    func reset() {
        inputText = ""
        resultText = ""
        showResult = false
        focusInput = false
        finished = false
        selectAll = false  // 重置全选状态
    }
}

// MARK: - SpotlightView (主视图)
struct SpotlightView: View {
    @ObservedObject var viewModel: SpotlightViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // 背景卡片：圆角、阴影，自适配暗色
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)

            if (viewModel.showResult) {
                ResultView(viewModel: viewModel)
            } else {
                VStack(spacing: 12) {
                    // --- 输入区：使用自定义的 NSTextView 包装以拦截回车键 ---
                    SpotlightTextView(
                        text: $viewModel.inputText,
                        isFirstResponder: $isInputFocused,
                        selectAll: $viewModel.selectAll, // 传递全选绑定
                        placeholder: "输入要翻译/搜索的内容（Shift+Enter 换行，Enter 提交）"
                    ) {
                        viewModel.performAction()
                    }
                    .frame(height: 108)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.18), lineWidth: 1))

                    // --- 操作按钮行 ---
                    HStack(spacing: 12) {
                        Button(action: { viewModel.close() }) {
                            Text("关闭")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(action: { viewModel.performAction() }) {
                            Text(viewModel.isSearchMode ? "搜索" : "翻译")
                                .frame(minWidth: 72)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: viewModel.isSearchMode ? .purple : .accentColor))

                        Spacer()

                        // Switch 控件：打开时显示“搜索”按钮文本
                        Toggle(isOn: $viewModel.isSearchMode) {
                            Text(viewModel.isSearchMode ? "搜索模式" : "翻译模式")
                                .font(.system(size: 12))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 180) // 更小一些的窗口
        .onChange(of: viewModel.focusInput) { shouldFocus in
            if shouldFocus {
                isInputFocused = true
                viewModel.focusInput = false
            }
        }
        .onAppear {
            // 首次出现时聚焦输入
            isInputFocused = true
        }
        // 监听 ESC (这种方式只有控件有焦点时才会响应)
        .onExitCommand {
            if viewModel.showResult {
                viewModel.backToInput()
            }
        }
    }
}

// MARK: - ResultView（结果展示）
struct ResultView: View {
    @ObservedObject var viewModel: SpotlightViewModel

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                Text(viewModel.resultText)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(6)
            }
            .frame(height: 108)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.18), lineWidth: 1))

            HStack {
                if !viewModel.finished {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.small)
                        .opacity(viewModel.finished ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.finished)
                }

                Spacer()

                Button("复制") {
                    viewModel.copyResult()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("返回") {
                    viewModel.backToInput()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        // 捕获 ESC (这种方式可以在控件无焦点时响应事件，但当控件获取焦点后，这里的事件就不起作用了，所以需要与上面的配合)
        .background(
            KeyCatcherView {
                viewModel.backToInput()
            }
        )
    }
}

struct KeyCatcherView: NSViewRepresentable {
    var onEsc: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherNSView()
        view.onEsc = onEsc
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}

class KeyCatcherNSView: NSView {
    var onEsc: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // 53 = ESC
            onEsc?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - 自定义按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - SpotlightTextView: 用 NSTextView 拦截回车键
struct SpotlightTextView: NSViewRepresentable {
    @Binding var text: String
    var isFirstResponder: FocusState<Bool>.Binding
    @Binding var selectAll: Bool  // 全选控制
    var placeholder: String?
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // 创建自定义的 NSTextView
        let textView = KeyInterceptingTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.onCommit = {
            // 保证回到主线程触发 SwiftUI 回调
            DispatchQueue.main.async {
                onCommit()
            }
        }

        // placeholder（简单实现：如果空则显示灰色占位）
        if let placeholder = placeholder, text.isEmpty {
            textView.string = ""
            context.coordinator.placeholderLabel.stringValue = placeholder
            context.coordinator.placeholderLabel.isHidden = false
        }

        // 包装到 ScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? KeyInterceptingTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        // placeholder 隐藏/显示
        context.coordinator.placeholderLabel.isHidden = !text.isEmpty

        // 聚焦控制
        // if isFirstResponder.wrappedValue, nsView.window?.firstResponder != textView {
        nsView.window?.makeFirstResponder(textView)
        // }

        // 全选控制
        if selectAll {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                textView.selectAll(nil)
                // 重置全选标志，防止重复触发
                self.selectAll = false
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SpotlightTextView
        weak var textView: KeyInterceptingTextView?
        weak var scrollView: NSScrollView?
        lazy var placeholderLabel: NSTextField = {
            let lbl = NSTextField(labelWithString: "")
            lbl.textColor = NSColor.placeholderTextColor
            lbl.isEditable = false
            lbl.backgroundColor = .clear
            lbl.isBordered = false
            lbl.font = NSFont.systemFont(ofSize: 13)
            return lbl
        }()

        init(_ parent: SpotlightTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else {
                return
            }
            parent.text = tv.string
            placeholderLabel.isHidden = !tv.string.isEmpty
        }
    }
}

// 自定义 NSTextView：拦截 Enter/Shift+Enter
class KeyInterceptingTextView: NSTextView {
    var onCommit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // 判断是否为回车
        if let chars = event.charactersIgnoringModifiers, chars == "\r" || chars == "\n" {
            // 如果按下 Shift -> 插入换行
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event) // 交给系统处理（插入换行）
            } else {
                // 直接回车 -> 提交（不插入换行）
                onCommit?()
                // 不调用 super，防止插入换行
            }
        } else {
            super.keyDown(with: event)
        }
    }
}
