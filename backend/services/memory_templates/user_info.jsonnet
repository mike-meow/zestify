// user_info.jsonnet - User info memory template
local base = import 'base.jsonnet';

base + {
  // Extend the base template with user info specific fields
  user_info:: {
    // Core user information
    user_id: $.metadata.user_id,
    created_at: $.metadata.created_at,
    updated_at: $.metadata.last_updated,
  },
  
  // Factory method to create a new user info
  newUserInfo(user_id):: {
    user_id: user_id,
    created_at: std.extVar('timestamp'),
    updated_at: std.extVar('timestamp'),
  },
  
  // Method to update user info
  updateUserInfo(info, updates):: $.utils.deepMerge(info, updates) + {
    updated_at: std.extVar('timestamp'),
  },
}
