"""
LenseScan Role-Based Access Control (RBAC).
FastAPI dependencies for authentication and authorization.
"""

from typing import List

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.security import decode_token
from app.database import get_db
from app.models.user import User

# OAuth2 scheme — extracts Bearer token from Authorization header
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    FastAPI dependency: Extract and validate the current user from JWT.

    Returns the User ORM object if the token is valid and user exists.
    Raises 401 if token is invalid or user not found.
    """
    payload = decode_token(token)
    username: str = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    return user


def require_role(allowed_roles: List[str]):
    """
    Factory function that returns a FastAPI dependency enforcing role-based access.

    Usage:
        @router.post("/admin-only", dependencies=[Depends(require_role(["admin"]))])
        async def admin_endpoint(): ...

    Args:
        allowed_roles: List of role strings that are permitted to access the endpoint.

    Returns:
        A FastAPI dependency function.
    """

    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role(s): {', '.join(allowed_roles)}",
            )
        return current_user

    return role_checker
