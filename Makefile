build:
	docker compose build
run:
	docker compose run --rm shell-quest
test:
	bash tests/test-conditions.sh
