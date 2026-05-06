from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


@dataclass
class FileIndentStats:
	path: Path
	tab_lines: int = 0
	space_lines: int = 0
	mixed_lines: int = 0
	indented_lines: int = 0

	@property
	def style(self) -> str:
		if self.mixed_lines > 0:
			return "MIXED"
		if self.tab_lines > 0 and self.space_lines > 0:
			return "MIXED"
		if self.tab_lines > 0:
			return "TAB"
		if self.space_lines > 0:
			return "SPACE"
		return "NONE"

	@property
	def suspicious(self) -> bool:
		return self.mixed_lines > 0 or (self.tab_lines > 0 and self.space_lines > 0)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description="Audit leading indentation style for all GDScript files."
	)
	parser.add_argument(
		"path",
		nargs="?",
		default=".",
		help="Project root or subdirectory to scan. Defaults to current directory.",
	)
	return parser.parse_args()


def collect_stats(file_path: Path) -> FileIndentStats:
	stats = FileIndentStats(path=file_path)
	with file_path.open("r", encoding="utf-8", errors="replace", newline="") as handle:
		for raw_line in handle:
			line = raw_line.rstrip("\r\n")
			if not line.strip():
				continue

			indent_width = len(line) - len(line.lstrip(" \t"))
			if indent_width <= 0:
				continue

			indent = line[:indent_width]
			has_tab = "\t" in indent
			has_space = " " in indent

			stats.indented_lines += 1
			if has_tab and has_space:
				stats.mixed_lines += 1
			elif has_tab:
				stats.tab_lines += 1
			elif has_space:
				stats.space_lines += 1

	return stats


def iter_gd_files(root: Path) -> list[Path]:
	return sorted(
		path
		for path in root.rglob("*.gd")
		if path.is_file()
	)


def print_report(stats_list: list[FileIndentStats], root: Path) -> None:
	if not stats_list:
		print("No .gd files found.")
		return

	relative_names = [stats.path.relative_to(root).as_posix() for stats in stats_list]
	name_width = max(len(name) for name in relative_names) + 2

	tab_file_count = 0
	space_file_count = 0
	mixed_file_count = 0

	for name, stats in zip(relative_names, stats_list):
		if stats.style == "TAB":
			tab_file_count += 1
		elif stats.style == "SPACE":
			space_file_count += 1
		elif stats.style == "MIXED":
			mixed_file_count += 1

		print(
			f"{name:<{name_width}}"
			f"{stats.style:<6} "
			f"tab={stats.tab_lines:<5} "
			f"space={stats.space_lines:<5} "
			f"mixed={stats.mixed_lines:<5} "
			f"indented={stats.indented_lines}"
		)

	print()
	print(
		f"Summary: TAB files={tab_file_count}  "
		f"SPACE files={space_file_count}  "
		f"MIXED files={mixed_file_count}"
	)

	suspicious = [stats for stats in stats_list if stats.suspicious]
	print()
	print("Suspicious files:")
	if not suspicious:
		print("  (none)")
		return

	for stats in suspicious:
		name = stats.path.relative_to(root).as_posix()
		print(
			f"  {name} -> {stats.style} "
			f"(tab={stats.tab_lines}, space={stats.space_lines}, mixed={stats.mixed_lines})"
		)


def main() -> int:
	args = parse_args()
	root = Path(args.path).resolve()
	if not root.exists():
		print(f"Path not found: {root}")
		return 1

	files = iter_gd_files(root)
	stats_list = [collect_stats(path) for path in files]
	print_report(stats_list, root)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
