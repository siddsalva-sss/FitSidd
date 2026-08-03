import SwiftUI
import CoreMotion

@Observable
class PedometerManager {
    private let pedometer = CMPedometer()
    var livePace: Double = 0
    var fastestPace: Double = 0

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { data, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                if let pace = data.currentPace?.doubleValue, pace > 0 {
                    let mph = 1 / pace * 2.237
                    self.livePace = mph
                    if mph > self.fastestPace { self.fastestPace = mph }
                }
            }
        }
    }
    func stop() { pedometer.stopUpdates() }
}

struct TreadmillEntry: Identifiable, Codable {
    var id = UUID()
    let miles: Double
    let date: Date
}

struct StepsView: View {
    @State private var health = HealthKitManager()
    @State private var pedometer = PedometerManager()
    @AppStorage("treadmillData") private var treadmillData: Data = Data()
    @AppStorage("stepGoal") private var goal: Int = 10000
    @State private var treadmillEntries: [TreadmillEntry] = []
    @State private var showTreadmillSheet = false
    @State private var treadmillInput = ""

    var treadmillMiles: Double {
        treadmillEntries.filter { Calendar.current.isDateInToday($0.date) }
                        .reduce(0) { $0 + $1.miles }
    }
    var totalMiles: Double { health.distanceMiles + treadmillMiles }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    stepCard
                    statsGrid
                    healthWorkoutsCard
                    treadmillCard
                }
                .padding(.bottom, 30)
        }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Steps")
                .refreshable { health.refreshAll() }.navigationTitle("Steps")
            .refreshable { health.refreshAll() }
            .onAppear {
                health.requestAuth()
                pedometer.start()
                loadTreadmill()
            }
            .onDisappear { pedometer.stop() }
            .sheet(isPresented: $showTreadmillSheet) { treadmillSheet }
        }
    }

    var stepCard: some View {
        VStack(spacing: 8) {
            Text("\(health.steps)")
                .font(.system(size: 64, weight: .bold))
            Text("steps today · Apple Health")
                .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(min(health.steps, goal)), total: Double(goal))
                .padding(.horizontal)
                .tint(health.steps >= goal ? .green : .blue)
            Text(health.steps >= goal ? "✅ Goal smashed!" : "\(goal - health.steps) to goal")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }

    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Miles", value: String(format: "%.2f", totalMiles), icon: "figure.walk")
            StatCard(title: "Active Cal", value: "\(health.activeCalories)", icon: "flame.fill")
            StatCard(title: "Fastest Pace",
                     value: pedometer.fastestPace > 0 ? String(format: "%.1f mph", pedometer.fastestPace) : "--",
                     icon: "hare.fill")
            StatCard(title: "Current Pace",
                     value: pedometer.livePace > 0 ? String(format: "%.1f mph", pedometer.livePace) : "--",
                     icon: "figure.run")
        }
        .padding(.horizontal)
    }

    var healthWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("From Apple Health", systemImage: "heart.fill")
                    .font(.headline).foregroundStyle(.red)
                Spacer()
                Button { health.refreshAll() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
            }

            if health.workouts.isEmpty {
                Text("No workouts synced yet. Pull down to refresh.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(health.workouts.prefix(8)) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).font(.subheadline).fontWeight(.medium)
                            Text("\(w.date.formatted(date: .abbreviated, time: .shortened)) · \(w.source)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(w.minutes) min").font(.caption).fontWeight(.semibold)
                            Text("\(w.calories) cal").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
    }

    var treadmillCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Treadmill (manual)").font(.headline)
                Spacer()
                Button("+ Log") { showTreadmillSheet = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            let today = treadmillEntries.filter { Calendar.current.isDateInToday($0.date) }
            if today.isEmpty {
                Text("No treadmill sessions today")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(today) { entry in
                    HStack {
                        Image(systemName: "figure.run")
                        Text(String(format: "%.2f miles", entry.miles))
                        Spacer()
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
    }

    var treadmillSheet: some View {
        NavigationView {
            Form {
                Section("Distance walked on treadmill") {
                    TextField("Miles (e.g. 1.5)", text: $treadmillInput)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log Treadmill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTreadmillSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let miles = Double(treadmillInput) {
                            treadmillEntries.insert(TreadmillEntry(miles: miles, date: Date()), at: 0)
                            saveTreadmill()
                        }
                        treadmillInput = ""
                        showTreadmillSheet = false
                    }
                }
            }
        }
    }

    func loadTreadmill() {
        if let decoded = try? JSONDecoder().decode([TreadmillEntry].self, from: treadmillData) {
            treadmillEntries = decoded
        }
    }
    func saveTreadmill() {
        if let encoded = try? JSONEncoder().encode(treadmillEntries) {
            treadmillData = encoded
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.blue)
            Text(value).font(.title3).fontWeight(.semibold)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview { StepsView() }
