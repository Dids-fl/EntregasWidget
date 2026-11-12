import SwiftUI
import WidgetKit

@main
struct EntregasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var calendarURL: String = DataStore.calendarURL ?? ""
    @State private var isSaved = false
    @State private var isLoading = false
    @State private var eventCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 56))
                        .foregroundColor(.white)

                    Text("Entregas")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)

                    Text("Cole o link da sua agenda para\nver suas entregas no widget")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Link da Agenda (.ics)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("Cole o link aqui...", text: $calendarURL)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }

                    Button(action: saveURL) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else if isSaved {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                            }
                            Text(isSaved ? "Salvo!" : "Salvar e Sincronizar")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(calendarURL.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                        .foregroundColor(calendarURL.isEmpty ? .gray : .black)
                        .cornerRadius(12)
                    }
                    .disabled(calendarURL.isEmpty || isLoading)

                    if isSaved && eventCount > 0 {
                        Text("\(eventCount) eventos encontrados")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 4) {
                    Text("Adicione o widget na tela inicial")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Toque e segure a tela > + > Entregas")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            calendarURL = DataStore.calendarURL ?? ""
        }
    }

    private func saveURL() {
        isLoading = true
        isSaved = false
        DataStore.calendarURL = calendarURL
        UserDefaults.standard.set(calendarURL, forKey: "widget_calendar_url")

        Task {
            let events = await DataStore.fetchAndCacheEvents()
            await MainActor.run {
                eventCount = events.count
                isLoading = false
                isSaved = true
                WidgetCenter.shared.reloadAllTimelines()
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                isSaved = false
            }
        }
    }
}
