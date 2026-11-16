import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var synapse: SynapseStore
    @State private var showResetSynapse = false
    @State private var showLogout = false
    var body: some View {
        NavigationView {
            Form {
                Section("Фон плеера") {
                    Picker("Фон", selection: $settings.background) {
                        ForEach(PlayerBackground.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Оформление") {
                    Toggle("AMOLED режим", isOn: $settings.amoled)
                    Toggle("Адаптивный пузырь", isOn: $settings.adaptiveBubble)
                }
                Section("Качество аудио") {
                    Picker("Кодек", selection: $settings.codec) {
                        ForEach(AudioCodec.selectableCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Synapse") {
                    Toggle(isOn: $synapse.continuePlayback) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Продолжать воспроизведение")
                            Text("Synapse подберёт музыку, когда закончится очередь")
                                .font(.caption).foregroundColor(CoreColors.textSecondary)
                        }
                    }
                    .disabled(synapse.resetting)
                    Picker("Анимация", selection: $synapse.burstAnimation) {
                        Text("Лучи").tag(true)
                        Text("Сфера").tag(false)
                    }.disabled(synapse.resetting)
                    Picker("Цвет частиц", selection: $synapse.whiteParticles) {
                        Text("Белый").tag(true)
                        Text("Фиолетовый").tag(false)
                    }.disabled(synapse.resetting)
                    Button(synapse.resetting ? "Сбрасываем профиль…" : "Сбросить профиль Synapse") {
                        showResetSynapse = true
                    }
                    .foregroundColor(Color(red: 197 / 255, green: 166 / 255, blue: 1))
                    .disabled(synapse.resetting)
                    if let error = synapse.error { Text(error).font(.caption).foregroundColor(.red) }
                    if let notice = synapse.notice { Text(notice).font(.caption).foregroundColor(CoreColors.textSecondary) }
                }
                Section("Аккаунт") {
                    Text(auth.serverURLString).font(.caption)
                    Button("Выйти") { showLogout = true }.foregroundColor(.red)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.white)
                }
            }
            .tint(.white)
        }
        .preferredColorScheme(.dark)
        .alert("Сбросить Synapse?", isPresented: $showResetSynapse) {
            Button("Сбросить", role: .destructive) { synapse.resetProfile() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("История обучения и предпочтения Synapse будут удалены на сервере для всех ваших устройств. Избранное сохранится.")
        }
        .confirmationDialog("Выйти?", isPresented: $showLogout) {
            Button("Выйти", role: .destructive) {
                auth.logout()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}
