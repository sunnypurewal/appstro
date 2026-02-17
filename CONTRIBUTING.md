# Contributing to appstro

Thank you for your interest in contributing to appstro! We welcome contributions from the community to help make this tool better for everyone.

## Getting Started

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/appstro.git
    cd appstro
    ```
3.  **Ensure you have the prerequisites** installed:
    - macOS
    - Xcode 16.0+
    - Swift 5.9+
4.  **Install dependencies** (if any) and build the project:
    ```bash
    make cli
    ```

## How to Contribute

### Reporting Bugs
- Use the [GitHub Issues](https://github.com/sunnypurewal/appstro/issues) to report bugs.
- Provide a clear and descriptive title.
- Include steps to reproduce the issue, what you expected to happen, and what actually happened.
- Attach any relevant logs or screenshots.

### Suggesting Enhancements
- Open a [GitHub Issue](https://github.com/sunnypurewal/appstro/issues) to suggest new features or improvements.
- Explain why the enhancement would be useful and how it should work.

### Pull Requests
1.  **Create a new branch** for your feature or bug fix:
    ```bash
    git checkout -b feature/your-feature-name
    ```
2.  **Make your changes**.
3.  **Ensure code quality** by running linting and formatting:
    ```bash
    make format
    make lint
    ```
4.  **Write and run tests** to verify your changes:
    ```bash
    swift test
    ```
5.  **Commit your changes** with clear and concise commit messages.
6.  **Push to your fork** and **open a Pull Request** against the `main` branch.

## Development Workflow

- **Building:** Use `make cli` for debug builds and `make release` for release builds.
- **Linting:** We use [SwiftLint](https://github.com/realm/SwiftLint). Please ensure your code passes `make lint`.
- **Testing:** Always add unit tests for new features or bug fixes. Run them using `swift test`.

## Code Style

- Follow standard Swift naming conventions and design patterns.
- Use tabs for indentation (as configured in `.swiftlint.yml`).
- Keep functions and classes focused and modular.

## License

By contributing to appstro, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
