import SwiftUI
import AppKit
import Carbon
import Combine
import QuartzCore
import ServiceManagement

@main
struct FocusOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

enum AppTheme: String, CaseIterable, Hashable, Identifiable {
    case system = "Sistema"
    case light = "Claro"
    case dark = "Escuro"
    var id: Self { self }
}

enum FocusModePreset: String, CaseIterable, Hashable, Identifiable {
    case ambient = "Ambiente"
    case deep = "Deep"
    var id: Self { self }
}

struct KeyboardShortcutConfig: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String

    static let defaultShortcut = KeyboardShortcutConfig(
        keyCode: 49,
        carbonModifiers: UInt32(optionKey),
        displayString: "⌥ + Espaço"
    )

    static func from(event: NSEvent) -> KeyboardShortcutConfig? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty else { return nil }

        var carbonMods: UInt32 = 0
        var parts: [String] = []

        if flags.contains(.control) {
            carbonMods |= UInt32(controlKey)
            parts.append("⌃")
        }
        if flags.contains(.option) {
            carbonMods |= UInt32(optionKey)
            parts.append("⌥")
        }
        if flags.contains(.shift) {
            carbonMods |= UInt32(shiftKey)
            parts.append("⇧")
        }
        if flags.contains(.command) {
            carbonMods |= UInt32(cmdKey)
            parts.append("⌘")
        }

        let code = UInt32(event.keyCode)
        let keyName = keyDisplayName(for: event.keyCode, characters: event.charactersIgnoringModifiers)
        parts.append(keyName)

        return KeyboardShortcutConfig(
            keyCode: code,
            carbonModifiers: carbonMods,
            displayString: parts.joined(separator: " + ")
        )
    }

    private static func keyDisplayName(for keyCode: UInt16, characters: String?) -> String {
        switch keyCode {
        case 49: return "Espaço"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let chars = characters?.trimmingCharacters(in: .whitespacesAndNewlines), !chars.isEmpty {
                return chars.uppercased()
            }
            return "Tecla " + String(keyCode)
        }
    }
}

struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let black = RGBAColor(red: 0.0, green: 0.0, blue: 0.0)

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.red = Double(converted.redComponent)
        self.green = Double(converted.greenComponent)
        self.blue = Double(converted.blueComponent)
    }

    func isApproximatelyEqual(to other: RGBAColor, tolerance: Double = 0.02) -> Bool {
        abs(red - other.red) < tolerance &&
        abs(green - other.green) < tolerance &&
        abs(blue - other.blue) < tolerance
    }

    static func lerp(from a: RGBAColor, to b: RGBAColor, t: Double) -> RGBAColor {
        RGBAColor(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t
        )
    }
}

struct DimSwatchPreset: Identifiable {
    let id: String
    let order: Int
    let name: String
    let color: RGBAColor

    static let macOSPresets: [DimSwatchPreset] = [
        DimSwatchPreset(id: "black", order: 9, name: "Preto", color: RGBAColor(red: 0.0, green: 0.0, blue: 0.0)),
        DimSwatchPreset(id: "blue", order: 8, name: "Azul", color: RGBAColor(red: 0.0, green: 0.478, blue: 1.0)),
        DimSwatchPreset(id: "purple", order: 7, name: "Roxo", color: RGBAColor(red: 0.686, green: 0.322, blue: 0.871)),
        DimSwatchPreset(id: "pink", order: 6, name: "Rosa", color: RGBAColor(red: 1.0, green: 0.176, blue: 0.333)),
        DimSwatchPreset(id: "red", order: 5, name: "Vermelho", color: RGBAColor(red: 1.0, green: 0.231, blue: 0.188)),
        DimSwatchPreset(id: "orange", order: 4, name: "Laranja", color: RGBAColor(red: 1.0, green: 0.584, blue: 0.0)),
        DimSwatchPreset(id: "yellow", order: 3, name: "Amarelo", color: RGBAColor(red: 1.0, green: 0.800, blue: 0.0)),
        DimSwatchPreset(id: "green", order: 2, name: "Verde", color: RGBAColor(red: 0.157, green: 0.804, blue: 0.255)),
        DimSwatchPreset(id: "graphite", order: 1, name: "Grafite", color: RGBAColor(red: 0.557, green: 0.557, blue: 0.576))
    ]
}

struct ModeSettings: Codable, Equatable {
    var blurRadius: Double
    var grainAmount: Double
    var gradientAmount: Double
    var windowBordersMode: Bool
    var invertGradient: Bool
    var dimAmount: Double
    var dimColor: RGBAColor?

    var effectiveDimColor: RGBAColor {
        dimColor ?? .black
    }

    static let factoryAmbient = ModeSettings(
        blurRadius: 61.470588235294116,
        grainAmount: 0.15029411764705883,
        gradientAmount: 0.5113257721389208,
        windowBordersMode: false,
        invertGradient: false,
        dimAmount: 0.1341176470588235,
        dimColor: .black
    )

    static let factoryDeep = ModeSettings(
        blurRadius: 62.13071895424838,
        grainAmount: 0.11098039215686278,
        gradientAmount: 0.0,
        windowBordersMode: false,
        invertGradient: false,
        dimAmount: 0.30247549019607844,
        dimColor: .black
    )
}

