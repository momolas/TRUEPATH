# BallisticsKit (TRUEPATH)

A high-performance Swift 6 port and modern evolution of the `libballistics` library, designed for accurate and efficient ballistics simulation.

## Features

- **Accurate trajectory calculations** with 3-DOF point-mass numerical integration (`Solver3DOF`) and continuous query interpolation
- **High-Fidelity 6-DOF Simulation**: Full rigid-body 6-DOF solver (`Solver6DOF`) following STANAG 4355 / McCoy standards
- **Aerodynamic Drag Models**: Support for standard **G1, G2, G5, G6, G7, and G8** profiles, plus Doppler radar **Custom Drag Models (CDM)**
- **Ballistic Truing**: Live-fire calibration of true muzzle velocity ($V_0$) and ballistic coefficient ($BC$) via `Truing`
- **Incline Shooting**: Rifleman's rule and Sierra improved cosine approximations via `InclineShooting`
- **Dynamic Speed of Sound**: Real-time thermodynamic speed of sound $c(T)$ based on atmospheric temperature
- **Point Blank Range (PBR)** solver for vital zone target optimization
- **Integrated Advanced Long-Range Physics**:
  - Gyroscopic Spin Drift (`SpinDrift`) with Miller stability factor ($S_g$)
  - Earth rotation deflections (`Coriolis` horizontal & Eötvös vertical effects)
  - Aerodynamic Jump (`AerodynamicJump`)
  - Powder Temperature Sensitivity (`PowderSensitivity`)
  - Danger Space (`DangerSpace`) calculation
- **Optics & Field Tools**:
  - Direct Turret Click conversion (`1/4 MOA`, `1/8 MOA`, `0.1 MIL / MRAD`) on `Point`
  - Reticle Ranging & Subtensions (`Ranging`)
  - Mach flight regime detection (`isSupersonic`, `isTransonic`, `isSubsonic`)
  - Sectional density ($SD$), form factor ($i$), and ballistic coefficient reconstruction via `SectionalDensity`
- **Atmospheric corrections** (altitude, barometric pressure, temperature, relative humidity)
- **Type-Safe Units**: Native integration with Foundation `Measurement` (`UnitLength`, `UnitSpeed`, `UnitAngle`, `UnitMass`, `UnitEnergy`, `UnitPressure`, `UnitTemperature`, `UnitDuration`)
- Concurrency-ready (`Sendable`, Swift 6 strict mode)

## Installation

### Swift Package Manager (SPM)

To include `SwiftBallistics` in your project, add it as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/momolas/BallisticsKit.git", .upToNextMajor(from: "1.2.2"))
]
```

## Usage

### 1. Calculate Ballistic Trajectory (with Advanced Long-Range Options)

```swift
import BallisticsKit

// Generate a comprehensive ballistic solution
let solution = Ballistics.solve3DOF(
    preferredDistanceUnit: .yards, // Distance units used for trajectory sampling
    dragFunction: .g7, // .g1, .g2, .g5, .g6, .g7, .g8
    dragCoefficient: 0.265, // Projectile ballistic coefficient
    initialVelocity: Measurement(value: 2750, unit: .feetPerSecond), // Initial muzzle velocity
    sightHeight: Measurement(value: 1.5, unit: .inches), // Sight offset from bore
    shootingAngle: Measurement(value: 0, unit: .degrees), // Firing angle (+ up, - down)
    zeroRange: Measurement(value: 100, unit: .yards), // Zeroed distance
    atmosphere: Atmosphere(
        altitude: Measurement(value: 1500, unit: .feet),
        pressure: Measurement(value: 29.92, unit: .inchesOfMercury),
        temperature: Measurement(value: 59, unit: .fahrenheit),
        relativeHumidity: 0.5
    ),
    windSpeed: Measurement(value: 10, unit: .milesPerHour),
    windAngle: 90, // 0=headwind, 90=left-to-right, 180=tailwind, 270=right-to-left
    weight: Measurement(value: 175, unit: .grains),
    twist: Measurement(value: 10, unit: .inches), // 1:10" twist rate
    twistDirection: .right,
    bulletDiameter: Measurement(value: 0.308, unit: .inches),
    bulletLength: Measurement(value: 1.24, unit: .inches),
    latitude: Measurement(value: 45, unit: .degrees), // 45° N latitude
    azimuth: Measurement(value: 90, unit: .degrees) // Shooting East
)

