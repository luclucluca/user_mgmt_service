from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ModuleCreate(BaseModel):
    code: str = Field(min_length=2, max_length=32, examples=["CLOUD-ARCH"])
    name: str = Field(min_length=2, max_length=150, examples=["Cloud Architecture"])
    description: str | None = Field(default=None, max_length=2000)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        normalized = value.strip().upper()
        if len(normalized) < 2:
            raise ValueError("code must contain at least two non-whitespace characters")
        return normalized

    @field_validator("name")
    @classmethod
    def trim_name(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 2:
            raise ValueError("name must contain at least two non-whitespace characters")
        return normalized


class ModuleUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=32)
    name: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=2000)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("code must not be null")
        normalized = value.strip().upper()
        if len(normalized) < 2:
            raise ValueError("code must contain at least two non-whitespace characters")
        return normalized

    @field_validator("name")
    @classmethod
    def trim_name(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("name must not be null")
        normalized = value.strip()
        if len(normalized) < 2:
            raise ValueError("name must contain at least two non-whitespace characters")
        return normalized

class ModuleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    name: str
    description: str | None
    created_at: datetime
    updated_at: datetime


class ErrorResponse(BaseModel):
    code: str
    message: str