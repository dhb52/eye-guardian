import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let categoryIdentifier = "breakCategory"
    static let startAction = "startBreak"
    static let skipAction = "skipBreak"

    var onStartBreak: (() -> Void)?
    var onSkip: (() -> Void)?
    var onOpenApp: (() -> Void)?

    func start(onAuthorization: @escaping (UNAuthorizationStatus) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let start = UNNotificationAction(identifier: Self.startAction,
                                         title: L10n.t("BreakStartAction"),
                                         options: [.foreground])
        let skip = UNNotificationAction(identifier: Self.skipAction,
                                        title: L10n.t("BreakSkipAction"),
                                        options: [])
        let category = UNNotificationCategory(identifier: Self.categoryIdentifier,
                                              actions: [start, skip],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
        requestAuthorization(completion: onAuthorization)
    }

    func requestAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    completion(settings.authorizationStatus)
                }
            }
        }
    }

    func refreshAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    func postBreakReminder() {
        post(title: L10n.t("PreBreakTitle"),
             body: L10n.t("TakeABreak"),
             category: true)
    }

    func postPreReminder() {
        post(title: L10n.t("PreBreakTitle"),
             body: L10n.t("PreBreakBody"),
             category: false)
    }

    func postExtraReminder(hours: Int) {
        post(title: L10n.t("ScreenTime"),
             body: L10n.f("ExtraReminderBody", hours),
             category: false)
    }

    func postBreakStarted() {
        post(title: L10n.t("PreBreakTitle"),
             body: L10n.t("TakeABreak"),
             category: false)
    }

    private func post(title: String, body: String, category: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if category {
            content.categoryIdentifier = Self.categoryIdentifier
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        Task { @MainActor in
            switch action {
            case Self.startAction:
                self.onStartBreak?()
            case Self.skipAction:
                self.onSkip?()
            default:
                self.onOpenApp?()
            }
        }
        completionHandler()
    }
}
