import SwiftUI

public struct SettingsView: View {
    @Bindable private var state: AppState
    @Environment(\.dismiss) private var dismiss

    public init(state: AppState) {
        self._state = Bindable(state)
    }

    public var body: some View {
        @Bindable var settings = state.settings
        Form {
            Section {
                Toggle("Запускать при входе", isOn: $settings.launchAtLogin)
            }

            Section("Звук") {
                Toggle("Звук при запросе решения", isOn: $settings.soundEnabled)
                Picker("Звук", selection: $settings.soundName) {
                    ForEach(Settings.availableSoundNames, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!settings.soundEnabled)
            }

            Section("Уведомления") {
                Toggle("Уведомлять о порогах", isOn: $settings.notificationsEnabled)
                if !state.notifier.isAuthorized {
                    Text("Уведомления запрещены в системных настройках macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Пороги", selection: thresholdBinding) {
                    Text("80% и 95%").tag([80.0, 95.0])
                    Text("50%, 80% и 95%").tag([50.0, 80.0, 95.0])
                    Text("только 95%").tag([95.0])
                }
                .disabled(!settings.notificationsEnabled)
            }

            Section("Меню-бар") {
                Picker("Показывать процент", selection: $settings.menuBarLimit) {
                    Text("Сессия").tag(LimitKind.session)
                    Text("Неделя").tag(LimitKind.weeklyAll)
                    Text("Неделя модели").tag(LimitKind.weeklyScoped)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Готово") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(.vertical, 8)
    }

    private var thresholdBinding: Binding<[Double]> {
        Binding(
            get: { state.settings.thresholds },
            set: { state.settings.thresholds = $0 }
        )
    }
}
