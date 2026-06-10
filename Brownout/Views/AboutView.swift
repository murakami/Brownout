import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let tdgcURL = URL(string: "https://www.tdgc.jp/areainfo/denki/")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brownout")
                                .font(.headline)
                            Text("© 2011-2026 Bitz Co., Ltd.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Data") {
                    Link(destination: tdgcURL) {
                        Label("Area Power Forecasts (TDGC)", systemImage: "arrow.up.right.square")
                    }

                    ForEach(PowerArea.all) { area in
                        Link(destination: area.websiteURL) {
                            Label {
                                Text(LocalizedStringKey(area.nameKey))
                            } icon: {
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Version") {
                    if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        LabeledContent("App Version", value: v)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
