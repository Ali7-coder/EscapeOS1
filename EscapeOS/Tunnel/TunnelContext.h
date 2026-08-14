//
//  TunnelContext.h
//  EscapeOS
//
//  RPPairing tunnel over LocalDevVPN (10.7.0.1:49152), then InstallationProxy
//  via RSD. This is the StikDebug/SideStore nightly path required on iOS 26.4+.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "idevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface TunnelContext : NSObject {
    @protected struct AdapterHandle *_adapter;
    @protected struct RsdHandshakeHandle *_handshake;
    @protected BOOL _tunnelConnecting;
    @protected NSError *_Nullable _lastTunnelError;
}

@property (class, readonly) TunnelContext *shared;

/// Whether a pairing file is present on disk.
@property (nonatomic, readonly) BOOL hasPairingFile;

/// Save a user-imported pairing file (contents of a .mobiledevicepairing plist).
- (BOOL)savePairingFile:(NSString *)contents error:(NSError **)error;

/// Remove the stored pairing file.
- (void)resetPairingFile;

/// Establish the RPPairing tunnel. Requires LocalDevVPN on its default IP.
/// Returns YES on success; on failure fills error.
- (BOOL)startHeartbeat:(NSError **)error;

/// Start the tunnel only if adapter/handshake handles are missing.
- (BOOL)ensureHeartbeatWithError:(NSError **)error;

/// Enumerate all installed apps (full info dictionaries). Requires tunnel.
- (nullable NSDictionary<NSString *, NSDictionary *> *)getAllAppsInfoWithError:(NSError **)error;

/// Fetch an app's SpringBoard icon PNG.
- (nullable UIImage *)getAppIconWithBundleId:(NSString *)bundleId error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
