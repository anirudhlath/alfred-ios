# Clear Session from Settings

**Feature:** Clear Session
**Priority:** high
**Type:** functional

## Prerequisites
- App with an active session and message history
- Alfred server running

## Test Steps
1. Send several messages to establish a conversation with context.
2. Navigate to the Settings tab.
3. Tap "Clear Session" (red destructive button).
4. Navigate back to the Chat tab.
5. Send a message referencing earlier conversation context (e.g., "What did I just ask you?").

## Expected Result
- Step 3: The session ID and conversation ID are cleared from Keychain. A new WebSocket connection is established (connectUseCase re-executes).
- Step 4: The chat may still show old messages from SwiftData (since message store is not cleared), but the server treats this as a new session.
- Step 5: The server has no context of the previous conversation — the response should not reference prior messages.

## Notes
- `clearSession()` calls `KeychainStore.delete` for both `sessionId` and `conversationId`, then re-executes `connectUseCase`.
- This does NOT clear SwiftData messages — only the session/conversation identifiers. The UI may still show old messages until a new conversation starts.
- There is no confirmation dialog before clearing — tapping the button acts immediately. Consider whether this is acceptable UX.
- Verify the server assigns a new session_id after reconnect (check server logs).
