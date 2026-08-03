import SwiftUI
import UserNotifications

struct DashboardView: View {
    @Binding var selection: Int
    @State private var health = HealthKitManager()

    @AppStorage("waterBottles") private var waterBottles: Int = 0
    @AppStorage("waterDate") private var waterDate: String = ""
    @AppStorage("suppDate") private var suppDate: String = ""
    @AppStorage("suppMulti") private var suppMulti = false
    @AppStorage("suppMag") private var suppMag = false
    @AppStorage("suppTest") private var suppTest = false
    @AppStorage("suppCreatine") private var suppCreatine = false
    @AppStorage("suppB12") private var suppB12 = false
    @AppStorage("b12LastTaken") private var b12LastTaken = ""
    @AppStorage("proteinAllEntries") private var proteinData: Data = Data()
    @AppStorage("proteinGoal") private var proteinGoal: Double = 150
    @AppStorage("sessionsData") private var sessionsData: Data = Data()
    @AppStorage("stepGoal") private var stepGoal: Int = 10000

    @State private var isStanding = false
    @State private var countdown = 45 * 60
    @State private var sittingMinutes = 45
    @State private var countdownTimer: Timer? = nil
    @State private var showIntervalPicker = false

    let waterGoal = 8

    var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var todayProtein: Double {
        guard let all = try? JSONDecoder().decode([ProteinEntry].self, from: proteinData) else { return 0 }
        return all.filter { Calendar.current.isDateInToday($0.time) }
                  .reduce(0) { $0 + $1.protein }
    }

