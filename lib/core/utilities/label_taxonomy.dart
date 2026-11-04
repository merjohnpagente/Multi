import '../../shared/models/app_category.dart';
import 'slug_utils.dart';

class LabelInfo {
  const LabelInfo({
    required this.category,
    required this.subcategory,
    required this.displayName,
  });

  final AppCategory category;
  final String subcategory;
  final String displayName;
}

class LabelTaxonomy {
  LabelTaxonomy._();

  static const Set<String> _dogWords = <String>{
    'dog',
    'retriever',
    'terrier',
    'spaniel',
    'poodle',
    'shepherd',
    'collie',
    'corgi',
    'husky',
    'malamute',
    'chihuahua',
    'pug',
    'beagle',
    'bloodhound',
    'basset',
    'bluetick',
    'coonhound',
    'foxhound',
    'walker hound',
    'saluki',
    'whippet',
    'greyhound',
    'borzoi',
    'wolfhound',
    'deerhound',
    'elkhound',
    'otterhound',
    'dingo',
    'dhole',
    'dingo',
    'mastiff',
    'bullmastiff',
    'bulldog',
    'boxer',
    'boxer',
    'saint bernard',
    'newfoundland',
    'great pyrenees',
    'samoyed',
    'pomeranian',
    'keeshond',
    'schipperke',
    'groenendael',
    'malinois',
    'kelpie',
    'komondor',
    'kuvasz',
    'leonberg',
    'affenpinscher',
    'basenji',
    'briard',
    'dingo',
    'pug',
    'chow',
    'keeshond',
    'brabancon',
    'cardigan',
    'pembroke',
    'rhodesian ridgeback',
    'afghan hound',
    'ibizan hound',
    'norwegian elkhound',
    'weimaraner',
    'vizsla',
    'clumber',
    'sussex spaniel',
    'irish water spaniel',
    'curly-coated retriever',
    'flat-coated retriever',
    'chesapeake bay retriever',
    'labrador retriever',
    'golden retriever',
  };

  static const Set<String> _catWords = <String>{
    'cat',
    'tabby',
    'siamese',
    'persian cat',
    'egyptian cat',
    'lynx',
    'cougar',
    'puma',
    'jaguar',
    'leopard',
    'snow leopard',
    'tiger',
    'lion',
    'cheetah',
  };

  static const Set<String> _birdWords = <String>{
    'bird',
    'eagle',
    'hawk',
    'kite',
    'owl',
    'parrot',
    'macaw',
    'cockatoo',
    'lorikeet',
    'peacock',
    'ostrich',
    'flamingo',
    'stork',
    'heron',
    'crane',
    'swan',
    'goose',
    'duck',
    'drake',
    'chicken',
    'hen',
    'rooster',
    'turkey',
    'penguin',
    'albatross',
    'hummingbird',
    'jay',
    'magpie',
    'chickadee',
    'water ouzel',
    'dipper',
    'vulture',
    'black grouse',
    'ptarmigan',
    'ruffed grouse',
    'prairie chicken',
    'peafowl',
    'quail',
    'partridge',
    'hornbill',
    'jacamar',
    'toucan',
    'pelican',
    'king penguin',
    'spoonbill',
    'ibis',
    'limpkin',
    'bustard',
    'coot',
    'gallinule',
    'rail',
    'bittern',
    'egret',
    'crane',
    'kite',
    'vulture',
  };

