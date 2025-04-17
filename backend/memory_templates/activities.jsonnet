// activities.jsonnet - Activities memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with activities specific fields
  activity:: {
    // Basic activity data
    date: "",
    steps: 0,
    distance: 0.0,
    distance_unit: "km",
    floors_climbed: 0,
    active_energy_burned: 0.0,
    active_energy_burned_unit: "kcal",
    exercise_minutes: 0,
    move_minutes: 0,
    source: "Apple Health",
  },
  
  // Factory method to create a new activity
  newActivity(date, steps, distance):: $.activity + {
    date: date,
    steps: steps,
    distance: distance,
  },
  
  // Method to update an activity
  updateActivity(activity, updates):: $.utils.deepMerge(activity, updates),
  
  // Convert to YAML-friendly format for LLM
  toYaml(activities):: [
    {
      date: activity.date,
      steps: std.toString(activity.steps),
      distance: std.toString(activity.distance) + " " + activity.distance_unit,
      energy: std.toString(activity.active_energy_burned) + " " + activity.active_energy_burned_unit,
      exercise_time: std.toString(activity.exercise_minutes) + " minutes",
    }
    for activity in activities
  ],
}
