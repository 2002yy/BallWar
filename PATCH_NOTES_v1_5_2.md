# Patch v1.5.2

Fixed remaining Godot "Variant inference" warning-as-error.

Change:
- Replaced all `:=` occurrences with `=` in every `.gd` script.
- This includes local variables and constants.
- This is the safest option for projects where warnings are treated as errors.

Gameplay is unchanged from v1.5.
