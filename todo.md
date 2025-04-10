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

### Local Storage

- [ ] Design and implement database schema for workout data
  - [ ] Main workout table
  - [ ] Heart rate samples table
  - [ ] Route data table
  - [ ] Workout segments table
- [ ] Create WorkoutDatabaseService for local storage operations
  - [ ] Save workout with all related data
  - [ ] Retrieve workout with all related data
  - [ ] Query workouts by type, date range, etc.
  - [ ] Update and delete operations

### Backend Integration (Future)

- [ ] Design API endpoints for workout data
- [ ] Implement WorkoutSyncService
  - [ ] Sync workouts to backend
  - [ ] Fetch workouts from backend
  - [ ] Handle conflict resolution
- [ ] Add background sync functionality

### Privacy & Security

- [ ] Implement local encryption for sensitive health data
- [ ] Add user consent flows for data collection and sharing
- [ ] Create data retention policies
- [ ] Add options for users to delete their health data

### UI Enhancements

- [ ] Create detailed workout view with all metrics
- [ ] Add charts and visualizations for workout data
  - [ ] Heart rate chart
  - [ ] Pace chart
  - [ ] Elevation profile
  - [ ] Route map
- [ ] Implement workout comparison feature
- [ ] Add workout insights and trends analysis

## Other Health Data Integration

### Activity Data

- [ ] Implement step count tracking
- [ ] Implement active energy burned tracking
- [ ] Implement stand hours and exercise minutes

### Body Measurements

- [ ] Implement weight tracking
- [ ] Implement body fat percentage tracking
- [ ] Implement BMI calculation

### Heart Health

- [ ] Implement resting heart rate tracking
- [ ] Implement heart rate variability tracking
- [ ] Implement cardio fitness level (VO2 max)

### Sleep Data

- [ ] Implement sleep analysis
  - [ ] Sleep duration
  - [ ] Sleep stages (deep, REM, etc.)
  - [ ] Sleep quality metrics

## App Features

### User Experience

- [ ] Implement onboarding flow for health data permissions
- [ ] Create dashboard with health summary
- [ ] Add notification system for health insights
- [ ] Implement goal setting and tracking

### AI Integration

- [ ] Develop health data analysis algorithms
- [ ] Implement personalized recommendations
- [ ] Create natural language summaries of health data
- [ ] Add voice interface for health queries
