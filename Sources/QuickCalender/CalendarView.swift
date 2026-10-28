import SwiftUI
import CalendarCore

extension Color {
    static let calAccent = Color(red: 0.24, green: 0.34, blue: 0.88)
    static let calMuted = Color.secondary
}

struct CalendarView: View {
    @ObservedObject var model: AppModel
    var viewportSize = CalendarPopupLayout.preferredSize
    @State private var showJump = false
    private var calendar: Calendar { model.engine.calendar }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 14) {
                    monthHeader
                    calendarGrid
                    DateWeatherCard(model: model)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(width: viewportSize.width, height: viewportSize.height)
        .clipped()
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.calAccent)
        .preferredColorScheme(model.colorScheme)
    }

    private var monthHeader: some View {
        HStack {
            Button { showJump.toggle() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(calendar.component(.month, from: model.displayedMonth))月")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(String(calendar.component(.year, from: model.displayedMonth)))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain).help("选择年份和月份")
                .popover(isPresented: $showJump, arrowEdge: .bottom) {
                    MonthJumpView(model: model, isPresented: $showJump)
                }
            Spacer()
            Button { model.today() } label: {
                Text("今天").font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.calAccent.opacity(0.08), in: Capsule())
            }.buttonStyle(.plain).foregroundStyle(Color.calAccent).help("回到今天（⌘T）").keyboardShortcut("t", modifiers: .command)
            Button { model.moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 22, height: 26) }
                .buttonStyle(.plain).help("上个月").keyboardShortcut(.leftArrow, modifiers: .command)
                .accessibilityLabel("上个月")
            Button { model.moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 22, height: 26) }
                .buttonStyle(.plain).help("下个月").keyboardShortcut(.rightArrow, modifiers: .command)
                .accessibilityLabel("下个月")
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(day == "六" || day == "日" ? Color.calAccent.opacity(0.7) : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            let days = model.month.days
            VStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(days[(row * 7)..<(row * 7 + 7)]) { day in
                            dayCell(day)
                        }
                    }
                }
            }
        }
    }

    private var weekdays: [String] { model.preferences.mondayFirst ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"] }

    private func dayCell(_ day: CalendarDay) -> some View {
        let date = day.date
        let selected = calendar.isDate(date, inSameDayAs: model.selectedDate)
        let today = calendar.isDate(date, inSameDayAs: model.now)
        let inMonth = calendar.isDate(date, equalTo: model.displayedMonth, toGranularity: .month)
        let holiday = model.preferences.showFestivals ? day.festivals.first : nil
        let weather = model.preferences.showWeather ? model.forecast?.day(day.key) : nil
        let forecast = model.preferences.showDayWeather ? weather : nil
        let accessibility = dayAccessibility(day, weather: weather)
        return Button { model.select(date) } label: {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    Text(String(day.number))
                        .font(.system(size: 14, weight: selected || today ? .bold : .medium, design: .rounded))
                    if let forecast {
                        Image(systemName: WeatherCode.symbol(forecast.code))
                            .symbolRenderingMode(.hierarchical).font(.system(size: 7))
                    }
                }
                if model.preferences.showLunar || holiday != nil {
                    Text(holiday ?? day.lunar)
                        .font(.system(size: 9, weight: holiday == nil ? .regular : .medium))
                        .lineLimit(1).minimumScaleFactor(0.65)
                        .foregroundStyle(selected ? Color.white.opacity(0.8) : (holiday != nil ? Color.orange : Color.secondary))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 38)
            .foregroundStyle(selected ? Color.white : (today ? Color.calAccent : Color.primary))
            .background {
                if selected { RoundedRectangle(cornerRadius: 10).fill(Color.calAccent).shadow(color: .calAccent.opacity(0.22), radius: 4, y: 2) }
                else if today { RoundedRectangle(cornerRadius: 10).fill(Color.calAccent.opacity(0.09)) }
            }
            .opacity(inMonth ? 1 : 0.3)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(accessibility)
    }

    private func dayAccessibility(_ day: CalendarDay, weather: WeatherDay?) -> String {
        var parts = [day.accessibleDate]
        if model.preferences.showLunar { parts.append("农历" + day.fullLunar) }
        if model.preferences.showFestivals { parts += day.festivals }
        if let weather { parts.append("\(WeatherCode.label(weather.code))，\(Int(weather.low.rounded()))至\(Int(weather.high.rounded()))度") }
        return parts.joined(separator: "，")
    }

    private var footer: some View {
        HStack {
            if model.preferences.showWeather {
                Link("天气 · Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            } else { Text("每一天，都从容有序").font(.system(size: 10)).foregroundStyle(.tertiary) }
            Spacer()
            Button { model.showSettings?() } label: {
                Label("设置", systemImage: "slider.horizontal.3").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundStyle(.secondary).keyboardShortcut(",", modifiers: .command)
            Divider().frame(height: 12).padding(.horizontal, 4)
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundStyle(.secondary).help("退出快捷日历").accessibilityLabel("退出快捷日历")
        }
        .padding(.horizontal, 22).padding(.vertical, 13)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
    }
}

struct MonthJumpView: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool
    @State private var year = 2026
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { if year > 1901 { year -= 1 } } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).accessibilityLabel("上一年")
                Picker("年份", selection: $year) { ForEach(1901...2099, id: \.self) { Text(String($0) + "年").tag($0) } }.labelsHidden().frame(width: 120)
                Button { if year < 2099 { year += 1 } } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).accessibilityLabel("下一年")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(58)), count: 4), spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    Button { model.jump(year: year, month: month); isPresented = false } label: {
                        Text("\(month)月").font(.system(size: 12, weight: .medium)).frame(width: 54, height: 32)
                            .background(Color.calAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(18).onAppear { year = model.engine.calendar.component(.year, from: model.displayedMonth) }
    }
}
