import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:myapp/icons/chart_icons.dart';
import 'package:myapp/icons/huyet_ap_icons.dart';
import 'package:myapp/icons/nhiptim_icons.dart';
import 'package:myapp/icons/spo2_icons.dart';
import 'package:myapp/icons/temper_icons.dart';
import 'package:ndialog/ndialog.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

var temper, temperLCD, temper1, temper2, spo2bpm, systolic, diastolic, spo2;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MQTT E-Health',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      // theme: ThemeData(
      //     elevatedButtonTheme: ElevatedButtonThemeData(
      //         style: ElevatedButton.styleFrom(
      //             padding:
      //                 const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      //             shape: RoundedRectangleBorder(
      //                 borderRadius: BorderRadius.circular(20)),
      //             primary: const Color.fromRGBO(192, 108, 132, 1),
      //             textStyle: const TextStyle(
      //               fontSize: 20, fontStyle: FontStyle.italic)
      //             ))),
      home: const MQTTClient(),
    );
  }
}

class SharedPrefs {
  static late SharedPreferences _sharedPrefs;

  factory SharedPrefs() => SharedPrefs._internal();

  SharedPrefs._internal();

  Future<void> init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  List<String> get huyetapdata =>
      _sharedPrefs.getStringList('huyetapdata') ?? <String>[];

  set huyetapdata(List<String> value) {
    _sharedPrefs.setStringList('huyetapdata', value);
  }
}

class MQTTClient extends StatefulWidget {
  const MQTTClient({Key? key}) : super(key: key);

  @override
  _MQTTClientState createState() => _MQTTClientState();
}

class _MQTTClientState extends State<MQTTClient> {
  String statusText = "Status Text";
  bool isConnected = false;
  TextEditingController idTextController = TextEditingController();

  final MqttServerClient client = MqttServerClient(
      'efe545b723c6413a94f9b2910b00c39a.s1.eu.hivemq.cloud', '');

