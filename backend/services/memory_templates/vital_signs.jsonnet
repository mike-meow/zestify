// vital_signs.jsonnet - Vital signs memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with vital signs specific fields
  vital_signs:: {
    // Heart rate data
    resting_heart_rate: {
      current: 0.0,
      unit: "bpm",
      history: [],
    },
    
    // Blood pressure
    blood_pressure_systolic: {
      current: 0.0,
      unit: "mmHg",
      history: [],
    },
    
    blood_pressure_diastolic: {
      current: 0.0,
      unit: "mmHg",
      history: [],
    },
    
    // Oxygen saturation
    oxygen_saturation: {
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
    
    // Respiratory rate
    respiratory_rate: {
      current: 0.0,
      unit: "breaths/min",
      history: [],
    },
  },
  
  // Factory method to create new vital signs data
  newVitalSigns():: $.vital_signs,
  
  // Method to update vital signs
  updateVitalSigns(data, updates):: $.utils.deepMerge(data, updates),
  
  // Convert to YAML-friendly format for LLM
  toYaml(data):: {
    resting_heart_rate: data.resting_heart_rate.current + " " + data.resting_heart_rate.unit,
    blood_pressure: data.blood_pressure_systolic.current + "/" + 
                   data.blood_pressure_diastolic.current + " " + 
                   data.blood_pressure_systolic.unit,
    oxygen_saturation: data.oxygen_saturation.current + " " + data.oxygen_saturation.unit,
    blood_glucose: data.blood_glucose.current + " " + data.blood_glucose.unit,
    body_temperature: data.body_temperature.current + " " + data.body_temperature.unit,
    respiratory_rate: data.respiratory_rate.current + " " + data.respiratory_rate.unit,
  },
}
