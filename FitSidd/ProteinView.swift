import SwiftUI

struct ProteinEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var description: String
    var protein: Double
    var time: Date
}

struct SavedFood: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var grams: Double
    var emoji: String
}

let defaultFoods: [SavedFood] = [
    SavedFood(name: "Tofu 200g", grams: 17, emoji: "⬜️"),
    SavedFood(name: "Paneer 100g", grams: 18, emoji: "🧀"),
    SavedFood(name: "Dal 1 bowl", grams: 9, emoji: "🍲"),
    SavedFood(name: "Greek yogurt", grams: 17, emoji: "🥛"),
    SavedFood(name: "3 eggs", grams: 18, emoji: "🥚"),
    SavedFood(name: "Peanut butter 2 tbsp", grams: 8, emoji: "🥜"),
]

struct ProteinView: View {
    @AppStorage("proteinAllEntries") private var entriesData: Data = Data()
    @AppStorage("savedFoodsData") private var foodsData: Data = Data()
    @AppStorage("proteinGoal") private var goal: Double = 150
    @AppStorage("didSeedFoods") private var didSeedFoods: Bool = false

    @State private var entries: [ProteinEntry] = []
    @State private var foods: [SavedFood] = []
    @State private var mealInput = ""
    @State private var isLoading = false
    @State private var tab = 0
    @State private var editingEntry: ProteinEntry? = nil
    @State private var editingFood: SavedFood? = nil
    @State private var showGoalSheet = false
    @State private var showAddFood = false
    @State private var showManualSheet = false
    @FocusState private var isFocused: Bool

    // MARK: - Computed

    var todayEntries: [ProteinEntry] { entries(on: Date()) }
    var todayTotal: Double { total(on: Date()) }

    func entries(on date: Date) -> [ProteinEntry] {
        entries.filter { Calendar.current.isDate($0.time, inSameDayAs: date) }
               .sorted { $0.time > $1.time }
    }

    func total(on date: Date) -> Double {
        entries(on: date).reduce(0) { $0 + $1.protein }
    }

