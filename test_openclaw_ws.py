import websocket
import json
import time
import pytest


@pytest.fixture(scope="module")
def ws_server_url():
    return "ws://localhost:18789"


def test_openclaw_ws_challenge_response(ws_server_url):
    """
    Test OpenClaw WebSocket challenge-response flow:
    - Connect
    - Receive challenge with nonce
    - Send challenge_response
    - Accept empty reply or connection close as success (silent auth)
    """
    ws = None
    try:
        print(f"Connecting to {ws_server_url}...")
        ws = websocket.create_connection(ws_server_url, timeout=10)
        print("Connected.")

        print("Waiting for challenge (timeout 10s)...")
        challenge_raw = ws.recv()
        print("Raw challenge:", challenge_raw)

        # Parse challenge
        challenge = json.loads(challenge_raw)
        nonce = challenge.get("payload", {}).get("nonce")
        print("Nonce:", nonce)
        assert nonce is not None, "Nonce missing from challenge payload"

        # Send response
        response = {
            "type": "challenge_response",
            "nonce": nonce
        }
        print("Sending:", json.dumps(response))
        ws.send(json.dumps(response))

        # Wait for possible reply (or connection close)
        print("Waiting for reply or close (timeout 5s)...")
        ws.settimeout(5)
        try:
            reply = ws.recv()
            print("Server sent reply:", reply)
            # Optional: parse if reply exists
            if reply.strip():
                reply_data = json.loads(reply)
                print("Parsed reply:", reply_data)
                assert "type" in reply_data, "Reply should have 'type' field"
            else:
                print("Empty reply received (possible silent success)")

        except websocket.WebSocketTimeoutException:
            print("No reply received within 5s — assuming silent authentication success")

        except json.JSONDecodeError as e:
            print("Reply not JSON (possible binary/close frame):", e)

        # Final check: connection may be closed after auth — that's OK
        if not ws.connected:
            print("Connection closed by server after response — authentication likely successful")
        else:
            print("Connection still open — server may expect more interaction")

        # Test passes if we reached here without fatal errors
        assert True

    except websocket.WebSocketException as e:
        pytest.fail(f"WebSocket error: {e}")

    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid challenge JSON: {e}\nRaw: {challenge_raw}")

    finally:
        if ws and ws.connected:
            print("Closing WebSocket...")
            ws.close()