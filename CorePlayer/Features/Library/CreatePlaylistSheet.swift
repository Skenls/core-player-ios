import SwiftUI

struct CreatePlaylistSheet: View {
    @Environment(\.api) private var api
    @Environment(\.presentationMode) private var presentationMode
    @State private var name = ""
    @State private var isCreating = false
    @State private var error: String?
    var body: some View {
        NavigationView {
            Form {
                TextField("Название", text: $name)
                if let error = error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            .navigationTitle("Новый плейлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            // CREATE
        }
        .preferredColorScheme(.dark)
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        Task {
            do {
                _ = try await api.createPlaylist(name: trimmed)
                presentationMode.wrappedValue.dismiss()
            } catch {
                self.error = error.localizedDescription
                isCreating = false
            }
        }
    }
}