  static const Set<String> _animalWords = <String>{
    'animal',
    'mammal',
    'fish',
    'shark',
    'ray',
    'eel',
    'salmon',
    'trout',
    'goldfish',
    'koi',
    'sturgeon',
    'tench',
    'frog',
    'toad',
    'salamander',
    'newt',
    'axolotl',
    'snake',
    'serpent',
    'lizard',
    'gecko',
    'iguana',
    'chameleon',
    'crocodile',
    'alligator',
    'turtle',
    'tortoise',
    'terrapin',
    'spider',
    'scorpion',
    'insect',
    'butterfly',
    'bee',
    'ant',
    'dragonfly',
    'damselfly',
    'beetle',
    'ladybug',
    'moth',
    'cockroach',
    'mantis',
    'cricket',
    'grasshopper',
    'cicada',
    'leafhopper',
    'lacewing',
    'weevil',
    'fly',
    'mosquito',
    'snail',
    'slug',
    'jellyfish',
    'starfish',
    'sea anemone',
    'whale',
    'dolphin',
    'seal',
    'sea lion',
    'otter',
    'walrus',
    'crab',
    'lobster',
    'shrimp',
    'octopus',
    'squid',
    'crayfish',
    'hermit crab',
    'horse',
    'cow',
    'ox',
    'sheep',
    'ram',
    'goat',
    'pig',
    'hog',
    'boar',
    'rabbit',
    'hare',
    'squirrel',
    'beaver',
    'porcupine',
    'hamster',
    'mouse',
    'rat',
    'guinea pig',
    'bat',
    'bear',
    'elephant',
    'zebra',
    'giraffe',
    'hippopotamus',
    'rhinoceros',
    'monkey',
    'ape',
    'gorilla',
    'chimpanzee',
    'orangutan',
    'gibbon',
    'baboon',
    'macaque',
    'lemur',
    'deer',
    'elk',
    'gazelle',
    'antelope',
    'bison',
    'buffalo',
    'camel',
    'llama',
    'kangaroo',
    'koala',
    'wombat',
    'platypus',
    'meerkat',
    'mongoose',
    'hyena',
    'jackal',
    'coyote',
    'dingo',
    'wolf',
    'fox',
    'badger',
    'weasel',
    'ferret',
    'mink',
    'skunk',
    'raccoon',
    'armadillo',
    'sloth',
    'anteater',
    'pangolin',
    'hedgehog',
    'shrew',
    'mole',
    'aardvark',
    'okapi',
    'tapir',
    'manatee',
    'dugong',
    'ibex',
    'mouflon',
    'bighorn',
    'hartebeest',
    'impala',
    'gazelle',
    'water buffalo',
    'musk ox',
  };

  static const Set<String> _plantWords = <String>{
    'plant',
    'flower',
    'daisy',
    'rose',
    'tulip',
    'sunflower',
    'orchid',
    'poppy',
    'lily',
    'lotus',
    'cactus',
    'tree',
    'oak',
    'maple',
    'pine',
    'palm',
    'willow',
    'leaf',
    'fern',
    'moss',
    'mushroom',
    'fungus',
    'fungi',
    'toadstool',
    'acorn',
    'hip',
    'buckeye',
    'rapeseed',
    'dandelion',
    'marigold',
    'petunia',
    'violet',
    'pansy',
    'azalea',
    'rhododendron',
    'magnolia',
    'geranium',
    'begonia',
    'primrose',
    'buttercup',
    'anemone',
    'columbine',
    'bellflower',
    'thistle',
    'carnation',
    'chrysanthemum',
    'gladiolus',
    'hyacinth',
    'iris',
    'lavender',
    'lilac',
    'peony',
    'phlox',
    'snapdragon',
    'zinnia',
    'bamboo',
    'fern',
    'ivy',
    'vine',
    'bush',
    'shrub',
    'sapling',
    'seedling',
    'sprout',
    'blossom',
    'bud',
    'petal',
    'stem',
    'branch',
  };

  static const Set<String> _fruitVegetableWords = <String>{
    'banana',
    'orange',
    'lemon',
    'pineapple',
    'strawberry',
    'fig',
    'pomegranate',
    'custard apple',
    'granny smith',
    'broccoli',
    'cauliflower',
    'zucchini',
    'spaghetti squash',
    'acorn squash',
    'butternut squash',
    'cucumber',
    'artichoke',
    'bell pepper',
    'cardoon',
    'corn',
    'cabbage',
    'carrot',
    'potato',
    'tomato',
    'onion',
    'garlic',
    'lettuce',
    'spinach',
    'pumpkin',
    'apple',
    'pear',
    'peach',
    'cherry',
    'grape',
    'watermelon',
    'melon',
    'mango',
    'papaya',
    'avocado',
    'kiwi',
    'blueberry',
    'raspberry',
    'blackberry',
    'cranberry',
    'gooseberry',
    'elderberry',
    'date',
    'apricot',
    'plum',
    'nectarine',
    'coconut',
    'almond',
    'walnut',
    'pecan',
    'cashew',
    'pistachio',
    'peanut',
    'chestnut',
    'hazelnut',
  };

