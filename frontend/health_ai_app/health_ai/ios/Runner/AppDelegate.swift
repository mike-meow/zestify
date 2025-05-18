import Flutter
import UIKit
import HealthKit
import CoreLocation

// Native implementation of HealthKit access for more accurate workout data
class NativeHealthService {
    private let healthStore = HKHealthStore()
    private var channel: FlutterMethodChannel?
    private let iso8601Formatter = ISO8601DateFormatter()

    // Register the method channel with Flutter
    func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "com.healthai.health/native", binaryMessenger: registrar.messenger())
        channel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "initialize":
                self.initialize(completion: result)

            case "getWorkoutKilometerSplits":
                if let args = call.arguments as? [String: Any],
                   let workoutId = args["workoutId"] as? String {
                    self.getWorkoutKilometerSplits(workoutId: workoutId, completion: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }

            case "getWorkoutsWithSplits":
                if let args = call.arguments as? [String: Any] {
                    let startDateString = args["startDate"] as? String
                    let endDateString = args["endDate"] as? String

                    var startDate: Date? = nil
                    var endDate: Date? = nil

                    if let startDateString = startDateString {
                        startDate = iso8601Formatter.date(from: startDateString)
                    }

                    if let endDateString = endDateString {
                        endDate = iso8601Formatter.date(from: endDateString)
                    }

                    self.getWorkoutsWithSplits(startDate: startDate, endDate: endDate, completion: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // Initialize the health store and request permissions
    private func initialize(completion: @escaping FlutterResult) {
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization successful")
                    completion(true)
                } else {
                    print("HealthKit authorization failed: \(String(describing: error))")
                    completion(false)
                }
            }
        }
    }

    // Get kilometer splits for a specific workout
    private func getWorkoutKilometerSplits(workoutId: String, completion: @escaping FlutterResult) {
        print("Native: getWorkoutKilometerSplits called with ID: \(workoutId)")

        // Try to create a UUID from the workout ID
        guard let uuid = UUID(uuidString: workoutId) else {
            // If the ID is not a valid UUID, it might be a timestamp
            // In this case, we'll try to find the workout by date
            if let timestamp = Double(workoutId) {
                print("Native: Converting timestamp to date: \(timestamp)")
                let date = Date(timeIntervalSince1970: timestamp / 1000.0)
                findWorkoutByDate(date: date, completion: completion)
                return
            }

            print("Native: Invalid workout ID format: \(workoutId)")
            completion(FlutterError(code: "INVALID_ID", message: "Invalid workout ID", details: nil))
            return
        }

        // Create a predicate to find the specific workout by UUID
        let predicate = HKQuery.predicateForObject(with: uuid)

        // Create the workout query
        let workoutQuery = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                        predicate: predicate,
                                        limit: 1,
                                        sortDescriptors: nil) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "QUERY_ERROR",
                                           message: "Error querying workout: \(error.localizedDescription)",
                                           details: nil))
                }
                return
            }

            guard let workouts = samples as? [HKWorkout], let workout = workouts.first else {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "WORKOUT_NOT_FOUND",
                                           message: "Workout not found",
                                           details: nil))
                }
                return
            }

            // Process the workout to extract kilometer splits
            self.processWorkoutForSplits(workout: workout, completion: completion)
        }

        healthStore.execute(workoutQuery)
    }

    // Find a workout by date
    private func findWorkoutByDate(date: Date, completion: @escaping FlutterResult) {
        // Create a predicate to find workouts around the given date
        let startDate = date.addingTimeInterval(-60) // 1 minute before
        let endDate = date.addingTimeInterval(60)    // 1 minute after
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Sort by date (closest to the target date first)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        // Create the workout query
        let workoutQuery = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                        predicate: predicate,
                                        limit: 1,
                                        sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "QUERY_ERROR",
                                           message: "Error querying workout: \(error.localizedDescription)",
                                           details: nil))
                }
                return
            }

            guard let workouts = samples as? [HKWorkout], let workout = workouts.first else {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "WORKOUT_NOT_FOUND",
                                           message: "Workout not found",
                                           details: nil))
                }
                return
            }

            // Process the workout to extract kilometer splits
            self.processWorkoutForSplits(workout: workout, completion: completion)
        }

        healthStore.execute(workoutQuery)
    }

    // Process a workout to extract kilometer and mile splits
    private func processWorkoutForSplits(workout: HKWorkout, completion: @escaping FlutterResult) {
        print("Native: Processing workout: \(workout.uuid.uuidString), type: \(workout.workoutActivityType.rawValue)")
        print("Native: Workout start: \(workout.startDate), end: \(workout.endDate)")
        if let distance = workout.totalDistance {
            print("Native: Workout distance: \(distance.doubleValue(for: HKUnit.meter()) / 1000) km")
        }

        // Get the route data for this workout
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        print("Native: Querying route data...")
        let routeQuery = HKAnchoredObjectQuery(type: routeType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
            guard let self = self else { return }

            if let error = error {
                print("Native: Error querying route: \(error.localizedDescription)")
                // Fall back to distance samples if route query fails
                print("Native: Falling back to distance samples...")
                self.calculateSplitsFromDistanceSamples(workout: workout, completion: completion)
                return
            }

            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                print("Native: No route data found, falling back to distance samples")
                // Fall back to distance samples if no route data
                self.calculateSplitsFromDistanceSamples(workout: workout, completion: completion)
                return
            }

            print("Native: Route data found, calculating splits from route...")
            // Process the route to extract kilometer and mile splits
            self.calculateSplitsFromRoute(workout: workout, route: route, completion: completion)
        }

        healthStore.execute(routeQuery)
    }

    // Calculate splits from route data
    private func calculateSplitsFromRoute(workout: HKWorkout, route: HKWorkoutRoute, completion: @escaping FlutterResult) {
        // Create a query to get all location data from the route
        let locationQuery = HKWorkoutRouteQuery(route: route) { [weak self] (query, locations, done, error) in
            guard let self = self else { return }

            if let error = error {
                print("Error querying route locations: \(error.localizedDescription)")
                if done {
                    // Fall back to distance samples if route location query fails
                    self.calculateSplitsFromDistanceSamples(workout: workout, completion: completion)
                }
                return
            }

            guard let locations = locations, !locations.isEmpty else {
                if done {
                    print("No locations found in route, falling back to distance samples")
                    // Fall back to distance samples if no locations
                    self.calculateSplitsFromDistanceSamples(workout: workout, completion: completion)
                }
                return
            }

            // Process locations to calculate splits
            if done {
                // We have all locations, calculate splits
                self.calculateSplitsFromLocations(workout: workout, locations: locations, completion: completion)
            }
        }

        healthStore.execute(locationQuery)
    }

    // Calculate splits from location data
    private func calculateSplitsFromLocations(workout: HKWorkout, locations: [CLLocation], completion: @escaping FlutterResult) {
        // Track cumulative distance and create segments
        var cumulativeDistanceMeters = 0.0
        var kmSplits: [[String: Any]] = []
        var mileSplits: [[String: Any]] = []

        // Use for kilometer and mile detection
        var lastKmMark = 0.0
        var lastMileMark = 0.0
        var lastKmLocation: CLLocation?
        var lastMileLocation: CLLocation?
        var lastKmTime: Date?
        var lastMileTime: Date?

        // Process all locations
        for i in 1..<locations.count {
            let prevLocation = locations[i-1]
            let currentLocation = locations[i]

            // Calculate distance between consecutive points
            let distanceMeters = currentLocation.distance(from: prevLocation)

            // Update cumulative distance
            cumulativeDistanceMeters += distanceMeters

            // Check if we've completed a new kilometer
            let currentKmMark = floor(cumulativeDistanceMeters / 1000)
            if currentKmMark > lastKmMark {
                // We've passed a new kilometer mark
                if let lastKmLocation = lastKmLocation, let lastKmTime = lastKmTime {
                    let kmSegment: [String: Any] = [
                        "index": Int(lastKmMark) + 1, // 1-based index for display
                        "distance": 1.0,
                        "distance_unit": "km",
                        "start_time": iso8601Formatter.string(from: lastKmTime),
                        "end_time": iso8601Formatter.string(from: currentLocation.timestamp),
                        "duration_seconds": currentLocation.timestamp.timeIntervalSince(lastKmTime),
                        "pace": (currentLocation.timestamp.timeIntervalSince(lastKmTime) / 60), // min/km
                        "pace_unit": "min/km"
                    ]

                    kmSplits.append(kmSegment)
                }

                lastKmMark = currentKmMark
                lastKmLocation = currentLocation
                lastKmTime = currentLocation.timestamp
            }

            // Check if we've completed a new mile
            let currentMileMark = floor(cumulativeDistanceMeters / 1609.34)
            if currentMileMark > lastMileMark {
                // We've passed a new mile mark
                if let lastMileLocation = lastMileLocation, let lastMileTime = lastMileTime {
                    let mileSegment: [String: Any] = [
                        "index": Int(lastMileMark) + 1, // 1-based index for display
                        "distance": 1.0,
                        "distance_unit": "mile",
                        "start_time": iso8601Formatter.string(from: lastMileTime),
                        "end_time": iso8601Formatter.string(from: currentLocation.timestamp),
                        "duration_seconds": currentLocation.timestamp.timeIntervalSince(lastMileTime),
                        "pace": (currentLocation.timestamp.timeIntervalSince(lastMileTime) / 60), // min/mile
                        "pace_unit": "min/mile"
                    ]

                    mileSplits.append(mileSegment)
                }

                lastMileMark = currentMileMark
                lastMileLocation = currentLocation
                lastMileTime = currentLocation.timestamp
            }
        }

        // Create the result with both kilometer and mile splits
        var result: [[String: Any]] = []

        // Add kilometer splits if available
        if !kmSplits.isEmpty {
            result = kmSplits
        }

        DispatchQueue.main.async {
            completion(result)
        }
    }

    // Calculate splits from distance samples
    private func calculateSplitsFromDistanceSamples(workout: HKWorkout, completion: @escaping FlutterResult) {
        print("Native: Calculating splits from distance samples...")

        // Get distance samples for the workout
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        print("Native: Querying distance samples from \(workout.startDate) to \(workout.endDate)")
        let query = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                print("Native: Error querying distance samples: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([]) // Return empty array if error
                }
                return
            }

            guard let distanceSamples = samples as? [HKQuantitySample], !distanceSamples.isEmpty else {
                print("Native: No distance samples found")
                DispatchQueue.main.async {
                    completion([]) // Return empty array if no samples
                }
                return
            }

            print("Native: Found \(distanceSamples.count) distance samples")

            // Track cumulative distance and create segments
            var cumulativeDistanceMeters = 0.0
            var kmSplits: [[String: Any]] = []
            var mileSplits: [[String: Any]] = []

            // Use for kilometer and mile detection
            var lastKmMark = 0.0
            var lastMileMark = 0.0
            var lastKmTime: Date?
            var lastMileTime: Date?

            print("Native: Processing \(distanceSamples.count) distance samples")

            // Process all distance samples
            for sample in distanceSamples {
                let distanceMeters = sample.quantity.doubleValue(for: HKUnit.meter())

                // Update cumulative distance
                cumulativeDistanceMeters += distanceMeters

                // Check if we've completed a new kilometer
                let currentKmMark = floor(cumulativeDistanceMeters / 1000)
                if currentKmMark > lastKmMark {
                    // We've passed a new kilometer mark
                    if let lastKmTime = lastKmTime {
                        print("Native: Detected kilometer split at \(currentKmMark) km")

                        let durationSeconds = sample.endDate.timeIntervalSince(lastKmTime)
                        let paceMinPerKm = durationSeconds / 60

                        print("Native: Split duration: \(durationSeconds) seconds, pace: \(paceMinPerKm) min/km")

                        let kmSegment: [String: Any] = [
                            "index": Int(lastKmMark) + 1, // 1-based index for display
                            "distance": 1.0,
                            "distance_unit": "km",
                            "start_time": self.iso8601Formatter.string(from: lastKmTime),
                            "end_time": self.iso8601Formatter.string(from: sample.endDate),
                            "duration_seconds": durationSeconds,
                            "pace": paceMinPerKm, // min/km
                            "pace_unit": "min/km"
                        ]

                        kmSplits.append(kmSegment)
                    }

                    lastKmMark = currentKmMark
                    lastKmTime = sample.endDate
                }

                // Check if we've completed a new mile
                let currentMileMark = floor(cumulativeDistanceMeters / 1609.34)
                if currentMileMark > lastMileMark {
                    // We've passed a new mile mark
                    if let lastMileTime = lastMileTime {
                        let mileSegment: [String: Any] = [
                            "index": Int(lastMileMark) + 1, // 1-based index for display
                            "distance": 1.0,
                            "distance_unit": "mile",
                            "start_time": self.iso8601Formatter.string(from: lastMileTime),
                            "end_time": self.iso8601Formatter.string(from: sample.endDate),
                            "duration_seconds": sample.endDate.timeIntervalSince(lastMileTime),
                            "pace": (sample.endDate.timeIntervalSince(lastMileTime) / 60), // min/mile
                            "pace_unit": "min/mile"
                        ]

                        mileSplits.append(mileSegment)
                    }

                    lastMileMark = currentMileMark
                    lastMileTime = sample.endDate
                }
            }

            // Create the result with both kilometer and mile splits
            var result: [[String: Any]] = []

            // Add kilometer splits if available
            if !kmSplits.isEmpty {
                print("Native: Returning \(kmSplits.count) kilometer splits")
                result = kmSplits
            } else {
                print("Native: No kilometer splits found")
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }

        healthStore.execute(query)
    }

    // Get all workouts with their kilometer splits
    private func getWorkoutsWithSplits(startDate: Date?, endDate: Date?, completion: @escaping FlutterResult) {
        print("Native: getWorkoutsWithSplits called")

        // Create date predicates
        let now = Date()
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let end = endDate ?? now

        print("Native: Fetching workouts from \(start) to \(end)")

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // Sort by date, newest first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        // Create the workout query
        print("Native: Creating workout query")
        let workoutQuery = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                        predicate: predicate,
                                        limit: HKObjectQueryNoLimit,
                                        sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                print("Native: Error querying workouts: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([]) // Return empty array if error
                }
                return
            }

            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                print("Native: No workouts found")
                DispatchQueue.main.async {
                    completion([]) // Return empty array if no workouts
                }
                return
            }

            print("Native: Found \(workouts.count) workouts")

            // Process each workout
            self.processWorkoutsWithSplits(workouts: workouts, completion: completion)
        }

        healthStore.execute(workoutQuery)
    }

    // Process multiple workouts to include their kilometer splits
    private func processWorkoutsWithSplits(workouts: [HKWorkout], completion: @escaping FlutterResult) {
        print("Native: Processing \(workouts.count) workouts with splits")

        // Create a dispatch group to wait for all workouts to be processed
        let group = DispatchGroup()
        var processedWorkouts: [[String: Any]] = []

        for workout in workouts {
            group.enter()

            // Process the workout to extract kilometer splits
            let workoutId = workout.uuid.uuidString
            print("Native: Processing workout: \(workoutId), type: \(workout.workoutActivityType.rawValue)")

            getWorkoutKilometerSplits(workoutId: workoutId) { result in
                print("Native: Got kilometer splits for workout: \(workoutId)")

                var workoutData: [String: Any] = [
                    "id": workout.uuid.uuidString,
                    "workout_type": self.normalizeWorkoutType(workout.workoutActivityType),
                    "original_type": workout.workoutActivityType.rawValue,
                    "start_date": self.iso8601Formatter.string(from: workout.startDate),
                    "end_date": self.iso8601Formatter.string(from: workout.endDate),
                    "duration_seconds": workout.duration,
                    "source": "Apple Health"
                ]

                // Add distance if available
                if let distance = workout.totalDistance {
                    let distanceKm = distance.doubleValue(for: HKUnit.meter()) / 1000
                    print("Native: Workout distance: \(distanceKm) km")
                    workoutData["distance"] = distanceKm // Convert to km
                    workoutData["distance_unit"] = "km"
                }

                // Add energy burned if available
                if let energy = workout.totalEnergyBurned {
                    workoutData["active_energy_burned"] = energy.doubleValue(for: HKUnit.kilocalorie())
                    workoutData["active_energy_burned_unit"] = "kcal"
                }

                // Add heart rate data if available
                self.getHeartRateDataForWorkout(workout: workout) { heartRateData in
                    if !heartRateData.isEmpty {
                        print("Native: Adding heart rate data to workout")
                        workoutData["heart_rate_summary"] = heartRateData
                    }

                    // Add kilometer splits if available
                    if let splits = result as? [[String: Any]], !splits.isEmpty {
                        print("Native: Adding \(splits.count) kilometer splits to workout")
                        workoutData["segment_data"] = ["kilometer_splits": splits]
                    } else {
                        print("Native: No kilometer splits available for workout")
                        // Explicitly set segment_data to null
                        workoutData["segment_data"] = NSNull()
                    }

                    processedWorkouts.append(workoutData)
                    print("Native: Processed workout: \(workoutId)")
                    group.leave()
                }
            }
        }

        // Wait for all workouts to be processed
        group.notify(queue: .main) {
            completion(processedWorkouts)
        }
    }

    // Get heart rate data for a workout
    private func getHeartRateDataForWorkout(workout: HKWorkout, completion: @escaping ([String: Any]) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
            if let error = error {
                print("Error querying heart rate: \(error.localizedDescription)")
                completion([:])
                return
            }

            guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else {
                completion([:])
                return
            }

            // Calculate min, max, and average heart rate
            var sum = 0.0
            var min = Double.greatestFiniteMagnitude
            var max = 0.0

            for sample in heartRateSamples {
                let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                sum += value
                min = value < min ? value : min
                max = value > max ? value : max
            }

            let average = sum / Double(heartRateSamples.count)

            let heartRateData: [String: Any] = [
                "average": average,
                "min": min,
                "max": max,
                "unit": "bpm"
            ]

            completion(heartRateData)
        }

        healthStore.execute(query)
    }

    // Normalize workout type
    private func normalizeWorkoutType(_ type: HKWorkoutActivityType) -> String {
        // Map workout types to normalized strings
        switch type {
        case .running:
            return "RUNNING"
        case .walking:
            return "WALKING"
        case .cycling:
            return "CYCLING"
        case .swimming:
            return "SWIMMING"
        case .hiking:
            return "HIKING"
        case .yoga:
            return "YOGA"
        case .functionalStrengthTraining:
            return "STRENGTH"
        case .traditionalStrengthTraining:
            return "STRENGTH"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .mixedCardio:
            return "CARDIO"
        default:
            // For other types, use a generic format
            let rawValue = type.rawValue
            if rawValue == 37 { // RUNNING_SAND
                return "RUNNING"
            } else if rawValue == 52 { // RUNNING_JOGGING
                return "RUNNING"
            }
            return "WORKOUT_\(rawValue)"
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register our native health service
    let nativeHealthService = NativeHealthService()
    nativeHealthService.register(with: self.registrar(forPlugin: "NativeHealthService")!)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
