# Patch v1.1

Fixed:

`Bullet.gd:18 @_ready(): Can't change this state while flushing queries`

Cause:
Bullets were implemented as `Area2D` and were spawned from an `Area2D.area_entered` gate signal.
Godot was still flushing physics queries, so changing Area2D collision/monitoring state in the new
bullet's `_ready()` triggered the runtime error.

Fix:
`Bullet.gd` now extends `Node2D`. This is enough for V1 because bullet behavior is grid-based:
bullet position -> battlefield cell -> recolor / disappear. Bullet physics collision is not needed.

Also reduced integer division warnings in `Battlefield.gd`.
