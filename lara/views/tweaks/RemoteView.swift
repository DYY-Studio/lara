//
//  RemoteView.swift
//  lara
//
//  Created by ruter on 17.04.26.
//

import SwiftUI
import Darwin

struct RemoteView: View {
    @ObservedObject var mgr: laramgr
    @State private var statusBarTimeFormat: String = "HH:mm"
    @State private var running: Bool = false
    @State private var columns: Int = 5
    @State private var performanceHUD: Int = -1
    @AppStorage("rcdockunlimited") private var rcdockunlimited: Bool = false
    @State private var customProcessName: String = "SpringBoard"
    @State private var customFunctionName: String = "getpid"
    @State private var customArgsText: String = ""
    @State private var customTimeoutMs: Int = 100
    @State private var customMigBypass: Bool = false
    @State private var customLastResult: String = ""
    @State private var hsRows: Int = 6
    @State private var hsColumns: Int = 4
    @State private var freakyrunning: Bool = false
    @State private var freakyseq: Int = 0

    private var dockMaxColumns: Int { rcdockunlimited ? 50 : 10 }

    var body: some View {
        List {
            Section {
                TextField("Date format (e.g. HH:mm)", text: $statusBarTimeFormat)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    run("Status Bar Time Format") {
                        status_bar_time_format(mgr.sbProc, statusBarTimeFormat)
                        return "status_bar_time_format() done"
                    }
                } label: {
                    Text("Apply")
                }
            } header: {
                Text("Status Bar Time Format")
            } footer: {
                Text("The text automatically updates every MINUTE")
            }

            Section {
                Button {
                    run("Hide Icon Labels") {
                        let hidden = hide_icon_labels(mgr.sbProc)
                        return "hide_icon_labels() -> \(hidden)"
                    }
                } label: {
                    Text("Hide Icon Labels")
                }
            } header: {
                Text("SpringBoard")
            }

            Section {
                Stepper(value: $hsColumns, in: 1...10) {
                    HStack {
                        Text("Home screen columns")
                        Spacer()
                        Text("\(hsColumns)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Stepper(value: $hsRows, in: 1...10) {
                    HStack {
                        Text("Home screen rows")
                        Spacer()
                        Text("\(hsRows)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    run("Patch Home Screen Grid \(hsColumns)x\(hsRows)") {
                        return patch_homescreen_grid(mgr.sbProc, Int32(hsColumns), Int32(hsRows))
                            ? "patch_homescreen_grid(\(hsColumns), \(hsRows)) -> ok"
                            : "patch_homescreen_grid(\(hsColumns), \(hsRows)) -> failed"
                    }
                } label: {
                    Text("Apply Home Screen Grid")
                }
            }

            Section {
                Stepper(value: $columns, in: 1...dockMaxColumns) {
                    HStack {
                        Text("Dock columns")
                        Spacer()
                        Text("\(columns)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: rcdockunlimited) { _ in
                    if !rcdockunlimited, columns > 10 {
                        columns = 10
                    }
                }

                Button {
                    run("Apply Dock Columns=\(columns)") {
                        let result = set_dock_icon_count(mgr.sbProc, Int32(columns))
                        return result == 0
                            ? "set_dock_icon_count(\(columns)) -> ok"
                            : "set_dock_icon_count(\(columns)) -> failed (\(result))"
                    }
                } label: {
                    Text("Apply Dock Columns")
                }
            }

            Section {
                Button {
                    run("Enable Upside Down") {
                        let result = enable_upside_down(mgr.sbProc)
                        return result == 0
                            ? "enable_upside_down() -> ok"
                            : "enable_upside_down() -> failed (\(result))"
                    }
                } label: {
                    Text("Enable Upside Down")
                }
            }

            Section {
                Button {
                    run("Enable Floating Dock") {
                        let result = enable_floating_dock(mgr.sbProc)
                        return result == 0
                            ? "enable_floating_dock() -> ok"
                            : "enable_floating_dock() -> failed (\(result))"
                    }
                } label: {
                    Text("Enable Floating Dock")
                }
                
                Button {
                    run("Enable Grid App Switcher") {
                        let result = enable_grid_app_switcher(mgr.sbProc)
                        return result == 0
                            ? "enable_grid_app_switcher() -> ok"
                            : "enable_grid_app_switcher() -> failed (\(result))"
                    }
                } label: {
                    Text("Enable Grid App Switcher (Broken animation)")
                }
                
                Button {
                    run("Enable UIKit Debug Overlay") {
                        let result = enable_debug_overlay(mgr.sbProc)
                        return result == 0
                            ? "enable_debug_overlay() -> ok"
                            : "enable_debug_overlay() -> failed (\(result))"
                    }
                } label: {
                    Text("Enable UIKit Debug Overlay")
                }

                /*
                Button {
                    togglefreakydog()
                } label: {
                    Text(freakyrunning ? "Stop Freaky Dog Overlay" : "Start Freaky Dog Overlay")
                }
                */
            } footer: {
                Text("To use UIKit Debug Overlay, double tap the status bar.")
            }
            
            Section {
                Picker("Performance HUD", selection: $performanceHUD) {
                    Text("Off").tag(-1)
                    Text("Basic").tag(0)
                    Text("Backdrops").tag(1)
                    Text("Particles").tag(2)
                    Text("Full").tag(3)
                    Text("Power").tag(5)
                    Text("EDR").tag(7)
                    Text("Glitches").tag(8)
                    Text("GPU Time").tag(9)
                    Text("Memory Bandwidth").tag(10)
                }
                .onChange(of: performanceHUD) { newValue in
                    set_performance_hud(mgr.sbProc, Int32(newValue))
                }
                .onAppear {
                    if mgr.rcrunning {
                        performanceHUD = Int(get_performance_hud(mgr.sbProc))
                    }
                }
            } footer: {
                Text("These call into SpringBoard via RemoteCall. Keep RemoteCall initialized while running them.")
                
                if !mgr.rcready {
                    Text("RemoteCall is not initialized. How are you here?")
                }
            }
            .disabled(!mgr.rcready || running)
            
            if #available(iOS 17.4, *) {
                Section {
                    Button {
                        mgr.rcinitDaemon(serviceName: "com.apple.xpc.amsaccountsd", process: "amsaccountsd", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            mgr.eligibilitystate = euenabler_overwrite_eligibility(proc) == 0
                            mgr.logmsg("overwrite_eligibility() returned: \(mgr.eligibilitystate! ? "success" : "failure")")
                            proc.destroy()
                        }
                    } label: {
                        HStack {
                            Text("Overwrite eligibility (one time setup)")
                            if let state = mgr.eligibilitystate {
                                Spacer()
                                if state {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .disabled(mgr.eligibilitystate ?? false)
                    
                    Button {
                        mgr.eu1progress = 0.0
                        mgr.eu2progress = 0.0
                        mgr.eu1running = true
                        mgr.eu2running = true
                        mgr.rcinitDaemon(serviceName: "com.apple.managedappdistributiond.xpc", process: "managedappdistributiond", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                mgr.eu1running = false
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            euenabler_override_country_code(proc) { progress in
                                DispatchQueue.main.async {
                                    self.mgr.eu1progress = progress
                                }
                            }
                            proc.destroy()
                            DispatchQueue.main.async {
                                mgr.eu1running = false
                            }
                        }
                        // fix unable to load app info
                        mgr.rcinitDaemon(serviceName: "com.apple.appstorecomponentsd.xpc", process: "appstorecomponentsd", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                mgr.eu2running = false
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            euenabler_override_country_code(proc) { progress in
                                DispatchQueue.main.async {
                                    self.mgr.eu2progress = progress
                                }
                            }
                            proc.destroy()
                            DispatchQueue.main.async {
                                mgr.eu2running = false
                            }
                        }
                    } label: {
                        HStack {
                            if mgr.eu1running || mgr.eu2running {
                                ProgressView(value: (mgr.eu1progress + mgr.eu2progress)/2)
                                    .progressViewStyle(.circular)
                                    .frame(width: 18, height: 18)
                                Text("Running...")
                                Spacer()
                                Text("\(Int((mgr.eu1progress + mgr.eu2progress)/2 * 100))%")
                            } else {
                                Text("Enable Spoof EU Region")
                                Spacer()
                                if mgr.eu1progress + mgr.eu2progress == 2 {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                } else if mgr.dsattempted && mgr.dsfailed {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .disabled(mgr.eu1running || mgr.eu2running || mgr.eu1progress+mgr.eu2progress == 2)
                } footer: {
                    Text("Enables installing of EU/Japan Marketplace apps.")
                }
                .disabled(isdebugged() || mgr.rcrunning || !mgr.rcready)
            }
            
            Section {
                Button {
                    youtube_tweak(mgr.ytProc)
                } label: {
                    Text("Generic Youtube Tweaks")
                }
            }
            
            Section {
                Button {
                    _ = mgr.rccall(name: "exit", args: [0], timeout: 100)
                } label: {
                    Text("Respring")
                }
            } header: {
                Text("Tools")
            }
            
            Section {
                TextField("Process name", text: $customProcessName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    TextField("Function (symbol or 0xaddr)", text: $customFunctionName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1)
                    
                    TextEditor(text: $customArgsText)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Stepper(value: $customTimeoutMs, in: 10...5000, step: 10) {
                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text("\(customTimeoutMs) ms")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Toggle("MIG filter bypass", isOn: $customMigBypass)

                Button {
                    run("Custom RemoteCall \(customProcessName):\(customFunctionName)") {
                        let process = customProcessName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let function = customFunctionName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !process.isEmpty else { return "custom: missing process name" }
                        guard !function.isEmpty else { return "custom: missing function name" }

                        let (args, parseError) = parseRemoteCallArgs(customArgsText)
                        if let parseError {
                            return "custom: args parse error: \(parseError)"
                        }

                        let ptr: UnsafeMutableRawPointer?
                        if let addr = parseAddress(function) {
                            ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))
                        } else {
                            let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
                            ptr = function.withCString { dlsym(RTLD_DEFAULT, $0) }
                        }

                        guard let ptr else {
                            return "custom: failed to resolve \(function)"
                        }

                        guard let proc = RemoteCall(process: process, useMigFilterBypass: customMigBypass) else {
                            return "custom: RemoteCall init failed for \(process)"
                        }
                        defer { proc.destroy() }

                        var argsCopy = args
                        let ret = function.withCString { (cName: UnsafePointer<CChar>) -> UInt64 in
                            UInt64(argsCopy.withUnsafeMutableBufferPointer { buffer in
                                proc.doStable(
                                    withTimeout: Int32(customTimeoutMs),
                                    functionName: UnsafeMutablePointer(mutating: cName),
                                    functionPointer: ptr,
                                    args: buffer.baseAddress,
                                    argCount: UInt(args.count)
                                )
                            })
                        }

                        let err = proc.lastError ?? ""
                        let suffix = err.isEmpty ? "" : " (err: \(err))"
                        return "custom: \(process) \(function)(\(args.count) args) -> 0x\(String(ret, radix: 16)) / \(ret)\(suffix)"
                    } onComplete: { msg in
                        self.customLastResult = msg
                    }
                } label: {
                    Text("Call")
                }

                if !customLastResult.isEmpty {
                    Text(customLastResult)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Custom RemoteCall")
            } footer: {
                Text("Calls a symbol (via dlsym) or an absolute address. Numeric args are passed as x0-x7 then stack.")
            }
            .disabled(!mgr.rcready || running)

            Section {
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/khanhduytran0.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Duy Tran")
                            .font(.headline)
                        
                        Text("Responsible for most things related to remotecall.")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/khanhduytran0"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
                
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/zeroxjf.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("0xjf")
                            .font(.headline)
                        
                        Text("Powercuff and SBCustomizer")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/zeroxjf"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
                
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/Scr-eam.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Scream")
                            .font(.headline)
                        
                        Text("Fixed Hide Icon Labels")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/Scr-eam"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Credits")
            }
        }
        .navigationTitle(Text("Tweaks"))
        .onDisappear {
            if freakyrunning, let proc = mgr.sbProc {
                stopfreakydog(proc)
            }
        }
    }

    private func run(_ name: String, _ work: @escaping () -> String, onComplete: ((String) -> Void)? = nil) {
        guard mgr.rcready, !running else { return }
        running = true
        mgr.logmsg("(rc) \(name)...")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async {
                self.mgr.logmsg("(rc) \(result)")
                onComplete?(result)
                if self.isRemoteCallFailure(result) {
                    Alertinator.shared.alert(title: "\(name) Failed", body: result)
                }
                self.running = false
            }
        }
    }

    private func isRemoteCallFailure(_ result: String) -> Bool {
        let lowercased = result.lowercased()
        return lowercased.contains("-> -1") ||
            lowercased.contains("-> failed") ||
            lowercased.contains(": failed") ||
            lowercased.contains("failed to")
    }

    private func togglefreakydog() {
        guard mgr.rcready, let proc = mgr.sbProc else { return }

        if freakyrunning {
            stopfreakydog(proc)
            return
        }

        let view = enable_freaky_dog_overlay(proc)
        guard view != 0 else {
            mgr.logmsg("(rc) enable_freaky_dog_overlay() failed")
            return
        }

        let seq = freakyseq + 1
        freakyseq = seq
        freakyrunning = true
        mgr.logmsg("(rc) enable_freaky_dog_overlay() -> 0x\(String(view, radix: 16))")

        let screen = UIScreen.main.bounds
        let maxw = max(Int(screen.width), 200)
        let maxh = max(Int(screen.height), 300)

        DispatchQueue.global(qos: .userInitiated).async {
            while true {
                let shouldcontinue = DispatchQueue.main.sync { () -> Bool in
                    self.freakyrunning && self.freakyseq == seq && self.mgr.rcready && self.mgr.sbProc != nil
                }
                if !shouldcontinue {
                    break
                }

                let size = Int.random(in: 110...220)
                let x = Int.random(in: 0...max(maxw - size, 0))
                let y = Int.random(in: 40...max(maxh - size, 40))
                let result = move_freaky_dog_overlay(proc, view, Int32(x), Int32(y), Int32(size), Int32(size))
                if result != 0 {
                    DispatchQueue.main.async {
                        self.mgr.logmsg("(rc) move_freaky_dog_overlay() failed: \(result)")
                        self.stopfreakydog(proc)
                    }
                    break
                }

                usleep(UInt32.random(in: 25000...90000))
            }
        }
    }

    private func stopfreakydog(_ proc: RemoteCall) {
        freakyrunning = false
        freakyseq += 1
        let result = disable_freaky_dog_overlay(proc)
        mgr.logmsg("(rc) disable_freaky_dog_overlay() -> \(result)")
    }

    private func parseRemoteCallArgs(_ text: String) -> (args: [UInt64], error: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], nil) }

        let separators = CharacterSet(charactersIn: ", \t\r\n")
        let tokens = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [UInt64] = []
        out.reserveCapacity(tokens.count)

        for token in tokens {
            if let value = parseUInt64OrInt64BitPattern(token) {
                out.append(value)
            } else {
                return ([], "bad token '\(token)'")
            }
        }

        return (out, nil)
    }

    private func parseUInt64OrInt64BitPattern(_ token: String) -> UInt64? {
        if token.hasPrefix("-") {
            let rest = String(token.dropFirst())
            if rest.lowercased().hasPrefix("0x") {
                let hex = String(rest.dropFirst(2))
                guard let magnitude = UInt64(hex, radix: 16) else { return nil }
                let signed = -Int64(bitPattern: magnitude)
                return UInt64(bitPattern: signed)
            } else {
                guard let signed = Int64(rest) else { return nil }
                return UInt64(bitPattern: -signed)
            }
        }

        if token.lowercased().hasPrefix("0x") {
            return UInt64(token.dropFirst(2), radix: 16)
        }

        return UInt64(token)
    }

    private func parseAddress(_ functionField: String) -> UInt64? {
        let s = functionField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("0x") else { return nil }
        guard let value = UInt64(s.dropFirst(2), radix: 16) else { return nil }
        guard value <= UInt64(UInt.max) else { return nil }
        return value
    }
}

private enum RemoteCallLabActionMode: Int {
    case inventoryOnly = 1
    case restoreOnly = 2
    case returnPathProbeOnly = 4

    var title: String {
        switch self {
        case .inventoryOnly:
            return "Inventory"
        case .restoreOnly:
            return "Restore Only"
        case .returnPathProbeOnly:
            return "Return Path Probe"
        }
    }

    var description: String {
        switch self {
        case .inventoryOnly:
            return "Install guards, wait for FIRST_LANDING, log, restore, and exit."
        case .restoreOnly:
            return "Add classification and restore decisions, but do not create a call thread."
        case .returnPathProbeOnly:
            return "Run one pending-exception return-path probe with a selectable entry mode, restore, and exit."
        }
    }
}

private enum RemoteCallReturnPathStrategyOption: Int, CaseIterable {
    case auto = 0
    case objcTrapBRK = 1
    case executableMisalign = 2
    case pacFault = 3

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .objcTrapBRK:
            return "ObjC BRK"
        case .executableMisalign:
            return "Executable Misalign"
        case .pacFault:
            return "PAC Fault"
        }
    }
}

private enum RemoteCallReturnPathEntryModeOption: Int, CaseIterable {
    case retGadget = 0
    case directTarget = 1

    var title: String {
        switch self {
        case .retGadget:
            return "RET Gadget"
        case .directTarget:
            return "Direct Target"
        }
    }
}

struct RemoteCallLabView: View {
    @ObservedObject private var mgr = laramgr.shared
    @AppStorage("lara.rc.lab.maxTestThreads") private var maxTestThreads: Int = 8
    @AppStorage("lara.rc.lab.includeFirstQueueThread") private var includeFirstQueueThread: Bool = false
    @AppStorage("lara.rc.lab.allowReturnPathProbeExperimental") private var allowReturnPathProbeExperimental: Bool = false
    @AppStorage("lara.rc.lab.returnPathProbeStrategy") private var returnPathProbeStrategy: Int = 0
    @AppStorage("lara.rc.lab.returnPathProbeEntryMode") private var returnPathProbeEntryMode: Int = 0
    @AppStorage("lara.rc.lab.ios16.threadCpuDataOffsetOverride") private var threadCpuDataOffsetOverride: String = ""
    @AppStorage("lara.rc.lab.ios16.activeThreadOffsetOverride") private var activeThreadOffsetOverride: String = ""
    @State private var query: String = ""
    @State private var apps: [InstalledUserApp] = []
    @State private var selectedAppID: String?
    @State private var launchRunning: Bool = false

    private var filteredApps: [InstalledUserApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        let lowered = trimmed.lowercased()
        return apps.filter {
            $0.displayName.lowercased().contains(lowered) ||
            $0.bundleID.lowercased().contains(lowered) ||
            $0.executable.lowercased().contains(lowered)
        }
    }

    private var selectedApp: InstalledUserApp? {
        guard let selectedAppID else { return nil }
        return apps.first { $0.id == selectedAppID }
    }

    private var offsetInfo: [AnyHashable: Any] {
        RemoteCall.currentIOS16LabOffsetInfo()
    }

    private var offsetsReady: Bool {
        offsetInfo["ready"] as? Bool ?? false
    }

    var body: some View {
        List {
            statusSection
            targetSection
            offsetsSection
            appSwitchingSection
            armSection
            sessionSummarySection
        }
        .navigationTitle("RemoteCall Lab")
        .onAppear {
            maxTestThreads = min(max(maxTestThreads, 1), 32)
            if RemoteCallReturnPathStrategyOption(rawValue: returnPathProbeStrategy) == nil {
                returnPathProbeStrategy = RemoteCallReturnPathStrategyOption.auto.rawValue
            }
            if RemoteCallReturnPathEntryModeOption(rawValue: returnPathProbeEntryMode) == nil {
                returnPathProbeEntryMode = RemoteCallReturnPathEntryModeOption.retGadget.rawValue
            }
            refreshApps()
            mgr.refreshRemoteCallLabOffsetInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            mgr.refreshRemoteCallLabOffsetInfo()
            if mgr.sbxready && !launchRunning {
                refreshApps()
            }
        }
        .onChange(of: mgr.sbxready) { ready in
            if ready {
                refreshApps()
            } else {
                apps.removeAll()
                selectedAppID = nil
            }
        }
        .onChange(of: threadCpuDataOffsetOverride) { _ in
            mgr.refreshRemoteCallLabOffsetInfo()
        }
        .onChange(of: activeThreadOffsetOverride) { _ in
            mgr.refreshRemoteCallLabOffsetInfo()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section(header: HeaderLabel(text: "Status", icon: "waveform.path.ecg")) {
            if !mgr.dsready {
                Text("Kernel read/write is required before using RemoteCall Lab.")
                    .foregroundColor(.secondary)
            }
            if !mgr.sbxready {
                Text("Sandbox escape is required to enumerate and launch ordinary apps.")
                    .foregroundColor(.secondary)
            }

            Text(mgr.labStatus.isEmpty ? "Idle." : mgr.labStatus)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack {
                Text("Offsets Ready")
                Spacer()
                Image(systemName: offsetsReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(offsetsReady ? .green : .red)
            }

            HStack {
                Text("Lab Session")
                Spacer()
                Text(mgr.labRunning ? "Running" : (mgr.labArmed ? "Armed" : "Idle"))
                    .foregroundColor(mgr.labRunning || mgr.labArmed ? .orange : .secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var targetSection: some View {
        Section(header: HeaderLabel(text: "Target App", icon: "app.badge")) {
            HStack {
                TextField("Search apps", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(action: refreshApps) {
                    Text("Refresh Apps")
                }
                .disabled(!mgr.sbxready || launchRunning || mgr.labRunning)
            }

            if let selectedApp {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedApp.displayName)
                        .font(.headline)
                    Text(selectedApp.bundleID)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(selectedApp.executable)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(filteredApps.isEmpty ? "No installed apps available." : "Select a target app below.")
                    .foregroundColor(.secondary)
            }

            if filteredApps.isEmpty {
                Text(query.isEmpty ? "No apps loaded." : "No matching apps.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredApps) { app in
                    Button {
                        selectedAppID = app.id
                    } label: {
                        RemoteCallLabAppRow(app: app, isSelected: selectedAppID == app.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var offsetsSection: some View {
        Section(
            header: HeaderLabel(text: "Offsets", icon: "cpu"),
            footer: Text(offsetSummaryText)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(offsetDescription(
                    value: offsetInfo["threadCpuDataOffset"],
                    source: offsetInfo["threadCpuDataSource"],
                    label: "thread -> CPUData*"
                ))
                Text(offsetDescription(
                    value: offsetInfo["activeThreadOffset"],
                    source: offsetInfo["activeThreadSource"],
                    label: "CPUData -> active_thread"
                ))
            }
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.secondary)

            TextField("thread -> CPUData* override (hex)", text: $threadCpuDataOffsetOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            TextField("CPUData -> active_thread override (hex)", text: $activeThreadOffsetOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            Stepper(value: $maxTestThreads, in: 1...32) {
                HStack {
                    Text("Max Test Threads")
                    Spacer()
                    Text("\(maxTestThreads)")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Toggle("Include First Queue Thread", isOn: $includeFirstQueueThread)

            Button("Clear Manual Overrides") {
                threadCpuDataOffsetOverride = ""
                activeThreadOffsetOverride = ""
                mgr.refreshRemoteCallLabOffsetInfo()
            }
            .disabled(manualOverridesAreEmpty)

            Button("Probe Offsets") {
                mgr.probeRemoteCallLabOffsets()
            }
            .disabled(!mgr.dsready || mgr.labRunning || mgr.labArmed)
        }
    }

    @ViewBuilder
    private var appSwitchingSection: some View {
        Section(
            header: HeaderLabel(text: "App Switching", icon: "arrow.left.arrow.right"),
            footer: Text("Use Launch Target for cold-start/warm-start and automatic return to Lara before arming. After Arm succeeds, switch manually to the target app to trigger thread activity.")
        ) {
            Button("Launch Target") {
                guard let selectedApp else { return }
                launchTargetAndReturn(app: selectedApp)
            }
            .disabled(selectedApp == nil || launchRunning || mgr.labRunning)

            Button("Return to Lara") {
                returnToLara()
            }
            .disabled(launchRunning || mgr.labRunning)

            Button("Open Target App") {
                guard let selectedApp else { return }
                openTargetApp(app: selectedApp)
            }
            .disabled(selectedApp == nil || launchRunning)
        }
    }

    @ViewBuilder
    private var armSection: some View {
        Section(
            header: HeaderLabel(text: "Arm Lab", icon: "syringe"),
            footer: VStack(alignment: .leading, spacing: 4) {
                Text("Return Path Probe is experimental and tests one signed return-path strategy per session.")
                ForEach(labModes, id: \.rawValue) { mode in
                    Text("\(mode.title): \(mode.description)")
                }
            }
        ) {
            Button("Arm Inventory") {
                armLab(.inventoryOnly)
            }
            .disabled(selectedApp == nil || launchRunning || mgr.labRunning || mgr.labArmed)

            Button("Arm Restore Only") {
                armLab(.restoreOnly)
            }
            .disabled(selectedApp == nil || launchRunning || mgr.labRunning || mgr.labArmed)

            Toggle("Allow Return Path Probe (Experimental)", isOn: $allowReturnPathProbeExperimental)

            Picker("Return Path Strategy", selection: $returnPathProbeStrategy) {
                ForEach(RemoteCallReturnPathStrategyOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }

            Picker("Probe Entry Mode", selection: $returnPathProbeEntryMode) {
                ForEach(RemoteCallReturnPathEntryModeOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }

            Button("Arm Return Path Probe") {
                armLab(.returnPathProbeOnly)
            }
            .disabled(selectedApp == nil || launchRunning || mgr.labRunning || mgr.labArmed || !allowReturnPathProbeExperimental)

            Button("Disarm Session") {
                mgr.disarmRemoteCallLab()
            }
            .disabled(!mgr.labArmed && !mgr.labRunning)
        }
    }

    @ViewBuilder
    private var sessionSummarySection: some View {
        if !mgr.labReport.isEmpty {
            Section(header: HeaderLabel(text: "Session Summary", icon: "doc.text")) {
                Text(mgr.labReport)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private var labModes: [RemoteCallLabActionMode] {
        [.inventoryOnly, .restoreOnly, .returnPathProbeOnly]
    }

    private var manualOverridesAreEmpty: Bool {
        threadCpuDataOffsetOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            activeThreadOffsetOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var offsetSummaryText: String {
        if mgr.labOffsetSummary.isEmpty {
            return "Probe results are written to rc.lab logs. Manual overrides require both offsets."
        }
        return mgr.labOffsetSummary
    }

    private func refreshApps() {
        guard mgr.sbxready else {
            apps.removeAll()
            selectedAppID = nil
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedApps = InstalledUserAppCatalog.loadApps()
            DispatchQueue.main.async {
                self.apps = loadedApps
                if let selectedAppID, loadedApps.contains(where: { $0.id == selectedAppID }) {
                    return
                }
                self.selectedAppID = loadedApps.first?.id
            }
        }
    }

    private func armLab(_ mode: RemoteCallLabActionMode) {
        guard let selectedApp,
              let rcMode = RCInitMode(rawValue: mode.rawValue) else { return }
        mgr.startRemoteCallLab(app: selectedApp, mode: rcMode)
    }

    private func openTargetApp(app: InstalledUserApp) {
        guard !app.bundleID.isEmpty else {
            mgr.labStatus = "Target app has no bundle identifier."
            return
        }
        let ret = launch_app(app.bundleID)
        if ret == 0 {
            mgr.labStatus = "Opened \(app.displayName)."
        } else {
            mgr.labStatus = "Failed to open \(app.displayName)."
        }
    }

    private func returnToLara() {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            mgr.labStatus = "Current app bundle identifier is unavailable."
            return
        }
        let ret = launch_app(bundleID)
        if ret == 0 {
            mgr.labStatus = "Returned to Lara."
        } else {
            mgr.labStatus = "Failed to return to Lara."
        }
    }

    private func launchTargetAndReturn(app: InstalledUserApp) {
        guard !app.bundleID.isEmpty else {
            mgr.labStatus = "Target app has no bundle identifier."
            return
        }
        guard let laraBundleID = Bundle.main.bundleIdentifier else {
            mgr.labStatus = "Current app bundle identifier is unavailable."
            return
        }

        launchRunning = true
        mgr.labStatus = "Launching \(app.displayName) and returning to Lara..."

        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemoteCallLabLaunch") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let launchRet = launch_app(app.bundleID)
            if launchRet == 0 {
                usleep(2500000)
                _ = launch_app(laraBundleID)
                usleep(500000)
            }
            let pid = find_process_pid(app.executable)

            DispatchQueue.main.async {
                self.launchRunning = false
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
                if launchRet != 0 {
                    self.mgr.labStatus = "Failed to launch \(app.displayName)."
                    return
                }
                if pid > 0 {
                    self.mgr.labStatus = "Target ready: \(app.displayName) pid=\(pid). You can arm the Lab session now."
                } else {
                    self.mgr.labStatus = "Target launch finished, but pid lookup failed. Open it manually and retry."
                }
            }
        }
    }

    private func offsetDescription(value: Any?, source: Any?, label: String) -> String {
        let number = value as? NSNumber
        let sourceText = source as? String ?? "unknown"
        let hex = number.map { String(format: "0x%x", $0.uint32Value) } ?? "(unset)"
        return "\(label): \(hex) [\(sourceText)]"
    }
}

private struct RemoteCallLabAppRow: View {
    let app: InstalledUserApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 36, height: 36)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .foregroundColor(.primary)
                Text(app.bundleID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(app.executable)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 2)
    }
}
