.PHONY: build
build:
	zig build -p ./zig-out

test:
	zig build test

clean:
	rm -rf ./zig-out/*
