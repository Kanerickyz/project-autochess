class_name EventData
extends Resource

@export var id: String = ""
@export var title: String = "随机事件"
@export_multiline var body: String = ""
## 为 true 时进入节点直接开徽章三选一（不花金、可跳过），不走下方选项 UI。
@export var offers_badge_pick: bool = false
@export var choices: Array[EventChoice] = []
