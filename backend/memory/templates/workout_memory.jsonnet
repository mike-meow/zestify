// workout_memory.jsonnet - Workout memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with workout memory specific fields
  workout_memory:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Recent workouts
    recent_workouts: [],
    
    // Workout goals
    workout_goals: {
      current_goals: [],
      completed_goals: [],
      
      // Method to add a workout goal
      addGoal(goal):: self + {
        current_goals: self.current_goals + [goal],
      },
      
      // Method to complete a workout goal
      completeGoal(goal_description, completed_date):: self + {
        current_goals: [
          g for g in self.current_goals 
          if g.goal != goal_description
        ],
        completed_goals: self.completed_goals + [
          g + {completed_date: completed_date}
          for g in self.current_goals 
          if g.goal == goal_description
        ],
      },
      
      // Method to update goal progress
      updateGoalProgress(goal_description, progress):: self + {
        current_goals: [
          if g.goal == goal_description then
            g + {progress: progress}
          else g
          for g in self.current_goals
        ],
      },
    },
    
    // Workout recommendations
    workout_recommendations: {
      suggested_workouts: [],
      training_adjustments: [],
      recovery_suggestions: [],
    },
    
    // Method to add a workout
    addWorkout(workout):: self + {
      recent_workouts: [workout] + self.recent_workouts,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Workout structure
  workout:: {
    id: "",
    date: "",
    type: "",
    start_time: "",
    end_time: "",
    duration_seconds: 0,
    distance_meters: 0.0,
    calories_burned: 0.0,
    average_heart_rate: 0,
    max_heart_rate: 0,
    average_pace: "",
    route_available: false,
    user_feedback: {
      rating: 0,
      perceived_effort: 0,
      notes: "",
      mood_after: "",
    },
    weather_conditions: {
      temperature: 0,
      conditions: "",
      humidity: 0,
    },
    post_workout_metrics: {
      recovery_heart_rate: 0,
      fatigue_level: 0,
    },
    
    // Method to calculate duration from start and end times
    calculateDuration():: self + {
      // This would require a date/time library in a real implementation
      // For now, we'll just leave it as a placeholder
      duration_seconds: 0,
    },
  },
  
  // Factory method to create new workout memory
  newWorkoutMemory(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    workout_memory: $.workout_memory + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Factory method to create a new workout
  newWorkout(type, start_time, end_time):: $.workout + {
    id: $.utils.generateId("workout"),
    date: std.split(start_time, "T")[0],
    type: type,
    start_time: start_time,
    end_time: end_time,
  },
  
  // Method to update workout memory
  updateWorkoutMemory(memory, updates):: {
    metadata: memory.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    workout_memory: $.utils.deepMerge(memory.workout_memory, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(memory):: {
    user_id: memory.workout_memory.user_id,
    last_updated: memory.workout_memory.last_updated,
    
    recent_workouts: [
      {
        date: workout.date,
        type: workout.type,
        duration: std.toString(std.floor(workout.duration_seconds / 60)) + " minutes",
        distance: std.toString(workout.distance_meters / 1000) + " km",
        calories: std.toString(workout.calories_burned),
        heart_rate: {
          average: std.toString(workout.average_heart_rate),
          max: std.toString(workout.max_heart_rate),
        },
        user_feedback: workout.user_feedback,
      }
      for workout in memory.workout_memory.recent_workouts
    ][0:5],  // Only include the 5 most recent workouts
    
    workout_patterns: memory.workout_memory.workout_patterns,
    
    current_goals: [
      {
        goal: goal.goal,
        progress: std.toString(goal.progress) + "%",
        next_milestone: goal.next_milestone,
      }
      for goal in memory.workout_memory.workout_goals.current_goals
    ],
    
    recommendations: {
      suggested_workouts: [
        workout.type + ": " + workout.details
        for workout in memory.workout_memory.workout_recommendations.suggested_workouts
      ],
      training_adjustments: memory.workout_memory.workout_recommendations.training_adjustments,
      recovery_suggestions: memory.workout_memory.workout_recommendations.recovery_suggestions,
    },
  },
}
