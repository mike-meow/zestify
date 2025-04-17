// body_composition.jsonnet - Body composition memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with body composition specific fields
  body_composition:: {
    // Body composition measurements
    weight: {
      current: 0.0,
      unit: "kg",
      history: [],
    },
    
    bmi: {
      current: 0.0,
      unit: "kg/m²",
      history: [],
    },
    
    body_fat_percentage: {
      current: 0.0,
      unit: "%",
      history: [],
    },
    
    muscle_mass: {
      current: 0.0,
      unit: "kg",
      history: [],
    },
    
    bone_mass: {
      current: 0.0,
      unit: "kg",
      history: [],
    },
    
    water_percentage: {
      current: 0.0,
      unit: "%",
      history: [],
    },
  },
  
  // Factory method to create new body composition data
  newBodyComposition():: $.body_composition,
  
  // Method to update body composition
  updateBodyComposition(data, updates):: $.utils.deepMerge(data, updates),
  
  // Convert to YAML-friendly format for LLM
  toYaml(data):: {
    weight: data.weight.current + " " + data.weight.unit,
    bmi: data.bmi.current + " " + data.bmi.unit,
    body_fat: data.body_fat_percentage.current + " " + data.body_fat_percentage.unit,
    muscle_mass: data.muscle_mass.current + " " + data.muscle_mass.unit,
    water_percentage: data.water_percentage.current + " " + data.water_percentage.unit,
  },
}
