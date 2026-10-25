from decimal import Decimal

from app.config import Settings
from app.services.pricing_service import estimate_provider_cost_usd


def _settings(
    first_mp: str = "0.03",
    additional_mp: str = "0.015",
    input_mp: str = "0.015",
) -> Settings:
    return Settings(
        bfl_output_first_mp_usd=first_mp,
        bfl_output_additional_mp_usd=additional_mp,
        bfl_input_mp_usd=input_mp,
    )


def test_estimate_provider_cost_usd_one_megapixel_one_input():
    # 1 MP output (first-MP flat) + 1 MP input at input rate.
    cost = estimate_provider_cost_usd(1000, 1000, _settings(), num_input_images=1)
    assert cost == Decimal("0.0450")


def test_estimate_provider_cost_usd_matches_tiered_formula():
    # 2 MP output: first MP flat + one additional MP at the cheaper rate,
    # plus 2 MP of input cost (1 reference image, assumed same size as output).
    cost = estimate_provider_cost_usd(1000, 2000, _settings(), num_input_images=1)
    expected = Decimal("0.03") + Decimal("1") * Decimal("0.015") + Decimal("0.015") * Decimal("2")
    assert cost == expected.quantize(Decimal("0.0001"))


def test_estimate_provider_cost_usd_scales_with_input_image_count():
    one_input = estimate_provider_cost_usd(1000, 1000, _settings(), num_input_images=1)
    two_inputs = estimate_provider_cost_usd(1000, 1000, _settings(), num_input_images=2)
    assert two_inputs > one_input


def test_estimate_provider_cost_usd_rounds_up():
    cost = estimate_provider_cost_usd(333, 333, _settings(), num_input_images=1)
    mp = Decimal(333 * 333) / Decimal(1_000_000)
    exact = Decimal("0.03") + Decimal("0.015") * mp
    assert cost >= exact
