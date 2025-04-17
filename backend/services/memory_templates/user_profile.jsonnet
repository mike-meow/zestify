// user_profile.jsonnet - User profile memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with user profile specific fields
  user_profile:: {
    // Core user information
    user_id: $.metadata.user_id,
    name: "",
    email: "",
    created_at: $.metadata.created_at,
    updated_at: $.metadata.last_updated,
    
    // Demographics
    demographics: {
      birth_date: "",
      age: 0,
      gender: "",
      height: 0,
      weight: 0,
      blood_type: "",
    },
    
    // Fitness timeline
    fitness_timeline: [],
    
    // Goals
    goals: {
      active: [],
      completed: [],
      
      // Method to add a new goal
      addGoal(goal):: self + {
        active: self.active + [goal],
      },
      
      // Method to complete a goal
      completeGoal(goal_id, completion_date):: self + {
        active: [g for g in self.active if g.id != goal_id],
        completed: self.completed + [
          g + {status: "completed", completion_date: completion_date}
          for g in self.active if g.id == goal_id
        ],
      },
    },
    
    // Workout preferences
    preferences: {
      workout_locations: [],
      time_availability: {
        preferred_time: "",
        days_per_week: 0,
        minutes_per_session: 0,
        updated_at: "",
      },
      equipment_access: [],
      activity_preferences: {
        preferred: [],
        avoided: [],
      },
    },
    
    // Motivation factors
    motivation_factors: [],
    
    // Additional fields
    dietary_preferences: [],
    sleep_habits: {
      bedtime: "",
      wake_time: "",
      quality: "",
    },
    notes: "",
    
    // References to other memory files
    references: {
      health_metrics_file: "",
      workout_memory_file: "",
      conversation_memory_file: "",
    },
  },
  
  // Factory method to create a new user profile
  newUserProfile(user_id, name, email=""):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    user_profile: $.user_profile + {
      user_id: user_id,
      name: name,
      email: email,
      created_at: std.extVar('timestamp'),
      updated_at: std.extVar('timestamp'),
    },
  },
  
  // Method to update user profile
  updateUserProfile(profile, updates):: {
    metadata: profile.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    user_profile: $.utils.deepMerge(profile.user_profile, updates) + {
      updated_at: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(profile):: {
    user_id: profile.user_profile.user_id,
    name: profile.user_profile.name,
    demographics: profile.user_profile.demographics,
    fitness_level: if std.length(profile.user_profile.fitness_timeline) > 0 
                   then profile.user_profile.fitness_timeline[std.length(profile.user_profile.fitness_timeline)-1].fitness_level 
                   else "unknown",
    active_goals: [
      {
        description: goal.description,
        target_date: goal.target_date,
        progress: goal.progress + "%",
      }
      for goal in profile.user_profile.goals.active
    ],
    preferences: profile.user_profile.preferences,
    motivation_factors: profile.user_profile.motivation_factors,
  },
}
