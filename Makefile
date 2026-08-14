TARGET = iphone:clang:16.5:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = EscapeOS

# Public release with iOS 26 Liquid Glass tab bar requires Xcode 26 on macOS — see docs/BUILD.md.
# WSL/Theos uses iPhoneOS16.5.sdk because Apple SDK 18+/26+ needs Apple Clang, not Linux clang.

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = EscapeOS

EscapeOS_FILES = \
	EscapeOS/EscapeOSApp.swift \
	EscapeOS/Views/RootView.swift \
	EscapeOS/Views/AppListView.swift \
	EscapeOS/Views/AppDetailView.swift \
	EscapeOS/Views/FileBrowserView.swift \
	EscapeOS/Views/FileViewerView.swift \
	EscapeOS/Views/HexEditorView.swift \
	EscapeOS/Views/FilePropertiesView.swift \
	EscapeOS/Views/BackupView.swift \
	EscapeOS/Views/BackupsListView.swift \
	EscapeOS/Views/LimitsDisclaimer.swift \
	EscapeOS/Engine/ZipReader.swift \
	EscapeOS/Engine/BackupPaths.swift \
	EscapeOS/Engine/RestoreService.swift \
	EscapeOS/Engine/SandboxEscape.swift \
	EscapeOS/Engine/FileKind.swift \
	EscapeOS/Engine/FileService.swift \
	EscapeOS/Engine/AppDiscovery.swift \
	EscapeOS/Engine/BackupService.swift \
	EscapeOS/Engine/ZipWriter.swift \
	EscapeOS/Engine/bad_query.c \
	EscapeOS/Tunnel/TunnelContext.m \
	EscapeOS/Tunnel/applist.m

EscapeOS_SWIFT_BRIDGING_HEADER = EscapeOS/Engine/EscapeOS-Bridging-Header.h
EscapeOS_CFLAGS = -IEscapeOS/Engine -IEscapeOS/Tunnel
EscapeOS_OBJCFLAGS = -IEscapeOS/Engine -IEscapeOS/Tunnel -fobjc-arc

# Link the Rust idevice FFI static library and its system dependencies.
EscapeOS_LDFLAGS = -LEscapeOS/Tunnel -lidevice_ffi -lresolv -framework Security -framework Network -framework SystemConfiguration -framework QuickLook -framework PDFKit -framework AVKit -framework AVFoundation
EscapeOS_CODESIGN_FLAGS = -SEscapeOS.entitlements

include $(THEOS_MAKE_PATH)/application.mk
