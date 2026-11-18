// MobX stores use a private base class by design.
// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:mobx/mobx.dart';

import '../agent/agent_loop.dart';
import '../agent/agent_state.dart';
import '../agent/checks.dart';
import '../agent/context_builder.dart';
import '../agent/conversation.dart';
import '../agent/harness.dart';
import '../agent/levels.dart';
import '../agent/model_client.dart';
import '../agent/recordings.dart';
import '../agent/seeds.dart';
import '../agent/tools.dart';
import '../config.dart';
import '../data/schedule.dart';
import 'chat_items.dart';

part 'app_store.g.dart';

enum InspectorTab { context, trace, memory, checks }

class AppStore = _AppStore with _$AppStore;

abstract class _AppStore with Store implements LoopHost {
  _AppStore(this.schedule, this.recordings) : builder = ContextBuilder(schedule) {
    _resetConversation();
  }

  @override
  final Schedule schedule;
  final RecordingStore recordings;
  final ContextBuilder builder;
  late Conversation conversation;

  // ---- what is selected ----
  @observable
  int levelIndex = 0;
  @observable
  int experimentIndex = 0;
  @observable
  Side side = Side.without;
  @observable
  bool replay = false;
  @observable
  bool inspectorOpen = false;
  @observable
  InspectorTab inspectorTab = InspectorTab.context;
  @observable
  bool showRawJson = false;

  @computed
  Level get level => levels[levelIndex];
  @computed
  Experiment get experiment => level.experiments[experimentIndex];
  @computed
  HarnessConfig get config => experiment.config(side);
  @computed
  HarnessConfig get otherConfig =>
      experiment.config(side == Side.without ? Side.withPiece : Side.without);

  String get _sideKey =>
      experiment.baseline ? 'baseline' : (side == Side.without ? 'without' : 'with');

  @computed
  String get nextRecordingKey => RecordingStore.keyFor(
      level: level.number,
      experiment: experiment.id,
      side: _sideKey,
      turn: sentTurns);

  /// Bumped when a run is saved, so the toolbar's replay icon updates.
  @observable
  int recordingsVersion = 0;

  @computed
  bool get hasRecordingForNextTurn =>
      recordingsVersion >= 0 && recordings[nextRecordingKey] != null;

  // ---- the run ----
  @observable
  AgentState state = const Idle();
  final ObservableList<ChatItem> chat = ObservableList();
  final ObservableList<TraceEvent> trace = ObservableList();
  @observable
  BuiltRequest? lastRequest;
  @observable
  int? lastExactTokens;
  @observable
  List<CheckOutcome> checks = const [];
  /// Turns the user has sent in this conversation (seeded turns excluded).
  @observable
  int sentTurns = 0;

  // ---- app state the tools change ----
  @override
  final ObservableList<String> memoryFacts = ObservableList();
  final ObservableList<String> itinerary = ObservableList();
  final ObservableList<Session> calendar = ObservableList();
  final ObservableList<String> exports = ObservableList();

  // ---- saving runs ----
  RecordingClient? _capture;
  String? _captureKey;
  String? _captureInput;
  @observable
  bool canSave = false;
  @observable
  String? toast;

  Rules get rules => Rules.from([...conversation.userTexts, ...memoryFacts]);

  @computed
  int get contextTokens =>
      lastExactTokens ??
      (lastRequest?.sections
              .where((s) => !s.dropped)
              .fold<int>(0, (a, s) => a + s.tokens) ??
          0);

  // ================= selection =================

  @action
  void selectLevel(int index) {
    if (state.isBusy) return;
    levelIndex = index;
    experimentIndex = 0;
    side = Side.without;
    inspectorOpen = index > 0;
    _resetConversation();
  }

  @action
  void selectExperiment(int index) {
    if (state.isBusy) return;
    experimentIndex = index;
    side = Side.without;
    _resetConversation();
  }

  @action
  void selectSide(Side value) {
    if (state.isBusy || value == side) return;
    side = value;
    _resetConversation();
  }

