cmake_minimum_required(VERSION 3.15)
project(ClaudeSynth VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required frameworks
find_library(AUDIO_UNIT AudioUnit)
find_library(AUDIO_TOOLBOX AudioToolbox)
find_library(CORE_AUDIO CoreAudio)
find_library(CORE_FOUNDATION CoreFoundation)

# Source files
set(SOURCES
    Source/ClaudeSynth.cpp
)

set(HEADERS
    Source/ClaudeSynth.h
    Source/ClaudeSynthVersion.h
    Source/SynthVoice.h
)

# Create the Audio Unit bundle
add_library(ClaudeSynth MODULE ${SOURCES} ${HEADERS})

# Link frameworks
target_link_libraries(ClaudeSynth
    ${AUDIO_UNIT}
    ${AUDIO_TOOLBOX}
    ${CORE_AUDIO}
    ${CORE_FOUNDATION}
)

# Set bundle properties
set_target_properties(ClaudeSynth PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "component"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.demo.audiounit.ClaudeSynth"
    MACOSX_BUNDLE_BUNDLE_NAME "ClaudeSynth"
    MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
)

# Include AudioUnit SDK headers
target_include_directories(ClaudeSynth PRIVATE
    /System/Library/Frameworks/AudioUnit.framework/Headers
    /System/Library/Frameworks/AudioToolbox.framework/Headers
)

# Copy Info.plist to bundle
set_target_properties(ClaudeSynth PROPERTIES
    RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist"
)
