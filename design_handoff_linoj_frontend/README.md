# Handoff: LinoJ 前端原型（主页 / 个人 / 公司 / 日历 / 灵感）

## Overview
LinoJ 是一款"安静的计划工具"，把**有钟点的事（日程 / Event）**和**没钟点的事（待办 / Todo）**彻底分开，外加项目（Project）、灵感笔记（Note）。本原型用 HTML 还原了 macOS 与 iOS 两端的五个顶层页面（主页、个人、公司、日历、灵感）、各自的新建卡片，以及设置面板，整体采用 Apple "Liquid Glass" 亮色风格、靛蓝→紫品牌色。

后端是已有的 Swift / SwiftUI + SwiftData 工程（仓库 `linocai/LinoJ`，核心模型在 `Packages/LinoJCore`）。本次原型的字段已对齐后端 SwiftData 模型 —— 实现时应直接复用 `LinoJCore` 里的 `Todo / Event / Note / Project / Person` 模型与 `Scope / Urgency / AppTab` 枚举。

## About the Design Files
本包内的文件是用 **HTML 制作的设计参考**（展示预期的外观与交互的高保真原型），**不是要直接搬进生产环境的代码**。任务是用目标工程已有的环境（这里是 **SwiftUI**）和既有模式/组件**重新实现**这些界面，而不是直接发布 HTML。

- `LinoJ 主页.dc.html` —— 全部界面。它是一个"Design Component"，需要同目录的 `support.js` 运行时才能在浏览器里打开预览。
- `support.js` —— 仅用于让上面的原型在浏览器里跑起来，**与生产实现无关**，不要移植。

打开方式：把这两个文件放在同一目录，用浏览器打开 `LinoJ 主页.dc.html` 即可看到 macOS + iOS 两个画框并排。顶部导航可切换页面，子页面里的"＋ 新建…"按钮可打开新建卡片，右上角齿轮为设置。

## Fidelity
**高保真（hifi）**。颜色、字号、字重、间距、圆角、阴影、交互态均为最终意图，应按下文 Design Tokens 像素级还原，并落到 SwiftUI 既有的设计系统（`LinoJCore/DesignSystem`：`Colors / Typography / Spacing / Radii`）里。原型里的具体待办/项目/人名都是**示例数据**，真实数据来自 SwiftData。

> 注意：原型用 Web 字体栈与 RGBA 近似了苹果系统材质（毛玻璃）。SwiftUI 实现请用 `.ultraThinMaterial` / `.regularMaterial` 等原生材质 + SF Pro / PingFang 系统字体，而不是照抄 RGBA。

---

## Screens / Views

两端共享同一套信息架构，导航有 5 个目的地：**主页 · 个人 · 公司 · 日历 · 灵感**（对应 `AppTab.main/personal/company/calendar/inspiration`）。

### 1. 主页 / Main
- **Purpose**：只读的总览，**只查看与勾选，没有任何新建动作**（新建都在各子页面里完成）。
- **Layout**：macOS 为左右两栏 —— 左主区 + 右侧 340px 左右的"未来 7 天"侧栏；iOS 为单列竖向滚动。
- **Components**：
  - **抬头看（Heads-up）横幅**：最近一个即将开始的日程提醒，"N 分钟后 · 标题 · 地点" + "打开"按钮，可关闭。品牌色脉冲圆点动画（`@keyframes pulseDot`）。
  - **待办区**：分"紧急 / 普通"两列（macOS）或两段（iOS）。每条待办左侧 18px 复选框（勾选切换完成态：描边变实心渐变 + 删除线 + 半透明）。
  - **来源标签（本次重点）**：主页的每条待办下方有一个小胶囊标签标明来源 —— `个人`（灰底 `rgba(60,60,67,0.07)`、灰字、灰点）或 `公司`（紫底 `rgba(123,123,240,0.12)`、`#6E63E6` 字、`#8A6DF0` 点）。对应 `Todo.scope`（`Scope.personal` / `Scope.company`）。若该待办还关联了项目，则在来源标签**右侧并排**再显示项目名胶囊。
  - **项目条**：紧凑列表，每行项目名 + 状态 tag + 待办/紧急计数 + 成员头像堆叠。
  - **右侧"未来 7 天"侧栏**：按天分组的日程列表 + 底部虚线框"昨天遗漏"（可勾选补打卡，对应 `Event.attendedConfirmed` / `dismissedFromYesterday`）。

### 2. 个人 / Personal
- **Purpose**：个人 scope 的待办（`Todo.scope == .personal`）。
- **Layout**：标题 + "＋ 新建个人待办"按钮；下分"紧急 / 普通"，底部可折叠"已完成"。
- 本页所有待办都是个人，**不显示来源标签**（避免冗余）。