  @action
  void setReplay(bool value) => replay = value;
  @action
  void toggleInspector() => inspectorOpen = !inspectorOpen;
  @action
  void setTab(InspectorTab tab) => inspectorTab = tab;
  @action
  void setRawJson(bool value) => showRawJson = value;
  @action
  void dismissToast() => toast = null;

  @action
  void restart() {
    if (state.isBusy) return;
    _resetConversation();
  }

  @action
  void resetMemory() {
    if (state.isBusy) return;
    memoryFacts.clear();
    itinerary.clear();
    calendar.clear();
    exports.clear();
    _resetConversation();
  }

  @action
  void _resetConversation() {
    final exp = experiment;
    if (exp.id == 'save') memoryFacts.clear();
    if (exp.seed == Seed.demoMemoryAndPlan || exp.seed == Seed.demoMemory) {
      if (memoryFacts.isEmpty) memoryFacts.addAll(demoMemory);
      if (exp.seed == Seed.demoMemoryAndPlan && itinerary.isEmpty) {
        itinerary.addAll(demoPlanIds(schedule));
      }
    }
    conversation = Conversation(memorySnapshot: memoryFacts.toList());
    chat.clear();
    trace.clear();
    checks = const [];
    lastRequest = null;
    lastExactTokens = null;
    canSave = false;
    _calendarTimedOut = false;
    _pending.clear();
    state = const Idle();
    if (exp.seed == Seed.longChat) {
      seedLongChat(conversation, schedule);
      chat.add(DividerText(
          '${conversation.seededTurns} earlier turns. The rules were said at the start.'));
    }
    if (exp.seed == Seed.demoMemoryAndPlan) {
      chat.add(const DividerText('New conversation'));
    }
    lastRequest = builder.build(conversation, config,
        calendarTools: exp.calendarTools);
    sentTurns = 0;
  }

  // ================= sending =================