  @override
  void dispose() {
    idTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    final bool hasShortWidth = width < 600;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [header(), body(hasShortWidth), footer()],
        ),
      ),
    );
  }

  Widget header() {
    return const Expanded(
      child: Center(
        child: Text(
          'E-Health',
          style: TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      flex: 3,
    );
  }

  Widget body(bool hasShortWidth) {
    return Expanded(
      child: Container(
        child: hasShortWidth
            ? Column(
                children: [bodyMenu(), Expanded(child: bodySteam())],
              )
            : Row(
                children: [
                  Expanded(
                    child: bodyMenu(),
                    flex: 2,
                  ),
                  Expanded(
                    child: bodySteam(),
                    flex: 8,
                  )
                ],
              ),
      ),
      flex: 20,
    );
  }

  Widget bodyMenu() {
    return Container(
      color: Colors.black26,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
                validator: (value) {
                  if (value != "vominhtri" || value == null || value.isEmpty) {
                    return 'patient ID not found';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.always,
                enabled: !isConnected,
                controller: idTextController,
                decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    labelText: 'MQTT Client Id',
                    labelStyle: const TextStyle(fontSize: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.subdirectory_arrow_left),
                      onPressed: _connect,
                    ))),
          ),
          isConnected
              ? TextButton(
                  onPressed: _disconnect, child: const Text('Disconnect'))
              : Container()
        ],
      ),
    );
  }

  Widget bodySteam() {
    return Container(
      color: Colors.black12,
      child: StreamBuilder(
        stream: client.updates,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          } else {
            final mqttReceivedMessages =
                snapshot.data as List<MqttReceivedMessage<MqttMessage?>>?;
            final recMess =
                mqttReceivedMessages![0].payload as MqttPublishMessage;
            final pt = MqttPublishPayload.bytesToStringAsString(
                recMess.payload.message);
            final data = jsonDecode(pt);
            for (var item in data['values']) {
              switch (item['key']) {
                case 'temper1':
                  temper1 = item['value'];
                  temper1 = (temper1 << 8);
                  break;
                case 'temper2':
                  temper2 = item['value'];
                  temper2 = temper1 | temper2;
                  temper2 = temper2 / 10;
                  break;
                case 'spo2bpm':
                  spo2bpm = item['value'];
                  break;
                case 'systolic':
                  systolic = item['value'];
                  break;
                case 'diastolic':
                  diastolic = item['value'];
                  break;
                case 'spo2':
                  spo2 = item['value'];
                  break;
                default:
                  break;
              }
            }

            final tamThuCu = SharedPrefs().huyetapdata;
            tamThuCu.add(
                '$systolic/$diastolic mmHg - ${DateTime.now().toLocal().toString().split(' ')[0]}');
            if (tamThuCu.length > 5) {
              tamThuCu.removeAt(0);
            }
            SharedPrefs().huyetapdata = tamThuCu;

            return Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Temper.temper, size: 43),
                      title: Text('Nhiệt độ: $temper2 °C'),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Temper1graph()),
                          );
                        },
                        icon: const Icon(Chart.chart, size: 30),
                        //icon data for elevated button
                        label: const Text("Đồ thị"),
                        //label text
                        style: ElevatedButton.styleFrom(
                          primary: const Color.fromRGBO(192, 108, 132, 1),
                        ),
                      ),
                      subtitle: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ReferenceValueTemp()),
                          );
                        },
                        child: const Text(
                          'Giá trị tham chiếu',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ListTile(
                      leading: const Icon(Spo2.spo2, size: 40),
                      title: Text('Chỉ số spo2: $spo2 %'),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Spo2graph()),
                          );
                        },
                        icon: const Icon(Chart.chart, size: 30),
                        //icon data for elevated button
                        label: const Text("Đồ thị"),
                        //label text
                        style: ElevatedButton.styleFrom(
                          primary: const Color.fromRGBO(192, 108, 132, 1),
                        ),
                      ),
                      subtitle: const Tooltip(
                        message:
                            'Thang đo chỉ số SpO2 tiêu chuẩn:\n    -SpO2 từ 97 - 99%: Chỉ số oxy trong máu tốt;\n    -SpO2 từ 94 - 96%: Chỉ số oxy trong máu trung bình, cần thở thêm oxy;\n    -SpO2 từ 90% - 93%: Chỉ số oxy trong máu thấp, cần xin ý kiến của bác sĩ chủ trị;\n    -SpO2 dưới 92% không thở oxy hoặc dưới 95% có thở oxy: Dấu hiệu suy hô hấp rất nặng;\n    -SpO2 dưới 90%: Biểu hiện của một ca cấp cứu trên lâm sàng.',
                        child: Text(
                          'Giá trị tham chiếu',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ListTile(
                      leading: const Icon(Nhiptim.beats, size: 43),
                      title: Text('Nhịp tim: $spo2bpm bpm'),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Spo2bpmgraph()),
                          );
                        },
                        icon: const Icon(Chart.chart, size: 30),
                        //icon data for elevated button
                        label: const Text("Đồ thị"),
                        //label text
                        style: ElevatedButton.styleFrom(
                          primary: const Color.fromRGBO(192, 108, 132, 1),
                        ),
                      ),
                      subtitle: const Tooltip(
                        message:
                            'Thang đo chỉ số nhịp tim tiêu chuẩn:\n    -Dưới 1 tháng tuổi: 70 – 190 bpm;\n    -Từ 1 – 11 tháng tuổi: 80 – 160 bpm;\n    -Từ 1 – 2 tuổi: 80 – 130 bpm;\n    -Từ 3 – 4 tuổi: 80 – 120 bpm;\n    -Từ 5 – 6 tuổi: 75 – 115 bpm;\n    -Từ 7 – 9 tuổi: 70 – 110;\n    -Từ 10 tuổi trở lên: 60 – 100 bpm.',
                        child: Text(
                          'Giá trị tham chiếu',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ListTile(
                      leading: const Icon(HuyetAp.huyetap, size: 40),
                      title: Text('Huyết áp: $systolic/$diastolic mmHg'),
                      subtitle: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ReferenceValueha()),
                          );
                        },
                        child: const Text(
                          'Giá trị tham chiếu',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget footer() {
    return Expanded(
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          statusText,
          style: const TextStyle(
              fontWeight: FontWeight.normal, color: Colors.amberAccent),
        ),
      ),
      flex: 1,
    );
  }

  _connect() async {
    final patientId = idTextController.text.trim();
    if (patientId.isNotEmpty && patientId == "vominhtri") {
      ProgressDialog progressDialog = ProgressDialog(context,
          blur: 0,
          dialogTransitionType: DialogTransitionType.Shrink,
          dismissable: false);
      progressDialog.setLoadingWidget(const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Colors.red),
      ));
      progressDialog
          .setMessage(const Text("Please Wait, Connecting to IoT MQTT Broker"));
      // ignore: prefer_const_constructors
      progressDialog.setTitle(Text("Connecting"));
      progressDialog.show();

      isConnected = await mqttConnect(idTextController.text.trim());
      progressDialog.dismiss();
    }
  }

  _disconnect() {
    client.disconnect();
  }

  Future<bool> mqttConnect(String uniqueId) async {
    setStatus("Connecting MQTT Broker");

    ByteData rootCA = await rootBundle.load('assets/certs/RootCA.pem');
    SecurityContext context = SecurityContext.defaultContext;
    context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
    client.securityContext = context;

    const username = 'vominhtri';
    const password = 'Vominhtrithcsdhtp1';
    const port = 8883;

    /// Set the port
    client.port = port;

    /// Set secure
    client.secure = true;

    /// Set the protocol to V3.1.1 for iot-core, if you fail to do this you will receive a connect ack with the response code
    /// 0x01 Connection Refused, unacceptable protocol version
    client.setProtocolV311();

    /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
    client.keepAlivePeriod = 60;

    /// logging if you wish
    client.logging(on: true);

    /// Add the successful connection callback
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;

    /// Set a ping received callback if needed, called whenever a ping response(pong) is received
    /// from the broker.
    client.pongCallback = pong;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password and clean session,
    /// an example of a specific one below.
    final MqttConnectMessage connMess =
        MqttConnectMessage().withClientIdentifier(uniqueId).startClean();
    print('Hivemq client connecting....');
    client.connectionMessage = connMess;

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await client.connect(username, password);
    } on Exception catch (e) {
      print('client exception - $e');
      client.disconnect();
      exit(-1);
    }

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Hivemq client connected');
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        /// Debug
        final recMess = c[0].payload as MqttPublishMessage;
        final pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final data = jsonDecode(pt);
        for (var item in data['values']) {
          switch (item['key']) {
            case 'temper1':
              print('Nhiệt độ 1: ${item['value']}');
              break;
            case 'temper2':
              print('Nhiệt độ 2: ${item['value']}');
              break;
            case 'spo2bpm':
              print('Nhịp tim: ${item['value']}');
              break;
            case 'systolic':
              print('Huyết áp tâm thu: ${item['value']}');
              break;
            case 'diastolic':
              print('Huyết áp tâm trương: ${item['value']}');
              break;
            case 'spo2':
              print('SpO2: ${item['value']}');
              break;
            default:
              break;
          }
        }
        print(
            'Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
        print('');
      });
    } else {
      /// Use status here rather than state if you also want the broker return code.
      print(
          'Hivemq client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
      exit(-1);
    }

    /// Ok, lets try a subscription
    print('Subscribing to the vominhtri/pi/ topic');
    const topic = 'vominhtri/pi/#'; // Not a wildcard topic
    client.subscribe(topic, MqttQos.atMostOnce);

    return true;
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The successful connect callback
  void onConnected() {
    setStatus("Client connection was successful");
    print('OnConnected client callback - Client connection was sucessful');
  }

  /// Pong callback
  void pong() {
    print('Ping response client callback invoked');
  }

  void onDisconnected() {
    setStatus("Client Disconnected");
    isConnected = false;
  }

  void setStatus(String content) {
    setState(() {
      statusText = content;
    });
  }
}

