# Patch v1.5

Gameplay update:

1. Turrets now use smooth 90-degree cyclic sweeping.
   - Each turret has a fixed inward-facing center angle.
   - It sweeps ±45 degrees using a sine wave.
   - Firing does not interrupt turret rotation.

2. Added control buttons at the bottom of the screen.
   - Each faction has a "+控制球" button.
   - Adds one extra control ball to that faction's chamber.
   - Each chamber supports up to 8 control balls.
   - More balls means more frequent x2/R triggers and faster firing.

3. Added turret health and destruction.
   - Each turret has 30 HP.
   - Enemy bullets can hit turrets and reduce HP.
   - At 0 HP, the turret stops firing.
   - Its corresponding control chamber becomes damaged.
   - Damaged chamber removes control balls, stops triggering, and shows a broken animation.
   - When only one turret remains, the winner is displayed.

4. Bullet interaction:
   - Bullets now check enemy turret hit radius before grid capture.
   - A bullet that hits a turret is absorbed and disappears.
