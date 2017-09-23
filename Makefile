all: compile

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

