import SwiftUI
import CalendarCore
import AppServices

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "calendar").font(.system(size: 25, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(LinearGradient(colors: [.calAccent, Color(red: 0.43, green: 0.47, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("让时间，一目了然").font(.system(size: 19, weight: .semibold))
                    Text("快捷日历  /  QuickCalender").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.4")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }.padding(24)
            Picker("设置分类", selection: $tab) {
                Text("状态栏").tag(0)
                Text("日历").tag(1)
                Text("天气").tag(2)
                Text("通用").tag(3)
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.bottom, 12)
            Group {
                switch tab {
                case 0: statusSettings
                case 1: calendarSettings
                case 2: CitySettingsView(model: model)
                default: generalSettings
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("所有设置即时生效，自动保存")
                Spacer()
                Link("GitHub ↗", destination: URL(string: "https://github.com/chenzhen411/QuickCalender")!)
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 14)
        }
        .frame(width: 560, height: 590)
        .background(Color(nsColor: .windowBackgroundColor)).tint(.calAccent)
        .preferredColorScheme(model.colorScheme)
    }

    private var statusSettings: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if model.preferences.showStatusIcon { Image(systemName: "calendar") }
                        Text(model.preferences.statusLabel(at: model.now)).monospacedDigit()
                    }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.08)) }
                    Spacer()
                }.padding(.vertical, 8)
            } header: { Text("实时预览") }
            Section("显示样式") {
                Picker("状态栏样式", selection: $model.preferences.statusStyle) {
                    ForEach(StatusStyle.allCases) { style in Text(style.title).tag(style) }
                }.pickerStyle(.segmented)
                Toggle("显示日历图标", isOn: $model.preferences.showStatusIcon)
                Toggle("24 小时制", isOn: $model.preferences.use24Hour)
                Toggle("显示秒数", isOn: $model.preferences.showSeconds)
            }
            Section { Text("日期和时间跟随 Mac 的系统时区。三种样式都包含日期、星期和时间。").font(.system(size: 11)).foregroundStyle(.secondary) }
        }.formStyle(.grouped)
    }

    private var calendarSettings: some View {
        Form {
            Section("日历内容") {
                Toggle("显示农历", isOn: $model.preferences.showLunar)
                Toggle("显示中国节日", isOn: $model.preferences.showFestivals)
                Toggle("日期卡片中显示天气", isOn: $model.preferences.showWeather)
                Toggle("日期格中显示天气图标", isOn: $model.preferences.showDayWeather).disabled(!model.preferences.showWeather)
            }
            Section("日历布局") {
                Picker("每周开始于", selection: $model.preferences.mondayFirst) {
                    Text("星期一").tag(true)
                    Text("星期日").tag(false)
                }.pickerStyle(.segmented)
            }
            Section {
                Text("支持 1901–2099 年。点击日历的月份标题可快速跳转年月，⌘← / ⌘→ 切换月份，⌘T 回到今天。")
                Text("节日用于纪念日提醒；不标注法定放假、调休安排。农历跟随系统时区，清明节按中国标准时间计算。")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }

    private var generalSettings: some View {
        Form {
            LoginItemSettingsView(controller: model.loginItem)
            Section("界面配色") {
                Picker("配色", selection: $model.preferences.appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }.pickerStyle(.segmented)
                Text("Light 为浅色，Dark 为深色，System 跟随 Mac 系统。切换后日历和设置窗口即时生效。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Section("使用方式") {
                LabeledContent("打开日历", value: "点击状态栏日期")
                LabeledContent("打开设置", value: "日历右下角设置 / ⌘,")
                LabeledContent("更多操作", value: "右键点击状态栏日期")
                LabeledContent("关闭日历", value: "再次点击状态栏 / 点击其他位置 / Esc")
            }.font(.system(size: 12))
            Section("数据与隐私") {
                Text("设置仅保存在本机。获取天气时会向 Open-Meteo 发送所选城市的坐标，搜索城市时发送查询文本；应用不请求定位权限。")
                Link("天气数据：Open-Meteo · CC BY 4.0 ↗", destination: URL(string: "https://open-meteo.com/")!)
                Text("公共天气接口用于非商业用途。商业分发前请配置符合服务许可的天气接口。")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}

private struct LoginItemSettingsView: View {
    @ObservedObject var controller: LoginItemController

    var body: some View {
        Section("启动") {
            Toggle("开机自动启动", isOn: Binding(
                get: { controller.isEnabled },
                set: { enabled in Task { await controller.setEnabled(enabled) } }
            ))
            .disabled(controller.isUpdating || !controller.canConfigure)
            if controller.isUpdating { ProgressView().controlSize(.small) }
            Text("首次启动时默认开启，登录 Mac 后自动显示状态栏日历。关闭后不会自动重新开启。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if !controller.canConfigure {
                Text("请将快捷日历拖入“应用程序”，再从应用图标启动，以设置开机启动。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else if controller.status == .requiresApproval {
                Text("开机启动尚未获准，请在系统登录项中允许快捷日历。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("打开系统登录项设置") { controller.openSystemSettings() }
                Button("取消开机启动申请") { Task { await controller.setEnabled(false) } }
                    .disabled(controller.isUpdating)
            }
            if let error = controller.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }.onAppear { controller.refreshStatus() }
    }
}

struct CitySettingsView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var cities: [WeatherCity] = []
    @State private var searching = false
    @State private var message: String?
    @State private var searchTask: Task<Void, Never>?
    var body: some View {
        Form {
            Section("当前城市") {
                HStack {
                    Label(model.preferences.city.name, systemImage: "location.circle.fill").foregroundStyle(Color.calAccent).font(.system(size: 13, weight: .medium))
                    Spacer()
                    if model.loadingWeather { ProgressView().controlSize(.small) }
                    else { Button("刷新天气") { model.refreshWeather() }.disabled(!model.preferences.showWeather) }
                }
                Toggle("显示天气", isOn: $model.preferences.showWeather)
            }
            Section("常用城市") {
                HStack(spacing: 7) {
                    ForEach(WeatherCity.presets) { city in
                        Button(city.name) { model.preferences.city = city }
                            .buttonStyle(.bordered).tint(model.preferences.city == city ? .calAccent : .gray)
                    }
                }
            }
            Section("搜索其他城市") {
                HStack {
                    TextField("输入城市名，例如 南京 / London", text: $query).onSubmit(search)
                    if searching { ProgressView().controlSize(.small) }
                    Button("搜索", action: search).disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
                if let message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
                ForEach(cities) { city in
                    Button { model.preferences.city = city; cities = []; message = "已切换到 \(city.name)" } label: {
                        HStack {
                            Text(city.name).lineLimit(2)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).font(.system(size: 12))
                }
            }
            Section {
                Text("天气每 30 分钟更新；每日预报最多覆盖未来 16 天。超出预报范围的日期不显示天气。时间跟随所选城市，日期格按对应公历日期展示预报。")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }.formStyle(.grouped)
            .onDisappear { searchTask?.cancel(); searching = false }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        searchTask?.cancel(); searching = true; cities = []; message = nil
        searchTask = Task { @MainActor in
            do {
                let results = try await WeatherClient().search(text)
                guard !Task.isCancelled else { return }
                cities = results; searching = false
                message = results.isEmpty ? "没有找到城市，请尝试英文名或拼音。" : "选择一个城市以应用"
            } catch {
                guard !Task.isCancelled else { return }
                searching = false; message = "搜索失败，请检查网络后重试。"
            }
        }
    }
}
