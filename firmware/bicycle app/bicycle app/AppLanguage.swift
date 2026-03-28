//
//  AppLanguage.swift
//  bicycle app
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"

    /// `UserDefaults` / `@AppStorage` 键，与全工程一致。
    static let storageKey = "app_language"

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

struct L10n {
    let lang: AppLanguage

    init(_ lang: AppLanguage) {
        self.lang = lang
    }

    // MARK: - Login

    var loginToggleRegister: String {
        switch lang {
        case .chinese: return "没有账号？去注册"
        case .english: return "No account? Register"
        }
    }

    var loginToggleLogin: String {
        switch lang {
        case .chinese: return "已有账号？去登录"
        case .english: return "Have an account? Log in"
        }
    }

    var loginUsername: String {
        switch lang {
        case .chinese: return "用户名"
        case .english: return "Username"
        }
    }

    var loginPassword: String {
        switch lang {
        case .chinese: return "密码"
        case .english: return "Password"
        }
    }

    var loginSubmit: String {
        switch lang {
        case .chinese: return "登录"
        case .english: return "Log in"
        }
    }

    var registerSubmit: String {
        switch lang {
        case .chinese: return "注册"
        case .english: return "Register"
        }
    }

    var loginEmptyError: String {
        switch lang {
        case .chinese: return "用户名和密码不能为空"
        case .english: return "Username and password are required"
        }
    }

    // MARK: - Tabs

    var tabMap: String {
        switch lang {
        case .chinese: return "地图"
        case .english: return "Map"
        }
    }

    var tabSafety: String {
        switch lang {
        case .chinese: return "安全"
        case .english: return "Safety"
        }
    }

    var tabDevice: String {
        switch lang {
        case .chinese: return "设备"
        case .english: return "Device"
        }
    }

    var safetyNavTitle: String {
        switch lang {
        case .chinese: return "安全"
        case .english: return "Safety"
        }
    }

    var deviceNavTitle: String {
        switch lang {
        case .chinese: return "设备"
        case .english: return "Device"
        }
    }

    // MARK: - Map & navigation

    var mapSearchPlaceholder: String {
        switch lang {
        case .chinese: return "搜索地图"
        case .english: return "Search the map"
        }
    }

    var mapDestinationMarker: String {
        switch lang {
        case .chinese: return "目的地"
        case .english: return "Destination"
        }
    }

    var mapStyleMenuTitle: String {
        switch lang {
        case .chinese: return "地图样式"
        case .english: return "Map style"
        }
    }

    var mapStyleStandard: String {
        switch lang {
        case .chinese: return "标准"
        case .english: return "Standard"
        }
    }

    var mapStyleSatellite: String {
        switch lang {
        case .chinese: return "卫星"
        case .english: return "Satellite"
        }
    }

    var mapStyleHybrid: String {
        switch lang {
        case .chinese: return "混合"
        case .english: return "Hybrid"
        }
    }

    func mapETA(_ durationText: String) -> String {
        switch lang {
        case .chinese: return "预计 \(durationText)"
        case .english: return "ETA \(durationText)"
        }
    }

    var mapStepsShow: String {
        switch lang {
        case .chinese: return "详情"
        case .english: return "Steps"
        }
    }

    var mapStepsHide: String {
        switch lang {
        case .chinese: return "收起"
        case .english: return "Hide"
        }
    }

    var mapStartNavigation: String {
        switch lang {
        case .chinese: return "开始导航"
        case .english: return "Start navigation"
        }
    }

    var mapStopNavigation: String {
        switch lang {
        case .chinese: return "结束导航"
        case .english: return "End navigation"
        }
    }

    var mapGlassesDefaultName: String {
        switch lang {
        case .chinese: return "眼镜"
        case .english: return "Glasses"
        }
    }

    func mapGlassesConnectedLine(name: String) -> String {
        switch lang {
        case .chinese: return "\(name) 已连接"
        case .english: return "\(name) connected"
        }
    }

