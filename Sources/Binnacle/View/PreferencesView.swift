import SwiftUI

struct PreferencesView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 400, height: 200)
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { state.theme },
                    set: {
                        state.theme = $0
                        UserDefaults.standard.set($0.rawValue, forKey: "binnacle_theme")
                    }
                )) {
                    Text("System").tag(AppState.Theme.system)
                    Text("Navy").tag(AppState.Theme.navy)
                    Text("Parchment").tag(AppState.Theme.parchment)
                }
                .pickerStyle(.segmented)
            }

            Section("File") {
                HStack {
                    Text("Current file:")
                        .font(PequodTheme.metadataFont())
                    Text(state.fileURL?.path ?? "None")
                        .font(PequodTheme.metadataFont())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding()
    }
}
