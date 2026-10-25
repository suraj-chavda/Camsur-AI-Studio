from fastapi import APIRouter, Query

from app.core.response import ok
from app.dependencies import CreditServiceDep, CurrentUserDep
from app.schemas.credit_schema import CreditPurchaseRequest

router = APIRouter(prefix="/credits", tags=["credits"])


@router.get("/balance")
async def get_credit_balance(
    current_user: CurrentUserDep,
    credits: CreditServiceDep,
):
    balance = await credits.get_balance(current_user.id)
    return ok(data=balance.model_dump())


@router.get("/packages")
async def list_credit_packages(
    credits: CreditServiceDep,
):
    """Public catalog — plans load even if the session is refreshing."""
    packages = await credits.list_packages()
    return ok(data=[package.model_dump() for package in packages])


@router.get("/settings")
async def get_credit_settings(
    credits: CreditServiceDep,
):
    settings = await credits.get_settings()
    return ok(data=settings.model_dump())


@router.get("/transactions")
async def list_credit_transactions(
    current_user: CurrentUserDep,
    credits: CreditServiceDep,
    limit: int = Query(default=50, ge=1, le=100),
):
    transactions = await credits.list_transactions(current_user.id, limit=limit)
    return ok(data=[transaction.model_dump() for transaction in transactions])


@router.post("/purchases")
async def purchase_credit_package(
    body: CreditPurchaseRequest,
    current_user: CurrentUserDep,
    credits: CreditServiceDep,
):
    """Top-up credits by buying a catalog package (not a subscription)."""
    purchase = await credits.purchase_package(
        user_id=current_user.id,
        package_slug=body.package_slug,
        idempotency_key=body.idempotency_key,
    )
    return ok(
        message="Top-up completed" if purchase.status == "completed" else "Top-up started",
        data=purchase.model_dump(),
    )
