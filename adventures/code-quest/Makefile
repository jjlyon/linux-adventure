.PHONY: build run test clean

build:
	docker compose build

run:
	docker compose run --rm code-quest

test:
	bash tests/test-conditions.sh

clean:
	docker rmi code-quest 2>/dev/null || true
