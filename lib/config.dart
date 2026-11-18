/// Build-time configuration.
///
/// Values come from `--dart-define-from-file=.env` and `--dart-define`
/// (see `tool/run.sh`). The API key is never stored in code or in git.
class AppConfig {
  static const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const model = String.fromEnvironment(
    'CLAUDE_MODEL',
    defaultValue: 'claude-opus-5-5',
  );
  static const effort = String.fromEnvironment(
    'CLAUDE_EFFORT',
    defaultValue: 'low',
  );

  /// Absolute path of the project folder, so recordings can be written back
  /// into `recordings/recordings.json`.
  static const projectDir = String.fromEnvironment('PROJECT_DIR');

  /// A deliberately small window so it fills on stage. Real models have 1M.
  static const contextBudget = 8000;

  /// The harness step limit (level 3).
  static const stepLimit = 8;

  /// Not part of the harness being taught: a hard cap so a run without the
  /// step limit can't spend money forever during a demo.
  static const safetyCap = 16;

  static bool get hasKey => apiKey.isNotEmpty;

  static String? get recordingsPath =>
      projectDir.isEmpty ? null : '$projectDir/recordings/recordings.json';
}