  static const Set<String> _foodWords = <String>{
    'food',
    'dish',
    'meal',
    'pizza',
    'hamburger',
    'cheeseburger',
    'hot dog',
    'hotdog',
    'sandwich',
    'burrito',
    'taco',
    'pretzel',
    'bagel',
    'bread',
    'meat loaf',
    'steak',
    'guacamole',
    'consomme',
    'hot pot',
    'trifle',
    'ice cream',
    'ice lolly',
    'chocolate sauce',
    'dough',
    'potpie',
    'red wine',
    'espresso',
    'eggnog',
    'mashed potato',
    'carbonara',
    'plate',
    'soup',
    'salad',
    'pasta',
    'noodle',
    'rice',
    'sushi',
    'cake',
    'cookie',
    'biscuit',
    'dessert',
    'pudding',
    'pie',
    'tart',
    'waffle',
    'pancake',
    'coffee',
    'tea',
    'juice',
    'smoothie',
    'beer',
    'wine',
    'cocktail',
    'cheese',
    'yogurt',
    'cereal',
    'oatmeal',
    'popcorn',
    'french fries',
    'fried chicken',
  };

  static const Set<String> _vehicleWords = <String>{
    'vehicle',
    'car',
    'cab',
    'limousine',
    'minivan',
    'convertible',
    'sports car',
    'station wagon',
    'jeep',
    'ambulance',
    'police van',
    'fire engine',
    'garbage truck',
    'pickup',
    'tow truck',
    'trailer truck',
    'semi',
    'truck',
    'bus',
    'minibus',
    'trolleybus',
    'school bus',
    'motorcycle',
    'moped',
    'scooter',
    'bicycle',
    'mountain bike',
    'unicycle',
    'tricycle',
    'train',
    'locomotive',
    'electric locomotive',
    'steam locomotive',
    'streetcar',
    'tram',
    'airplane',
    'airliner',
    'warplane',
    'airship',
    'balloon',
    'spacecraft',
    'ship',
    'boat',
    'canoe',
    'kayak',
    'catamaran',
    'schooner',
    'yawl',
    'container ship',
    'fireboat',
    'paddlewheel',
    'speedboat',
    'submarine',
    'aircraft carrier',
    'warship',
    'sailboat',
    'forklift',
    'tractor',
    'harvester',
    'snowplow',
    'go-kart',
    'golfcart',
  };

  static const Set<String> _natureWords = <String>{
    'mountain',
    'alp',
    'valley',
    'volcano',
    'geyser',
    'lakeside',
    'lakeshore',
    'lake',
    'forest',
    'woodland',
    'meadow',
    'prairie',
    'grassland',
    'desert',
    'glacier',
    'waterfall',
    'river',
    'island',
    'cliff',
    'canyon',
    'hill',
    'field',
    'sky',
    'cloud',
    'sunset',
    'sunrise',
    'horizon',
    'rainbow',
    'snow',
    'ice',
    'swamp',
    'marsh',
    'bog',
    'jungle',
    'rainforest',
    'grove',
    'orchard',
  };

  static const Set<String> _placeWords = <String>{
    'place',
    'building',
    'castle',
    'palace',
    'bridge',
    'church',
    'monastery',
    'mosque',
    'lighthouse',
    'pier',
    'dock',
    'seashore',
    'beach',
    'sandbar',
    'promontory',
    'coral reef',
    'barn',
    'boathouse',
    'greenhouse',
    'patio',
    'ruin',
    'tower',
    'skyscraper',
    'stadium',
    'theater',
    'theatre',
    'library',
    'museum',
    'restaurant',
    'hotel',
    'house',
    'home',
    'street',
    'city',
    'town',
    'village',
    'harbor',
    'harbour',
    'market',
    'park',
    'garden',
    'courtyard',
    'plaza',
    'square',
    'temple',
    'shrine',
    'cathedral',
    'abbey',
    'fort',
    'dam',
    'windmill',
    'water mill',
    'locksmith',
  };

  static const Set<String> _documentWords = <String>{
    'document',
    'envelope',
    'binder',
    'notebook',
    'book jacket',
    'comic book',
    'newspaper',
    'menu',
    'crossword',
    'packet',
    'binder',
    'web site',
    'website',
    'internet site',
    'screen',
    'monitor',
    'desktop computer',
  };

  static const Set<String> _peopleWords = <String>{
    'person',
    'people',
    'human',
    'bridegroom',
    'scuba diver',
    'groom',
    'child',
    'baby',
    'man',
    'woman',
    'boy',
    'girl',
    'portrait',
  };

  static final Map<String, String> _displayOverrides = <String, String>{
    'golden retriever': 'Golden Retriever',
    'labrador retriever': 'Labrador Retriever',
    'german shepherd': 'German Shepherd',
    'french bulldog': 'French Bulldog',
    'pembroke': 'Pembroke Welsh Corgi',
    'tabby': 'Tabby Cat',
    'egyptian cat': 'Egyptian Cat',
    'granny smith': 'Granny Smith Apple',
    'sports car': 'Sports Car',
    'mountain bike': 'Mountain Bike',
    'hot dog': 'Hot Dog',
    'ice cream': 'Ice Cream',
    'seashore': 'Seashore',
    'lakeside': 'Lakeside',
    'alp': 'Mountain',
  };

