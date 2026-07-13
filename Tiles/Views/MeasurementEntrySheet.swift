import SwiftUI

struct MeasurementEntrySheet: View {
    let tile: Tracker
    let onSave: (Double, String?) -> Void
    let onCancel: () -> Void

    @State private var valueText = ""
    @State private var note = ""

    private var parsedValue: Double? { Double(valueText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("entry.field.label")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField(tile.unit, text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text(tile.name)
                }

                Section {
                    TextField("entry.field.note.label", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(String(format: NSLocalizedString("entry.nav.title", comment: ""), tile.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("entry.action.cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("entry.action.save") {
                        if let v = parsedValue {
                            onSave(v, note.isEmpty ? nil : note)
                        }
                    }
                    .bold()
                    .disabled(parsedValue == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
