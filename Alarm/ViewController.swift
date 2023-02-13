//
//  ViewController.swift
//  Alarm
//

import UIKit
import UserNotifications

struct Alarm {
    private var notificationId: String
    
    var date: Date
    
    init(date: Date, notificationId: String? = nil) {
        self.date = date
        self.notificationId = notificationId ?? UUID().uuidString
    }
    
    func schedule(completion: @escaping (Bool) -> ()) {
        // Create local notifications when an alarm gets set and when the user decides to snooze an alarm.
        authorizeIfNeeded { (granted) in
            guard granted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                
                return
            }
            
            // Create the notification content and specify the notification's category identifier.
            let content = UNMutableNotificationContent()
            content.title = "Alarm"
            content.body = "Beep Beep"
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = Alarm.notificationCategoryId
            
            // Create the notification's trigger.
            let triggerDateComponents = Calendar.current.dateComponents([.minute, .hour, .day, .month, .year], from: self.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
            
            // Create the notification request.
            let request = UNNotificationRequest(identifier: self.notificationId, content: content, trigger: trigger)
            
            // Schedule the notification.
            UNUserNotificationCenter.current().add(request) {
                (error: Error?) in DispatchQueue.main.async {
                    if let error = error {
                        print(error.localizedDescription)
                        completion(false)
                    } else {
                        Alarm.scheduled = self
                        completion(true)
                    }
                }
            }
        }
    }
    
    func unschedule() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        Alarm.scheduled = nil
    }
}

private func authorizeIfNeeded(completion: @escaping (Bool) -> ()) {
    // Notification permission (the first time when a user schedules an alarm).
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.getNotificationSettings { (settings) in
        switch settings.authorizationStatus {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            notificationCenter.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { (granted, _) in completion(granted)
            })
            
        case .denied, .provisional, .ephemeral:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}

extension Alarm: Codable {
    static let notificationCategoryId = "AlarmNotification"
    static let snoozeActionID = "snooze"
    
    private static let alarmURL: URL = {
        guard let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Can't get URL for documents directory.")
        }
        
        return baseURL.appendingPathComponent("ScheduledAlarm")
    }()
    
    static var scheduled: Alarm? {
        get {
            guard let data = try? Data(contentsOf: alarmURL) else {
                return nil
            }
            
            return try? JSONDecoder().decode(Alarm.self, from: data)
        }
        
        set {
            if let alarm = newValue {
                guard let data = try? JSONEncoder().encode(alarm) else {
                    return
                }
                try? data.write(to: alarmURL)
            } else {
                try? FileManager.default.removeItem(at: alarmURL)
            }
            
            NotificationCenter.default.post(name: .alarmUpdated, object: nil)
        }
    }
}

class ViewController: UIViewController {

    @IBOutlet var datePicker: UIDatePicker!
    
    @IBOutlet var alarmLabel: UILabel!
    
    @IBOutlet var scheduleButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .alarmUpdated, object: nil)
    }
    
    func presentNeedAuthorizationAlert() {
        let title = "Authorization Needed"
        let message = "Alarms don't work without notifications, and it looks like you haven't granted us permission to send you those. Please go to the iOS Settings app and grant us notification permissions."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Okay", style: .default, handler: nil)
        
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }

    @IBAction func setAlarmButtonTapped(_ sender: UIButton) {
        if let alarm = Alarm.scheduled {
            alarm.unschedule()
        } else {
            let alarm = Alarm(date: datePicker.date)
            alarm.schedule { [weak self] (permissionGranted) in
                if !permissionGranted {
                    self?.presentNeedAuthorizationAlert()
                }
            }
        }
    }
    
    @objc func updateUI() {
        if let scheduledAlarm = Alarm.scheduled {
            let formattedAlarm = scheduledAlarm.date.formatted(.dateTime
                .day(.defaultDigits)
                .month(.defaultDigits)
                .year(.twoDigits)
                .hour().minute())
            alarmLabel.text = "Your alarm is scheduled for \(formattedAlarm)"
            datePicker.isEnabled = false
            scheduleButton.setTitle("Remove Alarm", for: .normal)
        } else {
            alarmLabel.text = "Set an alarm below"
            datePicker.isEnabled = true
            scheduleButton.setTitle("Set Alarm", for: .normal)
        }
    }
}

