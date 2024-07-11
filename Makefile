all: build

# Get the absolute path and name of the current directory.
PWD := $(abspath .)
BASE_DIR := $(notdir $(PWD))

# BIN_OUT is the directory containing the built binaries.
export BIN_OUT ?= bin

################################################################################
##                             VERIFY GO VERSION                              ##
################################################################################
# Go 1.11+ required for Go modules.
GO_VERSION_EXP := "go1.11"
GO_VERSION_ACT := $(shell a="$$(go version | awk '{print $$3}')" && test $$(printf '%s\n%s' "$${a}" "$(GO_VERSION_EXP)" | sort | tail -n 1) = "$${a}" && printf '%s' "$${a}")
ifndef GO_VERSION_ACT
$(error Requires Go $(GO_VERSION_EXP)+ for Go module support)
endif
MOD_NAME := $(shell head -n 1 <go.mod | awk '{print $$2}')

################################################################################
##                             VERIFY BUILD PATH                              ##
################################################################################
ifneq (on,$(GO111MODULE))
export GO111MODULE := on
# should not be cloned inside the GOPATH.
GOPATH := $(shell go env GOPATH)
ifeq (/src/$(MOD_NAME),$(subst $(GOPATH),,$(PWD)))
$(warning This project uses Go modules and should not be cloned into the GOPATH)
endif
endif

################################################################################
##                                DEPENDENCIES                                ##
################################################################################
# Verify the dependencies are in place.
.PHONY: deps
deps:
	go mod download && go mod verify

################################################################################
##                                VERSIONS                                    ##
################################################################################
# Ensure the version is injected into the binaries via a linker flag.
export VERSION ?= $(shell git describe --tags --always --dirty)

.PHONY: version
version:
	@echo $(VERSION)

################################################################################
##                                BUILD DIRS                                  ##
################################################################################
.PHONY: build-dirs
build-dirs:
	@mkdir -p $(BIN_OUT)

################################################################################
##                              BUILD BINARIES                                ##
################################################################################
# Unless otherwise specified the binaries should be built for linux-amd64.
GOOS ?= linux
ifeq (aarch64,$(shell uname -p))
    GOARCH = arm64
else
    GOARCH = amd64
endif

LDFLAGS := -extldflags "-static" -w -s
LDFLAGS_CRANE := $(LDFLAGS) -X github.com/google/go-containerregistry/cmd/crane/cmd.Version=$(VERSION)

# The crane binary.
CRANE_BIN_NAME := crane
CRANE_BIN := $(BIN_OUT)/$(CRANE_BIN_NAME)
build-crane: $(CRANE_BIN)
ifndef CRANE_BIN_SRCS
CRANE_BIN_SRCS := cmd/crane/main.go go.mod go.sum
CRANE_BIN_SRCS += $(addsuffix /*.go,$(shell go list -f '{{ join .Deps "\n" }}' ./cmd/crane | grep $(MOD_NAME) | sed 's~$(MOD_NAME)~.~'))
export CRANE_BIN_SRCS
endif
$(CRANE_BIN): $(CRANE_BIN_SRCS)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -ldflags '$(LDFLAGS_CRANE)' -o $(abspath $@) $<
	@touch $@

# The default build target.
build build-bins: $(CRANE_BIN)

################################################################################
##                                 CLEAN                                      ##
################################################################################
.PHONY: clean
clean:
	rm -f $(CRANE_BIN)

.PHONY: clean-d
clean-d:
	@find . -name "*.d" -type f -delete
