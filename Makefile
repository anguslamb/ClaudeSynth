# Makefile for ClaudeSynth Audio Unit
PLUGIN_NAME = ClaudeSynth
BUNDLE_IDENTIFIER = com.demo.audiounit.ClaudeSynth
INSTALL_PATH = $(HOME)/Library/Audio/Plug-Ins/Components

# Compiler and flags
CXX = clang++
SDK_PATH = $(shell xcrun --show-sdk-path)
CXXFLAGS = -std=c++11 -arch x86_64 -arch arm64 \
           -mmacosx-version-min=10.13 \
           -fvisibility=hidden \
           -fvisibility-inlines-hidden \
           -fobjc-arc \
           -O2 \
           -isysroot $(SDK_PATH)

# Include paths
INCLUDES = -ISource

# Frameworks
FRAMEWORKS = -framework AudioUnit \
             -framework AudioToolbox \
             -framework CoreAudio \
             -framework CoreFoundation \
             -framework Cocoa \
             -framework QuartzCore

# Source files
SOURCES = Source/ClaudeSynth.cpp \
          Source/ClaudeSynthView.mm \
          Source/RotaryKnob.mm \
          Source/DiscreteKnob.mm \
          Source/ADSREnvelopeView.mm \
          Source/MatrixDropdown.mm \
          Source/MatrixCheckbox.mm \
          Source/MatrixSlider.mm \
          Source/MatrixLED.mm

# Bundle structure
BUNDLE_DIR = build/$(PLUGIN_NAME).component
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Build bundle
all: $(BUNDLE_DIR)

$(BUNDLE_DIR): $(SOURCES)
	@echo "Building $(PLUGIN_NAME)..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)

	# Compile and link
	$(CXX) $(CXXFLAGS) $(INCLUDES) $(FRAMEWORKS) \
		-bundle -o $(MACOS_DIR)/$(PLUGIN_NAME) \
		$(SOURCES)

	# Copy Info.plist
	@cp Resources/Info.plist $(CONTENTS_DIR)/Info.plist

	# Set bundle bit
	@SetFile -a B $(BUNDLE_DIR) 2>/dev/null || true

	@echo "Build complete: $(BUNDLE_DIR)"

install: $(BUNDLE_DIR)
	@echo "Installing to $(INSTALL_PATH)..."
	@mkdir -p $(INSTALL_PATH)
	@cp -R $(BUNDLE_DIR) $(INSTALL_PATH)/
	@echo "Installed successfully"
	@echo "Clearing component cache..."
	@killall -9 AudioComponentRegistrar 2>/dev/null || true
	@echo "Installation complete"

validate: install
	@echo "Validating plugin..."
	auval -v aumu ClSy Demo

clean:
	@rm -rf build
	@echo "Clean complete"

uninstall:
	@rm -rf $(INSTALL_PATH)/$(PLUGIN_NAME).component
	@echo "Uninstalled $(PLUGIN_NAME)"

.PHONY: all install validate clean uninstall
