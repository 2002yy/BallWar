# BallWar Tests

## Test runner

Run all automated tests:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --headless --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script res://tests/TestRunner.gd
```

## Performance benchmark

Run the conservative burst benchmark:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --headless --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script res://tests/PerfBurstBenchmark.gd
```

The benchmark writes:

```text
user://test_reports/perf_burst_benchmark.json
```

## Current coverage

- `TestEventRoulette.gd`
- `TestControlChamber.gd`
- `TestSaveGameCodec.gd`
- `TestBattlefield.gd`

## Notes

- Tests are designed to run without editor UI.
- If headless still crashes in the Codex environment, run them on the desktop machine with the same commands.
