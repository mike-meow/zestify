// sleep.jsonnet - Sleep memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with sleep specific fields
  sleep:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Sleep history - collection of sleep sessions
    sessions: [],
    
    // Sleep metrics
    metrics: {
      total_sleep_duration: $.measurement_with_history + {
        unit: "hours",
      },
      deep_sleep: $.measurement_with_history + {
        unit: "hours",
      },
      rem_sleep: $.measurement_with_history + {
        unit: "hours",
      },
      light_sleep: $.measurement_with_history + {
        unit: "hours",
      },
      awake_time: $.measurement_with_history + {
        unit: "minutes",
      },
      sleep_efficiency: $.measurement_with_history + {
        unit: "percent",
      },
      sleep_score: $.measurement_with_history + {
        unit: "score", // 0-100
      },
    },
    
    // Sleep statistics
    statistics: {
      weekly_average: {
        total_sleep: 0.0,
        deep_sleep: 0.0,
        rem_sleep: 0.0,
        light_sleep: 0.0,
        sleep_efficiency: 0.0,
      },
      monthly_average: {
        total_sleep: 0.0,
        deep_sleep: 0.0,
        rem_sleep: 0.0,
        light_sleep: 0.0,
        sleep_efficiency: 0.0,
      },
    },
    
    // Sleep patterns
    patterns: {
      bedtime: {
        earliest: "",
        latest: "",
        typical: "",
      },
      wake_time: {
        earliest: "",
        latest: "",
        typical: "",
      },
      interrupted_sleep: {
        frequency: "low", // low, medium, high
        typical_duration: 0.0, // minutes
      },
    },
    
    // Method to add a sleep session
    addSleepSession(session):: self + {
      sessions: self.sessions + [session],
      
      // Update sleep metrics based on the new session
      metrics: self.metrics + {
        total_sleep_duration: self.metrics.total_sleep_duration.addHistoryEntry(
          session.duration_minutes / 60.0, // convert to hours
          session.end_date,
          session.source,
          ""
        ),
        // Update other metrics based on sleep stages
        light_sleep: self.metrics.light_sleep.addHistoryEntry(
          session.asleep_minutes / 60.0, // convert to hours
          session.end_date,
          session.source,
          ""
        ),
        awake_time: self.metrics.awake_time.addHistoryEntry(
          session.awake_minutes,
          session.end_date,
          session.source,
          ""
        ),
        sleep_efficiency: self.metrics.sleep_efficiency.addHistoryEntry(
          session.sleep_efficiency,
          session.end_date,
          session.source,
          ""
        ),
      },
    },
  },
  
  // Sleep session structure
  sleep_session:: {
    id: "",
    start_date: "",
    end_date: "",
    duration_minutes: 0.0,
    duration_seconds: 0.0,
    asleep_minutes: 0.0,
    awake_minutes: 0.0,
    in_bed_minutes: 0.0,
    sleep_efficiency: 0.0,
    source: "Apple Health",
    sleep_stages: [],
    heart_rate_average: null,
    heart_rate_min: null,
    heart_rate_max: null,
    respiratory_rate_average: null,
    notes: "",
  },
  
  // Sleep stage structure
  sleep_stage:: {
    stage_type: "", // AWAKE, LIGHT, DEEP, REM, IN_BED, UNSPECIFIED
    start_date: "",
    end_date: "",
    duration_minutes: 0.0,
  },
  
  // Factory method to create new sleep data
  newSleep(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    sleep: $.sleep + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Method to update sleep data
  updateSleep(sleepData, updates):: {
    metadata: sleepData.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    sleep: $.utils.deepMerge(sleepData.sleep, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(sleepData):: {
    user_id: sleepData.sleep.user_id,
    last_updated: sleepData.sleep.last_updated,
    
    sleep_metrics: {
      average_sleep_duration: sleepData.sleep.metrics.total_sleep_duration.current + " " + 
                              sleepData.sleep.metrics.total_sleep_duration.unit,
      light_sleep: sleepData.sleep.metrics.light_sleep.current + " " + 
                   sleepData.sleep.metrics.light_sleep.unit,
      sleep_efficiency: sleepData.sleep.metrics.sleep_efficiency.current + "%",
    },
    
    sleep_patterns: {
      typical_bedtime: sleepData.sleep.patterns.bedtime.typical,
      typical_wake_time: sleepData.sleep.patterns.wake_time.typical,
      interrupted_sleep_frequency: sleepData.sleep.patterns.interrupted_sleep.frequency,
    },
    
    recent_sleep: [
      {
        date: session.end_date.split('T')[0],
        duration: session.duration_minutes / 60.0,
        quality: if session.sleep_efficiency > 85 then "good"
                 else if session.sleep_efficiency > 70 then "fair"
                 else "poor",
      }
      for session in std.slice(sleepData.sleep.sessions, 0, std.min(5, std.length(sleepData.sleep.sessions)))
    ],
  },
} 