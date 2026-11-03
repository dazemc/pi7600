from sqlalchemy import select

from Models import MessageCreate


def message_row(**overrides) -> MessageCreate:
    data = {
        "message_index": "7",
        "message_type": "REC READ",
        "message_originating_address": "+15551234567",
        "message_destination_address": None,
        "message_date": "2026-01-01",
        "message_time": "12:00:00",
        "message_contents": "hello",
        "is_partial": False,
        "in_sim_memory": True,
        "is_sent": None,
    }
    data.update(overrides)
    return MessageCreate(**data)


async def test_list_sms_empty(client, auth_headers):
    response = await client.get("/sms", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == []


async def test_send_sms_success(client, auth_headers, app):
    response = await client.post(
        "/sms",
        headers=auth_headers,
        json={"number": "+15551234567", "msg": "hi"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["message_contents"] == "hi"
    assert body["is_sent"] is True
    assert app.state.sms.sent == [("+15551234567", "hi")]


async def test_send_sms_failure_returns_502_and_persists(
    client, auth_headers, app, db_session
):
    app.state.sms.fail_send = True
    response = await client.post(
        "/sms",
        headers=auth_headers,
        json={"number": "+15551234567", "msg": "will fail"},
    )
    assert response.status_code == 502

    rows = (await db_session.execute(select(MessageCreate))).scalars().all()
    assert len(rows) == 1
    assert rows[0].is_sent is False
    assert rows[0].message_contents == "will fail"


async def test_delete_sim_message_uses_modem_index(
    client, auth_headers, app, db_session
):
    row = message_row(message_index="7", in_sim_memory=True)
    db_session.add(row)
    await db_session.commit()
    await db_session.refresh(row)

    response = await client.delete(f"/sms/delete/{row.id}", headers=auth_headers)
    assert response.status_code == 202
    assert app.state.sms.deleted == [7]

    remaining = (await db_session.execute(select(MessageCreate))).scalars().all()
    assert remaining == []


async def test_delete_db_only_message_does_not_touch_modem(
    client, auth_headers, app, db_session
):
    row = message_row(message_index=None, in_sim_memory=False)
    db_session.add(row)
    await db_session.commit()
    await db_session.refresh(row)

    response = await client.delete(f"/sms/delete/{row.id}", headers=auth_headers)
    assert response.status_code == 202
    assert app.state.sms.deleted == []


async def test_delete_missing_message_returns_404(client, auth_headers):
    response = await client.delete("/sms/delete/999", headers=auth_headers)
    assert response.status_code == 404


async def test_cleanup_removes_sim_messages(client, auth_headers, app, db_session):
    db_session.add(message_row(message_index="1", in_sim_memory=True))
    db_session.add(message_row(message_index="2", in_sim_memory=True))
    await db_session.commit()

    response = await client.delete("/sms/cleanup/", headers=auth_headers)
    assert response.status_code == 202
    assert app.state.sms.deleted == [1, 2]

    rows = (await db_session.execute(select(MessageCreate))).scalars().all()
    assert all(row.in_sim_memory is False for row in rows)
