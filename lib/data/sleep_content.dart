import 'package:flutter/material.dart';

class RadioStation {
  final String title;
  final String subtitle;
  final IconData icon;
  final String streamUrl;
  final Color color;

  const RadioStation({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.streamUrl,
    required this.color,
  });
}

class SleepStory {
  final String title;
  final String author;
  final String duration;
  final String preview;
  final String body;

  const SleepStory({
    required this.title,
    required this.author,
    required this.duration,
    required this.preview,
    required this.body,
  });
}

const radioStations = [
  RadioStation(
    title: 'Drone Zone',
    subtitle: 'Ambient space music • SomaFM',
    icon: Icons.blur_on,
    streamUrl: 'https://ice1.somafm.com/dronezone-256-mp3',
    color: Color(0xFF1A237E),
  ),
  RadioStation(
    title: 'Deep Space One',
    subtitle: 'Deep ambient electronic • SomaFM',
    icon: Icons.rocket_launch,
    streamUrl: 'https://ice1.somafm.com/deepspaceone-128-mp3',
    color: Color(0xFF0D47A1),
  ),
  RadioStation(
    title: 'Groove Salad',
    subtitle: 'Ambient & downtempo • SomaFM',
    icon: Icons.spa,
    streamUrl: 'https://ice1.somafm.com/groovesalad-256-mp3',
    color: Color(0xFF2E7D32),
  ),
  RadioStation(
    title: 'Groove Salad Classic',
    subtitle: 'Original downtempo classics • SomaFM',
    icon: Icons.eco,
    streamUrl: 'https://ice1.somafm.com/gsclassic-128-mp3',
    color: Color(0xFF388E3C),
  ),
  RadioStation(
    title: 'Mission Control',
    subtitle: 'NASA deep space network • SomaFM',
    icon: Icons.satellite_alt,
    streamUrl: 'https://ice1.somafm.com/missioncontrol-128-mp3',
    color: Color(0xFF37474F),
  ),
  RadioStation(
    title: 'Fluid',
    subtitle: 'Instrumental hip hop & future chill • SomaFM',
    icon: Icons.water,
    streamUrl: 'https://ice1.somafm.com/fluid-128-mp3',
    color: Color(0xFF00695C),
  ),
  RadioStation(
    title: 'Sleep Pig',
    subtitle: 'Music to help you sleep • SomaFM',
    icon: Icons.bedtime,
    streamUrl: 'https://ice1.somafm.com/sleeppig-128-mp3',
    color: Color(0xFF4A148C),
  ),
  RadioStation(
    title: 'Vaporwaves',
    subtitle: 'Vaporwave, future funk & chillwave • SomaFM',
    icon: Icons.cloud,
    streamUrl: 'https://ice1.somafm.com/vaporwaves-128-mp3',
    color: Color(0xFF880E4F),
  ),
  RadioStation(
    title: 'n5MD Radio',
    subtitle: 'Post-rock, ambient & experimental • SomaFM',
    icon: Icons.album,
    streamUrl: 'https://ice1.somafm.com/n5md-128-mp3',
    color: Color(0xFF263238),
  ),
  RadioStation(
    title: 'Space Station Soma',
    subtitle: 'Ambient spacemusic • SomaFM',
    icon: Icons.auto_awesome,
    streamUrl: 'https://ice1.somafm.com/spacestation-128-mp3',
    color: Color(0xFF1565C0),
  ),
];

class RadioBrowseCategory {
  final String label;
  final String tag;
  final IconData icon;
  final Color color;

  const RadioBrowseCategory({
    required this.label,
    required this.tag,
    required this.icon,
    required this.color,
  });
}

const radioBrowseCategories = [
  RadioBrowseCategory(
    label: 'Ambient',
    tag: 'ambient',
    icon: Icons.blur_on,
    color: Color(0xFF3F51B5),
  ),
  RadioBrowseCategory(
    label: 'Sleep',
    tag: 'sleep',
    icon: Icons.bedtime,
    color: Color(0xFF5C6BC0),
  ),
  RadioBrowseCategory(
    label: 'Nature',
    tag: 'nature',
    icon: Icons.forest,
    color: Color(0xFF4CAF50),
  ),
  RadioBrowseCategory(
    label: 'Relaxation',
    tag: 'relaxation',
    icon: Icons.spa,
    color: Color(0xFF009688),
  ),
  RadioBrowseCategory(
    label: 'Meditation',
    tag: 'meditation',
    icon: Icons.self_improvement,
    color: Color(0xFF00BCD4),
  ),
  RadioBrowseCategory(
    label: 'Classical',
    tag: 'classical',
    icon: Icons.piano,
    color: Color(0xFF795548),
  ),
  RadioBrowseCategory(
    label: 'Chillout',
    tag: 'chillout',
    icon: Icons.airline_seat_recline_normal,
    color: Color(0xFFE91E63),
  ),
  RadioBrowseCategory(
    label: 'Lo-Fi',
    tag: 'lofi',
    icon: Icons.headphones,
    color: Color(0xFF9C27B0),
  ),
  RadioBrowseCategory(
    label: 'Jazz',
    tag: 'jazz',
    icon: Icons.music_note,
    color: Color(0xFFFF9800),
  ),
  RadioBrowseCategory(
    label: 'New Age',
    tag: 'new age',
    icon: Icons.auto_awesome,
    color: Color(0xFF607D8B),
  ),
];

