# GameForge AI — Android-Spielentwicklungs-Starter

A minimal Godot 4 project with a GitHub Actions validation pipeline and an Android debug-APK pipeline, plus instructions for an AI coding assistant.

## Setup from an Android phone
1. Create a **new empty GitHub repository** named `GameForgeAI` (without README).
2. Upload the contents of this ZIP to the repository root (not the containing folder), using a Git client, GitHub web editor or Termux.
3. Open **Actions**. Run **Validate Godot project** first.
4. Run **Android debug APK** using `workflow_dispatch`. If successful, download the `GameForgeAI-debug-APK` artifact from that run and install the APK on your Android device.
5. If a build fails, share the workflow log; Android SDK and Godot export settings vary by version and runner.

## AI connection
`AGENTS.md` contains instructions for an AI coding agent. To connect ChatGPT, grant its GitHub connector access to the new repository, then ask ChatGPT to inspect the repo and prepare changes in feature branches / pull requests. A persistent autonomous agent is NOT installed by this ZIP.

## Tools
- Godot 4.4.1 for reproducible CI; change both workflows together when upgrading.
- GitHub Actions cloud Linux runner, Java 17, Android SDK platform 35.
- Android Studio is optional for this Godot-first workflow. Eclipse Android ADT is obsolete.
- Signing in this starter is for debug builds only. Google Play requires an appropriate release AAB and secure release signing.

## Notes
This is a starter template, not a verified finished build. GitHub Actions have not yet run. The first Android export may need changes to the Godot Android export preset or SDK configuration. Avoid storing signing credentials in the repository.
