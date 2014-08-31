all: clean
	./node_modules/coffee-script/bin/coffee --output lib --compile src

clean:
	rm -rvf ./lib/*