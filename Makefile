.PHONY: pre-commit-install lint

pre-commit-install:
	uv run pre-commit install

lint:
	uv run pre-commit run --all-files