class Spo2graph extends StatefulWidget {
  const Spo2graph({Key? key}) : super(key: key);

  @override
  _Spo2graphState createState() => _Spo2graphState();
}

class _Spo2graphState extends State<Spo2graph> {
  late List<LiveData> chartData;
  late ChartSeriesController _chartSeriesController;

  @override
  void initState() {
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 5), updateDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Đồ Thị SpO2 Theo Thời Gian',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            body: SfCartesianChart(
                series: <LineSeries<LiveData, int>>[
                  LineSeries<LiveData, int>(
                    onRendererCreated: (ChartSeriesController controller) {
                      _chartSeriesController = controller;
                    },
                    dataSource: chartData,
                    color: const Color.fromRGBO(192, 108, 132, 1),
                    xValueMapper: (LiveData sales, _) => sales.time,
                    yValueMapper: (LiveData sales, _) => sales.speed,
                  )
                ],
                primaryXAxis: NumericAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    interval: 1,
                    title: AxisTitle(text: 'Time (seconds)')),
                primaryYAxis: NumericAxis(
                    maximum: 100,
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    title: AxisTitle(
                        text: 'Saturation of peripheral oxygen (%)')))));
  }

  int time = 26;

  void updateDataSource(Timer timer) {
    chartData.add(LiveData(time++, spo2));
    chartData.removeAt(0);
    _chartSeriesController.updateDataSource(
        addedDataIndex: chartData.length - 1, removedDataIndex: 0);
  }

  List<LiveData> getChartData() {
    return <LiveData>[
      LiveData(0, spo2),
      LiveData(1, spo2),
      LiveData(2, spo2),
      LiveData(3, spo2),
      LiveData(4, spo2),
      LiveData(5, spo2),
      LiveData(6, spo2),
      LiveData(7, spo2),
      LiveData(8, spo2),
      LiveData(9, spo2),
      LiveData(10, spo2),
      LiveData(11, spo2),
      LiveData(12, spo2),
      LiveData(13, spo2),
      LiveData(14, spo2),
      LiveData(15, spo2),
      LiveData(16, spo2),
      LiveData(17, spo2),
      LiveData(18, spo2),
      LiveData(19, spo2),
      LiveData(20, spo2),
      LiveData(21, spo2),
      LiveData(22, spo2),
      LiveData(23, spo2),
      LiveData(24, spo2),
      LiveData(25, spo2)
    ];
  }
}

