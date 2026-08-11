import SwiftUI

public struct DashboardView: View {
    @Bindable private var state: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var showSettings = false
    @State private var tick = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    public init(state: AppState) {
        self._state = Bindable(state)
    }

    public var body: some View {
        let palette = Palette.forScheme(scheme)
        VStack(alignment: .leading, spacing: 0) {
            header(palette)
            cluster(palette)
            burnLine(palette)
            Divider().overlay(palette.divider).padding(.vertical, 10)
            tokenSection(palette)
            footer(palette)
        }
        .padding(16)
        .frame(width: 330)
        .background(
            LinearGradient(
                colors: [palette.panelTop, palette.panelBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onReceive(timer) { tick = $0 }
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
        }
    }

    private func header(_ palette: Palette) -> some View {
        HStack {
            Text("⏱ Odometer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            Spacer()
            if let badge = state.planBadge {
                Text(badge)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(palette.badgeBackground, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.bottom, 10)
    }

    private func cluster(_ palette: Palette) -> some View {
        HStack(alignment: .bottom) {
            gauge(for: .weeklyAll, diameter: 76, isPrimary: false)
            Spacer(minLength: 0)
            gauge(for: .session, diameter: 120, isPrimary: true)
            Spacer(minLength: 0)
            if state.snapshot?.limit(.weeklyScoped) != nil {
                gauge(for: .weeklyScoped, diameter: 76, isPrimary: false)
            }
        }
    }

    private func gauge(for kind: LimitKind, diameter: CGFloat, isPrimary: Bool) -> some View {
        let limit = state.snapshot?.limit(kind)
        return GaugeView(
            percent: limit?.percent,
            caption: limit?.label ?? defaultCaption(for: kind),
            subcaption: resetText(limit?.resetsAt),
            diameter: diameter,
            isPrimary: isPrimary
        )
    }

    private func defaultCaption(for kind: LimitKind) -> String {
        switch kind {
        case .session: return "Сессия 5 ч"
        case .weeklyAll: return "Неделя"
        case .weeklyScoped: return "Модель · нед."
        }
    }

    private func resetText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate(
            Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
        )
        return "до \(formatter.string(from: date))"
    }

    @ViewBuilder
    private func burnLine(_ palette: Palette) -> some View {
        Text(burnText)
            .font(.system(size: 11))
            .foregroundStyle(palette.burnText)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private var burnText: String {
        switch state.usageState {
        case .noCredentials:
            return "Войдите в Claude Code"
        case .unavailable where state.snapshot == nil:
            return "Лимиты недоступны"
        default:
            break
        }
        switch state.forecast {
        case .insufficientData:
            return "⚡ накапливаю данные"
        case .idle:
            return "⚡ расхода нет"
        case .lastsUntilReset:
            return "⚡ хватит до конца сессии"
        case let .exhausts(at, rate):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "⚡ ~\(Int(rate.rounded()))%/ч — хватит до \(formatter.string(from: at))"
        }
    }

    private func tokenSection(_ palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ТОКЕНЫ СЕГОДНЯ")
                .font(.system(size: 10, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(palette.secondaryText)

            if state.stats.total.total == 0 {
                Text("нет данных")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
            } else {
                row("Всего", value: totalText, palette: palette)
                ForEach(topEntries(state.stats.byModel), id: \.0) { name, counts in
                    row(name, value: format(counts.total), palette: palette)
                }
                ForEach(topEntries(state.stats.byProject), id: \.0) { name, counts in
                    row(name, value: format(counts.total), palette: palette)
                }
            }
        }
    }

    private var totalText: String {
        let tokens = format(state.stats.total.total)
        guard let cost = state.stats.estimatedCostUSD else { return "\(tokens) · —" }
        let suffix = state.stats.hasUnpricedModel ? "+" : ""
        return String(format: "%@ · ≈$%.2f%@", tokens, cost, suffix)
    }

    private func topEntries(_ source: [String: TokenCounts]) -> [(String, TokenCounts)] {
        source.sorted { $0.value.total > $1.value.total }.prefix(2).map { ($0.key, $0.value) }
    }

    private func format(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func row(_ label: String, value: String, palette: Palette) -> some View {
        HStack {
            Text(label).foregroundStyle(palette.secondaryText)
            Spacer()
            Text(value).foregroundStyle(palette.primaryText).monospacedDigit()
        }
        .font(.system(size: 12))
    }

    private func footer(_ palette: Palette) -> some View {
        HStack {
            Button("⚙︎ Настройки") { showSettings = true }
                .buttonStyle(.plain)
            Spacer()
            if let stale = state.staleText(now: tick) {
                Text(stale)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(palette.secondaryText)
        .padding(.top, 12)
    }
}
