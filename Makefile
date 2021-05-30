SHELL:=/bin/bash
####
# images: register, gateway, provider, lotus full/daemon

####
# BR="257-gateway-dht-discover-offer-request"

# 2 pr for gatewayadmin and itest
BR?="269-gatewayadmin-add-new-requester-2"

# BR="247-gateway-paymentmgr-initialisation"

# BR="252-provider-paymentmgr-initialisation"

# BR="270-add-new-requester"

# BR="XJ1-20210528a"


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


#### Tests

t1: BR
	@set -e; \
	d=common; \
	d=fc-retrieval-$$d; \
	cd $(BR)/$$d; \
	pwd; \
	go test github.com/ConsenSys/fc-retrieval-common/pkg/fcrmessages

#### Total 4 steps below
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
		make useremote; \
		cd ..; \
	done

s2: s2A s3A s3

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
	set -e; \
	cd $(BR); \
	true for d in common; \
	for d in $(REPO_8); \
	do \
		d=fc-retrieval-$$d; \
		cd $$d; \
		git add -v -u :/ ; \
		pwd; \
		git status -s; \
		st=$$(git status --porcelain); \
		test -n "$$st" && git commit -a && git push origin $(BR); \
		test -z "$$st" && git push origin $(BR); \
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
