import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WakelockPlus.enable();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final showTutorialOnStart = prefs.getBool('showTutorialOnStart') ?? true;

  runApp(HofNinjaApp(showTutorial: showTutorialOnStart));
}

class HofNinjaApp extends StatelessWidget {
  final bool showTutorial;
  const HofNinjaApp({super.key, required this.showTutorial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hof Ninja',
      debugShowCheckedModeBanner: false,

      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),

        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 255, 255, 255),
          secondary: Color.fromARGB(255, 138, 125, 5),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 0, 31, 77),
        ),

        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoAnimationBuilder(),
            TargetPlatform.iOS: NoAnimationBuilder(),
          },
        ),
      ),

      home: IntroScreen(showTutorial: showTutorial),
    );
  }
} 

// --- AudioController ---
class AudioController {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  bool _mutedByUser = false;

  static final AudioController instance = AudioController._internal();
  AudioController._internal() {
  _player.setPlayerMode(PlayerMode.mediaPlayer);
  _player.setAudioContext(AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  ));
}

  Future<void> init() async {
    if (_initialized) return;

    _player.setReleaseMode(ReleaseMode.loop);

    _player.onPlayerStateChanged.listen((state) {
    });
    _player.onPlayerComplete.listen((_) {
    });

    _initialized = true;
  }

  Future<void> startWave({bool force = false}) async {
    if (!_initialized) await init();

    if (_mutedByUser && !force) {
      return;
    }

    
    try {      
      if (_player.state == PlayerState.playing && !force) {
        return;
      }

      await _player.setVolume(0.12);

      if (force) {
        await _player.stop();
        await _player.seek(Duration.zero);
      }

      await _player.play(AssetSource('audio/morze.mp3'));
    } catch (e, st) {
      debugPrint('AudioController: $e\n$st');
    }
  }


  Future<void> stopWave() async {
    await _player.stop();
  }

  Future<void> toggleWave() async {
    if (!_initialized) await init();

    if (_player.state == PlayerState.playing) {
      await stopWave();
      _mutedByUser = true;
    } else {
      _mutedByUser = false;
      await startWave();
    }
  }

  void dispose() {
    _player.dispose();
  }
}

// --- koniec AudioController 

// No animation class
class NoAnimationBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}


// ----------------------------- Shared helpers -----------------------------
Future<void> saveSetting(String key, Object value) async {
  final prefs = await SharedPreferences.getInstance();
  if (value is bool) {
    await prefs.setBool(key, value);
  } else if (value is double) {
    await prefs.setDouble(key, value);
  } else if (value is int) {
    await prefs.setInt(key, value);
  } else if (value is String) {
    await prefs.setString(key, value);
  } else {
    throw Exception('Unsupported setting type for $key');
  }
}

// ----------------------------- Return Bar -----------------------------

AppBar sessionAppBar(BuildContext context) {
  return AppBar(
    automaticallyImplyLeading: false,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        AudioController.instance.stopWave(); 
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainPanel()),
          (route) => false,
        );
      },
    ),
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
  );
}

// ----------------------------- Vibrations -----------------------------

Future<void> vibrateIfEnabled(Map<String, dynamic> settings) async {
  final vibrations = settings['vibrations'] as bool;
  if (vibrations) {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 1500);
      }
    } catch (e) {
      print('Vibration not supported: $e');
    }
  }
}

// ----------------------------- Audio -----------------------------
final AudioPlayer _globalPlayer = AudioPlayer();

Future<void> playSound(String assetPath, {bool loop = false}) async {
  try {
    await _globalPlayer.stop();
    if (loop) {
      await _globalPlayer.setReleaseMode(ReleaseMode.loop);
    } else {
      await _globalPlayer.setReleaseMode(ReleaseMode.release);
    }
    await _globalPlayer.play(AssetSource(assetPath));
  } catch (e) {
    print('Error playing sound: $e');
  }
}

