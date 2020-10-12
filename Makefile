BABASHKA_CLASSPATH := $(shell clojure -A:test -Spath)
PATH  := $(PWD)/target:$(PATH)
ENV   := PATH=$(PATH) BABASHKA_CLASSPATH=$(BABASHKA_CLASSPATH)
SHELL := env $(ENV) /bin/bash

.PHONY: dev test

all: release

clean:
	rm -rf target resources/main.js .shadow-cljs

target/install-babashka:
	mkdir -p target
	curl -s https://raw.githubusercontent.com/borkdude/babashka/master/install -o target/install-babashka
	chmod +x target/install-babashka

target/bb: target/install-babashka
	target/install-babashka $(PWD)/target
	touch target/bb

bb: target/bb

node_modules: package.json
	npm ci

resources/main.js:
	clojure -A:cljs:shadow-cljs release client

resources/ws.js:
	npx browserify --node \
		--exclude bufferutil \
		--exclude utf-8-validate \
		--standalone Server \
		node_modules/ws > resources/ws.js

dev: node_modules release
	clojure -A:dev:cider:cljs:dev-cljs:shadow-cljs watch client

dev/node: node_modules resources/ws.js release
	clojure -A:dev:cider:cljs:dev-cljs:shadow-cljs watch node client

release: node_modules resources/main.js resources/ws.js

lint/check:
	clojure -A:nrepl:check

lint/kondo:
	clojure -A:kondo --lint dev src test

lint/cljfmt:
	clojure -A:cljfmt check

lint: lint/check lint/kondo lint/cljfmt

target:
	mkdir -p target

test/jvm: release target
	clojure -A:test -m portal.test-runner

test/bb: release bb
	bb -m portal.test-runner

test: test/jvm test/bb

fmt:
	clojure -A:cljfmt fix

pom.xml: deps.edn
	clojure -Spom

install:
	mvn install

deploy: pom.xml
	mvn deploy

ci: lint test

e2e/jvm: release
	@echo "running e2e tests for jvm"
	@clojure -A:test -m portal.e2e | clojure -e "(set! *warn-on-reflection* true)" -r

e2e/node: release
	@echo "running e2e tests for node"
	@clojure -A:test -m portal.e2e | clojure -A:cljs -m cljs.main -re node

e2e/bb: release bb
	@echo "running e2e tests for babashka"
	@clojure -A:test -m portal.e2e | bb

e2e/web: release
	@echo "running e2e tests for web"
	@echo "please wait for browser to open before proceeding"
	@clojure -A:test -m portal.e2e web | clojure -A:cljs -m cljs.main

e2e: e2e/jvm e2e/node e2e/web e2e/bb

main/jvm:
	cat deps.edn | clojure -m portal.main edn

main/bb:
	cat deps.edn | bb -cp src:resources -m portal.main edn

demo: bb release
	./build-demo
