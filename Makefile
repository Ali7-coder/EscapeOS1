TARGET = iphone:clang:16.5:18.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = EscapeOSPro

# Public release with iOS 26 Liquid Glass tab bar requires Xcode 26 on macOS — see docs/BUILD.md.
# WSL/Theos uses iPhoneOS16.5.sdk because Apple SDK 18+/26+ needs Apple Clang, not Linux clang.

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = EscapeOSPro

EscapeOSPro_FILES = \
	EscapeOSPro/EscapeOSProApp.swift \
	EscapeOSPro/Views/RootView.swift \
	EscapeOSPro/Views/AppListView.swift \
	EscapeOSPro/Views/AppDetailView.swift \
	EscapeOSPro/Views/FileBrowserView.swift \
	EscapeOSPro/Views/FileViewerView.swift \
	EscapeOSPro/Views/HexEditorView.swift \
	EscapeOSPro/Views/FilePropertiesView.swift \
	EscapeOSPro/Views/BackupView.swift \
	EscapeOSPro/Views/BackupsListView.swift \
	EscapeOSPro/Views/LimitsDisclaimer.swift \
	EscapeOSPro/Views/ReclaimAppView.swift \
	EscapeOSPro/Views/ReclaimTabView.swift \
	EscapeOSPro/Engine/ZipReader.swift \
	EscapeOSPro/Engine/BackupPaths.swift \
	EscapeOSPro/Engine/RestoreService.swift \
	EscapeOSPro/Engine/SandboxEscape.swift \
	EscapeOSPro/Engine/FileKind.swift \
	EscapeOSPro/Engine/FileClipboard.swift \
	EscapeOSPro/Engine/FileService.swift \
	EscapeOSPro/Engine/AppDiscovery.swift \
	EscapeOSPro/Engine/BackupService.swift \
	EscapeOSPro/Engine/ZipWriter.swift \
	EscapeOSPro/Engine/ZipPassword.swift \
	EscapeOSPro/Engine/SevenZipAES.swift \
	EscapeOSPro/Engine/ArchiveExtractor.swift \
	EscapeOSPro/Engine/ReclaimService.swift \
	EscapeOSPro/Engine/zip_crypto.c \
	EscapeOSPro/Engine/bad_query.c \
	EscapeOSPro/Tunnel/TunnelContext.m \
	EscapeOSPro/Tunnel/applist.m \
	EscapeOSPro/Tunnel/heartbeat.m

EscapeOSPro_FILES += $(shell find vendor/BitByteData/Sources vendor/SWCompression/Sources -name '*.swift' \
	! -name 'TarWriter.swift' ! -name 'TarReader.swift' ! -name 'TarCreateError.swift' \
	! -name 'ZlibArchive.swift' ! -name 'ZlibError.swift' ! -name 'ZlibHeader.swift' \
	! -name 'BigEndianByteReader.swift')

EscapeOSPro_SWIFT_BRIDGING_HEADER = EscapeOSPro/Engine/EscapeOS-Bridging-Header.h
EscapeOSPro_CFLAGS = -IEscapeOSPro/Engine -IEscapeOSPro/Tunnel
EscapeOSPro_OBJCFLAGS = -IEscapeOSPro/Engine -IEscapeOSPro/Tunnel -fobjc-arc

# Link the Rust idevice FFI static library and its system dependencies.
EscapeOSPro_LDFLAGS = -LEscapeOSPro/Tunnel -lidevice_ffi -lresolv -framework Security -framework Network -framework SystemConfiguration -framework QuickLook -framework PDFKit -framework AVKit -framework AVFoundation
EscapeOSPro_CODESIGN_FLAGS = -SEscapeOS.entitlements

include $(THEOS_MAKE_PATH)/application.mk
