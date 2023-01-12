PROJECT = elementumorg
NAME = libtorrent-go
GO_PACKAGE = github.com/ElementumOrg/$(NAME)
CC = cc
CXX = c++
PKG_CONFIG = pkg-config
DOCKER = docker
DOCKER_IMAGE = $(NAME)
PLATFORMS = \
	android-arm \
	android-arm64 \
	android-x64 \
	android-x86 \
	linux-armv6 \
	linux-armv7 \
	linux-arm64 \
	linux-x64 \
	linux-x86 \
	windows-x64 \
	windows-x86 \
	darwin-x64

LOCALPLATFORM=darwin-arm64
LOCALDEST=$(shell pwd)/local-env/

BOOST_VERSION = 1.72.0
BOOST_VERSION_FILE = $(shell echo $(BOOST_VERSION) | sed s/\\./_/g)
BOOST_SHA256 = 59c9b274bc451cf91a9ba1dd2c7fdcaf5d60b1b3aa83f2c9fa143417cc660722

OPENSSL_VERSION = 1.1.1s
OPENSSL_SHA256 = c5ac01e760ee6ff0dab61d6b2bbd30146724d063eb322180c6f18a6f74e4b6aa
#OPENSSL_SHA256 = 186c6bfe6ecfba7a5b48c47f8a1673d0f3b0e5ba2e25602dd23b629975da3f35

SWIG_VERSION = 77323a0f07562b7d90d36181697a72a909b9519a
SWIG_SHA256 = 26d7176c4a2ab66c5fc8cb48346c07f4d6e790ec375af1db74dfa60ce342e97d

GOLANG_VERSION = 1.19.4
GOLANG_SRC_URL = https://golang.org/dl/go$(GOLANG_VERSION).src.tar.gz
GOLANG_SRC_SHA256 = eda74db4ac494800a3e66ee784e495bfbb9b8e535df924a8b01b1a8028b7f368

#GOLANG_BOOTSTRAP_VERSION = 1.17-bootstrap
GOLANG_BOOTSTRAP_VERSION = 1.4-bootstrap-20170531
GOLANG_BOOTSTRAP_URL = https://dl.google.com/go/go$(GOLANG_BOOTSTRAP_VERSION).tar.gz
# GOLANG_BOOTSTRAP_SHA256 = 49f806f66762077861b7de7081f586995940772d29d4c45068c134441a743fa2
GOLANG_BOOTSTRAP_SHA256 = ef320a71987d491783fc898f4b1d7712f540b3e25d470760ccd3194fab356b84

LIBTORRENT_VERSION = 760f94862ef6b76a13bba0a68d55ca6507aef7c2 # RC_1_1

include platform_host.mk

ifneq ($(CROSS_TRIPLE),)
	CC := $(CROSS_TRIPLE)-$(CC)
	CXX := $(CROSS_TRIPLE)-$(CXX)
endif

include platform_target.mk

ifeq ($(TARGET_ARCH), x86)
	GOARCH = 386
else ifeq ($(TARGET_ARCH), x64)
	GOARCH = amd64
else ifeq ($(TARGET_ARCH), arm)
	GOARCH = arm
	GOARM = 6
else ifeq ($(TARGET_ARCH), armv6)
	GOARCH = arm
	GOARM = 6
else ifeq ($(TARGET_ARCH), armv7)
	GOARCH = arm
	GOARM = 7
	PATH_SUFFIX = v7
	PKGDIR = -pkgdir /go/pkg/linux_armv7
else ifeq ($(TARGET_ARCH), arm64)
	GOARCH = arm64
	GOARM =
endif

ifeq ($(TARGET_OS), windows)
	GOOS = windows
else ifeq ($(TARGET_OS), darwin)
	GOOS = darwin
else ifeq ($(TARGET_OS), linux)
	GOOS = linux
	ifeq ($(CROSS_TRIPLE),)
		CC = gcc
		CXX = g++
	endif
else ifeq ($(TARGET_OS), android)
	GOOS = android
	ifeq ($(TARGET_ARCH), armv6)
		GOARM = 7
	else
		GOARM =
	endif
	GO_LDFLAGS += -flto -extldflags=-pie
endif

ifneq ($(CROSS_ROOT),)
	CROSS_CFLAGS = -I$(CROSS_ROOT)/include -I$(CROSS_ROOT)/$(CROSS_TRIPLE)/include
	CROSS_LDFLAGS = -L$(CROSS_ROOT)/lib
	PKG_CONFIG_PATH = $(CROSS_ROOT)/lib/pkgconfig
endif

LIBTORRENT_CFLAGS = $(CFLAGS) $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) $(PKG_CONFIG) --cflags libtorrent-rasterbar)
LIBTORRENT_LDFLAGS = $(LDFLAGS) $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) $(PKG_CONFIG) --static --libs libtorrent-rasterbar)
DEFINE_IGNORES = __STDC__|_cdecl|__cdecl|_fastcall|__fastcall|_stdcall|__stdcall|__declspec
CC_DEFINES = $(shell echo | $(CC) -dM -E - | grep -v -E "$(DEFINE_IGNORES)" | sed -E "s/\#define[[:space:]]+([a-zA-Z0-9_()]+)[[:space:]]+(.*)/-D\1="\2"/g" | tr '\n' ' ')