    var mapGlassesDisconnected: String {
        switch lang {
        case .chinese: return "眼镜未连接"
        case .english: return "Glasses not connected"
        }
    }

    var mapConnectShort: String {
        switch lang {
        case .chinese: return "连接"
        case .english: return "Connect"
        }
    }

    var mapEmptyDestination: String {
        switch lang {
        case .chinese: return "请输入目的地。"
        case .english: return "Enter a destination."
        }
    }

    var mapSearchingPlace: String {
        switch lang {
        case .chinese: return "正在搜索地点..."
        case .english: return "Searching for place…"
        }
    }

    var mapPlanningRoute: String {
        switch lang {
        case .chinese: return "正在规划路线..."
        case .english: return "Planning route…"
        }
    }

    var mapPlaceNotFound: String {
        switch lang {
        case .chinese: return "未找到该地点，请更换关键词。"
        case .english: return "No results. Try different keywords."
        }
    }

    var mapNoRoute: String {
        switch lang {
        case .chinese: return "未找到可用路线。"
        case .english: return "No route found."
        }
    }

    func mapRouteFailed(_ errorDescription: String) -> String {
        switch lang {
        case .chinese: return "路线规划失败：\(errorDescription)"
        case .english: return "Routing failed: \(errorDescription)"
        }
    }

    var mapDistanceKmFormat: String {
        switch lang {
        case .chinese: return "%.1f 公里"
        case .english: return "%.1f km"
        }
    }

    var mapDistanceMetersFormat: String {
        switch lang {
        case .chinese: return "%.0f 米"
        case .english: return "%.0f m"
        }
    }

    func mapDurationHoursMinutes(hours: Int, minutes: Int) -> String {
        switch lang {
        case .chinese: return "\(hours) 小时 \(minutes) 分钟"
        case .english: return "\(hours) h \(minutes) min"
        }
    }

    func mapDurationMinutes(_ minutes: Int) -> String {
        switch lang {
        case .chinese: return "\(minutes) 分钟"
        case .english: return "\(minutes) min"
        }
    }

    // MARK: - Glasses sheet (map)

    var glassesSheetTitle: String {
        switch lang {
        case .chinese: return "连接智能眼镜"
        case .english: return "Connect smart glasses"
        }
    }

    var glassesSheetSubtitle: String {
        switch lang {
        case .chinese: return "连接眼镜以接收导航转向提示"
        case .english: return "Connect glasses for turn-by-turn prompts"
        }
    }

    var glassesSheetConnecting: String {
        switch lang {
        case .chinese: return "正在连接…"
        case .english: return "Connecting…"
        }
    }

    var glassesSheetScanning: String {
        switch lang {
        case .chinese: return "正在搜索眼镜设备…"
        case .english: return "Searching for glasses…"
        }
    }

    var glassesSheetSkip: String {
        switch lang {
        case .chinese: return "跳过，不连接眼镜"
        case .english: return "Skip without glasses"
        }
    }

    /// 异步任务里取当前语言（避免切换语言后 `statusMessage` 仍用旧文案）。
    static func currentL10n() -> L10n {
        let raw = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.chinese.rawValue
        return L10n(AppLanguage(rawValue: raw) ?? .chinese)
    }

    // MARK: - Safety (cards & copy)

    var safetyDangerIndexTitle: String {
        switch lang {
        case .chinese: return "危险指数"
        case .english: return "Danger index"
        }
    }

    var safetyLevelSafe: String {
        switch lang {
        case .chinese: return "安全"
        case .english: return "Safe"
        }
    }

    var safetyLevelCaution: String {
        switch lang {
        case .chinese: return "注意"
        case .english: return "Caution"
        }
    }

    var safetyLevelDanger: String {
        switch lang {
        case .chinese: return "危险"
        case .english: return "Danger"
        }
    }

    var safetyLatestTargetTitle: String {
        switch lang {
        case .chinese: return "最近目标"
        case .english: return "Latest target"
        }
    }

    var safetyRecordsSectionTitle: String {
        switch lang {
        case .chinese: return "危险记录"
        case .english: return "Danger log"
        }
    }

