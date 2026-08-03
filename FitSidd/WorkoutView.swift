import SwiftUI

// MARK: - Models

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var muscleGroup: String
    var alternates: [String] = []
    var isWarmup: Bool = false

    var symbol: String {
        isWarmup ? "figure.flexibility" : "figure.strengthtraining.traditional"
    }
}

struct Routine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var emoji: String
    var exercises: [Exercise]
}

struct WorkoutSession: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var routineName: String
    var exercisesCompleted: Int
    var cardio: String = ""
    var cardioMinutes: Int = 0
}

let defaultRoutines: [Routine] = [
    Routine(name: "Push", emoji: "💪", exercises: [
        Exercise(name: "Arm Circles", sets: 1, reps: "30 sec", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Band Pull-Aparts", sets: 2, reps: "15", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Bench Press", sets: 4, reps: "8", muscleGroup: "Chest", alternates: ["Dumbbell Press", "Machine Chest Press"]),
        Exercise(name: "Overhead Press", sets: 3, reps: "10", muscleGroup: "Shoulders", alternates: ["DB Shoulder Press", "Arnold Press"]),
        Exercise(name: "Incline DB Press", sets: 3, reps: "12", muscleGroup: "Chest", alternates: ["Cable Fly", "Pec Deck"]),
        Exercise(name: "Lateral Raises", sets: 3, reps: "15", muscleGroup: "Shoulders", alternates: ["Cable Lateral Raise", "Machine Lateral"]),
        Exercise(name: "Tricep Pushdowns", sets: 3, reps: "12", muscleGroup: "Triceps", alternates: ["Skull Crushers", "Dips"]),
    ]),
    Routine(name: "Pull", emoji: "🏋️", exercises: [
        Exercise(name: "Shoulder Rolls", sets: 1, reps: "30 sec", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Light Band Row", sets: 2, reps: "15", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Pull-Ups", sets: 4, reps: "8", muscleGroup: "Back", alternates: ["Lat Pulldown", "Assisted Pull-Up"]),
        Exercise(name: "Barbell Row", sets: 4, reps: "8", muscleGroup: "Back", alternates: ["DB Row", "Cable Row"]),
        Exercise(name: "Face Pulls", sets: 3, reps: "15", muscleGroup: "Rear Delt", alternates: ["Reverse Fly", "Band Pull-Apart"]),
        Exercise(name: "Bicep Curls", sets: 3, reps: "12", muscleGroup: "Biceps", alternates: ["Hammer Curls", "Cable Curls"]),
        Exercise(name: "Hammer Curls", sets: 3, reps: "12", muscleGroup: "Biceps", alternates: ["Concentration Curl", "Incline Curl"]),
    ]),
    Routine(name: "Legs", emoji: "🦵", exercises: [
        Exercise(name: "Leg Swings", sets: 1, reps: "30 sec", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Bodyweight Squats", sets: 2, reps: "15", muscleGroup: "Warmup", isWarmup: true),
        Exercise(name: "Barbell Squat", sets: 4, reps: "8", muscleGroup: "Quads", alternates: ["Leg Press", "Goblet Squat"]),
        Exercise(name: "Romanian Deadlift", sets: 3, reps: "10", muscleGroup: "Hamstrings", alternates: ["Leg Curl", "Stiff-Leg Deadlift"]),
        Exercise(name: "Leg Press", sets: 3, reps: "12", muscleGroup: "Quads", alternates: ["Hack Squat", "Split Squat"]),
        Exercise(name: "Walking Lunges", sets: 3, reps: "12 each", muscleGroup: "Glutes", alternates: ["Reverse Lunge", "Step-Ups"]),
        Exercise(name: "Calf Raises", sets: 4, reps: "15", muscleGroup: "Calves", alternates: ["Seated Calf Raise", "Single Leg Raise"]),
    ]),
]

enum WorkoutPhase { case warmup, main, cardio, complete }

// MARK: - Main View

struct WorkoutView: View {
    @State private var health = HealthKitManager()

    @AppStorage("routinesData") private var routinesData: Data = Data()
    @AppStorage("sessionsData") private var sessionsData: Data = Data()
    @AppStorage("lastWeightsData") private var lastWeightsData: Data = Data()
    @AppStorage("didSeedRoutines") private var didSeedRoutines = false

    @State private var routines: [Routine] = []
    @State private var sessions: [WorkoutSession] = []
    @State private var lastWeights: [String: String] = [:]

    @State private var tab = 0
    @State private var activeRoutine: Routine? = nil
    @State private var editingRoutine: Routine? = nil
    @State private var showNewRoutine = false

    // Session state
    @State private var phase: WorkoutPhase = .warmup
    @State private var exerciseIndex = 0
    @State private var alternateIndex = 0
    @State private var showingAlternate = false
    @State private var currentSet = 1
    @State private var weightInput = ""
    @State private var completedCount = 0
    @State private var selectedCardio = "Treadmill"
    @State private var cardioMinutes = ""

    var warmups: [Exercise] { activeRoutine?.exercises.filter { $0.isWarmup } ?? [] }
    var mains: [Exercise] { activeRoutine?.exercises.filter { !$0.isWarmup } ?? [] }
    var currentList: [Exercise] { phase == .warmup ? warmups : mains }
    var currentExercise: Exercise? {
        exerciseIndex < currentList.count ? currentList[exerciseIndex] : nil
    }
    var displayName: String {
        if showingAlternate, let ex = currentExercise, alternateIndex < ex.alternates.count {
            return ex.alternates[alternateIndex]
        }
        return currentExercise?.name ?? ""
    }
    var alternateLabel: String {
        guard let ex = currentExercise else { return "Alternate" }
        if !showingAlternate { return "Alternate" }
        return alternateIndex < ex.alternates.count - 1 ? "Try Another" : "Auto-Skip →"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if activeRoutine == nil {
                    Picker("", selection: $tab) {
                        Text("Today").tag(0)
                        Text("History").tag(1)
                        Text("Routines").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                if activeRoutine != nil {
                    sessionView
                } else if tab == 0 {
                    todayView
                } else if tab == 1 {
                    historyView
                } else {
                    routinesView
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(activeRoutine == nil ? "Workout" : (activeRoutine?.name ?? ""))
            .onAppear { loadAll(); health.requestAuth() }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditor(routine: routine) { updated in
                    if let i = routines.firstIndex(where: { $0.id == updated.id }) {
                        routines[i] = updated; saveRoutines()
                    }
                } onDelete: { r in
                    routines.removeAll { $0.id == r.id }; saveRoutines()
                }
            }
            .sheet(isPresented: $showNewRoutine) {
                RoutineEditor(routine: nil) { newRoutine in
                    routines.append(newRoutine); saveRoutines()
                } onDelete: { _ in }
            }
        }
    }

    // MARK: - Today

    var todayView: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                Text("Pick today's workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(routines) { routine in
                        Button { startRoutine(routine) } label: {
                            VStack(spacing: 6) {
                                Text(routine.emoji).font(.largeTitle)
                                Text(routine.name).font(.subheadline).fontWeight(.semibold)
                                Text("\(routine.exercises.filter { !$0.isWarmup }.count) exercises")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { showNewRoutine = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.largeTitle).foregroundStyle(.blue)
                            Text("New routine").font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                recentCard
            }
            .padding(.bottom, 30)
        }
    }

    var headerCard: some View {
        VStack(spacing: 6) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 24) {
                VStack {
                    Text("\(thisWeekCount)").font(.title2).fontWeight(.bold)
                    Text("this week").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(health.steps)").font(.title2).fontWeight(.bold)
                    Text("steps today").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(health.activeCalories)").font(.title2).fontWeight(.bold)
                    Text("active cal").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    var thisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let local = sessions.filter { $0.date > weekAgo }.count
        let fromHealth = health.workouts.filter { $0.date > weekAgo }.count
        return max(local, fromHealth)
    }

    var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity").font(.headline).padding(.horizontal)

            if health.workouts.isEmpty && sessions.isEmpty {
                Text("Nothing yet — start a workout above")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(health.workouts.prefix(4)) { w in
                    HStack {
                        Image(systemName: "heart.fill").foregroundStyle(.red).font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).font(.subheadline).fontWeight(.medium)
                            Text("\(w.date.formatted(date: .abbreviated, time: .shortened)) · \(w.source)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(w.minutes) min").font(.caption).fontWeight(.semibold)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - History

    var historyView: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
                        Text("\(thisWeekCount) workouts").font(.title3).fontWeight(.bold)
                    }
                    Spacer()
                    Button { health.refreshAll() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise").font(.caption)
                    }
                }
            }

            Section("From Apple Health") {
                if health.workouts.isEmpty {
                    Text("No synced workouts. Check Health permissions.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(health.workouts) { w in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.name).fontWeight(.medium)
                                Text("\(w.date.formatted(date: .abbreviated, time: .shortened)) · \(w.source)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(w.minutes) min").font(.caption).fontWeight(.semibold)
                                Text("\(w.calories) cal").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Logged in FitSidd") {
                if sessions.isEmpty {
                    Text("No sessions logged yet")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { s in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.routineName).fontWeight(.medium)
                                Text(s.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(s.exercisesCompleted) done").font(.caption)
                                if !s.cardio.isEmpty && s.cardioMinutes > 0 {
                                    Text("\(s.cardio) \(s.cardioMinutes)m")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { idx in
                        sessions.remove(atOffsets: idx); saveSessions()
                    }
                }
            }
        }
    }

    // MARK: - Routines

    var routinesView: some View {
        List {
            Section {
                Button { showNewRoutine = true } label: {
                    Label("Create new routine", systemImage: "plus.circle.fill")
                }
            }
            Section("My routines") {
                ForEach(routines) { routine in
                    Button { editingRoutine = routine } label: {
                        HStack {
                            Text(routine.emoji).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.name).fontWeight(.medium).foregroundStyle(.primary)
                                Text("\(routine.exercises.count) exercises")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Session

    var sessionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch phase {
                case .warmup:
                    phaseLabel("WARM UP", .orange)
                    if let ex = currentExercise { exerciseCard(ex) }
                case .main:
                    phaseLabel("MAIN WORKOUT", .blue)
                    ProgressView(value: Double(exerciseIndex), total: Double(max(mains.count, 1)))
                        .padding(.horizontal)
                    Text("Exercise \(min(exerciseIndex + 1, mains.count)) of \(mains.count)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let ex = currentExercise { exerciseCard(ex) }
                case .cardio:
                    cardioCard
                case .complete:
                    completeCard
                }

                if phase != .complete {
                    Button("Quit workout") { activeRoutine = nil }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 30)
        }
    }

    func phaseLabel(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption).fontWeight(.bold).foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    func exerciseCard(_ ex: Exercise) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ex.isWarmup ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: ex.symbol)
                        .font(.system(size: 28))
                        .foregroundStyle(ex.isWarmup ? .orange : .blue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if showingAlternate {
                        Text("ALTERNATE \(alternateIndex + 1)")
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.orange)
                    }
                    Text(displayName).font(.title3).fontWeight(.bold)
                    Text(ex.muscleGroup).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                Spacer()
                statPill("\(ex.sets)", "Sets")
                Spacer()
                Divider().frame(height: 36)
                Spacer()
                statPill(ex.reps, "Reps")
                Spacer()
                if !ex.isWarmup {
                    Divider().frame(height: 36)
                    Spacer()
                    statPill("\(currentSet)/\(ex.sets)", "Set")
                    Spacer()
                }
            }

            if !ex.isWarmup {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "scalemass").foregroundStyle(.secondary)
                        TextField("Weight", text: $weightInput)
                            .keyboardType(.decimalPad)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if let last = lastWeights[ex.name], !last.isEmpty {
                        Text("Last time: \(last)")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if currentSet < ex.sets {
                    Button("✓ Complete set \(currentSet)") { currentSet += 1 }
                        .buttonStyle(.bordered).tint(.green)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 10) {
                if !ex.isWarmup && !ex.alternates.isEmpty {
                    Button(alternateLabel) { handleAlternate() }
                        .buttonStyle(.bordered).tint(.orange)
                }
                Spacer()
                Button("Skip") { advance(saveWeight: false) }
                    .buttonStyle(.bordered).tint(.gray)
                Button("Done ✓") {
                    completedCount += 1
                    advance(saveWeight: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3).fontWeight(.bold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    var cardioCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill").font(.system(size: 40)).foregroundStyle(.red)
            Text("Cardio finisher").font(.title3).fontWeight(.bold)

            Picker("Cardio", selection: $selectedCardio) {
                Text("Treadmill").tag("Treadmill")
                Text("Elliptical").tag("Elliptical")
                Text("Stairs").tag("Stair Master")
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "timer").foregroundStyle(.secondary)
                TextField("Minutes", text: $cardioMinutes)
                    .keyboardType(.numberPad)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button("Skip cardio") { finish() }
                    .buttonStyle(.bordered).tint(.gray)
                Button("Done ✓") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    var completeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill").font(.system(size: 52)).foregroundStyle(.yellow)
            Text("Workout complete! 🔥").font(.title2).fontWeight(.bold)
            Text("\(completedCount) exercises crushed").foregroundStyle(.secondary)
            Button("Done") { activeRoutine = nil }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity).padding(30)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Session logic

    func startRoutine(_ routine: Routine) {
        activeRoutine = routine
        phase = routine.exercises.contains { $0.isWarmup } ? .warmup : .main
        exerciseIndex = 0; alternateIndex = 0; showingAlternate = false
        currentSet = 1; weightInput = ""; completedCount = 0; cardioMinutes = ""
    }

    func handleAlternate() {
        guard let ex = currentExercise, !ex.alternates.isEmpty else { return }
        if !showingAlternate { showingAlternate = true; alternateIndex = 0 }
        else if alternateIndex < ex.alternates.count - 1 { alternateIndex += 1 }
        else { advance(saveWeight: false) }
    }

    func advance(saveWeight: Bool) {
        if saveWeight, let ex = currentExercise, !weightInput.isEmpty {
            lastWeights[ex.name] = weightInput
            saveWeights()
        }
        showingAlternate = false; alternateIndex = 0
        weightInput = ""; currentSet = 1

        if exerciseIndex + 1 < currentList.count {
            exerciseIndex += 1
        } else if phase == .warmup {
            phase = .main; exerciseIndex = 0
        } else {
            phase = .cardio
        }
    }

    func finish() {
        let session = WorkoutSession(
            date: Date(),
            routineName: (activeRoutine?.emoji ?? "") + " " + (activeRoutine?.name ?? "Workout"),
            exercisesCompleted: completedCount,
            cardio: cardioMinutes.isEmpty ? "" : selectedCardio,
            cardioMinutes: Int(cardioMinutes) ?? 0
        )
        sessions.insert(session, at: 0)
        saveSessions()
        phase = .complete
    }

    // MARK: - Persistence

    func loadAll() {
        if let r = try? JSONDecoder().decode([Routine].self, from: routinesData), !r.isEmpty {
            routines = r
        } else if !didSeedRoutines {
            routines = defaultRoutines; didSeedRoutines = true; saveRoutines()
        }
        if let s = try? JSONDecoder().decode([WorkoutSession].self, from: sessionsData) {
            sessions = s
        }
        if let w = try? JSONDecoder().decode([String: String].self, from: lastWeightsData) {
            lastWeights = w
        }
    }

    func saveRoutines() {
        if let d = try? JSONEncoder().encode(routines) { routinesData = d }
    }
    func saveSessions() {
        if let d = try? JSONEncoder().encode(sessions) { sessionsData = d }
    }
    func saveWeights() {
        if let d = try? JSONEncoder().encode(lastWeights) { lastWeightsData = d }
    }
}

// MARK: - Routine Editor

struct RoutineEditor: View {
    let routine: Routine?
    let onSave: (Routine) -> Void
    let onDelete: (Routine) -> Void

    @State private var name = ""
    @State private var emoji = "💪"
    @State private var exercises: [Exercise] = []
    @State private var showAddExercise = false
    @Environment(\.dismiss) private var dismiss

    let emojiOptions = ["💪","🏋️","🦵","🔥","⚡️","🏃","🧘","🤸","🥊","🚴"]

    var body: some View {
        NavigationView {
            Form {
                Section("Routine") {
                    TextField("Name (e.g. Upper Body)", text: $name)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title3)
                                    .padding(4)
                                    .background(emoji == e ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Exercises") {
                    ForEach($exercises) { $ex in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Exercise name", text: $ex.name)
                                .fontWeight(.medium)
                            HStack {
                                Stepper("Sets: \(ex.sets)", value: $ex.sets, in: 1...10)
                                    .font(.caption)
                            }
                            TextField("Reps (e.g. 8 or 30 sec)", text: $ex.reps)
                                .font(.caption)
                            TextField("Muscle group", text: $ex.muscleGroup)
                                .font(.caption)
                            Toggle("Warm-up exercise", isOn: $ex.isWarmup)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        exercises.append(Exercise(name: "", sets: 3, reps: "10", muscleGroup: ""))
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                }

                if let routine {
                    Section {
                        Button(role: .destructive) {
                            onDelete(routine); dismiss()
                        } label: {
                            HStack { Spacer(); Label("Delete routine", systemImage: "trash"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty else { return }
                        var r = routine ?? Routine(name: "", emoji: "💪", exercises: [])
                        r.name = name; r.emoji = emoji
                        r.exercises = exercises.filter { !$0.name.isEmpty }
                        onSave(r); dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
            .onAppear {
                if let routine {
                    name = routine.name; emoji = routine.emoji; exercises = routine.exercises
                }
            }
        }
    }
}

#Preview { WorkoutView() }