class LiveData {
  LiveData(this.time, this.speed);

  final int time;
  final num speed;
}

class Temper1graph extends StatefulWidget {
  const Temper1graph({Key? key}) : super(key: key);

  @override
  _Temper1graphState createState() => _Temper1graphState();
}

class _Temper1graphState extends State<Temper1graph> {
  late List<LiveData1> chartData;
  late ChartSeriesController _chartSeriesController;

  @override
  void initState() {
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 5), updateDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Đồ Thị Nhiệt Độ Theo Thời Gian',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            body: SfCartesianChart(
                series: <LineSeries<LiveData1, int>>[
                  LineSeries<LiveData1, int>(
                    onRendererCreated: (ChartSeriesController controller) {
                      _chartSeriesController = controller;
                    },
                    dataSource: chartData,
                    color: const Color.fromRGBO(192, 108, 132, 1),
                    xValueMapper: (LiveData1 sales, _) => sales.time,
                    yValueMapper: (LiveData1 sales, _) => sales.speed,
                  )
                ],
                primaryXAxis: NumericAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    interval: 1,
                    title: AxisTitle(text: 'Time (seconds)')),
                primaryYAxis: NumericAxis(
                    maximum: 50,
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    title: AxisTitle(text: 'Temperature (°C)')))));
  }

  int time = 26;

  void updateDataSource(Timer timer) {
    chartData.add(LiveData1(time++, temper2));
    chartData.removeAt(0);
    _chartSeriesController.updateDataSource(
        addedDataIndex: chartData.length - 1, removedDataIndex: 0);
  }

  List<LiveData1> getChartData() {
    return <LiveData1>[
      LiveData1(0, temper2),
      LiveData1(1, temper2),
      LiveData1(2, temper2),
      LiveData1(3, temper2),
      LiveData1(4, temper2),
      LiveData1(5, temper2),
      LiveData1(6, temper2),
      LiveData1(7, temper2),
      LiveData1(8, temper2),
      LiveData1(9, temper2),
      LiveData1(10, temper2),
      LiveData1(11, temper2),
      LiveData1(12, temper2),
      LiveData1(13, temper2),
      LiveData1(14, temper2),
      LiveData1(15, temper2),
      LiveData1(16, temper2),
      LiveData1(17, temper2),
      LiveData1(18, temper2),
      LiveData1(19, temper2),
      LiveData1(20, temper2),
      LiveData1(21, temper2),
      LiveData1(22, temper2),
      LiveData1(23, temper2),
      LiveData1(24, temper2),
      LiveData1(25, temper2)
    ];
  }
}

