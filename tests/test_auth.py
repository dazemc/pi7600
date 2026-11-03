from datetime import timedelta

from Utils import create_jwt


async def test_token_success(client, user):
    response = await client.post(
        "/token", data={"username": user.user_name, "password": "secret"}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]


async def test_token_wrong_password(client, user):
    response = await client.post(
        "/token", data={"username": user.user_name, "password": "wrong"}
    )
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


async def test_token_unknown_user(client):
    response = await client.post(
        "/token", data={"username": "nobody", "password": "secret"}
    )
    assert response.status_code == 401


async def test_token_disabled_user(client, disabled_user):
    response = await client.post(
        "/token",
        data={"username": disabled_user.user_name, "password": "secret"},
    )
    assert response.status_code == 401


async def test_missing_token_returns_401(client):
    response = await client.get("/sms")
    assert response.status_code == 401


async def test_invalid_token_returns_401(client):
    response = await client.get("/sms", headers={"Authorization": "Bearer not-a-token"})
    assert response.status_code == 401


async def test_expired_token_returns_401(client, user):
    token = create_jwt({"sub": user.user_name}, expires_delta=timedelta(seconds=-1))
    response = await client.get("/sms", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401


async def test_disabled_user_token_returns_401(client, disabled_headers):
    response = await client.get("/sms", headers=disabled_headers)
    assert response.status_code == 401


async def test_valid_token_allows_access(client, auth_headers):
    response = await client.get("/sms", headers=auth_headers)
    assert response.status_code == 200
