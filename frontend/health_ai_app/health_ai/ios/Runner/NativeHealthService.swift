import Flutter
import UIKit
import HealthKit

/// Native implementation of HealthKit access for more accurate data
/// Provides direct access to workout segments and kilometer splits
class NativeHealthService {
    private let healthStore = HKHealthStore()
    private var channel: FlutterMethodChannel?
    
    /// Register the method channel with Flutter
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
                        startDate = ISO8601DateFormatter().date(from: startDateString)
                    }
                    
                    if let endDateString = endDateString {
                        endDate = ISO8601DateFormatter().date(from: endDateString)
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
    
    /// Initialize the health store and request permissions
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
                    completion(true)
                } else {
                    print("HealthKit authorization failed: \(String(describing: error))")
                    completion(false)
                }
            }
        }
    }
    
    /// Get kilometer splits for a specific workout
    private func getWorkoutKilometerSplits(workoutId: String, completion: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: workoutId) else {
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
            self.processWorkoutForKilometerSplits(workout: workout, completion: completion)
        }
        
        healthStore.execute(workoutQuery)
    }
    
    /// Process a workout to extract kilometer splits
    private func processWorkoutForKilometerSplits(workout: HKWorkout, completion: @escaping FlutterResult) {
        // Check if the workout has events (segments)
        if let events = workout.workoutEvents, !events.isEmpty {
            // Process events directly if available
            processWorkoutEvents(workout: workout, events: events, completion: completion)
            return
        }
        
        // If no events, try to get route data to calculate splits
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKAnchoredObjectQuery(type: routeType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "ROUTE_QUERY_ERROR", 
                                           message: "Error querying route: \(error.localizedDescription)", 
                                           details: nil))
                }
                return
            }
            
            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                // If no route data, fall back to calculating from distance samples
                self.calculateKilometerSplitsFromDistanceSamples(workout: workout, completion: completion)
                return
            }
            
            // Process the route to extract kilometer splits
            self.processRouteForKilometerSplits(workout: workout, route: route, completion: completion)
        }
        
        healthStore.execute(routeQuery)
    }
    
    /// Process workout events to extract kilometer splits
    private func processWorkoutEvents(workout: HKWorkout, events: [HKWorkoutEvent], completion: @escaping FlutterResult) {
        // Filter for segment events
        let segmentEvents = events.filter { $0.type == .segment }
        
        if segmentEvents.isEmpty {
            // If no segment events, try to calculate from distance samples
            calculateKilometerSplitsFromDistanceSamples(workout: workout, completion: completion)
            return
        }
        
        // Process the segments into kilometer splits
        var kmSplits: [[String: Any]] = []
        
        for (index, event) in segmentEvents.enumerated() {
            // Calculate segment duration
            let segmentDuration = event.dateInterval.duration
            
            // Create a split entry
            var split: [String: Any] = [
                "index": index + 1,
                "start_time": ISO8601DateFormatter().string(from: event.dateInterval.start),
                "end_time": ISO8601DateFormatter().string(from: event.dateInterval.end),
                "duration_seconds": segmentDuration,
            ]
            
            // If we have metadata, add it
            if let metadata = event.metadata {
                if let distance = metadata["HKDistanceKey"] as? Double {
                    split["distance"] = distance
                    split["distance_unit"] = "meters"
                    
                    // Calculate pace (min/km)
                    if distance > 0 {
                        let paceMinutesPerKm = (segmentDuration / 60) / (distance / 1000)
                        split["pace"] = paceMinutesPerKm
                        split["pace_unit"] = "min/km"
                    }
                }
            } else {
                // Assume 1km segments if no metadata
                split["distance"] = 1000.0
                split["distance_unit"] = "meters"
                
                // Calculate pace (min/km)
                let paceMinutesPerKm = segmentDuration / 60
                split["pace"] = paceMinutesPerKm
                split["pace_unit"] = "min/km"
            }
            
            kmSplits.append(split)
        }
        
        DispatchQueue.main.async {
            completion(kmSplits)
        }
    }
    
    /// Process route data to extract kilometer splits
    private func processRouteForKilometerSplits(workout: HKWorkout, route: HKWorkoutRoute, completion: @escaping FlutterResult) {
        // This would involve processing location data to calculate kilometer splits
        // For now, fall back to distance samples as this requires more complex implementation
        calculateKilometerSplitsFromDistanceSamples(workout: workout, completion: completion)
    }
    
    /// Calculate kilometer splits from distance samples
    private func calculateKilometerSplitsFromDistanceSamples(workout: HKWorkout, completion: @escaping FlutterResult) {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { (query, samples, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "DISTANCE_QUERY_ERROR", 
                                           message: "Error querying distance: \(error.localizedDescription)", 
                                           details: nil))
                }
                return
            }
            
            guard let distanceSamples = samples as? [HKQuantitySample], !distanceSamples.isEmpty else {
                DispatchQueue.main.async {
                    completion([]) // No distance samples available
                }
                return
            }
            
            // Track cumulative distance and create segments
            var cumulativeDistance = 0.0
            var kmSplits: [[String: Any]] = []
            
            // Use for kilometer detection
            var lastKmMark = 0.0
            var lastKmTime: Date?
            
            // Process all distance samples
            for sample in distanceSamples {
                let distanceValue = sample.quantity.doubleValue(for: HKUnit.meter())
                if distanceValue <= 0 { continue }
                
                // Update cumulative distance
                cumulativeDistance += distanceValue
                
                // Check if we've completed a new kilometer
                let currentKmMark = floor(cumulativeDistance / 1000)
                if currentKmMark > lastKmMark {
                    // We've passed a new kilometer mark
                    if let lastKmTime = lastKmTime {
                        let kmSegment: [String: Any] = [
                            "index": Int(lastKmMark) + 1, // 1-based index for display
                            "distance": 1000.0,
                            "distance_unit": "meters",
                            "start_time": ISO8601DateFormatter().string(from: lastKmTime),
                            "end_time": ISO8601DateFormatter().string(from: sample.endDate),
                            "duration_seconds": sample.endDate.timeIntervalSince(lastKmTime),
                            "pace": (sample.endDate.timeIntervalSince(lastKmTime) / 60), // min/km
                            "pace_unit": "min/km"
                        ]
                        
                        kmSplits.append(kmSegment)
                    }
                    
                    lastKmMark = currentKmMark
                    lastKmTime = sample.endDate
                }
            }
            
            DispatchQueue.main.async {
                completion(kmSplits)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Get all workouts with their kilometer splits
    private func getWorkoutsWithSplits(startDate: Date?, endDate: Date?, completion: @escaping FlutterResult) {
        // Create date predicates
        let now = Date()
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let end = endDate ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        // Sort by date, newest first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Create the workout query
        let workoutQuery = HKSampleQuery(sampleType: HKObjectType.workoutType(), 
                                        predicate: predicate, 
                                        limit: HKObjectQueryNoLimit, 
                                        sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(FlutterError(code: "QUERY_ERROR", 
                                           message: "Error querying workouts: \(error.localizedDescription)", 
                                           details: nil))
                }
                return
            }
            
            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                DispatchQueue.main.async {
                    completion([]) // No workouts found
                }
                return
            }
            
            // Process each workout
            self.processWorkoutsWithSplits(workouts: workouts, completion: completion)
        }
        
        healthStore.execute(workoutQuery)
    }
    
    /// Process multiple workouts to include their kilometer splits
    private func processWorkoutsWithSplits(workouts: [HKWorkout], completion: @escaping FlutterResult) {
        // Create a dispatch group to wait for all workouts to be processed
        let group = DispatchGroup()
        var processedWorkouts: [[String: Any]] = []
        
        for workout in workouts {
            group.enter()
            
            // Process the workout to extract kilometer splits
            processWorkoutForKilometerSplits(workout: workout) { result in
                var workoutData: [String: Any] = [
                    "id": workout.uuid.uuidString,
                    "workout_type": self.mapWorkoutType(workout.workoutActivityType),
                    "original_type": workout.workoutActivityType.rawValue,
                    "start_date": ISO8601DateFormatter().string(from: workout.startDate),
                    "end_date": ISO8601DateFormatter().string(from: workout.endDate),
                    "duration_seconds": workout.duration,
                    "source": "Apple Health"
                ]
                
                // Add distance if available
                if let distance = workout.totalDistance {
                    workoutData["distance"] = distance.doubleValue(for: HKUnit.meter()) / 1000 // Convert to km
                    workoutData["distance_unit"] = "km"
                }
                
                // Add energy burned if available
                if let energy = workout.totalEnergyBurned {
                    workoutData["active_energy_burned"] = energy.doubleValue(for: HKUnit.kilocalorie())
                    workoutData["active_energy_burned_unit"] = "kcal"
                }
                
                // Add kilometer splits if available
                if let splits = result as? [[String: Any]], !splits.isEmpty {
                    workoutData["segment_data"] = ["kilometer_splits": splits]
                }
                
                processedWorkouts.append(workoutData)
                group.leave()
            }
        }
        
        // Wait for all workouts to be processed
        group.notify(queue: .main) {
            completion(processedWorkouts)
        }
    }
    
    /// Map HKWorkoutActivityType to string representation
    private func mapWorkoutType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "RUNNING"
        case .walking:
            return "WALKING"
        case .cycling:
            return "CYCLING"
        case .swimming:
            return "SWIMMING"
        default:
            // For other types, use the raw value
            return "WORKOUT_\(type.rawValue)"
        }
    }
}
