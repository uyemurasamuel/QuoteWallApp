import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'speech_balloon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notifications.dart' as notifications;
import 'logger.dart';
import 'persistent_map.dart';

const nameMap = {
  'Branson': 'Branson',
  'Jeff': 'Jeff',
  'Cass': 'Cass',
  'Steven': 'Steven',
  'Sam U': 'Boy Sam',
  'Mackenzie S': 'Mackenzie S.',
  'Mackenzie M': 'Makenzie M.',
  'Sam R': 'Girl Sam',
  'Neely': 'Neely',
  'Elena': 'Elena',
  'Holly': 'Holly',
  'Tyler': 'Tyler',
  'Grace': 'Grace',
};

const imageMap = {
  'Branson': 'branson',
  'Jeff': 'jeff',
  'Cass': 'cass',
  'Steven': 'steven',
  'Sam U': 'samu',
  'Mackenzie S': 'mack',
  'Mackenzie M': 'mak',
  'Sam R': 'samr',
  'Neely': 'neely',
  'Elena': 'elena',
  'Holly': 'holly',
  'Tyler': 'tyler',
  'Grace': 'grace',
};

String getPreferredName(String author) {
  String? name = nameMap[author];
  return name ?? author;
}

String getImageFilePath(String author) {
  String? imageName = imageMap[author];
  if (imageName != null) {
    return 'assets/images/$imageName.png';
  }
  return 'assets/images/cass.png';
}

Future<void> launchLink(Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
    throw Exception('Could not launch $url');
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class Quote {
  late final String quote;
  late final String author;
  late final String context;

  Quote(this.quote, this.author, this.context);
  Quote.fromJSON(String json) {
    final data = jsonDecode(json);

    quote = data['text'];
    author = data['author'];
    context = data['context'];
  }
}

Future<Quote?> getQuoteFromDate(DateTime date) async {
  final dateString = "${date.year}-${date.month}-${date.day}";
  final url = Uri.parse('https://quotewall.vip/quote-of-the-day?date=$dateString');

  try {
    final response = await http.get(url);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final quote = Quote.fromJSON(response.body);
      log.info("Successfully got quote from date $dateString");
      return Future.value(quote);
    } else {
      log.severe('Fetching quote failed with status: ${response.statusCode}');
    }
  } catch (e) {
    log.severe('Error: $e');
  }
  return Future.value(null);
}

Widget buildQuoteWidget(Quote quote) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      quote.context == "No context given." || quote.context == ""
          ? Container()
          : Text("*Context: ${quote.context}", style: TextStyle(fontSize: 10)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SpeechBalloon(
          borderRadius: 30,
          borderColor: Colors.black,
          nipLocation: NipLocation.bottom,
          nipHeight: 20,
          width: 350,
          color: Colors.grey[300]!,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              quote.quote,
              style: TextStyle(
                wordSpacing: 0.5,
                fontSize: 30,
                fontFamily: 'BangersRegular',
                letterSpacing: 1.5,
                height: 0.9,
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text(
          getPreferredName(quote.author),
          textAlign: TextAlign.left,
          style: TextStyle(fontFamily: 'PressStart'),
        ),
      ),
      SizedBox(width: 60, child: Image.asset(getImageFilePath(quote.author))),
    ],
  );
}

Widget buildQuoteFutureWidget(Future<Quote?> quoteFuture) {
  return FutureBuilder(
    future: quoteFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        final quote = snapshot.data;
        if (quote != null) {
          return buildQuoteWidget(quote);
        }
        return Text("Something went wrong.");
      } else {
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: SpeechBalloon(
                borderRadius: 30,
                borderColor: Colors.black,
                nipLocation: NipLocation.bottom,
                nipHeight: 20,
                width: 350,
                color: Colors.grey[300]!,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '     ...     ',
                    style: TextStyle(
                      wordSpacing: 0.5,
                      fontSize: 30,
                      fontFamily: 'BangersRegular',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 140),
          ],
        );
      }
    },
  );
}

