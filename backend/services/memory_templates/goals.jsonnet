// goals.jsonnet - Goals memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with goals specific fields
  goals:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Active goals
    active_goals: [],
    
    // Completed goals
    completed_goals: [],
    
    // Abandoned goals
    abandoned_goals: [],
    
    // Goal categories
    categories: [
      "fitness",
      "nutrition",
      "weight_management",
      "sleep",
      "stress_management",
      "medical",
      "lifestyle",
      "mental_health",
    ],
    
    // Method to add a goal
    addGoal(goal):: self + {
      active_goals: self.active_goals + [goal],
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to complete a goal
    completeGoal(goal_id, completion_date, notes=""):: self + {
      active_goals: [g for g in self.active_goals if g.id != goal_id],
      completed_goals: self.completed_goals + [
        g + {
          status: "completed",
          completion_date: completion_date,
          completion_notes: notes,
        }
        for g in self.active_goals if g.id == goal_id
      ],
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to abandon a goal
    abandonGoal(goal_id, reason):: self + {
      active_goals: [g for g in self.active_goals if g.id != goal_id],
      abandoned_goals: self.abandoned_goals + [
        g + {
          status: "abandoned",
          abandonment_date: std.extVar('timestamp'),
          abandonment_reason: reason,
        }
        for g in self.active_goals if g.id == goal_id
      ],
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to update goal progress
    updateGoalProgress(goal_id, progress, notes=""):: self + {
      active_goals: [
        if g.id == goal_id then
          g + {
            progress: progress,
            last_updated: std.extVar('timestamp'),
            progress_history: g.progress_history + [{
              date: std.extVar('timestamp'),
              progress: progress,
              notes: notes,
            }],
          }
        else g
        for g in self.active_goals
      ],
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Goal structure
  goal:: {
    id: "",
    category: "",
    title: "",
    description: "",
    created_at: "",
    target_date: "",
    progress: 0, // 0-100 percentage
    status: "active", // active, completed, abandoned
    priority: "medium", // low, medium, high
    difficulty: "medium", // easy, medium, hard
    metrics: [],
    milestones: [],
    related_goals: [],
    progress_history: [],
    notes: "",
    
    // Method to add a milestone
    addMilestone(milestone):: self + {
      milestones: self.milestones + [milestone],
    },
    
    // Method to complete a milestone
    completeMilestone(milestone_id):: self + {
      milestones: [
        if m.id == milestone_id then
          m + {
            completed: true,
            completion_date: std.extVar('timestamp'),
          }
        else m
        for m in self.milestones
      ],
    },
  },
  
  // Milestone structure
  milestone:: {
    id: "",
    description: "",
    target_date: "",
    completed: false,
    completion_date: "",
    notes: "",
  },
  
  // Metric structure
  metric:: {
    name: "",
    current_value: 0,
    target_value: 0,
    unit: "",
    history: [],
    
    // Method to update metric value
    updateValue(value, timestamp, notes=""):: self + {
      current_value: value,
      history: self.history + [{
        value: value,
        timestamp: timestamp,
        notes: notes,
      }],
    },
  },
  
  // Factory method to create new goals memory
  newGoalsMemory(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    goals: $.goals + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Factory method to create a new goal
  newGoal(category, title, description, target_date):: $.goal + {
    id: $.utils.generateId("goal"),
    category: category,
    title: title,
    description: description,
    created_at: std.extVar('timestamp'),
    target_date: target_date,
  },
  
  // Factory method to create a new milestone
  newMilestone(description, target_date):: $.milestone + {
    id: $.utils.generateId("milestone"),
    description: description,
    target_date: target_date,
  },
  
  // Factory method to create a new metric
  newMetric(name, current_value, target_value, unit):: $.metric + {
    name: name,
    current_value: current_value,
    target_value: target_value,
    unit: unit,
    history: [{
      value: current_value,
      timestamp: std.extVar('timestamp'),
      notes: "Initial value",
    }],
  },
  
  // Method to update goals memory
  updateGoalsMemory(memory, updates):: {
    metadata: memory.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    goals: $.utils.deepMerge(memory.goals, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(memory):: {
    user_id: memory.goals.user_id,
    last_updated: memory.goals.last_updated,
    
    active_goals: [
      {
        category: goal.category,
        title: goal.title,
        description: goal.description,
        target_date: goal.target_date,
        progress: std.toString(goal.progress) + "%",
        priority: goal.priority,
        milestones: [
          {
            description: milestone.description,
            target_date: milestone.target_date,
            completed: milestone.completed,
          }
          for milestone in goal.milestones
        ],
        metrics: [
          {
            name: metric.name,
            current: std.toString(metric.current_value) + " " + metric.unit,
            target: std.toString(metric.target_value) + " " + metric.unit,
          }
          for metric in goal.metrics
        ],
      }
      for goal in memory.goals.active_goals
    ],
    
    recently_completed_goals: [
      {
        category: goal.category,
        title: goal.title,
        completion_date: goal.completion_date,
      }
      for goal in memory.goals.completed_goals
    ][0:3],  // Only include the 3 most recently completed goals
  },
}
