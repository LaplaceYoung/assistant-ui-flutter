# assistant_ui example

Demo app for the `assistant_ui` Flutter port. It runs offline: a scripted
adapter streams a reasoning part, a tool call that the runtime executes, and a
markdown answer, so the runtime, the primitives and the styled components can
all be exercised without a backend.

```bash
flutter run -d chrome          # or any device
flutter run -d chrome --dart-define=...
open 'http://localhost:PORT/?theme=dark'   # dark palette
```

Ask about the weather to see a tool-call round trip; anything else streams a
markdown answer. Use "New chat" to reset the thread.

To talk to a real backend, replace `DemoChatModelAdapter` with
`DataStreamChatModelAdapter(apiUrl: ...)` — the body and wire format match
`@assistant-ui/react-data-stream`.
