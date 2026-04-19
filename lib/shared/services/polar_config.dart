/// Polar Configuration
/// 
/// Update these values from your Polar node settings:
/// 1. Open Polar → Click on your node (e.g. "alice") → Check "Connect" tab
/// 2. Copy "REST Host" (e.g. https://127.0.0.1:8081)
/// 3. Copy "Macaroon" (hex string)
///
/// For Android Emulator: use 10.0.2.2 instead of 127.0.0.1
/// For real device: use your PC's local IP (e.g. 192.168.1.x)

class PolarConfig {
  /// REST URL of your Polar LND node
  /// Emulator: https://10.0.2.2:8081
  /// Real device: https://YOUR_PC_IP:8081
  static const String lndRestUrl = 'https://192.168.1.148:8081';

  /// Macaroon hex string from Polar node settings
  /// Found in: Polar → Click node "alice" → Connect tab → Macaroon (HEX)
  static const String macaroonHex = '0201036c6e6402f801030a10340b0d501f7153e4214758b3053f68881201301a160a0761646472657373120472656164120577726974651a130a04696e666f120472656164120577726974651a170a08696e766f69636573120472656164120577726974651a210a086d616361726f6f6e120867656e6572617465120472656164120577726974651a160a076d657373616765120472656164120577726974651a170a086f6666636861696e120472656164120577726974651a160a076f6e636861696e120472656164120577726974651a140a057065657273120472656164120577726974651a180a067369676e6572120867656e657261746512047265616400000620898038db869f9e38d4bc2e85e49bf8b5ca4ba599236d95a321315f6d498451fa';

  /// Whether Polar/LND mode is enabled
  /// Set to true to use LND directly, false to use Flash API
  static const bool enabled = true;
}