    var safetyRecordsEmptyHint: String {
        switch lang {
        case .chinese: return "当危险指数大于 70 时，会自动记录并显示车辆信息。"
        case .english: return "When the index exceeds 70, events are logged with vehicle details."
        }
    }

    func safetyRecordLine2(targetId: Int, direction: String, distance: Int, speed: Int, angle: Int) -> String {
        switch lang {
        case .chinese:
            return "目标\(targetId) · \(direction) · 距离 \(distance) m · \(speed) km/h · \(angle)°"
        case .english:
            return "Target \(targetId) · \(localizedDirection(direction)) · \(distance) m · \(speed) km/h · \(angle)°"
        }
    }

    // MARK: - Device (cards & copy)

    var deviceDisconnect: String {
        switch lang {
        case .chinese: return "断开连接"
        case .english: return "Disconnect"
        }
    }

    var deviceStopScan: String {
        switch lang {
        case .chinese: return "停止扫描"
        case .english: return "Stop scanning"
        }
    }

    var deviceConnectingEllipsis: String {
        switch lang {
        case .chinese: return "连接中…"
        case .english: return "Connecting…"
        }
    }

    var deviceSearchDevices: String {
        switch lang {
        case .chinese: return "搜索设备"
        case .english: return "Search devices"
        }
    }

    var deviceConnectedFallbackName: String {
        switch lang {
        case .chinese: return "设备已连接"
        case .english: return "Connected"
        }
    }

    var deviceGenericName: String {
        switch lang {
        case .chinese: return "设备"
        case .english: return "Device"
        }
    }

    func deviceStatusConnecting(to name: String) -> String {
        switch lang {
        case .chinese: return "连接 \(name)…"
        case .english: return "Connecting to \(name)…"
        }
    }

    var deviceStatusSearching: String {
        switch lang {
        case .chinese: return "正在搜索…"
        case .english: return "Searching…"
        }
    }

    var deviceBluetoothOffTitle: String {
        switch lang {
        case .chinese: return "蓝牙已关闭"
        case .english: return "Bluetooth off"
        }
    }

    var deviceBluetoothUnauthorizedTitle: String {
        switch lang {
        case .chinese: return "蓝牙未授权"
        case .english: return "Bluetooth denied"
        }
    }

    var deviceDisconnectedTitle: String {
        switch lang {
        case .chinese: return "未连接"
        case .english: return "Disconnected"
        }
    }

    func deviceSubtitleConnected(rssi: Int) -> String {
        switch lang {
        case .chinese: return "已连接 · 信号 \(rssi) dBm"
        case .english: return "Connected · RSSI \(rssi) dBm"
        }
    }

    var deviceSubtitleScanning: String {
        switch lang {
        case .chinese: return "正在搜索附近的设备"
        case .english: return "Looking for nearby devices"
        }
    }

    var deviceSubtitleEstablishing: String {
        switch lang {
        case .chinese: return "正在建立连接"
        case .english: return "Establishing connection"
        }
    }

    var deviceSubtitleBluetoothOff: String {
        switch lang {
        case .chinese: return "请在系统设置中开启蓝牙"
        case .english: return "Turn on Bluetooth in Settings"
        }
    }

    var deviceSubtitleUnauthorized: String {
        switch lang {
        case .chinese: return "请在设置中授权蓝牙权限"
        case .english: return "Allow Bluetooth access in Settings"
        }
    }

    var deviceSubtitleDisconnected: String {
        switch lang {
        case .chinese: return "点击下方按钮搜索设备"
        case .english: return "Tap below to search for devices"
        }
    }

    var deviceDiscoveredSectionTitle: String {
        switch lang {
        case .chinese: return "发现的设备"
        case .english: return "Found devices"
        }
    }

    var deviceSearchingNearby: String {
        switch lang {
        case .chinese: return "正在搜索附近的设备…"
        case .english: return "Searching for nearby devices…"
        }
    }