### 3. 公司 / Company
- **Purpose**：公司 scope 的待办（`Todo.scope == .company`）+ 项目。
- **Layout**：标题（含 N 待办 · N 紧急 · N 项目）+ "＋ 新建公司事项"按钮；下方一排项目筛选 chips（全部 / 独立 / 各项目名）；"紧急 / 普通"两列待办；再下方"项目"区。
- **项目区标题行（本次重点）**：标题"项目"右侧有一个 **"＋ 新建项目"** 次级按钮（白底、`rgba(123,123,240,0.3)` 描边、`#6E63E6` 字），点击打开新建项目卡片。
- 每个项目卡片：状态 tag + 标题 + 简介 + 成员头像 + 关联待办清单 + 关联日程清单（对应 `Project` 的 `todos` / `events` 反向关系）。
- 本页所有待办都是公司，不显示来源标签。

### 4. 日历 / Calendar
- **Purpose**：查看日程（`Event`）。
- **Layout**：macOS 为周视图（左侧时间轴 + 列）；iOS 为日期横滑条 + 当日日程卡列表。顶部"＋ 新建日程"按钮。

### 5. 灵感 / Inspiration
- **Purpose**：随手记的富文本笔记（`Note`，照抄苹果备忘录 MVP）。
- **Layout**：标题 + "记录灵感"按钮；下方笔记卡片列表（不同色调）。

---

## 新建卡片（Modals）—— 字段严格对齐后端模型

四种新建卡片共用一个弹层外壳（macOS 居中卡片 / iOS 底部 sheet），按类型渲染不同字段。**字段必须与 `LinoJCore` 模型一致，不要多加也不要少。**

### 新建待办（Todo）—— 个人 / 公司
- **标题**（`title`）—— 大号单行输入
- **紧急度**：紧急 / 普通 二选一（`Urgency.urgent` / `.normal`，README NON-NEGOTIABLE：只有这两级）
- scope 由进入的页面决定（个人页→`.personal`，公司页→`.company`）。`Todo` 还有可选 `project`（公司 scope 才可挂）。

### 新建日程（Event）
- **标题**（`title`）
- **开始**（`start: Date`）、**结束**（`end: Date`）—— 日期 + 时间；需校验 `end >= start`（ViewModel 校验）
- **地点**（`location: String`，自由文本：会议室 / Zoom / 地址…）
- **参与人**（`attendees: [Person]?`）—— 可多选头像
- **项目**（`project: Project?`，可选，含"无"选项）
- ⚠️ **Event 没有 todo 字段、没有紧急度** —— 这是后端硬约束（`Event.swift`：NON-NEGOTIABLE 没有 todo 字段）。

### 新建灵感（Note）
- **正文**（`body: AttributedString`）—— 多行富文本输入框，**没有单独的标题字段**：标题由正文首个非空行派生（`Note.displayTitle`，空则回退"新笔记 / New note"）。底部提示文案："正文第一行将作为标题"。
- **置顶**（`isPinned: Bool`）—— 开关
- ⚠️ Note MVP **无任何关系字段**（不挂 person / project / folder）。底层正文以 `bodyData: Data`（`AttributedString` 编码）存储，上层走 `body` computed property。每次编辑重写 `updatedAt`（列表按它倒序）。

### 新建项目（Project）
- **项目名称**（`title`）—— 大号输入
- **简介**（`intro: String`，1–2 句，卡片副标题位）
- **状态**（`tag: String`，自由文本：6月发布 / 评审中 / 接近完成…）
- **成员**（`members: [Person]?`）—— 可多选头像；写入成员时同步维护 `memberCount`
- **备注**（`notes: String`，长文，可选，`\n\n` 渲染段落）
- Project 只属于 company scope；`todos` / `events` 由反向关系维护，删除项目时把对应 `Todo.project` / `Event.project` 置 nil（`.nullify`），不删除待办/日程本身。

### 设置（Settings）
外观（跟随系统，锁定）/ iCloud 同步（开）/ 默认页面 / 关于（版本号）。

---

## Interactions & Behavior
- **导航**：顶部 5 个目的地点击切换页面（`AppTab`）。主页图标特意与其它做了区分。
- **勾选待办**：点复选框切换完成态 —— 框由 1.5px 描边变实心品牌渐变 + 白色对勾，文字加删除线并降到 ~0.5 透明度。
- **新建卡片**：点子页面"＋ 新建…"打开；点遮罩或"取消"关闭；macOS 卡片底部有 `esc 取消 · ⌘↵ 创建` 提示。
- **公司项目筛选 chips**：全部 / 独立（无项目）/ 具体项目名，过滤待办列表。
- **昨天遗漏框**：可勾选补确认出席。
- **微交互**：待办/卡片 hover 上浮 `translateY(-1px)`，过渡 `.12s`；置顶开关旋钮 `transform .2s`；抬头看圆点 2s 呼吸动画。
- **过渡时长**：hover ~0.12s，开关 ~0.2s。

