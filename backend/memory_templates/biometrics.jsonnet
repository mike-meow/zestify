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
        current: 0.0,
        unit: "kg",
        history: [],
      },

      // BMI
      bmi: {
        current: 0.0,
        unit: "kg/m²",
        history: [],
      },

      // Body fat percentage
      body_fat_percentage: {
        current: 0.0,
        unit: "%",
        history: [],
      },

      // Height
      height: {
        current: 0.0,
        unit: "cm",
        history: [],
      },

      // Lean body mass
      lean_body_mass: {
        current: 0.0,
        unit: "kg",
        history: [],
      },

      // Waist circumference
      waist_circumference: {
        current: 0.0,
        unit: "cm",
        history: [],
      },
    },

    // Vital signs section
    vital_signs: {
      // Resting heart rate
      resting_heart_rate: {
        current: 0.0,
        unit: "bpm",
        history: [],
      },

      // Blood pressure systolic
      blood_pressure_systolic: {
        current: 0.0,
        unit: "mmHg",
        history: [],
      },

      // Blood pressure diastolic
      blood_pressure_diastolic: {
        current: 0.0,
        unit: "mmHg",
        history: [],
      },

      // Respiratory rate
      respiratory_rate: {
        current: 0.0,
        unit: "breaths/min",
        history: [],
      },

      // Blood oxygen
      blood_oxygen: {
        current: 0.0,
        unit: "%",
        history: [],
      },

      // Blood glucose
      blood_glucose: {
        current: 0.0,
        unit: "mg/dL",
        history: [],
      },

      // Body temperature
      body_temperature: {
        current: 0.0,
        unit: "°C",
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
      weight: data.body_composition.weight.current + " " + data.body_composition.weight.unit,
      bmi: data.body_composition.bmi.current + " " + data.body_composition.bmi.unit,
      body_fat: data.body_composition.body_fat_percentage.current + " " + data.body_composition.body_fat_percentage.unit,
      height: data.body_composition.height.current + " " + data.body_composition.height.unit,
    },
    vital_signs: {
      resting_heart_rate: data.vital_signs.resting_heart_rate.current + " " + data.vital_signs.resting_heart_rate.unit,
      blood_pressure: data.vital_signs.blood_pressure_systolic.current + "/" +
                     data.vital_signs.blood_pressure_diastolic.current + " " +
                     data.vital_signs.blood_pressure_systolic.unit,
      blood_oxygen: data.vital_signs.blood_oxygen.current + " " + data.vital_signs.blood_oxygen.unit,
      blood_glucose: data.vital_signs.blood_glucose.current + " " + data.vital_signs.blood_glucose.unit,
    },
  },
}
