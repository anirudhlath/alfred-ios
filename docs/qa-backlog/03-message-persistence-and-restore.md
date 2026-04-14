# Message Persistence and Restore on Launch

**Feature:** Message Persistence (SwiftData + Keychain conversation ID)
**Priority:** critical
**Type:** functional

## Prerequisites
- iOS device or Simulator
- Alfred server running

## Test Steps
1. Launch the app fresh (first install or after clearing data).
2. Send 3-4 messages and receive Alfred responses.
3. Force-quit the app (swipe up from app switcher).
4. Relaunch the app.
5. Navigate to the Chat tab.
6. Send another message in the restored conversation.
7. Go to Settings and tap "Clear Session".
8. Observe the chat after session clear.

## Expected Result
- Step 1: A new conversation ID is generated and saved to Keychain. An empty chat view appears.
- Step 4-5: All previously sent and received messages are restored from SwiftData. The conversation ID is restored from Keychain, so the conversation continues in the same context.
- Step 6: The new message sends successfully with the same conversation ID, and the server maintains session context.
- Step 7-8: The conversation ID is cleared from Keychain. A new session is started (connectUseCase re-executes). Previous messages may still show from SwiftData until a new conversation begins.

## Notes
- Conversation ID is stored in Keychain (survives app reinstall on same device). Session ID is separate.
- `clearSession()` deletes both session_id and conversation_id from Keychain.
- If SwiftData migration fails on schema changes, messages may be lost — verify after app update scenarios.
- Edge case: kill the app mid-message-send. On relaunch, the unsent message should not appear (only persisted messages restore).
