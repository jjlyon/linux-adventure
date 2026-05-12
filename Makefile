.PHONY: shell-quest code-quest build-all

shell-quest:
	cd adventures/shell-quest && $(MAKE) run

code-quest:
	cd adventures/code-quest && $(MAKE) run

build-all:
	cd adventures/shell-quest && $(MAKE) build
	cd adventures/code-quest && $(MAKE) build
