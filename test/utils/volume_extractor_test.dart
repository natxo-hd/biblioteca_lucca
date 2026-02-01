import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca_lucca/utils/volume_extractor.dart';

void main() {
  group('VolumeExtractor.extractFromTitle', () {
    group('Omnibus patterns', () {
      test('ONE PIECE 3 EN 1 10', () {
        final info = VolumeExtractor.extractFromTitle('ONE PIECE 3 EN 1 10');
        expect(info.seriesName, 'ONE PIECE 3 EN 1');
        expect(info.volumeNumber, 10);
        expect(info.isOmnibus, true);
        expect(info.baseSeriesName, 'ONE PIECE');
      });

      test('Dragon Ball 3 en 1 5', () {
        final info = VolumeExtractor.extractFromTitle('Dragon Ball 3 en 1 5');
        expect(info.seriesName, 'Dragon Ball 3 en 1');
        expect(info.volumeNumber, 5);
        expect(info.isOmnibus, true);
        expect(info.baseSeriesName, 'Dragon Ball');
      });

      test('ONE PIECE 3 EN 1 (no volume number)', () {
        final info = VolumeExtractor.extractFromTitle('ONE PIECE 3 EN 1');
        expect(info.isOmnibus, true);
        expect(info.baseSeriesName, 'ONE PIECE');
        expect(info.volumeNumber, isNull);
      });

      test('X en 1 nº pattern', () {
        final info =
            VolumeExtractor.extractFromTitle('ONE PIECE 3 en 1 nº 05');
        expect(info.volumeNumber, 5);
        expect(info.isOmnibus, true);
      });
    });

    group('Standard volume patterns', () {
      test('nº pattern: NARUTO Nº 10', () {
        final info = VolumeExtractor.extractFromTitle('NARUTO Nº 10');
        expect(info.seriesName, 'NARUTO');
        expect(info.volumeNumber, 10);
      });

      test('n° pattern: Dragon Ball Super n° 5', () {
        final info =
            VolumeExtractor.extractFromTitle('Dragon Ball Super n° 5');
        expect(info.seriesName, 'Dragon Ball Super');
        expect(info.volumeNumber, 5);
      });

      test('Vol. pattern: Batman Vol. 3', () {
        final info = VolumeExtractor.extractFromTitle('Batman Vol. 3');
        expect(info.seriesName, 'Batman');
        expect(info.volumeNumber, 3);
      });

      test('Volume pattern: Batman Volume 1', () {
        final info = VolumeExtractor.extractFromTitle('Batman Volume 1');
        expect(info.seriesName, 'Batman');
        expect(info.volumeNumber, 1);
      });

      test('# pattern: Spider-Man #25', () {
        final info = VolumeExtractor.extractFromTitle('Spider-Man #25');
        expect(info.seriesName, 'Spider-Man');
        expect(info.volumeNumber, 25);
      });

      test('Tomo pattern: Berserk Tomo 12', () {
        final info = VolumeExtractor.extractFromTitle('Berserk Tomo 12');
        expect(info.seriesName, 'Berserk');
        expect(info.volumeNumber, 12);
      });

      test('Libro pattern: Saga: Libro 2', () {
        final info = VolumeExtractor.extractFromTitle('Saga: Libro 2');
        expect(info.seriesName, 'Saga');
        expect(info.volumeNumber, 2);
      });

      test('Parte pattern: Sandman: Parte 3', () {
        final info = VolumeExtractor.extractFromTitle('Sandman: Parte 3');
        expect(info.seriesName, 'Sandman');
        expect(info.volumeNumber, 3);
      });

      test('Parenthesis pattern: Akira (4)', () {
        final info = VolumeExtractor.extractFromTitle('Akira (4)');
        expect(info.seriesName, 'Akira');
        expect(info.volumeNumber, 4);
      });

      test('Number at end: One Piece 42', () {
        final info = VolumeExtractor.extractFromTitle('One Piece 42');
        expect(info.seriesName, 'One Piece');
        expect(info.volumeNumber, 42);
      });
    });

    group('TomoYGrapas patterns', () {
      test('GREEN BLOOD 02 (DE 5)', () {
        final info =
            VolumeExtractor.extractFromTitle('GREEN BLOOD 02 (DE 5)');
        expect(info.seriesName, 'GREEN BLOOD');
        expect(info.volumeNumber, 2);
      });

      test('RADIANT BLACK 02: TEAM-UP', () {
        final info =
            VolumeExtractor.extractFromTitle('RADIANT BLACK 02: TEAM-UP');
        expect(info.seriesName, 'RADIANT BLACK');
        expect(info.volumeNumber, 2);
      });

      test('SERIE 03 - SUBTITULO', () {
        final info =
            VolumeExtractor.extractFromTitle('VAGABOND 03 - El Camino');
        expect(info.seriesName, 'VAGABOND');
        expect(info.volumeNumber, 3);
      });

      test('MASSIVE-VERSE prefix is cleaned', () {
        final info = VolumeExtractor.extractFromTitle(
            'MASSIVE-VERSE: RADIANT BLACK 02');
        expect(info.seriesName, 'RADIANT BLACK');
        expect(info.volumeNumber, 2);
      });
    });

    group('Edge cases', () {
      test('empty string', () {
        final info = VolumeExtractor.extractFromTitle('');
        expect(info.seriesName, '');
        expect(info.volumeNumber, isNull);
      });

      test('no volume number', () {
        final info = VolumeExtractor.extractFromTitle('Batman: Year One');
        expect(info.seriesName, 'Batman: Year One');
        expect(info.volumeNumber, isNull);
      });

      test('title with only spaces', () {
        final info = VolumeExtractor.extractFromTitle('   ');
        expect(info.volumeNumber, isNull);
      });
    });
  });

  group('VolumeExtractor.cleanSeriesName', () {
    test('removes MASSIVE-VERSE prefix', () {
      expect(VolumeExtractor.cleanSeriesName('MASSIVE-VERSE: RADIANT BLACK'),
          'RADIANT BLACK');
    });

    test('removes (DE X) suffix', () {
      expect(VolumeExtractor.cleanSeriesName('GREEN BLOOD (DE 5)'),
          'GREEN BLOOD');
    });

    test('does not return empty string', () {
      expect(
          VolumeExtractor.cleanSeriesName('MASSIVE-VERSE: ').isNotEmpty, true);
    });
  });
}
