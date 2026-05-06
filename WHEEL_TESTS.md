# Lucky Wheel Manual Test Plan

## Test 1: Deterministic Reward Index 1
1. In `src/shared/Configs/WheelConfig.luau`, set reward 1 weight to `1` and all other reward weights to `0`.
2. Run 10 spins.
3. Expected:
- Server returns `RewardIndex = 1` each spin.
- Wheel lands with segment 1 center under pointer each spin.

## Test 2: Deterministic Reward Index 4
1. In `src/shared/Configs/WheelConfig.luau`, set reward 4 weight to `1` and all other reward weights to `0`.
2. Run 10 spins.
3. Expected:
- Server returns `RewardIndex = 4` each spin.
- Wheel lands with segment 4 center under pointer each spin.

## Test 3: Weighted Distribution Sanity
1. Restore normal weights in `src/shared/Configs/WheelConfig.luau`.
2. Run 50 spins.
3. Expected:
- Approximate distribution follows configured weights.
- No mismatch between server reward and visual landing.

## Test 4: Button Spam / Concurrency
1. Spam the spin button rapidly.
2. Expected:
- Only one active spin at a time.
- Additional requests are rejected by server lock/rate-limit.

## Test 5: Free Spin Daily Lock
1. Use all free spins for current UTC day.
2. Rejoin and try free spin again same UTC day.
3. Expected:
- Server rejects with free-spin message and next-UTC timestamp.

## Test 6: Next UTC Day Reset
1. Advance to next UTC day (or simulate server time in test environment).
2. Try free spin again.
3. Expected:
- Free spin is available again.

## Alignment Debug Mode
1. Set `WheelConfig.DebugMode = true`.
2. Spin the wheel.
3. Confirm output includes:
- `rewardIndex`
- `segmentAngle`
- `segmentCenterAngle`
- `targetRotation`
- `finalRotationMod`

If segment centers do not align, adjust `WheelConfig.WheelVisualOffset` and repeat.