  @action
  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || state.isBusy) return;

    final key = nextRecordingKey;
    ModelClient client;
    if (replay) {
      final rec = recordings[key];
      if (rec == null) {
        chat.add(UserText(text));
        chat.add(const ErrorText(
            'Nothing is recorded for this turn yet. Switch to Live, run it, and save the run.'));
        return;
      }
      client = ReplayClient(rec.exchanges);
      _capture = null;
    } else {
      _capture = RecordingClient(AnthropicClient());
      client = _capture!;
    }

    trace.clear();
    checks = const [];
    canSave = false;
    chat.add(UserText(text));
    _currentGroup = null;

    final loop = AgentLoop(
      client: client,
      builder: builder,
      host: this,
      config: config,
      conv: conversation,
      calendarTools: experiment.calendarTools,
    );
    final record = await loop.run(text);
    _finishTurn(record, key, text);
  }

  @action
  void _finishTurn(TurnRecord record, String key, String text) {
    checks = runChecks(record, rules, schedule);
    sentTurns++;
    final captured = _capture?.captured ?? const [];
    if (!replay && captured.isNotEmpty) {
      _captureKey = key;
      _captureInput = text;
      canSave = true;
    }
  }

  @action
  Future<void> saveRun() async {
    final cap = _capture, key = _captureKey;
    if (cap == null || key == null) return;
    try {
      await recordings.save(Recording(
        key: key,
        input: _captureInput ?? '',
        savedAt: DateTime.now(),
        exchanges: List.of(cap.captured),
      ));
      _saved(key);
    } catch (e) {
      _toast('$e');
    }
  }

  @action
  void _saved(String key) {
    canSave = false;
    toast = 'Saved $key';
    recordingsVersion++;
  }

  @action
  void _toast(String text) => toast = text;

  // ================= chat cards =================

  final Map<int, Completer<bool>> _pending = {};
  int _nextId = 0;
  int? _currentGroup;

  @action
  void toggleToolGroup(int index) {
    final item = chat[index];
    if (item is ToolGroup) chat[index] = item.copyWith(expanded: !item.expanded);
  }

  @action
  void decide(int id, bool yes) {
    final c = _pending.remove(id);
    if (c == null) return;
    for (var i = 0; i < chat.length; i++) {
      final item = chat[i];
      final d = yes ? Decision.yes : Decision.no;
      if (item is ApprovalCard && item.id == id) {
        chat[i] = ApprovalCard(item.id, item.tool, item.sessions, item.args, d);
      } else if (item is MemoryCard && item.id == id) {
        chat[i] = MemoryCard(item.id, item.fact, d);
      }
    }
    c.complete(yes);
  }

  // ================= LoopHost =================

  @override
  @action
  void setState(AgentState value) => state = value;

  @override
  @action
  void showRequest(BuiltRequest request, {int? exactTokens}) {
    lastRequest = request;
    lastExactTokens = exactTokens;
  }

  @override
  @action
  int addTrace(TraceEvent event) {
    trace.add(event);
    return trace.length - 1;
  }

  @override
  @action
  void updateTrace(int index, TraceEvent event) => trace[index] = event;

  @override
  @action
  void assistantText(String text) {
    _currentGroup = null;
    chat.add(AssistantText(text, fromRecording: replay));
  }

  @override
  @action
  void appText(String text) {
    _currentGroup = null;
    chat.add(AppText(text));
  }

  @override
  @action
  void budgetError(int tokens) =>
      chat.add(BudgetError(tokens, AppConfig.contextBudget));

  @override
  @action
  void errorText(String text) => chat.add(ErrorText(text));

  @override
  @action
  int toolStarted(String name, Map<String, dynamic> args) {
    final call = ToolCallView(name, args, CallState.running);
    final g = _currentGroup;
    if (g != null && g < chat.length && chat[g] is ToolGroup) {
      final group = chat[g] as ToolGroup;
      chat[g] = group.copyWith(calls: [...group.calls, call]);
    } else {
      chat.add(ToolGroup([call], expanded: true));
      _currentGroup = chat.length - 1;
    }
    final group = chat[_currentGroup!] as ToolGroup;
    return (_currentGroup! << 8) | (group.calls.length - 1);
  }

  @override
  @action
  void toolFinished(int handle, ToolOutcome outcome) {
    final gi = handle >> 8, ci = handle & 0xff;
    final group = chat[gi] as ToolGroup;
    final calls = [...group.calls];
    calls[ci] = calls[ci].finish(outcome);
    chat[gi] = group.copyWith(calls: calls);
  }

  @override
  @action
  Future<bool> requestApproval(String tool, Map<String, dynamic> args) {
    final id = _nextId++;
    final sessions = [
      for (final s in (args['sessionIds'] as List? ?? const [])) ?schedule.byId('$s')
    ];
    _currentGroup = null;
    chat.add(ApprovalCard(id, tool, sessions, args, Decision.pending));
    return (_pending[id] = Completer<bool>()).future;
  }

  @override
  @action
  Future<bool> confirmMemory(String fact) {
    final id = _nextId++;
    _currentGroup = null;
    chat.add(MemoryCard(id, fact, Decision.pending));
    return (_pending[id] = Completer<bool>()).future;
  }

  @override
  @action
  void saveMemory(String fact) {
    if (!memoryFacts.contains(fact)) memoryFacts.add(fact);
  }

  // ---- ToolHost ----
  @override
  List<String> get itineraryIds => itinerary.toList();

  @override
  @action
  void setItinerary(List<String> ids) => itinerary
    ..clear()
    ..addAll(ids);

  @override
  @action
  void showPlan(List<Session> sessions, List<String> unknownIds) {
    _currentGroup = null;
    chat.add(PlanCard(sessions, unknownIds));
    if (config.has(HarnessPiece.appState)) {
      setItinerary(sessions.map((s) => s.id).toList());
    }
  }

  @override
  @action
  void addCalendarEvents(List<Session> sessions) {
    for (final s in sessions) {
      if (!calendar.any((c) => c.id == s.id)) calendar.add(s);
    }
  }

  @override
  @action
  void recordExport(String to, int count) => exports.add('$count contacts → $to');

  bool _calendarTimedOut = false;

  @override
  bool calendarShouldTimeOut() {
    if (_calendarTimedOut) return false;
    _calendarTimedOut = true;
    return true;
  }
}