    var last7Days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    }

    var weekAverage: Double {
        let active = last7Days.map { total(on: $0) }.filter { $0 > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0, +) / Double(active.count)
    }

    var streak: Int {
        var c = 0
        for day in last7Days {
            if total(on: day) >= goal { c += 1 } else { break }
        }
        return c
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Today").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if tab == 0 { todayView } else { historyView }
            }
            .scrollContentBackground(.hidden)
                        .navigationTitle("Protein").navigationTitle("Protein")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showGoalSheet = true } label: { Image(systemName: "target") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                }
            }
            .onAppear { loadAll() }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry) { updated in
                    if let i = entries.firstIndex(where: { $0.id == updated.id }) {
                        entries[i] = updated; saveEntries()
                    }
                } onDelete: { toDelete in
                    entries.removeAll { $0.id == toDelete.id }; saveEntries()
                }
            }
            .sheet(item: $editingFood) { food in
                FoodSheet(food: food) { updated in
                    if let i = foods.firstIndex(where: { $0.id == updated.id }) {
                        foods[i] = updated; saveFoods()
                    }
                } onDelete: { toDelete in
                    foods.removeAll { $0.id == toDelete.id }; saveFoods()
                }
            }
            .sheet(isPresented: $showAddFood) {
                FoodSheet(food: nil) { newFood in
                    foods.append(newFood); saveFoods()
                } onDelete: { _ in }
            }
            .sheet(isPresented: $showGoalSheet) { goalSheet }
            .sheet(isPresented: $showManualSheet) { manualSheet }
        }
    }

    // MARK: - Today

    var todayView: some View {
        ScrollView {
            VStack(spacing: 16) {
                progressCard
                quickAddSection
                aiInputSection
                todayLogSection
            }
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    var progressCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(todayTotal))g")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(todayTotal >= goal ? .green : .primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("of \(Int(goal))g").font(.headline).foregroundStyle(.secondary)
                    if todayTotal >= goal {
                        Text("✅ Goal hit!").font(.caption).foregroundStyle(.green)
                    } else {
                        Text("\(Int(goal - todayTotal))g to go")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            ProgressView(value: min(todayTotal, goal), total: goal)
                .tint(todayTotal >= goal ? .green : .blue)
            HStack {
                miniStat("Week avg", "\(Int(weekAverage))g")
                Divider().frame(height: 30)
                miniStat("Streak", "\(streak) days")
                Divider().frame(height: 30)
                miniStat("Meals", "\(todayEntries.count)")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My foods").font(.headline)
                Spacer()
                Text("tap to log · hold to edit")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { showAddFood = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2).foregroundStyle(.blue)
                            Text("Add food")
                                .font(.caption2).foregroundStyle(.blue)
                        }
                        .frame(width: 88, height: 84)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    ForEach(foods) { food in
                        Button { addEntry(food.name, food.grams) } label: {
                            VStack(spacing: 4) {
                                Text(food.emoji).font(.title3)
                                Text(food.name)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                Text("\(Int(food.grams))g")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                            .frame(width: 88, height: 84)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingFood = food } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                foods.removeAll { $0.id == food.id }; saveFoods()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    var aiInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Describe a meal").font(.headline)
                Spacer()
                Button("+ Manual") { showManualSheet = true }.font(.caption)
            }
            .padding(.horizontal)

            TextField("e.g. 1 plate dal rice, tofu curry, 2 rotis",
                      text: $mealInput, axis: .vertical)
                .lineLimit(1...4)
                .focused($isFocused)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            Button(action: calculateProtein) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Image(systemName: "sparkles")
                    Text(isLoading ? "Calculating..." : "Calculate with AI")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding()
                .background(mealInput.isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(mealInput.isEmpty || isLoading)
            .padding(.horizontal)
        }
    }

    var todayLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's log").font(.headline).padding(.horizontal)

            if todayEntries.isEmpty {
                Text("Nothing logged yet — tap a food above")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayEntries) { entry in
                        Button { editingEntry = entry } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.description)
                                        .font(.subheadline).foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text(entry.time.formatted(date: .omitted, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(entry.protein))g")
                                    .fontWeight(.bold).foregroundStyle(.green)
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - History

    var historyView: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("7-day average").font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(weekAverage))g").font(.title2).fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Current streak").font(.caption).foregroundStyle(.secondary)
                        Text("\(streak) days 🔥").font(.title2).fontWeight(.bold)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Last 7 days") {
                ForEach(last7Days, id: \.self) { day in
                    let dayTotal = total(on: day)
                    let dayEntries = entries(on: day)

                    DisclosureGroup {
                        if dayEntries.isEmpty {
                            Text("No meals logged").font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(dayEntries) { entry in
                                Button { editingEntry = entry } label: {
                                    HStack {
                                        Text(entry.description)
                                            .font(.caption).foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(Int(entry.protein))g")
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundStyle(.green)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dayLabel(day)).fontWeight(.medium)
                                Text(day.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(dayTotal))g").fontWeight(.bold)
                                    .foregroundStyle(dayTotal >= goal ? .green : .primary)
                                Text("\(Int(goal))g goal")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Circle()
                                .fill(dayTotal >= goal ? Color.green :
                                      dayTotal > 0 ? Color.orange : Color(.systemGray4))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
    }

    func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    // MARK: - Sheets

    var goalSheet: some View {
        NavigationView {
            Form {
                Section("Daily protein goal") {
                    HStack {
                        Text("\(Int(goal))g").font(.title).fontWeight(.bold)
                        Spacer()
                        Stepper("", value: $goal, in: 50...300, step: 5).labelsHidden()
                    }
                }
                Section {
                    Text("Tip: aim for ~0.8–1g per pound of bodyweight if building muscle.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showGoalSheet = false }
                }
            }
        }
    }

    @State private var manualName = ""
    @State private var manualGrams = ""

    var manualSheet: some View {
        NavigationView {
            Form {
                Section("One-off entry") {
                    TextField("What did you eat?", text: $manualName)
                    TextField("Protein (grams)", text: $manualGrams)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manualName = ""; manualGrams = ""; showManualSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let g = Double(manualGrams), !manualName.isEmpty {
                            addEntry(manualName, g)
                        }
                        manualName = ""; manualGrams = ""; showManualSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Data

    func addEntry(_ name: String, _ grams: Double) {
        entries.insert(ProteinEntry(description: name, protein: grams, time: Date()), at: 0)
        saveEntries()
    }

    func loadAll() {
        if let decoded = try? JSONDecoder().decode([ProteinEntry].self, from: entriesData) {
            entries = decoded
        }
        if let decoded = try? JSONDecoder().decode([SavedFood].self, from: foodsData), !decoded.isEmpty {
            foods = decoded
        } else if !didSeedFoods {
            foods = defaultFoods
            didSeedFoods = true
            saveFoods()
        }
    }

    func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) { entriesData = encoded }
    }

    func saveFoods() {
        if let encoded = try? JSONEncoder().encode(foods) { foodsData = encoded }
    }

    // MARK: - AI

    func calculateProtein() {
        isFocused = false
        isLoading = true
        let meal = mealInput
        let prompt = """
        The user ate: \(meal)
        Estimate total protein in grams. Reply with ONLY a number.
        No units, no explanation. Use standard nutrition values.
        For Indian and vegetarian food use typical serving sizes.
        """

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            isLoading = false; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 10
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String,
                      let protein = Double(content.trimmingCharacters(in: .whitespacesAndNewlines))
                else { return }
                addEntry(meal, protein)
                mealInput = ""
            }
        }.resume()
    }
}

// MARK: - Food Sheet

struct FoodSheet: View {
    let food: SavedFood?
    let onSave: (SavedFood) -> Void
    let onDelete: (SavedFood) -> Void

    @State private var name = ""
    @State private var grams = ""
    @State private var emoji = "🥤"
    @Environment(\.dismiss) private var dismiss

    let emojiOptions = ["🥤","🍶","🧃","🥛","🍫","🍪","🥜","🥚","🧀","🍲","⬜️","🫘","🍗","🐟","🍚","🥗"]

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("e.g. Optimum Nutrition Gold Std", text: $name)
                }
                Section("Protein per serving") {
                    TextField("Grams (check the label)", text: $grams)
                        .keyboardType(.decimalPad)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title3)
                                    .padding(6)
                                    .background(emoji == e ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let food {
                    Section {
                        Button(role: .destructive) {
                            onDelete(food); dismiss()
                        } label: {
                            HStack { Spacer(); Label("Delete food", systemImage: "trash"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(food == nil ? "Add Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let g = Double(grams), !name.isEmpty else { return }
                        var item = food ?? SavedFood(name: "", grams: 0, emoji: "🥤")
                        item.name = name; item.grams = g; item.emoji = emoji
                        onSave(item); dismiss()
                    }
                }
            }
            .onAppear {
                if let food {
                    name = food.name; grams = String(Int(food.grams)); emoji = food.emoji
                }
            }
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    let entry: ProteinEntry
    let onSave: (ProteinEntry) -> Void
    let onDelete: (ProteinEntry) -> Void

    @State private var name: String = ""
    @State private var grams: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Meal") {
                    TextField("Description", text: $name, axis: .vertical).lineLimit(1...4)
                }
                Section("Protein") {
                    TextField("Grams", text: $grams).keyboardType(.decimalPad)
                }
                Section {
                    Text(entry.time.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button(role: .destructive) {
                        onDelete(entry); dismiss()
                    } label: {
                        HStack { Spacer(); Label("Delete entry", systemImage: "trash"); Spacer() }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = entry
                        updated.description = name
                        updated.protein = Double(grams) ?? entry.protein
                        onSave(updated); dismiss()
                    }
                }
            }
            .onAppear { name = entry.description; grams = String(Int(entry.protein)) }
        }
    }
}

#Preview { ProteinView() }
