import SwiftUI
import CalendarCore

struct WeatherCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(model.preferences.city.name, systemImage: "location.fill")
                    .font(.system(size: 11, weight: .medium)).lineLimit(1)
                Spacer()
                if model.loadingWeather { ProgressView().controlSize(.mini) }
                else {
                    Button { model.refreshWeather() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 10)) }
                        .buttonStyle(.plain).help("刷新天气").accessibilityLabel("刷新天气")
                }
            }.foregroundStyle(.secondary)
            if let forecast = model.forecast, let temperature = forecast.current.temperature_2m, let code = forecast.current.weather_code {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: WeatherCode.symbol(code, night: forecast.current.is_day == 0))
                        .symbolRenderingMode(.multicolor).font(.system(size: 34))
                        .frame(width: 48)
                    Text("\(Int(temperature.rounded()))°").font(.system(size: 36, weight: .light, design: .rounded)).tracking(-1)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(WeatherCode.label(code)).font(.system(size: 12, weight: .medium))
                        if let apparent = forecast.current.apparent_temperature { Text("体感 \(Int(apparent.rounded()))°").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        if let humidity = forecast.current.relative_humidity_2m { Label("\(humidity)%", systemImage: "humidity").font(.system(size: 10)) }
                        if let wind = forecast.current.wind_speed_10m { Text("风速 \(Int(wind.rounded())) km/h").font(.system(size: 9)) }
                    }.foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    if let error = model.weatherError { Button(error) { model.refreshWeather() }.buttonStyle(.plain).foregroundStyle(.orange) }
                    else if let updated = model.updatedAt {
                        Text(updated, format: .dateTime.hour().minute()).monospacedDigit()
                        Text("更新 · 预报最多16天")
                    }
                }.font(.system(size: 9)).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "cloud.sun").font(.system(size: 26)).foregroundStyle(Color.calAccent.opacity(0.6))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.loadingWeather ? "正在获取天气…" : "天气暂不可用").font(.system(size: 12, weight: .medium))
                        if let error = model.weatherError {
                            Button(error) { model.refreshWeather() }.buttonStyle(.plain).foregroundStyle(Color.calAccent).font(.system(size: 10))
                        } else { Text("可在设置中更换城市").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                }.padding(.vertical, 5)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color.calAccent.opacity(0.08), Color.calAccent.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.calAccent.opacity(0.07)) }
    }
}
