# Health AI App Makefile

.PHONY: download-health-data clean-health-data fetch-all-health-data download-all-health-data

# Download health data from connected iOS device using ios-deploy
download-health-data:
	@echo "Downloading health data from connected iOS device..."
	ios-deploy --bundle_id 'com.healthai.coach' --download=/Documents/health_data --to frontend/health_ai_app/health_ai/example_data

# Fetch all health data using the app's health service (basic version)
fetch-all-health-data:
	@echo "Fetching all health data using the app's health service..."
	cd frontend/health_ai_app/health_ai && flutter run bin/download_health_data.dart

# Download ALL health data comprehensively (recommended)
download-all-health-data:
	@echo "Downloading ALL health data comprehensively..."
	cd frontend/health_ai_app/health_ai && flutter run bin/download_all_health_data.dart

# Clean downloaded health data
clean-health-data:
	@echo "Cleaning downloaded health data..."
	rm -rf frontend/health_ai_app/health_ai/example_data/Documents/health_data

# List available iOS devices
list-devices:
	ios-deploy -c

# Help command
help:
	@echo "Health AI App Makefile Commands:"
	@echo "  download-health-data      - Download health data from connected iOS device using ios-deploy"
	@echo "  download-all-health-data  - Download ALL health data comprehensively (RECOMMENDED)"
	@echo "  fetch-all-health-data     - Fetch all health data using the app's health service (basic version)"
	@echo "  clean-health-data         - Clean downloaded health data"
	@echo "  list-devices              - List available iOS devices"