// Smooth continuous interpolation supported at any arbitrary distance!
if let point = solution.getPoint(at: Measurement(value: 735.5, unit: .yards)) {
    print("Range: \(point.range)")
    print("Drop: \(point.drop)")
    print("Drop Correction: \(point.dropCorrection)")
    print("Crosswind Drift: \(point.windage)")
    print("Spin Drift: \(point.spinDrift ?? Measurement(value: 0, unit: .inches))")
    print("Coriolis Horizontal: \(point.coriolisHorizontal ?? Measurement(value: 0, unit: .inches))")
    print("Total Windage: \(point.totalWindage)")
    print("Total Windage Correction: \(point.totalWindageCorrection)")
    print("Turret Clicks (0.1 MIL): \(point.totalElevationClicks(.pointOneMRAD)) Up, \(point.totalWindageClicks(.pointOneMRAD)) Right")
    print("Flight Regime: Transonic? \(point.isTransonic()), Subsonic? \(point.isSubsonic())")
}
```

### 2. Ballistic Truing (Calibrating V0 & BC on Live Fire)

```swift
// Calibrate true muzzle velocity based on actual mid-range impact (e.g. 500 yds with 11.2 MOA dialed)
let truingV0 = Truing.calibrateMuzzleVelocity(
    observedDropCorrection: Measurement(value: 11.2, unit: .minutesOfAngle),
    atDistance: Measurement(value: 500, unit: .yards),
    dragFunction: .g1,
    dragCoefficient: 0.450,
    sightHeight: Measurement(value: 1.5, unit: .inches),
    zeroRange: Measurement(value: 100, unit: .yards)
)

if case .success(let trueV0) = truingV0 {
    print("Calibrated True Muzzle Velocity: \(trueV0.converted(to: .feetPerSecond))")
}

// Calibrate true BC at long range (e.g. 900 yds with 28.5 MOA dialed)
let truingBC = Truing.calibrateBallisticCoefficient(
    observedDropCorrection: Measurement(value: 28.5, unit: .minutesOfAngle),
    atDistance: Measurement(value: 900, unit: .yards),
    muzzleVelocity: Measurement(value: 2650, unit: .feetPerSecond),
    dragFunction: .g7,
    sightHeight: Measurement(value: 1.5, unit: .inches),
    zeroRange: Measurement(value: 100, unit: .yards)
)

