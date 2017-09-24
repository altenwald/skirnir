all: compile

bootstrap:
	mix local.rebar --force
	mix local.hex --force

compile: deps
	mix compile

deps: mix.lock
	mix deps.get

run: compile
	iex -S mix

clean:
	-rm -rf deps _build

test: compile
	mix test --cover

.PHONY: test

