// memory_utils.jsonnet - Utility functions for memory operations
{
  // Import all memory templates
  user_profile: import 'memory_templates/user_profile.jsonnet',
  health_metrics: import 'memory_templates/health_metrics.jsonnet',
  workout_memory: import 'memory_templates/workout_memory.jsonnet',
  conversation_memory: import 'memory_templates/conversation_memory.jsonnet',
  medical_history: import 'memory_templates/medical_history.jsonnet',
  biometrics: import 'memory_templates/biometrics.jsonnet',
  goals: import 'memory_templates/goals.jsonnet',
  
  // Compose memory from multiple sources
  composeMemory(user_id, options={})::
    local default_options = {
      include_profile: true,
      include_health_metrics: true,
      include_workouts: true,
      include_conversations: true,
      include_medical_history: true,
      include_biometrics: true,
      include_goals: true,
      
      // Filtering options
      recent_workouts_count: 5,
      recent_conversations_count: 3,
      recent_medical_visits_count: 3,
    };
    
    local opts = default_options + options;
    
    // This would load the actual data in a real implementation
    // For now, we'll just create empty templates
    local profile = if opts.include_profile then 
      $.user_profile.newUserProfile(user_id, "Example User") else null;
    
    local health_metrics = if opts.include_health_metrics then 
      $.health_metrics.newHealthMetrics(user_id) else null;
    
    local workouts = if opts.include_workouts then 
      $.workout_memory.newWorkoutMemory(user_id) else null;
    
    local conversations = if opts.include_conversations then 
      $.conversation_memory.newConversationMemory(user_id) else null;
    
    local medical = if opts.include_medical_history then 
      $.medical_history.newMedicalHistory(user_id) else null;
    
    local biometrics = if opts.include_biometrics then 
      $.biometrics.newBiometrics(user_id) else null;
    
    local goals = if opts.include_goals then 
      $.goals.newGoalsMemory(user_id) else null;
    
    // Compose the memory
    {
      user_id: user_id,
      timestamp: std.extVar('timestamp'),
      
      profile: if profile != null then profile.user_profile else null,
      health_metrics: if health_metrics != null then health_metrics.health_metrics else null,
      workouts: if workouts != null then workouts.workout_memory else null,
      conversations: if conversations != null then conversations.conversation_memory else null,
      medical_history: if medical != null then medical.medical_history else null,
      biometrics: if biometrics != null then biometrics.biometrics else null,
      goals: if goals != null then goals.goals else null,
    },
  
  // Format memory for LLM prompt
  formatPrompt(memory, template_name, additional_context={})::
    local templates = {
      onboarding_question: |||
        # User Profile
        Name: %(name)s
        
        # Current Goals
        %(goals)s
        
        # Health Context
        %(health_context)s
        
        # Previous Conversations
        %(conversations)s
        
        # Additional Context
        %(additional_context)s
        
        Based on the above information, ask the next most relevant onboarding question to understand the user's health and fitness needs better.
      |||,
      
      workout_recommendation: |||
        # User Profile
        Name: %(name)s
        Fitness Level: %(fitness_level)s
        
        # Goals
        %(goals)s
        
        # Recent Workouts
        %(recent_workouts)s
        
        # Health Metrics
        %(health_metrics)s
        
        # Preferences
        %(preferences)s
        
        # Additional Context
        %(additional_context)s
        
        Based on the above information, recommend a workout plan for the next week that aligns with the user's goals and takes into account their recent activity and health status.
      |||,
      
      // Add more templates as needed
    };
    
    // Extract relevant information from memory
    local name = if memory.profile != null then memory.profile.name else "User";
    
    local goals_text = if memory.goals != null && std.length(memory.goals.active_goals) > 0 then
      std.join("\n", [
        "- " + goal.title + ": " + goal.description + " (Progress: " + std.toString(goal.progress) + "%)"
        for goal in memory.goals.active_goals
      ])
    else
      "No goals set yet.";
    
    local health_context = if memory.health_metrics != null then
      "Height: " + std.toString(memory.health_metrics.measurements.height.current) + " cm\n" +
      "Weight: " + std.toString(memory.health_metrics.measurements.weight.current) + " kg\n" +
      "Conditions: " + (
        if std.length(memory.health_metrics.conditions.chronic) > 0 then
          std.join(", ", [condition.condition for condition in memory.health_metrics.conditions.chronic])
        else
          "None reported"
      )
    else
      "No health metrics available.";
    
    local recent_workouts = if memory.workouts != null && std.length(memory.workouts.recent_workouts) > 0 then
      std.join("\n", [
        "- " + workout.date + ": " + workout.type + " (" + 
        std.toString(std.floor(workout.duration_seconds / 60)) + " min, " + 
        std.toString(workout.distance_meters / 1000) + " km)"
        for workout in memory.workouts.recent_workouts
      ][0:5])  // Only include the 5 most recent workouts
    else
      "No recent workouts.";
    
    local conversations_text = if memory.conversations != null && std.length(memory.conversations.recent_conversations) > 0 then
      std.join("\n", [
        "- " + conversation.topic + ": " + conversation.summary
        for conversation in memory.conversations.recent_conversations
      ][0:3])  // Only include the 3 most recent conversations
    else
      "No previous conversations.";
    
    local health_metrics_text = if memory.health_metrics != null then
      "Height: " + std.toString(memory.health_metrics.measurements.height.current) + " cm\n" +
      "Weight: " + std.toString(memory.health_metrics.measurements.weight.current) + " kg\n" +
      "BMI: " + std.toString(memory.health_metrics.measurements.body_composition.bmi.current) + "\n" +
      "Resting Heart Rate: " + std.toString(memory.health_metrics.vitals.resting_heart_rate.current) + " bpm"
    else
      "No health metrics available.";
    
    local preferences_text = if memory.profile != null && memory.profile.preferences != null then
      "Preferred workout time: " + memory.profile.preferences.time_availability.preferred_time + "\n" +
      "Days per week: " + std.toString(memory.profile.preferences.time_availability.days_per_week) + "\n" +
      "Minutes per session: " + std.toString(memory.profile.preferences.time_availability.minutes_per_session) + "\n" +
      "Preferred activities: " + std.join(", ", [
        pref.activity for pref in memory.profile.preferences.activity_preferences.preferred
      ])
    else
      "No preferences available.";
    
    local additional_context_text = std.join("\n", [
      key + ": " + additional_context[key]
      for key in std.objectFields(additional_context)
    ]);
    
    // Format the template
    templates[template_name] % {
      name: name,
      goals: goals_text,
      health_context: health_context,
      recent_workouts: recent_workouts,
      conversations: conversations_text,
      health_metrics: health_metrics_text,
      preferences: preferences_text,
      fitness_level: if memory.profile != null && std.length(memory.profile.fitness_timeline) > 0 then
                     memory.profile.fitness_timeline[std.length(memory.profile.fitness_timeline)-1].fitness_level
                     else "unknown",
      additional_context: additional_context_text,
    },
  
  // Convert memory to YAML for LLM
  toYaml(memory)::
    local yaml_sections = [];
    
    local profile_yaml = if memory.profile != null then
      $.user_profile.toYaml({user_profile: memory.profile})
    else
      null;
    
    local health_metrics_yaml = if memory.health_metrics != null then
      $.health_metrics.toYaml({health_metrics: memory.health_metrics})
    else
      null;
    
    local workouts_yaml = if memory.workouts != null then
      $.workout_memory.toYaml({workout_memory: memory.workouts})
    else
      null;
    
    local conversations_yaml = if memory.conversations != null then
      $.conversation_memory.toYaml({conversation_memory: memory.conversations})
    else
      null;
    
    local medical_yaml = if memory.medical_history != null then
      $.medical_history.toYaml({medical_history: memory.medical_history})
    else
      null;
    
    local biometrics_yaml = if memory.biometrics != null then
      $.biometrics.toYaml({biometrics: memory.biometrics})
    else
      null;
    
    local goals_yaml = if memory.goals != null then
      $.goals.toYaml({goals: memory.goals})
    else
      null;
    
    // Combine all YAML sections
    {
      user_id: memory.user_id,
      timestamp: memory.timestamp,
      profile: profile_yaml,
      health_metrics: health_metrics_yaml,
      workouts: workouts_yaml,
      conversations: conversations_yaml,
      medical_history: medical_yaml,
      biometrics: biometrics_yaml,
      goals: goals_yaml,
    },
  
  // Update memory with new information
  updateMemory(memory, updates)::
    // This would handle updating the appropriate memory sections
    // based on the structure of the updates
    // For now, we'll just provide a simple deep merge
    local deepMerge(a, b) =
      if std.type(a) == 'object' && std.type(b) == 'object' then
        local all_keys = std.set(std.objectFields(a) + std.objectFields(b));
        {
          [k]: if !std.objectHas(a, k) then b[k] else
               if !std.objectHas(b, k) then a[k] else
               deepMerge(a[k], b[k])
          for k in all_keys
        }
      else
        b;
    
    deepMerge(memory, updates) + {
      timestamp: std.extVar('timestamp'),
    },
}
