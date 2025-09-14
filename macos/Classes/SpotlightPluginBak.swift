// import Cocoa
// import FlutterMacOS
// import Carbon
//
// public class SpotlightPlugin: NSObject, FlutterPlugin {
//     // Flutter 通信通道
//     private var channel: FlutterMethodChannel!
//
//     // Spotlight window & views
//     private var spotlightWindow: NSWindow!
//     private var inputScrollView: NSScrollView!
//     private var inputTextView: NSTextView!
//     private var resultTextView: NSTextView!
//     private var resultContainer: NSView!
//
//     // Carbon 热键相关
//     private var hotKeyRef: EventHotKeyRef?
//     private var eventHandler: EventHandlerRef?
//
//     // MARK: - Method calls from Flutter
//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let instance = SpotlightPlugin()
//         instance.channel = FlutterMethodChannel(name: "spotlight", binaryMessenger: registrar.messenger)
//         registrar.addMethodCallDelegate(instance, channel: instance.channel)
//
//         instance.createSpotlightWindow()
//         instance.registerCarbonHotkey()
//     }
//
//     deinit {
//         unregisterCarbonHotkey()
//     }
//
//     // MARK: - Carbon 热键注册
//     private func registerCarbonHotkey() {
//         print("🔧 开始注册 Carbon 热键...")
//
//         // 检查权限
//         let trusted = AXIsProcessTrusted()
//         print("辅助功能权限状态: \(trusted)")
//
//         if !trusted {
//             print("⚠️ 需要辅助功能权限！")
//             let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
//             AXIsProcessTrustedWithOptions(options as CFDictionary)
//             return
//         }
//
//         // 定义热键 ID
//         let hotKeyID = EventHotKeyID(signature: OSType(0x53504C54), id: 1) // 'SPLT'
//
//         // 创建热键事件处理器
//         var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
//
//         let result = InstallEventHandler(
//             GetApplicationEventTarget(),
//             { (nextHandler, theEvent, userData) -> OSStatus in
//                 // 获取 SpotlightPlugin 实例
//                 let pluginPtr = unsafeBitCast(userData, to: SpotlightPlugin.self)
//
//                 print("🎯 Carbon 热键被触发！")
//
//                 DispatchQueue.main.async {
//                     pluginPtr.toggleSpotlight(show: true)
//                 }
//
//                 return noErr
//             },
//             1,
//             &eventSpec,
//             Unmanaged.passUnretained(self).toOpaque(),
//             &eventHandler
//         )
//
//         if result != noErr {
//             print("❌ 安装事件处理器失败: \(result)")
//             return
//         }
//
//         // 注册热键: Cmd+Shift+Space
//         // modifiers: cmdKey = 256, shiftKey = 512
//         let modifiers = UInt32(cmdKey | shiftKey)
//         let keyCode = UInt32(49) // 空格键
//
//         let registerResult = RegisterEventHotKey(
//             keyCode,
//             modifiers,
//             hotKeyID,
//             GetApplicationEventTarget(),
//             0,
//             &hotKeyRef
//         )
//
//         if registerResult == noErr {
//             print("✅ Carbon 热键注册成功！(Cmd+Shift+Space)")
//         } else {
//             print("❌ Carbon 热键注册失败: \(registerResult)")
//         }
//     }
//
//     private func unregisterCarbonHotkey() {
//         if let hotKeyRef = hotKeyRef {
//             UnregisterEventHotKey(hotKeyRef)
//         }
//
//         if let eventHandler = eventHandler {
//             RemoveEventHandler(eventHandler)
//         }
//     }
//
//     // 辅助方法：获取修饰键名称
//     private func getModifierNames(_ flags: NSEvent.ModifierFlags) -> String {
//         var names: [String] = []
//         if flags.contains(.command) { names.append("Cmd") }
//         if flags.contains(.shift) { names.append("Shift") }
//         if flags.contains(.option) { names.append("Option") }
//         if flags.contains(.control) { names.append("Ctrl") }
//         if flags.contains(.function) { names.append("Fn") }
//         return names.isEmpty ? "无" : names.joined(separator: "+")
//     }
//
//     // MARK: - Method calls from Flutter
//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "updateResult":
//             if let text = call.arguments as? String {
//                 DispatchQueue.main.async {
//                     self.showResult(text)
//                 }
//                 result(nil)
//             } else {
//                 result(FlutterError(code: "invalid_args", message: "expected string", details: nil))
//             }
//         case "show":
//             DispatchQueue.main.async {
//                 self.toggleSpotlight(show: true)
//             }
//             result(nil)
//         case "hide":
//             DispatchQueue.main.async {
//                 self.toggleSpotlight(show: false)
//             }
//             result(nil)
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
//
//     // MARK: - Window creation (保持原有代码)
//     private func createSpotlightWindow() {
//         let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
//         let windowWidth: CGFloat = 700
//         let windowHeight: CGFloat = 220
//
//         spotlightWindow = NSWindow(
//             contentRect: NSRect(
//                 x: (screenFrame.width - windowWidth) / 2,
//                 y: (screenFrame.height - windowHeight) / 2,
//                 width: windowWidth,
//                 height: windowHeight
//             ),
//             styleMask: [.titled, .fullSizeContentView],
//             backing: .buffered,
//             defer: false
//         )
//
//         spotlightWindow.isReleasedWhenClosed = false
//         spotlightWindow.level = .floating
//         spotlightWindow.titleVisibility = .hidden
//         spotlightWindow.titlebarAppearsTransparent = true
//         spotlightWindow.isOpaque = false
//         spotlightWindow.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.86)
//         spotlightWindow.hasShadow = true
//         spotlightWindow.center()
//
//         // Content view
//         let content = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
//         spotlightWindow.contentView = content
//
//         // Input area (multiline)
//         let inputFrame = NSRect(x: 16, y: 80, width: windowWidth - 32, height: 100)
//         inputScrollView = NSScrollView(frame: inputFrame)
//         inputScrollView.hasVerticalScroller = true
//         inputScrollView.borderType = .noBorder
//         inputScrollView.wantsLayer = true
//         inputScrollView.layer?.cornerRadius = 6
//
//         inputTextView = NSTextView(frame: inputScrollView.bounds)
//         inputTextView.font = NSFont.systemFont(ofSize: 14)
//         inputTextView.isRichText = false
//         inputTextView.isAutomaticQuoteSubstitutionEnabled = false
//         inputTextView.delegate = self
//         inputTextView.enclosingScrollView?.borderType = .noBorder
//
//         inputScrollView.documentView = inputTextView
//         content.addSubview(inputScrollView)
//
//         // Buttons: Translate, Close
//         let translateButton = NSButton(title: "翻译", target: self, action: #selector(onTranslateClicked))
//         translateButton.frame = NSRect(x: windowWidth - 90, y: 36, width: 70, height: 28)
//         translateButton.bezelStyle = .rounded
//         content.addSubview(translateButton)
//
//         let closeButton = NSButton(title: "关闭", target: self, action: #selector(onCloseClicked))
//         closeButton.frame = NSRect(x: windowWidth - 170, y: 36, width: 70, height: 28)
//         closeButton.bezelStyle = .rounded
//         content.addSubview(closeButton)
//
//         // Result container (initially hidden)
//         resultContainer = NSView(frame: NSRect(x: 16, y: 16, width: windowWidth - 32, height: 180))
//         resultContainer.isHidden = true
//
//         resultTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: resultContainer.frame.width, height: resultContainer.frame.height - 40))
//         resultTextView.isEditable = false
//         resultTextView.font = NSFont.systemFont(ofSize: 13)
//         resultContainer.addSubview(resultTextView)
//
//         // Result buttons: Copy, Back
//         let copyButton = NSButton(title: "复制", target: self, action: #selector(onCopyClicked))
//         copyButton.frame = NSRect(x: resultContainer.frame.width - 160, y: 8, width: 70, height: 28)
//         copyButton.bezelStyle = .rounded
//         resultContainer.addSubview(copyButton)
//
//         let backButton = NSButton(title: "返回", target: self, action: #selector(onBackClicked))
//         backButton.frame = NSRect(x: resultContainer.frame.width - 80, y: 8, width: 70, height: 28)
//         backButton.bezelStyle = .rounded
//         resultContainer.addSubview(backButton)
//
//         content.addSubview(resultContainer)
//     }
//
//     // MARK: - Toggle show/hide
//     private func toggleSpotlight(show: Bool) {
//         if show {
//             spotlightWindow.makeKeyAndOrderFront(nil)
//             NSApp.activate(ignoringOtherApps: true)
//             inputTextView.string = ""
//             inputTextView.window?.makeFirstResponder(inputTextView)
//             inputScrollView.isHidden = false
//             resultContainer.isHidden = true
//         } else {
//             spotlightWindow.orderOut(nil)
//         }
//     }
//
//     // MARK: - UI Actions
//     @objc private func onTranslateClicked() {
//         sendInputToFlutter()
//     }
//
//     @objc private func onCloseClicked() {
//         toggleSpotlight(show: false)
//     }
//
//     @objc private func onCopyClicked() {
//         let pasteboard = NSPasteboard.general
//         pasteboard.clearContents()
//         pasteboard.setString(resultTextView.string, forType: .string)
//     }
//
//     @objc private func onBackClicked() {
//         resultContainer.isHidden = true
//         inputScrollView.isHidden = false
//         inputTextView.window?.makeFirstResponder(inputTextView)
//     }
//
//     private func sendInputToFlutter() {
//         let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
//         guard !text.isEmpty else {
//             return
//         }
//         channel.invokeMethod("onQuery", arguments: text)
//     }
//
//     private func showResult(_ text: String) {
//         inputScrollView.isHidden = true
//         resultContainer.isHidden = false
//         resultTextView.string = text
//     }
// }
//
// // MARK: - NSTextViewDelegate
// extension SpotlightPlugin: NSTextViewDelegate {
//     public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
//         if commandSelector == #selector(NSTextView.insertNewline(_:)) {
//             if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
//                 sendInputToFlutter()
//                 return true
//             }
//             return false
//         }
//         return false
//     }
// }