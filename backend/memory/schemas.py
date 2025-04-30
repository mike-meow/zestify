from pydantic import BaseModel, Field, root_validator, field_validator
from typing import List, Optional, Dict, Any, Union
from datetime import datetime, date, timedelta
from collections import defaultdict
import statistics
import pprint

# Helper function for date calculations
def get_time_ago(target_date: Union[date, datetime], now: datetime = None) -> timedelta:
    if now is None:
        now = datetime.now()
    if isinstance(target_date, datetime):
        target_date = target_date.date()
    return now.date() - target_date

# Helper to format duration
def format_duration(seconds: Optional[float]) -> str:
    if seconds is None or seconds < 0:
        return "N/A"

    seconds = int(seconds)
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60

    parts = []
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    if secs > 0 or not parts: # Show seconds if non-zero or if it's the only unit
        parts.append(f"{secs}s")

    return " ".join(parts)

# Helper to format distance
def format_distance(distance: Optional[float], unit: Optional[str]) -> str:
    if distance is None or unit is None:
        return "N/A"
    return f"{distance:.2f} {unit}"

# Helper to format HR
def format_hr(hr_summary: Optional[Dict[str, Any]]) -> str:
    if not hr_summary or 'average' not in hr_summary or hr_summary['average'] is None:
        return "HR N/A"
    avg = int(hr_summary['average'])
    unit = hr_summary.get('unit', 'bpm')
    return f"Avg {avg} {unit}"

# Helper for summarizing list of values
def summarize_values(values: List[float]) -> str:
    if not values:
        return "N/A"
    count = len(values)
    avg = statistics.mean(values) if count > 0 else 0
    min_val = min(values) if count > 0 else 0
    max_val = max(values) if count > 0 else 0
    median = statistics.median(values) if count > 0 else 0
    return f"Count: {count}, Avg: {avg:.1f}, Min: {min_val:.1f}, Max: {max_val:.1f}, Median: {median:.1f}"

class UserInfo(BaseModel):
    user_id: str
    created_at: datetime
    updated_at: datetime

class HeartRateSummary(BaseModel):
    average: Optional[float]
    min: Optional[float]
    max: Optional[float]
    unit: Optional[str]

class CompactWorkout(BaseModel):
    workout_type: Optional[str] = None
    start_date: Optional[date] = None
    duration_minutes: Optional[float] = None
    distance: Optional[float] = None
    distance_unit: Optional[str] = None
    calories: Optional[float] = None

