//
//  DecryptView.swift
//  lara
//
//  Created by neonmodder123 on 23.05.26.
//

import SwiftUI

struct KeychainApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let bundlePath: String
    let executable: String
    let icon: UIImage?
}

struct KeychainView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var query = ""
    @State private var apps: [KeychainApp] = []
    @State private var datareadingbid: String? = nil
    @State private var errormsg: String? = nil
    @State private var pendingread: KeychainApp? = nil

    private var filteredapps: [KeychainApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return apps }
        let q = trimmed.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !mgr.sbxready {
                    Section {
                        Text("Sandbox escape not ready. Run the sandbox escape first.")
                            .foregroundColor(.secondary)
                    } header: { Text("Status") }
                }

                HStack {
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(action: loadApps) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!mgr.sbxready || datareadingbid != nil)
                }

                if let error = errormsg {
                    Section {
                        PlainAlert(title: "Error", icon: "exclamationmark.triangle", text: error, color: .red)
                    }
                }

                Section {
                    if filteredapps.isEmpty {
                        Text(query.isEmpty ? "Loading..." : "No matches.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredapps) { app in
                            KCAppRow(app: app, isreading: datareadingbid == app.bundleID) {
                                startRead(app)
                            }
                        }
                    }
                } header: {
                    HeaderLabel(text: "Installed Apps", icon: "app.badge")
                }
            }
            .navigationTitle("Keychain Read")
        }
        .onAppear {
            set_log_callback_kc { msg in
                guard let msg = msg else { return }
                let s = String(cString: msg)
                DispatchQueue.main.async {
                    laramgr.shared.logmsg("(keychain) \(s)")
                }
            }
            if mgr.sbxready { loadApps() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if let app = pendingread {
                pendingread = nil
                let pid = find_process_pid(app.executable)
                if pid > 0 {
                    doRead(app, pid: pid)
                } else {
                    errormsg = "App is not running, try again."
                    datareadingbid = nil
                }
            }
        }
        .onChange(of: mgr.sbxready) { ready in
            if ready { loadApps() } else { apps.removeAll() }
        }
    }

    func loadApps() {
        guard mgr.sbxready else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [KeychainApp] = []
            let bundleFolder = "/private/var/containers/Bundle/Application"

            guard let bundles = try? FileManager.default.contentsOfDirectory(atPath: bundleFolder) else {
                DispatchQueue.main.async { apps.removeAll() }
                return
            }

            for bundle in bundles {
                let appPath = bundleFolder + "/" + bundle
                guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appPath) else { continue }
                for item in contents {
                    guard item.hasSuffix(".app") else { continue }
                    let fullAppPath = appPath + "/" + item
                    let infoPath = fullAppPath + "/Info.plist"
                    guard let info = NSDictionary(contentsOfFile: infoPath) else { continue }

                    let executable = info["CFBundleExecutable"] as? String ?? ""
                    if executable.isEmpty { continue }
                    let bundleid = info["CFBundleIdentifier"] as? String ?? ""
                    let name = (info["CFBundleDisplayName"] as? String) ??
                               (info["CFBundleName"] as? String) ??
                               (item as NSString).deletingPathExtension

                    var icon: UIImage? = nil
                    if let icons = info["CFBundleIcons"] as? [String: Any],
                       let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                       let iconfiles = primary["CFBundleIconFiles"] as? [String],
                       let iconname = iconfiles.last {
                        let iconpath = fullAppPath + "/" + iconname
                        if let img = UIImage(contentsOfFile: iconpath) { icon = img }
                        else if let img = UIImage(contentsOfFile: iconpath + "@2x.png") { icon = img }
                        else if let img = UIImage(contentsOfFile: iconpath + ".png") { icon = img }
                    }

                    results.append(KeychainApp(
                        name: name, bundleID: bundleid, bundlePath: fullAppPath,
                        executable: executable,
                        icon: icon ?? UIImage(named: "unknown"),
                    ))
                    break
                }
            }

            results.sort { $0.name.lowercased() < $1.name.lowercased() }
            DispatchQueue.main.async { apps = results }
        }
    }

    func startRead(_ app: KeychainApp) {
        guard datareadingbid == nil && pendingread == nil else { return }
        guard mgr.dsready else { errormsg = "Darksword not ready, run the exploit first."; return }
        guard mgr.sbxready else { errormsg = "Sandbox not escaped."; return }

        runRead(app)
    }

    func runRead(_ app: KeychainApp) {
        errormsg = nil
        datareadingbid = app.bundleID

        // let pid = find_process_pid(app.executable)
        // if pid > 0 {
        //     doRead(app, pid: pid)
        // } else {
        pendingread = app

        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "AutoResumeDecrypt") {
            UIApplication.shared.endBackgroundTask(bgTask)
        }

        let ret = launch_app(app.bundleID)
        guard ret == 0 else {
            UIApplication.shared.endBackgroundTask(bgTask)
            pendingread = nil
            datareadingbid = nil
            errormsg = "Could not launch app. Open it manually."
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5) {
            launch_app(Bundle.main.bundleIdentifier!)
            usleep(500000)

            if self.pendingread != nil {
                self.pendingread = nil
                let foundPid = find_process_pid(app.executable)
                if foundPid > 0 {
                    DispatchQueue.main.async {
                        self.doRead(app, pid: foundPid)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.datareadingbid = nil
                        self.errormsg = "Process not found after launch. Try manually."
                    }
                }
            }

            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
        // }
    }

    func doRead(_ app: KeychainApp, pid: pid_t) {
        laramgr.shared.logmsg("(keychain) reading \(app.bundleID)...")

        DispatchQueue.global(qos: .userInitiated).async {
            if let proc = RemoteCall(process: app.executable, useMigFilterBypass: false) {
                var sec_symbols = remote_sec_symbols()
                if find_secitem_symbols(proc, &sec_symbols) {
                    if let secitems = get_secitems(proc, &sec_symbols, .scGenericPassword, false) {
                        laramgr.shared.logmsg("(keychain) fetched \(secitems.count) generic password item(s)")
                        for (index, item) in secitems.prefix(3).enumerated() {
                            laramgr.shared.logmsg("(keychain) item[\(index)] \(item)")
                        }
                        if secitems.count > 3 {
                            laramgr.shared.logmsg("(keychain) truncated \(secitems.count - 3) additional item(s)")
                        }
                    } else {
                        laramgr.shared.logmsg("(keychain) failed to read generic password items")
                    }
                } else {
                    laramgr.shared.logmsg("(keychain) failed to resolve Security symbols")
                }

                DispatchQueue.main.async {
                    self.datareadingbid = nil
                }
                proc.destroy()
            } else {
                DispatchQueue.main.async {
                    self.datareadingbid = nil
                    self.errormsg = "Cannot init RemoteCall."
                }
                return
            }
        }
    }
}

struct KCAppRow: View {
    let app: KeychainApp
    let isreading: Bool
    let onread: () -> Void

    var body: some View {
        HStack {
            if let icon = app.icon {
                Image(uiImage: icon)
                    .resizable().frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                Image("unknown")
                    .resizable().frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.headline)
                Text(app.bundleID).font(.caption).foregroundColor(.gray)
            }

            Spacer()

            Button(action: onread) {
                if isreading { ProgressView() }
                else { Text("Read") }
            }
        }
        .opacity(isreading ? 0.6 : 1.0)
    }
}
