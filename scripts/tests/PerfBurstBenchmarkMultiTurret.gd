extends "res://scripts/tests/PerfBurstBenchmark.gd"

func _benchmark_label() -> String:
	return "PerfBurstBenchmarkMultiTurret"

func _benchmark_version() -> String:
	return "2.1.4-multi-turret"

func _json_report_path() -> String:
	return "user://test_reports/perf_burst_benchmark_multi_turret.json"

func _csv_report_path() -> String:
	return "user://test_reports/perf_burst_benchmark_multi_turret.csv"

func _build_case_defs() -> Array:
	return [
		{
			"case_name": "stress_60_mid_four_turrets",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [
				GameConfig.Faction.BLUE,
				GameConfig.Faction.RED,
				GameConfig.Faction.GREEN,
				GameConfig.Faction.YELLOW,
			],
			"pending_values": [512, 1024],
		},
		{
			"case_name": "stress_60_high_four_turrets",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_HIGH,
			"turret_ids": [
				GameConfig.Faction.BLUE,
				GameConfig.Faction.RED,
				GameConfig.Faction.GREEN,
				GameConfig.Faction.YELLOW,
			],
			"pending_values": [512, 1024],
		},
	]
