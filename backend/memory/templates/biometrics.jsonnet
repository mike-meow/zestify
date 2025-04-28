// biometrics.jsonnet - Biometrics memory template
// This template combines both body composition and vital signs data
local base = import 'base.jsonnet';

base + {
  // Extend the base template with biometrics specific fields
  biometrics:: {
    // Core biometrics data structure

    // Body composition section
    body_composition: {
      // Weight
      weight: {
        value: 0.0,
        unit: "kg",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // BMI
      bmi: {
        value: 0.0,
        unit: "kg/m²",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Body fat percentage
      body_fat_percentage: {
        value: 0.0,
        unit: "%",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Height
      height: {
        value: 0.0,
        unit: "cm",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Lean body mass
      lean_body_mass: {
        value: 0.0,
        unit: "kg",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Waist circumference
      waist_circumference: {
        value: 0.0,
        unit: "cm",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },
    },

    // Vital signs section
    vital_signs: {
      // Resting heart rate
      resting_heart_rate: {
        value: 0.0,
        unit: "bpm",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Blood pressure systolic
      blood_pressure_systolic: {
        value: 0.0,
        unit: "mmHg",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Blood pressure diastolic
      blood_pressure_diastolic: {
        value: 0.0,
        unit: "mmHg",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Respiratory rate
      respiratory_rate: {
        value: 0.0,
        unit: "breaths/min",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Blood oxygen
      blood_oxygen: {
        value: 0.0,
        unit: "%",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Blood glucose
      blood_glucose: {
        value: 0.0,
        unit: "mg/dL",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },

      // Body temperature
      body_temperature: {
        value: 0.0,
        unit: "°C",
        timestamp: "",
        source: "Apple Health",
        notes: null,
        history: [],
      },
    },

  },

  // Factory method to create new biometrics
  newBiometrics():: {
    body_composition: $.biometrics.body_composition,
    vital_signs: $.biometrics.vital_signs,
  },

  // Method to update biometrics
  updateBiometrics(data, updates):: $.utils.deepMerge(data, updates),

  // Convert to YAML-friendly format for LLM
  toYaml(data):: {
    body_composition: {
      weight: data.body_composition.weight.value + " " + data.body_composition.weight.unit,
      bmi: data.body_composition.bmi.value + " " + data.body_composition.bmi.unit,
      body_fat: data.body_composition.body_fat_percentage.value + " " + data.body_composition.body_fat_percentage.unit,
      height: data.body_composition.height.value + " " + data.body_composition.height.unit,
      // Include history count for reference
      weight_history_count: std.length(data.body_composition.weight.history),
    },
    vital_signs: {
      resting_heart_rate: data.vital_signs.resting_heart_rate.value + " " + data.vital_signs.resting_heart_rate.unit,
      blood_pressure: data.vital_signs.blood_pressure_systolic.value + "/" +
                     data.vital_signs.blood_pressure_diastolic.value + " " +
                     data.vital_signs.blood_pressure_systolic.unit,
      blood_oxygen: data.vital_signs.blood_oxygen.value + " " + data.vital_signs.blood_oxygen.unit,
      blood_glucose: data.vital_signs.blood_glucose.value + " " + data.vital_signs.blood_glucose.unit,
    },
  },
}