    func deviceSignalLabel(rssi: Int) -> String {
        switch lang {
        case .chinese: return "信号: \(rssi) dBm"
        case .english: return "RSSI: \(rssi) dBm"
        }
    }

    var deviceConnect: String {
        switch lang {
        case .chinese: return "连接"
        case .english: return "Connect"
        }
    }

    var deviceInfoSectionTitle: String {
        switch lang {
        case .chinese: return "设备信息"
        case .english: return "Device info"
        }
    }

    var deviceInfoName: String {
        switch lang {
        case .chinese: return "名称"
        case .english: return "Name"
        }
    }

    var deviceInfoRSSI: String {
        switch lang {
        case .chinese: return "信号强度"
        case .english: return "Signal"
        }
    }

    var deviceInfoFrames: String {
        switch lang {
        case .chinese: return "数据接收"
        case .english: return "Frames received"
        }
    }

    var deviceInfoParseErrors: String {
        switch lang {
        case .chinese: return "解析错误"
        case .english: return "Parse errors"
        }
    }

    func deviceInfoFramesValue(_ count: Int) -> String {
        switch lang {
        case .chinese: return "\(count) 帧"
        case .english: return "\(count) frames"
        }
    }

    var tabPeople: String {
        switch lang {
        case .chinese: return "关联人"
        case .english: return "People"
        }
    }

    var tabYou: String {
        switch lang {
        case .chinese: return "我的"
        case .english: return "Profile"
        }
    }

    // MARK: - You / Settings

    var youNavTitle: String {
        switch lang {
        case .chinese: return "我的"
        case .english: return "Profile"
        }
    }

    // MARK: - AI riding insight (demo)

    var aiRidingEntryTitle: String {
        switch lang {
        case .chinese: return "AI 骑行习惯分析"
        case .english: return "AI riding habits"
        }
    }

    var aiRidingEntrySubtitle: String {
        switch lang {
        case .chinese: return "演示 · 示例数据与建议"
        case .english: return "Demo · sample data & tips"
        }
    }

    var aiRidingNavTitle: String {
        switch lang {
        case .chinese: return "AI 骑行洞察"
        case .english: return "AI riding insights"
        }
    }

    var aiRidingDemoBadge: String {
        switch lang {
        case .chinese: return "演示"
        case .english: return "Demo"
        }
    }

    var aiRidingHabitSection: String {
        switch lang {
        case .chinese: return "习惯概览"
        case .english: return "Habit overview"
        }
    }

    var aiRidingChartCaption: String {
        switch lang {
        case .chinese: return "近四周骑行活跃度（示例）"
        case .english: return "Last 4 weeks activity (sample)"
        }
    }

    var aiRidingMetricRidesLabel: String {
        switch lang {
        case .chinese: return "本周骑行次数"
        case .english: return "Rides this week"
        }
    }

    var aiRidingMetricRidesValue: String {
        switch lang {
        case .chinese: return "5 次"
        case .english: return "5 rides"
        }
    }

    var aiRidingMetricDurationLabel: String {
        switch lang {
        case .chinese: return "平均单次时长"
        case .english: return "Avg. duration / ride"
        }
    }

    var aiRidingMetricDurationValue: String {
        switch lang {
        case .chinese: return "约 42 分钟"
        case .english: return "~42 min"
        }
    }

    var aiRidingMetricNightLabel: String {
        switch lang {
        case .chinese: return "晚间出行占比"
        case .english: return "Evening share"
        }
    }

    var aiRidingMetricNightValue: String {
        switch lang {
        case .chinese: return "28%"
        case .english: return "28%"
        }
    }

    var aiRidingSuggestionsSection: String {
        switch lang {
        case .chinese: return "智能建议"
        case .english: return "Suggestions"
        }
    }

    var aiRidingSuggestion1: String {
        switch lang {
        case .chinese: return "通勤路段可尝试固定路线，便于雷达与导航协同预警。"
        case .english: return "Try a fixed commute route so radar alerts and navigation stay in sync."
        }
    }

