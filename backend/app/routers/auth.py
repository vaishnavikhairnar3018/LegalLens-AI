"""
LenseScan Authentication Router.
Login and registration endpoints with JWT token generation.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.user import User, UserRole
from app.schemas.auth import LoginRequest, TokenResponse, UserCreate, UserResponse
from app.core.security import verify_password, get_password_hash, create_access_token
from app.core.rbac import get_current_user, require_role

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticate an officer and return a JWT access token.

    Uses OAuth2 password flow (username + password).
    The token must be included in subsequent requests as:
        Authorization: Bearer <token>
    """
    # Look up user by username
    result = await db.execute(
        select(User).where(User.username == form_data.username.lower())
    )
    user = result.scalar_one_or_none()

    if user is None or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated. Contact administrator.",
        )

    # Create JWT with user claims
    access_token = create_access_token(
        data={
            "sub": user.username,
            "role": user.role.value if isinstance(user.role, UserRole) else user.role,
            "full_name": user.full_name,
        }
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user.role.value if isinstance(user.role, UserRole) else user.role,
        username=user.username,
    )


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(["admin"])),
):
    """
    Register a new officer account. Admin-only endpoint.

    The requesting user must have the 'admin' role.
    """
    # Check if username already exists
    existing = await db.execute(
        select(User).where(User.username == user_data.username)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already exists",
        )

    # Create user
    new_user = User(
        username=user_data.username,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password),
        role=UserRole(user_data.role),
        is_active=True,
    )

    db.add(new_user)
    await db.flush()
    await db.refresh(new_user)

    return UserResponse(
        id=new_user.id,
        username=new_user.username,
        full_name=new_user.full_name,
        role=new_user.role.value if isinstance(new_user.role, UserRole) else new_user.role,
        is_active=new_user.is_active,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get the current authenticated user's profile."""
    return UserResponse(
        id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name,
        role=(
            current_user.role.value
            if isinstance(current_user.role, UserRole)
            else current_user.role
        ),
        is_active=current_user.is_active,
    )
