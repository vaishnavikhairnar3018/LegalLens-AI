"""
LenseScan Authentication Schemas.
Pydantic models for auth request/response validation.
"""

from pydantic import BaseModel, Field, field_validator, ConfigDict
import re


class LoginRequest(BaseModel):
    """Login request payload."""
    username: str = Field(..., min_length=3, max_length=150)
    password: str = Field(..., min_length=8, max_length=128)


class TokenResponse(BaseModel):
    """JWT token response."""
    access_token: str
    token_type: str = "bearer"
    role: str
    username: str


class UserCreate(BaseModel):
    """User registration payload."""
    username: str = Field(..., min_length=3, max_length=150)
    full_name: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)
    role: str = Field(default="officer")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """Only allow alphanumeric characters, underscores, and dots."""
        if not re.match(r"^[a-zA-Z0-9_.]+$", v):
            raise ValueError(
                "Username must contain only letters, numbers, underscores, or dots"
            )
        return v.lower()

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        """Enforce minimum password complexity."""
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", v):
            raise ValueError("Password must contain at least one special character")
        return v

    @field_validator("role")
    @classmethod
    def validate_role(cls, v: str) -> str:
        """Ensure role is valid."""
        allowed = {"officer", "admin", "supervisor"}
        if v.lower() not in allowed:
            raise ValueError(f"Role must be one of: {', '.join(allowed)}")
        return v.lower()


class UserResponse(BaseModel):
    """Public user information response."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    full_name: str
    role: str
    is_active: bool