ifeq ($(TARGET_OS), windows)
	CC_DEFINES += -DSWIGWIN
	CC_DEFINES += -D_WIN32_WINNT=0x0600
	ifeq ($(TARGET_ARCH), x64)
		CC_DEFINES += -DSWIGWORDSIZE32
	endif
else ifeq ($(TARGET_OS), darwin)
	CC = $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang
	CXX = $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang++
	CC_DEFINES += -DSWIGMAC
else ifeq ($(TARGET_OS), android)
	CC = $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang
	CXX = $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang++
	GO_LDFLAGS = -flto -extldflags=-pie
	ifeq ($(TARGET_ARCH), arm64)
		CC_DEFINES = -DSWIGWORDSIZE64
	endif
else ifeq ($(TARGET_OS), linux)
	GO_LDFLAGS += -flto
	ifeq ($(TARGET_ARCH), arm64)
		CC_DEFINES = -DSWIGWORDSIZE64
	endif
endif


OUT_PATH = $(shell go env GOPATH)/pkg/$(GOOS)_$(GOARCH)$(PATH_SUFFIX)
OUT_LIBRARY = $(OUT_PATH)/$(GO_PACKAGE).a

.PHONY: $(PLATFORMS) local-env

all:
	for i in $(PLATFORMS); do \
		$(MAKE) $$i; \
	done

$(PLATFORMS):
ifeq ($@, all)
	$(MAKE) all
else
	$(DOCKER) run --rm -v $(GOPATH):/go -v $(shell pwd):/go/src/$(GO_PACKAGE) -w /go/src/$(GO_PACKAGE) -e GOPATH=/go $(PROJECT)/$(DOCKER_IMAGE):$@ make re;
endif

build:
	SWIG_FLAGS='$(CC_DEFINES) $(LIBTORRENT_CFLAGS)' \
	CC=$(CC) CXX=$(CXX) \
	PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
	CGO_ENABLED=1 \
	GOOS=$(GOOS) GOARCH=$(GOARCH) GOARM=$(GOARM) \
	PATH=.:$$PATH \
	go install -v -ldflags '$(GO_LDFLAGS)' $(PKGDIR)

clean:
	rm -rf $(OUT_LIBRARY)

re: clean build

retest:
	$(DOCKER) run --rm -v $(GOPATH):/go -v $(shell pwd):/go/src/$(GO_PACKAGE) -w /go/src/$(GO_PACKAGE) -e GOPATH=/go $(PROJECT)/$(DOCKER_IMAGE):linux-x64 make runtest;

runtest:
	CC=${CC} CXX=$(CXX) \
	PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
	CGO_ENABLED=1 \
	GOOS=$(GOOS) GOARCH=$(GOARCH) GOARM=$(GOARM) \
	PATH=.:$$PATH \
	cd test; go run -x test.go; cd ..

local-env:
	mkdir -p $(LOCALDEST)
	$(MAKE) env PLATFORM=$(LOCALPLATFORM)
	$(DOCKER) run --rm -v $(LOCALDEST):/local-env $(PROJECT)/$(DOCKER_IMAGE):$(LOCALPLATFORM) /bin/bash -c "rm -rf /local-env/*; /bin/cp -rf /usr/$(CROSS_TRIPLE)/* /local-env/; chmod -R 777 /local-env/lib/pkgconfig"
	sed -i 's|/usr/$(CROSS_TRIPLE)|$(LOCALDEST)|g' $(LOCALDEST)/lib/pkgconfig/*.pc
	echo ">>> Run 'make re' to compile libtorrent-go locally"

env:
	$(DOCKER) build \
		--build-arg BOOST_VERSION=$(BOOST_VERSION) \
		--build-arg BOOST_VERSION_FILE=$(BOOST_VERSION_FILE) \
		--build-arg BOOST_SHA256=$(BOOST_SHA256) \
		--build-arg OPENSSL_VERSION=$(OPENSSL_VERSION) \
		--build-arg OPENSSL_SHA256=$(OPENSSL_SHA256) \
		--build-arg SWIG_VERSION=$(SWIG_VERSION) \
		--build-arg SWIG_SHA256=$(SWIG_SHA256) \
		--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
		--build-arg GOLANG_SRC_SHA256=$(GOLANG_SRC_SHA256) \
		--build-arg GOLANG_BOOTSTRAP_VERSION=$(GOLANG_BOOTSTRAP_VERSION) \
		--build-arg GOLANG_BOOTSTRAP_SHA256=$(GOLANG_BOOTSTRAP_SHA256) \
		--build-arg LIBTORRENT_VERSION=$(LIBTORRENT_VERSION) \
		-t $(PROJECT)/$(DOCKER_IMAGE):$(PLATFORM) \
		-f docker/$(PLATFORM).Dockerfile docker

envs:
	for i in $(PLATFORMS); do \
		$(MAKE) env PLATFORM=$$i; \
	done

pull:
	docker pull $(PROJECT)/libtorrent-go:$(PLATFORM)

pull-all:
	for i in $(PLATFORMS); do \
		PLATFORM=$$i $(MAKE) pull; \
	done

pull-libtorrent:
	docker pull $(PROJECT)/libtorrent-go:$(PLATFORM)

pull-libtorrent-all:
	for i in $(PLATFORMS); do \
		PLATFORM=$$i $(MAKE) pull-libtorrent; \
	done

push:
	docker push $(PROJECT)/libtorrent-go:$(PLATFORM)

push-all:
	for i in $(PLATFORMS); do \
		PLATFORM=$$i $(MAKE) push; \
	done
