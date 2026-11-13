import SwiftUI
import WidgetKit

/// «Сканер цен»: открывает Cento сразу на камере, которая пересчитывает цены на ценниках и в меню.
/// Камеру в самом виджете iOS не запускает, поэтому виджет — кнопка-ссылка cento://scan.
struct ScanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScanWidget", provider: ScanProvider()) { _ in
            ScanWidgetView()
        }
        .configurationDisplayName("Scan Prices")
        .description("Point the camera at a price tag or menu to convert it")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct ScanEntry: TimelineEntry {
    let date: Date
}

/// Содержимое не меняется — одна запись без обновлений.
struct ScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScanEntry { ScanEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ScanEntry) -> Void) { completion(ScanEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanEntry>) -> Void) {
        completion(Timeline(entries: [ScanEntry(date: .now)], policy: .never))
    }
}

struct ScanWidgetView: View {
    @Environment(\.widgetFamily) private var family

    /// Акцентный цвет приложения (как у кнопки «Готово»).
    private static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE9 / 255, green: 0xB3 / 255, blue: 0xFB / 255, alpha: 1)
            : UIColor(red: 0xDA / 255, green: 0x9C / 255, blue: 0xF6 / 255, alpha: 1)
    })

    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 26, weight: .medium))
                }
                .containerBackground(for: .widget) { Color.clear }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Self.accent))
                    Spacer(minLength: 8)
                    Text("Scan Prices")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: "€ → $")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { Color(.systemBackground) }
            }
        }
        .widgetURL(URL(string: "cento://scan"))
    }
}
