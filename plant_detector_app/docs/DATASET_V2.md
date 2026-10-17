# Dataset v2

## Status

Not started. A validation/test dataset and human-reviewed hard cases are required before Dataset v2 can be built safely.

## Hard Case Sources

Future Dataset v2 should prioritize:

- Real phone photos.
- Bright light, low light, backlight.
- Blurry or shaky images.
- Near and far plant shots.
- Occluded plants.
- Complex backgrounds.
- Classes that baseline confuses.

## Quality Rules

- Human review is required before adding model mistakes to training data.
- Keep train/val/test separated.
- Do not use model predictions as labels without verification.
- Preserve the existing 12 class IDs.
