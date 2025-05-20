# Zestify - AI-Powered Personal Wellness Assistant

An intelligent wellness platform that combines generative AI with behavioral science to create personalized health and fitness plans. The app adapts its recommendations based on real-time data from user input and wearables, providing a truly personalized wellness experience.

## Project Overview

Zestify is built with a modern tech stack:
- **Backend**: Python 3.11+ with FastAPI
- **Frontend**: Flutter for cross-platform support
- **AI Integration**: Support for multiple LLM providers
- **Data Processing**: Real-time processing and memory management

## Core Components

### Backend Architecture (`/backend`)
- `services/`: Core business logic and API endpoints
- `memory/`: Data persistence and state management
- `prompts/`: LLM prompt templates and configurations
- `llm/`: AI model integrations and abstractions
- `examples/`: Sample implementations and demos
- `docs/`: Additional documentation

### Key Features
- Deep contextual understanding of user's health data
- Personalized wellness plan generation
- Real-time feedback and plan adjustments
- Privacy-focused data handling
- Gamified engagement elements

## Technical Stack

### Backend Framework
- FastAPI for high-performance API endpoints
- Pydantic for data validation
- Uvicorn for ASGI server

### Development Tools
- Python 3.11+ required
- Black for code formatting
- Ruff for linting
- MyPy for type checking
- Pytest for testing

### Frontend (Flutter)
- Cross-platform support (iOS, Android, Web)
- Rich UI capabilities
- Hot reload for rapid development
- Component-based architecture

## Getting Started

1. Clone the repository
2. Copy `.env.example` to `.env` and configure your environment variables
3. Install dependencies:
   ```bash
   pip install -e ".[dev]"
   ```
4. Run the development server:
   ```bash
   uvicorn backend.services.api:app --reload
   ```

## Development Workflow

- Use `make` commands for common tasks (see Makefile)
- Follow Python type hints and documentation standards
- Run tests before submitting PRs
- Use feature branches for development

## Testing

- Backend: Pytest for unit and integration tests
- Frontend: Flutter testing framework
  - Widget tests
  - Golden tests for UI
  - Integration tests

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

[License information to be added]
