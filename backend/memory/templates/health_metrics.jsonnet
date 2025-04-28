// health_metrics.jsonnet - Health metrics memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with health metrics specific fields
  health_metrics:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Anthropometric measurements
    measurements: {
      height: $.measurement_with_history + {
        unit: "cm",
      },
      
      weight: $.measurement_with_history + {
        unit: "kg",
        goal: null,
      },
      
      body_composition: {
        body_fat_percentage: $.measurement_with_history + {
          unit: "%",
        },
        muscle_mass: $.measurement_with_history + {
          unit: "kg",
        },
        bmi: $.measurement_with_history + {
          unit: "kg/m²",
        },
      },
    },
    
    // Vital signs
    vitals: {
      resting_heart_rate: $.measurement_with_history + {
        unit: "bpm",
      },
      
      blood_pressure: {
        current: {
          systolic: 0,
          diastolic: 0,
        },
        history: [],
        
        // Method to add a blood pressure reading
        addReading(systolic, diastolic, timestamp, source="user", notes=""):: self + {
          current: {
            systolic: systolic,
            diastolic: diastolic,
          },
          history: self.history + [{
            value: {
              systolic: systolic,
              diastolic: diastolic,
            },
            timestamp: timestamp,
            source: source,
            notes: notes,
          }],
        },
      },
      
      respiratory_rate: $.measurement_with_history + {
        unit: "breaths/min",
      },
      
      body_temperature: $.measurement_with_history + {
        unit: "°C",
      },
    },
    
    // Health conditions
    conditions: {
      chronic: [],
      injuries: [],
      allergies: [],
      
      // Method to add a condition
      addCondition(condition_type, condition):: self + {
        [condition_type]: self[condition_type] + [condition],
      },
    },
    
    // Fitness assessments
    fitness_assessments: {
      cardio: {
        vo2_max: $.measurement_with_history + {
          unit: "ml/kg/min",
        },
        resting_metabolic_rate: $.measurement_with_history + {
          unit: "kcal/day",
        },
      },
      
      strength: [],
      flexibility: [],
      
      // Method to add a strength assessment
      addStrengthAssessment(exercise, value, unit, timestamp, source="user", notes=""):: self + {
        strength: [
          if s.exercise == exercise then
            s + {
              one_rep_max: s.one_rep_max + {
                current: value,
                unit: unit,
                history: s.one_rep_max.history + [{
                  value: value,
                  timestamp: timestamp,
                  source: source,
                  notes: notes,
                }],
              },
            }
          else s
          for s in self.strength
        ] + (
          if std.length([s for s in self.strength if s.exercise == exercise]) == 0 then
            [{
              exercise: exercise,
              one_rep_max: {
                current: value,
                unit: unit,
                history: [{
                  value: value,
                  timestamp: timestamp,
                  source: source,
                  notes: notes,
                }],
              },
            }]
          else []
        ),
      },
    },
    
    // Nutrition and sleep
    nutrition: {
      dietary_restrictions: [],
      supplements: [],
      daily_calories: $.measurement_with_history + {
        unit: "kcal",
      },
      macronutrients: {
        protein: $.measurement_with_history + {
          unit: "g",
        },
        carbohydrates: $.measurement_with_history + {
          unit: "g",
        },
        fat: $.measurement_with_history + {
          unit: "g",
        },
      },
    },
    
    sleep: {
      average_duration: $.measurement_with_history + {
        unit: "hours",
      },
      quality_rating: $.measurement_with_history + {
        unit: "rating", // poor, fair, good, excellent
      },
      history: [],
      
      // Method to add a sleep record
      addSleepRecord(duration, quality, start_time, end_time, notes=""):: self + {
        average_duration: self.average_duration + {
          current: duration,
          history: self.average_duration.history + [{
            value: duration,
            timestamp: end_time,
            notes: notes,
          }],
        },
        quality_rating: self.quality_rating + {
          current: quality,
          history: self.quality_rating.history + [{
            value: quality,
            timestamp: end_time,
            notes: notes,
          }],
        },
        history: self.history + [{
          start_time: start_time,
          end_time: end_time,
          duration: duration,
          quality: quality,
          notes: notes,
        }],
      },
    },
    
    // Medical notes and documents
    medical_notes: [],
    documents: [],
  },
  
  // Factory method to create new health metrics
  newHealthMetrics(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    health_metrics: $.health_metrics + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Method to update health metrics
  updateHealthMetrics(metrics, updates):: {
    metadata: metrics.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    health_metrics: $.utils.deepMerge(metrics.health_metrics, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(metrics):: {
    user_id: metrics.health_metrics.user_id,
    last_updated: metrics.health_metrics.last_updated,
    
    // Include only the most relevant information for LLM
    current_measurements: {
      height: metrics.health_metrics.measurements.height.current + " " + 
              metrics.health_metrics.measurements.height.unit,
      weight: metrics.health_metrics.measurements.weight.current + " " + 
              metrics.health_metrics.measurements.weight.unit,
      body_fat: metrics.health_metrics.measurements.body_composition.body_fat_percentage.current + " " + 
                metrics.health_metrics.measurements.body_composition.body_fat_percentage.unit,
    },
    
    current_vitals: {
      resting_heart_rate: metrics.health_metrics.vitals.resting_heart_rate.current + " " + 
                          metrics.health_metrics.vitals.resting_heart_rate.unit,
      blood_pressure: metrics.health_metrics.vitals.blood_pressure.current.systolic + "/" + 
                      metrics.health_metrics.vitals.blood_pressure.current.diastolic + " mmHg",
    },
    
    health_conditions: {
      chronic: [condition.condition for condition in metrics.health_metrics.conditions.chronic],
      injuries: [injury.injury for injury in metrics.health_metrics.conditions.injuries],
      allergies: [allergy.allergy for allergy in metrics.health_metrics.conditions.allergies],
    },
    
    fitness_level: {
      vo2_max: metrics.health_metrics.fitness_assessments.cardio.vo2_max.current + " " + 
               metrics.health_metrics.fitness_assessments.cardio.vo2_max.unit,
      strength: [
        exercise.exercise + ": " + exercise.one_rep_max.current + " " + exercise.one_rep_max.unit
        for exercise in metrics.health_metrics.fitness_assessments.strength
      ],
    },
    
    nutrition_summary: {
      dietary_restrictions: metrics.health_metrics.nutrition.dietary_restrictions,
      supplements: metrics.health_metrics.nutrition.supplements,
    },
    
    sleep_summary: {
      average_duration: metrics.health_metrics.sleep.average_duration.current + " " + 
                        metrics.health_metrics.sleep.average_duration.unit,
      quality: metrics.health_metrics.sleep.quality_rating.current,
    },
  },
}
