import AppKit
import ServiceManagement
import SwiftUI

@MainActor
public final class OdometerAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var state: AppState!
    private var usageTimer: Timer?
    private var logsTimer: Timer?
    private var blinkTimer: Timer?
    private var blinkOn = true

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dataDirectory = home.appendingPathComponent(".claude/odometer")
        let credentials = KeychainCredentialsProvider()

        state = AppState(
            usage: HTTPUsageProvider(
                credentials: credentials,
                transport: HTTPUsageProvider.liveTransport()
            ),
            logs: LogsService(
                projectsDirectory: home.appendingPathComponent(".claude/projects"),
                cacheURL: dataDirectory.appendingPathComponent("cache.json")
            ),
            attention: AttentionService(
                store: AttentionStore(directory: dataDirectory.appendingPathComponent("attention"))
            ),
            settings: Settings(),
            planBadge: try? credentials.credentials().planBadge
        )

        state.attention.newBeaconHandler = { [weak self] _ in self?.playSound() }
        state.attention.start()

        buildStatusItem()
        buildPopover()
        startTimers()
        applyLaunchAtLogin()

        Task {
            await state.notifier.requestAuthorization()
            await state.refreshUsage(now: Date())
            state.refreshLogs(now: Date())
            redraw()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        state?.attention.stop()
        usageTimer?.invalidate()
        logsTimer?.invalidate()
        blinkTimer?.invalidate()
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        redraw()
    }

    private func buildPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 330, height: 420)
        popover.contentViewController = NSHostingController(rootView: DashboardView(state: state))
    }

    private func startTimers() {
        scheduleUsageRefresh(after: 0)
        logsTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.state.refreshLogs(now: Date())
                self?.redraw()
            }
        }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }
    }

    /// Reschedules itself each cycle so the interval can follow the backoff.
    private func scheduleUsageRefresh(after delay: TimeInterval) {
        usageTimer?.invalidate()
        usageTimer = Timer.scheduledTimer(withTimeInterval: max(delay, 1), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.state.refreshUsage(now: Date())
                self.redraw()
                self.scheduleUsageRefresh(after: self.state.nextRefreshDelay)
            }
        }
    }

    private func pulse() {
        guard state.attention.isBlinking else {
            if !blinkOn {
                blinkOn = true
                statusItem.button?.alphaValue = 1
            }
            return
        }
        blinkOn.toggle()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            statusItem.button?.animator().alphaValue = blinkOn ? 1.0 : 0.25
        }
    }

    private func redraw() {
        let percent = state.menuBarPercent()
        statusItem.button?.image = MenuBarIconRenderer.image(
            percent: percent,
            zone: GaugeGeometry.zone(percent: percent ?? 0),
            isAttention: state.attention.isBlinking
        )
        if !state.attention.isBlinking { statusItem.button?.alphaValue = 1 }
    }

    private func playSound() {
        guard state.settings.soundEnabled else { return }
        NSSound(named: state.settings.soundName)?.play()
    }

    @objc private func statusItemClicked() {
        if state.attention.isBlinking {
            activateOriginatingTerminal()
            state.attention.clear()
            redraw()
        }
        togglePopover()
    }

    /// Brings the terminal that asked for a decision to the front. If the
    /// beacon did not record a recognizable terminal, the panel simply opens.
    private func activateOriginatingTerminal() {
        guard let program = state.attention.beacons.last?.termProgram,
              let bundleId = Self.bundleIdentifier(forTermProgram: program)
        else { return }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        apps.first?.activate(options: [.activateAllWindows])
    }

    static func bundleIdentifier(forTermProgram program: String) -> String? {
        switch program {
        case "Apple_Terminal": return "com.apple.Terminal"
        case "iTerm.app": return "com.googlecode.iterm2"
        case "WarpTerminal": return "dev.warp.Warp-Stable"
        case "ghostty": return "com.mitchellh.ghostty"
        case "vscode": return "com.microsoft.VSCode"
        case "Hyper": return "co.zeit.hyper"
        default: return nil
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if state.settings.launchAtLogin, service.status != .enabled {
                try service.register()
            } else if !state.settings.launchAtLogin, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            Diagnostics.log("launch-at-login update failed: \(error)")
        }
    }
}
