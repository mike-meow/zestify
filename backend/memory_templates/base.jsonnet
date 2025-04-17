// base.jsonnet - Core memory template structures and utilities
{
  // Common metadata fields for all memory types
  metadata:: {
    user_id: "",
    created_at: "",
    last_updated: "",
    version: "1.0",
  },

  // Common timestamp format for consistency
  timestamp_format:: "%Y-%m-%dT%H:%M:%SZ",
  
  // Common history entry structure
  history_entry:: {
    timestamp: "",
    value: null,
    source: "user", // user, system, device, etc.
    notes: "",
  },
  
  // Common measurement with history
  measurement_with_history:: {
    current: null,
    unit: "",
    history: [],
    
    // Method to add a history entry
    addHistoryEntry(value, timestamp, source="user", notes=""):: self + {
      current: value,
      history: self.history + [{
        value: value,
        timestamp: timestamp,
        source: source,
        notes: notes,
      }],
    },
  },
  
  // Common goal structure
  goal:: {
    id: "",
    type: "",
    description: "",
    created_at: "",
    target_date: "",
    progress: 0, // 0-100 percentage
    status: "active", // active, completed, abandoned
    metrics: [],
  },
  
  // Common insight structure
  insight:: {
    category: "",
    insight: "",
    confidence: 0, // 0-100 percentage
    supporting_evidence: [],
    timestamp: "",
  },
  
  // Utility functions
  utils:: {
    // Generate a unique ID with prefix and timestamp
    generateId(prefix):: 
      local timestamp = std.extVar('timestamp'); // This would be provided externally
      prefix + "_" + std.strReplace(timestamp, ":", "") + "_" + std.substr(std.md5(timestamp), 0, 6),
    
    // Deep merge two objects
    deepMerge(a, b)::
      if std.type(a) == 'object' && std.type(b) == 'object' then
        local all_keys = std.set(std.objectFields(a) + std.objectFields(b));
        {
          [k]: if !std.objectHas(a, k) then b[k] else
               if !std.objectHas(b, k) then a[k] else
               $.utils.deepMerge(a[k], b[k])
          for k in all_keys
        }
      else
        b,
  },
}
