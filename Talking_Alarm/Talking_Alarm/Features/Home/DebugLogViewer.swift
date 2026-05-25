import SwiftUI

#if DEBUG
struct DebugLogViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sections: [(String, [String])] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading logs...")
                } else if sections.isEmpty {
                    ContentUnavailableView("No Logs", systemImage: "doc.text", description: Text("No debug logs captured yet."))
                } else {
                    List {
                        ForEach(sections.indices, id: \.self) { sectionIndex in
                            let section = sections[sectionIndex]
                            Section(header: Text(section.0).font(Brand.Typography.caption)) {
                                ForEach(section.1.indices, id: \.self) { entryIndex in
                                    Text(section.1[entryIndex])
                                        .font(Brand.Typography.caption2)
                                        .foregroundStyle(Brand.Colors.textPrimary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        let loaded = await DebugLogStore.shared.loadSections()
        await MainActor.run {
            sections = loaded
            isLoading = false
        }
    }
}
#endif
