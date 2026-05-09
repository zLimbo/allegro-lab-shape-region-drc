# Shape Region Rule Case Design

## Goal

This plan validates the current hypothesis for Allegro `static shape + shape-to-line`
spacing DRC:

1. Allegro first selects a representative DRC location.
2. The selected location maps to a `shape-side reference point`.
3. A region is effective only when that reference point is inside the region or on
   its boundary.
4. If multiple regions are effective, non-nested regions appear to choose the
   stricter spacing, while nested regions may prefer the more specific inner region.

The cases below are designed as small, reproducible geometry perturbations. Each
case should change only one meaningful variable from its control case.

## Common Setup

- Shape type: `static shape`
- DRC type: `shape to line`
- Default line-to-shape spacing: `0.11 mm`
- R1 spacing: `0.21 mm`
- R2 spacing: `0.22 mm`, unless a value-swap case says otherwise
- Actual line-to-shape distance: `0.10 mm`
- Expected DRC marker side: line side
- Record for every case:
  - DRC origin xy
  - line element location from Show Constraints
  - shape element location from Show Constraints
  - reported constraint value and source
  - whether the shape-side reference point is inside, outside, or on a region boundary

## Case Groups

### G1: Single Region Boundary Semantics

These cases verify whether `inside` and all boundary variants are treated as
effective, and whether `outside` always falls back to default.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr015 | Edge boundary, non-vertex | Move R1 so the shape-side reference point lies on a straight R1 edge but not on a corner. | R1, `0.21 mm` |
| sr016 | Boundary just outside by epsilon | Move R1 outward from sr015 by a small epsilon, keeping visual geometry nearly identical. | Default, `0.11 mm` |
| sr017 | Boundary just inside by epsilon | Move R1 inward from sr015 by a small epsilon. | R1, `0.21 mm` |
| sr018 | Region vertex with line not crossing region | Place only the shape-side reference point on an R1 vertex; keep line fully outside R1. | R1, `0.21 mm` |
| sr019 | Shape reference point outside, line-side DRC location inside | Put the DRC marker on line inside R1, but keep the shape-side reference point outside R1. | Default, `0.11 mm` |
| sr020 | Shape reference point inside, line-side DRC location outside | Inverse of sr019. | R1, `0.21 mm` |

Pass condition: sr019 and sr020 should differ. If they do, the rule depends on
the shape-side reference point rather than the line-side marker.

### G2: Endpoint Geometry Type

These cases check whether the geometry class of the shape-side point is irrelevant
after its region membership is known.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr021 | Segment midpoint inside | Use a straight shape edge; nearest point is on the edge interior and inside R1. | R1, `0.21 mm` |
| sr022 | Segment midpoint outside | Same as sr021, move R1 so the same nearest point is outside. | Default, `0.11 mm` |
| sr023 | Arc midpoint inside | Use an arc edge; nearest point is on arc interior and inside R1. | R1, `0.21 mm` |
| sr024 | Arc midpoint outside | Same as sr023, move R1 so the same nearest point is outside. | Default, `0.11 mm` |
| sr025 | Concave shape vertex inside | Use a concave static shape where the nearest point is a concave vertex inside R1. | R1, `0.21 mm` |
| sr026 | Concave shape vertex outside | Same as sr025, but nearest point outside R1. | Default, `0.11 mm` |

Pass condition: for each pair, only region membership changes the result.

### G3: Overall Region Relation Is Not Sufficient

These cases make the overall object-region relation misleading on purpose.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr027 | Overall cross, reference outside | Shape or line crosses R1, but selected shape-side reference point is outside. | Default, `0.11 mm` |
| sr028 | Overall no cross, reference inside | R1 covers only the shape-side reference point area; the line does not cross R1. | R1, `0.21 mm` |
| sr029 | Shape mostly inside, reference outside | Most of the static shape is inside R1, but the nearest shape-side point is outside. | Default, `0.11 mm` |
| sr030 | Shape mostly outside, reference inside | Only a small local shape-side area around the nearest point is inside R1. | R1, `0.21 mm` |

Pass condition: results follow reference-point membership, not object-level labels.

### G4: Representative DRC Location Selection

These cases target non-unique shortest-gap situations. Their main purpose is to
identify the representative-location selection rule, not just the region rule.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr031 | Long parallel equal-gap band, upper half covered | Shape edge and cline are parallel for a long span; R1 covers only the upper half of possible nearest positions. | Reveals whether representative point is upper/lower/center biased |
| sr032 | Long parallel equal-gap band, lower half covered | Same as sr031 but R1 covers only lower half. | Complement of sr031 |
| sr033 | Long parallel equal-gap band, middle covered | R1 covers only the middle portion of the equal-gap band. | Reveals center preference |
| sr034 | Same band, line direction reversed | Same geometry as sr031, reverse cline start/end direction. | Same as sr031 if direction-independent |
| sr035 | Same band, shape vertex order reversed | Recreate static shape with reversed vertex order if possible. | Same as sr031 if polygon-order-independent |
| sr036 | Equal-gap band split by tiny notch | Add a tiny notch to break the equal-gap band into two equal minima. | Reveals tie-break between disconnected candidates |
| sr037 | Near-equal but unique minimum | Perturb one end by epsilon so only one location is truly closest and inside R1. | R1 if Allegro uses geometric minimum strictly |
| sr038 | Near-equal but unique minimum outside | Same as sr037, unique minimum outside R1 while another nearly equal segment is inside. | Default if strict minimum wins |

