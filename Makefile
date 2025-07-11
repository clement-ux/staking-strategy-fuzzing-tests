# Environment Variables
-include .env

# Export Variables
.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

# Default Target
default:
	forge fmt && forge build

# Installation
install:
	foundryup
	forge soldeer install
	rm -f requirements.txt


# Cleaning Targets
clean:
	rm -f -r out
	rm -f -r cache

clean-all: 
	$(MAKE) clean
	rm -f -r dependencies
	rm -f -r soldeer.lock

# Testing Targets
test:
	forge test --summary --detailed

t: 
	$(MAKE) test

# Coverage
coverage:
	forge coverage --report lcov
	lcov --ignore-errors unused --remove ./lcov.info -o ./lcov.info.pruned "test/*" "script/*"

coverage-html:
	make coverage
	genhtml ./lcov.info.pruned -o report --branch-coverage --output-dir ./coverage

# Override default `test` and `coverage` targets
.PHONY: default install clean clean-all coverage test