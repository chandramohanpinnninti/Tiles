import SwiftUI

struct SetInput: Identifiable {
    var id = UUID()
    var weight: String = ""
    var reps: String = ""

    var parsedWeight: Double? { Double(weight) }
    var parsedReps: Int? { Int(reps) }
    var volume: Double { (parsedWeight ?? 0) * Double(parsedReps ?? 0) }
    var isValid: Bool { (parsedReps ?? 0) > 0 }
}

struct ExerciseInput: Identifiable {
    var id = UUID()
    var name: String = ""
    var sets: [SetInput] = [SetInput()]

    var volume: Double { sets.reduce(0) { $0 + $1.volume } }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && sets.contains { $0.isValid }
    }
}

struct ExerciseEntrySheet: View {
    let tile: Tracker
    let onSave: ([ExerciseInput], String?) -> Void
    let onCancel: () -> Void

    @State private var exercises: [ExerciseInput] = [ExerciseInput()]
    @State private var note: String = ""

    private var totalVolume: Double { exercises.reduce(0) { $0 + $1.volume } }
    private var canSave: Bool { exercises.contains { $0.isValid } }

    private var weightUnit: String {
        tile.unit.components(separatedBy: " ").first ?? tile.unit
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($exercises) { $exercise in
                    ExerciseSectionView(
                        exercise: $exercise,
                        weightUnit: weightUnit,
                        showDeleteButton: exercises.count > 1,
                        onDelete: { exercises.removeAll { $0.id == exercise.id } }
                    )
                }

                Section {
                    Button {
                        exercises.append(ExerciseInput())
                    } label: {
                        Label("exercise.entry.add", systemImage: "plus.circle.fill")
                    }
                }

                if totalVolume > 0 {
                    Section {
                        HStack {
                            Text("exercise.entry.totalVolume")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(totalVolume.formatted()) \(tile.unit)")
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section {
                    TextField("entry.field.note.label", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(tile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("entry.action.cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("entry.action.save") {
                        onSave(exercises.filter { $0.isValid }, note.isEmpty ? nil : note)
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct ExerciseSectionView: View {
    @Binding var exercise: ExerciseInput
    let weightUnit: String
    let showDeleteButton: Bool
    let onDelete: () -> Void

    var body: some View {
        Section {
            HStack {
                TextField("exercise.field.name", text: $exercise.name)
                    .font(.body.weight(.semibold))
                if showDeleteButton {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.quaternary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, _ in
                SetInputRow(
                    setNumber: idx + 1,
                    set: $exercise.sets[idx],
                    weightUnit: weightUnit
                )
            }
            .onDelete { exercise.sets.remove(atOffsets: $0) }

            Button {
                exercise.sets.append(SetInput())
            } label: {
                Label("exercise.entry.addSet", systemImage: "plus")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.accentColor)
        }
    }
}

private struct SetInputRow: View {
    let setNumber: Int
    @Binding var set: SetInput
    let weightUnit: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Set \(setNumber)")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .frame(width: 44, alignment: .leading)

            Spacer()

            TextField("0", text: $set.weight)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            if !weightUnit.isEmpty {
                Text(weightUnit)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(width: 28, alignment: .leading)
            }

            Text("×")
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 2)

            TextField("0", text: $set.reps)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 32)
            Text("exercise.field.reps")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}