    var aiRidingSuggestion2: String {
        switch lang {
        case .chinese: return "晚间骑行占比偏高，建议检查车灯与反光装备，并降低陌生路段速度。"
        case .english: return "Evening rides are common—check lights and reflectors, and ease off on unfamiliar roads."
        }
    }

    var aiRidingSuggestion3: String {
        switch lang {
        case .chinese: return "单次时长适中，可在长途前关注天气预报与补水节奏。"
        case .english: return "Ride length looks moderate—before longer trips, check weather and hydration."
        }
    }

    var aiRidingDisclaimer: String {
        switch lang {
        case .chinese: return "以上为界面演示，非真实 AI 分析结果，也未上传你的数据。"
        case .english: return "For UI demo only—not real AI analysis; your data is not uploaded."
        }
    }

    var settingsTitle: String {
        switch lang {
        case .chinese: return "设置"
        case .english: return "Settings"
        }
    }

    var settingsLanguage: String {
        switch lang {
        case .chinese: return "语言"
        case .english: return "Language"
        }
    }

    var settingsInviteTitle: String {
        switch lang {
        case .chinese: return "我的邀请码"
        case .english: return "My invite code"
        }
    }

    var settingsInviteHint: String {
        switch lang {
        case .chinese: return "将邀请码分享给家人或朋友，让他们把你加为监护对象。"
        case .english: return "Share your code so others can add you as someone to watch over."
        }
    }

    var settingsNoCode: String {
        switch lang {
        case .chinese: return "暂无邀请码"
        case .english: return "No code yet"
        }
    }

    var settingsCopyCode: String {
        switch lang {
        case .chinese: return "复制邀请码"
        case .english: return "Copy code"
        }
    }

    var settingsCopied: String {
        switch lang {
        case .chinese: return "已复制"
        case .english: return "Copied"
        }
    }

    var settingsShareInvite: String {
        switch lang {
        case .chinese: return "分享邀请"
        case .english: return "Share"
        }
    }

    var settingsAddGuardianTitle: String {
        switch lang {
        case .chinese: return "添加监护对象"
        case .english: return "Add to watch list"
        }
    }

    var settingsInvitePlaceholder: String {
        switch lang {
        case .chinese: return "输入邀请码（例如 A1B2C3）"
        case .english: return "Enter invite code (e.g. A1B2C3)"
        }
    }

    var settingsAddButton: String {
        switch lang {
        case .chinese: return "添加到监护列表"
        case .english: return "Add to list"
        }
    }

    var settingsAddSuccess: String {
        switch lang {
        case .chinese: return "添加监护对象成功"
        case .english: return "Added successfully"
        }
    }

    var settingsAccount: String {
        switch lang {
        case .chinese: return "账号"
        case .english: return "Account"
        }
    }

    var settingsLogout: String {
        switch lang {
        case .chinese: return "退出登录"
        case .english: return "Log out"
        }
    }

    var settingsGuardianEnabled: String {
        switch lang {
        case .chinese: return "监护模式已启用"
        case .english: return "Guardian mode on"
        }
    }

    var settingsStatsTitle: String {
        switch lang {
        case .chinese: return "骑行统计"
        case .english: return "Ride stats"
        }
    }

    var settingsStatDistance: String {
        switch lang {
        case .chinese: return "总里程"
        case .english: return "Distance"
        }
    }

    var settingsStatRides: String {
        switch lang {
        case .chinese: return "骑行次数"
        case .english: return "Rides"
        }
    }

    var settingsStatSpeed: String {
        switch lang {
        case .chinese: return "平均速度"
        case .english: return "Avg speed"
        }
    }

    func watchListStatus(count: Int) -> String {
        switch lang {
        case .chinese:
            return count > 0 ? "当前监护 \(count) 人" : "暂无监护对象"
        case .english:
            return count > 0 ? "Watching \(count)" : "No one in list"
        }
    }

    func inviteShareBody(username: String, code: String) -> String {
        switch lang {
        case .chinese:
            return "我是 \(username)，邀请你作为我的监护人。请在 app 中输入邀请码：\(code)"
        case .english:
            return "I'm \(username). Add me with this invite code in the app: \(code)"
        }
    }