Pass condition: sr031-sr038 should clarify whether Allegro chooses by lower-left,
center, object order, segment order, or strict geometric minimum.

### G5: Multiple Non-Nested Regions

These cases test whether valid non-nested regions always resolve to the stricter
spacing, and whether the result is independent of region name and creation order.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr039 | Overlap, R1 stricter | Reference point lies in both R1 and R2; R1 = `0.22`, R2 = `0.21`. | `0.22 mm` |
| sr040 | Overlap, R2 stricter | Same geometry as sr039; swap values. | `0.22 mm` |
| sr041 | Touching regions, point on shared edge | R1 and R2 touch at an edge; reference point lies on the shared edge. | Stricter value if both boundary hits are effective |
| sr042 | Touching regions, point on shared vertex | R1 and R2 touch at one vertex; reference point lies exactly on that vertex. | Stricter value if both boundary hits are effective |
| sr043 | R1 inside, R2 boundary | Reference point is inside R1 and on R2 boundary; regions are not nested. | Unknown: validates inside vs boundary priority |
| sr044 | R1 boundary, R2 inside | Inverse of sr043. | Compare with sr043 |
| sr045 | Creation order A | Create R1 first, then R2; both effective and non-nested. | Stricter value |
| sr046 | Creation order B | Same geometry as sr045, create R2 first, then R1. | Same as sr045 if order-independent |

Pass condition: sr039-sr046 should either confirm stricter-value resolution or
expose hidden priority from boundary status or creation order.

### G6: Nested Regions

These cases verify whether inner-region priority is stable and what happens when
the reference point lies on nested boundaries.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr047 | Inner less strict, outer more strict | R2 contains R1; reference point inside R1; R1 = `0.21`, R2 = `0.22`. | R1, `0.21 mm` if inner priority holds |
| sr048 | Inner more strict, outer less strict | Same as sr047, swap values. | R1, `0.22 mm` if inner priority holds |
| sr049 | Point inside outer only | R2 contains R1; reference point inside R2 but outside R1. | R2 |
| sr050 | Point on inner boundary, inside outer | Reference point lies on R1 boundary and inside R2. | R1 if inner boundary is effective and inner priority holds |
| sr051 | Point on outer boundary and inside inner impossible-control | Place R1 touching R2 boundary so reference point is inside/touching R1 and on R2 boundary. | Reveals boundary plus nesting priority |
| sr052 | Three-level nesting | R3 contains R2 contains R1; reference point inside all three. | Innermost region if specificity is recursive |
| sr053 | Three-level nesting, middle excludes point | R3 contains R2 contains R1 spatially, but reference point inside R3 and R1 only if geometry allows a ring-like R2 or equivalent compound region. | Tests whether all containers must be simple polygons |

Pass condition: sr047-sr052 should settle whether "most specific region" is a real
priority rule or just an accident of c014.

### G7: Region Boundary Numerical Robustness

These cases are for tolerance behavior. They should be run with exact coordinates
and with small offsets such as `0.001 mm`, `0.0001 mm`, and one database unit.

| Case | Purpose | Geometry Delta | Expected |
| --- | --- | --- | --- |
| sr054 | Boundary plus one DBU inside | Move R1 so reference point is one database unit inside. | R1 |
| sr055 | Boundary exact | Reference point exactly on edge. | R1 |
| sr056 | Boundary plus one DBU outside | Move R1 so reference point is one database unit outside. | Default unless Allegro uses tolerance |
| sr057 | Nearly tangent arc boundary | Arc nearest point lies nearly tangent to R1 edge. | Determines tolerance handling |

Pass condition: these cases define the compatibility tolerance for `IsOnRegionBoundary`.

## Suggested Execution Order

1. Run G1 and G3 first. They validate the central single-region rule.
2. Run G4 next. Without representative-location behavior, later multi-region
   observations can be misread.
3. Run G5 and G6 for multi-region arbitration.
4. Run G7 last to quantify tolerance.

## Minimal Regression Set

If time is limited, run this smaller set:

- sr015, sr016, sr019, sr020
- sr021, sr023
- sr031, sr032, sr034, sr037, sr038
- sr039, sr040, sr043, sr044
- sr047, sr048, sr049, sr050, sr052
- sr054, sr055, sr056

This subset covers the three main hypotheses and the riskiest edge behavior.
