# Contributing to Zarr MATLAB

Thank you for your interest in contributing to the Zarr MATLAB implementation! This document provides guidelines and information for contributors.

## Development Setup

1. Fork the repository and clone your fork:
```bash
git clone https://github.com/yourusername/zarr-matlab.git
cd zarr-matlab
```

2. Add the original repository as a remote:
```bash
git remote add upstream https://github.com/originuser/zarr-matlab.git
```

3. Create a new branch for your feature or bugfix:
```bash
git checkout -b feature-name
```

## Code Style Guidelines

- Follow MATLAB's standard naming conventions:
  - Function and variable names in `camelCase`
  - Class names in `PascalCase`
  - Constants in `UPPER_CASE`
- Use clear, descriptive variable names
- Include function documentation using MATLAB's help format:
```matlab
function result = myFunction(param1, param2)
% MYFUNCTION Brief description
%   Detailed description of what the function does
%
% Parameters:
%   param1: type
%       Description of param1
%   param2: type
%       Description of param2
%
% Returns:
%   result: type
%       Description of return value
```

## Testing

- Write tests for new features using MATLAB's unit testing framework
- Place tests in the `tests` directory
- Test files should be named `test_*.m`
- Run the test suite before submitting changes:
```matlab
runtests('tests')
```

## Pull Request Process

1. Update documentation for any new features or changes
2. Add or update tests as needed
3. Run the test suite and ensure all tests pass
4. Commit your changes with clear, descriptive commit messages
5. Push to your fork and submit a pull request
6. Describe your changes in the pull request description

## Reporting Issues

When reporting issues, please include:

- A clear description of the problem
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- MATLAB version and operating system
- Any relevant error messages or screenshots

## Feature Requests

Feature requests are welcome! Please provide:

- A clear description of the feature
- Use cases and benefits
- Any relevant examples or references
- Potential implementation approaches (optional)

## Code Organization

The codebase is organized as follows:

```
zarr-matlab/
├── +zarr/              # Main package directory
│   ├── +core/         # Core functionality
│   ├── +codecs/       # Compression codecs
│   ├── +errors/       # Error classes
│   └── +storage/      # Storage backends
├── tests/             # Test files
├── examples/          # Example scripts
└── docs/             # Documentation
```

## Adding New Features

When adding new features:

1. Follow the existing code organization
2. Maintain compatibility with Python Zarr where possible
3. Document new functionality thoroughly
4. Add examples demonstrating usage
5. Include appropriate error handling
6. Write comprehensive tests

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

## Questions and Discussion

For questions or discussion about development:

1. Open a GitHub issue for technical discussions
2. Use pull request comments for code-specific discussions
3. Check existing issues and pull requests before posting

## Development Process

1. Choose an issue to work on or create a new one
2. Discuss implementation approach if needed
3. Write code and tests
4. Update documentation
5. Submit pull request
6. Respond to review feedback
7. Iterate until changes are approved

Thank you for contributing to Zarr MATLAB!
