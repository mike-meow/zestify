// conversation_memory.jsonnet - Conversation memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with conversation memory specific fields
  conversation_memory:: {
    // Link to user profile
    user_id: $.metadata.user_id,
    last_updated: $.metadata.last_updated,
    
    // Recent conversations
    recent_conversations: [],
    
    // Important insights derived from conversations
    important_insights: [],
    
    // Conversation patterns
    conversation_patterns: {
      engagement_level: "",
      response_time: "",
      conversation_depth: "",
      preferred_topics: [],
      avoided_topics: [],
    },
    
    // Communication preferences
    communication_preferences: {
      tone: "",
      detail_level: "",
      interaction_style: "",
      feedback_style: "",
    },
    
    // Coaching approach
    coaching_approach: {
      primary_style: "",
      effective_motivators: [],
      ineffective_approaches: [],
    },
    
    // Method to add a conversation
    addConversation(conversation):: self + {
      recent_conversations: [conversation] + self.recent_conversations,
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to add an insight
    addInsight(insight):: self + {
      important_insights: self.important_insights + [insight],
      last_updated: std.extVar('timestamp'),
    },
    
    // Method to update conversation patterns
    updateConversationPatterns(patterns):: self + {
      conversation_patterns: $.utils.deepMerge(self.conversation_patterns, patterns),
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Conversation structure
  conversation:: {
    id: "",
    timestamp: "",
    topic: "",
    summary: "",
    key_points: [],
    user_sentiment: "",
    action_items: [],
    follow_up_required: false,
    follow_up_date: "",
    
    // Method to add a key point
    addKeyPoint(point):: self + {
      key_points: self.key_points + [point],
    },
    
    // Method to add an action item
    addActionItem(item):: self + {
      action_items: self.action_items + [item],
    },
  },
  
  // Topic structure for preferred/avoided topics
  topic:: {
    topic: "",
    engagement_score: 0,
  },
  
  // Factory method to create new conversation memory
  newConversationMemory(user_id):: {
    metadata: $.metadata + {
      user_id: user_id,
      created_at: std.extVar('timestamp'),
      last_updated: std.extVar('timestamp'),
    },
    conversation_memory: $.conversation_memory + {
      user_id: user_id,
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Factory method to create a new conversation
  newConversation(topic, summary):: $.conversation + {
    id: $.utils.generateId("conv"),
    timestamp: std.extVar('timestamp'),
    topic: topic,
    summary: summary,
  },
  
  // Method to update conversation memory
  updateConversationMemory(memory, updates):: {
    metadata: memory.metadata + {
      last_updated: std.extVar('timestamp'),
    },
    conversation_memory: $.utils.deepMerge(memory.conversation_memory, updates) + {
      last_updated: std.extVar('timestamp'),
    },
  },
  
  // Convert to YAML-friendly format for LLM
  toYaml(memory):: {
    user_id: memory.conversation_memory.user_id,
    last_updated: memory.conversation_memory.last_updated,
    
    recent_conversations: [
      {
        timestamp: conversation.timestamp,
        topic: conversation.topic,
        summary: conversation.summary,
        key_points: conversation.key_points,
        user_sentiment: conversation.user_sentiment,
        action_items: conversation.action_items,
      }
      for conversation in memory.conversation_memory.recent_conversations
    ][0:3],  // Only include the 3 most recent conversations
    
    important_insights: [
      {
        category: insight.category,
        insight: insight.insight,
        confidence: std.toString(insight.confidence) + "%",
        supporting_evidence: insight.supporting_evidence,
      }
      for insight in memory.conversation_memory.important_insights
    ],
    
    communication_preferences: memory.conversation_memory.communication_preferences,
    
    coaching_approach: memory.conversation_memory.coaching_approach,
  },
}
