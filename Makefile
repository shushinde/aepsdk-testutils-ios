
export EXTENSION_NAME = AEPTestUtils
PROJECT_NAME = $(EXTENSION_NAME)

CURR_DIR := ${CURDIR}

setup-tools: install-githook

clean:
	rm -rf build

clean-ios-test-files:
	rm -rf iosUnitResults.xcresult

clean-tvos-test-files:
	rm -rf tvosresults.xcresult

open:
	open $(PROJECT_NAME).xcworkspace

archive: _archive

ci-archive: _archive

_archive: clean build-ios build-tvos
	./Script/archive.sh create-xcframeworks

build-ios:
	./Script/archive.sh build-ios

build-tvos:
	./Script/archive.sh build-tvos

zip:
	cd build && zip -r -X $(EXTENSION_NAME).xcframework.zip $(EXTENSION_NAME).xcframework/
	swift package compute-checksum build/$(EXTENSION_NAME).xcframework.zip

unit-test-ios: clean-ios-test-files
	@echo "######################################################################"
	@echo "### Unit Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "UnitTests" -destination "platform=iOS Simulator,name=iPhone 15" -derivedDataPath build/out -resultBundlePath iosUnitResults.xcresult -enableCodeCoverage YES ADB_SKIP_LINT=YES

test-tvos: clean-tvos-test-files
	@echo "######################################################################"
	@echo "### Testing tvOS"
	@echo "######################################################################"
	@echo "List of available shared Schemes in xcworkspace"
	xcodebuild -workspace $(PROJECT_NAME).xcworkspace -list
	final_scheme=""; \
	if xcodebuild -workspace $(PROJECT_NAME).xcworkspace -list | grep -q "($(PROJECT_NAME) project)"; \
	then \
	   final_scheme="$(EXTENSION_NAME) ($(PROJECT_NAME) project)" ; \
	   echo $$final_scheme ; \
	else \
	   final_scheme="$(EXTENSION_NAME)" ; \
	   echo $$final_scheme ; \
	fi; \
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "$$final_scheme" -destination 'platform=tvOS Simulator,name=Apple TV' -derivedDataPath build/out -resultBundlePath tvosresults.xcresult -enableCodeCoverage YES

install-githook:
	git config core.hooksPath .githooks

lint-autocorrect:
	(swiftlint --fix --format)

lint:
	(swiftlint lint Sources)

test-SPM-integration:
	(sh ./Script/test-SPM.sh)
