# appstro

[![Swift](https://github.com/sunnypurewal/appstro/actions/workflows/test.yml/badge.svg)](https://github.com/sunnypurewal/appstro/actions/workflows/test.yml)

Fully automated iOS app builder. `appstro` allows you to manage the entire lifecycle of your iOS app—from project initialization and App Store Connect registration to metadata generation (powered by AI) and final submission—all from your terminal.

## Setup

### Prerequisites
- **macOS**
- **Xcode 16.0** or later
- **Swift 5.9** or later

### Installation
The recommended way to install `appstro` is using `make`:

```bash
make install
```

This builds the application in release mode and copies the binary to `/usr/local/bin/appstro`.

### Configuration
To interact with App Store Connect, you need to set up API keys. Run the following command for instructions:

```bash
appstro login
```

You will need to set the following environment variables in your shell profile (e.g., `.zshrc` or `.bash_profile`):
- `APPSTORE_ISSUER_ID`
- `APPSTORE_KEY_ID`
- `APPSTORE_PRIVATE_KEY`

## Commands

### Main Commands
- `appstro init [path]` - Initialize a new iOS project with an `appstro.json` configuration.
- `appstro app <parameter>` - Fetch details of an app from App Store Connect by name or bundle ID.
- `appstro login` - Open App Store Connect to manage API keys and see setup instructions.
- `appstro create <name>` - Create a new app entry in App Store Connect.
- `appstro build` - Build the RELEASE configuration of the app for App Store submission.
- `appstro profile` - Manage provisioning profiles.
  - `create` - Create a new iOS App Store provisioning profile for the current app.
- `appstro submission` - Manage App Store versions and submissions.
  - `create <version>` - Create a new App Store version (e.g., 1.0.1).
  - `screenshots` - Generate (with AI-suggested titles/bezels) and upload screenshots.
  - `metadata` - Manage, generate, and upload app metadata.
    - `generate` - Generate and upload app metadata using AI based on your code and pitch.
    - `all` - Fetch and display all current metadata from App Store Connect.
    - `description` - Update or fetch the app description.
    - `keywords` - Update or fetch app keywords.
    - `whats-new` - Update or fetch "What's New in this Version".
    - `promotional-text` - Update or fetch promotional text.
    - `review-notes` - Update or fetch app review notes.
    - `copyright` - Update or fetch copyright information.
    - `support-url` - Update or fetch the support URL.
    - `marketing-url` - Update or fetch the marketing URL.
    - `contact` - Update or fetch app review contact information.
  - `upload <ipa-path>` - Upload an IPA file to App Store Connect and attach it to the draft version.
  - `submit` - Submit the prepared app version for review.
  - `attach <file-path>` - Attach a file (e.g., demo video) for App Store review.
  - `cancel` - Cancel an active review submission.
  - `add-build` - Attach the most recent successful uploaded build to the pending release version.
  - `app-clip` - Manage App Clip experiences.
    - `delete` - Delete an App Clip experience.
- `appstro info` - Manage app-level information and declarations.
  - `content-rights` - Declare content rights for the app.
  - `age-ratings` - Manage and suggest age ratings.
  - `privacy` - Manage privacy policy and settings.
  - `data-collection` - Manage data collection declarations.
  - `pricing` - Manage app pricing and availability.
- `appstro version` - Print the version of appstro.

## Development

Use the provided `Makefile` for common development tasks:

- `make cli` - Build the appstro CLI.
- `make release` - Build the appstro CLI in release mode.
- `make clean` - Clean the build directory.
- `make lint` - Run SwiftLint.
- `make format` - Run SwiftLint with autocorrect.
- `make install` - Build and install `appstro` to `/usr/local/bin`.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
