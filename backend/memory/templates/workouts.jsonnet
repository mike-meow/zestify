// workouts.jsonnet - Workouts memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with workout specific fields
  workout:: {
    // Basic workout data
    id: "",
    workout_type: "",
    start_date: "",
    end_date: "",
    duration_seconds: 0.0,
    active_energy_burned: 0.0,
    active_energy_burned_unit: "kcal",
    distance: 0.0,
    distance_unit: "km",
    heart_rate_summary: {
      average: 0.0,
      min: 0.0,
      max: 0.0,
      unit: "bpm",
    },
    source: "Apple Health",
  },
  
  // Factory method to create a new workout
  newWorkout(id, type, start_date, end_date):: $.workout + {
    id: id,
    workout_type: type,
    start_date: start_date,
    end_date: end_date,
  },
  
  // Method to update a workout
  updateWorkout(workout, updates):: $.utils.deepMerge(workout, updates),
  
  // Convert to YAML-friendly format for LLM
  toYaml(workouts):: [
    {
      type: workout.workout_type,
      date: std.split(workout.start_date, "T")[0],
      time: std.split(workout.start_date, "T")[1],
      duration: std.toString(std.floor(workout.duration_seconds / 60)) + " minutes",
      distance: std.toString(workout.distance) + " " + workout.distance_unit,
      calories: std.toString(workout.active_energy_burned) + " " + workout.active_energy_burned_unit,
      heart_rate: {
        average: std.toString(workout.heart_rate_summary.average) + " " + workout.heart_rate_summary.unit,
        min: std.toString(workout.heart_rate_summary.min) + " " + workout.heart_rate_summary.unit,
        max: std.toString(workout.heart_rate_summary.max) + " " + workout.heart_rate_summary.unit,
      },
    }
    for workout in workouts
  ],
}
