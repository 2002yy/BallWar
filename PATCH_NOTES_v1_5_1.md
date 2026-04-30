# Patch v1.5.1

Fixed Godot parser error:

`The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)`

Change:
- Replaced local `var name := ...` declarations with `var name = ...` across scripts.
- This avoids strict static inference from Dictionary/Array/Variant values when the project treats warnings as errors.
- Gameplay logic is unchanged from v1.5.