const String EN_NOTIFY_KEY = 'enableNotifications';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  // Get checkbox status
  await PersistentMap.init();
  final pmap = PersistentMap.instance;

  // If doesn't have key (first bootup) then make the key
  if (!pmap.contains(EN_NOTIFY_KEY)) {
    await pmap.set(EN_NOTIFY_KEY, true);
  }

  // Set up push notifications (prompts user for permission), then sync the
  // daily quote subscription with the checkbox. Not awaited so the UI can
  // start while the permission dialog is up.
  notifications.initializeNotifications().then((_) {
    if (pmap.get(EN_NOTIFY_KEY, defaultValue: true)) {
      return notifications.subscribeToDailyQuote();
    } else {
      return notifications.unsubscribeFromDailyQuote();
    }
  }).catchError((e) {
    log.severe("Notification setup failed: $e");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quote Archive',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

int notificationId = 0;

class _MyHomePageState extends State<MyHomePage> {
  late Future<Quote?> _quoteOfTheDay;
  DateTime _date = DateTime.now();
  bool _sendNotifications = true;
  PersistentMap pmap = PersistentMap.instance;

  void _previousDay() {
    setState(() {
      _date = _date.subtract(Duration(days: 1));
      _quoteOfTheDay = getQuoteFromDate(_date);
    });
  }

  void _nextDay() {
    if (isSameDay(_date, DateTime.now()) || DateTime.now().difference(_date).isNegative) {
      return;
    }
    setState(() {
      _date = _date.add(Duration(days: 1));
      _quoteOfTheDay = getQuoteFromDate(_date);
    });
  }

  void _enableNotifications() {
    log.info("Enabling notifications");
    notifications.subscribeToDailyQuote();
  }

  void _disableNotifications() {
    log.info("Disabling notifications");
    notifications.unsubscribeFromDailyQuote();
  }

  @override
  void initState() {
    super.initState();
    log.info("Initializing home page state");
    _quoteOfTheDay = getQuoteFromDate(_date);
    _sendNotifications = pmap.get(EN_NOTIFY_KEY, defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    String label = "ERR";
    if (isSameDay(_date, DateTime.now())) {
      label = "Today";
    } else {
      label = "${_date.month}/${_date.day}/${_date.year}";
    }
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 111, 168, 220),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          label,
          style: TextStyle(
            wordSpacing: 0.5,
            fontSize: 30,
            fontFamily: 'BangersRegular',
            letterSpacing: 1.5,
            height: 0.9,
          ),
        ),
        leading: IconButton(iconSize: 35, icon: Icon(Icons.arrow_back), onPressed: _previousDay),
        actions: [
          IconButton(
            iconSize: 35,
            icon: Icon(Icons.arrow_forward),
            onPressed: isSameDay(_date, DateTime.now()) ? null : _nextDay,
          ),
        ],
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            buildQuoteFutureWidget(_quoteOfTheDay),
            Container(
              height: 300,
              color: Color.fromRGBO(50, 150, 0, 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: CheckboxListTile(
                      activeColor: Color.fromRGBO(0, 100, 0, 1),
                      checkboxScaleFactor: 2,
                      value: _sendNotifications,
                      onChanged: (value) {
                        if (value != null) {
                          if (value == true) {
                            _enableNotifications();
                          } else {
                            _disableNotifications();
                          }
                          setState(() {
                            _sendNotifications = value;
                            pmap.set(EN_NOTIFY_KEY, value);
                          });
                        }
                      },
                      title: Text(
                        "Daily Quote Notifications",
                        style: TextStyle(fontFamily: 'PressStart', fontSize: 14),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Color.fromRGBO(0, 100, 0, 1)),
                    ),
                    child: Text(
                      "Submit Quote",
                      style: TextStyle(color: Colors.white, fontFamily: 'PressStart'),
                    ),
                    onPressed: () {
                      final uri = Uri.https('quotewall.vip', '/submit-quote');
                      try {
                        launchLink(uri);
                      } catch (e) {
                        log.severe("Error launching quotewall submit-quote link.");
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ), //This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