class RecentWorkout(CompactWorkout):
    id: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    active_energy_burned: Optional[float] = None
    active_energy_burned_unit: Optional[str] = None
    heart_rate_summary: Optional[Dict[str, Any]] = None
    source: Optional[str] = None
    original_type: Optional[str] = None
    workout_type: Optional[str] = None

    @root_validator(pre=True)
    def process_incoming_workout_data(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        """Ensure original_type is populated if missing, using workout_type."""

        # If original_type is missing in the incoming data, copy workout_type to it.
        # Now, workout_type should ideally be the raw string directly from the frontend.
        if values.get('original_type') is None and values.get('workout_type') is not None:
            values['original_type'] = values.get('workout_type')

        # Ensure workout_type is not None, default to original_type or 'Other'
        if values.get('workout_type') is None:
             values['workout_type'] = values.get('original_type', 'Other')

        # Calculate Duration (Keep existing logic)
        if values.get('duration_seconds') is None:
            start = values.get('start_date')
            end = values.get('end_date')
            if start and end:
                try:
                    start_dt = datetime.fromisoformat(str(start).replace("Z", "+00:00"))
                    end_dt = datetime.fromisoformat(str(end).replace("Z", "+00:00"))
                    if end_dt > start_dt:
                        values['duration_seconds'] = (end_dt - start_dt).total_seconds()
                except (ValueError, TypeError):
                    pass # Ignore if dates are invalid

        return values

    def to_compact(self) -> CompactWorkout:
        # Calculate duration_minutes on the fly for the compact view
        duration_mins = None
        if self.duration_seconds is not None:
             duration_mins = round(self.duration_seconds / 60, 1)

        return CompactWorkout(
            workout_type=self.workout_type, # Use the potentially corrected type
            start_date=self.start_date.date() if self.start_date else None,
            duration_minutes=duration_mins,
            distance=self.distance,
            distance_unit=self.distance_unit,
            calories=self.active_energy_burned
        )

class CompactWorkoutGoals(BaseModel):
    current_goals: List[str] = []
    completed_goals: List[str] = []

class WorkoutGoal(BaseModel):
    id: str
    description: Optional[str]
    status: Optional[str]
    created_at: Optional[datetime]
    completed_at: Optional[datetime]

class WorkoutGoals(BaseModel):
    current_goals: List[WorkoutGoal] = []
    completed_goals: List[WorkoutGoal] = []

    def to_compact(self) -> CompactWorkoutGoals:
        return CompactWorkoutGoals(
            current_goals=[g.description for g in self.current_goals if g.description],
            completed_goals=[g.description for g in self.completed_goals if g.description]
        )

    def get_llm_view(self) -> str:
        view_lines = []
        if self.current_goals:
            view_lines.append("Current Goals:")
            view_lines.extend([f"- {g.description}" for g in self.current_goals if g.description])
        if self.completed_goals:
            view_lines.append("Completed Goals:")
            view_lines.extend([f"- {g.description} (Completed: {g.completed_at.date() if g.completed_at else 'N/A'})" for g in self.completed_goals if g.description])
        if not view_lines:
            return "No specific workout goals defined."
        return "\n".join(view_lines)

class CompactWorkoutMemory(BaseModel):
    recent_workouts: List[CompactWorkout] = []
    workout_goals: CompactWorkoutGoals

class WorkoutMemory(CompactWorkoutMemory):
    user_id: str
    last_updated: datetime
    recent_workouts: List[RecentWorkout] = Field(default_factory=list)
    workout_goals: WorkoutGoals = Field(default_factory=WorkoutGoals)

    def to_compact(self) -> CompactWorkoutMemory:
        return CompactWorkoutMemory(
            recent_workouts=[w.to_compact() for w in self.recent_workouts],
            workout_goals=self.workout_goals.to_compact()
        )

    def get_llm_view(self, now: datetime = None) -> str:
        if now is None:
            now = datetime.now()
        if not self.recent_workouts:
            return "=== Workout History ===\nNo workout history available."

        workouts_by_period = {
            "last_30_days": [],
            "last_year_quarterly": defaultdict(list),  # Key: YYYY-Qx (quarterly for most recent year)
            "second_year": []  # All workouts from the second year as a whole
        }
        sorted_workouts = sorted(self.recent_workouts, key=lambda w: w.start_date or datetime.min, reverse=True)

        for workout in sorted_workouts:
            if not workout.start_date: continue
            days_ago = get_time_ago(workout.start_date, now).days
            workout_date = workout.start_date.date()

            if days_ago <= 30:
                workouts_by_period["last_30_days"].append(workout)
            elif days_ago <= 365:
                # Quarterly for the most recent year (excluding last 30 days)
                quarter = (workout_date.month - 1) // 3 + 1
                quarter_key = f"{workout_date.year}-Q{quarter}"
                workouts_by_period["last_year_quarterly"][quarter_key].append(workout)
            elif days_ago <= 2 * 365:
                # Second year as a whole
                workouts_by_period["second_year"].append(workout)
            # Data older than 2 years is omitted entirely

        view_lines = ["=== Workout History ==="]
        view_lines.append("-- Recent Workouts (Last 30 Days) --")
        if workouts_by_period["last_30_days"]:
            for w in workouts_by_period["last_30_days"]:
                date_str = w.start_date.strftime('%Y-%m-%d') if w.start_date else "N/A"
                # Use original_type field if available, otherwise fallback to workout_type
                type_str = w.original_type or w.workout_type or "Workout"
                duration_str = format_duration(w.duration_seconds)
                distance_str = format_distance(w.distance, w.distance_unit)
                hr_str = format_hr(w.heart_rate_summary)
                calories_str = f"{int(w.active_energy_burned)} {w.active_energy_burned_unit or 'kcal'}" if w.active_energy_burned else "Calories N/A"
                view_lines.append(f"- {date_str}: {type_str} ({duration_str}, {distance_str}, {hr_str}, {calories_str})")
        else:
            view_lines.append("  No workouts recorded in the last 30 days.")

        view_lines.append("\n-- Recent Year (Quarterly Summary) --")
        if workouts_by_period["last_year_quarterly"]:
            # Sort quarter keys in reverse chronological order (newest first)
            sorted_quarters = sorted(workouts_by_period["last_year_quarterly"].keys(), reverse=True)
            for quarter_key in sorted_quarters:
                workouts = workouts_by_period["last_year_quarterly"][quarter_key]
                view_lines.append(f"  {quarter_key}:")
                summary = self._summarize_period(workouts)
                view_lines.extend([f"    - {line}" for line in summary])
        else:
            view_lines.append("  No workouts recorded in the recent year (beyond 30 days).")

        # Get the year for the second year summary
        second_year_date = None
        if workouts_by_period["second_year"] and len(workouts_by_period["second_year"]) > 0:
            # Find the most recent workout in the second year to get the year
            second_year_workouts = sorted(workouts_by_period["second_year"],
                                         key=lambda w: w.start_date or datetime.min,
                                         reverse=True)
            if second_year_workouts and second_year_workouts[0].start_date:
                second_year_date = second_year_workouts[0].start_date.date()

        # Format the year for display
        year_str = f"Year {second_year_date.year}" if second_year_date else "Second Year"
        view_lines.append(f"\n-- {year_str} (Annual Summary) --")

        if workouts_by_period["second_year"]:
            summary = self._summarize_period(workouts_by_period["second_year"])
            view_lines.extend([f"  - {line}" for line in summary])
        else:
            view_lines.append("  No workouts recorded in the second year.")

        view_lines.append("\n-- Workout Goals --")
        view_lines.append(self.workout_goals.get_llm_view())

        return "\n".join(view_lines)

    def _summarize_period(self, workouts: List[RecentWorkout]) -> List[str]:
        if not workouts:
            return ["No workouts in this period."]
        summary_lines = [f"Total Workouts: {len(workouts)}"]
        by_type = defaultdict(list)
        for w in workouts:
            # Use original_type if available for type grouping
            type_key = w.original_type or w.workout_type or "Unknown"
            by_type[type_key].append(w)

        for workout_type, type_workouts in by_type.items():
            # Convert RUNNING_SAND to "Running" and make format more readable
            readable_type = ' '.join(word.capitalize() for word in workout_type.replace('_', ' ').split())
            summary_lines.append(f"  {readable_type} {len(type_workouts)} times:")

            distances = [w.distance for w in type_workouts if w.distance is not None]
            if distances:
                unit = next((w.distance_unit for w in type_workouts if w.distance_unit), "units")
                avg = statistics.mean(distances) if distances else 0
                min_val = min(distances) if distances else 0
                max_val = max(distances) if distances else 0
                summary_lines.append(f"    Distance: Avg: {avg:.1f}, Min: {min_val:.1f}, Max: {max_val:.1f} {unit}")

            durations = [w.duration_seconds for w in type_workouts if w.duration_seconds is not None]
            if durations:
                durations_min = [d/60 for d in durations]
                avg = statistics.mean(durations_min) if durations_min else 0
                min_val = min(durations_min) if durations_min else 0
                max_val = max(durations_min) if durations_min else 0
                summary_lines.append(f"    Duration: Avg: {avg:.1f}, Min: {min_val:.1f}, Max: {max_val:.1f} minutes")

            hrs = [w.heart_rate_summary['average'] for w in type_workouts if w.heart_rate_summary and 'average' in w.heart_rate_summary and w.heart_rate_summary['average'] is not None]
            if hrs:
                unit = next((w.heart_rate_summary.get('unit', 'bpm') for w in type_workouts if w.heart_rate_summary), "bpm")
                median = statistics.median(hrs) if hrs else 0
                summary_lines.append(f"    Heart Rate: {median:.0f} {unit} (median)")

            calories = [w.active_energy_burned for w in type_workouts if w.active_energy_burned is not None]
            if calories:
                unit = next((w.active_energy_burned_unit for w in type_workouts if w.active_energy_burned_unit), "kcal")
                avg = statistics.mean(calories) if calories else 0
                min_val = min(calories) if calories else 0
                max_val = max(calories) if calories else 0
                summary_lines.append(f"    Calories Burned: Avg: {avg:.1f}, Min: {min_val:.1f}, Max: {max_val:.1f} {unit}")

        # Remove the initial 'Total Workouts' line if there are type breakdowns
        if len(summary_lines) > 1:
            return summary_lines[1:] # Return only the per-type summaries
        return summary_lines # Should only happen if only one type of workout

class CompactActivity(BaseModel):
    date: date
    steps: int = 0
    distance: float = 0.0
    distance_unit: str = "km"
    active_energy_burned: float = 0.0
    exercise_minutes: int = 0

class Activity(CompactActivity):
    date: datetime
    floors_climbed: int = 0
    active_energy_burned_unit: str = "kcal"
    move_minutes: int = 0
    source: str = "Apple Health"

    def to_compact(self) -> CompactActivity:
        return CompactActivity(
            date=self.date.date(),
            steps=self.steps,
            distance=self.distance,
            distance_unit=self.distance_unit,
            active_energy_burned=self.active_energy_burned,
            exercise_minutes=self.exercise_minutes
        )

class CompactActivities(BaseModel):
    activities: List[CompactActivity] = []

class Activities(CompactActivities):
    activities: List[Activity] = Field(default_factory=list)

    def to_compact(self) -> CompactActivities:
        return CompactActivities(
            activities=[a.to_compact() for a in self.activities]
        )

    def get_llm_view(self, now: datetime = None) -> str:
        if now is None:
             now = datetime.now()
        if not self.activities:
             return "=== Activity Summary ===\nNo activity data available."

        sorted_activities = sorted(self.activities, key=lambda a: a.date, reverse=True)

        # Filter for days that have step data and deduplicate by date
        # Use set to track unique days to avoid counting duplicates
        days_with_data = []
        unique_dates = set()

        for activity in sorted_activities:
            if (isinstance(activity.date, (datetime, date)) and
                activity.steps is not None and
                activity.steps > 0):

                # Create a date string in YYYY-MM-DD format for deduplication
                if isinstance(activity.date, datetime):
                    date_str = activity.date.date().isoformat()
                else:
                    date_str = activity.date.isoformat()

                # Only add if we haven't seen this date before
                if date_str not in unique_dates:
                    unique_dates.add(date_str)
                    days_with_data.append(activity)

        if not days_with_data:
            return "=== Activity Summary ===\nNo step data available."

        # Calculate strict date ranges (exactly 7, 30, 365 days from now)
        today = now.date()
        date_7days_ago = today - timedelta(days=7)
        date_30days_ago = today - timedelta(days=30)
        date_365days_ago = today - timedelta(days=365)

        # Get activities within each strict date range
        last_7_days_stats = [a for a in days_with_data
                             if (isinstance(a.date, datetime) and a.date.date() > date_7days_ago)
                             or (isinstance(a.date, date) and not isinstance(a.date, datetime) and a.date > date_7days_ago)]

        last_30_days_stats = [a for a in days_with_data
                              if (isinstance(a.date, datetime) and a.date.date() > date_30days_ago)
                              or (isinstance(a.date, date) and not isinstance(a.date, datetime) and a.date > date_30days_ago)]

        last_365_days_stats = [a for a in days_with_data
                               if (isinstance(a.date, datetime) and a.date.date() > date_365days_ago)
                               or (isinstance(a.date, date) and not isinstance(a.date, datetime) and a.date > date_365days_ago)]

        # Calculate averages and counts
        avg_steps_7d = statistics.mean([a.steps for a in last_7_days_stats]) if last_7_days_stats else 0
        avg_cals_7d = statistics.mean([a.active_energy_burned for a in last_7_days_stats if a.active_energy_burned is not None]) if last_7_days_stats else 0
        avg_exer_7d = statistics.mean([a.exercise_minutes for a in last_7_days_stats if a.exercise_minutes is not None]) if last_7_days_stats else 0

        active_days_30d = sum(1 for a in last_30_days_stats if a.steps > 5000)
        avg_steps_30d = statistics.mean([a.steps for a in last_30_days_stats]) if last_30_days_stats else 0

        avg_steps_365d = statistics.mean([a.steps for a in last_365_days_stats]) if last_365_days_stats else 0
        total_active_days_365d = sum(1 for a in last_365_days_stats if a.steps > 5000)
        avg_exer_365d = statistics.mean([a.exercise_minutes for a in last_365_days_stats if a.exercise_minutes is not None]) if last_365_days_stats else 0

        view_lines = ["=== Activity Summary ==="]

        # Last 7 Days Summary
        view_lines.append("-- Last 7 Days Avg --")
        if last_7_days_stats:
             view_lines.append(f"  Steps/Day: {int(avg_steps_7d)}")
             view_lines.append(f"  Active Cal/Day: {int(avg_cals_7d)}")
             view_lines.append(f"  Exercise Min/Day: {int(avg_exer_7d)}")
             view_lines.append(f"  Days with Data: {len(last_7_days_stats)}/7")
        else:
             view_lines.append("  No activity data.")

        # Last 30 Days Summary
        view_lines.append("\n-- Last 30 Days --")
        if last_30_days_stats:
             view_lines.append(f"  Active Days (>5k steps): {active_days_30d}")
             view_lines.append(f"  Avg Steps/Day: {int(avg_steps_30d)}")
             view_lines.append(f"  Days with Data: {len(last_30_days_stats)}/30")
        else:
             view_lines.append("  No activity data.")

        # Last 365 Days Summary
        view_lines.append("\n-- Last 365 Days --")
        if last_365_days_stats:
            view_lines.append(f"  Avg Steps/Day: {int(avg_steps_365d)}")
            view_lines.append(f"  Total Active Days (>5k steps): {total_active_days_365d}")
            view_lines.append(f"  Avg Exercise Min/Day: {int(avg_exer_365d)}")
            view_lines.append(f"  Days with Data: {len(last_365_days_stats)}/365")
        else:
             view_lines.append("  No activity data.")

        return "\n".join(view_lines)

class CompactBodyComposition(BaseModel):
    weight: Optional[Dict[str, Any]] = None
    body_fat_percentage: Optional[Dict[str, Any]] = None

class BodyComposition(CompactBodyComposition):
    weight_readings: List[Dict[str, Any]] = Field(default_factory=list, description="List of {'value': float, 'unit': str, 'date': datetime}")
    bmi_readings: List[Dict[str, Any]] = Field(default_factory=list)
    body_fat_percentage_readings: List[Dict[str, Any]] = Field(default_factory=list)

    # Legacy format support
    weight: Optional[Dict[str, Any]] = None
    bmi: Optional[Dict[str, Any]] = None
    body_fat_percentage: Optional[Dict[str, Any]] = None

    def _summarize_biometric_period(self, readings: List[Dict[str, Any]], is_body_fat: bool = False) -> str:
        if not readings:
            return "N/A"
        values = [r['value'] for r in readings if 'value' in r]
        unit = readings[0].get('unit', '') if readings else ''

        # Format body fat as actual percentages
        if is_body_fat:
            # Determine if values need to be multiplied by 100 (if they're in decimal form)
            need_conversion = all(v < 1.0 for v in values if isinstance(v, (int, float)))
            values = [v * 100 if need_conversion and isinstance(v, (int, float)) else v for v in values]
            unit = '%'  # Always use % symbol for body fat

        # Calculate statistics
        count = len(values)
        avg = statistics.mean(values) if count > 0 else 0
        min_val = min(values) if count > 0 else 0
        max_val = max(values) if count > 0 else 0

        return f"Count: {count}, Avg: {avg:.1f}, Min: {min_val:.1f}, Max: {max_val:.1f} {unit}".strip()

    def get_llm_view(self, now: datetime = None) -> str:
        if now is None:
            now = datetime.now()
        view_lines = []

        # Transform legacy format to readings format if needed
        self._transform_legacy_data()

        metrics = {
            "Weight": self.weight_readings,
            "Body Fat %": self.body_fat_percentage_readings,
            "BMI": self.bmi_readings
        }
        has_data = any(metrics.values())
        if not has_data:
            return "" # Return empty string if no body comp data

        view_lines.append("--- Body Composition ---")
        for name, readings_list in metrics.items():
            if not readings_list: continue

            is_body_fat = name == "Body Fat %"
            sorted_readings = sorted(readings_list, key=lambda r: r['date'] if isinstance(r.get('date'), (datetime, date)) else datetime.min, reverse=True)
            periods = {
                "last_30_days": [],
                "last_year_quarterly": defaultdict(list),  # Key: YYYY-Qx (quarterly for most recent year)
                "second_year": []  # All readings from the second year as a whole
            }
            for reading in sorted_readings:
                if not isinstance(reading.get('date'), (datetime, date)): continue # Skip if date is invalid
                reading_date = reading['date'] if isinstance(reading['date'], date) else reading['date'].date()
                days_ago = get_time_ago(reading_date, now).days

                if days_ago <= 30:
                    periods["last_30_days"].append(reading)
                elif days_ago <= 365:
                    # Quarterly for the most recent year (excluding last 30 days)
                    quarter = (reading_date.month - 1) // 3 + 1
                    quarter_key = f"{reading_date.year}-Q{quarter}"
                    periods["last_year_quarterly"][quarter_key].append(reading)
                elif days_ago <= 2 * 365:
                    # Second year as a whole
                    periods["second_year"].append(reading)
                # Data older than 2 years is omitted entirely

            view_lines.append(f"  {name}:")
            if periods["last_30_days"]:
                view_lines.append("    Last 30 Days:")
                for r in periods["last_30_days"]:
                    date_str = (r['date'].strftime('%Y-%m-%d') if isinstance(r.get('date'), (datetime, date)) else "Invalid Date")
                    unit = r.get('unit', '')

                    # Format body fat as actual percentages
                    if is_body_fat:
                        value = r.get('value', 0)
                        # Convert decimal values to percentages
                        if isinstance(value, (int, float)) and value < 1.0:
                            value = value * 100
                        value_str = f"{value:.1f}%" if isinstance(value, (int, float)) else "N/A"
                    else:
                        value_str = f"{r['value']:.1f}" if isinstance(r.get('value'), (int, float)) else "N/A"
                        if unit:
                            value_str += f" {unit}"

                    view_lines.append(f"    - {date_str}: {value_str}")

            # Sort period keys in reverse chronological order for quarterly periods
            if periods["last_year_quarterly"]:
                view_lines.append("    Recent Year (Quarterly Avg):")
                # Sort quarter keys in reverse chronological order (newest first)
                sorted_quarters = sorted(periods["last_year_quarterly"].keys(), reverse=True)
                for quarter_key in sorted_quarters:
                    readings = periods["last_year_quarterly"][quarter_key]
                    summary = self._summarize_biometric_period(readings, is_body_fat)
                    if summary != "N/A": view_lines.append(f"    - {quarter_key}: {summary}")

            # Add second year summary as a whole
            if periods["second_year"]:
                # Get the year for the second year summary
                second_year_date = None
                if len(periods["second_year"]) > 0:
                    # Find the most recent reading in the second year to get the year
                    second_year_readings = sorted(periods["second_year"],
                                                key=lambda r: r['date'] if isinstance(r.get('date'), (datetime, date)) else datetime.min,
                                                reverse=True)
                    if second_year_readings and isinstance(second_year_readings[0].get('date'), (datetime, date)):
                        reading_date = second_year_readings[0]['date']
                        second_year_date = reading_date if isinstance(reading_date, date) and not isinstance(reading_date, datetime) else reading_date.date()

                # Format the year for display
                year_str = f"Year {second_year_date.year}" if second_year_date else "Second Year"
                view_lines.append(f"    {year_str} (Annual Avg):")

                summary = self._summarize_biometric_period(periods["second_year"], is_body_fat)
                if summary != "N/A": view_lines.append(f"    - {summary}")

            # Add a placeholder if no data was displayed for this metric
            if not any(p for p in periods.values() if p):
                 view_lines.append("    No recent data.")

        return "\n".join(view_lines)

    def _transform_legacy_data(self):
        """Transform legacy data format to readings format."""
        # Convert weight history to weight_readings if available
        if self.weight and not self.weight_readings:
            history = self.weight.get('history', [])
            if isinstance(history, list) and history and not self.weight_readings:
                self.weight_readings = [
                    {'value': entry.get('value'),
                     'date': datetime.fromisoformat(entry.get('timestamp').replace('Z', '+00:00')) if entry.get('timestamp') else None,
                     'unit': entry.get('unit', 'kg')}
                    for entry in history if entry.get('value') and entry.get('timestamp')
                ]

        # Convert body fat percentage history to body_fat_percentage_readings if available
        if self.body_fat_percentage and not self.body_fat_percentage_readings:
            history = self.body_fat_percentage.get('history', [])
            if isinstance(history, list) and history and not self.body_fat_percentage_readings:
                self.body_fat_percentage_readings = [
                    {'value': entry.get('value'),
                     'date': datetime.fromisoformat(entry.get('timestamp').replace('Z', '+00:00')) if entry.get('timestamp') else None,
                     'unit': entry.get('unit', '%')}
                    for entry in history if entry.get('value') and entry.get('timestamp')
                ]

        # Convert BMI history to bmi_readings if available
        if self.bmi and not self.bmi_readings:
            history = self.bmi.get('history', [])
            if isinstance(history, list) and history and not self.bmi_readings:
                self.bmi_readings = [
                    {'value': entry.get('value'),
                     'date': datetime.fromisoformat(entry.get('timestamp').replace('Z', '+00:00')) if entry.get('timestamp') else None,
                     'unit': entry.get('unit', 'kg/m²')}
                    for entry in history if entry.get('value') and entry.get('timestamp')
                ]

class CompactBiometrics(BaseModel):
    body_composition: CompactBodyComposition

class Biometrics(CompactBiometrics):
    body_composition: BodyComposition = BodyComposition()
    resting_heart_rate_readings: List[Dict[str, Any]] = Field(default_factory=list)
    sleep_analysis_readings: List[Dict[str, Any]] = Field(default_factory=list)

    def to_compact(self) -> CompactBiometrics:
        return CompactBiometrics(
            body_composition=self.body_composition.to_compact()
        )

    def _summarize_other_biometric(self, readings: List[Dict[str, Any]], unit_default: str) -> str:
        if not readings: return "N/A"
        values = [r['value'] for r in readings if 'value' in r and isinstance(r['value'], (int, float))]
        if not values: return "N/A"
        unit = readings[0].get('unit', unit_default) if readings else unit_default
        summary = summarize_values(values)
        return f"{summary} {unit}".strip()

    def get_llm_view(self, now: datetime = None) -> str:
        if now is None: now = datetime.now()
        view_lines = ["=== Biometrics ==="]

        bc_view = self.body_composition.get_llm_view(now)

        if bc_view:
            view_lines.append(bc_view) # Appends the "--- Body Composition ---" section

        # Resting Heart Rate (Simplified - Just Latest & 7d Avg)
        if self.resting_heart_rate_readings:
            view_lines.append("\n--- Resting Heart Rate ---")
            sorted_rhr = sorted([r for r in self.resting_heart_rate_readings if isinstance(r.get('date'), (datetime, date))], key=lambda x: x['date'], reverse=True)
            if sorted_rhr:
                 latest_rhr = sorted_rhr[0]
                 date_str = latest_rhr['date'].strftime('%Y-%m-%d')
                 unit = latest_rhr.get('unit', 'bpm')
                 value_str = f"{latest_rhr['value']:.0f}" if isinstance(latest_rhr.get('value'), (int, float)) else "N/A"
                 view_lines.append(f"  Latest ({date_str}): {value_str} {unit}")

                 last_7d_rhr = [r for r in sorted_rhr if get_time_ago(r['date'], now).days <= 7]
                 avg_7d = self._summarize_other_biometric(last_7d_rhr, 'bpm')
                 if avg_7d != "N/A": view_lines.append(f"  Avg (Last 7d): {avg_7d}")
            else:
                 view_lines.append("  No valid RHR data.")

        # Sleep Analysis (Simplified - Just 7d Avg)
        if self.sleep_analysis_readings:
             view_lines.append("\n--- Sleep Analysis (Last 7 Days Avg) ---")
             recent_sleep = [r for r in self.sleep_analysis_readings if isinstance(r.get('date'), (datetime, date)) and get_time_ago(r['date'], now).days <= 7]
             if recent_sleep:
                 asleep_readings = [r for r in recent_sleep if r.get('type') == 'asleep']
                 in_bed_readings = [r for r in recent_sleep if r.get('type') == 'inBed']
                 avg_asleep = self._summarize_other_biometric(asleep_readings, 'hours')
                 avg_in_bed = self._summarize_other_biometric(in_bed_readings, 'hours')
                 if avg_asleep != "N/A": view_lines.append(f"  Time Asleep: {avg_asleep}")
                 if avg_in_bed != "N/A": view_lines.append(f"  Time in Bed: {avg_in_bed}")
                 if avg_asleep == "N/A" and avg_in_bed == "N/A": view_lines.append("  No sleep data found for last 7 days.")
             else:
                 view_lines.append("  No sleep data found for last 7 days.")

        # If only the header is present, return nothing
        if len(view_lines) == 1 and not bc_view:
            return ""

        return "\n".join(view_lines)


class CompactDemographics(BaseModel):
    age: Optional[int] = None
    gender: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None

class Demographics(CompactDemographics):
    blood_type: Optional[str] = None

    def to_compact(self) -> CompactDemographics:
        return CompactDemographics(
            age=self.age, gender=self.gender, height=self.height, weight=self.weight
        )

class Goal(BaseModel):
    id: str
    description: str
    category: Optional[str] = None
    target_date: Optional[date] = None
    status: str = "active"
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

class Goals(BaseModel):
    fitness: List[Goal] = []
    nutrition: List[Goal] = []
    wellbeing: List[Goal] = []
    other: List[Goal] = []

    def to_compact(self) -> Dict[str, List[str]]:
        return {
            "fitness": [g.description for g in self.fitness if g.description],
            "nutrition": [g.description for g in self.nutrition if g.description],
            "wellbeing": [g.description for g in self.wellbeing if g.description],
            "other": [g.description for g in self.other if g.description]
        }

    def get_llm_view(self) -> str:
        view_lines = []
        categories = {"Fitness": self.fitness, "Nutrition": self.nutrition, "Wellbeing": self.wellbeing, "Other": self.other}
        has_goals = False
        for category, goals_list in categories.items():
            active_goals = [g for g in goals_list if g.status == 'active' and g.description]
            completed_goals = [g for g in goals_list if g.status == 'completed' and g.description]
            if active_goals or completed_goals:
                if not has_goals: # Add header only if there are any goals
                     view_lines.append("--- User Goals ---")
                     has_goals = True
                view_lines.append(f"  {category}:")
                if active_goals:
                    view_lines.append("    Current:")
                    view_lines.extend([f"    - {g.description}{f' (Target: {g.target_date})' if g.target_date else ''}" for g in active_goals])
                if completed_goals:
                     view_lines.append("    Completed:")
                     view_lines.extend([f"    - {g.description} (Completed: {g.completed_at.date() if g.completed_at else 'N/A'})" for g in completed_goals])
        if not has_goals:
            return "--- User Goals ---\n  No specific goals defined."
        return "\n".join(view_lines)

# =============================================
# Define MedicalHistory and Preferences FIRST
# =============================================

class MedicalCondition(BaseModel):
    name: str = ""
    condition_type: str = "condition"  # condition, medication, allergy
    diagnosed_date: Optional[date] = None
    status: str = "template"  # active, resolved, managed, template, etc.
    feeling: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    purpose: Optional[str] = None
    notes: Optional[str] = None

class CompactMedicalHistory(BaseModel):
    conditions: List[MedicalCondition] = []

    @classmethod
    def example(cls) -> 'CompactMedicalHistory':
        # ... (example implementation - keep as is) ...
        return cls(conditions=[]) # Simplified for brevity

class MedicalHistory(CompactMedicalHistory):
    user_id: Optional[str] = None
    last_updated: Optional[datetime] = None
    conditions: List[MedicalCondition] = Field(default_factory=list)

    def to_compact(self) -> CompactMedicalHistory:
        valid_conditions = [c for c in self.conditions if c.status != "template" and c.name]
        if not valid_conditions:
             return CompactMedicalHistory(conditions=[])
        return CompactMedicalHistory(conditions=valid_conditions)

    def get_llm_view(self) -> str:
        view_lines = ["=== Medical History ==="]
        valid_conditions = [c for c in self.conditions if c.status != "template" and c.name]
        if not valid_conditions:
             view_lines.append("No significant medical history provided.")
             return "\n".join(view_lines)

        conditions = sorted([c for c in valid_conditions if c.condition_type == 'condition'], key=lambda x: x.name)
        medications = sorted([c for c in valid_conditions if c.condition_type == 'medication'], key=lambda x: x.name)
        allergies = sorted([c for c in valid_conditions if c.condition_type == 'allergy'], key=lambda x: x.name)

        if conditions:
            view_lines.append("-- Conditions --")
            for c in conditions:
                details = [f"Status: {c.status}"]
                if c.diagnosed_date: details.append(f"Diagnosed: {c.diagnosed_date}")
                if c.feeling: details.append(f"Feeling: {c.feeling}")
                if c.notes: details.append(f"Notes: {c.notes}")
                view_lines.append(f"- {c.name} ({', '.join(details)})")
        if medications:
            view_lines.append("-- Medications --")
            for m in medications:
                details = [f"Status: {m.status}"]
                if m.dosage: details.append(f"Dosage: {m.dosage}")
                if m.frequency: details.append(f"Frequency: {m.frequency}")
                if m.purpose: details.append(f"Purpose: {m.purpose}")
                if m.start_date: details.append(f"Started: {m.start_date}")
                if m.end_date: details.append(f"Ended: {m.end_date}")
                if m.notes: details.append(f"Notes: {m.notes}")
                view_lines.append(f"- {m.name} ({', '.join(details)})")
        if allergies:
            view_lines.append("-- Allergies --")
            for a in allergies:
                details = [f"Status: {a.status}"]
                if a.notes: details.append(f"Notes: {a.notes}")
                view_lines.append(f"- {a.name} ({', '.join(details)})")
        # Add a line if no conditions of a type were found but the list wasn't empty
        if not conditions and valid_conditions: view_lines.append("-- Conditions: None reported --")
        if not medications and valid_conditions: view_lines.append("-- Medications: None reported --")
        if not allergies and valid_conditions: view_lines.append("-- Allergies: None reported --")

        return "\n".join(view_lines)

class Preferences(BaseModel):
    liked_activities: List[str] = Field(default_factory=list)
    disliked_activities: List[str] = Field(default_factory=list)
    preferred_time_of_day: List[str] = Field(default_factory=list)
    preferred_days: List[str] = Field(default_factory=list)
    preferred_locations: List[str] = Field(default_factory=list)
    availability_notes: Optional[str] = None
    other_notes: Optional[str] = None

    def get_llm_view(self) -> str:
        view_lines = ["=== Preferences ==="]
        if self.liked_activities: view_lines.append(f"Likes: {', '.join(self.liked_activities)}")
        if self.disliked_activities: view_lines.append(f"Dislikes: {', '.join(self.disliked_activities)}")
        if self.preferred_time_of_day: view_lines.append(f"Preferred Times: {', '.join(self.preferred_time_of_day)}")
        if self.preferred_days: view_lines.append(f"Preferred Days: {', '.join(self.preferred_days)}")
        if self.preferred_locations: view_lines.append(f"Preferred Locations: {', '.join(self.preferred_locations)}")
        if self.availability_notes: view_lines.append(f"Availability Notes: {self.availability_notes}")
        if self.other_notes: view_lines.append(f"Other Notes: {self.other_notes}")
        if len(view_lines) == 1: # Only the header
            return "=== Preferences ===\nNo specific preferences set."
        return "\n".join(view_lines)


# =============================================
# UserProfile Definition (depends on above)
# =============================================

class CompactUserProfile(BaseModel):
    name: Optional[str] = None
    demographics: Optional[CompactDemographics] = None
    goals: Optional[Dict[str, List[str]]] = None

class UserProfile(CompactUserProfile):
    user_id: str
    name: Optional[str] = None
    email: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    demographics: Demographics = Field(default_factory=Demographics)
    goals: Goals = Field(default_factory=Goals)
    medical_history: MedicalHistory = Field(default_factory=MedicalHistory)
    preferences: Preferences = Field(default_factory=Preferences)

    def to_compact(self) -> CompactUserProfile:
        demographics_compact = self.demographics.to_compact() if any([
            self.demographics.age, self.demographics.gender,
            self.demographics.height, self.demographics.weight
        ]) else None
        goals_compact = self.goals.to_compact() if any(self.goals.model_dump().values()) else None
        return CompactUserProfile(
            name=self.name, demographics=demographics_compact, goals=goals_compact
        )

    def get_llm_view(self) -> str:
        view_lines = ["=== User Profile ==="]
        # Demographics
        demo = self.demographics
        view_lines.append("--- Demographics ---")
        view_lines.append(f"  Age: {demo.age or 'N/A'}")
        view_lines.append(f"  Gender: {demo.gender or 'N/A'}")
        view_lines.append(f"  Height: {f'{demo.height} cm' if demo.height else 'N/A'}")
        view_lines.append(f"  Weight: {f'{demo.weight} kg' if demo.weight else 'N/A'}")
        view_lines.append(f"  Blood Type: {demo.blood_type or 'N/A'}")
        # Medical History, Preferences, Goals (use their views)
        view_lines.append("\n" + self.medical_history.get_llm_view())
        view_lines.append("\n" + self.preferences.get_llm_view())
        view_lines.append("\n" + self.goals.get_llm_view()) # Includes --- User Goals --- header
        return "\n".join(view_lines)


# =============================================
# Rest of the classes
# =============================================

class WorkoutExercise(BaseModel):
    name: str
    sets: Optional[int] = None
    reps: Optional[int] = None
    duration: Optional[int] = None
    duration_unit: Optional[str] = "seconds"
    weight: Optional[float] = None
    weight_unit: Optional[str] = "kg"
    notes: Optional[str] = None

class WorkoutDay(BaseModel):
    day: str
    focus: Optional[str] = None
    exercises: List[WorkoutExercise] = []
    notes: Optional[str] = None

class CompactWorkoutPlan(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    days: List[WorkoutDay] = []

    @classmethod
    def example(cls) -> 'CompactWorkoutPlan':
        # ... (example implementation - keep as is) ...
         return cls(name="Example Plan", days=[]) # Simplified for brevity

class WorkoutPlan(CompactWorkoutPlan):
    id: Optional[str] = None
    user_id: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    active: bool = True

    def to_compact(self) -> CompactWorkoutPlan:
        return CompactWorkoutPlan(
            name=self.name, description=self.description,
            start_date=self.start_date, end_date=self.end_date, days=self.days
        )

    def get_llm_view(self) -> str:
        # Simple view for workout plan
        if not self.name and not self.days:
            return "=== Current Workout Plan ===\nNo active workout plan defined."
        view_lines = ["=== Current Workout Plan ==="]
        view_lines.append(f"Name: {self.name or 'Unnamed Plan'}")
        if self.description: view_lines.append(f"Description: {self.description}")
        if self.start_date: view_lines.append(f"Start Date: {self.start_date}")
        if self.end_date: view_lines.append(f"End Date: {self.end_date}")
        view_lines.append(f"Focus: {len(self.days)} workout days defined.")
        # Optionally list day focuses
        if self.days:
             view_lines.append("Days:")
             view_lines.extend([f"  - {d.day}: {d.focus or 'General'}" for d in self.days])
        return "\n".join(view_lines)

class ChatMessage(BaseModel):
    sender: str
    content: str
    timestamp: datetime = Field(default_factory=datetime.now)
    message_type: str = "text"
    metadata: Optional[Dict[str, Any]] = None

class CompactChatHistory(BaseModel):
    conversations: List[Dict[str, Any]] = []
    last_interaction: Optional[datetime] = None

    @classmethod
    def example(cls) -> 'CompactChatHistory':
         # ... (example implementation - keep as is) ...
         return cls(conversations=[]) # Simplified for brevity

class ChatHistory(CompactChatHistory):
    user_id: Optional[str] = None

    def to_compact(self) -> CompactChatHistory:
        recent_conversations = self.conversations[-10:]
        return CompactChatHistory(
            conversations=recent_conversations, last_interaction=self.last_interaction
        )


# =============================================
# Overall Memory Schema
# =============================================

# Add Sleep and Nutrition Schemas here

class SleepStageData(BaseModel):
    """Data for a single sleep stage"""
    stage_type: str # Using string, could be Enum later e.g., SleepStageEnum
    start_date: datetime
    end_date: datetime
    duration_minutes: Optional[float] = None # Keep optional for flexibility

class SleepEntry(BaseModel):
    """Represents a single sleep session."""
    id: Optional[str] = None
    start_date: datetime
    end_date: datetime
    duration_seconds: Optional[float] = None # Make optional, calculate if needed
    source: Optional[str] = "Apple Health" # Default source
    sleep_stages: Optional[List[SleepStageData]] = Field(default_factory=list)
    heart_rate_average: Optional[float] = None
    heart_rate_min: Optional[float] = None
    heart_rate_max: Optional[float] = None
    respiratory_rate_average: Optional[float] = None
    notes: Optional[str] = None
    # Additional fields that might be useful internally or from source data
    duration_minutes: Optional[float] = None
    asleep_minutes: Optional[float] = None
    awake_minutes: Optional[float] = None
    in_bed_minutes: Optional[float] = None
    sleep_efficiency: Optional[float] = None

    @field_validator('end_date')
    def end_date_after_start_date(cls, v, info):
        data = info.data
        if 'start_date' in data and v < data['start_date']:
            raise ValueError('end_date must be after start_date')
        return v

    @root_validator(pre=False, skip_on_failure=True)
    def calculate_durations(cls, values):
        start = values.get('start_date')
        end = values.get('end_date')
        if start and end:
            duration = end - start
            if values.get('duration_seconds') is None:
                values['duration_seconds'] = duration.total_seconds()
            if values.get('duration_minutes') is None:
                 values['duration_minutes'] = duration.total_seconds() / 60
        # Could add calculations for asleep/awake/in_bed if stages are present
        return values

class SleepAnalysis(BaseModel):
    """Holds a list of sleep sessions for a user."""
    sleep_sessions: List[SleepEntry] = Field(default_factory=list)
    last_updated: Optional[datetime] = None

class NutritionEntry(BaseModel):
    """Represents a single nutrition entry (e.g., a meal or food item)."""
    id: Optional[str] = None
    date: datetime
    meal_type: Optional[str] = None
    food_name: str
    calories: Optional[float] = None
    protein_grams: Optional[float] = None
    carbohydrates_grams: Optional[float] = None
    fat_grams: Optional[float] = None
    fiber_grams: Optional[float] = None
    sugar_grams: Optional[float] = None
    sodium_milligrams: Optional[float] = None
    serving_size: Optional[float] = None
    serving_unit: Optional[str] = None
    source: Optional[str] = "Manual Entry"
    notes: Optional[str] = None

class NutritionLog(BaseModel):
    """Holds a list of nutrition entries for a user."""
    nutrition_entries: List[NutritionEntry] = Field(default_factory=list)
    last_updated: Optional[datetime] = None


class CompactOverallMemory(BaseModel):
    workout_memory: Optional[CompactWorkoutMemory] = None
    activities: Optional[CompactActivities] = None
    biometrics: Optional[CompactBiometrics] = None
    user_profile: Optional[CompactUserProfile] = None
    workout_plan: Optional[CompactWorkoutPlan] = None
    medical_history: Optional[CompactMedicalHistory] = None # Kept for potential backward compatibility if needed
    chat_history: Optional[CompactChatHistory] = None

class OverallMemory(BaseModel):
    user_info: Optional[UserInfo] = None
    user_profile: Optional[UserProfile] = None
    workout_memory: WorkoutMemory = Field(default_factory=WorkoutMemory)
    activities: Activities = Field(default_factory=Activities)
    biometrics: Biometrics = Field(default_factory=Biometrics)
    workout_plan: WorkoutPlan = Field(default_factory=WorkoutPlan)
    chat_history: ChatHistory = Field(default_factory=ChatHistory)

    @root_validator(pre=True)
    def ensure_user_profile_and_defaults(cls, values):
        user_profile_data = values.get('user_profile')
        user_info_data = values.get('user_info')
        passed_user_id = values.get('_passed_user_id')
        now = datetime.now()

        for key in ['activities', 'biometrics', 'workout_memory', 'chat_history', 'workout_plan']: # Add other keys if needed
             component_data = values.get(key)
             if isinstance(component_data, list): # Check if it was loaded as a list
                  inner_list_key = key # Default assumption
                  if key == 'medical_history': inner_list_key = 'conditions' # Example override
                  values[key] = { inner_list_key: component_data }

        user_id = None
        if user_profile_data and isinstance(user_profile_data, dict) and user_profile_data.get('user_id'):
            user_id = user_profile_data['user_id']
        elif user_info_data and isinstance(user_info_data, dict) and user_info_data.get('user_id'):
            user_id = user_info_data['user_id']
        elif passed_user_id:
            user_id = passed_user_id

        if user_profile_data and isinstance(user_profile_data, dict):
            if user_id and 'user_id' not in user_profile_data:
                 user_profile_data['user_id'] = user_id
            if 'created_at' not in user_profile_data: user_profile_data['created_at'] = now
            if 'updated_at' not in user_profile_data: user_profile_data['updated_at'] = now
            if 'medical_history' in values and 'medical_history' not in user_profile_data:
                 mh_val = values.pop('medical_history')
                 if isinstance(mh_val, list):
                      user_profile_data['medical_history'] = {'conditions': mh_val}
                 else:
                      user_profile_data['medical_history'] = mh_val

        elif user_profile_data is None and user_id:
             user_profile_data = {"user_id": user_id, "created_at": now, "updated_at": now}
        values['user_profile'] = user_profile_data

        if 'workout_memory' not in values and user_id:
             values['workout_memory'] = { "user_id": user_id, "last_updated": now }
        elif 'workout_memory' in values and isinstance(values['workout_memory'], dict):
             if user_id and 'user_id' not in values['workout_memory']:
                  values['workout_memory']['user_id'] = user_id
             if 'last_updated' not in values['workout_memory']:
                   values['workout_memory']['last_updated'] = now

        if '_passed_user_id' in values:
             del values['_passed_user_id']

        return values

    @classmethod
    def from_user_dir(cls, user_dir: str, user_id_from_caller: str) -> 'OverallMemory':
        import os
        import json
        memory_components = {}
        files_found = False

        if not os.path.isdir(user_dir):
             return cls.model_validate({'_passed_user_id': user_id_from_caller})

        for fname in os.listdir(user_dir):
            if fname.endswith('.json'):
                files_found = True
                path = os.path.join(user_dir, fname)
                try:
                    with open(path, 'r') as f:
                        component_name = fname.replace('.json', '')
                        data = json.load(f)

                        if component_name == 'workout_memory' and 'recent_workouts' in data:
                            for workout in data['recent_workouts']:
                                if 'workout_type' in workout and workout['workout_type'] != 'Other':
                                    workout['original_type'] = workout['workout_type']

                        if component_name == 'biometrics':
                            if 'body_composition' not in data or not isinstance(data['body_composition'], dict):
                                data['body_composition'] = {}
                            if 'vital_signs' not in data or not isinstance(data['vital_signs'], dict):
                                data['vital_signs'] = {}

                            bc_data = data['body_composition']
                            vs_data = data['vital_signs']

                            weight_history = bc_data.get('weight', {}).get('history')
                            if isinstance(weight_history, list) and weight_history and not data.get('weight_readings'):
                                data['weight_readings'] = [
                                    {'value': entry.get('value'), 'date': entry.get('timestamp'), 'unit': entry.get('unit', 'kg')}
                                    for entry in weight_history if entry.get('value') and entry.get('timestamp')
                                ]

                            bfp_history = bc_data.get('body_fat_percentage', {}).get('history')
                            if isinstance(bfp_history, list) and bfp_history and not data.get('body_fat_percentage_readings'):
                                data['body_fat_percentage_readings'] = [
                                    {'value': entry.get('value'), 'date': entry.get('timestamp'), 'unit': entry.get('unit', '%')}
                                    for entry in bfp_history if entry.get('value') and entry.get('timestamp')
                                ]

                            bmi_history = bc_data.get('bmi', {}).get('history')
                            if isinstance(bmi_history, list) and bmi_history and not data.get('bmi_readings'):
                                data['bmi_readings'] = [
                                    {'value': entry.get('value'), 'date': entry.get('timestamp'), 'unit': entry.get('unit', 'kg/m²')}
                                    for entry in bmi_history if entry.get('value') and entry.get('timestamp')
                                ]

                            rhr_history = vs_data.get('resting_heart_rate', {}).get('history')
                            if isinstance(rhr_history, list) and rhr_history and not data.get('resting_heart_rate_readings'):
                                data['resting_heart_rate_readings'] = [
                                    {'value': entry.get('value'), 'date': entry.get('timestamp'), 'unit': entry.get('unit', 'bpm')}
                                    for entry in rhr_history if entry.get('value') and entry.get('timestamp')
                                ]

                        memory_components[component_name] = data

                except json.JSONDecodeError as e:
                    continue
                except Exception as e:
                    continue

        if not files_found:
             return cls.model_validate({'_passed_user_id': user_id_from_caller})

        memory_components['_passed_user_id'] = user_id_from_caller

        try:
             validated_memory = cls.model_validate(memory_components)
             return validated_memory
        except Exception as e:
             return cls.model_validate({'_passed_user_id': user_id_from_caller})

    def to_compact(self) -> CompactOverallMemory:
        return CompactOverallMemory(
            workout_memory=self.workout_memory.to_compact() if self.workout_memory else None,
            activities=self.activities.to_compact() if self.activities else None,
            biometrics=self.biometrics.to_compact() if self.biometrics else None,
            user_profile=self.user_profile.to_compact() if self.user_profile else None,
            workout_plan=self.workout_plan.to_compact() if self.workout_plan else None,
            medical_history=None,
            chat_history=self.chat_history.to_compact() if self.chat_history else None
        )

    def get_llm_view(self) -> str:
        now = datetime.now()
        view_parts = []
        if self.user_profile: view_parts.append(self.user_profile.get_llm_view())
        else: view_parts.append("=== User Profile ===\nProfile not fully initialized.")

        if self.workout_memory: view_parts.append(self.workout_memory.get_llm_view(now))
        if self.workout_plan: view_parts.append(self.workout_plan.get_llm_view())
        if self.activities: view_parts.append(self.activities.get_llm_view(now))
        if self.biometrics: view_parts.append(self.biometrics.get_llm_view(now))
        joined_view = "\n\n".join(filter(None, view_parts))
        joined_view = joined_view.replace("\\n", "\n")
        return joined_view