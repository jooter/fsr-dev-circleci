SHELL:=/bin/bash
####
# images: register, gateway, provider, lotus full/daemon

#### branches have deleted only locally
# BR="263-provideradmin-initialise-key-v2"
# BR="262-gatewayadmin-initialise-key-v2"
#### branches have deleted remotely and locally
# BR="XJ1-20210528"
# BR="XJ1-20210528a"
# BR="269-gatewayadmin-add-new-requester"
# BR="277-check-empty-key"
# BR="257-gateway-dht-discover-offer-request"
# BR="247-gateway-paymentmgr-initialisation"
# BR="252-provider-paymentmgr-initialisation"
# BR="252-provider-big-int-price"
# BR="278-fix-broken-itests"
# BR="247-gateway-paymentmgr-initialisation"
# BR="252-provider-paymentmgr-initialisation"
# BR="270-add-new-requester"
#### branches have deleted remotely

#### branches are working on
# BR="271-gateway-receives-payment"
BR="285-gateway-crash"


REPO_6=register gateway provider client gateway-admin provider-admin
REPO_8=common $(REPO_6) itest

####

default: t1

usage:
	@echo Usage:
	@echo make s1 BR=xxxx 
	@echo make s2 BR=xxxx
	@echo Or update BR in Makefile

# check variables
MSG:
	@test -n $(MSG)

BR:
	@test -n $(BR)

# build

build-gateway:
	cd $(BR); \
	cd fc-retrieval-gateway; \
	go build -v cmd/gateway/main.go

build-provider:
	cd $(BR); \
	cd fc-retrieval-provider; \
	go build -v cmd/provider/main.go

build-register:
	cd $(BR); \
	cd fc-retrieval-register; \
	go build -v cmd/register-server/main.go
	
build: build-gateway build-provider build-register

# -v /etc/timezone:/etc/timezone:ro \
# -v /etc/localtime:/etc/localtime:ro \
# ALLOW_EMPTY_PASSWORD=yes redis-server --protected-mode no > redis.out 2>&1 &
# redis-server --protected-mode no > redis.out 2>&1 &
# ALLOW_EMPTY_PASSWORD=yes redis-server --protected-mode no > redis.out 2>&1 &
# pkill redis-server
# docker run --name redis --network help -e ALLOW_EMPTY_PASSWORD=yes bitnami/redis:latest redis-server --requirepass "" --protected-mode no >redis.out 2>&1 &
# docker exec -it container_id_or_name ash


apline64:
	echo -e "FROM amd64/alpine\nRUN apk add libc6-compat" | docker build - -t alpinelib64:v1

redis:
	docker stop redis
	docker rm redis
	docker run --name redis --network help \
		-e TZ=Australia/Melbourne \
		-e ALLOW_EMPTY_PASSWORD=yes \
		redis:alpine redis-server --requirepass xxxx >redis.out 2>&1 &
	
register:
	cd $(BR); \
	cd fc-retrieval-register; \
	cp -u .env.example .env; \
	docker stop register; \
	docker rm register; \
	docker run -d \
		--env-file .env \
		--network help \
		-v $$(pwd):/app \
		--name register \
		-w /app \
		-e TZ=Australia/Melbourne \
		-e REDIS_PASSWORD=xxxx \
		alpinelib64:v1 ash -c "./main --host=0.0.0.0 --port=9020 >register.out 2>&1"
provider:
	cd $(BR); \
	cd fc-retrieval-provider; \
	cp -u .env.example .env; \
	for I in "" `seq 0 3| sed 's/^/-/'`; \
	do \
	dname=provider$$I;
	docker stop $$dname || true; \
	docker rm   $$dname || true; \
	docker run -d \
		--env-file .env \
		--network help \
		-v $$(pwd):/app \
		--name $$dname \
		-w /app \
		-e TZ=Australia/Melbourne \
		-e REDIS_PASSWORD=xxxx \
		alpinelib64:v1 ash -c "./main >$$dname.out 2>&1"; \
	done
gateway:
	cd $(BR); \
	cd fc-retrieval-gateway; \
	cp -u .env.example .env; \
	for I in "" `seq 0 32| sed 's/^/-/'`; \
	do \
	dname=gateway$$I;
	docker stop $$dname || true; \
	docker rm   $$dname || true; \
	docker run -d \
		--env-file .env \
		--network help \
		-v $$(pwd):/app \
		--name $$dname \
		-w /app \
		-e TZ=Australia/Melbourne \
		-e REDIS_PASSWORD=xxxx \
		alpinelib64:v1 ash -c "./main >$$dname.out 2>&1"; \
	done
hosts:
	cd $(BR); \
	cd fc-retrieval-itest; \
	docker ps -q \
        | xargs -n 1 docker inspect --format \
        '{{ .Name }} {{range .NetworkSettings.Networks}} {{.IPAddress}}{{end}}' \
        | sed 's#^/##' | sed 's/$$/.nip.io/' >./hosts
