// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AppStore on _AppStore, Store {
  Computed<Level>? _$levelComputed;

  @override
  Level get level => (_$levelComputed ??= Computed<Level>(
    () => super.level,
    name: '_AppStore.level',
  )).value;
  Computed<Experiment>? _$experimentComputed;

  @override
  Experiment get experiment => (_$experimentComputed ??= Computed<Experiment>(
    () => super.experiment,
    name: '_AppStore.experiment',
  )).value;
  Computed<HarnessConfig>? _$configComputed;

  @override
  HarnessConfig get config => (_$configComputed ??= Computed<HarnessConfig>(
    () => super.config,
    name: '_AppStore.config',
  )).value;
  Computed<HarnessConfig>? _$otherConfigComputed;

  @override
  HarnessConfig get otherConfig =>
      (_$otherConfigComputed ??= Computed<HarnessConfig>(
        () => super.otherConfig,
        name: '_AppStore.otherConfig',
      )).value;
  Computed<int>? _$contextTokensComputed;

  @override
  int get contextTokens => (_$contextTokensComputed ??= Computed<int>(
    () => super.contextTokens,
    name: '_AppStore.contextTokens',
  )).value;

  late final _$levelIndexAtom = Atom(
    name: '_AppStore.levelIndex',
    context: context,
  );

  @override
  int get levelIndex {
    _$levelIndexAtom.reportRead();
    return super.levelIndex;
  }

  @override
  set levelIndex(int value) {
    _$levelIndexAtom.reportWrite(value, super.levelIndex, () {
      super.levelIndex = value;
    });
  }

  late final _$experimentIndexAtom = Atom(
    name: '_AppStore.experimentIndex',
    context: context,
  );

  @override
  int get experimentIndex {
    _$experimentIndexAtom.reportRead();
    return super.experimentIndex;
  }

  @override
  set experimentIndex(int value) {
    _$experimentIndexAtom.reportWrite(value, super.experimentIndex, () {
      super.experimentIndex = value;
    });
  }

  late final _$sideAtom = Atom(name: '_AppStore.side', context: context);

  @override
  Side get side {
    _$sideAtom.reportRead();
    return super.side;
  }

  @override
  set side(Side value) {
    _$sideAtom.reportWrite(value, super.side, () {
      super.side = value;
    });
  }

  late final _$inspectorOpenAtom = Atom(
    name: '_AppStore.inspectorOpen',
    context: context,
  );

  @override
  bool get inspectorOpen {
    _$inspectorOpenAtom.reportRead();
    return super.inspectorOpen;
  }

  @override
  set inspectorOpen(bool value) {
    _$inspectorOpenAtom.reportWrite(value, super.inspectorOpen, () {
      super.inspectorOpen = value;
    });
  }

  late final _$inspectorTabAtom = Atom(
    name: '_AppStore.inspectorTab',
    context: context,
  );

  @override
  InspectorTab get inspectorTab {
    _$inspectorTabAtom.reportRead();
    return super.inspectorTab;
  }

  @override
  set inspectorTab(InspectorTab value) {
    _$inspectorTabAtom.reportWrite(value, super.inspectorTab, () {
      super.inspectorTab = value;
    });
  }

  late final _$showRawJsonAtom = Atom(
    name: '_AppStore.showRawJson',
    context: context,
  );

  @override
  bool get showRawJson {
    _$showRawJsonAtom.reportRead();
    return super.showRawJson;
  }

  @override
  set showRawJson(bool value) {
    _$showRawJsonAtom.reportWrite(value, super.showRawJson, () {
      super.showRawJson = value;
    });
  }

  late final _$stateAtom = Atom(name: '_AppStore.state', context: context);

  @override
  AgentState get state {
    _$stateAtom.reportRead();
    return super.state;
  }

  @override
  set state(AgentState value) {
    _$stateAtom.reportWrite(value, super.state, () {
      super.state = value;
    });
  }

  late final _$lastRequestAtom = Atom(
    name: '_AppStore.lastRequest',
    context: context,
  );

  @override
  BuiltRequest? get lastRequest {
    _$lastRequestAtom.reportRead();
    return super.lastRequest;
  }

  @override
  set lastRequest(BuiltRequest? value) {
    _$lastRequestAtom.reportWrite(value, super.lastRequest, () {
      super.lastRequest = value;
    });
  }

  late final _$lastExactTokensAtom = Atom(
    name: '_AppStore.lastExactTokens',
    context: context,
  );

  @override
  int? get lastExactTokens {
    _$lastExactTokensAtom.reportRead();
    return super.lastExactTokens;
  }

  @override
  set lastExactTokens(int? value) {
    _$lastExactTokensAtom.reportWrite(value, super.lastExactTokens, () {
      super.lastExactTokens = value;
    });
  }

  late final _$checksAtom = Atom(name: '_AppStore.checks', context: context);

  @override
  List<CheckOutcome> get checks {
    _$checksAtom.reportRead();
    return super.checks;
  }

  @override
  set checks(List<CheckOutcome> value) {
    _$checksAtom.reportWrite(value, super.checks, () {
      super.checks = value;
    });
  }

  late final _$sentTurnsAtom = Atom(
    name: '_AppStore.sentTurns',
    context: context,
  );

  @override
  int get sentTurns {
    _$sentTurnsAtom.reportRead();
    return super.sentTurns;
  }

  @override
  set sentTurns(int value) {
    _$sentTurnsAtom.reportWrite(value, super.sentTurns, () {
      super.sentTurns = value;
    });
  }

  late final _$sendAsyncAction = AsyncAction(
    '_AppStore.send',
    context: context,
  );

  @override
  Future<void> send(String text) {
    return _$sendAsyncAction.run(() => super.send(text));
  }

  late final _$_AppStoreActionController = ActionController(
    name: '_AppStore',
    context: context,
  );

  @override
  void selectLevel(int index) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.selectLevel',
    );
    try {
      return super.selectLevel(index);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectExperiment(int index) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.selectExperiment',
    );
    try {
      return super.selectExperiment(index);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectSide(Side value) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.selectSide',
    );
    try {
      return super.selectSide(value);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleInspector() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.toggleInspector',
    );
    try {
      return super.toggleInspector();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setTab(InspectorTab tab) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.setTab',
    );
    try {
      return super.setTab(tab);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setRawJson(bool value) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.setRawJson',
    );
    try {
      return super.setRawJson(value);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void restart() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.restart',
    );
    try {
      return super.restart();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetForStage() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.resetForStage',
    );
    try {
      return super.resetForStage();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _startExperiment() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore._startExperiment',
    );
    try {
      return super._startExperiment();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _showBranch() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore._showBranch',
    );
    try {
      return super._showBranch();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void cancel() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.cancel',
    );
    try {
      return super.cancel();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _finishTurn(TurnRecord record) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore._finishTurn',
    );
    try {
      return super._finishTurn(record);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleToolGroup(int index) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.toggleToolGroup',
    );
    try {
      return super.toggleToolGroup(index);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void decide(int id, bool yes) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.decide',
    );
    try {
      return super.decide(id, yes);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setState(AgentState value) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.setState',
    );
    try {
      return super.setState(value);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showRequest(BuiltRequest request, {int? exactTokens}) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.showRequest',
    );
    try {
      return super.showRequest(request, exactTokens: exactTokens);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  int addTrace(TraceEvent event) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.addTrace',
    );
    try {
      return super.addTrace(event);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateTrace(int index, TraceEvent event) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.updateTrace',
    );
    try {
      return super.updateTrace(index, event);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void assistantText(String text, {bool interim = false}) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.assistantText',
    );
    try {
      return super.assistantText(text, interim: interim);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void appText(String text) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.appText',
    );
    try {
      return super.appText(text);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void budgetError(int tokens) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.budgetError',
    );
    try {
      return super.budgetError(tokens);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void errorText(String text) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.errorText',
    );
    try {
      return super.errorText(text);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  int toolStarted(String name, Map<String, dynamic> args) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.toolStarted',
    );
    try {
      return super.toolStarted(name, args);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toolFinished(int handle, ToolOutcome outcome) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.toolFinished',
    );
    try {
      return super.toolFinished(handle, outcome);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<bool> requestApproval(String tool, Map<String, dynamic> args) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.requestApproval',
    );
    try {
      return super.requestApproval(tool, args);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<bool> confirmMemory(String fact) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.confirmMemory',
    );
    try {
      return super.confirmMemory(fact);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void saveMemory(String fact) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.saveMemory',
    );
    try {
      return super.saveMemory(fact);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setItinerary(List<String> ids) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.setItinerary',
    );
    try {
      return super.setItinerary(ids);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void showPlan(List<Session> sessions, List<String> unknownIds) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.showPlan',
    );
    try {
      return super.showPlan(sessions, unknownIds);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addCalendarEvents(List<Session> sessions) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.addCalendarEvents',
    );
    try {
      return super.addCalendarEvents(sessions);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void recordExport(String to, int count) {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.recordExport',
    );
    try {
      return super.recordExport(to, count);
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
levelIndex: ${levelIndex},
experimentIndex: ${experimentIndex},
side: ${side},
inspectorOpen: ${inspectorOpen},
inspectorTab: ${inspectorTab},
showRawJson: ${showRawJson},
state: ${state},
lastRequest: ${lastRequest},
lastExactTokens: ${lastExactTokens},
checks: ${checks},
sentTurns: ${sentTurns},
level: ${level},
experiment: ${experiment},
config: ${config},
otherConfig: ${otherConfig},
contextTokens: ${contextTokens}
    ''';
  }
}
