# Patch v1.2

User-requested implementation fixes:

1. Turrets are moved closer to the battlefield corners/edges.
2. Turrets now rotate only within the inward-facing 90-degree arc for their quadrant.
   - Top-left: right/down
   - Top-right: left/down
   - Bottom-left: right/up
   - Bottom-right: left/up
3. The bottom of each control chamber is fully occupied by two exits:
   - left half: x2 multiplier
   - right half: R release
   The control ball has no third bottom choice. A deterministic bottom routing check is added
   so even if Area2D overlap misses at high speed, the ball will still choose x2 or R.
