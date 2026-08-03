import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            if granted { self.scheduleAll() }
        }
    }

    func scheduleAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        scheduleMorning()
        scheduleWaterReminders()
        scheduleStandReminders()
        scheduleSupplementReminder()
        scheduleSleepReminder()
    }

    private func notify(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMorning() {
        notify(id: "morning", title: "Good morning, Sidd! 🌅",
               body: "Supplements first, then water. Let's make today count 💪",
               hour: 8, minute: 30)
    }

    private func scheduleWaterReminders() {
        let schedule: [(Int, Int, String)] = [
            (10, 0,  "Work day started — log your first glass of water 💧"),
            (12, 0,  "Halfway through the day — how's the water? 💧"),
            (14, 0,  "2pm check — keep drinking, don't let it slip 💧"),
            (16, 0,  "4pm — almost there, push to that gallon 💧"),
            (18, 0,  "End of work — last push for your water goal 💧"),
        ]
        for (i, item) in schedule.enumerated() {
            notify(id: "water_\(i)", title: "Drink water 💧",
                   body: item.2, hour: item.0, minute: item.1)
        }
    }

    private func scheduleStandReminders() {
        let schedule: [(Int, Int)] = [(11,0),(13,0),(15,0),(17,0)]
        for (i, time) in schedule.enumerated() {
            notify(id: "stand_\(i)", title: "Stand up! 🧍",
                   body: "You've been sitting a while — 3 min walk or stretch. Your back will thank you.",
                   hour: time.0, minute: time.1)
        }
    }

    private func scheduleSupplementReminder() {
        notify(id: "supplements", title: "Supplements 💊",
               body: "Did you take your supplements today? Log them in FitSidd!",
               hour: 9, minute: 0)
    }

    private func scheduleSleepReminder() {
        notify(id: "sleep", title: "Put the phone down, Sidd 😴",
               body: "Recovery is part of the grind. Sleep = gains. Rest up 💤",
               hour: 22, minute: 30)
    }
}