## State Management
对应 SwiftUI 的 `@Query` + ViewModel（仓库已有 `MainViewModel / CalendarViewModel / CompanyViewModel` 等）。原型里的本地态：
- 当前页（macOS / iOS 各一份）
- 待办完成态映射（done map）
- 新建卡片：当前类型（todo/event/note/project）、紧急度、参与人/成员选择、项目选择、置顶开关
- 抬头看是否关闭、设置面板开关、公司筛选 chip、日历选中日
真实数据全部来自 SwiftData（`@Model`：`Todo / Event / Note / Project / Person`）。

## Design Tokens

### Colors
| 用途 | 值 |
|---|---|
| 品牌渐变（按钮 / 强调） | `linear-gradient(135deg, #5B8DEF, #8A6DF0)` |
| 品牌强调色（文字 / 图标 / 紧急） | `#6E63E6`，深一档 `#5B5BD6` |
| 紫点（项目 / 公司标签点） | `#8A6DF0` |
| 主文字 | `#1C1C1E` |
| 次要文字 | `rgba(60,60,67,0.5)` ~ `0.6` |
| 更弱文字 / 占位 | `rgba(60,60,67,0.4)` |
| macOS 背景 | `linear-gradient(135deg,#F7F8FB,#EEF0F6)` |
| iOS 背景 | `linear-gradient(160deg,#F4F3EF,#EBEDF3)` |
| 玻璃卡片底 | `rgba(255,255,255,0.5~0.62)` + `backdrop-filter: blur(20–40px) saturate(1.5–1.6)` |
| 卡片描边 | `0.5px solid rgba(60,60,67,0.08~0.14)` |
| 紧急待办底 | `rgba(123,123,240,0.09~0.1)`，描边 `rgba(123,123,240,0.2~0.22)` |
| 来源标签·个人 | 底 `rgba(60,60,67,0.07)`、字 `rgba(60,60,67,0.6)`、点 `rgba(60,60,67,0.4)` |
| 来源标签·公司 | 底 `rgba(123,123,240,0.12)`、字 `#6E63E6`、点 `#8A6DF0` |
| 背景光晕（可选） | 橙 `rgba(255,176,120,.4)` / 蓝 `rgba(120,170,255,.44)` / 紫 `rgba(190,150,255,.4)` 的 radial |
| 完成态对勾 | 白 `#fff` on 品牌渐变 |

### Typography
- 字体栈：`-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'PingFang SC', 'Helvetica Neue', sans-serif`（SwiftUI 直接用系统字体）。
- 页面大标题 H1 30px / 700；iOS 段标题 34px / 700。
- 区块标题 26px / 700；卡片标题 14–17px / 600。
- 正文/待办 13.5–15.5px / 500–600；标签 10.5–12px / 600。
- 字距：标题多用 `letter-spacing: -0.02 ~ -0.03em`；标签小字 `+0.04 ~ 0.05em`、大写。
- 数字用 `font-variant-numeric: tabular-nums`；时间/代码提示用等宽 `ui-monospace,'SF Mono',Menlo`。

### Spacing / Radii / Shadow
- 圆角：按钮/胶囊 9–13px；卡片 13–18px；大卡 16–18px；iOS sheet 顶部 30px；头像/圆点圆形。
- 阴影：卡片 `0 6–9px 18–26px rgba(0,0,0,0.05~0.07)`；弹层 `0 30px 80px rgba(20,20,40,0.4)`；普遍叠加 `inset 0 0.5px 0 rgba(255,255,255,0.7~0.9)` 高光。
- 复选框 18px（macOS）/ 21–22px（iOS），圆角 6–7px，描边 1.5px。
- 头像 22–34px。

## Assets
无位图资源。全部图标为内联 SVG（线性，`stroke-width` 1.8–2.5，圆头圆角）—— 实现时请换成 **SF Symbols**（home / person / building / calendar / lightbulb / gear / search / plus / check / clock / pin 等）。背景光晕、毛玻璃用 SwiftUI 原生材质实现。

## Files
- `LinoJ 主页.dc.html` —— 全部界面与交互（设计参考）。
- `support.js` —— 仅供浏览器预览的运行时，**不要移植**。
- 后端模型参考（仓库 `linocai/LinoJ`）：`Packages/LinoJCore/Sources/LinoJCore/Models/{Todo,Event,Note,Project,Person}.swift`、`Models/Enums.swift`，以及 `DesignSystem/{Colors,Typography,Spacing,Radii}.swift`。实现时以这些为准。
