import Foundation

/// Lightweight, resource-free localization. The English string is the key; a
/// translation table provides other languages. This avoids SwiftPM resource
/// bundles (which are awkward to ship inside a hand-assembled .app) while still
/// giving Turkish users a localized UI. Unknown keys fall back to English.
enum L {
    static func t(_ key: String) -> String {
        guard let code = Locale.preferredLanguages.first?.prefix(2).lowercased(),
              let table = tables[String(code)],
              let value = table[key]
        else { return key }
        return value
    }

    /// Convenience for one interpolated argument, e.g. L.t("Stop monitoring %@", app.name).
    static func t(_ key: String, _ arg: String) -> String {
        t(key).replacingOccurrences(of: "%@", with: arg)
    }

    private static let tables: [String: [String: String]] = [
        "tr": [
            // Tabs & sections
            "Apps": "Uygulamalar",
            "Settings": "Ayarlar",
            "Menu bar": "Menü çubuğu",
            "On-screen alert": "Ekran uyarısı",
            "General": "Genel",
            "Permissions": "İzinler",
            // Menu-bar settings
            "Show unread count": "Okunmamış sayısını göster",
            "Off: show a small red dot instead of the number.": "Kapalı: sayı yerine küçük kırmızı nokta gösterir.",
            "Only show an app when it has a notification": "Uygulamayı yalnızca bildirim varken göster",
            "Hides the icon completely until there's an unread badge.": "Okunmamış rozet gelene kadar ikonu tamamen gizler.",
            "Dim the icon when there's no notification": "Bildirim yokken ikonu soluklaştır",
            "Greys out the icon instead of hiding it. Ignored when the option above is on.": "Gizlemek yerine ikonu grileştirir. Üstteki seçenek açıkken yok sayılır.",
            "Hide an app when it isn't running": "Çalışmıyorken uygulamayı gizle",
            "Removes the icon while the app is closed.": "Uygulama kapalıyken ikonu kaldırır.",
            "Always show a BadgeBar icon": "Her zaman bir BadgeBar ikonu göster",
            "Keeps a small BadgeBar icon in the menu bar for quick access, even when nothing has a notification.": "Hiç bildirim yokken bile hızlı erişim için menü çubuğunda küçük bir BadgeBar ikonu tutar.",
            // On-screen alert
            "Show a floating alert on new messages": "Yeni mesajda ekranda uyarı göster",
            "Appears briefly on top of everything — even full-screen apps.": "Her şeyin üstünde kısa süre belirir — tam ekran uygulamalar dahil.",
            "Stay on screen for": "Ekranda kalma süresi",
            "2 seconds": "2 saniye",
            "4 seconds": "4 saniye",
            "6 seconds": "6 saniye",
            // General
            "Launch BadgeBar at login": "Girişte BadgeBar'ı başlat",
            "Poll interval": "Yoklama aralığı",
            "1 second (default)": "1 saniye (varsayılan)",
            "5 seconds": "5 saniye",
            "Check for Updates…": "Güncellemeleri Denetle…",
            // Permissions
            "Accessibility access": "Erişilebilirlik erişimi",
            "Granted — badges can be read from the Dock.": "Verildi — rozetler Dock'tan okunabilir.",
            "Required to read badges from the Dock.": "Rozetleri Dock'tan okumak için gerekli.",
            "Open Settings": "Ayarları Aç",
            "About": "Hakkında",
            "Quit BadgeBar": "BadgeBar'dan Çık",
            // Picker / list
            "Search apps…": "Uygulama ara…",
            "Monitoring": "İzlenen",
            "All apps": "Tüm uygulamalar",
            "Version %@": "Sürüm %@",
            "Add": "Ekle",
            "Remove": "Kaldır",
            "Drag to reorder how icons appear in the menu bar.": "Menü çubuğundaki ikon sırasını değiştirmek için sürükleyin.",
            // Status item menus
            "Configure…": "Yapılandır…",
            "Stop monitoring %@": "%@ izlemeyi durdur",
            "This app": "Bu uygulama",
            "Reset to defaults": "Varsayılana döndür",
            // Tooltips
            "BadgeBar needs Accessibility access — click to grant": "BadgeBar erişilebilirlik izni gerektiriyor — vermek için tıklayın",
            "BadgeBar — click to configure, right-click for menu": "BadgeBar — yapılandırmak için tıklayın, menü için sağ tık",
            // Alert
            "New notification": "Yeni bildirim",
            // Update check
            "You're up to date": "Güncelsiniz",
            "BadgeBar %@ is the latest version.": "BadgeBar %@ en son sürüm.",
            "Update available": "Güncelleme var",
            "Download": "İndir",
            "Later": "Sonra",
            "OK": "Tamam",
            "Couldn't check for updates": "Güncellemeler denetlenemedi",
            "Please try again later.": "Lütfen daha sonra tekrar deneyin.",
        ],
    ]
}
