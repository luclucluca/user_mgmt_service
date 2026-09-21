from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Module, UserModule
from app.schemas import ModuleCreate, ModuleUpdate


class DuplicateModuleCodeError(Exception):
    pass


def list_modules(db: Session) -> list[Module]:
    statement = select(Module).order_by(Module.code)
    return list(db.scalars(statement))


def get_module(db: Session, module_id: UUID) -> Module | None:
    return db.get(Module, str(module_id))


def create_module(db: Session, payload: ModuleCreate) -> Module:
    module = Module(**payload.model_dump())
    db.add(module)
    return _commit(db, module)


def update_module(db: Session, module: Module, payload: ModuleUpdate) -> Module:
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(module, field, value)
    return _commit(db, module)


def delete_module(db: Session, module: Module) -> None:
    db.delete(module)
    db.commit()


def assign_module_to_user(db: Session, user_id: UUID, module_id: UUID) -> None:
    key = (str(user_id), str(module_id))
    if db.get(UserModule, key) is not None:
        return

    db.add(UserModule(user_id=key[0], module_id=key[1]))
    db.commit()


def _commit(db: Session, module: Module) -> Module:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise DuplicateModuleCodeError from exc
    db.refresh(module)
    return module