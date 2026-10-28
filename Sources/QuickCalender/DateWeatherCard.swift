import SwiftUI
import CalendarCore

struct DateWeatherCard: View {
    @ObservedObject var model: AppModel
    private var day: CalendarDay { model.selectedDay }
    private var forecast: WeatherDay? { model.forecast?.day(day.key) }
    private var current: Forecast.Current? {
        guard model.engine.calendar.isDate(model.selectedDate, inSameDayAs: model.now),
              let weather = model.forecast,
              let zone = TimeZone(identifier: weather.timezone),
              model.engine.dayKey(model.now, timeZone: zone) == day.key else { return nil }
        return weather.current
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(String(day.number)).font(.system(size: 29, weight: .light, design: .rounded))
                    Text(model.selectedDate, format: .dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN")))
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }.frame(width: 40)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 36)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.selectedDate, format: .dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
                        .font(.system(size: 12, weight: .medium))
                    if model.preferences.showLunar {
                        Text("农历 " + day.fullLunar).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if model.preferences.showFestivals && !day.festivals.isEmpty {
                        Text(day.festivals.joined(separator: " · ")).font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 4)
                if model.preferences.showWeather { weatherSummary }
            }
            if model.preferences.showWeather {
                Divider().opacity(0.5)
                HStack(spacing: 7) {
                    Label(model.preferences.city.name, systemImage: "location.fill")
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    if let error = model.weatherError {
                        Button("重试") { model.refreshWeather() }.buttonStyle(.plain).help(error).foregroundStyle(Color.calAccent)
                    } else if let humidity = current?.relative_humidity_2m {
                        Text("湿度 \(humidity)%").fixedSize()
                    } else if let rain = forecast?.rain {
                        Text("降水 \(rain)%").fixedSize()
                    }
                    if model.loadingWeather { ProgressView().controlSize(.mini) }
                    else {
                        Button { model.refreshWeather() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).accessibilityLabel("刷新天气").help("刷新天气")
                    }
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.calAccent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var weatherSummary: some View {
        if let current, let temperature = current.temperature_2m, let code = current.weather_code {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: WeatherCode.symbol(code, night: current.is_day == 0)).symbolRenderingMode(.multicolor)
                    Text("\(Int(temperature.rounded()))°").font(.system(size: 23, weight: .light, design: .rounded))
                }
                Text(WeatherCode.label(code)).font(.system(size: 10)).foregroundStyle(.secondary)
                if let forecast { temperatureRange(forecast) }
            }
        } else if let forecast {
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: WeatherCode.symbol(forecast.code)).symbolRenderingMode(.multicolor).font(.system(size: 21))
                Text(WeatherCode.label(forecast.code)).font(.system(size: 10)).foregroundStyle(.secondary)
                temperatureRange(forecast)
            }
        } else {
            Text(model.loadingWeather ? "加载中…" : (model.forecast == nil ? "天气暂不可用" : "暂无预报"))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    private func temperatureRange(_ forecast: WeatherDay) -> some View {
        Text("\(Int(forecast.low.rounded()))° / \(Int(forecast.high.rounded()))°")
            .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
    }
}