class OverlayState: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            onUpdate?(true, false)
        }
    }
    @Published var selectedMode: FocusModePreset {
        didSet {
            UserDefaults.standard.set(selectedMode.rawValue, forKey: "selectedMode")
        }
    }
    @Published var blurRadius: Double {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var grainAmount: Double {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var gradientAmount: Double {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var windowBordersMode: Bool {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var invertGradient: Bool {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var dimAmount: Double {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var dimColor: RGBAColor {
        didSet {
            saveCurrentModeSettings()
            if !isApplyingPreset { onUpdate?(false, false) }
        }
    }
    @Published var transitionMs: Double {
        didSet {
            UserDefaults.standard.set(transitionMs, forKey: "transitionMs")
        }
    }
    @Published var shakeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(shakeEnabled, forKey: "shakeEnabled")
        }
    }
    @Published var shakeSensitivity: Double {
        didSet {
            UserDefaults.standard.set(shakeSensitivity, forKey: "shakeSensitivity")
        }
    }
    @Published var shortcut: KeyboardShortcutConfig {
        didSet {
            if let encoded = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(encoded, forKey: "customShortcut")
            }
            onShortcutChange?()
        }
    }
    @Published var isRecordingShortcut: Bool = false
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
            onThemeChange?()
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    @Published var lastUpdateCheck: Date? {
        didSet {
            UserDefaults.standard.set(lastUpdateCheck, forKey: "lastUpdateCheck")
        }
    }
    @Published var isCheckingUpdate: Bool = false
    @Published var updateStatusMessage: String? = nil

    var onUpdate: ((Bool, Bool) -> Void)?
    var onThemeChange: (() -> Void)?
    var onShortcutChange: (() -> Void)?
    private var isApplyingPreset = false

    private var ambientConfig: ModeSettings
    private var deepConfig: ModeSettings

    let currentVersion = "1.01"
    let githubReleasesAPI = ["https:", "", "://github.com", "repos", "Reinaldoking147", "FocusOverlay", "releases", "latest"].joined(separator: "/")

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true


        if let data = UserDefaults.standard.data(forKey: "ambientConfig"),
        let decoded = try? JSONDecoder().decode(ModeSettings.self, from: data) {
        self.ambientConfig = decoded
        } else {
        self.ambientConfig = .factoryAmbient
        }
        if let data = UserDefaults.standard.data(forKey: "deepConfig"),
        let decoded = try? JSONDecoder().decode(ModeSettings.self, from: data) {
        self.deepConfig = decoded
        } else {
        self.deepConfig = .factoryDeep
        }
        let savedMode = UserDefaults.standard.string(forKey: "selectedMode") ?? FocusModePreset.deep.rawValue
        let initialMode = FocusModePreset(rawValue: savedMode) ?? .deep
        self.selectedMode = initialMode
        let activeConfig = (initialMode == .ambient) ? ambientConfig : deepConfig
        self.blurRadius = activeConfig.blurRadius
        self.grainAmount = activeConfig.grainAmount
        self.gradientAmount = activeConfig.gradientAmount
        self.windowBordersMode = activeConfig.windowBordersMode
        self.invertGradient = activeConfig.invertGradient
        self.dimAmount = activeConfig.dimAmount
        self.dimColor = activeConfig.effectiveDimColor
        if let shortcutData = UserDefaults.standard.data(forKey: "customShortcut"),
        let decodedShortcut = try? JSONDecoder().decode(KeyboardShortcutConfig.self, from: shortcutData) {
        self.shortcut = decodedShortcut
        } else {
        self.shortcut = .defaultShortcut
        }
        self.transitionMs = UserDefaults.standard.object(forKey: "transitionMs") as? Double ?? 1000.0
        self.shakeEnabled = UserDefaults.standard.object(forKey: "shakeEnabled") as? Bool ?? true
        self.shakeSensitivity = UserDefaults.standard.object(forKey: "shakeSensitivity") as? Double ?? 0.5
        self.lastUpdateCheck = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date
        let savedTheme = UserDefaults.standard.string(forKey: "theme") ?? AppTheme.system.rawValue
        self.theme = AppTheme(rawValue: savedTheme) ?? .system
        if #available(macOS 13.0, *) {
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
        self.launchAtLogin = false
        }
        }
        var currentSettings: ModeSettings {
        ModeSettings(
        blurRadius: blurRadius,
        grainAmount: grainAmount,
        gradientAmount: gradientAmount,
        windowBordersMode: windowBordersMode,
        invertGradient: invertGradient,
        dimAmount: dimAmount,
        dimColor: dimColor
        )
        }
        var isCurrentModeModified: Bool {
        let targetFactory = (selectedMode == .ambient) ? ModeSettings.factoryAmbient : ModeSettings.factoryDeep
        return abs(currentSettings.blurRadius - targetFactory.blurRadius) > 0.1 ||
        abs(currentSettings.grainAmount - targetFactory.grainAmount) > 0.01 ||
        abs(currentSettings.gradientAmount - targetFactory.gradientAmount) > 0.01 ||
        currentSettings.windowBordersMode != targetFactory.windowBordersMode ||
        currentSettings.invertGradient != targetFactory.invertGradient ||
        abs(currentSettings.dimAmount - targetFactory.dimAmount) > 0.01 ||
        !currentSettings.effectiveDimColor.isApproximatelyEqual(to: targetFactory.effectiveDimColor)
        }
        private func saveCurrentModeSettings() {
        guard !isApplyingPreset else { return }
        if selectedMode == .ambient {
        ambientConfig = currentSettings
        if let encoded = try? JSONEncoder().encode(ambientConfig) {
        UserDefaults.standard.set(encoded, forKey: "ambientConfig")
        }
        } else {
        deepConfig = currentSettings
        if let encoded = try? JSONEncoder().encode(deepConfig) {
        UserDefaults.standard.set(encoded, forKey: "deepConfig")
        }
        }
        }
        func switchMode(to mode: FocusModePreset) {
        guard mode != selectedMode else { return }
        isApplyingPreset = true
        selectedMode = mode
        let targetConfig = (mode == .ambient) ? ambientConfig : deepConfig
        blurRadius = targetConfig.blurRadius
        grainAmount = targetConfig.grainAmount
        gradientAmount = targetConfig.gradientAmount
        windowBordersMode = targetConfig.windowBordersMode
        invertGradient = targetConfig.invertGradient
        dimAmount = targetConfig.dimAmount
        dimColor = targetConfig.effectiveDimColor
        isApplyingPreset = false
        onUpdate?(false, true)
        }
        func resetCurrentModeToFactory() {
        isApplyingPreset = true
        let factory = (selectedMode == .ambient) ? ModeSettings.factoryAmbient : ModeSettings.factoryDeep
        blurRadius = factory.blurRadius
        grainAmount = factory.grainAmount
        gradientAmount = factory.gradientAmount
        windowBordersMode = factory.windowBordersMode
        invertGradient = factory.invertGradient
        dimAmount = factory.dimAmount
        dimColor = factory.effectiveDimColor
        isApplyingPreset = false
        saveCurrentModeSettings()
        objectWillChange.send()
        onUpdate?(false, true)
        }
        func checkForUpdates() {
        guard !isCheckingUpdate else { return }
        isCheckingUpdate = true
        updateStatusMessage = nil
        guard let url = URL(string: githubReleasesAPI) else {
        finishUpdateCheck(message: "Você está na v" + currentVersion)
        return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("FocusOverlay-macOS", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
        DispatchQueue.main.async {
        guard let self = self else { return }
        if let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let tagName = json["tag_name"] as? String {
        let cleanTag = tagName.replacingOccurrences(of: "v", with: "")
        if cleanTag != self.currentVersion {
        self.finishUpdateCheck(message: "Nova versão v" + cleanTag + " disponível!")
        } else {
        self.finishUpdateCheck(message: "Versão mais recente")
        }
        } else {
        self.finishUpdateCheck(message: "Atualizado")
        }
        }
        }.resume()
        }
        private func finishUpdateCheck(message: String) {
        self.isCheckingUpdate = false
        self.lastUpdateCheck = Date()
        self.updateStatusMessage = message
        }
        private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
        do {
        if enabled {
        if SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
        }
        } else {
        if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
        }
        }
        } catch {
        print("Erro Launch at Login: " + error.localizedDescription)
        }
        }
        }
        }
        class MacColorWheelController: NSObject {
        static let shared = MacColorWheelController()
        private var onColorPicked: ((RGBAColor) -> Void)?
        func openColorWheel(initialColor: RGBAColor, onChange: @escaping (RGBAColor) -> Void) {
        self.onColorPicked = onChange
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.color = initialColor.nsColor
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        }
        @objc private func colorDidChange(_ sender: NSColorPanel) {
        let picked = RGBAColor(nsColor: sender.color)
        onColorPicked?(picked)
        }
        }
        struct MacOSCollapsibleColorPicker: View {
        @Binding var selectedColor: RGBAColor
        var isEnabled: Bool
        @State private var isExpanded: Bool = false
        @State private var visibleCount: Int = 0
        @State private var pulseScale: CGFloat = 1.0
        private let totalItems = 10
        private var isCustomMulticolorSelected: Bool {
        !DimSwatchPreset.macOSPresets.contains { $0.color.isApproximatelyEqual(to: selectedColor) }
        }
        var body: some View {
        HStack(spacing: 5) {
        if isExpanded {
        if visibleCount >= 10 {
        Button {
        MacColorWheelController.shared.openColorWheel(initialColor: selectedColor) { newColor in
        selectedColor = newColor
        }
        collapseWithSelection()
        } label: {
        ZStack {
        Circle()
        .fill(
        AngularGradient(
        gradient: Gradient(colors: [
        .red, .yellow, .green, .cyan, .blue, .purple, .pink, .red
        ]),
        center: .center
        )
        )
        .frame(width: 15, height: 15)
        Circle()
        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.75)
        .frame(width: 15, height: 15)
        }
        .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.2).combined(with: .opacity))
        .help("Multicor — abrir roda de cores")
        }
        ForEach(DimSwatchPreset.macOSPresets) { preset in
        if visibleCount >= preset.order {
        Button {
        selectedColor = preset.color
        collapseWithSelection()
        } label: {
        ZStack {
        Circle()
        .fill(preset.color.swiftUIColor)
        .frame(width: 15, height: 15)
        .overlay(
        Circle()
        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.75)
        )
        if preset.color.isApproximatelyEqual(to: selectedColor) {
        Circle()
        .strokeBorder(Color.accentColor, lineWidth: 1.8)
        .frame(width: 19, height: 19)
        }
        }
        .frame(width: 19, height: 19)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.2).combined(with: .opacity))
        .help(preset.name)
        }
        }
        } else {
        Button {
        expandSequentially()
        } label: {
        ZStack {
        if isCustomMulticolorSelected {
        Circle()
        .fill(
        AngularGradient(
        gradient: Gradient(colors: [
        .red, .yellow, .green, .cyan, .blue, .purple, .pink, .red
        ]),
        center: .center
        )
        )
        .frame(width: 17, height: 17)
        Circle()
        .fill(selectedColor.swiftUIColor)
        .frame(width: 10, height: 10)
        } else {
        Circle()
        .fill(selectedColor.swiftUIColor)
        .frame(width: 16, height: 16)
        }
        Circle()
        .strokeBorder(Color.primary.opacity(0.32), lineWidth: 1.0)
        .frame(width: 17, height: 17)
        }
        .frame(width: 20, height: 20)
        .scaleEffect(pulseScale)
        }
        .buttonStyle(.plain)
        .help("Escolher cor da tinta")
        }
        }
        .frame(height: 20)
        .opacity(isEnabled ? 1.0 : 0.45)
        .disabled(!isEnabled)
        }
        private func expandSequentially() {
        visibleCount = 0
        isExpanded = true
        for step in 1...totalItems {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.024) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
        visibleCount = step
        }
        }
        }
        }
        private func collapseWithSelection() {
        for step in (0..<totalItems).reversed() {
        let delay = Double(totalItems - 1 - step) * 0.020
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        withAnimation(.easeInOut(duration: 0.14)) {
        visibleCount = step
        }
        }
        }
        let totalCollapseTime = Double(totalItems) * 0.020 + 0.06
        DispatchQueue.main.asyncAfter(deadline: .now() + totalCollapseTime) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
        isExpanded = false
        pulseScale = 1.25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
        pulseScale = 1.0
        }
        }
        }
        }
        }
        struct MonitorIconView: View {
        @ObservedObject var state: OverlayState
        private var isDeepActive: Bool {
        state.isEnabled && state.selectedMode == .deep
        }
        private var isAmbientActive: Bool {
        state.isEnabled && state.selectedMode == .ambient
        }
        var body: some View {
        VStack(spacing: 1.5) {
        ZStack {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
        .stroke(
        Color.primary.opacity(
        isDeepActive ? 0.28 : (isAmbientActive ? 0.18 : 0.0)
        ),
        lineWidth: 2.0
        )
        .frame(width: 17.2, height: 11.8)
        .blur(radius: 1.3)
        .opacity(state.isEnabled ? 1.0 : 0.0)
        ZStack {
        if isDeepActive {
        RoundedRectangle(cornerRadius: 2.0, style: .continuous)
        .fill(
        RadialGradient(
        colors: [
        Color.primary.opacity(0.90),
        Color.primary.opacity(0.72),
        Color.primary.opacity(0.25)
        ],
        center: .center,
        startRadius: 1.0,
        endRadius: 8.5
        )
        )
        .blur(radius: 0.3)
        } else if isAmbientActive {
        LinearGradient(
        stops: [
        .init(color: Color.primary.opacity(0.0), location: 0.0),
        .init(color: Color.primary.opacity(0.05), location: 0.36),
        .init(color: Color.primary.opacity(0.52), location: 0.56),
        .init(color: Color.primary.opacity(0.88), location: 0.85),
        .init(color: Color.primary.opacity(0.94), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
        )
        .blur(radius: 0.45)
        }
        }
        .frame(width: 13.6, height: 8.4)
        .clipShape(RoundedRectangle(cornerRadius: 2.0, style: .continuous))
        .opacity(state.isEnabled ? 1.0 : 0.0)
        RoundedRectangle(cornerRadius: 3.2, style: .continuous)
        .strokeBorder(
        Color.primary.opacity(state.isEnabled ? 0.88 : 0.55),
        lineWidth: 1.2
        )
        .frame(width: 16.5, height: 11.0)
        }
        Capsule()
        .fill(Color.primary.opacity(state.isEnabled ? 0.85 : 0.52))
        .frame(width: 6.5, height: 1.15)
        }
        .animation(.easeInOut(duration: 0.22), value: state.isEnabled)
        .animation(.easeInOut(duration: 0.22), value: state.selectedMode)
        }
        }
        class AppDelegate: NSObject, NSApplicationDelegate {
        var statusItem: NSStatusItem!
        var popover: NSPopover!
        var overlayWindows: [BackdropOverlayWindow] = []
        var state = OverlayState()
        var timer: Timer?
        var hotKeyRef: EventHotKeyRef?
        var eventHandlerInstalled = false
        var lastOrderedWindowNumber: Int = -1
        var localEventMonitor: Any?
        var shortcutRecorderMonitor: Any?
        private var lastMouseX: CGFloat = 0
        private var lastDirection: Int = 0
        private var accumulatedStroke: CGFloat = 0
        private var reversalTimestamps: [TimeInterval] = []
        private var lastShakeToggleTime: TimeInterval = 0
        func applicationDidFinishLaunching(_ notification: Notification) {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
        if app.processIdentifier != currentPID &&
        (app.localizedName == "FocusOverlay" || app.bundleIdentifier == Bundle.main.bundleIdentifier) {
        app.forceTerminate()
        }
        }
        state.onUpdate = { [weak self] isPowerToggle, isModeTransition in
        self?.refreshOverlays(isPowerToggle: isPowerToggle, isModeTransition: isModeTransition)
        }
        state.onThemeChange = { [weak self] in
        self?.applyPopoverAppearance()
        }
        state.onShortcutChange = { [weak self] in
        self?.registerGlobalShortcut()
        }
        setupPopover()
        setupMenuBar()
        setupOverlays()
        startTrackingActiveWindow()
        registerGlobalShortcut()
        setupMouseShakeDetector()
        setupShortcutRecorderMonitor()
        NotificationCenter.default.addObserver(
        self,
        selector: #selector(screensChanged),
        name: NSApplication.didChangeScreenParametersNotification,
        object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(activeAppChanged),
        name: NSWorkspace.didActivateApplicationNotification,
        object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(accessibilityDisplayChanged),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
        )
        }
        func setupShortcutRecorderMonitor() {
        shortcutRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
        guard let self = self, self.state.isRecordingShortcut else { return event }
        if event.keyCode == 53 {
        DispatchQueue.main.async {
        self.state.isRecordingShortcut = false
        }
        return nil
        }
        if let newShortcut = KeyboardShortcutConfig.from(event: event) {
        DispatchQueue.main.async {
        self.state.shortcut = newShortcut
        self.state.isRecordingShortcut = false
        }
        return nil
        }
        return nil
        }
        }
        func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
        rootView: ControlPanelView(state: state, onQuit: {
        NSApplication.shared.terminate(nil)
        })
        )
        applyPopoverAppearance()
        }
        @objc func accessibilityDisplayChanged() {
        applyPopoverAppearance()
        }
        func applyPopoverAppearance() {
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let targetAppearance: NSAppearance?
        switch state.theme {
        case .system:
        targetAppearance = nil
        case .light:
        targetAppearance = NSAppearance(named: .aqua)
        case .dark:
        targetAppearance = NSAppearance(named: .darkAqua)
        }
        popover.appearance = targetAppearance
        if let popoverWindow = popover.contentViewController?.view.window {
        popoverWindow.appearance = targetAppearance
        popoverWindow.isOpaque = reduceTransparency
        }
        }
        func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
        button.title = ""
        button.image = nil
        button.action = #selector(togglePopover(_:))
        button.target = self
        let hostingView = NSHostingView(rootView: MonitorIconView(state: state).frame(width: 28, height: 22))
        hostingView.frame = NSRect(x: 0, y: 0, width: 28, height: 22)
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)
        }
        }
        @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
        state.isRecordingShortcut = false
        popover.performClose(sender)
        } else {
        applyPopoverAppearance()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        applyPopoverAppearance()
        popover.contentViewController?.view.window?.makeKey()
        }
        }
        func setupMouseShakeDetector() {
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
        self?.processMouseMovement()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
        self?.processMouseMovement()
        return event
        }
        }
        private func processMouseMovement() {
        guard state.shakeEnabled else { return }
        let currentX = NSEvent.mouseLocation.x
        let deltaX = currentX - lastMouseX
        lastMouseX = currentX
        guard abs(deltaX) > 1.0 else { return }
        let s = state.shakeSensitivity
        let requiredStroke: CGFloat = CGFloat(165.0 - (s * 145.0))
        let requiredReversals: Int = max(2, Int(round(5.0 - (s * 3.0))))
        let timeWindow: TimeInterval = 0.65
        let direction = deltaX > 0 ? 1 : -1
        if direction == lastDirection || lastDirection == 0 {
        accumulatedStroke += abs(deltaX)
        lastDirection = direction
        } else {
        if accumulatedStroke >= requiredStroke {
        let now = Date().timeIntervalSince1970
        reversalTimestamps.append(now)
        reversalTimestamps = reversalTimestamps.filter { now - $0 <= timeWindow }
        if reversalTimestamps.count >= requiredReversals && (now - lastShakeToggleTime) > 1.0 {
        reversalTimestamps.removeAll()
        lastShakeToggleTime = now
        DispatchQueue.main.async {
        self.state.isEnabled.toggle()
        }
        }
        }
        accumulatedStroke = abs(deltaX)
        lastDirection = direction
        }
        }
        @objc func screensChanged() {
        lastOrderedWindowNumber = -1
        setupOverlays()
        }
        @objc func activeAppChanged() {
        updateOverlayOrderAndWindowFrame()
        }
        func setupOverlays() {
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        for screen in NSScreen.screens {
        let window = BackdropOverlayWindow(screen: screen)
        overlayWindows.append(window)
        }
        refreshOverlays(isPowerToggle: false, isModeTransition: false)
        }
        func refreshOverlays(isPowerToggle: Bool, isModeTransition: Bool) {
        if isPowerToggle && state.isEnabled {
        positionOverlaysBelowActiveWindow()
        }
        for overlay in overlayWindows {
        overlay.apply(state: state, animated: isPowerToggle, isModeTransition: isModeTransition)
        }
        }
        func startTrackingActiveWindow() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in
        self?.updateOverlayOrderAndWindowFrame()
        }
        }
        private func findTopmostTargetWindow() -> (windowNumber: Int, cgRect: CGRect)? {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let frontPID = frontPID, frontPID != myPID {
        for windowInfo in windowList {
        if let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
        pid == frontPID,
        let layer = windowInfo[kCGWindowLayer as String] as? Int,
        layer == 0,
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat,
        alpha > 0.1,
        let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
        let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0
        if width >= 160 && height >= 160 {
        let rect = CGRect(x: boundsDict["X"] ?? 0, y: boundsDict["Y"] ?? 0, width: width, height: height)
        return (windowNumber, rect)
        }
        }
        }
        }
        for windowInfo in windowList {
        if let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
        pid != myPID,
        let layer = windowInfo[kCGWindowLayer as String] as? Int,
        layer == 0,
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat,
        alpha > 0.1,
        let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
        let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0
        if width >= 160 && height >= 160 {
        let rect = CGRect(x: boundsDict["X"] ?? 0, y: boundsDict["Y"] ?? 0, width: width, height: height)
        return (windowNumber, rect)
        }
        }
        }
        return nil
        }
        private func positionOverlaysBelowActiveWindow() {
        guard let target = findTopmostTargetWindow() else { return }
        lastOrderedWindowNumber = target.windowNumber
        for overlay in overlayWindows {
        overlay.snapBelowWindow(windowNumber: target.windowNumber, cgRect: target.cgRect, state: state)
        }
        }
        func updateOverlayOrderAndWindowFrame() {
        guard state.isEnabled else { return }
        guard let target = findTopmostTargetWindow() else { return }
        if target.windowNumber != lastOrderedWindowNumber {
        let isFirstOrder = (lastOrderedWindowNumber == -1)
        lastOrderedWindowNumber = target.windowNumber
        let duration = isFirstOrder ? 0.0 : (state.transitionMs / 1000.0)
        for overlay in overlayWindows {
        overlay.transitionToWindow(windowNumber: target.windowNumber, cgRect: target.cgRect, state: state, duration: duration)
        }
        } else {
        for overlay in overlayWindows {
        overlay.updateActiveWindowBounds(target.cgRect, state: state)
        }
        }
        }
        func registerGlobalShortcut() {
        if let existingRef = hotKeyRef {
        UnregisterEventHotKey(existingRef)
        hotKeyRef = nil
        }
        if !eventHandlerInstalled {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData -> OSStatus in
        if let userData = userData {
        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
        if !appDelegate.state.isRecordingShortcut {
        appDelegate.state.isEnabled.toggle()
        }
        }
        }
        return noErr
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, nil)
        eventHandlerInstalled = true
        }
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4353)
        hotKeyID.id = 1
        RegisterEventHotKey(
        state.shortcut.keyCode,
        state.shortcut.carbonModifiers,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
        )
        }
        }
        struct SectionCard<Content: View>: View {
        let content: () -> Content
        init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        }
        var body: some View {
        VStack(alignment: .leading, spacing: 8) {
        content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(0.045))
        )
        .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75)
        )
        }
        }
        struct ControlPanelView: View {
        @ObservedObject var state: OverlayState
        var onQuit: () -> Void
        @State private var isAdjustingTransition = false
        @State private var shrinkWorkItem: DispatchWorkItem?
        private var formattedMs: String {
        String(format: "%.0f ms", state.transitionMs)
        }
        private var lastCheckedText: String {
        guard let date = state.lastUpdateCheck else {
        return "Update Checked: nunca"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return "Update Checked: " + relative
        }
        var body: some View {
        VStack(spacing: 10) {
        HStack(spacing: 8) {
        MonitorIconView(state: state)
        .frame(width: 22, height: 18)
        Text("FocusOverlay")
        .font(.headline)
        Spacer()
        Toggle("", isOn: $state.isEnabled)
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
        }
        .padding(.horizontal, 2)
        SectionCard {
        HStack {
        Label("Modo de Foco", systemImage: "sparkles")
        .font(.subheadline.weight(.medium))
        .foregroundColor(.secondary)
        Spacer()
        Button {
        state.resetCurrentModeToFactory()
        } label: {
        HStack(spacing: 3) {
        Image(systemName: "arrow.counterclockwise")
        Text("Reset")
        }
        .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundColor(state.isCurrentModeModified ? .accentColor : .secondary.opacity(0.4))
        .disabled(!state.isEnabled || !state.isCurrentModeModified)
        .help("Restaurar padrão de fábrica")
        }
        HStack(spacing: 8) {
        Button {
        state.switchMode(to: .ambient)
        } label: {
        HStack(spacing: 5) {
        Image(systemName: "sun.haze.fill")
        Text("Ambiente")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .tint(state.selectedMode == .ambient ? .accentColor : Color.primary.opacity(0.08))
        .foregroundColor(state.selectedMode == .ambient ? .white : .primary)
        Button {
        state.switchMode(to: .deep)
        } label: {
        HStack(spacing: 5) {
        Image(systemName: "moon.stars.fill")
        Text("Deep")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .tint(state.selectedMode == .deep ? .accentColor : Color.primary.opacity(0.08))
        .foregroundColor(state.selectedMode == .deep ? .white : .primary)
        }
        .disabled(!state.isEnabled)
        }
        SectionCard {
        VStack(alignment: .leading, spacing: 3) {
        Label("Desfoque Óptico", systemImage: "camera.aperture")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Slider(value: $state.blurRadius, in: 0.0...120.0)
        .controlSize(.small)
        .disabled(!state.isEnabled)
        }
        VStack(alignment: .leading, spacing: 3) {
        Label("Granulação", systemImage: "aqi.low")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Slider(value: $state.grainAmount, in: 0.0...1.0)
        .controlSize(.small)
        .disabled(!state.isEnabled)
        }
        VStack(alignment: .leading, spacing: 5) {
        Label("Gradiente", systemImage: "circle.dashed")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Slider(value: $state.gradientAmount, in: 0.0...1.0)
        .controlSize(.small)
        .disabled(!state.isEnabled)
        HStack {
        Toggle("Bordas da Janela", isOn: $state.windowBordersMode)
        .font(.subheadline)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .disabled(!state.isEnabled)
        Spacer()
        }
        if state.windowBordersMode {
        Toggle("Inverter direção do gradiente", isOn: $state.invertGradient)
        .font(.subheadline)
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .disabled(!state.isEnabled || state.gradientAmount <= 0.02)
        .transition(.opacity.combined(with: .move(edge: .top)))
        }
        }
        .animation(.easeInOut(duration: 0.18), value: state.windowBordersMode)
        VStack(alignment: .leading, spacing: 6) {
        HStack {
        Label("Tinta", systemImage: "drop.fill")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Spacer()
        MacOSCollapsibleColorPicker(
        selectedColor: $state.dimColor,
        isEnabled: state.isEnabled
        )
        }
        Slider(value: $state.dimAmount, in: 0.0...0.95)
        .controlSize(.small)
        .disabled(!state.isEnabled)
        }
        }
        SectionCard {
        VStack(alignment: .leading, spacing: 3) {
        Label("Tempo de Transição", systemImage: "timer")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Slider(value: $state.transitionMs, in: 0.0...2000.0, step: 25.0)
        .controlSize(.small)
        .onChange(of: state.transitionMs) { _, _ in
        triggerPillExpansion()
        }
        GeometryReader { geo in
        let ratio = CGFloat(state.transitionMs / 2000.0)
        let thumbPadding: CGFloat = 8
        let usableWidth = max(1, geo.size.width - (thumbPadding * 2))
        let xCenter = thumbPadding + (ratio * usableWidth)
        Text(formattedMs)
        .font(.caption2.monospacedDigit().weight(isAdjustingTransition ? .semibold : .regular))
        .padding(.horizontal, isAdjustingTransition ? 8 : 6)
        .padding(.vertical, isAdjustingTransition ? 3 : 2)
        .background(
        Capsule()
        .fill(isAdjustingTransition ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
        )
        .foregroundColor(isAdjustingTransition ? .accentColor : .secondary)
        .scaleEffect(isAdjustingTransition ? 1.15 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isAdjustingTransition)
        .position(x: xCenter, y: 11)
        }
        .frame(height: 22)
        }
        Divider().opacity(0.5)
        VStack(alignment: .leading, spacing: 5) {
        HStack {
        Label("Sacudir Mouse", systemImage: "cursorarrow.motionlines")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Spacer()
        Toggle("", isOn: $state.shakeEnabled)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
        }
        if state.shakeEnabled {
        HStack(spacing: 8) {
        Text("Sensibilidade")
        .font(.caption)
        .foregroundColor(.secondary)
        Slider(value: $state.shakeSensitivity, in: 0.05...1.0)
        .controlSize(.mini)
        }
        .transition(.opacity)
        }
        }
        .animation(.easeInOut(duration: 0.18), value: state.shakeEnabled)
        }
        SectionCard {
        HStack {
        Label("Aparência", systemImage: "circle.lefthalf.filled")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Spacer()
        Picker("", selection: $state.theme) {
        ForEach(AppTheme.allCases) { item in
        Text(item.rawValue).tag(item)
        }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 165)
        }
        HStack {
        Label("Iniciar com Login", systemImage: "power")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Spacer()
        Toggle("", isOn: $state.launchAtLogin)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
        }
        Divider().opacity(0.5)
        VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
        Label("Atualização", systemImage: "arrow.triangle.2.circlepath")
        .font(.subheadline)
        .foregroundColor(.secondary)
        Text("v" + state.currentVersion)
        .font(.caption2.monospacedDigit())
        .fixedSize()
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .background(Color.primary.opacity(0.08))
        .clipShape(Capsule())
        .foregroundColor(.secondary)
        Spacer()
        Button {
        state.checkForUpdates()
        } label: {
        if state.isCheckingUpdate {
        ProgressView()
        .controlSize(.small)
        } else {
        Text("Check Updates")
        .font(.caption)
        }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(state.isCheckingUpdate)
        }
        HStack {
        Text(lastCheckedText)
        .font(.caption2)
        .foregroundColor(.secondary)
        Spacer()
        if let msg = state.updateStatusMessage {
        Text(msg)
        .font(.caption2)
        .foregroundColor(.accentColor)
        }
        }
        }
        }
        HStack(spacing: 6) {
        Text("Atalho:")
        .font(.caption)
        .foregroundColor(.secondary)
        Button {
        state.isRecordingShortcut.toggle()
        } label: {
        Text(state.isRecordingShortcut ? "Pressione teclas..." : state.shortcut.displayString)
        .font(.caption.monospacedDigit().weight(.medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
        Capsule()
        .fill(state.isRecordingShortcut ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
        )
        .overlay(
        Capsule()
        .strokeBorder(state.isRecordingShortcut ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .foregroundColor(state.isRecordingShortcut ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help("Clique para gravar um novo atalho de teclado")
        Spacer()
        Button("Sair") {
        onQuit()
        }
        .buttonStyle(.borderless)
        .font(.subheadline)
        .foregroundColor(.red)
        }
        .padding(.horizontal, 4)
        }
        .padding(14)
        .frame(width: 326)
        .background(
        Group {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
        Color(nsColor: .windowBackgroundColor)
        } else {
        Color.clear
        }
        }
        )
        }
        private func triggerPillExpansion() {
        shrinkWorkItem?.cancel()
        isAdjustingTransition = true
        let task = DispatchWorkItem {
        isAdjustingTransition = false
        }
        shrinkWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: task)
        }
        }
        class BackdropOverlayWindow: NSWindow {
        private var backdropLayer: CALayer!
        private var blurFilter: NSObject!
        private var backdropMaskLayer: CAGradientLayer!
        private var grainLayer: CALayer!
        private var grainMaskLayer: CAGradientLayer!
        private var dimLayer: CALayer!
        private var dimMaskLayer: CAGradientLayer!
        private let targetScreen: NSScreen
        private var smoothedWindowRect: CGRect = .zero
        private var targetWindowRect: CGRect = .zero
        private var currentBlurRadius: Double = 62.13
        private var currentGrainAmount: Double = 0.11
        private var currentGradientAmount: Double = 0.0
        private var currentDimAmount: Double = 0.30
        private var currentDimColor: RGBAColor = .black
        private var modeTransitionTimer: Timer?
        init(screen: NSScreen) {
        self.targetScreen = screen
        super.init(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
        )
        self.isOpaque = false
        self.backgroundColor = NSColor.white.withAlphaComponent(0.001)
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setupBackdropLayers()
        }
        private func makeConfiguredGradientLayer(bounds: CGRect) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.frame = bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.actions = [
        "colors": NSNull(),
        "locations": NSNull(),
        "startPoint": NSNull(),
        "endPoint": NSNull(),
        "type": NSNull(),
        "bounds": NSNull(),
        "position": NSNull()
        ]
        return layer
        }
        private func setupBackdropLayers() {
        guard let contentView = self.contentView else { return }
        contentView.wantsLayer = true
        guard let rootLayer = contentView.layer else { return }
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
        backdropLayer = backdropClass.init()
        } else {
        backdropLayer = CALayer()
        }
        backdropLayer.frame = rootLayer.bounds
        backdropLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        backdropLayer.setValue(true, forKey: "windowServerAware")
        backdropLayer.setValue(0.25, forKey: "scale")
        backdropLayer.setValue(200.0, forKey: "marginWidth")
        if let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
        let filter = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?.takeUnretainedValue() as? NSObject {
        filter.setValue(62.13, forKey: "inputRadius")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        self.blurFilter = filter
        backdropLayer.filters = [filter]
        }
        backdropMaskLayer = makeConfiguredGradientLayer(bounds: rootLayer.bounds)
        backdropLayer.mask = backdropMaskLayer
        rootLayer.addSublayer(backdropLayer)
        grainLayer = CALayer()
        grainLayer.frame = rootLayer.bounds
        grainLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        grainLayer.actions = ["opacity": NSNull()]
        if let noiseImage = createGrainPatternImage() {
        grainLayer.backgroundColor = NSColor(patternImage: noiseImage).cgColor
        }
        grainLayer.opacity = 0.0
        grainMaskLayer = makeConfiguredGradientLayer(bounds: rootLayer.bounds)
        grainLayer.mask = grainMaskLayer
        rootLayer.addSublayer(grainLayer)
        dimLayer = CALayer()
        dimLayer.frame = rootLayer.bounds
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dimLayer.actions = ["opacity": NSNull(), "backgroundColor": NSNull()]
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.opacity = 0.0
        dimMaskLayer = makeConfiguredGradientLayer(bounds: rootLayer.bounds)
        dimLayer.mask = dimMaskLayer
        rootLayer.addSublayer(dimLayer)
        }
        private func createGrainPatternImage() -> NSImage? {
        let size = 128
        let pixelCount = size * size
        var pixels = [UInt8](repeating: 0, count: pixelCount * 4)
        for i in 0..<pixelCount {
        let noise = UInt8.random(in: 0...255)
        let alpha = UInt8.random(in: 10...45)
        let offset = i * 4
        pixels[offset] = noise
        pixels[offset + 1] = noise
        pixels[offset + 2] = noise
        pixels[offset + 3] = alpha
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
        let cgImage = CGImage(
        width: size,
        height: size,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
        ) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        }
        func snapBelowWindow(windowNumber: Int, cgRect: CGRect, state: OverlayState) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? targetScreen.frame.height
        let cocoaY = primaryHeight - cgRect.origin.y - cgRect.height
        let cocoaRect = CGRect(x: cgRect.origin.x, y: cocoaY, width: cgRect.width, height: cgRect.height)
        self.targetWindowRect = cocoaRect
        self.smoothedWindowRect = cocoaRect
        self.order(.below, relativeTo: windowNumber)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateGradientMask(state: state, gradientOverride: currentGradientAmount)
        CATransaction.commit()
        }
        private func renderImmediateValues(
        blur: Double,
        grain: Double,
        gradient: Double,
        dim: Double,
        color: RGBAColor,
        state: OverlayState
        ) {
        currentBlurRadius = blur
        currentGrainAmount = grain
        currentGradientAmount = gradient
        currentDimAmount = dim
        currentDimColor = color
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let effectiveRadius = blur * 1.4
        blurFilter?.setValue(effectiveRadius, forKey: "inputRadius")
        backdropLayer.setValue(effectiveRadius, forKeyPath: "filters.gaussianBlur.inputRadius")
        grainLayer.opacity = Float(grain * 0.85)
        dimLayer.backgroundColor = color.nsColor.cgColor
        dimLayer.opacity = Float(dim)
        updateGradientMask(state: state, gradientOverride: gradient)
        CATransaction.commit()
        }
        func apply(state: OverlayState, animated: Bool, isModeTransition: Bool = false) {
        let duration = state.transitionMs / 1000.0
        modeTransitionTimer?.invalidate()
        modeTransitionTimer = nil
        if state.isEnabled && !self.isVisible {
        self.alphaValue = 0
        self.orderFrontRegardless()
        }
        if isModeTransition && state.isEnabled && duration > 0.03 {
        let startBlur = currentBlurRadius
        let startGrain = currentGrainAmount
        let startGradient = currentGradientAmount
        let startDim = currentDimAmount
        let startColor = currentDimColor
        let endBlur = state.blurRadius
        let endGrain = state.grainAmount
        let endGradient = state.gradientAmount
        let endDim = state.dimAmount
        let endColor = state.dimColor
        let startTime = CACurrentMediaTime()
        modeTransitionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
        guard let self = self else {
        timer.invalidate()
        return
        }
        let elapsed = CACurrentMediaTime() - startTime
        let rawProgress = min(1.0, max(0.0, elapsed / duration))
        let t = rawProgress < 0.5
        ? 2.0 * rawProgress * rawProgress
        : 1.0 - pow(-2.0 * rawProgress + 2.0, 2.0) / 2.0
        let interpBlur = startBlur + (endBlur - startBlur) * t
        let interpGrain = startGrain + (endGrain - startGrain) * t
        let interpGradient = startGradient + (endGradient - startGradient) * t
        let interpDim = startDim + (endDim - startDim) * t
        let interpColor = RGBAColor.lerp(from: startColor, to: endColor, t: t)
        self.renderImmediateValues(
        blur: interpBlur,
        grain: interpGrain,
        gradient: interpGradient,
        dim: interpDim,
        color: interpColor,
        state: state
        )
        if rawProgress >= 1.0 {
        timer.invalidate()
        self.modeTransitionTimer = nil
        }
        }
        return
        }
        renderImmediateValues(
        blur: state.blurRadius,
        grain: state.grainAmount,
        gradient: state.gradientAmount,
        dim: state.dimAmount,
        color: state.dimColor,
        state: state
        )
        let targetAlpha: CGFloat = state.isEnabled ? 1.0 : 0.0
        if animated && duration > 0.01 {
        NSAnimationContext.runAnimationGroup({ context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.animator().alphaValue = targetAlpha
        }, completionHandler: {
        if !state.isEnabled {
        self.orderOut(nil)
        }
        })
        } else {
        self.alphaValue = targetAlpha
        if !state.isEnabled {
        self.orderOut(nil)
        }
        }
        }
        func transitionToWindow(windowNumber: Int, cgRect: CGRect, state: OverlayState, duration: TimeInterval) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? targetScreen.frame.height
        let cocoaY = primaryHeight - cgRect.origin.y - cgRect.height
        let cocoaRect = CGRect(x: cgRect.origin.x, y: cocoaY, width: cgRect.width, height: cgRect.height)
        self.order(.below, relativeTo: windowNumber)
        self.targetWindowRect = cocoaRect
        if self.smoothedWindowRect == .zero {
        self.smoothedWindowRect = cocoaRect
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateGradientMask(state: state, gradientOverride: currentGradientAmount)
        CATransaction.commit()
        if duration > 0.05 && state.isEnabled {
        self.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup({ context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.animator().alphaValue = 1.0
        })
        }
        }
        func updateActiveWindowBounds(_ cgRect: CGRect, state: OverlayState) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? targetScreen.frame.height
        let cocoaY = primaryHeight - cgRect.origin.y - cgRect.height
        targetWindowRect = CGRect(x: cgRect.origin.x, y: cocoaY, width: cgRect.width, height: cgRect.height)
        if smoothedWindowRect == .zero {
        smoothedWindowRect = targetWindowRect
        }
        let ease: CGFloat = 0.14
        let dx = targetWindowRect.origin.x - smoothedWindowRect.origin.x
        let dy = targetWindowRect.origin.y - smoothedWindowRect.origin.y
        let dw = targetWindowRect.width - smoothedWindowRect.width
        let dh = targetWindowRect.height - smoothedWindowRect.height
        if abs(dx) > 0.2 || abs(dy) > 0.2 || abs(dw) > 0.2 || abs(dh) > 0.2 {
        smoothedWindowRect = CGRect(
        x: smoothedWindowRect.origin.x + dx * ease,
        y: smoothedWindowRect.origin.y + dy * ease,
        width: smoothedWindowRect.width + dw * ease,
        height: smoothedWindowRect.height + dh * ease
        )
        if state.windowBordersMode {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateGradientMask(state: state, gradientOverride: currentGradientAmount)
        CATransaction.commit()
        }
        }
        }
        private func syncNativeGradient(_ layer: CAGradientLayer, state: OverlayState, gradientValue: Double) {
        let g = CGFloat(gradientValue)
        if !state.windowBordersMode {
        layer.type = .axial
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        let topAlpha = max(0.0, 1.0 - (g * 1.15))
        layer.colors = [
        NSColor.black.cgColor,
        NSColor.black.cgColor,
        NSColor.black.withAlphaComponent(topAlpha).cgColor
        ]
        layer.locations = [0.0, 0.50, 0.94]
        return
        }
        layer.type = .radial
        if g <= 0.01 {
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        let solidAlpha: CGFloat = state.invertGradient ? 0.0 : 1.0
        layer.colors = [
        NSColor.black.withAlphaComponent(solidAlpha).cgColor,
        NSColor.black.withAlphaComponent(solidAlpha).cgColor
        ]
        layer.locations = [0.0, 1.0]
        return
        }
        let subtleG = min(1.0, pow(g, 0.85))
        let lowAlpha = max(0.0, 1.0 - subtleG)
        let highAlpha: CGFloat = 1.0
        let innerAlpha = state.invertGradient ? highAlpha : lowAlpha
        let outerAlpha = state.invertGradient ? lowAlpha : highAlpha
        let midLow = innerAlpha + (outerAlpha - innerAlpha) * 0.22
        let midHigh = innerAlpha + (outerAlpha - innerAlpha) * 0.68
        let cInner = NSColor.black.withAlphaComponent(innerAlpha).cgColor
        let cMidLow = NSColor.black.withAlphaComponent(midLow).cgColor
        let cMidHigh = NSColor.black.withAlphaComponent(midHigh).cgColor
        let cOuter = NSColor.black.withAlphaComponent(outerAlpha).cgColor
        layer.colors = [cInner, cInner, cMidLow, cMidHigh, cOuter, cOuter]
        let activeRect = (smoothedWindowRect == .zero) ? targetScreen.frame.insetBy(dx: 200, dy: 150) : smoothedWindowRect
        let normX = (activeRect.midX - targetScreen.frame.origin.x) / targetScreen.frame.width
        let normY = (activeRect.midY - targetScreen.frame.origin.y) / targetScreen.frame.height
        let auraScale = 0.72 + (0.42 * g)
        let radiusX = max(0.20, (activeRect.width / targetScreen.frame.width) * auraScale)
        let radiusY = max(0.20, (activeRect.height / targetScreen.frame.height) * auraScale)
        layer.startPoint = CGPoint(x: normX, y: normY)
        layer.endPoint = CGPoint(x: normX + radiusX, y: normY + radiusY)
        layer.locations = [0.0, 0.48, 0.68, 0.85, 0.97, 1.0]
        }
        private func updateGradientMask(state: OverlayState, gradientOverride: Double) {
        syncNativeGradient(backdropMaskLayer, state: state, gradientValue: gradientOverride)
        syncNativeGradient(grainMaskLayer, state: state, gradientValue: gradientOverride)
        syncNativeGradient(dimMaskLayer, state: state, gradientValue: gradientOverride)
        }
        }
