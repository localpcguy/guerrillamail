all: clean
	coffee --output lib --compile src

clean:
	rm -rvf ./lib/*