    // MARK: - Related people

    var peopleNavTitle: String {
        switch lang {
        case .chinese: return "监护对象"
        case .english: return "Watch list"
        }
    }

    var peopleEmptyTitle: String {
        switch lang {
        case .chinese: return "暂无监护对象"
        case .english: return "No one yet"
        }
    }

    var peopleEmptyHint: String {
        switch lang {
        case .chinese: return "点击右上角 + 按钮，通过邀请码添加监护对象。"
        case .english: return "Tap + and enter an invite code to add someone."
        }
    }

    var peopleListSection: String {
        switch lang {
        case .chinese: return "监护列表"
        case .english: return "List"
        }
    }

    func peopleInviteLabel(_ code: String) -> String {
        switch lang {
        case .chinese: return "邀请码: \(code)"
        case .english: return "Code: \(code)"
        }
    }

    func peopleLiveData(_ name: String) -> String {
        switch lang {
        case .chinese: return "\(name) 的实时数据"
        case .english: return "\(name)'s live data"
        }
    }

    var peopleDangerTitle: String {
        switch lang {
        case .chinese: return "当前危险指数"
        case .english: return "Danger index"
        }
    }

    var peopleRecordsTitle: String {
        switch lang {
        case .chinese: return "危险记录"
        case .english: return "Danger log"
        }
    }

    var peopleRecordsHint: String {
        switch lang {
        case .chinese: return "当危险指数超过 70 时，系统会自动记录。"
        case .english: return "Events are logged when the index exceeds 70."
        }
    }

    var peopleAddNavTitle: String {
        switch lang {
        case .chinese: return "添加监护对象"
        case .english: return "Add person"
        }
    }

    var peopleAddHint: String {
        switch lang {
        case .chinese: return "输入对方的邀请码来添加监护对象。"
        case .english: return "Enter their invite code to add them."
        }
    }

    var peopleAddButton: String {
        switch lang {
        case .chinese: return "添加监护对象"
        case .english: return "Add"
        }
    }

    func peopleRecordLine1(score: Int, side: String) -> String {
        switch lang {
        case .chinese: return "危险指数 \(score) · \(side)"
        case .english: return "Index \(score) · \(localizedSide(side))"
        }
    }

    func peopleRecordLine2(targetId: Int, direction: String, distance: Int, speed: Int) -> String {
        switch lang {
        case .chinese:
            return "目标\(targetId) · \(direction) · 距离 \(distance) m · \(speed) km/h"
        case .english:
            return "Target \(targetId) · \(localizedDirection(direction)) · \(distance) m · \(speed) km/h"
        }
    }

    var peopleRemove: String {
        switch lang {
        case .chinese: return "移除"
        case .english: return "Remove"
        }
    }

    var peopleCancel: String {
        switch lang {
        case .chinese: return "取消"
        case .english: return "Cancel"
        }
    }

    var peopleSheetSuccess: String {
        switch lang {
        case .chinese: return "添加成功"
        case .english: return "Added"
        }
    }

    var peopleSheetCodePlaceholder: String {
        switch lang {
        case .chinese: return "邀请码（例如 A1B2C3）"
        case .english: return "Invite code (e.g. A1B2C3)"
        }
    }

    var relatedNeverUpdated: String {
        switch lang {
        case .chinese: return "尚未更新"
        case .english: return "Not updated yet"
        }
    }

    func relatedUpdatedAt(_ time: String) -> String {
        switch lang {
        case .chinese: return "更新于 \(time)"
        case .english: return "Updated \(time)"
        }
    }

    func localizedSide(_ side: String) -> String {
        guard lang == .english else { return side }
        switch side {
        case "左侧": return "Left"
        case "右侧": return "Right"
        case "后方": return "Rear"
        default: return side
        }
    }

    func localizedDirection(_ direction: String) -> String {
        guard lang == .english else { return direction }
        switch direction {
        case "近": return "Approaching"
        default: return direction
        }
    }
}
