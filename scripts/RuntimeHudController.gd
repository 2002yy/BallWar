extends RefCounted
class_name RuntimeHudController

static func format_time_text(seconds: float) -> String:
    var total_seconds: int = maxi(0, int(floor(seconds)))
    var mm: int = floori(float(total_seconds) / 60.0)
    var ss: int = total_seconds % 60
    return "%02d:%02d" % [mm, ss]

static func current_stage_name(game_elapsed_time: float) -> String:
    if game_elapsed_time < 120.0:
        return "前期扩张"
    elif game_elapsed_time < 300.0:
        return "中期翻倍加速"
    return "终局狂暴"

static func get_active_bullet_count(bullet_container) -> int:
    if bullet_container == null or not is_instance_valid(bullet_container):
        return 0
    if bullet_container.has_method("get_active_count"):
        return int(bullet_container.get_active_count())
    return bullet_container.get_child_count()

static func get_burst_queue_count(turrets: Dictionary) -> int:
    var total: int = 0
    for turret in turrets.values():
        if turret != null and is_instance_valid(turret):
            total += int(turret.get("burst_remaining"))
    return total

static func get_pressure_label(active_count: int, burst_queue: int) -> String:
    var fps: int = Engine.get_frames_per_second()
    if active_count >= GameConfig.get_force_simple_threshold():
        return "极高"
    if active_count >= GameConfig.get_high_pressure_threshold():
        return "高"
    if active_count >= GameConfig.get_mid_pressure_threshold():
        return "中"
    if burst_queue >= 1024:
        return "队列高"
    if burst_queue >= 256:
        return "队列中"
    if fps > 0 and fps < 24:
        return "帧低"
    return "低"

static func get_perf_debug_text(bullet_container, battlefield, selected_grid_size: int, turrets: Dictionary = {}) -> String:
    var active_count: int = get_active_bullet_count(bullet_container)
    var max_active: int = GameConfig.get_max_active_bullets()
    var burst_queue: int = get_burst_queue_count(turrets)
    var grid_value: int = battlefield.grid_size if battlefield != null and is_instance_valid(battlefield) else selected_grid_size
    return "FPS %d | 子弹 %d/%d | 队列 %d | 画质 %s | 地图 %d×%d | 压力 %s" % [
        Engine.get_frames_per_second(),
        active_count,
        max_active,
        burst_queue,
        GameConfig.get_quality_name(),
        grid_value,
        grid_value,
        get_pressure_label(active_count, burst_queue),
    ]

static func update_meta(timer_label, stage_label, leader_label, current_score_counts: Dictionary, game_elapsed_time: float) -> void:
    if timer_label != null and is_instance_valid(timer_label):
        timer_label.text = format_time_text(game_elapsed_time)
    if stage_label != null and is_instance_valid(stage_label):
        stage_label.text = current_stage_name(game_elapsed_time)
    if leader_label != null and is_instance_valid(leader_label):
        var total: int = 0
        var best_id: int = 0
        var best_count: int = -1
        for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
            var c: int = int(current_score_counts.get(faction_id, 0))
            total += c
            if c > best_count:
                best_count = c
                best_id = faction_id
        var percent: int = 0
        if total > 0:
            percent = int(round(float(best_count) * 100.0 / float(total)))
        leader_label.text = "领先：%s %d%%" % [GameConfig.faction_name(best_id), percent]
        leader_label.add_theme_color_override("font_color", GameConfig.faction_color(best_id).lightened(0.42))

static func update_top_bar(counts: Dictionary, top_bar_segments: Dictionary, top_bar_labels: Dictionary, top_bar_name_labels: Dictionary, top_bar_total_width: float, is_mobile_layout: bool) -> void:
    if top_bar_segments.size() == 0:
        return

    var total: int = 0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        total += int(counts.get(faction_id, 0))
    if total <= 0:
        total = 1

    var running_x: float = 3.0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var ratio: float = float(counts.get(faction_id, 0)) / float(total)
        var p: int = int(round(ratio * 100.0))
        var segment: Panel = top_bar_segments[faction_id] as Panel
        var seg_w: float = top_bar_total_width * ratio
        if faction_id == GameConfig.Faction.YELLOW:
            seg_w = maxf(50.0, top_bar_total_width + 3.0 - running_x)
        segment.position.x = running_x
        segment.size.x = maxf(50.0, seg_w)

        var fill: ColorRect = segment.get_node("Fill") as ColorRect
        fill.size = Vector2(maxf(4.0, segment.size.x - 4.0), segment.size.y - 4.0)
        fill.color = GameConfig.faction_color(faction_id)
        var gloss: ColorRect = segment.get_node("Gloss") as ColorRect
        gloss.size = Vector2(maxf(4.0, segment.size.x - 4.0), maxf(5.0, (segment.size.y - 4.0) * 0.42))
        var bottom_shadow: ColorRect = segment.get_node("BottomShadow") as ColorRect
        bottom_shadow.position = Vector2(2.0, maxf(4.0, segment.size.y - 8.0))
        bottom_shadow.size = Vector2(maxf(4.0, segment.size.x - 4.0), 4.0)
        if segment.has_node("Separator"):
            var sep: ColorRect = segment.get_node("Separator") as ColorRect
            sep.position = Vector2(segment.size.x - 2.0, 0.0)
            sep.size = Vector2(2.0, segment.size.y)

        var value_label: Label = top_bar_labels[faction_id] as Label
        var name_label: Label = top_bar_name_labels[faction_id] as Label
        value_label.text = "%d%%" % p
        name_label.text = GameConfig.faction_name(faction_id)
        name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.45))
        name_label.visible = true

        if segment.size.x < 110.0:
            name_label.position = Vector2(0, 1)
            name_label.size = Vector2(segment.size.x, 12)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 9 if is_mobile_layout else 11)

            value_label.position = Vector2(0, 10)
            value_label.size = Vector2(segment.size.x, 20)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 15 if is_mobile_layout else 18)
        else:
            name_label.position = Vector2(6, 2)
            name_label.size = Vector2(segment.size.x - 12.0, 14)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 10 if is_mobile_layout else 12)

            value_label.position = Vector2(0, -1)
            value_label.size = Vector2(segment.size.x, segment.size.y)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 18 if is_mobile_layout else 22)
        running_x += segment.size.x
