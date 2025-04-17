# Workout Goal Prompt Template Research

## Overview

This document explores the design of effective prompt templates for workout goal setting in a health AI application. The goal is to create conversational, option-based prompts that leverage existing user data to help users set meaningful fitness goals with minimal effort.

## Key Considerations

1. **Data-Informed Prompting**: Utilize existing health data to make relevant suggestions
2. **Conversational Flow**: Create a natural dialogue that feels like talking to a coach
3. **Option-Based Approach**: Reduce user burden by providing clear choices
4. **Personalization**: Tailor suggestions to user's fitness level, preferences, and history
5. **Progressive Disclosure**: Start broad, then narrow down based on user responses

## Prompt Structure

### System Prompt (Context Setting)

The system prompt provides context to the AI about the user and the goal-setting task:

```
You are a health and fitness AI assistant focused on helping the user set and achieve workout goals.

User Profile:
- Name: {user.name}
- Age: {user.age}
- Fitness Level: {user.fitness_level}
- Health Conditions: {user.health_conditions}
- Preferred Activities: {user.preferred_activities}

Recent Activity:
{recent_workouts_summary}

Current Goals:
{current_goals_summary}

Your task is to help the user set meaningful workout goals. Ask targeted questions to understand their preferences and aspirations.
Offer 2-3 specific goal options based on their fitness level and history.
Each goal should be SMART (Specific, Measurable, Achievable, Relevant, Time-bound).
Present options in a conversational way, making it easy for the user to choose.
```

### Initial Prompt (Conversation Starter)

The initial prompt begins the goal-setting conversation:

```
I'd like to help you set some meaningful workout goals. Based on your activity history and preferences, I have a few ideas, but first:

1. Are you looking to focus more on performance (like speed or distance), consistency (regular exercise habit), or specific fitness outcomes (strength, endurance, etc.)?

2. What timeframe are you thinking for your next goal? A few weeks, a couple of months, or longer term?

3. Is there a specific activity you'd like to focus on improving?
```

### Follow-up Prompts (Based on User Responses)

#### Performance Focus

```
Great! Since you're interested in improving performance, here are some potential goals based on your recent {activity_type} data:

Option A: Improve your 5K time from {current_5k_time} to {target_5k_time} in the next 8 weeks
- This would involve 3-4 runs per week including one interval session
- Your recent pace improvements suggest this is achievable

Option B: Increase your cycling FTP from {current_ftp} to {target_ftp} by {target_date}
- This would involve 2 structured cycling workouts per week
- Builds on your consistent riding over the past month

Option C: Complete a {target_distance} {activity_type} event by {target_date}
- This would gradually build your endurance with progressive long sessions
- Aligns with your preference for longer weekend activities

Which of these resonates with you, or would you prefer something different?
```

#### Consistency Focus

```
Building consistent habits is a great focus! Based on your schedule and preferences, here are some potential consistency goals:

Option A: Complete {target_number} workouts per week for the next 4 weeks
- Mix of {activity_1}, {activity_2}, and {activity_3} based on your preferences
- Flexible scheduling to fit your typical availability

Option B: Establish a {day_1}/{day_2}/{day_3} workout routine for 30 days
- Specific activities assigned to specific days for better habit formation
- Includes one rest/recovery day between challenging sessions

Option C: Accumulate {target_minutes} active minutes per week for 6 weeks
- Allows for variety in workout types and durations
- Focus on consistency rather than specific performance metrics

Which approach to consistency would work best for your schedule and preferences?
```

#### Specific Fitness Outcome Focus

```
Focusing on {specific_fitness_outcome} is a great goal! Here are some targeted options:

Option A: Increase {specific_metric} by {target_improvement} in 8 weeks
- Structured progression with weekly targets
- Includes specific exercises/workouts designed for this outcome

Option B: Complete a progressive {workout_type} program by {target_date}
- 3 phases of increasing intensity
- Designed specifically to improve {specific_fitness_outcome}

Option C: Achieve {specific_benchmark} by {target_date}
- A specific, measurable target that demonstrates improvement in {specific_fitness_outcome}
- Includes regular assessment points to track progress

Which of these approaches to improving {specific_fitness_outcome} appeals to you most?
```

## Example Conversation Flow

### Example 1: Runner Looking to Improve Performance

**System**: [Context about user, running history, etc.]

**Assistant**: I'd like to help you set some meaningful workout goals. Based on your running history and preferences, I have a few ideas, but first:

1. Are you looking to focus more on performance (like speed or distance), consistency (regular exercise habit), or specific fitness outcomes (strength, endurance, etc.)?

2. What timeframe are you thinking for your next goal? A few weeks, a couple of months, or longer term?

3. Is there a specific activity you'd like to focus on improving?

**User**: I want to get faster at running, maybe over the next 2-3 months.

**Assistant**: Great! Since you're interested in improving your running performance over the next 2-3 months, here are some potential goals based on your recent activity:

Option A: Improve your 5K time from 28:30 to 26:00 by July 15th
- This would involve 3 runs per week including one interval session
- Your recent pace improvements suggest this is achievable

Option B: Build up to a 10K race in 55 minutes by August 1st
- This would involve a progressive training plan with longer runs
- Builds on your current 5K fitness with gradual distance increases

Option C: Increase your average running frequency from 2 to 4 times per week for 8 weeks
- Focus on consistency as the foundation for speed improvements
- Includes a mix of easy runs, intervals, and one longer run per week

Which of these resonates with you, or would you prefer something different?

**User**: I like option A, improving my 5K time sounds good.

**Assistant**: Excellent choice! Improving your 5K time from 28:30 to 26:00 by July 15th is a specific, measurable goal that's challenging but achievable based on your history.

Here's a simple plan to get started:

Week 1-2: Baseline building
- 3 runs per week: 2 easy runs (30 min each) + 1 interval session (6x400m)
- Focus on consistency and form

Week 3-4: Building speed
- 3-4 runs per week: 2 easy runs + 1 interval session (8x400m) + optional longer run
- Start tracking your pace more closely

Week 5-8: Performance focus
- 3-4 runs per week with more structured workouts
- Weekly interval session progressively increasing in intensity
- One tempo run at target 5K pace

Would you like me to set this up as your current goal and provide more details on the training plan?

## Implementation Recommendations

1. **Dynamic Template Population**:
   - Use user data to populate templates with personalized values
   - Calculate appropriate target metrics based on current performance
   - Reference recent activities and patterns

2. **Branching Logic**:
   - Create decision trees for different user responses
   - Prepare templates for common goal types and timeframes
   - Have fallback options for unexpected responses

3. **Memory Integration**:
   - Store user responses to inform future interactions
   - Track which goals were selected vs. rejected
   - Update templates based on user progress and feedback

4. **Feedback Loop**:
   - After goal selection, confirm understanding
   - Provide immediate next steps
   - Schedule check-ins to assess progress

## Next Steps

1. Implement prototype prompt templates for the most common goal types
2. Test with sample user data to ensure personalization works effectively
3. Create a library of follow-up prompts for different user responses
4. Develop a mechanism to track goal progress and adjust recommendations
5. Integrate with the broader conversation flow of the AI assistant