// ----------------------------- Intro Screen -----------------------------
class IntroScreen extends StatelessWidget {
  final bool showTutorial;
  const IntroScreen({super.key, required this.showTutorial});

  static const blogUrl = 'https://notatki-hakera.pl/';

  Future<void> _openBlog() async {
    final uri = Uri.parse(blogUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // ignore: avoid_print
      print('Could not launch $blogUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // app logo
              Image.asset('assets/images/ninja.png',
                  width: 160,
                  height: 160,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, size: 120)),
              const SizedBox(height: 28),
              const Text(
                'HOF NINJA',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _openBlog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                  'ABOUT AUTHOR',
                  style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (showTutorial) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TutorialScreen()));
                  } else {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const MainPanel()));
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('NINJA BEGINS TO BREATHE!', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Tutorial Screen (11 pages) -----------------------------
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int page = 0;

  final List<String> tutorialImages =
      List.generate(11, (i) => 'assets/tutorial/tutorial_${i + 1}.png');
  final List<String> tutorialTitles = [
  'Hello, Hof Ninja! 🥷',
  'Before You Begin',
  'Understanding the Cycle',
  'Breathing Rhythm 🔵(2)',
  'Power Breathing Phase 🔵(2)',
  'What You Might Feel',
  'After Exhale 🟠(3)',
  'Recovery Breath 🟤(4)',
  'Remember Your Progress 🟠(3)',
  'Make It Yours 🎨',
  'Let\'s go!',
];

final List<String> tutorialDescriptions = [
  'Wim Hof Breathing Method is a simple yet powerful technique that will help you:\n\n- Boost your energy levels\n- Reduce stress and anxiety\n- Strengthen your immune system\n- Sharpen your focus\n- Improve sleep quality\n- Increase cold tolerance\n- Enhance overall mood and emotional balance\n- Support faster recovery after exercise\n\nReady to transform yourself?',
  '✓ Take a cold shower for 1-10 min (optional)\n✓ Sit comfortably or lie down\n✓ Find a quiet space\n✓ Loosen any tight (ninja) clothing\n ✓ Keep a phone in your hand\n✓ Connect to speaker or headphones (optional)\n\n\Never practice while driving or in water!',
  '1. Countdown Before: 5-30 sec. (once time)\n2. 🔵 Power Breathing: 30-80 deep breaths \n (Ninja Hof: 5-150 breaths available!)\n3. 🟠 Hold: Breath retention on exhale\n4. 🟤 Recovery Breath: Deep inhale + hold\n5. Break - Rest for 5-30 sec.\n\nThis app will guide you through each phase!',
  'Find Your Flow\n\n 🌬️\nInhale: \nDeep and full - belly, chest, head\n\n💨\nExhale:\nLet go naturally - no force needed\n\nBreathe at YOUR comfortable rate!\nThink of it like waves  🌊 - smooth and rhythmic.',
  'Repeat the inhale-exhale sequence 30-80 times.\n\n🎯 Each breath should feel full but effortless\n🎯 Don\'t force or strain\n🎯 Let the app guide your rhythm\n\nYour body knows what to do - trust it!',
  'Normal Sensations:\n\n✨ Tingling in hands, feet, or face\n✨ Lightheadedness or dizziness\n✨ Feeling of energy or alertness\n✨ Warmth spreading through body\n\nThese are signs it\'s working!\nIf uncomfortable, simply slow down.',
  'Let all air out naturally.\n\n⏸️ Hold your breath (on empty lungs)\n🟠 Stay relaxed - don\'t create tension\n🟠 Wait until you feel the urge to breathe\n🟠 Notice your body\'s signals\n\nEvery second counts - but don\'t compete!',
  'When You Need Air...\n\n🫁 Take one BIG, DEEP breath\n⏱️ Hold it for 15 seconds\n✨ Feel the oxygen flooding in\n😌 Release and fully relax\n\nThat\'s one complete round! Rest before your next round.',
  'See Your Improvement\n\n⏱️\n Before practice: \nHold your breath - note the time\n\n⏱️\nAfter practice:\nHold again - compare\n\nLonger hold time = technique is working!\nMost people double their time within weeks.',
  '⏱️ Breathing Rate: 0.4-30.0 points per breath\n☀️ Rounds: Start with 3, build up\n🫁 Breaths: 30-40 per round recommended\n(but 80-150 is fun! ✨)\nSounds: Ocean waves 🌊, for relaxation\n📳 Vibrations: Gentle guidance\n🎵 Breathing sounds: Follow the rhythm.\n\n\ 💡 Experiment and find what feels right for YOU',
  'You\'re All Set\n\n🎯 Start with minimal settings\n📅 Practice daily for best results\n📈 Watch your retention time grow\n💪 Trust the process\n\nTake a deep breath and press Let\'s go!\nYour journey begins now!🚀\n\nReady, Hof Ninja? 🥷',
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ninja Tutorial'),
        actions: [
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const MainPanel()));
            },
            child: const Text('Skip Screen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    tutorialImages[page],
                    height: 330,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 140),
                  ),
                  const SizedBox(height: 24),

                  // --- Tytuł ---
                  Text(
                    tutorialTitles[page],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- Opis ---
                  Text(
                    tutorialDescriptions[page],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: page == 0 ? null : () => setState(() => page--),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (page < 10) {
                      setState(() => page++);
                    } else {
                      if (!mounted) return;
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const MainPanel()));
                    }
                  },
                  child: Text(page == 10 ? 'Finish' : 'Next Page'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ----------------------------- Main Panel -----------------------------
class MainPanel extends StatefulWidget {
  const MainPanel({super.key});

  @override
  State<MainPanel> createState() => _MainPanelState();
}

class _MainPanelState extends State<MainPanel> {
  double tempo = 1.5; 
  int rounds = 4;
  int breaths = 40;
  int countdownBefore = 15;
  int breakSec = 10;

  bool bgSound = false;
  bool vibrations = false;
  bool breathingSounds = false;
  bool tutorialEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tempo = prefs.getDouble('tempo') ?? 1.5;
      rounds = prefs.getInt('rounds') ?? 4;
      breaths = prefs.getInt('breaths') ?? 40;
      countdownBefore = prefs.getInt('countdownBefore') ?? 15;
      breakSec = prefs.getInt('breakSec') ?? 10;
      bgSound = prefs.getBool('bgSound') ?? false;
      vibrations = prefs.getBool('vibrations') ?? false;
      breathingSounds = prefs.getBool('breathingSounds') ?? false;
      tutorialEnabled = prefs.getBool('showTutorialOnStart') ?? true;
    });
  }

  Future<void> _saveDouble(String key, double value) async =>
      await saveSetting(key, value);
  Future<void> _saveInt(String key, int value) async =>
      await saveSetting(key, value);
  Future<void> _saveBoolVal(String key, bool value) async =>
      await saveSetting(key, value);

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget buildTempoSlider() {
    return Row(
      children: [
        Expanded(
          child: Slider(
            min: 0.4,
            max: 30.0,
            divisions: 25,
            value: tempo,
            label: tempo.toStringAsFixed(1),
            onChanged: (val) {
              final rounded = (val * 10).round() / 10.0;
              setState(() {
                tempo = rounded;
              });
            },
            onChangeEnd: (val) async {
              final rounded = (val * 10).round() / 10.0;
              tempo = rounded;
              await _saveDouble('tempo', tempo);
            },
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Mniej (0.1s)',
              onPressed: () async {
                setState(() {
                  tempo = (((tempo - 0.1) * 10).round()) / 10.0;
                  if (tempo < 0.4) tempo = 30.0;
                });
                await _saveDouble('tempo', tempo);
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(tempo.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'Więcej (0.1s)',
              onPressed: () async {
                setState(() {
                  tempo = (((tempo + 0.1) * 10).round()) / 10.0;
                  if (tempo > 30.0) tempo = 0.4;
                });
                await _saveDouble('tempo', tempo);
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        )
      ],
    );
  }

  Widget _numberCounter(
      String label, int value, int min, int max, void Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$value', style: const TextStyle(fontSize: 16)),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        )
      ],
    );
  }

  Widget _stepSlider(String label, int value, void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value sec.'),
        Slider(
          min: 5,
          max: 30,
          divisions: 5,
          value: value.toDouble(),
          onChanged: (v) => onChanged(v.round()),
        )
      ],
    );
  }

  Widget _buildSwitch(String label, bool val, void Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: val,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hof Ninja (Panel)'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveDouble('tempo', tempo);
              await _saveInt('rounds', rounds);
              await _saveInt('breaths', breaths);
              await _saveInt('countdownBefore', countdownBefore);
              await _saveInt('breakSec', breakSec);
              await _saveBoolVal('bgSound', bgSound);
              await _saveBoolVal('vibrations', vibrations);
              await _saveBoolVal('breathingSounds', breathingSounds);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('showTutorialOnStart', tutorialEnabled);

              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BreathingFlowStart()));
            },
            child:
                const Text("Let's go!", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Breathing Rate: ${tempo.toStringAsFixed(1)} points'),
          buildTempoSlider(),
          const SizedBox(height: 8),
          _numberCounter(
              'Rounds', rounds, 1, 40, (v) => setState(() => rounds = v)),
          const SizedBox(height: 8),
          _numberCounter(
              'Breaths', breaths, 5, 150, (v) => setState(() => breaths = v)),
          const SizedBox(height: 8),
          _stepSlider('Countdown Before', countdownBefore,
              (v) => setState(() => countdownBefore = v)),
          const SizedBox(height: 8),
          _stepSlider('Break', breakSec, (v) => setState(() => breakSec = v)),
          const SizedBox(height: 8),
          _buildSwitch(
            'Wave Sound',
            bgSound,
            (v) => setState(() {
              bgSound = v;
              saveSetting('bgSound', v);
            }),
          ),
          _buildSwitch(
              'Vibrations',
              vibrations,
              (v) => setState(() {
                    vibrations = v;
                    saveSetting('vibrations', v);
                  })),
          _buildSwitch(
              'Breathings',
              breathingSounds,
              (v) => setState(() {
                    breathingSounds = v;
                    saveSetting('breathingSounds', v);
                  })),
          _buildSwitch('Tutorial', tutorialEnabled, (v) async {
            setState(() {
              tutorialEnabled = v;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('showTutorialOnStart', v);
          }),
        ],
      ),
    );
  }
}



