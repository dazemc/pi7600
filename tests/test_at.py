async def test_at_requires_auth(client):
    response = await client.post("/at", json={"cmd": "AT"})
    assert response.status_code == 401


async def test_at_rejects_non_admin(client, auth_headers):
    response = await client.post("/at", headers=auth_headers, json={"cmd": "AT+CSQ"})
    assert response.status_code == 403


async def test_at_allows_admin(client, admin_headers, app):
    response = await client.post("/at", headers=admin_headers, json={"cmd": "AT+CSQ"})
    assert response.status_code == 202
    assert "OK" in response.json()
    assert app.state.modem.commands[-1] == "AT+CSQ"


async def test_at_audit_logs_command(client, admin_headers, caplog):
    with caplog.at_level("INFO", logger="uvicorn.pi7600"):
        response = await client.post(
            "/at", headers=admin_headers, json={"cmd": "AT+CSQ"}
        )
    assert response.status_code == 202
    assert "AT audit" in caplog.text
    assert "AT+CSQ" in caplog.text