const sleepStories = [
  SleepStory(
    title: 'The Lighthouse Keeper',
    author: 'PahingApp',
    duration: '5 min read',
    preview: 'A gentle keeper tends a lighthouse on a quiet island...',
    body: '''On a small island far from any city, there is a lighthouse. Its beam sweeps slowly across the dark water, a calm rhythm that has not changed in fifty years.

The keeper's name is Thomas. Each evening, as the sun slips beneath the horizon, he climbs the winding staircase — ninety-seven steps — to light the great lamp. The stairs creak softly under his feet, a sound as familiar as his own breathing.

Tonight the air is still. The ocean barely moves, just a gentle rise and fall, like the chest of someone sleeping. Thomas sits in his wooden chair beside the lamp and looks out at the water. Stars appear one by one, reflected in the sea until the sky and the water become the same thing — a vast, dark blanket of tiny lights.

He listens. There is the slow wash of waves against the rocks below. The distant call of a seabird settling for the night. The soft ticking of the lighthouse clock.

Thomas opens his journal and writes: "Clear skies. Calm seas. Nothing to report." He writes this most nights, and it brings him comfort. Nothing to report means everything is well. Everything is safe.

He thinks about the ships that pass in the night — their crews looking for his light, a steady glow that says: you are on the right path, keep going, all is well.

The lamp turns slowly. Light, then dark, then light again. A heartbeat for the ocean.

Thomas leans back in his chair. The warmth of the lamp is pleasant on his face. His eyelids grow heavy. The sounds of the night — the water, the clock, the slow turn of the lamp — blend together into a single, soft hum.

He doesn't need to fight it. The light will keep turning on its own. The ocean will keep breathing. The stars will keep watch.

Thomas closes his eyes, and the island sleeps.''',
  ),
  SleepStory(
    title: 'The Cloud Garden',
    author: 'PahingApp',
    duration: '4 min read',
    preview: 'High above the world, an old woman tends a garden in the clouds...',
    body: '''High above the world, above the tallest mountain and the highest-flying bird, there is a garden. It sits on a cloud — not a stormy one, but the kind that looks like a cotton pillow in the afternoon sky.

An old woman named Lina tends this garden. She has been here longer than she can remember, and she doesn't mind one bit. Her garden grows unusual things: silver flowers that hum when the breeze passes through them, soft mosses that glow faintly blue, and trees whose leaves are made of the thinnest mist you've ever seen.

Each evening, Lina walks the winding paths of her garden with a watering can that never runs empty. The water is not ordinary water; it's made of starlight, collected in a basin that sits at the center of the garden.

As she waters each flower, it releases a scent: lavender from the silver blooms, warm vanilla from the golden ones, and something like fresh rain from the tiny blue ones that grow along the edges.

The cloud drifts slowly, and below, the world grows quiet. Cities dim their lights. Fields of wheat go still. Rivers slow to a whisper.

Lina finishes her watering and sits on a bench made from a curved piece of cloud. She looks down and watches the world settle into sleep. She can see bedroom windows glowing softly, the last lights before rest.

"Sleep well," she whispers, and the breeze carries her words down, sprinkling them over rooftops and treetops and open windows.

Lina pulls a blanket of fog across her lap. The silver flowers hum their lullaby — a sound so gentle it's more of a feeling than a noise. The blue moss glows a little brighter, then fades, then glows again, a slow pulse like a resting heart.

The garden drifts on, carrying its small guardian through the night sky. And below, everyone who hears the faintest hum of the silver flowers turns over in their bed and sinks a little deeper into sleep.''',
  ),
  SleepStory(
    title: 'The Sleepy Train',
    author: 'PahingApp',
    duration: '5 min read',
    preview: 'A night train glides through mountains and valleys...',
    body: '''Somewhere in a quiet corner of the world, a train begins its nightly journey. It's not a fast train — there's no rush. It moves at exactly the pace of a comfortable yawn.

You're sitting in a carriage with soft seats covered in deep blue velvet. A small reading lamp casts a warm circle of light, and the window beside you is large enough to frame the world like a painting.

The train hums as it leaves the station. Not a loud hum, but a low, steady vibration that you feel in your chest — a sound that says: I will carry you, you don't need to carry anything tonight.

Fields appear outside your window. They are bathed in moonlight, silver and still, stretching to the horizon. A barn here. A pond there. Everything sleeping already.

The train enters a valley. Tall pines stand on either side of the tracks, their branches heavy and dark. You can almost smell them through the glass — clean, woody, cool. An owl watches the train pass with calm, golden eyes, then turns its head away. Nothing unusual. Just the sleepy train, right on time.

A gentle knock, and the conductor appears: an older gentleman with kind eyes and a voice like warm tea. "We'll pass through the mountain tunnel soon," he says softly. "Very peaceful in there."

And it is. The tunnel wraps around the train like a blanket. The rhythmic click of wheels on rails echoes gently: ta-dum, ta-dum, ta-dum. It's the most soothing sound you've ever heard.

When the train emerges, there's a lake. Perfectly still. The moon is reflected in it so clearly that for a moment there are two moons — one in the sky, one in the water. The train curves around the lake's edge, and the reflection ripples just slightly, then goes still again.

You lean your head against the cool window. The velvet seat holds you perfectly. The lamp dims as if it knows what you need.

The train will keep going — through meadows and over bridges, past sleeping villages and silent rivers. It knows the way. It's taken this route a thousand nights before.

You don't need to stay awake for any of it. The train will carry you all the way to morning.''',
  ),
  SleepStory(
    title: 'The Bookshop at the End of the Lane',
    author: 'PahingApp',
    duration: '4 min read',
    preview: 'A dusty old bookshop where stories read themselves to you...',
    body: '''There's a bookshop at the end of a narrow lane that most people walk right past. It has no sign outside, just a wooden door with a brass handle worn smooth by years of gentle hands.

Inside, it smells of old paper and candle wax and something like cinnamon. The shelves stretch from floor to ceiling, and they're filled with books of every size — thick ones and thin ones, some with leather covers, some with cloth, some with no covers at all, just their stories, bare and honest.

The owner is a cat. A large, orange tabby named Chapter who sits on the counter and blinks slowly at anyone who enters. Chapter doesn't speak, but he doesn't need to. He nudges books toward visitors with his paw, always choosing exactly the right one.

Tonight, the shop is empty except for you. You've come in from the rain — you can hear it pattering on the windows, a soft, steady rhythm. Chapter looks up, blinks once, and pushes a small book toward you. Its cover is the color of the night sky, and when you open it, the pages are blank.

But then words begin to appear, one line at a time, as if someone is writing them just for you. The handwriting is beautiful and unhurried:

"Once, in a place very much like this one, there was someone who needed to rest. Not because they were weak, but because they had carried so much during the day — thoughts and tasks and worries, all packed carefully into their mind like books on a shelf."

You settle into the old armchair by the window. It's impossibly comfortable, as if it were made specifically for you. Chapter jumps down from the counter and curls up on your lap. His purring vibrates gently against your legs.

The book continues its story, but you don't need to read ahead. The words come at exactly the right pace — slow enough to follow without effort, gentle enough to let your eyelids rest.

The rain taps on. Chapter purrs. The candle flickers. And the book, sensing you're nearly asleep, writes its final line:

"And so they rested, knowing that every story pauses here — in this warm place, in this quiet moment — and picks up again when morning comes."''',
  ),
  SleepStory(
    title: 'The Night Baker',
    author: 'PahingApp',
    duration: '4 min read',
    preview: 'A baker works through the night, filling the town with warmth...',
    body: '''In a small town where the streets are cobblestone and the rooftops are made of red clay, there is a bakery. Its windows glow golden each night, the only light on the sleeping street.

The baker's name is Rosa. She begins her work when everyone else ends theirs. While the town tucks itself into bed, Rosa ties her apron and begins to mix flour and water and a little salt. She could do it with her eyes closed — and sometimes, in the deep quiet of 2 AM, she nearly does.

The dough is warm and alive in her hands. She kneads it slowly, pressing and folding, pressing and folding. It's a rhythm as old as bread itself: push, fold, turn. Push, fold, turn.

The oven has been heating for an hour. It fills the bakery with a warmth that reaches into every corner. Rosa places the first loaves inside and closes the heavy iron door. Then she waits.

This is her favorite part — the waiting. She sits on her wooden stool, dusts the flour from her hands, and listens to the town sleep. She can hear the fountain in the square, trickling softly. A dog shifts in its sleep somewhere. The clock tower chimes once — a single, gentle note that floats over the rooftops and fades.

The smell begins. First, just warmth. Then, gradually, the golden scent of baking bread fills the bakery, slips under the door, and curls into the street. It drifts through open windows and into bedrooms, and the sleeping people of the town smell it in their dreams.

Rosa opens the oven to check. The loaves are rising beautifully, their crusts turning the color of sunset. She smiles and closes the door again.

She makes cinnamon rolls next. The brown sugar and cinnamon swirl together, and as she rolls the dough into spirals, the scent is so sweet and warm that even she feels her eyes growing heavy.

The town sleeps on, wrapped in the scent of bread and cinnamon. And Rosa, once the last tray is in the oven, folds her arms on the counter, rests her head, and closes her eyes. Just for a minute, she tells herself.

But the oven knows what to do. And the bread will be perfect in the morning.''',
  ),
];
