  @override
  void initState() {
    super.initState();
    _draft =
        widget.initialProfile ?? UserProfile(languageCode: widget.languageCode);
  }

  void _saveDraft(UserProfile profile) {
    _draft = profile;
    final repository = ref.read(userProfileRepositoryProvider);
    _saveQueue = _saveQueue.then(
      (_) => repository.save(profile.copyWith(onboardingCompleted: false)),
    );
  }

  Future<void> _submit(UserProfile profile) async {
    await _saveQueue;

    // Completing onboarding activates the local Guest ledger for the
    // subsequent import and for StartupGate/profile consumers.
    ref.read(activeLocalAccountIdStateProvider.notifier).state =
        UserProfile.localLedgerUserId;

    final finalizedProfile = profile.copyWith(
      witrIncluded: ProfileRules.effectiveWitr(profile),
      onboardingCompleted: true,
    );

    final plan = ref.read(qazaPlanServiceProvider).planFor(finalizedProfile);
    if (plan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }
