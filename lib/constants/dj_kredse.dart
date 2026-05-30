class DJKreds {
  final int number;
  final String name;
  final List<String> kommuner;

  const DJKreds({required this.number, required this.name, required this.kommuner});

  @override
  String toString() => 'Kreds $number — $name';
}

const djKredse = [
  DJKreds(number: 1, name: 'Nordjylland', kommuner: [
    'Aalborg', 'Brønderslev', 'Frederikshavn', 'Hjørring', 'Jammerbugt',
    'Læsø', 'Mariagerfjord', 'Morsø', 'Rebild', 'Thisted', 'Vesthimmerland',
  ]),
  DJKreds(number: 2, name: 'Midt-vest', kommuner: [
    'Herning', 'Holstebro', 'Ikast-Brande', 'Lemvig', 'Ringkøbing-Skjern',
    'Skive', 'Struer', 'Viborg',
  ]),
  DJKreds(number: 3, name: 'Midt-øst', kommuner: [
    'Aarhus', 'Favrskov', 'Hedensted', 'Horsens', 'Norddjurs', 'Odder',
    'Randers', 'Samsø', 'Silkeborg', 'Skanderborg', 'Syddjurs',
  ]),
  DJKreds(number: 4, name: 'Sydjylland', kommuner: [
    'Aabenraa', 'Billund', 'Esbjerg', 'Fanø', 'Fredericia', 'Haderslev',
    'Kolding', 'Sønderborg', 'Tønder', 'Varde', 'Vejen', 'Vejle',
  ]),
  DJKreds(number: 5, name: 'Fyn', kommuner: [
    'Assens', 'Faaborg-Midtfyn', 'Kerteminde', 'Middelfart', 'Nordfyn',
    'Nyborg', 'Odense', 'Svendborg',
  ]),
  DJKreds(number: 6, name: 'Sydsjælland & øer', kommuner: [
    'Faxe', 'Guldborgsund', 'Lolland', 'Næstved', 'Slagelse', 'Sorø',
    'Vordingborg', 'Ærø', 'Langeland',
  ]),
  DJKreds(number: 7, name: 'Sjælland & Bornholm', kommuner: [
    'Allerød', 'Ballerup', 'Dragør', 'Egedal', 'Fredensborg', 'Frederiksberg',
    'Frederikssund', 'Furesø', 'Gentofte', 'Gladsaxe', 'Glostrup', 'Greve',
    'Gribskov', 'Halsnæs', 'Helsingør', 'Hillerød', 'Holbæk', 'Høje-Tåstrup',
    'Hørsholm', 'Ishøj', 'Kalundborg', 'København', 'Køge', 'Lejre',
    'Lyngby-Taarbæk', 'Odsherred', 'Roskilde', 'Rudersdal', 'Rødovre',
    'Solrød', 'Stevns', 'Tårnby', 'Vallensbæk',
  ]),
  DJKreds(number: 8, name: 'Bornholm', kommuner: ['Bornholm']),
];

// Simple coordinate-based kreds suggestion
// Returns best kreds guess based on lat/lon
int? suggestKredsFromLocation(double lat, double lon) {
  // Bornholm
  if (lon > 14.4) return 8;
  // Nordjylland
  if (lat > 56.9) return 1;
  // Fyn (roughly between the two belts)
  if (lon >= 9.7 && lon <= 10.95 && lat < 55.9 && lat > 55.0) return 5;
  // Sydsjælland & øer
  if (lon > 11.3 && lat < 55.4) return 6;
  // Sjælland
  if (lon > 11.3) return 7;
  // Sydjylland
  if (lat < 55.7 && lon < 9.7) return 4;
  // Midt-vest
  if (lon < 9.5) return 2;
  // Midt-øst
  return 3;
}
