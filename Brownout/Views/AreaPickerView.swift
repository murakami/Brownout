import SwiftUI

struct AreaPickerView: View {
    @Binding var selectedArea: PowerArea

    var body: some View {
        Menu {
            ForEach(PowerArea.all) { area in
                Button {
                    selectedArea = area
                } label: {
                    if area == selectedArea {
                        Label(LocalizedStringKey(area.nameKey), systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(area.nameKey))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(LocalizedStringKey(selectedArea.nameKey))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
    }
}

#Preview {
    @Previewable @State var area = PowerArea.tokyo
    NavigationStack {
        Text("Preview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AreaPickerView(selectedArea: $area)
                }
            }
    }
}
