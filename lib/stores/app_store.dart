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
  _AppStore(this.schedule, this.recordings,
      // Passed through the generated AppStore constructor.
      // ignore: unused_element_parameter
      {ModelClient Function()? liveClient, this.scheduleText = ''})
      : builder = ContextBuilder(schedule),
        _liveClient = liveClient ?? AnthropicClient.new {
    _startExperiment();
  }

  @override
  final Schedule schedule;
  final RecordingStore recordings;
  final ContextBuilder builder;
  final ModelClient Function() _liveClient;

  /// The compact schedule users paste at levels 1 and 2.
  final String scheduleText;
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
  @observable
  bool canSave = false;
  @observable
  String? toast;

  /// The system prompt this side sends, as lines.
  List<String> get systemLines => _systemLines(config);

  /// The system prompt the other side of this experiment sends.
  List<String> get otherSystemLines => _systemLines(otherConfig);

  List<String> _systemLines(HarnessConfig c) {
    final body = builder.build(conversation, c, calendarTools: experiment.calendarTools).request.body;
    final blocks = (body['system'] as List? ?? const []).cast<Map>();
    final lines = <String>[];
    for (final b in blocks) {
      if (lines.isNotEmpty) lines.add('');
      lines.addAll('${b['text']}'.split('\n'));
    }
    return lines;
  }

  Rules get rules => Rules.from([...conversation.userTexts, ...memoryFacts]);

  @computed
  int get contextTokens =>
      lastExactTokens ??
      (lastRequest?.sections
              .where((s) => !s.dropped)
              .fold<int>(0, (a, s) => a + s.tokens) ??
          0);

  // ================= selection =================
  //
  // One conversation accumulates across the levels. Within a level, the
  // Without and With runs each continue the same history, so the only
  // difference between them is the harness. Experiments in a level share
  // the level's starting point. Only the With run of a level's first
  // experiment carries forward (or of its new conversation, once that has
  // run), and a level never starts from a later one.

  /// Each level's result, by level index: the run the next level starts from.
  final Map<int, _Branch> _results = {};
  final Map<Side, _Branch> _branches = {};

  /// Demo data loaded for this experiment because nothing real was saved.
  List<String> _staged = [];

  /// The nearest earlier level's result, or null at the start of the talk.
  _Branch? get _levelStart {
    for (var i = levelIndex - 1; i >= 0; i--) {
      if (_results[i] != null) return _results[i];
    }
    return null;
  }

  @action
  void selectLevel(int index) {
    if (state.isBusy) return;
    _keepResult();
    levelIndex = index;
    experimentIndex = 0;
    side = Side.without;
    inspectorOpen = index > 0;
    _startExperiment();
  }

  /// Experiments in one level all start from where the level started; history
  /// only carries forward when you change level.
  @action
  void selectExperiment(int index) {
    if (state.isBusy) return;
    _keepResult();
    experimentIndex = index;
    side = Side.without;
    _startExperiment();
  }

  @action
  void selectSide(Side value) {
    if (state.isBusy || value == side) return;
    _saveBranch();
    side = value;
    _showBranch();
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

  /// Runs this side of the experiment again from the shared history.
  @action
  void restart() {
    if (state.isBusy) return;
    _branches[side] = _newBranch(side);
    _showBranch();
  }

  /// Back to the start of the talk with an empty conversation.
  @action
  void resetForStage() {
    if (state.isBusy) return;
    _results.clear();
    memoryFacts.clear();
    itinerary.clear();
    levelIndex = 0;
    experimentIndex = 0;
    side = Side.without;
    inspectorOpen = false;
    replay = false;
    toast = null;
    _startExperiment();
  }

  /// The With run of the level's first experiment becomes the level's
  /// result. A Without run never carries forward (level 1 has only one run).
  /// A new conversation replaces it: from then on, that is the conversation.
  void _keepResult() {
    if (_branches.isEmpty) return;
    _saveBranch();
    if (experimentIndex != 0 && experiment.id != 'new-conversation') return;
    final run = _branches[experiment.baseline ? Side.without : Side.withPiece];
    if (run != null && run.sentTurns > 0) _results[levelIndex] = run;
  }

  @action
  void _startExperiment() {
    final exp = experiment;
    if (exp.id == 'save') memoryFacts.clear();
    _staged = [];
    if (exp.seed == Seed.demoMemoryAndPlan) {
      if (memoryFacts.isEmpty) {
        memoryFacts.addAll(demoMemory);
        _staged.add('three demo preferences');
      }
      if (itinerary.isEmpty) {
        itinerary.addAll(demoPlanIds(schedule));
        _staged.add('a demo plan from this morning');
      }
    }
    calendar.clear();
    exports.clear();
    _branches
      ..clear()
      ..addAll({for (final s in Side.values) s: _newBranch(s)});
    _showBranch();
  }

  _Branch _newBranch(Side s) {
    final exp = experiment;
    final Conversation conv;
    final items = <ChatItem>[];
    if (exp.id == 'new-conversation') {
      conv = Conversation(memorySnapshot: memoryFacts.toList());
      items.add(const DividerText('New conversation'));
    } else {
      final start = _levelStart;
      conv = Conversation.continuing(start?.conv ?? Conversation(), memoryFacts.toList());
      items.addAll(start?.chat ?? const []);
      if (exp.seed == Seed.longChat && _estimate(conv) < AppConfig.contextBudget) {
        final before = conv.userTurns;
        seedLongChat(conv, schedule);
        items.add(DividerText(
            'Fast-forward: ${conv.userTurns - before} earlier turns. The rules were said at the start.'));
      }
    }
    if (_staged.isNotEmpty) {
      items.add(DividerText('Staged for the demo: ${_staged.join(' and ')}.'));
    }
    final label = exp.baseline
        ? level.name
        : '${s == Side.without ? 'Without' : 'With'} ${exp.change}';
    items.add(DividerText('Level ${level.number} · $label'));
    return _Branch(conv, items);
  }

  int _estimate(Conversation conv) => estimateTokens(conv.messages);

  void _saveBranch() {
    final b = _branches[side];
    if (b == null) return;
    b
      ..chat = chat.toList()
      ..trace = trace.toList()
      ..checks = checks
      ..sentTurns = sentTurns
      ..request = lastRequest
      ..exactTokens = lastExactTokens
      ..calendar = calendar.toList()
      ..exports = exports.toList();
  }

  @action
  void _showBranch() {
    final b = _branches[side]!;
    conversation = b.conv;
    chat
      ..clear()
      ..addAll(b.chat);
    trace
      ..clear()
      ..addAll(b.trace);
    checks = b.checks;
    sentTurns = b.sentTurns;
    lastRequest =
        b.request ?? builder.build(conversation, config, calendarTools: experiment.calendarTools);
    lastExactTokens = b.exactTokens;
    // Each side has its own calendar, so one side's writes never show on the other.
    calendar
      ..clear()
      ..addAll(b.calendar);
    exports
      ..clear()
      ..addAll(b.exports);
    canSave = false;
    _turns.clear();
    _pending.clear();
    _cancel = Completer<void>();
    state = const Idle();
  }

  // ================= sending =================

  /// Live turns captured in this conversation, saved together by Save run.
  final List<({String key, String input, List<Exchange> exchanges})> _turns = [];
  Completer<void> _cancel = Completer<void>();

  @override
  Future<void> get cancelled => _cancel.future;

  @action
  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || state.isBusy) return;
    final pasted = text.contains(pasteSchedule);
    final shown = text.replaceAll(pasteSchedule, '').trim();
    text = text.replaceAll(pasteSchedule, scheduleText.trim());

    final key = nextRecordingKey;
    ModelClient client;
    RecordingClient? capture;
    chat.add(UserText(shown,
        pastedLines: pasted ? '\n'.allMatches(scheduleText.trim()).length + 1 : 0));
    if (replay) {
      // A recording only plays back for the exact message it was recorded
      // with, in the same position. Anything else would show a reply to a
      // different question.
      final rec = recordings[key];
      if (rec == null || rec.input != text) {
        chat.add(ErrorText(_replayMismatch(text)));
        return;
      }
      client = ReplayClient(rec.exchanges);
    } else {
      client = capture = RecordingClient(_liveClient());
    }

    if (_cancel.isCompleted) _cancel = Completer<void>();
    _calendarTimedOut = false;
    trace.clear();
    checks = const [];
    canSave = false;
    _currentGroup = null;

    final loop = AgentLoop(
      client: client,
      builder: builder,
      host: this,
      config: config,
      conv: conversation,
      calendarTools: experiment.calendarTools,
    );
    final record = await loop.run(text, selfContained: pasted);
    _finishTurn(record, key, text, capture);
  }

  /// Explains why a message can't be replayed, and what to do instead.
  String _replayMismatch(String text) {
    final suggestions = experiment.inputs
        .map((i) => i.replaceAll(pasteSchedule, scheduleText.trim()).trim())
        .toList();
    final at = suggestions.indexOf(text);
    if (at >= 0 && at != sentTurns) {
      return 'In Replay, send the suggestions in order. This one was recorded as message ${at + 1}. '
          'Press restart (↻) to begin the conversation again.';
    }
    if (at < 0) {
      return 'This message wasn’t recorded, so Replay can’t answer it. '
          'Use the suggestions below, or switch to Live to ask anything.';
    }
    return 'Nothing is recorded for this message yet. Switch to Live, run it, and save the run.';
  }

  @action
  void cancel() {
    if (!state.isBusy) return;
    if (!_cancel.isCompleted) _cancel.complete();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pending.clear();
    for (var i = 0; i < chat.length; i++) {
      final item = chat[i];
      if (item is ApprovalCard && item.decision == Decision.pending) {
        chat[i] = ApprovalCard(item.id, item.tool, item.sessions, item.args, Decision.no);
      } else if (item is MemoryCard && item.decision == Decision.pending) {
        chat[i] = MemoryCard(item.id, item.fact, Decision.no);
      }
    }
  }

  @action
  void _finishTurn(TurnRecord record, String key, String text, RecordingClient? capture) {
    checks = runChecks(record, rules, schedule);
    sentTurns++;
    if (capture == null) return;
    final broken = state is Failed || (state is Stopped && (state as Stopped).reason == 'cancelled');
    if (broken) {
      // Later turns would replay against a conversation that never happened.
      _turns.clear();
      canSave = false;
      return;
    }
    if (capture.captured.isNotEmpty) {
      _turns.add((key: key, input: text, exchanges: List.of(capture.captured)));
      canSave = true;
    }
  }

  /// Saves every live turn of this conversation, so multi-turn experiments
  /// stay consistent.
  @action
  Future<void> saveRun() async {
    if (_turns.isEmpty) return;
    final turns = List.of(_turns);
    try {
      for (final t in turns) {
        await recordings.save(Recording(
            key: t.key, input: t.input, savedAt: DateTime.now(), exchanges: t.exchanges));
      }
      _saved(turns.length == 1 ? turns.single.key : '${turns.length} turns (${turns.first.key} …)');
    } catch (e) {
      _toast('$e');
    }
  }

  @action
  void _saved(String what) {
    canSave = false;
    toast = 'Saved $what';
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
  void assistantText(String text, {bool interim = false}) {
    _currentGroup = null;
    chat.add(AssistantText(text, fromRecording: replay, interim: interim));
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

/// One side's run within a level, continuing the shared conversation.
class _Branch {
  _Branch(this.conv, this.chat);
  final Conversation conv;
  List<ChatItem> chat;
  List<TraceEvent> trace = const [];
  List<CheckOutcome> checks = const [];
  int sentTurns = 0;
  BuiltRequest? request;
  int? exactTokens;
  List<Session> calendar = const [];
  List<String> exports = const [];
}
