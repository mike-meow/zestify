// medical_history.jsonnet - Medical history memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with medical history specific fields
  medical_history:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Medical conditions
    conditions: {
      chronic: [],
      past: [],
      family: [],
      
      // Method to add a condition
      addCondition(category, condition):: self + {
        [category]: self[category] + [condition],
      },
    },
    
    // Medications
    medications: {
      current: [],
      past: [],
      
      // Method to add a medication
      addMedication(category, medication):: self + {
        [category]: self[category] + [medication],
      },
    },
    
    // Allergies
    allergies: [],
    
    // Surgeries and procedures
    procedures: [],
    
    // Immunizations
    immunizations: [],
    
    // Medical visits
    medical_visits: [],
    
    // Lab results
    lab_results: [],
    
    // Method to add a medical visit
    addMedicalVisit(visit):: self + {
      medical_visits: [visit] + self.medical_visits,
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to add a lab result
    addLabResult(result):: self + {
      lab_results: [result] + self.lab_results,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Medical condition structure
  medical_condition:: {
    condition: "",
    diagnosed_date: "",
    status: "", // active, resolved, managed
    severity: "", // mild, moderate, severe
    treating_physician: "",
    medications: [],
    notes: "",
  },
  
  // Medication structure
  medication:: {
    name: "",
    dosage: "",
    frequency: "",
    start_date: "",
    end_date: "",
    purpose: "",
    prescribing_physician: "",
    side_effects: [],
    notes: "",
  },
  
  // Allergy structure
  allergy:: {
    allergen: "",
    reaction: "",
    severity: "", // mild, moderate, severe
    diagnosed_date: "",
    notes: "",
  },
  
  // Procedure structure
  procedure:: {
    procedure: "",
    date: "",
    provider: "",
    facility: "",
    reason: "",
    outcome: "",
    notes: "",
  },
  
  // Immunization structure
  immunization:: {
    vaccine: "",
    date: "",
    provider: "",
    lot_number: "",
    notes: "",
  },
  
  // Medical visit structure
  medical_visit:: {
    visit_type: "", // routine, specialist, emergency
    date: "",
    provider: "",
    facility: "",
    reason: "",
    diagnosis: "",
    treatment: "",
    follow_up: "",
    notes: "",
  },
  
  // Lab result structure
  lab_result:: {
    test_name: "",
    date: "",
    result: "",
    reference_range: "",
    interpretation: "", // normal, abnormal, critical
    ordering_physician: "",
    notes: "",
  },
  
  // Factory method to create new medical history
  newMedicalHistory(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    medical_history: $.medical_history + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Method to update medical history
  updateMedicalHistory(history, updates):: {
    metadata: history.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    medical_history: $.utils.deepMerge(history.medical_history, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(history):: {
    user_id: history.medical_history.user_id,
    last_updated: history.medical_history.last_updated,
    
    chronic_conditions: [
      condition.condition + " (" + condition.status + ")"
      for condition in history.medical_history.conditions.chronic
    ],
    
    current_medications: [
      medication.name + " " + medication.dosage + " " + medication.frequency
      for medication in history.medical_history.medications.current
    ],
    
    allergies: [
      allergy.allergen + " - " + allergy.reaction + " (" + allergy.severity + ")"
      for allergy in history.medical_history.allergies
    ],
    
    recent_procedures: [
      procedure.procedure + " (" + procedure.date + ")"
      for procedure in history.medical_history.procedures
    ][0:3],  // Only include the 3 most recent procedures
    
    recent_visits: [
      {
        date: visit.date,
        provider: visit.provider,
        reason: visit.reason,
        diagnosis: visit.diagnosis,
        treatment: visit.treatment,
      }
      for visit in history.medical_history.medical_visits
    ][0:3],  // Only include the 3 most recent visits
    
    recent_lab_results: [
      {
        test: result.test_name,
        date: result.date,
        result: result.result,
        interpretation: result.interpretation,
      }
      for result in history.medical_history.lab_results
    ][0:5],  // Only include the 5 most recent lab results
  },
}
