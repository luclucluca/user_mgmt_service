# Module Service

Der Service verwaltet Module über eine REST-API und speichert sie in MySQL.

## API

| Methode | Pfad | Beschreibung | Status |
| --- | --- | --- | --- |
| `POST` | `/api/v1/modules` | Modul anlegen | `201` |
| `GET` | `/api/v1/modules` | Alle Module lesen | `200` |
| `GET` | `/api/v1/modules/{module_id}` | Modul lesen | `200` |
| `PATCH` | `/api/v1/modules/{module_id}` | Modul teilweise aktualisieren | `200` |
| `DELETE` | `/api/v1/modules/{module_id}` | Modul löschen | `204` |
| `PUT` | `/api/v1/users/{user_id}/modules/{module_id}` | Modul einem User zuweisen | `204` |

Ein Modul enthält folgende Felder:

```json
{
  "id": "c02f58f2-3aca-4f1e-8076-bacf6f1999e6",
  "code": "CLOUD-ARCH",
  "name": "Cloud Architecture",
  "description": "Designing reliable and scalable cloud systems",
  "created_at": "2026-09-16T09:02:09",
  "updated_at": "2026-09-16T09:02:09"
}
```

Die OpenAPI-Dokumentation ist unter `/docs` erreichbar.

Die Zuweisung ist idempotent: Wiederholte `PUT`-Requests für denselben User und dasselbe
Modul erzeugen nur einen Eintrag in `users_modules`. Die User-ID stammt aus dem
`user_mgmt_service`; der Module Service prüft nur, ob das angegebene Modul existiert.

## Anwendung starten

```bash
python -m venv .venv
source .venv/bin/activate
pip install uv
uv sync --frozen --extra dev
cp .env.example .env
uvicorn app.main:app --reload --port 8080
```
