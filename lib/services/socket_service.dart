import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  late final io.Socket _socket;

  void connect() {
    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      // ignore: avoid_print
      print('Socket conectado: ${_socket.id}');
    });

    _socket.onDisconnect((_) {
      // ignore: avoid_print
      print('Socket desconectado');
    });

    _socket.onConnectError((error) {
      // ignore: avoid_print
      print('Error de conexión Socket: $error');
    });
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket.on(event, handler);
  }

  void emit(String event, [dynamic data]) {
    _socket.emit(event, data);
  }

  void off(String event) {
    _socket.off(event);
  }

  void disconnect() {
    _socket.disconnect();
  }
}