// ----------------------------- Breathing Flow (final integrated) -----------------------------

// Load settings
Future<Map<String, dynamic>> loadBreathingSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'tempo': prefs.getDouble('tempo') ?? 1.5,
    'rounds': prefs.getInt('rounds') ?? 3,
    'breaths': prefs.getInt('breaths') ?? 30,
    'countdownBefore': prefs.getInt('countdownBefore') ?? 5,
    'breakSec': prefs.getInt('breakSec') ?? 30,
    'breathingSounds': prefs.getBool('breathingSounds') ?? false,
    'bgSound': prefs.getBool('bgSound') ?? false,  // ✅ DODAJ TĘ LINIĘ
    'vibrations': prefs.getBool('vibrations') ?? false,  // ✅ DODAJ TEŻ vibrations
  };
}

// Entry — ONLY first time shows countdown
class BreathingFlowStart extends StatelessWidget {
  const BreathingFlowStart({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadBreathingSettings(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = snap.data!;

        return BreathingCountdown(
          settings: settings,
          round: 1,
        );
      },
    );
  }
}

class BreathingCountdown extends StatefulWidget {
  final Map<String, dynamic> settings;
  final int round;
  const BreathingCountdown({super.key, required this.settings, required this.round});
  @override
  State<BreathingCountdown> createState() => _BreathingCountdownState();
}

