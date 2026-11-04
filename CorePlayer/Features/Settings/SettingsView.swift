import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
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
        .confirmationDialog("Выйти?", isPresented: $showLogout) {
            Button("Выйти", role: .destructive) {
                auth.logout()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}
