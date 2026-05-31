public enum LinoJCloudKit {
    public static let containerID = "iCloud.com.linocai.linoj"
}

/// U9（v1.1）：App Group 标识。两端 App 与（将来的）widget extension 共享同一个 App Group
/// 容器，以便 widget 进程读取 App 私有的 SwiftData store（widget 进程访问不到 App 私有
/// Application Support 目录）。ID 已由用户在 developer.apple.com 注册并关联到 App ID。
public enum LinoJAppGroup {
    public static let id = "group.com.linocai.linoj"
}
