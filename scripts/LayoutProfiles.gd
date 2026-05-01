extends RefCounted
class_name LayoutProfiles

static func sanitize_grid_size(value) -> int:
    var n: int = int(value)
    if n in [10, 20, 30, 40, 50, 60]:
        return n
    return 40

static func get_profile(grid_size: int) -> Dictionary:
    match grid_size:
        10:
            return {
                "map_y": 178.0,
                "chamber_scale": 0.74,
                "left_chamber_y_top": 136.0,
                "left_chamber_y_bottom": 396.0,
                "chamber_gap": 14.0,
                "button_gap": 10.0,
                "button_size": Vector2(86.0, 44.0),
                "top_panel_w": 660.0,
                "top_panel_h": 84.0,
                "bar_h": 34.0,
                "title_font": 26,
                "title_y": 42.0,
                "palette_font": 15,
                "winner_y": 672.0,
                "banner_title_y": 304.0,
                "banner_sub_y": 356.0,
            }
        20:
            return {
                "map_y": 128.0,
                "chamber_scale": 0.76,
                "left_chamber_y_top": 136.0,
                "left_chamber_y_bottom": 382.0,
                "chamber_gap": 12.0,
                "button_gap": 10.0,
                "button_size": Vector2(86.0, 44.0),
                "top_panel_w": 700.0,
                "top_panel_h": 86.0,
                "bar_h": 35.0,
                "title_font": 28,
                "title_y": 44.0,
                "palette_font": 15,
                "winner_y": 670.0,
                "banner_title_y": 302.0,
                "banner_sub_y": 356.0,
            }
        30:
            return {
                "map_y": 108.0,
                "chamber_scale": 0.78,
                "left_chamber_y_top": 120.0,
                "left_chamber_y_bottom": 374.0,
                "chamber_gap": 10.0,
                "button_gap": 10.0,
                "button_size": Vector2(88.0, 46.0),
                "top_panel_w": 730.0,
                "top_panel_h": 88.0,
                "bar_h": 36.0,
                "title_font": 30,
                "title_y": 45.0,
                "palette_font": 16,
                "winner_y": 668.0,
                "banner_title_y": 296.0,
                "banner_sub_y": 348.0,
            }
        40:
            return {
                "map_y": 108.0,
                "chamber_scale": 0.80,
                "left_chamber_y_top": 104.0,
                "left_chamber_y_bottom": 362.0,
                "chamber_gap": 8.0,
                "button_gap": 11.0,
                "button_size": Vector2(88.0, 46.0),
                "top_panel_w": 710.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 31,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 666.0,
                "banner_title_y": 292.0,
                "banner_sub_y": 344.0,
            }
        50:
            return {
                "map_y": 106.0,
                "chamber_scale": 0.78,
                "left_chamber_y_top": 96.0,
                "left_chamber_y_bottom": 354.0,
                "chamber_gap": 7.0,
                "button_gap": 11.0,
                "button_size": Vector2(88.0, 46.0),
                "top_panel_w": 710.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 31,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 666.0,
                "banner_title_y": 292.0,
                "banner_sub_y": 344.0,
            }
        60:
            return {
                "map_y": 106.0,
                "chamber_scale": 0.76,
                "left_chamber_y_top": 100.0,
                "left_chamber_y_bottom": 352.0,
                "chamber_gap": 6.0,
                "button_gap": 10.0,
                "button_size": Vector2(86.0, 40.0),
                "top_panel_w": 710.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 30,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 666.0,
                "banner_title_y": 294.0,
                "banner_sub_y": 346.0,
            }
        _:
            return get_profile(40)
