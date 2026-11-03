import main


async def test_healthz(client):
    response = await client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


async def test_readyz(client):
    response = await client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


async def test_status_endpoint(client, auth_headers, monkeypatch):
    async def fake_ping(interface, target, timeout_seconds=5.0):
        return True

    monkeypatch.setattr(main, "run_ping", fake_ping)

    response = await client.get("/", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["cnum"] == "+15551234567"
    assert body["data"] == "OK"
    assert body["dns"] == "OK"
    assert body["timezone"] == 0


async def test_status_endpoint_reports_network_failures(
    client, auth_headers, monkeypatch
):
    async def fake_ping(interface, target, timeout_seconds=5.0):
        return False

    monkeypatch.setattr(main, "run_ping", fake_ping)

    response = await client.get("/", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["data"] == "ERROR"
    assert body["dns"] == "ERROR"


async def test_status_endpoint_handles_malformed_modem_output(
    client, auth_headers, monkeypatch, app
):
    async def fake_ping(interface, target, timeout_seconds=5.0):
        return False

    async def broken_send_at(command, back, timeout_seconds=3):
        return "ERROR"

    monkeypatch.setattr(main, "run_ping", fake_ping)
    monkeypatch.setattr(app.state.modem, "send_at", broken_send_at)

    response = await client.get("/", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["at"] == "ERROR"
    assert body["cnum"] == "ERROR"
    assert body["csq"] == "ERROR"
