## rebar3.mk
## Version 0.3.2
## Copyright 2023-2025 Jesse Gumm
## MIT License
##
## This is a tool to help you either use the existing rebar3 in the system or
## build a new one just for a specific project.
## 
## How to use:
##  1) include it in your Makefile with:
##
##         include rebar3.mk
##
##  2) Update any rules in your makefile so that rebar3 is required, and then
##     change the rebar3 calls to use "$(REBAR)" instead of "rebar3" or "./rebar3"
##
##     For example, change this:
##
##         compile:
##             rebar3 compile
##     
##     To This:
##
##         compile: rebar3
##             $(REBAR) compile


## TODO Notes:
## I'd like to update this to take a $MINIMUM_REBAR_VERSION variable
## to check the current version of rebar3, and if the version is less than
## the $MINIMUM_REBAR_VERSION, then download/compile the latest version

## Similarly, I'd like to add a $(FORCE_REBAR_VERSION) variable which *forces*
## the project to use that specific verion. This would work similarly by
## comparing versions, and if the version is different, download/compile that
## specific version locally.

## Finally, the logic here should be changed slightly to check for a local (in
## this project) version of rebar3 and use that first. If that doesn't exist,
## then fall back to checking the path, and finally, if that still doesn't
## exist, then (and only then) downloading and compiling rebar3.

## A more advanced version of this checker would also verify that rebar3
## actually runs and doesn't just throw an error.

MSG_PREFIX="rebar3.mk: "
REBAR3_MK_VERSION = 0.3.2
## master here means pull the latest version
NEW_REBAR3_MK_VERSION ?= master
REBAR3_MK_REPO = choptastic/rebar3.mk
REBAR3_MK_RAW_URL = https://raw.githubusercontent.com/$(REBAR3_MK_REPO)/$(NEW_REBAR3_MK_VERSION)/rebar3.mk

REPO ?= erlang/rebar3
REPO_SVC_NAME ?= Github
REPO_URL ?= https://github.com/$(REPO).git
REBAR_LATEST_VERSION ?= $(shell curl -s "https://api.github.com/repos/$(REPO)/releases/latest" | grep '"tag_name"' | cut -d '"' -f 4)

REBAR_VERSION ?= $(REBAR_LATEST_VERSION)

REBAR_PATH = $(shell which rebar3)

ifeq ($(REBAR_PATH),)
REBAR = $(shell pwd)/rebar3
RANDOM_STRING := rebar3_$(shell openssl rand -hex 16)
rebar3:
	@while true; do\
		echo "$(MSG_PREFIX)rebar3 not found! (in either the local directory, or in the PATH)"; \
		echo "$(MSG_PREFIX)Would you like to clone the rebar3 repo and and build it this local project?"; \
		echo "$(MSG_PREFIX) * Latest release: $(REBAR_LATEST_VERSION) (REBAR_LATEST_VERSION)"; \
		echo "$(MSG_PREFIX) * Release to download: $(REBAR_VERSION) (REBAR_VERSION)"; \
		echo "$(MSG_PREFIX) * From $(REPO_SVC_NAME) (REPO_SVC_NAME): $(REPO) (REPO)"; \
		echo "$(MSG_PREFIX)   URL: $(REPO_URL) (REPO_URL)"; \
		read -r -p " ===> Proceed to clone and build rebar3 based on the above? [Y/N] " yn; \
		case $$yn in \
			[Yy]*) \
				REPO="$(REPO)" REPO_URL="$(REPO_URL)" REBAR_VERSION="$(REBAR_VERSION)" make update_rebar3; \
				break;; \
			[Nn]*) \
				echo "$(MSG_PREFIX)Aborting! You will need to install rebar3 locally or allow rebar3.mk"; \
				echo "$(MSG_PREFIX)to build a project-local version. See rebar3.org for more information."; \
				exit 1;; \
			*) \
				echo "$(MSG_PREFIX)Please answer Y or N";; \
		esac; \
	done
else
REBAR = rebar3
rebar3:
endif

rebar3_mk:
	@echo "$(MSG_PREFIX)Getting rebar3.mk $(NEW_REBAR3_MK_VERSION) (NEW_REBAR3_MK_VERSION) from $(REBAR3_MK_REPO) (REBAR3_MK_REPO)"
	@echo "$(MSG_PREFIX)Downloading URL: $(REBAR3_MK_RAW_URL) (REBAR3_MK_RAW_URL)"
	@curl -O $(REBAR3_MK_RAW_URL)

update_rebar3:
	@echo "$(MSG_PREFIX)Fetching and compiling rebar3 ($(REBAR_VERSION)) for this local project..."
	@(cd /tmp && \
	git clone $(REPO_URL) $(RANDOM_STRING) -q && \
	cd $(RANDOM_STRING) && \
	git fetch --tags -q && \
	git checkout $(REBAR_VERSION) -q && \
	./bootstrap)
	@echo "$(MSG_PREFIX)Installing rebar3 into your project's directory..."
	@(mv /tmp/$(RANDOM_STRING)/rebar3 .)
	@echo "$(MSG_PREFIX)Cleaning up..."
	@(rm -fr /tmp/$(RANDOM_STRING))

install_rebar3: rebar3
	@(./rebar3 local install)