    var weekWorkouts: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var local = 0
        if let all = try? JSONDecoder().decode([WorkoutSession].self, from: sessionsData) {
            local = all.filter { $0.date > weekAgo }.count
        }
        let fromHealth = health.workouts.filter { $0.date > weekAgo }.count
        return max(local, fromHealth)
    }

    var isB12Day: Bool {
        guard !b12LastTaken.isEmpty else { return true }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let last = f.date(from: b12LastTaken) else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days != 1
    }

    var countdownString: String {
        String(format: "%02d:%02d", countdown / 60, countdown % 60)
    }

    var standColor: Color {
        if isStanding { return .green }
        let pct = Double(countdown) / Double(sittingMinutes * 60)
        if pct > 0.5 { return .cyan }
        if pct > 0.2 { return .orange }
        return .red
    }

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var motivation: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 10 { return "Supplements first, then hydrate 💧" }
        if h < 14 { return "Water, steps, movement — keep it rolling 🔥" }
        if h < 18 { return "Afternoon grind. Stand up, drink water 💪" }
        if h < 22 { return "Log your food and start winding down 🌙" }
        return "Sleep is where the gains happen 😴"
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        greetingCard
                        quickStats
                        standTimerCard
                        waterCard
                        supplementCard
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("FitSidd")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                resetIfNewDay()
                health.requestAuth()
                NotificationManager.shared.requestPermission()
                startCountdown()
            }
            .onDisappear { countdownTimer?.invalidate() }
        }
    }

    // MARK: - Greeting

    var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(greeting), Sidd 👋")
                .font(.title2).fontWeight(.bold)
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(motivation)
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
    }

    // MARK: - Quick Stats

    var quickStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(title: "Steps", value: "\(health.steps)", sub: "of \(stepGoal)",
                     icon: "figure.walk", color: .cyan,
                     progress: Double(health.steps) / Double(stepGoal)) { selection = 1 }

            statTile(title: "Protein", value: "\(Int(todayProtein))g", sub: "of \(Int(proteinGoal))g",
                     icon: "fork.knife", color: .green,
                     progress: todayProtein / proteinGoal) { selection = 2 }

            statTile(title: "Workouts", value: "\(weekWorkouts)", sub: "this week",
                     icon: "dumbbell.fill", color: .purple,
                     progress: Double(weekWorkouts) / 5.0) { selection = 3 }

            statTile(title: "Calories", value: "\(health.activeCalories)", sub: "active today",
                     icon: "flame.fill", color: .orange,
                     progress: Double(health.activeCalories) / 600.0) { selection = 1 }
        }
    }

    func statTile(title: String, value: String, sub: String,
                  icon: String, color: Color, progress: Double,
                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Text(value).font(.title2).fontWeight(.bold)
                Text(title).font(.caption).fontWeight(.medium)
                Text(sub).font(.caption2).foregroundStyle(.secondary)
                ProgressView(value: min(max(progress, 0), 1)).tint(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassCard(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stand Timer

    var standTimerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label(isStanding ? "Stand up!" : "Sit timer",
                      systemImage: isStanding ? "figure.stand" : "chair")
                    .font(.headline).foregroundStyle(standColor)
                Spacer()
                Button { showIntervalPicker.toggle() } label: {
                    Text("every \(sittingMinutes)m")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if showIntervalPicker {
                Picker("", selection: $sittingMinutes) {
                    Text("30m").tag(30); Text("45m").tag(45)
                    Text("60m").tag(60); Text("90m").tag(90)
                }
                .pickerStyle(.segmented)
                .onChange(of: sittingMinutes) { _, _ in resetSitTimer() }
            }

            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: isStanding
                          ? Double(countdown) / 180.0
                          : Double(countdown) / Double(sittingMinutes * 60))
                    .stroke(standColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdown)

                VStack(spacing: 2) {
                    Text(countdownString)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(standColor)
                    Text(isStanding ? "keep moving" : "until stand")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            if isStanding {
                Button("✓ Done standing") { finishStanding() }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .frame(maxWidth: .infinity)
            } else {
                Button("I'm standing early 🧍") { startStanding() }
                    .buttonStyle(.bordered).tint(.cyan)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Water

    var waterCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline).foregroundStyle(.cyan)
                Spacer()
                Text("\(waterBottles)/\(waterGoal) · \(waterBottles * 500)ml")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ProgressView(value: Double(waterBottles) / Double(waterGoal))
                .tint(waterBottles >= waterGoal ? .green : .cyan)

            HStack(spacing: 6) {
                ForEach(0..<waterGoal, id: \.self) { i in
                    Image(systemName: i < waterBottles ? "waterbottle.fill" : "waterbottle")
                        .font(.title3)
                        .foregroundStyle(i < waterBottles ? .cyan : .white.opacity(0.25))
                }
            }

            HStack {
                Button { if waterBottles > 0 { waterBottles -= 1 } } label: {
                    Image(systemName: "minus.circle").font(.title2).foregroundStyle(.red)
                }
                Spacer()
                Text(waterBottles >= waterGoal ? "✅ 4 litres done!"
                     : "\(waterGoal - waterBottles) bottles to go")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button { if waterBottles < waterGoal { waterBottles += 1 } } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.cyan)
                }
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Supplements

    var supplementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Supplements", systemImage: "pill.fill")
                .font(.headline).foregroundStyle(.purple)

            suppRow("Multivitamin", "🌿", $suppMulti)
            suppRow("Magnesium", "🪨", $suppMag)
            suppRow("Test Booster", "⚡️", $suppTest)
            suppRow("Creatine", "💪", $suppCreatine)

            if isB12Day {
                HStack {
                    Text("🔴")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("B12").font(.subheadline)
                        Text("today's B12 day").font(.caption2).foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        suppB12.toggle()
                        if suppB12 { b12LastTaken = todayString }
                    } label: {
                        Image(systemName: suppB12 ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(suppB12 ? .green : .white.opacity(0.3))
                    }
                }
            } else {
                HStack {
                    Text("🔴"); Text("B12").font(.subheadline)
                    Spacer()
                    Text("rest day").font(.caption).foregroundStyle(.secondary).italic()
                }
                .opacity(0.4)
            }
        }
        .padding()
        .glassCard()
    }

    func suppRow(_ name: String, _ icon: String, _ checked: Binding<Bool>) -> some View {
        HStack {
            Text(icon)
            Text(name).font(.subheadline)
            Spacer()
            Button { checked.wrappedValue.toggle() } label: {
                Image(systemName: checked.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked.wrappedValue ? .green : .white.opacity(0.3))
            }
        }
    }

    // MARK: - Timer logic

    func startCountdown() {
        countdownTimer?.invalidate()
        countdown = sittingMinutes * 60
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 { countdown -= 1 }
            else if !isStanding { startStanding() }
            else { finishStanding() }
        }
        scheduleStandNotification(sittingMinutes * 60)
    }

    func startStanding() {
        isStanding = true
        countdown = 180
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["stand_now"])
    }

    func finishStanding() {
        isStanding = false
        countdown = sittingMinutes * 60
        scheduleStandNotification(sittingMinutes * 60)
    }

    func resetSitTimer() {
        isStanding = false
        countdown = sittingMinutes * 60
        scheduleStandNotification(sittingMinutes * 60)
    }

    func scheduleStandNotification(_ seconds: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["stand_now"])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Stand up, Sidd! 🧍"
        content.body = "You've been sitting \(sittingMinutes) min — 3 minute walk 🚶"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "stand_now", content: content, trigger: trigger))
    }

    func resetIfNewDay() {
        let today = todayString
        if waterDate != today { waterDate = today; waterBottles = 0 }
        if suppDate != today {
            suppDate = today
            suppMulti = false; suppMag = false
            suppTest = false; suppCreatine = false; suppB12 = false
        }
    }
}

#Preview { DashboardView(selection: .constant(0)) }
