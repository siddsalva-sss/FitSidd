# FitSidd 🏋️

A personal iOS fitness tracker built with SwiftUI. It brings workouts, steps, protein, water and daily habits into one app.

## Features

- **Workouts:** Push / Pull / Legs routines with warm-ups, sets, reps and alternate exercises
- **Steps:** daily steps, distance and active calories from Apple Health, live walking pace, and manual treadmill miles
- **Protein:** describe a meal in plain English and AI estimates the protein, or log saved foods in one tap
- **Dashboard:** water bottles, supplement checklist and a stand-up timer
- **Reminders:** scheduled nudges for water, standing, supplements and sleep

## Built with

SwiftUI · SwiftData · HealthKit · CoreMotion · UserNotifications · OpenAI API (gpt-4o-mini)

## Download and run it

iPhone apps can't be installed straight from GitHub, so you build it onto your phone with Xcode (free). You need a Mac with Xcode and an iPhone; HealthKit and step counting don't fully work in the simulator.

1. Download the code: click the green **Code** button above, then **Download ZIP**. Or clone it:

   ```bash
   git clone https://github.com/siddsalva-sss/FitSidd.git
   ```

2. Copy `Secrets.example.swift` into the `FitSidd` folder, rename it to `Secrets.swift`, and paste in your own OpenAI API key. The AI protein estimate needs it; everything else works without a real key, but the file must exist for the app to build.
3. Open `FitSidd.xcodeproj`, choose your own team under **Signing & Capabilities** (a free Apple ID works) and change the Bundle Identifier to something unique (for example `com.yourname.FitSidd`), connect your iPhone and press **Run**.

`Secrets.swift` is in `.gitignore`, so your key never gets committed.