  static LabelInfo describe(String rawLabel, {String source = 'general'}) {
    final String label = rawLabel.toLowerCase().trim();
    final String display = _displayOverrides[label] ?? humanizeLabel(rawLabel);

    if (source == 'plant') {
      return LabelInfo(
        category: AppCategory.plants,
        subcategory: 'Plant species',
        displayName: humanizeLabel(rawLabel),
      );
    }
    if (source == 'bird') {
      return LabelInfo(
        category: AppCategory.animals,
        subcategory: 'Birds',
        displayName: humanizeLabel(rawLabel),
      );
    }

    if (_containsAny(label, _vehicleWords)) {
      return LabelInfo(
        category: AppCategory.vehicles,
        subcategory: _vehicleSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _dogWords)) {
      return LabelInfo(
        category: AppCategory.animals,
        subcategory: 'Dogs',
        displayName: display,
      );
    }

    if (_containsAny(label, _catWords)) {
      return LabelInfo(
        category: AppCategory.animals,
        subcategory: 'Cats',
        displayName: display,
      );
    }

    if (_containsAny(label, _birdWords)) {
      return LabelInfo(
        category: AppCategory.animals,
        subcategory: 'Birds',
        displayName: display,
      );
    }

    if (_containsAny(label, _animalWords)) {
      return LabelInfo(
        category: AppCategory.animals,
        subcategory: _animalSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _fruitVegetableWords)) {
      final bool isFruit = _fruitWords.any((String word) => label.contains(word));
      return LabelInfo(
        category: AppCategory.food,
        subcategory: isFruit ? 'Fruits' : 'Vegetables',
        displayName: display,
      );
    }

    if (_containsAny(label, _foodWords)) {
      return LabelInfo(
        category: AppCategory.food,
        subcategory: _foodSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _plantWords)) {
      return LabelInfo(
        category: AppCategory.plants,
        subcategory: _plantSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _placeWords)) {
      return LabelInfo(
        category: AppCategory.places,
        subcategory: _placeSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _natureWords)) {
      return LabelInfo(
        category: AppCategory.nature,
        subcategory: _natureSubcategory(label),
        displayName: display,
      );
    }

    if (_containsAny(label, _documentWords)) {
      return LabelInfo(
        category: AppCategory.documents,
        subcategory: 'Documents',
        displayName: display,
      );
    }

    if (_containsAny(label, _peopleWords)) {
      return LabelInfo(
        category: AppCategory.people,
        subcategory: 'People',
        displayName: display,
      );
    }

    return LabelInfo(
      category: AppCategory.other,
      subcategory: 'Objects',
      displayName: display,
    );
  }

  static bool isPlantHint(String label) {
    final String value = label.toLowerCase();
    return _containsAny(value, _plantWords) ||
        _containsAny(value, _fruitVegetableWords) ||
        value.contains('flower') ||
        value.contains('tree') ||
        value.contains('leaf');
  }

  static bool isBirdHint(String label) {
    return _containsAny(label.toLowerCase(), _birdWords);
  }

  static bool _containsAny(String label, Set<String> words) {
    return words.any((String word) {
      final String escaped = RegExp.escape(word);
      return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(label);
    });
  }

  static String _vehicleSubcategory(String label) {
    if (_containsAny(label, <String>{'car', 'jeep', 'cab', 'limousine', 'minivan', 'convertible', 'wagon', 'taxi'})) {
      return 'Cars';
    }
    if (_containsAny(label, <String>{'motorcycle', 'moped', 'scooter'})) {
      return 'Motorcycles';
    }
    if (_containsAny(label, <String>{'bus', 'truck', 'tractor', 'forklift', 'harvester', 'snowplow'})) {
      return 'Buses & Trucks';
    }
    if (_containsAny(label, <String>{'bicycle', 'bike', 'unicycle', 'tricycle'})) {
      return 'Bicycles';
    }
    if (_containsAny(label, <String>{'airplane', 'airliner', 'warplane', 'airship', 'balloon', 'spacecraft'})) {
      return 'Aircraft';
    }
    return 'Watercraft';
  }