class _BreathingCountdownState extends State<BreathingCountdown> {
  late int count;
  @override
  void initState() {
    super.initState();
    count = widget.settings['countdownBefore'];
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) t.cancel();
      if (count <= 0) {
        t.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BreathingSession(
              settings: widget.settings,
              round: widget.round,
              breathIndex: 1,
            ),
          ),
        );
      } else {
        setState(() => count--);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('$count', style: const TextStyle(fontSize: 60))));
}

// SESSION = breathing -> exhale -> hold -> break -> session (next) / end

class BreathingSession extends StatefulWidget {
  final Map<String, dynamic> settings;
  final int round;
  final int breathIndex;
  const BreathingSession({
    super.key,
    required this.settings,
    required this.round,
    required this.breathIndex,
  });

  @override
  State<BreathingSession> createState() => _BreathingSessionState();
}

class _BreathingSessionState extends State<BreathingSession>
    with SingleTickerProviderStateMixin {
  late AnimationController ctrl;
  late final AudioPlayer inhalePlayer;
  late final AudioPlayer exhalePlayer;
  bool isInhaling = true;
  bool playersReady = false;
  bool disposed = false;

  @override
  void initState() {
    super.initState();

    if (widget.settings['bgSound'] == true) {
      try {
        AudioController.instance.startWave();
      } catch (_) {}
    }

    inhalePlayer = AudioPlayer();
    exhalePlayer = AudioPlayer();

    final tempo = (widget.settings['tempo'] as num).toDouble();
    ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (tempo * 1000).toInt()),
    );

    ctrl.addListener(() {
    });

    ctrl.addStatusListener(_onCtrlStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || disposed) return;
      ctrl.forward(from: 0);
    });

    _prepareAudio();
  }

  Future<void> _prepareAudio() async {
    try {
      await inhalePlayer.setSourceAsset('audio/in.mp3');
      await inhalePlayer.setReleaseMode(ReleaseMode.stop);

      await exhalePlayer.setSourceAsset('audio/out.mp3');
      await exhalePlayer.setReleaseMode(ReleaseMode.stop);

      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted || disposed) return;

      playersReady = true;

      if (widget.settings['breathingSounds'] == true) {
        if (isInhaling) {
          try {
            inhalePlayer.seek(Duration.zero);
            await inhalePlayer.resume();
          } catch (_) {}
        } else {
          try {
            exhalePlayer.seek(Duration.zero);
            await exhalePlayer.resume();
          } catch (_) {}
        }
      }
    } catch (e) {
      playersReady = false;
    }
  }

  void _onCtrlStatus(AnimationStatus status) {
    if (!mounted || disposed) return;

    if (status == AnimationStatus.completed) {
      isInhaling = false;

      if (widget.settings['breathingSounds'] == true && playersReady) {
        try {
          exhalePlayer.seek(Duration.zero);
          exhalePlayer.resume();
        } catch (_) {}
      }

      ctrl.stop();
      Future.delayed(const Duration(milliseconds: 20), () {
        if (mounted && !disposed) ctrl.reverse();
      });
    }

    if (status == AnimationStatus.dismissed) {
      isInhaling = true;

      if (widget.settings['breathingSounds'] == true && playersReady) {
        try {
          inhalePlayer.seek(Duration.zero);
          inhalePlayer.resume();
        } catch (_) {}
      }

      final breaths = widget.settings['breaths'] as int;
      final index = widget.breathIndex;

      if (index < breaths) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BreathingSession(
              key: UniqueKey(),
              settings: widget.settings,
              round: widget.round,
              breathIndex: index + 1,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExhaleScreen(
              key: UniqueKey(),
              settings: widget.settings,
              round: widget.round,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    disposed = true;

    try {
      ctrl.removeStatusListener(_onCtrlStatus);
    } catch (_) {}
    try {
      ctrl.dispose();
    } catch (_) {}
    try {
      inhalePlayer.dispose();
    } catch (_) {}
    try {
      exhalePlayer.dispose();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breaths = widget.settings['breaths'] as int;
    final index = widget.breathIndex;

    return WillPopScope(
      onWillPop: () async {
        try {
          AudioController.instance.stopWave();
        } catch (_) {}
        return true;
      },
      child: Scaffold(
        appBar: sessionAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: ctrl,
                builder: (context, _) {
                  double scale = 0.6 + ctrl.value * 0.4;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              Text("$index / $breaths", style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text("Round: ${widget.round}", style: const TextStyle(fontSize: 21)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExhaleScreen extends StatefulWidget {
  final Map<String, dynamic> settings;
  final int round;
  const ExhaleScreen({super.key, required this.settings, required this.round});
  @override
  State<ExhaleScreen> createState() => _ExhaleScreenState();
}

class _ExhaleScreenState extends State<ExhaleScreen> {
  late Timer t;
  int sec = 0;

  String fmt(int s) =>
      "${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}";

  void _proceedToHold() {
    if (!mounted) return;
    t.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HoldScreen(settings: widget.settings, round: widget.round),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    vibrateIfEnabled(widget.settings)
        .catchError((e) => print('Vibration error: $e'));
    playSound('audio/exhale.mp3')
        .catchError((e) => print('Audio error: $e'));

    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => sec++);
      });
    });
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        AudioController.instance.stopWave();
        return true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _proceedToHold,
        child: Scaffold(
          appBar: sessionAppBar(context),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(fmt(sec), style: const TextStyle(fontSize: 50)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _proceedToHold,
                  child: const Text("Double Tap"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HoldScreen extends StatefulWidget {
  final Map<String, dynamic> settings;
  final int round;
  const HoldScreen({super.key, required this.settings, required this.round});
  @override
  State<HoldScreen> createState() => _HoldScreenState();
}

class _HoldScreenState extends State<HoldScreen> {
  int sec = 15;

  @override
  void initState() {
    super.initState();
    vibrateIfEnabled(widget.settings)
        .catchError((e) => print('Vibration error: $e'));
    playSound('audio/hold.mp3')
        .catchError((e) => print('Audio error: $e'));

    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (sec <= 0) {
          t.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BreakScreen(settings: widget.settings, round: widget.round),
            ),
          );
        } else {
          setState(() => sec--);
        }
      });
    });
  }

  String fmt(int s) =>
      "${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        AudioController.instance.stopWave();   // ← tutaj
        return true;
      },
      child: Scaffold(
        appBar: sessionAppBar(context),
        body: Center(
          child: Text("Hold: ${fmt(sec)}", style: const TextStyle(fontSize: 50)),
        ),
      ),
    );
  }
}

// BREAK — after break go directly to breathing session (not countdown)
class BreakScreen extends StatefulWidget {
  final Map<String, dynamic> settings;
  final int round;
  const BreakScreen({super.key, required this.settings, required this.round});
  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> {
  late int count;

  @override
  void initState() {
    super.initState();

    vibrateIfEnabled(widget.settings)
        .catchError((e) => print('Vibration error: $e'));

    if (widget.round >= widget.settings['rounds']) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BreathingEnd()),
        );
      });
      return;
    }

    count = widget.settings['breakSec'];

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) t.cancel();
      if (count <= 0) {
        t.cancel();

        if (widget.round < widget.settings['rounds']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BreathingSession(
                settings: widget.settings,
                round: widget.round + 1,
                breathIndex: 1,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BreathingEnd()),
          );
        }
      } else {
        setState(() => count--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        AudioController.instance.stopWave();
        return true;
      },
      child: Scaffold(
        appBar: sessionAppBar(context),
        body: Center(
            child: Text("Break: $count", style: const TextStyle(fontSize: 40))),
      ),
    );
  }
}

class BreathingEnd extends StatelessWidget {
  const BreathingEnd({super.key});

  @override
  Widget build(BuildContext context) {

    AudioController.instance.stopWave();

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          Navigator.pop(context); 
        },
        child: const Center(
          child: Text(
            "I wish you a good life!",
            style: TextStyle(fontSize: 17),
          ),
        ),
      ),
    );
  }
}
