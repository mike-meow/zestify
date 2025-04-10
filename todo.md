# Health AI App TODOs

## Apple HealthKit Data Integration

### Core Workout Data Handling

- [x] Fix workout type mapping from Apple Health
- [x] Fix workout duration calculation
- [x] Add formatted display methods for workout data
- [x] Add additional workout properties to the Workout model:
  - [x] Max heart rate
  - [x] Min heart rate
  - [x] Average pace
  - [x] Max pace
  - [x] Total ascent/descent (elevation data)
  - [x] Step count during workout
  - [x] Cadence data
  - [x] Power output (for cycling)

### Advanced Workout Data

- [x] Implement heart rate time series data collection
  - [x] Create HeartRateSample model
  - [x] Update health service to fetch heart rate samples
  - [x] Add basic heart rate statistics display
- [x] Implement route/GPS data collection for outdoor workouts
  - [x] Create RoutePoint model
  - [ ] Update health service to fetch route data
  - [ ] Add map visualization for workout routes
- [x] Implement workout segments/intervals tracking
  - [x] Create WorkoutSegment model
  - [ ] Update health service to fetch segment data
  - [ ] Add visualization for workout splits

## step 1

- [] fix heart rate series data
- [] fix workout history length, now I only see up to last month, fetch all the years we can find
- [] fetch all biometrics
