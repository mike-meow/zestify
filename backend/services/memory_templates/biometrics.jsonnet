// biometrics.jsonnet - Biometrics memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with biometrics specific fields
  biometrics:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Heart rate data
    heart_rate: {
      daily_average: $.measurement_with_history + {
        unit: "bpm",
      },
      resting: $.measurement_with_history + {
        unit: "bpm",
      },
      max: $.measurement_with_history + {
        unit: "bpm",
      },
      variability: $.measurement_with_history + {
        unit: "ms",
      },
      zones: {
        zone1_time: $.measurement_with_history + {
          unit: "minutes",
        },
        zone2_time: $.measurement_with_history + {
          unit: "minutes",
        },
        zone3_time: $.measurement_with_history + {
          unit: "minutes",
        },
        zone4_time: $.measurement_with_history + {
          unit: "minutes",
        },
        zone5_time: $.measurement_with_history + {
          unit: "minutes",
        },
      },
      detailed_readings: [],
    },
    
    // Sleep data
    sleep: {
      total_duration: $.measurement_with_history + {
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
      sleep_score: $.measurement_with_history + {
        unit: "score", // 0-100
      },
      detailed_records: [],
    },
    
    // Activity data
    activity: {
      steps: $.measurement_with_history + {
        unit: "steps",
      },
      distance: $.measurement_with_history + {
        unit: "km",
      },
      floors_climbed: $.measurement_with_history + {
        unit: "floors",
      },
      active_minutes: $.measurement_with_history + {
        unit: "minutes",
      },
      calories_active: $.measurement_with_history + {
        unit: "kcal",
      },
      calories_total: $.measurement_with_history + {
        unit: "kcal",
      },
      detailed_records: [],
    },
    
    // Body composition
    body_composition: {
      weight: $.measurement_with_history + {
        unit: "kg",
      },
      body_fat: $.measurement_with_history + {
        unit: "%",
      },
      muscle_mass: $.measurement_with_history + {
        unit: "kg",
      },
      bone_mass: $.measurement_with_history + {
        unit: "kg",
      },
      water_percentage: $.measurement_with_history + {
        unit: "%",
      },
      bmi: $.measurement_with_history + {
        unit: "kg/m²",
      },
      detailed_records: [],
    },
    
    // Blood pressure
    blood_pressure: {
      systolic: $.measurement_with_history + {
        unit: "mmHg",
      },
      diastolic: $.measurement_with_history + {
        unit: "mmHg",
      },
      detailed_readings: [],
      
      // Method to add a blood pressure reading
      addReading(systolic, diastolic, timestamp, source="device", notes=""):: self + {
        systolic: self.systolic.addHistoryEntry(systolic, timestamp, source, notes),
        diastolic: self.diastolic.addHistoryEntry(diastolic, timestamp, source, notes),
        detailed_readings: self.detailed_readings + [{
          systolic: systolic,
          diastolic: diastolic,
          timestamp: timestamp,
          source: source,
          notes: notes,
        }],
      },
    },
    
    // Blood glucose
    blood_glucose: {
      fasting: $.measurement_with_history + {
        unit: "mg/dL",
      },
      post_meal: $.measurement_with_history + {
        unit: "mg/dL",
      },
      detailed_readings: [],
    },
    
    // Oxygen saturation
    oxygen_saturation: {
      average: $.measurement_with_history + {
        unit: "%",
      },
      detailed_readings: [],
    },
    
    // Stress level
    stress: {
      average: $.measurement_with_history + {
        unit: "score", // 0-100
      },
      detailed_readings: [],
    },
    
    // Method to add a heart rate reading
    addHeartRateReading(value, timestamp, type="resting", source="device", notes=""):: self + {
      heart_rate: self.heart_rate + {
        [type]: self.heart_rate[type].addHistoryEntry(value, timestamp, source, notes),
        detailed_readings: self.heart_rate.detailed_readings + [{
          value: value,
          type: type,
          timestamp: timestamp,
          source: source,
          notes: notes,
        }],
      },
    },
    
    // Method to add a sleep record
    addSleepRecord(record):: self + {
      sleep: self.sleep + {
        total_duration: self.sleep.total_duration.addHistoryEntry(
          record.total_duration, 
          record.end_time, 
          record.source, 
          record.notes
        ),
        deep_sleep: self.sleep.deep_sleep.addHistoryEntry(
          record.deep_sleep, 
          record.end_time, 
          record.source, 
          record.notes
        ),
        rem_sleep: self.sleep.rem_sleep.addHistoryEntry(
          record.rem_sleep, 
          record.end_time, 
          record.source, 
          record.notes
        ),
        light_sleep: self.sleep.light_sleep.addHistoryEntry(
          record.light_sleep, 
          record.end_time, 
          record.source, 
          record.notes
        ),
        sleep_score: self.sleep.sleep_score.addHistoryEntry(
          record.sleep_score, 
          record.end_time, 
          record.source, 
          record.notes
        ),
        detailed_records: self.sleep.detailed_records + [record],
      },
    },
  },
  
  // Sleep record structure
  sleep_record:: {
    start_time: "",
    end_time: "",
    total_duration: 0.0,
    deep_sleep: 0.0,
    rem_sleep: 0.0,
    light_sleep: 0.0,
    awake_time: 0.0,
    sleep_score: 0,
    source: "device",
    notes: "",
  },
  
  // Factory method to create new biometrics
  newBiometrics(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    biometrics: $.biometrics + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Method to update biometrics
  updateBiometrics(bio, updates):: {
    metadata: bio.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    biometrics: $.utils.deepMerge(bio.biometrics, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(bio):: {
    user_id: bio.biometrics.user_id,
    last_updated: bio.biometrics.last_updated,
    
    heart_rate: {
      resting: bio.biometrics.heart_rate.resting.current + " " + 
               bio.biometrics.heart_rate.resting.unit,
      daily_average: bio.biometrics.heart_rate.daily_average.current + " " + 
                     bio.biometrics.heart_rate.daily_average.unit,
      variability: bio.biometrics.heart_rate.variability.current + " " + 
                   bio.biometrics.heart_rate.variability.unit,
    },
    
    sleep: {
      average_duration: bio.biometrics.sleep.total_duration.current + " " + 
                        bio.biometrics.sleep.total_duration.unit,
      deep_sleep: bio.biometrics.sleep.deep_sleep.current + " " + 
                  bio.biometrics.sleep.deep_sleep.unit,
      rem_sleep: bio.biometrics.sleep.rem_sleep.current + " " + 
                 bio.biometrics.sleep.rem_sleep.unit,
      sleep_score: bio.biometrics.sleep.sleep_score.current + "/100",
    },
    
    activity: {
      daily_steps: bio.biometrics.activity.steps.current + " " + 
                   bio.biometrics.activity.steps.unit,
      active_minutes: bio.biometrics.activity.active_minutes.current + " " + 
                      bio.biometrics.activity.active_minutes.unit,
      calories_burned: bio.biometrics.activity.calories_total.current + " " + 
                       bio.biometrics.activity.calories_total.unit,
    },
    
    body_composition: {
      weight: bio.biometrics.body_composition.weight.current + " " + 
              bio.biometrics.body_composition.weight.unit,
      body_fat: bio.biometrics.body_composition.body_fat.current + " " + 
                bio.biometrics.body_composition.body_fat.unit,
      bmi: bio.biometrics.body_composition.bmi.current + " " + 
           bio.biometrics.body_composition.bmi.unit,
    },
    
    blood_pressure: {
      systolic: bio.biometrics.blood_pressure.systolic.current + " " + 
                bio.biometrics.blood_pressure.systolic.unit,
      diastolic: bio.biometrics.blood_pressure.diastolic.current + " " + 
                 bio.biometrics.blood_pressure.diastolic.unit,
    },
    
    stress_level: bio.biometrics.stress.average.current + "/100",
  },
}