itest:
	cd $(BR); \
	cd fc-retrieval-itest; \
	export ITEST_CALLING_FROM_CONTAINER=yes; \
	export LOG_LEVEL=debug; \
	export LOG_TARGET=STDOUT; \
	export LOG_SERVICE_NAME=itest; \
	export HOSTALIASES=`realpath hosts`; \
	free -h; \
	true go test -count=1 -p 1 -v -failfast github.com/ConsenSys/fc-retrieval-itest/pkg/poc2; \
	go test -count=1 -p 1 -v -failfast github.com/ConsenSys/fc-retrieval-itest/pkg/poc2 \
	-run 'TestPublishDHTOffer|TestInitialiseProviders|TestInitialiseGateways'

lotus-start:
	docker start lotus-daemon >lotus.out 2>&1 &
redis-start:
	docker start redis
register-start:
	docker start register
provider-start:
	for I in "" `seq 0 3| sed 's/^/-/'`; do \
		echo provider$$I; \
	done | xargs docker start
gateway-start:
	for I in "" `seq 0 32| sed 's/^/-/'`; do \
		echo gateway$$I; \
	done | xargs docker start

lotus-stop:
	docker stop lotus-daemon || true
redis-stop:
	docker stop redis || true
register-stop:
	docker stop register || true
provider-stop:
	for I in "" `seq 0 3| sed 's/^/-/'`; do \
		echo provider$$I; \
	done | xargs docker stop
gateway-stop:
	for I in "" `seq 0 32| sed 's/^/-/'`; do \
		echo gateway$$I; \
	done | xargs docker stop

docker-rebuild: apline64 redis register provider gateway hosts itest
docker-stop: gateway-stop provider-stop register-stop redis-stop lotus-stop
docker-start: lotus-start redis-start register-start provider-start gateway-start

#### Tests

t1: BR
	@set -e; \
	d=common; \
	d=fc-retrieval-$$d; \
	cd $(BR)/$$d; \
	pwd; \
	go test github.com/ConsenSys/fc-retrieval-common/pkg/fcrmessages

#### Total 4 steps below
s0: BR
	@set -x;
	@cd $(BR);
	@for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd /home/localadmin/localbuild/$(BR)/$$d && \
		true git remote set-url origin git@github.com:ConsenSys/$$d.git && \
		git push origin --delete $(BR) && \
		pwd; \
	done

# check out 
s1: BR
	@set -e; \
	mkdir $(BR); \
	cd $(BR); \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		git clone https://github.com/ConsenSys/$$d.git; \
		cd $$d; \
		git remote set-url origin git@github.com:ConsenSys/$$d.git; \
		git switch -c $(BR); \
		cd ..; \
	done


# update dependency
# useremote may break itest
s2A: BR
	set -e; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		git fetch; \
		git merge origin/main; \
		cd ..; \
	done

s2B: BR
	set -e; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		make useremote; \
		cd ..; \
	done


s2: s2A s2B s3A s3

s3A: BR
	set -e; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		git -P diff --unified=0 go.mod; \
		pwd; \
		cd ..; \
	done


# check
s3: s3A BR 
	set -e; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		pwd; \
		git status -s; \
		cd ..; \
	done

# push
s4: BR
	set -ex; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		git add -v -u :/ ; \
		pwd; \
		git status -s; \
		make useremote; \
		st=$$(git status -s go.mod); \
	       	test -n "$$st" && git commit -m "update dependency in go.mod" go.mod go.sum;  \
		st=$$(git status -s); \
		test -n "$$st" && git commit -a && git push origin HEAD; \
		test -z "$$st" && git push origin HEAD; \
		cd ..; \
	done

# Pull request
s5: BR
	@set -e; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		true echo "https://github.com/ConsenSys/$$d/compare/$(BR)"; \
		echo "https://github.com/ConsenSys/$$d/pull/new/$(BR)"; \
	done

#####
# addtional helper, you may need

# set url
a1: BR
	@set -e; \
	cd $(BR); \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		git remote set-url origin git@github.com:ConsenSys/$$d.git; \
		cd ..; \
	done

# check clean source dir
a2: BR
	set -e; \
	d=common; \
	d=fc-retrieval-$$d; \
	cd $(BR)/$$d; \
	git status -s; \
	st=$$(git status --porcelain); \
	test -z "$$st"; \
	echo local source dir is clean

a3: BR
	@set -e; \
	cd $(BR); \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		pwd; \
		git status -s; \
		cd ..; \
	done

r1: BR
	@set -e; \
	cd $(BR); \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		make useremote; \
		git diff go.mod; \
		cd ..; \
	done

r2: BR
	@set -e; \
	cd $(BR); \
	for d in gateway provider register itest; \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		/usr/bin/time -vv make build tag; \
		cd ..; \
	done

r3: BR
	@set -e; \
	cd $(BR); \
	d=itest; \
	d=fc-retrieval-$$d; \
        cd $$d; \
        /usr/bin/time -vv make itestlocal

d1: BR
	@set -e; \
	cd $(BR); \
	for d in $(REPO_8); \
	do \
		~/go/bin/goplantuml \
		-recursive \
		-show-implementations \
		-show-connection-labels \
		-show-aliases \
		-show-options-as-note \
		-aggregate-private-members \
		-show-aggregations \
		-show-compositions \
		-output 1$$d.puml \
		fc-retrieval-$$d; \
		/opt/plantuml/plantuml -tsvg 1$$d.puml; \
	done

#
# 2: not -aggregate-private-members \
# 3: not -show-aggregations \
# 4: not -show-compositions \
