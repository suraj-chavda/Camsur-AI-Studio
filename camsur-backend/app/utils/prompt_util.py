"""Render Jinja2 prompt templates stored in the database."""

from jinja2 import BaseLoader, Environment, select_autoescape

_env = Environment(
    loader=BaseLoader(),
    autoescape=select_autoescape(enabled_extensions=()),
)


def render_prompt(template_text: str, **kwargs) -> str:
    template = _env.from_string(template_text)
    return template.render(**kwargs).strip()
