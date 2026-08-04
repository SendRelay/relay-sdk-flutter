# Relay Flutter SDK Example

Example Flutter application demonstrating the Relay Flutter SDK.

## Features

- Real-time task tracking
- Connection status monitoring
- Task status updates
- Rider location updates
- Event notifications

## Getting Started

1. Install dependencies:

```bash
flutter pub get
```

2. Update the backend endpoint in `lib/main.dart`:

```dart
const backendUrl = 'https://your-backend.com/api/relay/token';
```

3. Run the app:

```bash
flutter run
```

## Usage

1. Enter a task ID in the input field (e.g., "task-123")
2. Click "Start Tracking" to begin listening to task events
3. Watch real-time updates as the task progresses
4. Connection status is shown in the top-right corner

## Backend Setup

You need a backend endpoint that fetches WebSocket tokens from the Relay API.

### Example (Node.js)

```javascript
import express from 'express';
import { RelayClient } from '@relay-sdk/sdk-node';

const app = express();
app.use(express.json());

const relay = new RelayClient({
  apiKey: process.env.RELAY_API_KEY,
});

app.post('/api/relay/token', async (req, res) => {
  const { taskIds } = req.body;

  const { token } = await relay.auth.createWebSocketToken({
    scope: taskIds.map((id) => `task:${id}`),
    expiresIn: 3600,
  });

  res.json({ token });
});
```

## Events Demonstrated

- Task assigned
- Task in progress
- Task completed
- Task failed
- Rider location updates
- Connection state changes

## Learn More

- [Relay Flutter SDK Documentation](../README.md)
- [Relay API Documentation](https://docs.sendrelay.com.ng)
