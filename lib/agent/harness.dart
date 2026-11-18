/// The pieces of the harness, in the order the talk adds them.
enum HarnessPiece {
  model('Model', 1),
  history('History', 2),
  contextBuilder('Context builder', 2),
  tools('Tools', 3),
  loop('Loop', 3),
  validation('Validation', 3),
  stepLimit('Step limit', 3),
  contextBudget('Context budget', 4),
  memory('Memory', 5),
  appState('App state', 5),
  approval('Approval', 6),
  leastPrivilege('Least privilege', 6),
  retry('Retry', 6);

  const HarnessPiece(this.label, this.level);
  final String label;
  final int level;
}

enum ShrinkStrategy { summarise, remove }

/// One configuration of the harness. Each level's "without" and "with" runs
/// differ by exactly the pieces that level adds.
class HarnessConfig {
  const HarnessConfig(this.pieces, {this.shrink = ShrinkStrategy.summarise});

  final Set<HarnessPiece> pieces;
  final ShrinkStrategy shrink;

  bool has(HarnessPiece piece) => pieces.contains(piece);

  HarnessConfig plus(Set<HarnessPiece> more, {ShrinkStrategy? shrink}) =>
      HarnessConfig({...pieces, ...more}, shrink: shrink ?? this.shrink);
}

class Harnesses {
  static const h1 = HarnessConfig({HarnessPiece.model});
  static final h2 =
      h1.plus({HarnessPiece.history, HarnessPiece.contextBuilder});
  static final h3NoLimit = h2.plus(
      {HarnessPiece.tools, HarnessPiece.loop, HarnessPiece.validation});
  static final h3 = h3NoLimit.plus({HarnessPiece.stepLimit});
  static final h4Summarise = h3.plus({HarnessPiece.contextBudget},
      shrink: ShrinkStrategy.summarise);
  static final h4Remove =
      h3.plus({HarnessPiece.contextBudget}, shrink: ShrinkStrategy.remove);
  static final h5 =
      h4Summarise.plus({HarnessPiece.memory, HarnessPiece.appState});
  static final h6 = h5.plus({
    HarnessPiece.approval,
    HarnessPiece.leastPrivilege,
    HarnessPiece.retry,
  });
}
