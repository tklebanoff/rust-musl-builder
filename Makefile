default:
	docker build . -t rust-musl-builder

alias:
	@echo "add this alias for rust-musl-builder functionality in your shell:"
	@echo "alias rust-musl-builder='docker run --rm -it -v "$(pwd)":/home/rust/src rust-musl-builder'"
