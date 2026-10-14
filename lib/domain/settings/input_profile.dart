enum InputProfile {
  voiceIsolation('voiceIsolation', 'Voice Isolation'),
  studio('studio', 'Studio');

  const InputProfile(this.id, this.label);

  final String id;
  final String label;

  static InputProfile fromId(String? id) {
    for (final profile in InputProfile.values) {
      if (profile.id == id) {
        return profile;
      }
    }
    return InputProfile.studio;
  }
}
