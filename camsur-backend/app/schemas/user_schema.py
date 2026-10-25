from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    display_name: Optional[str] = None
    device_id: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)


class SocialLoginRequest(BaseModel):
    """Mobile app performs native Google/Apple sign-in and sends us the ID token."""

    provider: Literal["google", "apple"]
    id_token: str = Field(..., min_length=10, max_length=4096)
    access_token: Optional[str] = Field(default=None, max_length=4096)
    nonce: Optional[str] = Field(default=None, max_length=512)
    device_id: Optional[str] = None


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=20, max_length=2048)


class UserOut(BaseModel):
    id: str
    email: str
    display_name: Optional[str] = None
    device_id: Optional[str] = None
    role: str = "user"
    created_at: datetime


class AuthOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut
