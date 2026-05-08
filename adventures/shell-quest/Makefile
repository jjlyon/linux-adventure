.PHONY: build run test clean

build:
	docker compose build

run: build
	docker compose run --rm shell-quest

test:
	bash tests/test-conditions.sh

clean:
	docker rmi shell-quest 2>/dev/null || true
