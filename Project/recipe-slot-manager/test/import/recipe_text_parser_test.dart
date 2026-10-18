import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/recipe_text_parser.dart';

void main() {
  test('영어 레시피 카드 형식에서 모든 필드를 읽는다', () {
    const lines = [
      'My Summer Recipe',
      'Film Simulation: Classic Negative',
      'Grain Effect: Weak, Large',
      'Color Chrome Effect: Strong',
      'Color Chrome FX Blue: Off',
      'White Balance: Daylight, +2 Red & -4 Blue',
      'Dynamic Range: DR400',
      'Highlight: -1.5',
      'Shadow: +0.5',
      'Color: +3',
      'Sharpness: -2',
      'High ISO NR: -4',
      'Clarity: -3',
      'ISO: Auto, up to ISO 6400',
      'Exposure Compensation: +1/3 to +2/3',
    ];

    expect(parseRecipeText(lines), {
      'filmSimulation': 0x11,
      'grain': 4,
      'colorChrome': 3,
      'colorChromeFxBlue': 1,
      'whiteBalance': 0x0004,
      'wbShiftRed': 2,
      'wbShiftBlue': -4,
      'dynamicRange': 400,
      'highlight': -1.5,
      'shadow': 0.5,
      'color': 3,
      'sharpness': -2,
      'noiseReduction': -4,
      'clarity': -3,
    });
  });

  test('한국어 SNS 형식과 한 줄에 여러 항목이 있는 글을 읽는다', () {
    const lines = [
      '📷 오늘의 레시피',
      '• 필름 시뮬레이션 : 클래식 크롬',
      '• 그레인 : 강, 소 / 컬러 크롬 : 약 / 컬러 크롬 FX 블루 : 강',
      '• 화이트 밸런스 : 5600K, R+1 B-3',
      '• 하이라이트 +1 섀도 -0.5',
      '• 컬러 -1 / 샤프니스 0 / 노이즈 리덕션 -2 / 클래리티 +2',
      '• 다이나믹 레인지 : DR200',
    ];

    expect(parseRecipeText(lines), {
      'filmSimulation': 0x0B,
      'grain': 3,
      'colorChrome': 2,
      'colorChromeFxBlue': 3,
      'whiteBalance': 0x8007,
      'colorTemperature': 5600,
      'wbShiftRed': 1,
      'wbShiftBlue': -3,
      'highlight': 1,
      'shadow': -0.5,
      'color': -1,
      'sharpness': 0,
      'noiseReduction': -2,
      'clarity': 2,
      'dynamicRange': 200,
    });
  });

  test('흑백 시뮬레이션과 모노 WC·MG 를 읽는다', () {
    const lines = [
      'Film Simulation: Acros + R',
      'Monochromatic Color: WC +2 MG -1',
    ];

    expect(parseRecipeText(lines), {
      'filmSimulation': 0x0E,
      'monoWarmCool': 2,
      'monoMagentaGreen': -1,
    });
  });

  test('OCR 이 섞는 글자(유니코드 마이너스, O, ½)를 숫자 자리에서 바로잡는다', () {
    const lines = [
      'Highlight: −1',
      'Shadow: +O.5',
      'Sharpness: +½',
      'Clarity：-2',
    ];

    expect(parseRecipeText(lines), {
      'highlight': -1,
      'shadow': 0.5,
      'sharpness': 0.5,
      'clarity': -2,
    });
  });

  test('WB 오토, 주변광 우선, DR-Auto 는 각각 오토, 주변광 우선, 빈칸이다', () {
    expect(parseRecipeText(['White Balance: Auto']), {'whiteBalance': 0x0002});
    expect(parseRecipeText(['White Balance: Auto Ambience Priority']), {
      'whiteBalance': 0x8021,
    });
    expect(parseRecipeText(['Dynamic Range: DR-Auto']), isEmpty);
  });

  test('그레인 끔과, 크기 없이 세기만 적힌 그레인(작게로 본다)', () {
    expect(parseRecipeText(['Grain Effect: Off']), {'grain': 1});
    expect(parseRecipeText(['Grain: Strong']), {'grain': 3});
  });

  test('레시피 항목이 없는 줄과 읽을 수 없는 값은 건너뛴다', () {
    expect(
      parseRecipeText(['Sunrise in Seoul', 'Highlight: maybe', 'nr: ']),
      isEmpty,
    );
  });

  test('macOS Vision 이 실제로 돌려준 줄(붙거나 떨어진 구분자)을 읽는다', () {
    const lines = [
      '오늘의 레시피',
      '필름 시뮬레이션: 클래식 크롬',
      '그레인 : 강, 소/ 컬러 크롬 : 약',
      'Highlight: -1.5',
      'White Balance: Daylight, +2 Red &-4 Blue',
    ];

    expect(parseRecipeText(lines), {
      'filmSimulation': 0x0B,
      'grain': 3,
      'colorChrome': 2,
      'highlight': -1.5,
      'whiteBalance': 0x0004,
      'wbShiftRed': 2,
      'wbShiftBlue': -4,
    });
  });

  test('제목 줄의 낱말보다 "이름: 값" 으로 적힌 줄을 먼저 쓴다', () {
    const lines = [
      'Kodak Color Recipe 2',
      'Film Simulation: Classic Chrome',
      'Color: +3',
    ];

    expect(parseRecipeText(lines), {'filmSimulation': 0x0B, 'color': 3});
  });
}
