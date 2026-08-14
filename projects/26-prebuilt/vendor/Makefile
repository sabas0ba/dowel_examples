# dowel の外側のビルド。ADR-0049 の想定する相手（cargo / zig / go / vendor の
# SDK）の代わりに、ただの Makefile を置いてある。dowel はこれを走らせない。
libengine.a: engine.c
	cc -c engine.c -o engine.o
	ar rcs $@ engine.o
