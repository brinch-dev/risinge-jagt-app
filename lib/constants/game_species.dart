class GameSpeciesCategory {
  final String name;
  final List<String> species;
  const GameSpeciesCategory(this.name, this.species);
}

const gameSpeciesCategories = [
  GameSpeciesCategory('Hjortevildt', [
    'Kronhjort',
    'Dåhjort',
    'Sikahjort',
    'Råvildt',
    'Muntjak',
  ]),
  GameSpeciesCategory('Vildsvin', [
    'Vildsvin',
  ]),
  GameSpeciesCategory('Småvildt — Pattedyr', [
    'Hare',
    'Vildkanin',
    'Ræv',
    'Mårhund',
    'Mink',
    'Ilder',
    'Husmår',
    'Skovmår',
    'Vaskebjørn',
  ]),
  GameSpeciesCategory('Ænder', [
    'Gråand',
    'Krikand',
    'Pibeand',
    'Spidsand',
    'Skeand',
    'Troldand',
    'Bjergand',
    'Ederfugl',
    'Havlit',
    'Fløjlsand',
    'Sortand',
    'Hvinand',
    'Taffeland',
  ]),
  GameSpeciesCategory('Gæs', [
    'Grågås',
    'Blisgås',
    'Canadagås',
    'Bramgås',
    'Kortnæbbet gås',
  ]),
  GameSpeciesCategory('Hønsefugle', [
    'Fasan',
    'Agerhøne',
  ]),
  GameSpeciesCategory('Duer', [
    'Ringdue',
    'Tyrkerdue',
  ]),
  GameSpeciesCategory('Vadefugle', [
    'Skovsneppe',
    'Dobbeltbekkasin',
  ]),
  GameSpeciesCategory('Øvrige fugle', [
    'Blishøne',
    'Sølvmåge',
    'Sildemåge',
    'Svartbag',
  ]),
  GameSpeciesCategory('Regulering', [
    'Krage',
    'Husskade',
    'Råge',
    'Nilgås',
  ]),
];
