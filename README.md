# Anthro Calculator App

Offline-first pediatric anthropometry for clinical use, following the **OMS
2006/2007** growth standards and Colombia's **Resolución 2465 de 2016**.

Implemented from the Claude Design project *Anthro OMS Calculator* (design system
turn 1a → screens). Material 3 with light + dark themes.

## Screens (`lib/screens/`)

| File | Design ref | Screen |
|------|-----------|--------|
| `splash.dart` | 3a / 3b | Branded splash with offline badge |
| `home.dart` | 1b | Dashboard: quick action, modules, patient preview |
| `calculator.dart` | 1c | Interactive data entry — live IMC, plausibility, reference & position toggles |
| `results.dart` | 1d / 2a | Per-indicator Z-scores + semaforización legend sheet |
| `charts_screen.dart` | 1e | LMS growth curves + quantitative deficit analysis |
| `velocity.dart` | 1f | Growth velocity between evaluations |
| `patients.dart` | 1i | Patient database with search & filters |
| `patient_detail.dart` | 1j | Patient file with measurement history |

## Structure

- `theme.dart` — design tokens (`AppPalette` light/dark), `ClinicalStatus` semaphore.
- `data.dart` — models, sample data, and `Anthro` clinical helpers (IMC, plausibility, position notes) translated from the design's logic.
- `widgets.dart` — shared components (cards, chips, segmented control, brand mark…).
- `charts.dart` — `LmsChart` and `ZScoreChart` `CustomPainter`s.

The app icon is drawn in code (`BrandMark`); the original logo asset could not be
retrieved intact through the design API (256 KiB read cap truncated the PNG).

## Run

```bash
flutter run
```

Toggle light/dark from the sun/moon icon in the home header.

## Test

```bash
flutter test
```

---
Desarrollado por [selpeca](https://www.linkedin.com/in/selpeca/).
