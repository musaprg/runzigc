.PHONY: build
build:
	zig build -p ./zig-out

clean:
	rm -rf ./zig-out/*