  static String _animalSubcategory(String label) {
    if (_containsAny(label, <String>{'horse', 'pony', 'stallion', 'mare', 'donkey', 'zebra'})) {
      return 'Horses';
    }
    if (_containsAny(label, <String>{'cow', 'ox', 'bull', 'bison', 'buffalo', 'sheep', 'goat', 'ibex'})) {
      return 'Farm animals';
    }
    if (_containsAny(label, <String>{'fish', 'shark', 'ray', 'eel', 'salmon', 'trout', 'goldfish', 'koi'})) {
      return 'Fish';
    }
    if (_containsAny(label, <String>{'spider', 'insect', 'butterfly', 'bee', 'ant', 'beetle', 'ladybug', 'moth', 'dragonfly'})) {
      return 'Insects';
    }
    if (_containsAny(label, <String>{'snake', 'lizard', 'frog', 'toad', 'turtle', 'tortoise', 'crocodile', 'alligator'})) {
      return 'Reptiles & Amphibians';
    }
    if (_containsAny(label, <String>{'whale', 'dolphin', 'seal', 'otter', 'walrus', 'crab', 'lobster', 'shrimp', 'octopus', 'jellyfish', 'starfish'})) {
      return 'Marine life';
    }
    return 'Wild animals';
  }

  static String _foodSubcategory(String label) {
    if (_containsAny(label, <String>{'coffee', 'espresso', 'tea', 'wine', 'beer', 'juice', 'drink', 'cocktail'})) {
      return 'Drinks';
    }
    if (_containsAny(label, <String>{'pizza', 'burger', 'sandwich', 'taco', 'burrito', 'pasta', 'rice', 'soup', 'salad', 'sushi', 'steak', 'pot'})) {
      return 'Dishes';
    }
    return 'Food';
  }

  static String _plantSubcategory(String label) {
    if (_containsAny(label, <String>{'flower', 'daisy', 'rose', 'tulip', 'sunflower', 'orchid', 'poppy', 'lily', 'lotus', 'blossom', 'petal', 'violet', 'lavender', 'lilac', 'peony', 'iris'})) {
      return 'Flowers';
    }
    if (_containsAny(label, <String>{'tree', 'oak', 'maple', 'pine', 'palm', 'willow', 'bamboo', 'sapling', 'branch'})) {
      return 'Trees';
    }
    if (_containsAny(label, <String>{'leaf', 'fern', 'ivy', 'vine', 'sprout', 'seedling'})) {
      return 'Leaves';
    }
    if (_containsAny(label, <String>{'mushroom', 'fungus', 'toadstool'})) {
      return 'Mushrooms';
    }
    return 'Plants';
  }

  static String _placeSubcategory(String label) {
    if (_containsAny(label, <String>{'beach', 'seashore', 'sandbar', 'pier', 'dock', 'harbor', 'harbour', 'coral reef', 'promontory'})) {
      return 'Beaches';
    }
    if (_containsAny(label, <String>{'castle', 'palace', 'church', 'cathedral', 'monastery', 'mosque', 'temple', 'tower', 'skyscraper', 'building', 'barn', 'house', 'ruin', 'fort', 'lighthouse'})) {
      return 'Buildings';
    }
    if (_containsAny(label, <String>{'park', 'garden', 'courtyard', 'plaza', 'square', 'orchard'})) {
      return 'Parks';
    }
    return 'Landmarks';
  }

  static String _natureSubcategory(String label) {
    if (_containsAny(label, <String>{'mountain', 'alp', 'valley', 'volcano', 'geyser', 'cliff', 'canyon', 'hill'})) {
      return 'Mountains';
    }
    if (_containsAny(label, <String>{'forest', 'woodland', 'jungle', 'rainforest', 'grove'})) {
      return 'Forests';
    }
    if (_containsAny(label, <String>{'lake', 'lakeside', 'lakeshore', 'river', 'waterfall', 'island'})) {
      return 'Lakes & Rivers';
    }
    return 'Landscapes';
  }

  static final Set<String> _fruitWords = <String>{
    'banana',
    'orange',
    'lemon',
    'pineapple',
    'strawberry',
    'fig',
    'pomegranate',
    'custard apple',
    'granny smith',
    'apple',
    'pear',
    'peach',
    'cherry',
    'grape',
    'watermelon',
    'melon',
    'mango',
    'papaya',
    'avocado',
    'kiwi',
    'blueberry',
    'raspberry',
    'blackberry',
    'cranberry',
    'date',
    'apricot',
    'plum',
    'nectarine',
    'coconut',
  };
}