class LiveData1 {
  LiveData1(this.time, this.speed);

  final int time;
  final num speed;
}

class Spo2bpmgraph extends StatefulWidget {
  const Spo2bpmgraph({Key? key}) : super(key: key);

  @override
  _Spo2bpmgraphState createState() => _Spo2bpmgraphState();
}

class _Spo2bpmgraphState extends State<Spo2bpmgraph> {
  late List<LiveData3> chartData;
  late ChartSeriesController _chartSeriesController;

  @override
  void initState() {
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 5), updateDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Đồ Thị Nhịp Tim Theo Thời Gian',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            body: SfCartesianChart(
                series: <LineSeries<LiveData3, int>>[
                  LineSeries<LiveData3, int>(
                    onRendererCreated: (ChartSeriesController controller) {
                      _chartSeriesController = controller;
                    },
                    dataSource: chartData,
                    color: const Color.fromRGBO(192, 108, 132, 1),
                    xValueMapper: (LiveData3 sales, _) => sales.time,
                    yValueMapper: (LiveData3 sales, _) => sales.speed,
                  )
                ],
                primaryXAxis: NumericAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    interval: 1,
                    title: AxisTitle(text: 'Time (seconds)')),
                primaryYAxis: NumericAxis(
                    maximum: 200,
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    title: AxisTitle(text: 'Heartbeat (bpm)')))));
  }

  int time = 26;

  void updateDataSource(Timer timer) {
    chartData.add(LiveData3(time++, spo2bpm));
    chartData.removeAt(0);
    _chartSeriesController.updateDataSource(
        addedDataIndex: chartData.length - 1, removedDataIndex: 0);
  }

  List<LiveData3> getChartData() {
    return <LiveData3>[
      LiveData3(0, spo2bpm),
      LiveData3(1, spo2bpm),
      LiveData3(2, spo2bpm),
      LiveData3(3, spo2bpm),
      LiveData3(4, spo2bpm),
      LiveData3(5, spo2bpm),
      LiveData3(6, spo2bpm),
      LiveData3(7, spo2bpm),
      LiveData3(8, spo2bpm),
      LiveData3(9, spo2bpm),
      LiveData3(10, spo2bpm),
      LiveData3(11, spo2bpm),
      LiveData3(12, spo2bpm),
      LiveData3(13, spo2bpm),
      LiveData3(14, spo2bpm),
      LiveData3(15, spo2bpm),
      LiveData3(16, spo2bpm),
      LiveData3(17, spo2bpm),
      LiveData3(18, spo2bpm),
      LiveData3(19, spo2bpm),
      LiveData3(20, spo2bpm),
      LiveData3(21, spo2bpm),
      LiveData3(22, spo2bpm),
      LiveData3(23, spo2bpm),
      LiveData3(24, spo2bpm),
      LiveData3(25, spo2bpm)
    ];
  }
}

class LiveData3 {
  LiveData3(this.time, this.speed);

  final int time;
  final num speed;
}