if case .success(let trueBC) = truingBC {
    print("Calibrated True BC: \(trueBC)")
}
```

### 3. Incline Shooting (Uphill & Downhill Fire)

```swift
// Rifleman's rule equivalent horizontal range for a 600m target at 25° incline
let flatRange = InclineShooting.riflemanEquivalentRange(
    lineOfSightRange: Measurement(value: 600, unit: .meters),
    inclineAngle: Measurement(value: 25, unit: .degrees)
) // ~543.8 meters
```

### 4. Optics & Turret Clicks

```swift
// Get exact click adjustments for 1/4 MOA or 0.1 MRAD turrets
let elevClicksMOA = point.elevationClicks(.oneFourthMOA)
let elevClicksMIL = point.elevationClicks(.pointOneMRAD)
let totalWindageClicks = point.totalWindageClicks(.pointOneMRAD)
```

### 5. Reticle Ranging (Mil-Dot & MOA)

```swift
// Estimate distance to a 0.5m target measuring 1.2 MIL in the scope
let targetDistance = Ranging.distance(
    targetSize: Measurement(value: 0.5, unit: .meters),
    angularSize: Measurement(value: 1.2, unit: .milliradians)
) // ~416.7 meters
```

### 6. Danger Space (Hit Window Margin)

```swift
// Calculate tolerance window for a 20-inch target at 600 yards
let danger = DangerSpace.calculate(
    solution: solution,
    targetDistance: Measurement(value: 600, unit: .yards),
    targetHeight: Measurement(value: 20, unit: .inches)
)
print("Danger Space Window: \(danger.nearBound) to \(danger.farBound) (Depth: \(danger.totalDepth))")
```

### 7. Powder Temperature Sensitivity & Aerodynamic Jump

```swift
// Adjust muzzle velocity from 59°F base to 95°F hot summer condition (+1.5 fps/°F)
let vHot = PowderSensitivity.adjustedVelocity(
    baseVelocity: Measurement(value: 2700, unit: .feetPerSecond),
    baseTemperature: Measurement(value: 59, unit: .fahrenheit),
    currentTemperature: Measurement(value: 95, unit: .fahrenheit),
    sensitivityFPSPerDegreeF: 1.5
) // 2754 fps

// Aerodynamic jump from 15 mph crosswind
let jump = AerodynamicJump.jumpAngle(
    crosswindSpeed: Measurement(value: 15, unit: .milesPerHour),
    initialVelocity: Measurement(value: 2700, unit: .feetPerSecond),
    twistDirection: .right
)
```

### 8. Point Blank Range (PBR)

```swift
// Solve for an 8-inch vital zone target
let pbrResult = PBR.solve(
    dragFunction: .g1,
    dragCoefficient: 0.414,
    initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
    sightHeight: Measurement(value: 1.5, unit: .inches),
    vitalSize: Measurement(value: 8, unit: .inches)
)

if case .success(let pbr) = pbrResult {
    print("Near Zero: \(pbr.nearZeroYards) yards")
    print("Far Zero: \(pbr.farZeroYards) yards")
    print("Max PBR: \(pbr.maxPBRYards) yards")
}
```

### 9. Monte Carlo Ballistic Dispersion (Apple Accelerate vDSP)

Simulate shot group dispersion and calculate statistics (Mean Point of Impact, Extreme Spread, Standard Deviation, CEP 50% radius, R95) accelerated with Apple Accelerate `vDSP`:

```swift
let dispersion = MonteCarloDispersion(
    muzzleVelocitySD: Measurement(value: 12, unit: .feetPerSecond),
    windSpeedSD: Measurement(value: 2.0, unit: .milesPerHour),
    shooterAngularSD: Measurement(value: 0.35, unit: .minutesOfAngle)
)

let result = MonteCarlo.simulate(
    shotCount: 200,
    targetDistance: Measurement(value: 600, unit: .yards),
    dispersion: dispersion,
    dragFunction: .g7,
    dragCoefficient: 0.265,
    nominalVelocity: Measurement(value: 2750, unit: .feetPerSecond),
    sightHeight: Measurement(value: 1.5, unit: .inches),
    zeroRange: Measurement(value: 100, unit: .yards)
)

print("CEP (50% radius): \(result.cep50)")
print("R95 (95% radius): \(result.r95)")
print("Extreme Spread Vertical: \(result.extremeSpreadVertical)")
print("Extreme Spread Horizontal: \(result.extremeSpreadHorizontal)")
```

### 10. Vectorized Aerodynamic Drag Table Lookups (`vDSP_vlintD`)

Interpolate whole arrays of Mach numbers in $O(1)$ SIMD instructions with Apple Accelerate:

```swift
let cdm = CustomDragModel(dataPoints: [
    .init(mach: 0.5, cd: 0.15),
    .init(mach: 1.0, cd: 0.42),
    .init(mach: 2.0, cd: 0.30)
])

let machQueries = [0.7, 0.95, 1.1, 1.5]
let batchCd = cdm.dragCoefficients(atMachArray: machQueries)
```

