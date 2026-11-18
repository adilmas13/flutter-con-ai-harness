import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../stores/app_store.dart';
import 'chat_pane.dart';
import 'harness_bar.dart';
import 'inspector/inspector.dart';
import 'theme.dart';
import 'toolbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: Column(
        children: [
          PresenterBar(store: store),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.window,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      AppToolbar(store: store),
                      HarnessBar(store: store),
                      Expanded(
                        child: Observer(
                          builder: (_) => Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: ChatPane(store: store)),
                              if (store.inspectorOpen)
                                SizedBox(
                                  width: 520,
                                  child: Inspector(store: store),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