class ReferenceValueTemp extends StatelessWidget {
  const ReferenceValueTemp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Giá Trị Tham Chiếu Nhiệt Độ',
            style: TextStyle(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        body: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 30.0),
          child: Column(
            children: [
              Image.asset('assets/images/Body_Temp_Variation.png'),
              const Text(
                'Nhiệt độ cơ thể người thay đổi trong ngày',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                    border: TableBorder.all(), // Allows to add a border decoration around your table
                    children: const [
                      TableRow(children :[
                        Text('Nhiệt độ (°C)'),
                        Text('0 - 2 tuổi', textAlign: TextAlign.center,),
                        Text('3 - 10 tuổi', textAlign: TextAlign.center,),
                        Text('16 - 65 tuổi', textAlign: TextAlign.center,),
                        Text('Trên 65 tuổi', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Đo miệng',),
                        Text('36,4 - 38', textAlign: TextAlign.center,),
                        Text('35,5 - 37,5', textAlign: TextAlign.center,),
                        Text('36,4 - 37,5', textAlign: TextAlign.center,),
                        Text('35,7 - 36,9', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Đo hậu môn'),
                        Text('36,6 - 38', textAlign: TextAlign.center,),
                        Text('36,6 - 38', textAlign: TextAlign.center,),
                        Text('37 - 38,1', textAlign: TextAlign.center,),
                        Text('36,2 - 37,3', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Tooltip (message: 'Đo vùng nách',child: Text('Đo vùng nách', overflow: TextOverflow.ellipsis,)),
                        Text('34,7 - 37,3', textAlign: TextAlign.center,),
                        Text('35,8 - 36,7', textAlign: TextAlign.center,),
                        Text('35,2 - 36,8', textAlign: TextAlign.center,),
                        Text('35,5 - 36,3', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Đo tai'),
                        Text('36,4 - 38', textAlign: TextAlign.center,),
                        Text('36,1 - 37,7', textAlign: TextAlign.center,),
                        Text('35,8 - 37,6', textAlign: TextAlign.center,),
                        Text('35,7 - 37,5', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Thân nhiệt'),
                        Text('36,4 - 37,7', textAlign: TextAlign.center,),
                        Text('36,4 - 37,7', textAlign: TextAlign.center,),
                        Text('36,8 - 37,8', textAlign: TextAlign.center,),
                        Text('35,8 - 37,1', textAlign: TextAlign.center,),
                      ]),
                    ]
                ),
              ),
              const Text(
                'Thân nhiệt bình thường ở các vị trí đo khác nhau theo từng độ tuổi',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReferenceValueha extends StatelessWidget {
  const ReferenceValueha({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Giá Trị Tham Chiếu Huyết Áp',
            style: TextStyle(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        body: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 30,),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                    border: TableBorder.all(), // Allows to add a border decoration around your table
                    children: const [
                      TableRow(children :[
                        Text('Loại'),
                        Text('Tâm thu', textAlign: TextAlign.center,),
                        Text('Tâm trương', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Huyết áp thấp',),
                        Text('< 90', textAlign: TextAlign.center,),
                        Text('< 60', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Mong muốn'),
                        Text('90 - 119', textAlign: TextAlign.center,),
                        Text('60 - 79', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Text('Tiền cao huyết áp'),
                        Text('120 - 139', textAlign: TextAlign.center,),
                        Text('80 - 89', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Tooltip (message: 'Tăng huyết áp giai đoạn 1',child: Text('Tăng huyết áp giai đoạn 1', overflow: TextOverflow.ellipsis,)),
                        Text('140 - 159', textAlign: TextAlign.center,),
                        Text('90 - 99', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Tooltip (message: 'Tăng huyết áp giai đoạn 2',child: Text('Tăng huyết áp giai đoạn 2', overflow: TextOverflow.ellipsis,)),
                        Text('160 - 179', textAlign: TextAlign.center,),
                        Text('100 - 109', textAlign: TextAlign.center,),
                      ]),
                      TableRow(children :[
                        Tooltip (message: 'Tăng huyết áp nguy hiểm',child: Text('Tăng huyết áp nguy hiểm', overflow: TextOverflow.ellipsis,)),
                        Text('≥ 180', textAlign: TextAlign.center,),
                        Text('≥ 110', textAlign: TextAlign.center,),
                      ]),
                    ]
                ),
              ),
              const Text(
                'Chỉ số các loại huyết áp ở người trưởng thành (≥ 18 tuổi)',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50,),
              const Text(
                'Lịch sử đo',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              for (var value in SharedPrefs().huyetapdata) Text(value),
            ],
          ),
        ),
      ),
    );
  }
}
