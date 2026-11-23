import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  none,
  pending,
  accepted,
  declined,
}

class AlumniConnection {
  final String alumniName;
  String studentName;
  String requestMessage;
  ConnectionStatus status;

  AlumniConnection({
    required this.alumniName,
    this.studentName = '',
    this.requestMessage = '',
    this.status = ConnectionStatus.none,
  });
}

class ConnectionData extends ChangeNotifier {
  ConnectionData._();

  static final ConnectionData instance = ConnectionData._();

  final Map<String, AlumniConnection> _connections = {};

  String _selectedAlumniName = 'Sarah Ahmed';

  String get selectedAlumniName => _selectedAlumniName;

  AlumniConnection _getConnection(String alumniName) {
    if (!_connections.containsKey(alumniName)) {
      _connections[alumniName] = AlumniConnection(
        alumniName: alumniName,
      );
    }

    return _connections[alumniName]!;
  }

  AlumniConnection get selectedConnection {
    return _getConnection(_selectedAlumniName);
  }

  ConnectionStatus get status {
    return selectedConnection.status;
  }

  String get studentName {
    return selectedConnection.studentName.isEmpty
        ? 'Anik Hemal'
        : selectedConnection.studentName;
  }

  String get alumniName {
    return selectedConnection.alumniName;
  }

  String get requestMessage {
    return selectedConnection.requestMessage;
  }

  bool get canChat {
    return selectedConnection.status ==
        ConnectionStatus.accepted;
  }

  bool get isPending {
    return selectedConnection.status ==
        ConnectionStatus.pending;
  }

  bool get isAccepted {
    return selectedConnection.status ==
        ConnectionStatus.accepted;
  }

  bool get isDeclined {
    return selectedConnection.status ==
        ConnectionStatus.declined;
  }

  void selectAlumni(String alumniName) {
    _selectedAlumniName = alumniName;

    _getConnection(alumniName);

    notifyListeners();
  }

  ConnectionStatus getStatusFor(String alumniName) {
    return _getConnection(alumniName).status;
  }

  bool isPendingFor(String alumniName) {
    return getStatusFor(alumniName) ==
        ConnectionStatus.pending;
  }

  bool isAcceptedFor(String alumniName) {
    return getStatusFor(alumniName) ==
        ConnectionStatus.accepted;
  }

  bool isDeclinedFor(String alumniName) {
    return getStatusFor(alumniName) ==
        ConnectionStatus.declined;
  }

  bool canChatWith(String alumniName) {
    return getStatusFor(alumniName) ==
        ConnectionStatus.accepted;
  }

  String getMessageFor(String alumniName) {
    return _getConnection(alumniName).requestMessage;
  }

  String getStudentNameFor(String alumniName) {
    final connection = _getConnection(alumniName);

    if (connection.studentName.isEmpty) {
      return 'Anik Hemal';
    }

    return connection.studentName;
  }

  void sendRequest({
    required String studentName,
    required String alumniName,
    required String message,
  }) {
    _selectedAlumniName = alumniName;

    final connection = _getConnection(alumniName);

    connection.studentName = studentName;
    connection.requestMessage = message;
    connection.status = ConnectionStatus.pending;

    notifyListeners();
  }

  void acceptRequest({
    String? alumniName,
  }) {
    final name = alumniName ?? _selectedAlumniName;

    final connection = _getConnection(name);

    connection.status = ConnectionStatus.accepted;

    notifyListeners();
  }

  void declineRequest({
    String? alumniName,
  }) {
    final name = alumniName ?? _selectedAlumniName;

    final connection = _getConnection(name);

    connection.status = ConnectionStatus.declined;

    notifyListeners();
  }

  void resetConnection({
    String? alumniName,
  }) {
    final name = alumniName ?? _selectedAlumniName;

    final connection = _getConnection(name);

    connection.status = ConnectionStatus.none;
    connection.requestMessage = '';
    connection.studentName = '';

    notifyListeners();
  }

  List<AlumniConnection> get allConnections {
    return _connections.values.toList();
  }

  List<AlumniConnection> get pendingConnections {
    return _connections.values
        .where(
          (connection) =>
      connection.status ==
          ConnectionStatus.pending,
    )
        .toList();
  }

  List<AlumniConnection> get acceptedConnections {
    return _connections.values
        .where(
          (connection) =>
      connection.status ==
          ConnectionStatus.accepted,
    )
        .toList();
  }

  int get pendingCount {
    return pendingConnections.length;
  }
}