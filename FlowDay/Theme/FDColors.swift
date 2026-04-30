import SwiftUI

// FDColors_Updated.swift
// FlowDay — Dark Mode Support
//
// REPLACES the original FDColors.swift
// Uses UIColor dynamic providers to automatically adapt to light/dark mode.
// Remove `.preferredColorScheme(.light)` from your app entry point to enable dark mode.

extension Color {
    /// Initialize Color from hex string (for backward compatibility and manual use)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    /// Convert Color to hex string
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

extension UIColor {
    /// Initialize UIColor from hex string
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - Design System Colors (as Color extensions, matching original API)
// Every view in the codebase uses Color.fdBackground, Color.fdText, etc.
// These now adapt automatically to light/dark mode.

extension Color {

    // MARK: - Background & Surface

    /// Primary background color — warm light beige (#FAF8F5) or warm dark (#1C1917).
    /// The "Dark" theme overrides this to pure OLED black.
    static var fdBackground: Color {
        Color(UIColor { traits in
            if ThemeManager.isOLEDBlack { return .black }
            return traits.userInterfaceStyle == .dark
                ? UIColor(hex: "1C1917")
                : UIColor(hex: "FAF8F5")
        })
    }

    /// Primary surface color — white (#FFFFFF) or dark warm gray (#292524).
    /// "Dark" theme uses near-black (#0A0A0A) for layered cards on OLED.
    static var fdSurface: Color {
        Color(UIColor { traits in
            if ThemeManager.isOLEDBlack { return UIColor(hex: "0A0A0A") }
            return traits.userInterfaceStyle == .dark
                ? UIColor(hex: "292524")
                : UIColor(hex: "FFFFFF")
        })
    }

    /// Surface hover state — light gray (#F7F5F2) or darker warm gray (#342F2B).
    static var fdSurfaceHover: Color {
        Color(UIColor { traits in
            if ThemeManager.isOLEDBlack { return UIColor(hex: "1A1A1A") }
            return traits.userInterfaceStyle == .dark
                ? UIColor(hex: "342F2B")
                : UIColor(hex: "F7F5F2")
        })
    }

    // MARK: - Borders

    /// Primary border color — light warm gray (#E8E4DE) or dark border (#44403C)
    static let fdBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "44403C")
            : UIColor(hex: "E8E4DE")
    })

    /// Light border — very light gray (#F0ECE6) or subtle dark (#3A3632)
    static let fdBorderLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "3A3632")
            : UIColor(hex: "F0ECE6")
    })

    // MARK: - Text

    /// Primary text — dark brown (#1A1714) or light (#F5F5F4)
    static let fdText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "F5F5F4")
            : UIColor(hex: "1A1714")
    })

    /// Secondary text — medium brown (#6B6560) or light warm gray (#A8A29E)
    static let fdTextSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "A8A29E")
            : UIColor(hex: "6B6560")
    })

    /// Muted text — light brown (#A09A94) or muted light (#78716C)
    static let fdTextMuted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "78716C")
            : UIColor(hex: "A09A94")
    })

    // MARK: - Accent (Primary Brand Color)

    /// Primary accent — driven by the active theme. Warm orange by default.
    static var fdAccent: Color { ThemeManager.accent }

    /// Light accent background — very light peach (#FDF0E8) or dark tinted (#3D2518)
    static let fdAccentLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "3D2518")
            : UIColor(hex: "FDF0E8")
    })

    /// Soft accent — warm orange (#E89B6C), same in both modes
    static let fdAccentSoft = Color(hex: "E89B6C")

    // MARK: - Status Colors (Green)

    /// Success/positive green — medium green (#5BA065) or brighter green (#6BBF75)
    static let fdGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "6BBF75")
            : UIColor(hex: "5BA065")
    })

    /// Light green background — very light green (#EDF7EE) or dark green tint (#1A2E1C)
    static let fdGreenLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "1A2E1C")
            : UIColor(hex: "EDF7EE")
    })

    // MARK: - Status Colors (Blue)

    /// Info/primary blue — medium blue (#5B8FD4) or brighter blue (#6B9FE4)
    static let fdBlue = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "6B9FE4")
            : UIColor(hex: "5B8FD4")
    })

    /// Light blue background — very light blue (#EBF2FC) or dark blue tint (#1A2535)
    static let fdBlueLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "1A2535")
            : UIColor(hex: "EBF2FC")
    })

    // MARK: - Status Colors (Purple)

    /// Purple accent — medium purple (#8B6BBF) or brighter purple (#9B7BCF)
    static let fdPurple = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "9B7BCF")
            : UIColor(hex: "8B6BBF")
    })

    /// Light purple background — very light purple (#F3EEFB) or dark purple tint (#251E35)
    static let fdPurpleLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "251E35")
            : UIColor(hex: "F3EEFB")
    })

    // MARK: - Status Colors (Red)

    /// Error/warning red — medium red (#D45B5B) or brighter red (#E46B6B)
    static let fdRed = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "E46B6B")
            : UIColor(hex: "D45B5B")
    })

    /// Light red background — very light red (#FCEBEB) or dark red tint (#351A1A)
    static let fdRedLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "351A1A")
            : UIColor(hex: "FCEBEB")
    })

    // MARK: - Status Colors (Yellow)

    /// Warning yellow — warm yellow (#D4A73B) or brighter yellow (#E4B74B)
    static let fdYellow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "E4B74B")
            : UIColor(hex: "D4A73B")
    })

    /// Light yellow background — very light yellow (#FDF6E8) or dark yellow tint (#352E18)
    static let fdYellowLight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "352E18")
            : UIColor(hex: "FDF6E8")
    })
}
